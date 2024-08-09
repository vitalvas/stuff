package tool

import (
	"encoding/xml"
	"log"
)

func XmlToByte(value ...interface{}) []byte {
	output, err := xml.MarshalIndent(value, "", "  ")
	if err != nil {
		log.Fatal(err)
	}
	output = append(output, '\n')
	return output
}
