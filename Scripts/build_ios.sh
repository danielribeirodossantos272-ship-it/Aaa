#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild não encontrado. Este script precisa ser executado em macOS com Xcode." >&2
  exit 2
fi
xcodebuild -project FLEXReplica.xcodeproj -target FLEXReplicaDemo -sdk iphonesimulator -configuration Debug build
xcodebuild -project FLEXReplica.xcodeproj -target FLEXReplicaTests -sdk iphonesimulator -configuration Debug test
