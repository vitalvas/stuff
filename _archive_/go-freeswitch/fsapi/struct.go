package fsapi

import "encoding/xml"

type Document struct {
	XMLName xml.Name  `xml:"document"`
	Type    string    `xml:"type,attr"`
	Section []Section `xml:"section"`
}

type Section struct {
	Name          string          `xml:"name,attr"`
	Description   string          `xml:"description,attr,omitempty"`
	Context       []Context       `xml:"context"`
	Configuration []Configuration `xml:"configuration"`
	Domain        []Domain        `xml:"domain"`
	Result        []Result        `xml:"result"`
}

type Context struct {
	Name      string      `xml:"name,attr,omitempty"`
	Extension []Extension `xml:"extension"`
}

type Configuration struct {
	Name        string  `xml:"name,attr"`
	Description string  `xml:"description,attr,omitempty"`
	Settings    string  `xml:"settings,omitempty"`
	Params      []Param `xml:"param"`
}

type Domain struct {
	Name   string   `xml:"name,attr"`
	Params []Param  `xml:"params,omitempty>param"`
	Groups []Groups `xml:"groups,omitempty>group"`
	User   []User   `xml:"user,omitempty"`
}

type Param struct {
	Name  string `xml:"name,attr"`
	Value string `xml:"value,attr"`
}

type Groups struct {
	Name  string `xml:"name,attr"`
	Users []User `xml:"users>user"`
}

type User struct {
	Id        string  `xml:"id,attr"`
	Cacheable uint    `xml:"cacheable,attr,omitempty"`
	Params    []Param `xml:"params>param,omitempty"`
}

type Extension struct {
	Name      string      `xml:"name,attr"`
	Continue  string      `xml:"continue,attr,omitempty"`
	Condition []Condition `xml:"condition"`
}

type Condition struct {
	Field      string   `xml:"field,attr"`
	Expression string   `xml:"expression,attr"`
	Break      string   `xml:"break,attr,omitempty"`
	Action     []Action `xml:"action"`
}

type Action struct {
	Application string `xml:"application,attr"`
	Data        string `xml:"data,attr,omitempty"`
}

type Result struct {
	Status string `xml:"status,attr"`
}
