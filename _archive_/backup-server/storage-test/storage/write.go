package storage

import (
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"path"

	"github.com/klauspost/compress/s2"
	"github.com/minio/highwayhash"
)

var highwayhashKey = []byte{
	0xbc, 0x81, 0xd3, 0x01, 0x58, 0x91, 0x4b, 0xb9,
	0x2b, 0x44, 0x8b, 0x32, 0xc9, 0x35, 0xea, 0xd7,
	0x52, 0x33, 0x72, 0x7c, 0x20, 0xe1, 0xc1, 0x4f,
	0xdf, 0xbe, 0xba, 0x04, 0x6b, 0x0e, 0x89, 0x48,
}

func (storage *Storage) writeChunk(data []byte) (bool, string) {
	checksum := hash(data)

	if _, ok := storage.chunks[checksum]; ok {
		return false, checksum
	}

	if storage.discard {
		storage.chunks[checksum] = true
		return true, checksum
	}

	filePath := storage.getStoragePath(checksum)

	if _, err := os.Stat(filePath); !os.IsNotExist(err) {
		storage.chunks[checksum] = true
		return false, checksum
	}

	dst := s2.Encode(nil, data)

	if err := os.WriteFile(filePath, dst, 0640); err != nil {
		log.Fatal(err)
	}

	storage.chunks[checksum] = true

	return true, checksum
}

func hash(data []byte) string {
	hashData := highwayhash.Sum(data, highwayhashKey)
	return hex.EncodeToString(hashData[:])
}

func (storage *Storage) getStoragePath(checksum string) string {
	return path.Join(storage.path, ".chunks", checksum[0:2], checksum[2:4], fmt.Sprintf("%s.blob", checksum))
}
