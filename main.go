package main

import (
	"fmt"
	"log"
	"os"

	"github.com/urfave/cli/v2"
)

func main() {
	var session *Session
	var err error

	app := cli.App{
		Name:                 "hub",
		Usage:                "Hub",
		EnableBashCompletion: true,
		Suggest:              true,
		Before: func(context *cli.Context) error {
			session, err = OpenSession()
			if err != nil {
				return fmt.Errorf("failed to open remote session: %v", err)
			}

			return nil
		},
		Commands: []*cli.Command{
			{
				Name:  "sync",
				Usage: "Sync hub components",
				Action: func(context *cli.Context) error {
					out, err := session.ExecuteCommand("uname -a")
					if err != nil {
						return err
					}

					fmt.Println(string(out))
					return nil
				},
			},
		},
	}

	err = app.Run(os.Args)
	if err != nil {
		log.Fatalln(err)
	}
}
