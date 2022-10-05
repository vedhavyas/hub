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
				Action: func(context *cli.Context) error {
					err := SyncStaticFiles(session)
					if err != nil {
						return fmt.Errorf("failed to sync components: %v", err)
					}

					return nil
				},
			},

			{
				Name:  "init",
				Usage: "Initiate hub",
				Action: func(context *cli.Context) error {
					err := SyncStaticFiles(session)
					if err != nil {
						return fmt.Errorf("failed to sync components: %v", err)
					}

					return InitHub(session)
				},
			},

			{
				Name:  "status",
				Usage: "Status of hub",
				Action: func(context *cli.Context) error {
					return Status(session)
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
								Name:    "services",
								Value:   "*",
								Aliases: []string{"s"},
							},
						},
						Action: func(context *cli.Context) error {
							return ShowLogs(session, context.String("services"))
						},
					},
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
