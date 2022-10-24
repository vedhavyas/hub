package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/urfave/cli/v2"
)

// we are doing an incremental backups using tar
// restoring would be just extracting from oldest archive
// Use it as
// archiver.sh backup|restore src dest [extra-args for tar]
// (no trailing / for both src and dest)
// https://www.gnu.org/software/tar/manual/html_node/Scripted-Restoration.html//Scripted-Restoration

// State of the backup.
type State struct {
	LastSuccessfulBackup time.Time           `toml:"last_successful_backup"`
	IsBackupRunning      bool                `toml:"is_backup_running"`
	Backups              map[string][]string `toml:"backups"`
}

func main() {
	app := cli.App{
		Name:  "hub",
		Usage: "Hub",
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
						state = State{
							Backups: map[string][]string{},
						}
					}

					state.IsBackupRunning = true
					err = saveStateFile(backupDir, state)
					if err != nil {
						return err
					}

					log.Print("test")
					yearWeek, tarFileName, err := backup(src, backupDir)
					if err != nil {
						return err
					}

					state.LastSuccessfulBackup = time.Now().UTC()
					state.IsBackupRunning = false
					state.Backups[yearWeek] = append(state.Backups[yearWeek], tarFileName)
					return saveStateFile(backupDir, state)
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

func restore(backupDir, src string) error {
	// (no trailing / for both src and dest)
	src, backupDir = strings.TrimSuffix(src, "/"), strings.TrimSuffix(backupDir, "/")
	yearWeek, backups, err := findLatestBackup(backupDir)
	if err != nil {
		return err
	}

	err = ensureSrcIsEmpty(src)
	if err != nil {
		return err
	}

	log.Print("starting restore...")
	for _, backup := range backups {
		tarfile := fmt.Sprintf("%s/%s/%s.tgz", backupDir, yearWeek, backup)
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

func findLatestBackup(backupDir string) (yearWeek string, backups []string, err error) {
	state, err := loadStateFile(backupDir)
	if err != nil {
		return yearWeek, nil, fmt.Errorf("failed to load back up state: %v", err)
	}

	yearWeek, _ = getYearWeekAndTime()
	backups, ok := state.Backups[yearWeek]
	if ok {
		return yearWeek, backups, nil
	}

	// TODO: decrement week and check the older back up until max week stored.
	return yearWeek, nil, fmt.Errorf("no backup found")
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

	log.Print("starting backup...")
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

func saveStateFile(dir string, state State) error {
	err := os.MkdirAll(dir, 0755)
	if err != nil {
		return err
	}

	f, err := os.Create(fmt.Sprintf("%s/state.toml", dir))
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
