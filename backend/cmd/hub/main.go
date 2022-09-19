package main

import (
	"fmt"
	logger "log"
	"os"

	"github.com/mitchellh/go-homedir"
	"github.com/urfave/cli/v2"
	hub "github.com/vedhavyas/hub/backend"
)

var log = logger.New(os.Stderr, "[hub] ", logger.Lmsgprefix)

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
					err = hub.SetupComponents(session, config.Components)
					if err != nil {
						return fmt.Errorf("failed to sync components: %v", err)
					}
					return nil
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

			session, err = hub.OpenSession(config.Remote)
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
