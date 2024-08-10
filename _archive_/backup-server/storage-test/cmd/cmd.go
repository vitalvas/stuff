package cmd

import (
	"log"
	"os"

	"github.com/urfave/cli/v2"
)

func Execute() {
	cliApp := &cli.App{
		Name: "storage-test",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:  "storage-path",
				Value: "./test",
			},
		},
		Commands: []*cli.Command{
			newBackupCommand(),
			newRestoreCommand(),
		},
	}

	if err := cliApp.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
