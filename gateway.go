package main

import (
	"embed"
	"fmt"

	"github.com/sirupsen/logrus"
)

//go:embed libs/gateway
var gatewayFS embed.FS

func SyncGateway(gateway Remote, init bool) error {
	log.Infof("Syncing gateway files...\n")
	fileData, err := gatewayFS.ReadFile("libs/gateway/gateway.sh")
	if err != nil {
		return err
	}

	err = gateway.WriteDataToFile(fileData, "/usr/sbin/gateway")
	if err != nil {
		return err
	}

	// give execute permissions for gateway script
	res, err := gateway.ExecuteCommand("chmod +x /usr/sbin/gateway")
	if err != nil {
		return fmt.Errorf("failed to give exec permissions[%s]: %v", string(res), err)
	}

	fileData, err = gatewayFS.ReadFile("libs/gateway/gateway.service")
	if err != nil {
		return err
	}

	err = gateway.WriteDataToFile(fileData, "/etc/systemd/system/gateway.service")
	if err != nil {
		return err
	}

	res, err = gateway.ExecuteCommand("systemctl daemon-reload")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	res, err = gateway.ExecuteCommand("systemctl reenable gateway.service")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	_, err = gateway.ExecuteCommand("mkdir -p /etc/default")
	if err != nil {
		return err
	}

	err = gateway.WriteDataToFile([]byte(gateway.connection.EnvVars()), "/etc/default/gateway.env")
	if err != nil {
		return err
	}

	if !init {
		return nil
	}

	return initGateway(gateway)
}

func initGateway(gateway Remote) error {
	log.Info("Running init script...")
	remoteWriter := log.WithField("gateway", "init").WriterLevel(logrus.DebugLevel)
	err := gateway.ExecuteCommandStream("gateway", remoteWriter)
	if err != nil {
		return err
	}

	log.Info("Done.")
	return nil
}
