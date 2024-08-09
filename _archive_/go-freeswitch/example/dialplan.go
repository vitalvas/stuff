package main

import "freeswitch/fsapi"

func dialplan(doc fsapi.Document) fsapi.Document {
	section := fsapi.Section{Name: "dialplan", Description: "ok :)"}

	context := fsapi.Context{Name: "default"}

	extension := fsapi.Extension{Name: "test9"}

	condition := fsapi.Condition{Field: "destination_number", Expression: "^83789$"}

	condition.Action = append(condition.Action, fsapi.Action{
		Application: "bridge",
		Data:        "iax/guest@conference.freeswitch.org/888",
	})

	extension.Condition = append(extension.Condition, condition)

	context.Extension = append(context.Extension, extension)

	section.Context = append(section.Context, context)

	doc.Section = append(doc.Section, section)

	return doc
}
