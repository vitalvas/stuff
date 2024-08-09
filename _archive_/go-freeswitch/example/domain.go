package main

import (
	"crypto/md5"
	"fmt"
	"freeswitch/fsapi"
)

func domain(doc fsapi.Document) fsapi.Document {
	section := fsapi.Section{Name: "directory"}

	domain := fsapi.Domain{Name: "domain1.awesomevoipdomain.faketld"}

	domain.Params = append(domain.Params, fsapi.Param{
		Name:  "dial-string",
		Value: "{presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(${dialed_user}@${dialed_domain})}",
	})

	groups := fsapi.Groups{Name: "default"}

	user := fsapi.User{Id: "1004", Cacheable: 600}

	user_pass := fsapi.Param{Name: "password", Value: "some_password"}
	user.Params = append(user.Params, user_pass)

	pass := []byte(fmt.Sprintf("%s:%s:%s", user.Id, domain.Name, user_pass.Value))
	hashed_pass := fmt.Sprintf("%x", md5.Sum(pass))

	user.Params = append(user.Params, fsapi.Param{
		Name:  "a1-hash",
		Value: hashed_pass,
	})

	groups.Users = append(groups.Users, user)

	domain.Groups = append(domain.Groups, groups)

	section.Domain = append(section.Domain, domain)

	doc.Section = append(doc.Section, section)

	return doc
}
