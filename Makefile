.PHONY: build build-all test

build:
	./scripts/build.sh

build-all:
	./scripts/build.sh --all

test: build
	CGO_ENABLED=0 go test ./...
	nvim --headless -u tests/minimal_init.lua -l tests/run.lua
