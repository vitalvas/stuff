package storage

import (
	"log"

	"github.com/restic/chunker"
	"github.com/zeebo/blake3"
)

type Storage struct {
	discard bool
	path    string
	pol     chunker.Pol
	chunks  map[string]bool
}

type StorageConfig struct {
	Discard bool
	Path    string
}

func New(conf StorageConfig) *Storage {
	storage := &Storage{
		discard: conf.Discard,
		path:    conf.Path,
		chunks:  make(map[string]bool),
	}

	if !storage.discard {
		storage.InitStorageTree()
	}

	var err error

	chunkerPolHash := blake3.NewDeriveKey("backup-server/storage-test")
	storage.pol, err = chunker.DerivePolynomial(chunkerPolHash.Digest())
	if err != nil {
		log.Fatal(err)
	}

	return storage
}
