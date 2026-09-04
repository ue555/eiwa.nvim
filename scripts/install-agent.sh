#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
system=$(uname -s)
machine=$(uname -m)

case "$system" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *)
    echo "Unsupported operating system: $system" >&2
    exit 1
    ;;
esac

case "$machine" in
  x86_64|amd64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *)
    echo "Unsupported architecture: $machine" >&2
    exit 1
    ;;
esac

name="eiwa-agent-$os-$arch"
target="$root/bin/$name"
url="https://github.com/ue555/eiwa.nvim/releases/latest/download/$name"

mkdir -p "$root/bin"
if command -v curl >/dev/null 2>&1 && curl -fsSL "$url" -o "$target"; then
  chmod +x "$target"
  cp "$target" "$root/bin/eiwa-agent"
  echo "Installed $name from GitHub Releases"
  exit
fi

rm -f "$target"
if command -v go >/dev/null 2>&1; then
  echo "A release binary was not available; building with local Go"
  "$root/scripts/build.sh"
  exit
fi

echo "Unable to install $name: no release binary was available and Go was not found" >&2
exit 1
