package hub

import (
	"embed"
	_ "embed"
	"fmt"
	"log"
)

//go:embed scripts
var scriptsFs embed.FS

type Component struct {
	Name    string   `toml:"name"`
	Enabled bool     `toml:"enabled"`
	Type    string   `toml:"type"`
	Scripts []string `toml:"scripts"`
}

func SetupComponents(session *Session, components []Component) error {
	for _, component := range components {
		if !component.Enabled {
			log.Printf("skipping component[%s]: disabled\n", component.Name)
			continue
		}

		err := setupComponent(session, component)
		if err != nil {
			return fmt.Errorf("failed to setup component[%s]: %v", component.Name, err)
		}
	}

	return nil
}

func setupComponent(session *Session, component Component) (err error) {
	var scripts []string
	for _, script := range component.Scripts {
		scriptData, err := scriptsFs.ReadFile(fmt.Sprintf("scripts/%s.sh", script))
		if err != nil {
			return fmt.Errorf("script file missing: %v", err)
		}

		path := fmt.Sprintf("/usr/bin/hub-%s", script)
		err = session.WriteScriptToFile(scriptData, path)
		if err != nil {
			return fmt.Errorf("failed to write script: %v", err)
		}

		scripts = append(scripts, path)
	}

	unitName := component.Name
	var unitData string
	switch component.Type {
	case "single-exec":
		unitData, err = oneShotUnit(fmt.Sprintf("Hub %s", unitName), "network-online.target", "multi-user.target", scripts)
		if err != nil {
			return fmt.Errorf("failed to create setup unit file: %v", err)
		}
	}

	unitName = fmt.Sprintf("hub-%s.service", unitName)
	err = session.WriteDataToFile([]byte(unitData), fmt.Sprintf("/etc/systemd/system/%s", unitName))
	if err != nil {
		return fmt.Errorf("failed to write setup unit file: %v", err)
	}

	err = addSystemdUnit(session, unitName)
	if err != nil {
		return fmt.Errorf("failed to enable script: %v", err)
	}

	return nil
}
