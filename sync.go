package main

import (
	"embed"
	"fmt"
	"os"
	"strings"
)

func InitHub(session Session) error {
	log.Infoln("Running init script...")
	err := session.ExecuteCommandStream("hub-script-init", os.Stdout)
	if err != nil {
		return err
	}

	log.Infoln("Installing dependencies...")
	err = session.ExecuteCommandStream("hub run-script deps", os.Stdout)
	if err != nil {
		return err
	}

	err = loadSystemdUnits(session)
	if err != nil {
		return err
	}

	return nil
}

func SyncStaticFiles(session Session) error {
	err := syncStaticFiles(session)
	if err != nil {
		return err
	}

	// give execute permissions for scripts
	res, err := session.ExecuteCommand("chmod +x /opt/hub/scripts/*")
	if err != nil {
		return fmt.Errorf("failed to give exec permissions[%s]: %v", string(res), err)
	}

	// create symlinks for scripts
	err = createSymLinks(session, "scripts", "/sbin/hub-script-%s")
	if err != nil {
		return fmt.Errorf("failed to create symlinks for scripts: %v", err)
	}

	// copy systemd unit files
	_, err = session.ExecuteCommand("cp /opt/hub/systemd/* /etc/systemd/system/")
	if err != nil {
		return fmt.Errorf("failed to create sym links for systemd unit files: %v", err)
	}

	// give execute permissions for commands
	res, err = session.ExecuteCommand("chmod +x /opt/hub/commands/*")
	if err != nil {
		return fmt.Errorf("failed to give exec permissions[%s]: %v", string(res), err)
	}

	// sync env file
	err = syncEnvFile(session)
	if err != nil {
		return fmt.Errorf("failed to sync .env file: %v", err)
	}

	return nil
}

func createSymLinks(session Session, dir, linkPathTmpl string) error {
	log.Infof("Creating Symlinks for files in %v...\n", dir)
	files, err := staticFS.ReadDir(dir)
	if err != nil {
		return err
	}

	for _, file := range files {
		if file.IsDir() {
			continue
		}

		oldPath := fmt.Sprintf("/opt/hub/%s/%s", dir, file.Name())
		linkPath := fmt.Sprintf(linkPathTmpl, file.Name())

		// special case for scripts
		linkPath = strings.TrimSuffix(linkPath, ".sh")
		if file.Name() == "hub.sh" {
			linkPath = "/sbin/hub"
		}

		err = session.SymLink(oldPath, linkPath)
		if err != nil {
			return fmt.Errorf("failed to symlink script: %v", err)
		}
	}

	return nil
}

func loadSystemdUnits(session Session) error {
	log.Infoln("Enabling Systemd units...")
	units, err := staticFS.ReadDir("systemd")
	if err != nil {
		return err
	}

	var unitNames []string
	for _, file := range units {
		if file.IsDir() {
			continue
		}

		unitNames = append(unitNames, file.Name())
	}

	res, err := session.ExecuteCommand("systemctl daemon-reload")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	res, err = session.ExecuteCommand(fmt.Sprintf("systemctl reenable docker.service %s", strings.Join(unitNames, " ")))
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	res, err = session.ExecuteCommand("systemctl restart hub-*.timer")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	return nil
}

func syncEnvFile(session Session) error {
	log.Infoln("Syncing .env file...")
	file, err := staticFS.ReadFile(".env")
	if err != nil {
		return err
	}

	_, err = session.ExecuteCommand("mkdir -p /etc/hub")
	if err != nil {
		return err
	}

	return session.WriteDataToFile(file, "/etc/hub/.env")
}

//go:embed conf scripts docker systemd commands .env
var staticFS embed.FS

func syncStaticFiles(session Session) error {
	log.Infoln("Syncing static files...")
	entries, err := staticFS.ReadDir(".")
	if err != nil {
		return err
	}

	for _, dir := range entries {
		if !dir.IsDir() {
			continue
		}

		log.Infof("Syncing %s files...\n", dir.Name())
		files, err := staticFS.ReadDir(dir.Name())
		if err != nil {
			return err
		}

		_, err = session.ExecuteCommand(fmt.Sprintf("mkdir -p /opt/hub/%s", dir.Name()))
		if err != nil {
			return err
		}

		for _, file := range files {
			if file.IsDir() {
				continue
			}

			fileData, err := staticFS.ReadFile(fmt.Sprintf("%s/%s", dir.Name(), file.Name()))
			if err != nil {
				return err
			}

			remotePath := fmt.Sprintf("/opt/hub/%s/%s", dir.Name(), file.Name())
			err = session.WriteDataToFile(fileData, remotePath)
			if err != nil {
				return err
			}
		}

	}

	return err
}
