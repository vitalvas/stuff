package main

import "freeswitch/fsapi"

func configuration(doc fsapi.Document) fsapi.Document {
	section := fsapi.Section{Name: "configuration"}

	config := fsapi.Configuration{Name: "SECTIONNAME.conf", Description: "SECTIONDESCRIPTION"}

	section.Configuration = append(section.Configuration, config)

	doc.Section = append(doc.Section, section)

	return doc
}
