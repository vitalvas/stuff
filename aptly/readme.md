# Aptly Stuff

## Repo Maker

### Example

Example config:

* repo `infra`
* os `ubuntu`
* release `jammy`
* config file `/opt/aptly/repos/infra/ubuntu/jammy/aptly.conf`

```json
{
  "rootDir": "/opt/aptly/repos/infra/ubuntu/jammy/data",
  "gpgDisableSign": true,
  "skipLegacyPool": true,
  "FileSystemPublishEndpoints": {
    "main": {
      "rootDir": "/srv/www/repo-test.vitalvas.dev/public",
      "linkMethod": "copy",
      "verifyMethod": "md5"
    }
  }
}
```

```bash
echo "deb [trusted=yes] https://your-server/infra/ubuntu/jammy/ jammy main" > /etc/apt/sources.list.d/infra.list
```
