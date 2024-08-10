package cmd

import (
	"errors"
	"io"
	"log"
	"os"

	"github.com/cheggaaa/pb/v3"
	"github.com/urfave/cli/v2"
	"github.com/vitalvas/backup-server/storage-test/storage"
)

func newBackupCommand() *cli.Command {
	return &cli.Command{
		Name: "backup",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:  "file",
				Usage: "path to file",
			},
			&cli.BoolFlag{
				Name:  "stdin",
				Value: false,
				Usage: "read file from stdin",
			},
			&cli.BoolFlag{
				Name:  "discard",
				Value: false,
				Usage: "dont write blob to filesystem",
			},
		},
		Action: func(c *cli.Context) error {
			var reader io.Reader
			var size int64

			if c.Bool("stdin") {
				reader = os.Stdin

			} else if len(c.String("file")) > 0 {
				file, err := os.Open(c.String("file"))
				if err != nil {
					return err
				}

				defer file.Close()

				info, err := file.Stat()
				if err != nil {
					return err
				}

				size = info.Size()
				reader = file

			} else {
				return errors.New("no incoming data")
			}

			store := storage.New(storage.StorageConfig{
				Discard: c.Bool("discard"),
				Path:    c.String("storage-path"),
			})

			bar := pb.Full.Start64(size)
			barReader := bar.NewProxyReader(reader)

			stats := store.Writer(barReader)

			bar.Finish()

			log.Print(stats)

			return nil
		},
	}
}
