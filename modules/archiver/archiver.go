package main

import (
	"fmt"
	"io"
	logger "log"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/urfave/cli/v2"
)

// DefaultRetentionWeeks number of weeks backups are kept
const DefaultRetentionWeeks = 4

// we are doing an incremental backups using tar
// restoring would be just extracting from the oldest archive
// Use it as
// archiver.sh backup|restore src dest [extra-args for tar]
// (no trailing / for both src and dest)
// https://www.gnu.org/software/tar/manual/html_node/Scripted-Restoration.html//Scripted-Restoration

// State of the backup.
type State struct {
	LastSuccessfulBackup time.Time      `toml:"last_successful_backup"`
	IsBackupRunning      bool           `toml:"is_backup_running"`
	WeeklyBackups        []WeeklyBackup `toml:"weekly_backups"`
}

// WeeklyBackup contains a base tar with
type WeeklyBackup struct {
	YearWeek     string   `toml:"year_week"`
	DailyBackups []string `toml:"daily_backups"`
}

var log = logger.New(os.Stdout, "", 0)

func main() {
	app := cli.App{
		Name:  "archiver",
		Usage: "Archiver",
		Commands: []*cli.Command{
			{
				Name:        "backup",
				Aliases:     []string{"b"},
				Usage:       "archiver backup src backupDir",
				Description: "Backup using tar and gzip.",
				ArgsUsage:   "Takes src and backUp folder.",
				Action: func(context *cli.Context) error {
					args := context.Args()
					src, backupDir := args.Get(0), args.Get(1)
					if src == "" || backupDir == "" {
						return fmt.Errorf("src or backupDir is empty")
					}

					state, err := loadStateFile(backupDir)
					if err != nil {
						log.Print("initiating backup dir...")
					}

					state.IsBackupRunning = true
					err = saveStateFile(backupDir, state)
					if err != nil {
						return err
					}

					yearWeek, tarFileName, err := backup(src, backupDir)
					if err != nil {
						return err
					}

					weeklyBackup := WeeklyBackup{YearWeek: yearWeek}
					if len(state.WeeklyBackups) > 0 {
						wb := state.WeeklyBackups[len(state.WeeklyBackups)-1]
						if wb.YearWeek == yearWeek {
							state.WeeklyBackups = state.WeeklyBackups[:len(state.WeeklyBackups)-1]
							weeklyBackup = wb
						}
					}

					weeklyBackup.DailyBackups = append(weeklyBackup.DailyBackups, tarFileName)
					state.LastSuccessfulBackup = time.Now().UTC()
					state.IsBackupRunning = false
					state.WeeklyBackups = append(state.WeeklyBackups, weeklyBackup)
					err = saveStateFile(backupDir, state)
					if err != nil {
						return err
					}

					log.Print("cleaning up...")
					return cleanup(state, backupDir)
				},
			},
			{
				Name:        "restore",
				Aliases:     []string{"r"},
				Usage:       "archiver restore src backupDir",
				Description: "Restore using tar and gzip.",
				ArgsUsage:   "Takes src and backUp folder.",
				Action: func(context *cli.Context) error {
					args := context.Args()
					src, backupDir := args.Get(0), args.Get(1)
					if src == "" || backupDir == "" {
						return fmt.Errorf("src or backupDir is empty")
					}

					return restore(backupDir, src)
				},
			},
		},
		Suggest: true,
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatalln(err)
	}
}

func cleanup(state State, backupDir string) error {
	if len(state.WeeklyBackups) <= DefaultRetentionWeeks {
		return nil
	}

	toRemove := len(state.WeeklyBackups) - DefaultRetentionWeeks
	var toRemoveDirs []WeeklyBackup
	toRemoveDirs, state.WeeklyBackups = state.WeeklyBackups[:toRemove], state.WeeklyBackups[toRemove:]
	for _, backup := range toRemoveDirs {
		dir := fmt.Sprintf("%s/%s", backupDir, backup.YearWeek)
		log.Printf("deleting backup[%s]...", dir)
		err := os.RemoveAll(dir)
		if err != nil {
			return fmt.Errorf("failed to remove weekly backup[%s], %v", dir, err)
		}
	}

	return saveStateFile(backupDir, state)
}

// we use directory as / since we created with full path and tar tries to recreate it as is
// https://stackoverflow.com/questions/3153683/how-do-i-exclude-absolute-paths-for-tar may help if you want to exclude
// path

func restore(backupDir, src string) error {
	// (no trailing / for both src and dest)
	src, backupDir = strings.TrimSuffix(src, "/"), strings.TrimSuffix(backupDir, "/")
	weeklyBackup, err := findLatestBackup(backupDir)
	if err != nil {
		return err
	}

	err = ensureSrcIsEmpty(src)
	if err != nil {
		return err
	}

	log.Printf("starting restore from backup[%s]...", weeklyBackup.YearWeek)
	for _, backup := range weeklyBackup.DailyBackups {
		tarfile := fmt.Sprintf("%s/%s/%s.tgz", backupDir, weeklyBackup.YearWeek, backup)
		log.Printf("restoring %s...", tarfile)
		err = restoreTar(tarfile)
		if err != nil {
			return fmt.Errorf("failed to restore[%s]: %v", tarfile, err)
		}
	}
	log.Print("restore done.")
	return nil
}

func restoreTar(tarFile string) error {
	cmd := exec.Command("tar",
		"-vv", "--extract",
		fmt.Sprintf("--file=%s", tarFile),
		"--listed-incremental=/dev/null",
		"--directory=/")

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func ensureSrcIsEmpty(src string) error {
	err := os.MkdirAll(src, 0755)
	if err != nil {
		return err
	}

	f, err := os.Open(src)
	if err != nil {
		return err
	}

	_, err = f.ReadDir(1)
	if err == io.EOF {
		return nil
	}

	return fmt.Errorf("src directory must be empty")
}

func findLatestBackup(backupDir string) (weeklyBackup WeeklyBackup, err error) {
	state, err := loadStateFile(backupDir)
	if err != nil {
		return weeklyBackup, fmt.Errorf("failed to load back up state: %v", err)
	}

	if len(state.WeeklyBackups) < 1 {
		return weeklyBackup, fmt.Errorf("no backup found")
	}

	return state.WeeklyBackups[len(state.WeeklyBackups)-1], nil
}

func backup(src, backupDir string) (yearWeek, time string, err error) {
	// (no trailing / for both src and dest)
	src, backupDir = strings.TrimSuffix(src, "/"), strings.TrimSuffix(backupDir, "/")
	yearWeek, time = getYearWeekAndTime()
	wd := fmt.Sprintf("%s/%s", backupDir, yearWeek)

	// fetch next state file
	stateFile, exists, err := fetchNextStateFile(wd, time)
	if err != nil {
		return yearWeek, time, fmt.Errorf("failed to fetch next state file: %v", err)
	}
	if exists {
		log.Print("doing incremental backup...")
	} else {
		log.Print("doing full backup...")
	}

	backupFileName := fmt.Sprintf("%s/%s", wd, time)
	err = backupWithTar(src, stateFile, backupFileName)
	if err != nil {
		return yearWeek, time, fmt.Errorf("failed to backup: %v", err)
	}
	log.Print("backup done.")
	log.Print("verifying backup...")
	err = verifyTarBackup(backupFileName)
	if err != nil {
		return yearWeek, time, fmt.Errorf("tar backup verficication failed: %v", err)
	}
	log.Print("verification done.")
	return yearWeek, time, overwriteStateFile(wd, time)
}

func verifyTarBackup(fileName string) error {
	cmd := exec.Command("gzip", "-t", fmt.Sprintf("%s.tgz", fileName))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func backupWithTar(src, stateFile, fileName string) error {
	cmd := exec.Command("tar",
		"-vv", "--create", "--one-file-system", "--gzip",
		fmt.Sprintf("--listed-incremental=%s", stateFile),
		fmt.Sprintf("--file=%s.tgz", fileName), src)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Start()
	if err != nil {
		return err
	}

	err = cmd.Wait()
	if err != nil {
		if eErr, ok := err.(*exec.ExitError); ok {
			// exit could be 0 or 1
			// more on that here https://man7.org/linux/man-pages/man1/tar.1.html
			// tldr; if file changed during the archive or file changed after archive, tar returns 1
			// if this is more than 1, then its fatal
			if eErr.ExitCode() == 1 {
				return nil
			}
		}

		return err
	}

	return nil
}

// Returns the next state file.
// check if the latest state exists, if so copies and returns it
func fetchNextStateFile(dir, time string) (stateFile string, exists bool, err error) {
	stateFile = fmt.Sprintf("%s/state_%s.sngz", dir, time)
	latestStateFile := fmt.Sprintf("%s/state.sngz", dir)
	_, err = os.Stat(latestStateFile)
	if err != nil {
		return stateFile, false, os.MkdirAll(dir, 0755)
	}

	err = copyFile(latestStateFile, stateFile)
	if err != nil {
		return stateFile, false, fmt.Errorf("failed to copy the latest state file: %v", err)
	}

	return stateFile, true, nil
}

func overwriteStateFile(dir, time string) error {
	stateFile := fmt.Sprintf("%s/state_%s.sngz", dir, time)
	latestStateFile := fmt.Sprintf("%s/state.sngz", dir)
	_, err := os.Stat(stateFile)
	if err != nil {
		return err
	}

	err = copyFile(stateFile, latestStateFile)
	if err != nil {
		return fmt.Errorf("failed to update latest state file: %v", err)
	}

	return nil
}

func copyFile(src, dst string) error {
	cmd := exec.Command("cp", src, dst)
	return cmd.Run()
}

func getYearWeekAndTime() (yearWeek, date string) {
	// year-week number
	t := time.Now().UTC()
	year, week := t.ISOWeek()
	yearWeek = fmt.Sprintf("%d-%d", year, week)
	date = t.Format("2006-01-02T15-04-05")
	return yearWeek, date
}

func saveStateFile(backupdir string, state State) error {
	err := os.MkdirAll(backupdir, 0755)
	if err != nil {
		return err
	}

	f, err := os.Create(fmt.Sprintf("%s/state.toml", backupdir))
	if err != nil {
		return err
	}
	defer f.Close()

	enc := toml.NewEncoder(f)
	return enc.Encode(state)
}

func loadStateFile(dir string) (state State, err error) {
	_, err = toml.DecodeFile(fmt.Sprintf("%s/state.toml", dir), &state)
	return state, err
}
