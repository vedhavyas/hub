package main

import (
	"embed"
	"fmt"
	"strings"
)

//go:embed scripts
var s embed.FS

func syncScripts(session Session) error {
	log.Infoln("Syncing scripts...")
	scripts, err := s.ReadDir("scripts")
	if err != nil {
		return err
	}

	_, err = session.ExecuteCommand("mkdir -p /opt/hub/scripts")
	if err != nil {
		return err
	}

	for _, file := range scripts {
		if file.IsDir() {
			continue
		}

		fileData, err := s.ReadFile(fmt.Sprintf("scripts/%s", file.Name()))
		if err != nil {
			return err
		}

		remotePath := fmt.Sprintf("/opt/hub/scripts/%s", file.Name())
		err = session.WriteScriptToFile(fileData, remotePath)
		if err != nil {
			return err
		}

		binaryPath := fmt.Sprintf("/sbin/hub-script-%s", strings.TrimSuffix(file.Name(), ".sh"))
		if file.Name() == "hub.sh" {
			binaryPath = "/sbin/hub"
		}

		err = session.SymLink(remotePath, binaryPath)
		if err != nil {
			return fmt.Errorf("failed to symlink script: %v", err)
		}
	}

	return nil
}

//go:embed systemd
var systemdFs embed.FS

func syncSystemdUnitFiles(session Session) error {
	log.Infoln("Syncing Systemd unit files...")
	units, err := systemdFs.ReadDir("systemd")
	if err != nil {
		return err
	}

	_, err = session.ExecuteCommand("mkdir -p /opt/hub/systemd")
	if err != nil {
		return err
	}

	for _, file := range units {
		if file.IsDir() {
			continue
		}

		fileData, err := systemdFs.ReadFile(fmt.Sprintf("systemd/%s", file.Name()))
		if err != nil {
			return err
		}

		remotePath := fmt.Sprintf("/opt/hub/systemd/%s", file.Name())
		err = session.WriteDataToFile(fileData, remotePath)
		if err != nil {
			return err
		}

		linkPath := fmt.Sprintf("/etc/systemd/system/%s", file.Name())
		err = session.SymLink(remotePath, linkPath)
		if err != nil {
			return fmt.Errorf("failed to symlink script: %v", err)
		}
	}

	return nil
}

func loadSystemdUnits(session Session) error {
	log.Infoln("Enabling Systemd units...")
	units, err := systemdFs.ReadDir("systemd")
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

//go:embed docker
var dockerFs embed.FS

func syncDockerComposeFiles(session Session) error {
	log.Infoln("Syncing Docker compose files...")
	composeFiles, err := dockerFs.ReadDir("docker")
	if err != nil {
		return err
	}

	_, err = session.ExecuteCommand("mkdir -p /opt/hub/docker")
	if err != nil {
		return err
	}

	for _, file := range composeFiles {
		if file.IsDir() {
			continue
		}

		fileData, err := dockerFs.ReadFile(fmt.Sprintf("docker/%s", file.Name()))
		if err != nil {
			return err
		}

		remotePath := fmt.Sprintf("/opt/hub/docker/%s", file.Name())
		err = session.WriteDataToFile(fileData, remotePath)
		if err != nil {
			return err
		}
	}

	return nil
}
