package hub

import (
	"embed"
	_ "embed"
	"fmt"
)

//go:embed scripts
var scriptsFs embed.FS

func setupSingleExecScriptsUnit(session *Session, unitName string, scripts []string) (err error) {
	var scriptPaths []string
	for _, script := range scripts {
		scriptData, err := scriptsFs.ReadFile(fmt.Sprintf("scripts/%s", script))
		if err != nil {
			return fmt.Errorf("script file missing: %v", err)
		}

		path := fmt.Sprintf("/usr/bin/hub-%s", script)
		err = session.WriteScriptToFile(scriptData, path)
		if err != nil {
			return fmt.Errorf("failed to write script: %v", err)
		}

		scriptPaths = append(scriptPaths, path)
	}

	unitData, err := oneShotUnit(fmt.Sprintf("Hub %s", unitName), "network-online.target", "multi-user.target", scriptPaths)
	if err != nil {
		return fmt.Errorf("failed to create setup unit file: %v", err)
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

type scriptUnit struct {
	name    string
	scripts []string
}

func newSingleExecScriptsUnit(name string, scripts []string) Unit {
	return &scriptUnit{
		name:    name,
		scripts: scripts,
	}
}

func (s scriptUnit) Name() string {
	return s.name
}

func (s scriptUnit) Prepare(config Config, session *Session) error {
	return nil
}

func (s scriptUnit) Sync(config Config, session *Session) error {
	return setupSingleExecScriptsUnit(session, s.name, s.scripts)
}
