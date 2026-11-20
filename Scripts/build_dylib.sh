#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
  echo "swift e xcrun não encontrados. Este script requer macOS com Xcode." >&2
  exit 2
fi

build_dylib() {
  local variant="$1"
  local sdk_name="$2"
  local triple="$3"
  local sdk_path scratch_path dylib_path
  sdk_path="$(xcrun --sdk "$sdk_name" --show-sdk-path)"
  scratch_path="$ROOT/.build/dylib-$variant"

  swift build --package-path "$ROOT" --product FLEXReplicaCore \
    --configuration release --triple "$triple" --sdk "$sdk_path" \
    --scratch-path "$scratch_path"

  dylib_path="$(find "$scratch_path" -type f -name 'libFLEXReplicaCore.dylib' -print -quit)"
  if [[ -z "$dylib_path" ]]; then
    echo "A compilação de $variant não produziu libFLEXReplicaCore.dylib." >&2
    exit 1
  fi

  mkdir -p "$ROOT/dist/$variant"
  cp "$dylib_path" "$ROOT/dist/$variant/libFLEXReplicaCore.dylib"
  cp "$ROOT/include/FLEXReplicaCore.h" "$ROOT/dist/$variant/FLEXReplicaCore.h"
  local symbols
  symbols="$(xcrun nm -gU "$ROOT/dist/$variant/libFLEXReplicaCore.dylib")"
  if ! grep -q 'FLEXReplicaShowMenu$' <<<"$symbols"; then
    echo "O símbolo FLEXReplicaShowMenu não foi exportado em $variant." >&2
    exit 1
  fi
  if ! grep -q 'FLEXReplicaInstallFloatingButton$' <<<"$symbols"; then
    echo "O símbolo FLEXReplicaInstallFloatingButton não foi exportado em $variant." >&2
    exit 1
  fi
  if ! grep -q 'FLEXReplicaAutoOpenEnsureLinked$' <<<"$symbols"; then
    echo "O inicializador automático não foi ligado em $variant." >&2
    exit 1
  fi
  if ! grep -q 'FLEXReplicaCopyRuntimeClassNames$' <<<"$symbols"; then
    echo "A ponte Objective-C do runtime não foi ligada em $variant." >&2
    exit 1
  fi
  if ! grep -q 'FLEXReplicaTryGetObjectValue$' <<<"$symbols"; then
    echo "A leitura segura de propriedades não foi ligada em $variant." >&2
    exit 1
  fi
  if ! grep -q 'FLEXReplicaTrySetObjectValue$' <<<"$symbols"; then
    echo "A escrita segura de propriedades não foi ligada em $variant." >&2
    exit 1
  fi
  echo "Entrypoints do painel/botão, autostart e ponte runtime ligados em $variant."
  file "$ROOT/dist/$variant/libFLEXReplicaCore.dylib"
}

build_dylib "ios-device-arm64" "iphoneos" "arm64-apple-ios16.0"
build_dylib "ios-simulator-arm64" "iphonesimulator" "arm64-apple-ios16.0-simulator"
