package main

import (
	"fmt"
	"os"

	"github.com/sirupsen/logrus"
	"github.com/urfave/cli/v2"
)

var log = logrus.New()

func main() {
	var hub Remote
	var config Config
	var err error

	app := cli.App{
		Name:  "hub",
		Usage: "Hub",
		Commands: []*cli.Command{
			{
				Name:  "sync",
				Usage: "Sync components",
				Flags: []cli.Flag{
					&cli.BoolFlag{
						Name:  "init",
						Usage: "Initialize components",
						Value: false,
					},
				},
				Subcommands: []*cli.Command{
					{
						Name:  "hub",
						Usage: "Sync hub components",
						Action: func(context *cli.Context) error {
							err := SyncHub(hub, context.Bool("init"))
							if err != nil {
								return fmt.Errorf("failed to sync components: %v", err)
							}

							return nil
						},
					},
					{
						Name:  "gateway",
						Usage: "Sync gateway components",
						Action: func(context *cli.Context) error {
							gateway, err := ConnectToRemote(config.Gateway)
							if err != nil {
								return fmt.Errorf("failed to connect to gateway: %v", err)
							}
							defer gateway.Close()

							err = SyncGateway(gateway)
							if err != nil {
								return fmt.Errorf("failed to sync components: %v", err)
							}

							return nil
						},
					},
				},
			},

			{
				Name:  "reboot",
				Usage: "Reboot services",
				Subcommands: []*cli.Command{
					{
						Name:        "hub",
						Description: "Reboot of hub",
						Action: func(context *cli.Context) error {
							_, err = hub.ExecuteCommand("reboot")
							return err
						},
					},
					{
						Name:        "gateway",
						Description: "Reboot of gateway",
						Action: func(context *cli.Context) error {
							gateway, err := ConnectToRemote(config.Gateway)
							if err != nil {
								return fmt.Errorf("failed to connect to gateway: %v", err)
							}
							defer gateway.Close()
							_, err = gateway.ExecuteCommand("reboot")
							return err
						},
					},
				},
			},

			{
				Name:  "show",
				Usage: "Show hub info",
				Subcommands: []*cli.Command{
					{
						Name:        "logs",
						Aliases:     []string{"l"},
						Description: "Show hub service(s) logs.",
						Flags: []cli.Flag{
							&cli.StringFlag{
								Name:    "service",
								Value:   "*",
								Aliases: []string{"s"},
							},
						},
						Action: func(context *cli.Context) error {
							return ShowLogs(hub, context.String("service"))
						},
					},
					{
						Name:        "status",
						Aliases:     []string{"l"},
						Description: "Show hub status.",
						Action: func(context *cli.Context) error {
							return Status(hub)
						},
					},
				},
			},

			{
				Name:  "restart",
				Usage: "Restart hub services",
				Flags: []cli.Flag{
					&cli.StringSliceFlag{
						Name:     "service",
						Aliases:  []string{"s"},
						Required: true,
					},
				},
				Action: func(context *cli.Context) error {
					return RestartServices(hub, context.StringSlice("service")...)
				},
			},

			{
				Name:  "mail",
				Usage: "Mailserver services",
				Action: func(context *cli.Context) error {
					return ExecMail(hub, context.Args().Slice()...)
				},
			},

			{
				Name:  "wireguard",
				Usage: "Wireguard services",
				Action: func(context *cli.Context) error {
					args := context.Args()
					return AddWireguardPeer(hub, args.Get(0), args.Get(1))
				},
			},

			{
				Name:  "shell",
				Usage: "Open shell to Hub",
				Flags: []cli.Flag{&cli.StringFlag{
					Name:    "shell",
					Aliases: []string{"s"},
					Value:   "zsh",
				}},
				Action: func(context *cli.Context) error {
					log.Infof("Opening a shell...")
					return hub.OpenShell(context.String("shell"))
				},
			},
		},
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:    "verbose",
				Aliases: []string{"v"},
				Value:   false,
			},
		},
		EnableBashCompletion: true,
		Before: func(context *cli.Context) error {
			verbose := context.Bool("verbose")
			if verbose {
				log.Infof("Logging debug info...")
				log.SetLevel(logrus.DebugLevel)
			}

			log.Println("Initiating SSH Connection...")
			config, err = LoadConfig()
			if err != nil {
				return err
			}

			hub, err = ConnectToRemote(config.Hub)
			if err != nil {
				return fmt.Errorf("failed to connect to hub: %v", err)
			}

			log.Println("Connected.")
			return nil
		},
		After: func(context *cli.Context) error {
			log.Println("Closing SSH Connection...")
			hub.Close()
			log.Println("Closed.")
			return nil
		},
		Suggest: true,
	}

	err = app.Run(os.Args)
	if err != nil {
		log.Fatalln(err)
	}
}
