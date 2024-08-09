package main

import (
	"crypto/rand"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/vitalvas/go-freeswitch/backend/tool"
	"github.com/vitalvas/go-freeswitch/fsapi"
)

var dstNumber = "1009"

func Dialplan(w http.ResponseWriter, r *http.Request) {
	// if r.FormValue("Caller-Destination-Number") == "1009" {
	doc := fsapi.Document{Type: "freeswitch/xml"}
	section := fsapi.Section{Name: "dialplan"}
	context := fsapi.Context{Name: r.FormValue("Caller-Context")}
	extension := fsapi.Extension{
		Name: fmt.Sprintf("%s_%s", r.FormValue("Caller-Caller-ID-Number"), r.FormValue("Caller-Destination-Number")),
	}
	condition := fsapi.Condition{
		Field:      "destination_number",
		Expression: "^(" + r.FormValue("Caller-Destination-Number") + ")$",
	}

	uniqId := make([]byte, 8)
	if n, err := io.ReadFull(rand.Reader, uniqId); n != len(uniqId) || err != nil {
		panic(err)
	}

	t := time.Now()
	recordPath := []string{
		"$${recordings_dir}",
		r.FormValue("FreeSWITCH-Switchname"),
		fmt.Sprintf("%02d", t.Year()),
		fmt.Sprintf("%02d", t.Month()),
		fmt.Sprintf("%02d", t.Day()),
		fmt.Sprintf("%02d", t.Hour()),
		fmt.Sprintf("%02d", t.Minute()),
		fmt.Sprintf("%s.wav", fmt.Sprintf("%x", uniqId)),
	}
	recordPathFull := strings.Join(recordPath, "/")

	condition.Action = append(condition.Action, fsapi.Action{Application: "record_session", Data: recordPathFull})
	condition.Action = append(condition.Action, fsapi.Action{Application: "set", Data: "call_timeout=30"})
	condition.Action = append(condition.Action, fsapi.Action{Application: "set", Data: "hangup_after_bridge=true"})
	condition.Action = append(condition.Action, fsapi.Action{Application: "set", Data: "continue_on_fail=true"})
	condition.Action = append(condition.Action, fsapi.Action{
		Application: "log",
		Data: fmt.Sprintf(
			"Call record %s - %s: %s",
			r.FormValue("Caller-Caller-ID-Number"),
			r.FormValue("Caller-Destination-Number"),
			recordPathFull,
		),
	})
	condition.Action = append(condition.Action, fsapi.Action{
		Application: "bridge",
		Data:        fmt.Sprintf("user/%s@${domain_name}", dstNumber)},
	)
	condition.Action = append(condition.Action, fsapi.Action{Application: "answer"})
	condition.Action = append(condition.Action, fsapi.Action{Application: "sleep", Data: "1000"})
	condition.Action = append(condition.Action, fsapi.Action{
		Application: "bridge",
		Data:        fmt.Sprintf("loopback/app=voicemail:default ${domain_name} %s", dstNumber),
	})

	extension.Condition = append(extension.Condition, condition)
	context.Extension = append(context.Extension, extension)
	section.Context = append(section.Context, context)
	doc.Section = append(doc.Section, section)
	w.Write(tool.XmlToByte(doc))
	// } else {
	// 	NotFound(w, r)
	// }

}
