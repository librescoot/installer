BINARY := librescoot-install
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS := -ldflags "-w -s -X main.version=$(VERSION)"
BUILD_DIR := bin

FLASHER_BIN := assets/librescoot-flasher-linux-arm

.PHONY: build build-host clean flasher

build: build-host

flasher: $(FLASHER_BIN)

$(FLASHER_BIN):
	@echo "Fetching librescoot-flasher (pinned in assets/FLASHER_VERSION)"
	./scripts/update-flasher.sh

build-host: $(FLASHER_BIN)
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY) .

build-linux-amd64: $(FLASHER_BIN)
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-linux-amd64 .

build-linux-arm: $(FLASHER_BIN)
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-linux-arm .

build-linux-arm64: $(FLASHER_BIN)
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-linux-arm64 .

build-darwin-amd64: $(FLASHER_BIN)
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-darwin-amd64 .

build-darwin-arm64: $(FLASHER_BIN)
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-darwin-arm64 .

build-windows-amd64: $(FLASHER_BIN)
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY)-windows-amd64.exe .

build-all: build-linux-amd64 build-linux-arm build-linux-arm64 build-darwin-amd64 build-darwin-arm64 build-windows-amd64

deploy: build-linux-amd64
	scp $(BUILD_DIR)/$(BINARY)-linux-amd64 teal@100.111.179.114:/tmp/$(BINARY)
	ssh teal@100.111.179.114 "chmod +x /tmp/$(BINARY)"

clean:
	rm -rf $(BUILD_DIR)
