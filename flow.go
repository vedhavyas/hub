package hub

import "fmt"

func fetchUnits() []Unit {
	return []Unit{
		newSingleExecScriptsUnit("setup", []string{
			"auto-upgrades.sh",
			"install-docker.sh",
			"allow-ssh.sh",
		}),
	}
}

func SyncUnits(config Config, session *Session) error {
	units := fetchUnits()
	log.Infof("Preparing units...")
	for _, unit := range units {
		err := unit.Prepare(config, session)
		if err != nil {
			return fmt.Errorf("failed to prepare unit[%s]: %v", unit.Name(), err)
		}
	}

	log.Infof("Syncing units...")
	for _, unit := range units {
		err := unit.Sync(config, session)
		if err != nil {
			return fmt.Errorf("failed to sync unit[%s]: %v", unit.Name(), err)
		}
	}

	log.Infof("Done.")
	return nil
}
