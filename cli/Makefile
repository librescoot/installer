BINARY := librescoot-install
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS := -ldflags "-w -s -X main.version=$(VERSION)"
BUILD_DIR := bin

.PHONY: build build-host clean

build: build-host

build-host:
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY) .

build-linux-amd64:
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-linux-amd64 .

build-linux-arm:
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-linux-arm .

deploy: build-linux-amd64
	scp $(BUILD_DIR)/$(BINARY)-linux-amd64 teal@100.111.179.114:/tmp/$(BINARY)
	ssh teal@100.111.179.114 "chmod +x /tmp/$(BINARY)"

clean:
	rm -rf $(BUILD_DIR)
