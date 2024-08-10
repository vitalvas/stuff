# Drone plugin Artifactor


## Usage

```
publish-artifactor:
  image: jotcdn/drone-artifactor
  endpoint: http://artifactor-git.jotcdn.net
  files:
    - test.*.tgz
    - ./*.txt
```
