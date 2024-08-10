package storage

import (
	"fmt"
	"log"
	"os"
	"path"
)

func (storage *Storage) InitStorageTree() {
	if _, err := os.Stat(storage.path); !os.IsNotExist(err) {
		return
	}

	log.Println("init storage tree")

	if err := os.Mkdir(storage.path, 0755); err != nil {
		log.Fatal(err)
	}

	if err := os.Mkdir(path.Join(storage.path, "blocks"), 0755); err != nil {
		log.Fatal(err)
	}

	if err := os.Mkdir(path.Join(storage.path, ".chunks"), 0755); err != nil {
		log.Fatal(err)
	}

	for x := 0; x <= 255; x++ {
		name := fmt.Sprintf(".chunks/%02x", x)

		if err := os.Mkdir(path.Join(storage.path, name), 0755); err != nil {
			log.Fatal(err)
		}

		for y := 0; y <= 255; y++ {
			childName := fmt.Sprintf("%s/%02x", name, y)

			if err := os.Mkdir(path.Join(storage.path, childName), 0755); err != nil {
				log.Fatal(err)
			}
		}
	}

	log.Println("end init storage tree")
}
