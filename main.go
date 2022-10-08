package main

import (
	"fmt"
	"os"

	"github.com/sirupsen/logrus"
	"github.com/urfave/cli/v2"
)

var log = logrus.New()

func main() {
	var session Session
	var config Config
	var err error

	app := cli.App{
		Name:  "hub",
		Usage: "Hub",
		Commands: []*cli.Command{
			{
				Name:  "sync",
				Usage: "Sync hub components",
				Flags: []cli.Flag{
					&cli.BoolFlag{
						Name:  "init",
						Usage: "Initialize hub.",
						Value: false,
					},
				},
				Action: func(context *cli.Context) error {
					err := SyncStaticFiles(session, context.Bool("init"))
					if err != nil {
						return fmt.Errorf("failed to sync components: %v", err)
					}

					return nil
				},
			},

			{
				Name:  "reboot",
				Usage: "Reboot of hub",
				Action: func(context *cli.Context) error {
					_, err = session.ExecuteCommand("reboot")
					return err
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
							return ShowLogs(session, context.String("service"))
						},
					},
					{
						Name:        "status",
						Aliases:     []string{"l"},
						Description: "Show hub status.",
						Action: func(context *cli.Context) error {
							return Status(session)
						},
					},
				},
			},

			{
				Name:  "restart",
				Usage: "Restart hub services",
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:     "service",
						Aliases:  []string{"s"},
						Required: true,
					},
				},
				Action: func(context *cli.Context) error {
					return RestartServices(session, context.String("service"))
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

			session, err = OpenSession(config.Conn)
			if err != nil {
				return fmt.Errorf("failed to open remote session: %v", err)
			}

			log.Println("Connected.")
			return nil
		},
		After: func(context *cli.Context) error {
			log.Println("Closing SSH Connection...")
			session.Close()
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
