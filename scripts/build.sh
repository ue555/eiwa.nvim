#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=${VERSION:-dev}

build() {
  os=$1
  arch=$2
  output="$root/bin/eiwa-agent-$os-$arch"
  echo "Building $output"
  CGO_ENABLED=0 GOOS="$os" GOARCH="$arch" go build \
    -trimpath \
    -ldflags "-s -w -X main.version=$version" \
    -o "$output" \
    "$root/cmd/eiwa-agent"
}

if [ "${1:-}" = "--all" ]; then
  build linux amd64
  build linux arm64
  build darwin arm64
  exit
fi

os=$(go env GOOS)
arch=$(go env GOARCH)
build "$os" "$arch"
cp "$root/bin/eiwa-agent-$os-$arch" "$root/bin/eiwa-agent"
