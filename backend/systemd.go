package hub

import (
	_ "embed"
	"fmt"
	"strings"
	"text/template"
)

type UnitFileConfig struct {
	Name       string
	After      string
	Type       string
	ExecStarts []string
	WantedBy   string
}

//go:embed templates/systemd-unit.goservice
var systemdUnitTemplate string
var tmpl, _ = template.New("systemd-unit-file").Parse(systemdUnitTemplate)

func oneShotUnit(name, after, wantedBy string, starts []string) (string, error) {
	config := UnitFileConfig{
		Name:       name,
		After:      after,
		Type:       "oneshot",
		ExecStarts: starts,
		WantedBy:   wantedBy,
	}

	var buf strings.Builder
	err := tmpl.Execute(&buf, config)
	if err != nil {
		return "", fmt.Errorf("failed create template: %v", err)
	}

	return buf.String(), nil
}

func addSystemdUnit(session *Session, unitName string) error {
	err := systemdReload(session)
	if err != nil {
		return err
	}

	return enableSystemdUnit(session, unitName)
}

func systemdReload(session *Session) error {
	res, err := session.ExecuteCommand("systemctl daemon-reload")
	if err != nil {
		return fmt.Errorf("failed to reload systemd: %v(%v)", string(res), err)
	}

	return nil
}

func enableSystemdUnit(session *Session, unitName string) error {
	res, err := session.ExecuteCommand(fmt.Sprintf("systemctl reenable %s", unitName))
	if err != nil {
		return fmt.Errorf("failed to reload systemd unit: %v(%v)", string(res), err)
	}

	return nil
}

func restartSystemdUnit(session *Session, unitName string) error {
	res, err := session.ExecuteCommand(fmt.Sprintf("systemctl restart %s", unitName))
	if err != nil {
		return fmt.Errorf("failed to restart systemd unit: %v(%v)", string(res), err)
	}

	return nil
}
