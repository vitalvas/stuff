package storage

import (
	"time"

	"github.com/rs/xid"
)

type Block struct {
	ID        string
	Blobs     []Blob
	Size      uint64
	CheckSum  string
	Timestamp int64
}

type Blob struct {
	ID     string
	Offset uint
	Length uint
}

func NewBlock() *Block {
	return &Block{
		ID:        xid.New().String(),
		Timestamp: time.Now().UTC().Unix(),
	}
}

func (block *Block) WriteBlob(blob Blob) {
	block.Blobs = append(block.Blobs, blob)
}
