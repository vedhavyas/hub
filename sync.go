package main

import (
	"embed"
	"fmt"
	"strings"
)

//go:embed scripts
var scriptsFs embed.FS

func syncScripts(session Session) error {
	log.Infoln("Syncing scripts...")
	scripts, err := scriptsFs.ReadDir("scripts")
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

		fileData, err := scriptsFs.ReadFile(fmt.Sprintf("scripts/%s", file.Name()))
		if err != nil {
			return err
		}

		remotePath := fmt.Sprintf("/opt/hub/scripts/%s", file.Name())
		err = session.WriteScriptToFile(fileData, remotePath)
		if err != nil {
			return err
		}

		binaryPath := fmt.Sprintf("/sbin/hub-script-%s", strings.TrimSuffix(file.Name(), ".sh"))
		err = session.SymLink(remotePath, binaryPath)
		if err != nil {
			return fmt.Errorf("failed to symlink script: %v", err)
		}
	}

	return nil
}
