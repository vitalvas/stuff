package storage

import (
	"encoding/json"
	"fmt"
	"os"
	"path"

	"github.com/klauspost/compress/s2"
)

func (storage *Storage) writeBlock(block *Block) error {
	data, err := json.Marshal(block)
	if err != nil {
		return err
	}

	dst := s2.EncodeBest(nil, data)

	if err := os.MkdirAll(path.Join(storage.path, "blocks", block.ID[0:4]), 0755); err != nil {
		return err
	}

	filePath := path.Join(storage.path, "blocks", block.ID[0:4], fmt.Sprintf("%s.dat", block.ID))

	if err := os.WriteFile(filePath, dst, 0640); err != nil {
		return err
	}

	return nil
}
