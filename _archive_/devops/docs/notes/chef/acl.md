# Chef ACL


## Enable

Add to `/etc/opscode/chef-server.rb`.
```
opscode_erchef['strict_search_result_acls'] = true
```

And `chef-server-ctl reconfigure`.


## Usage

### Revoke global search for all nodes

Revoke access for new nodes
```
knife acl remove group clients containers nodes read
```

Revoke access for exists nodes
```
knife acl bulk remove group clients nodes '.*' read
```
