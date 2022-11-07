package main

import (
	"embed"
	"fmt"
	"regexp"
	"strings"

	"github.com/sirupsen/logrus"
)

func initHub(session Remote) error {
	remoteWriter := log.WithField("hub", "init").WriterLevel(logrus.DebugLevel)
	log.Infoln("Running init script...")
	err := session.StreamCmd("hub-script-init", remoteWriter)
	if err != nil {
		return err
	}

	log.Infoln("Installing dependencies...")
	err = session.StreamCmd("hub run-script deps", remoteWriter)
	if err != nil {
		return err
	}

	err = loadSystemdUnits(session)
	if err != nil {
		return err
	}

	return nil
}

func Status(remote Remote) error {
	return remote.RunCmdToLog("hub status")
}

func Network(remote Remote) error {
	return remote.RunCmdToLog("wg")
}

func ShowLogs(remote Remote, service string) error {
	return remote.StreamCmd(fmt.Sprintf(`journalctl -u 'hub-%s' -f`, service), log.Writer())
}

func RestartServices(session Remote, services ...string) error {
	for _, service := range services {
		log.Infof("Restarting %s service...", service)
		err := session.RunCmdToLog(fmt.Sprintf(`systemctl restart 'hub-services@%s.service'`, service))
		if err != nil {
			return err
		}
	}

	return nil
}

func SyncHub(remote Remote, init bool) error {
	err := cleanStaticFiles(remote)
	if err != nil {
		return fmt.Errorf("failed to clean static files: %v", err)
	}

	err = syncStaticFiles(remote)
	if err != nil {
		return fmt.Errorf("failed to sync static files: %v", err)
	}

	// give execute permissions for scripts
	res, err := remote.RunCmd("chmod +x /opt/hub/scripts/*")
	if err != nil {
		return fmt.Errorf("failed to give exec permissions[%s]: %v", string(res), err)
	}

	// create symlinks for scripts
	err = createSymLinks(remote, "scripts", "/sbin/hub-script-%s")
	if err != nil {
		return fmt.Errorf("failed to create symlinks for scripts: %v", err)
	}

	// copy systemd unit files
	_, err = remote.RunCmd("cp /opt/hub/systemd/hub-* /etc/systemd/system/")
	if err != nil {
		return fmt.Errorf("failed to create sym links for systemd unit files: %v", err)
	}

	// sync env file
	err = syncEnvFile(remote)
	if err != nil {
		return fmt.Errorf("failed to sync .env file: %v", err)
	}

	if init {
		return initHub(remote)
	}

	err = loadSystemdUnits(remote)
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

		if !strings.HasPrefix(file.Name(), "hub-") {
			continue
		}

		unitNames = append(unitNames, file.Name())
	}

	res, err := session.RunCmd("systemctl daemon-reload")
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	res, err = session.RunCmd(fmt.Sprintf("systemctl reenable %s", strings.Join(unitNames, " ")))
	if err != nil {
		return fmt.Errorf("%v(%v)", string(res), err)
	}

	services, err := fetchDockerServices()
	if err != nil {
		return fmt.Errorf("failed to fetch docker services: %v", err)
	}

	for _, service := range services {
		res, err = session.RunCmd(fmt.Sprintf("systemctl reenable hub-services@%s.service", service))
		if err != nil {
			return fmt.Errorf("%v(%v)", string(res), err)
		}
	}

	return nil
}

func syncEnvFile(remote Remote) error {
	log.Infoln("Syncing .env file...")
	_, err := remote.RunCmd("mkdir -p /etc/hub")
	if err != nil {
		return err
	}

	return remote.WriteDataToFile([]byte(remote.connection.EnvVars()), "/etc/hub/.env")
}

//go:embed conf scripts docker systemd
var staticFS embed.FS

func fetchDockerServices() ([]string, error) {
	entries, err := staticFS.ReadDir("docker")
	if err != nil {
		return nil, err
	}

	re := regexp.MustCompile("docker-compose-(?P<name>.*)\\.yml")
	var services []string
	for _, dockerService := range entries {
		matches := re.FindStringSubmatch(dockerService.Name())
		idx := re.SubexpIndex("name")
		services = append(services, matches[idx])
	}

	return services, nil
}

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

		_, err = session.RunCmd(fmt.Sprintf("mkdir -p /opt/hub/%s", dir.Name()))
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
	res, err := remote.RunCmd("rm -rf /opt/hub/*")
	if err != nil {
		return fmt.Errorf("%v: %s", err, res)
	}

	// remove copied systemd files
	res, err = remote.RunCmd("rm -rf /etc/systemd/system/hub-*")
	if err != nil {
		return fmt.Errorf("%v: %s", err, res)
	}

	return nil
}

func ExecMail(hub Remote, args ...string) error {
	return hub.RunCmdToLog(fmt.Sprintf("docker exec mailserver setup %s", strings.Join(args, " ")))
}

func AddWireguardPeer(hub Remote, name, gateway string) error {
	return hub.RunCmdToLog(fmt.Sprintf("hub wireguard %s %s", name, gateway))
}

func RestartDockerContainers(hub Remote, containers []string) error {
	return hub.RunCmdToLog(fmt.Sprintf("docker restart %s", strings.Join(containers, " ")))
}
