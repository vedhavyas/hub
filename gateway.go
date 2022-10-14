package main

import (
	"embed"
	"fmt"
)

//go:embed libs/gateway
var gatewayFS embed.FS

func SyncGateway(gateway Remote) error {
	log.Infof("Syncing gateway files...\n")
	fileData, err := gatewayFS.ReadFile("libs/gateway/gateway.sh")
	if err != nil {
		return err
	}

	err = gateway.WriteDataToFile(fileData, "/usr/sbin/gateway")
	if err != nil {
		return err
	}

	fileData, err = gatewayFS.ReadFile("libs/gateway/gateway.service")
	if err != nil {
		return err
	}

	err = gateway.WriteDataToFile(fileData, "/etc/systemd/system/gateway.service")
	if err != nil {
		return err
	}

	res, err := gateway.ExecuteCommand("systemctl daemon-reload")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	res, err = gateway.ExecuteCommand("systemctl reenable gateway.service")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	return err
}
