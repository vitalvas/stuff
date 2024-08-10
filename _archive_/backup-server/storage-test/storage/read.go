package storage

import (
	"log"
	"os"

	"github.com/klauspost/compress/s2"
)

func (storage *Storage) GetChunk(id string) []byte {
	filePath := storage.getStoragePath(id)

	data, err := os.ReadFile(filePath)
	if err != nil {
		log.Fatal(err)
	}

	dst, err := s2.Decode(nil, data)
	if err != nil {
		log.Fatal(err)
	}

	return dst
}
