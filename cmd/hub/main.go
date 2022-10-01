package main

import (
	"fmt"
	"os"

	"hub"

	"github.com/mitchellh/go-homedir"
	"github.com/urfave/cli/v2"
)

var log = hub.Logger()

func main() {
	hd, err := homedir.Dir()
	if err != nil {
		log.Fatalln(fmt.Errorf("failed to get home-dir: %v", err))
	}

	var config hub.Config
	var session *hub.Session

	app := cli.App{
		Name:  "hub",
		Usage: "Hub",
		Commands: []*cli.Command{
			{
				Name:  "sync",
				Usage: "Sync hub components",
				Action: func(context *cli.Context) error {
					return hub.SyncUnits(config, session)
				},
			},
			{
				Name:  "show",
				Usage: "Show info",
				Subcommands: []*cli.Command{
					{
						Name:  "config",
						Usage: "Show hub config",
						Action: func(context *cli.Context) error {
							fmt.Println(config)
							return nil
						},
					},
				},
			},

			{
				Name:  "create",
				Usage: "Create resource",
				Subcommands: []*cli.Command{
					{
						Name:  "config",
						Usage: "Create hub config",
						Action: func(context *cli.Context) error {
							config := hub.Config{
								Path:   fmt.Sprintf("%s/.config/hub.toml", hd),
								AppDir: "/var/lib/hub",
								Connection: hub.Connection{
									Addr:   "127.0.0.1",
									Port:   1022,
									User:   "root",
									Passwd: "password",
								},
								Network: hub.Network{
									Gateway: hub.Gateway{
										EnableHost: true,
										Mullvad: hub.Mullvad{
											Account:         "example",
											DefaultLocation: "es-mad",
											OtherLocations:  []string{"se-sto"},
										},
									},
									WireguardListenPort:      51820,
									WireGuardNetwork:         "10.10.1.0/24",
									DockerHostGatewayNetwork: "10.10.2.0/24",
									DockerVPNGatewayNetwork:  "10.10.3.0/24",
									DNS:                      "10.10.2.2",
								},
								SFTPStorages: []hub.SFTPStorage{
									{
										LocalMountPath: "/hub",
										Name:           "hub",
										Host:           "https://host.com",
										User:           "user",
										Password:       "passwd",
										CryptPassword1: "cryptpasswd1",
										CryptPassword2: "cryptpasswd2",
									},
								},
							}
							return hub.SaveConfig(config)
						},
					},
				},
			},
		},
		Flags: []cli.Flag{
			&cli.PathFlag{
				Name:      "config",
				Usage:     "Hub configuration file",
				Value:     fmt.Sprintf("%s/.config/hub.toml", hd),
				TakesFile: true,
			},
		},
		EnableBashCompletion: true,
		Before: func(context *cli.Context) error {
			cfpath := context.String("config")
			config, err = hub.LoadConfig(cfpath)
			if err != nil {
				return fmt.Errorf("failed to read config file: %v", err)
			}

			session, err = hub.OpenSession(config.Connection)
			if err != nil {
				return fmt.Errorf("failed to open remote session: %v", err)
			}

			return nil
		},
		Suggest: true,
	}

	err = app.Run(os.Args)
	if err != nil {
		log.Fatalln(err)
	}
}
