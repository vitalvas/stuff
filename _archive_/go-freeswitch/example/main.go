package main

import (
	"encoding/xml"
	"fmt"
	"freeswitch/fsapi"
	"strings"
)

// Example from https://freeswitch.org/confluence/display/FREESWITCH/mod_xml_curl

func main() {
	doc := fsapi.Document{Type: "freeswitch/xml"}

	// os.Stdout.Write([]byte(xml.Header))

	print("dialplan", dialplan(doc))
	print("configuration", configuration(doc))
	print("domain", domain(doc))
	print("notFound", notFound(doc))
	print("post_load_switch", post_load_switch(doc))

}

func print(name string, value fsapi.Document) {
	var nline []string
	for i := 0; i < 15; i++ {
		nline = append(nline, "-")
	}
	line := strings.Join(nline, "")

	output, err := xml.MarshalIndent(value, "", "  ")
	if err != nil {
		fmt.Printf("error: %v\n", err)
	}

	fmt.Printf("%s %s %s\n%s\n", line, name, line, string(output))
}
