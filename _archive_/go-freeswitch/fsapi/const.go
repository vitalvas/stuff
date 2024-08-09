package fsapi

var NotFound = Document{
	Type:    "freeswitch/xml",
	Section: []Section{{Name: "result", Result: []Result{{Status: "not found"}}}},
}
