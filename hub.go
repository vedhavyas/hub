package main

import (
	"embed"
	"fmt"
	"strings"

	"github.com/sirupsen/logrus"
)

func initHub(session Remote) error {
	remoteWriter := log.WithField("remote", "init").WriterLevel(logrus.DebugLevel)
	log.Infoln("Running init script...")
	err := session.ExecuteCommandStream("hub-script-init", remoteWriter)
	if err != nil {
		return err
	}

	log.Infoln("Installing dependencies...")
	err = session.ExecuteCommandStream("hub run-script deps", remoteWriter)
	if err != nil {
		return err
	}

	err = loadSystemdUnits(session)
	if err != nil {
		return err
	}

	return nil
}

func Status(session Remote) error {
	remoteWriter := log.WithField("remote", "status").WriterLevel(logrus.InfoLevel)
	err := session.ExecuteCommandStream(`
systemctl list-unit-files 'hub-*' docker.service
systemctl list-units 'hub-*' docker.service
docker compose ls`, remoteWriter)
	if err != nil {
		return err
	}

	return nil
}

func ShowLogs(session Remote, service string) error {
	remoteWriter := log.WithField("remote", "logs").WriterLevel(logrus.InfoLevel)
	err := session.ExecuteCommandStream(fmt.Sprintf(`journalctl -u 'hub-%s' -f`, service), remoteWriter)
	if err != nil {
		return err
	}

	return nil
}

func RestartServices(session Remote, services ...string) error {
	remoteWriter := log.WithField("remote", "restart").WriterLevel(logrus.InfoLevel)
	for _, service := range services {
		log.Infof("Restarting %s service...", service)
		err := session.ExecuteCommandStream(fmt.Sprintf(`systemctl restart 'hub-services@%s.service'`, service), remoteWriter)
		if err != nil {
			return err
		}
	}

	return nil
}

func SyncStaticFiles(session Remote, init bool) error {
	err := cleanStaticFiles(session)
	if err != nil {
		return fmt.Errorf("failed to clean static files: %v", err)
	}

	err = syncStaticFiles(session)
	if err != nil {
		return fmt.Errorf("failed to sync static files: %v", err)
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

	if init {
		return initHub(session)
	}

	err = loadSystemdUnits(session)
	if err != nil {
		return fmt.Errorf("failed to load systemd units: %v", err)
	}

	return nil
}

func createSymLinks(session Remote, dir, linkPathTmpl string) error {
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

func loadSystemdUnits(session Remote) error {
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

		if strings.Contains(file.Name(), "@") {
			continue
		}

		unitNames = append(unitNames, file.Name())
	}

	res, err := session.ExecuteCommand("systemctl daemon-reload")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	res, err = session.ExecuteCommand(fmt.Sprintf("systemctl reenable %s", strings.Join(unitNames, " ")))
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	services := []string{
		"security", "comms", "maintenance", "monitoring", "entertainment", "utilities", "mailserver", "nextcloud"}
	for _, service := range services {
		res, err = session.ExecuteCommand(fmt.Sprintf("systemctl reenable hub-services@%s.service", service))
		if err != nil {
			return fmt.Errorf("%v(%v)", string(res), err)
		}
	}

	dailyScripts := []string{"backup", "certbot"}
	for _, script := range dailyScripts {
		res, err = session.ExecuteCommand(fmt.Sprintf("systemctl reenable hub-script@%s.service", script))
		if err != nil {
			return fmt.Errorf("%v(%v)", string(res), err)
		}

		res, err = session.ExecuteCommand(fmt.Sprintf("systemctl reenable hub-daily@%s.timer", script))
		if err != nil {
			return fmt.Errorf("%v(%v)", string(res), err)
		}
	}

	res, err = session.ExecuteCommand("systemctl restart 'hub-*.timer'")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	return nil
}

func syncEnvFile(session Remote) error {
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

func syncStaticFiles(session Remote) error {
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

func cleanStaticFiles(remote Remote) (err error) {
	defer func() {
		if err == nil {
			return
		}

		if strings.Contains(err.Error(), "no matches found") {
			log.Debugf("static files doesn't exist")
			err = nil
		}
	}()

	// remove /opt/hub
	res, err := remote.ExecuteCommand("rm -rf /opt/hub/*")
	if err != nil {
		return fmt.Errorf("%v: %s", err, res)
	}

	// remove copied systemd files
	res, err = remote.ExecuteCommand("rm -rf /etc/systemd/system/hub-*")
	if err != nil {
		return fmt.Errorf("%v: %s", err, res)
	}

	return nil
}

func ExecMail(remote Remote, args ...string) error {
	remoteWriter := log.WithField("remote", "mail").WriterLevel(logrus.InfoLevel)
	return remote.ExecuteCommandStream(fmt.Sprintf("docker exec -it mailserver setup %s", strings.Join(args, " ")),
		remoteWriter)
}

func AddWireguardPeer(hub Remote, name, gateway string) error {
	remoteWriter := log.WithField("remote", "mail").WriterLevel(logrus.InfoLevel)
	return hub.ExecuteCommandStream(fmt.Sprintf("hub cmd wireguard %s %s", name, gateway), remoteWriter)
}
