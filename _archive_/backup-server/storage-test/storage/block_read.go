package storage

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path"

	"github.com/klauspost/compress/s2"
)

func (storage *Storage) GetBlock(id string) (block *Block) {
	filePath := path.Join(storage.path, "blocks", id[0:4], fmt.Sprintf("%s.dat", id))

	data, err := os.ReadFile(filePath)
	if err != nil {
		log.Fatal(err)
	}

	dst, err := s2.Decode(nil, data)
	if err != nil {
		log.Fatal(err)
	}

	if err := json.Unmarshal(dst, &block); err != nil {
		log.Fatal(err)
	}

	return
}
