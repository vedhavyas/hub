package main

import (
	"fmt"

	"github.com/sirupsen/logrus"
)

func SyncGateway(gateway Remote, init bool) error {
	log.Infof("Syncing %s files...\n", gateway.connection.Name)
	fileData, err := staticFS.ReadFile("scripts/gateway_exit_node.sh")
	if err != nil {
		return err
	}

	err = gateway.WriteScriptToFile(fileData, "/usr/sbin/gateway")
	if err != nil {
		return err
	}

	fileData, err = staticFS.ReadFile("systemd/gateway_exit_node.service")
	if err != nil {
		return err
	}

	err = gateway.WriteDataToFile(fileData, "/etc/systemd/system/gateway.service")
	if err != nil {
		return err
	}

	res, err := gateway.RunCmd("systemctl daemon-reload")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	res, err = gateway.RunCmd("systemctl reenable gateway.service")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	_, err = gateway.RunCmd("mkdir -p /etc/default")
	if err != nil {
		return err
	}

	err = gateway.WriteDataToFile([]byte(gateway.connection.EnvVars()), "/etc/default/gateway.env")
	if err != nil {
		return err
	}

	log.Infof("Done.")

	if !init {
		return nil
	}

	return initGateway(gateway)
}

func initGateway(gateway Remote) error {
	log.Info("Running init script...")
	fileData, err := staticFS.ReadFile("scripts/init.sh")
	if err != nil {
		return err
	}

	err = gateway.WriteScriptToFile(fileData, "/usr/sbin/gateway-init")
	if err != nil {
		return err
	}

	remoteWriter := log.WithField("gateway", "init").WriterLevel(logrus.DebugLevel)
	err = gateway.StreamCmd("gateway-init", remoteWriter)
	if err != nil {
		return err
	}

	log.Info("Done.")
	return nil
}
