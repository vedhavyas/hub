package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/urfave/cli/v2"
)

func main() {
	app := cli.App{
		Name:  "certbot",
		Usage: "Certbot",
		Commands: []*cli.Command{
			{
				Name:        "issue",
				Aliases:     []string{"i"},
				Usage:       "certbot issue adminEmail domains",
				Description: "Issue certificate to domains.",
				Action: func(context *cli.Context) error {
					args := context.Args()
					email, domains := args.Get(0), splitDomains(args.Get(1))
					if email == "" || len(domains) < 1 {
						return fmt.Errorf("email or domains is empty")
					}

					for _, domain := range domains {
						log.Printf("Issusing certificate for %s...", domain)
						err := issueCertDomain(domain, email)
						if err != nil {
							log.Print(err)
						}
					}

					return nil
				},
			},
		},
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatalln(err)
	}
}

func splitDomains(domains string) []string {
	return strings.Split(domains, ",")
}

func issueCertDomain(domain, adminEmail string) error {
	cmd := exec.Command(
		"certbot",
		"certonly",
		"--standalone",
		"-d", domain,
		"-m", adminEmail,
		"--non-interactive",
		"--agree-tos")

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
