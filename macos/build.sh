#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/ModuleCache 'build/Zendo Desktop.app/Contents/MacOS' 'build/Zendo Desktop.app/Contents/Resources'
desktop_arch="$(uname -m)"
xcrun swiftc -target "${desktop_arch}-apple-macos13.0" -module-cache-path "$PWD/build/ModuleCache" \
  -framework Cocoa -framework WebKit -framework AuthenticationServices \
  Sources/DesktopConfiguration.swift Sources/main.swift \
  -o 'build/Zendo Desktop.app/Contents/MacOS/ZendoDesktop'
cp Info.plist 'build/Zendo Desktop.app/Contents/Info.plist'
plutil -lint 'build/Zendo Desktop.app/Contents/Info.plist'
codesign --force --sign - 'build/Zendo Desktop.app'
printf '\nBuilt: %s/build/Zendo Desktop.app\n' "$PWD"
