package main

import (
	"net/http"

	"github.com/vitalvas/go-freeswitch/backend/tool"
	"github.com/vitalvas/go-freeswitch/fsapi"
)

func NotFound(w http.ResponseWriter, r *http.Request) {
	doc := fsapi.Document{Type: "freeswitch/xml"}
	section := fsapi.Section{Name: "result"}
	section.Result = append(section.Result, fsapi.Result{
		Status: "not found",
	})

	doc.Section = append(doc.Section, section)
	w.Write(tool.XmlToByte(doc))
}
