#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/RelayWatch.app"
CONTENTS="$APP/Contents"
MACOS_DIR="$CONTENTS/MacOS"
ARCH="$(uname -m)"

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
  echo "Desteklenmeyen Mac mimarisi: $ARCH"
  exit 1
fi

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple geliştirici araçları bulunamadı."
  echo "Önce şu komutu çalıştır: xcode-select --install"
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS_DIR"

echo "RelayWatch uygulaması hazırlanıyor…"
xcrun --sdk macosx swiftc \
  -parse-as-library \
  -O \
  -target "$ARCH-apple-macos13.0" \
  -o "$MACOS_DIR/RelayWatch" \
  "$ROOT/Sources/RelayWatchApp.swift" \
  -framework SwiftUI \
  -framework AppKit

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
codesign --force --deep --sign - "$APP"

echo ""
echo "Hazır: $APP"
echo "Uygulama şimdi açılıyor."
open "$APP"
