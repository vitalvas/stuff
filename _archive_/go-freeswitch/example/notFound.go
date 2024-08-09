package main

import "freeswitch/fsapi"

func notFound(doc fsapi.Document) fsapi.Document {
	section := fsapi.Section{Name: "result"}

	section.Result = append(section.Result, fsapi.Result{
		Status: "not found",
	})

	doc.Section = append(doc.Section, section)

	return doc
}
