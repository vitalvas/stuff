package main

import "freeswitch/fsapi"

func post_load_switch(doc fsapi.Document) fsapi.Document {
	section := fsapi.Section{Name: "configuration"}

	config := fsapi.Configuration{Name: "post_load_switch.conf", Description: "Core Configuration"}

	config.Params = append(config.Params, fsapi.Param{Name: "sessions-per-second", Value: "3000"})

	section.Configuration = append(section.Configuration, config)

	doc.Section = append(doc.Section, section)

	return doc
}
