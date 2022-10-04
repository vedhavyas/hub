package main

import (
	"embed"
	"fmt"
	"strings"
)

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
		return fmt.Errorf("failed to create sym links for scripts: %v", err)
	}

	// create symlinks for systemd files
	err = createSymLinks(session, "systemd", "/etc/systemd/system/%s")
	if err != nil {
		return fmt.Errorf("failed to create sym links for systemd unit files: %v", err)
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

		log.Infoln(oldPath, linkPath)
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

//go:embed conf scripts docker systemd
var staticFS embed.FS

func syncStaticFiles(session Session) error {
	log.Infoln("Syncing static files...")
	entries, err := staticFS.ReadDir(".")
	if err != nil {
		return err
	}

	for _, dir := range entries {
		if !dir.IsDir() {
			log.Errorf("unknown file found in static: %v", dir)
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
