#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/ModuleCache
xcrun swiftc -module-cache-path "$PWD/build/ModuleCache" Sources/DesktopConfiguration.swift Tests/main.swift -o build/configuration-tests
build/configuration-tests
