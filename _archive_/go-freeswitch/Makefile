all: build

build:
	GOOS=linux GOARCH=amd64 go build --ldflags '-extldflags "-static" -s -w' -o out/backend_linux_amd64 backend/*.go
	goupx out/backend_linux_amd64
