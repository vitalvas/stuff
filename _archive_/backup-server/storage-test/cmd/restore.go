package cmd

import (
	"log"
	"os"

	"github.com/cheggaaa/pb/v3"
	"github.com/urfave/cli/v2"
	"github.com/vitalvas/backup-server/storage-test/storage"
)

func newRestoreCommand() *cli.Command {
	return &cli.Command{
		Name: "restore",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:     "block-id",
				Usage:    "block id",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "output-file",
				Required: true,
			},
		},
		Action: func(c *cli.Context) error {
			store := storage.New(storage.StorageConfig{
				Path: c.String("storage-path"),
			})

			block := store.GetBlock(c.String("block-id"))

			file, err := os.Create(c.String("output-file"))
			if err != nil {
				log.Fatal(err)
			}

			defer file.Close()

			bar := pb.Full.Start64(int64(block.Size))

			defer bar.Finish()

			for _, blob := range block.Blobs {
				data := store.GetChunk(blob.ID)

				bar.Add64(int64(blob.Length))

				if _, err := file.WriteAt(data, int64(blob.Offset)); err != nil {
					log.Fatal(err)
				}
			}

			return nil
		},
	}
}
