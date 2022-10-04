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
	var err error

	app := cli.App{
		Name:                 "hub",
		Usage:                "Hub",
		EnableBashCompletion: true,
		Suggest:              true,
		Before: func(context *cli.Context) error {
			log.Println("Initiating SSH Connection...")
			session, err = OpenSession()
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
		Commands: []*cli.Command{
			{
				Name:  "sync",
				Usage: "Sync hub components",
				Action: func(context *cli.Context) error {
					return syncScripts(session)
				},
			},
		},
	}

	err = app.Run(os.Args)
	if err != nil {
		log.Fatalln(err)
	}
}
