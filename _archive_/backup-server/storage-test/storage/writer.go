package storage

import (
	"encoding/hex"
	"fmt"
	"io"
	"log"

	"github.com/dustin/go-humanize"
	"github.com/minio/highwayhash"
	"github.com/restic/chunker"
)

const (
	chunkerMinSize = 256 * (1 << 10) // 256 KB
)

func (storage *Storage) Writer(reader io.Reader) string {
	buf := make([]byte, 4*chunker.MaxSize)

	fileChunker := chunker.NewWithBoundaries(reader, storage.pol, chunkerMinSize, chunker.MaxSize)

	var writed uint
	var chunks uint
	var chunksWrited uint

	block := NewBlock()

	checksum, err := highwayhash.New(highwayhashKey)
	if err != nil {
		log.Fatal(err)
	}

	for {
		chunk, err := fileChunker.Next(buf)
		if err == io.EOF {
			break
		}

		if err != nil {
			log.Fatal(err)
		}

		isWrited, chunkID := storage.writeChunk(chunk.Data)

		if _, err := checksum.Write(chunk.Data); err != nil {
			log.Fatal(err)
		}

		block.WriteBlob(Blob{
			ID:     chunkID,
			Offset: chunk.Start,
			Length: chunk.Length,
		})

		block.Size += uint64(chunk.Length)

		chunks++

		if isWrited {
			chunksWrited++
			writed += chunk.Length
		}
	}

	block.CheckSum = hex.EncodeToString(checksum.Sum(nil))

	if err := storage.writeBlock(block); err != nil {
		log.Fatal(err)
	}

	return fmt.Sprintf(
		"size: %s, writed: %s, chunks: %d, chunks writed: %d\nBlock ID: %s\n",
		humanize.Bytes(block.Size), humanize.Bytes(uint64(writed)), chunks, chunksWrited,
		block.ID,
	)
}
