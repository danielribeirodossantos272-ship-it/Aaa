#!/usr/bin/env bash
# Compila FLEXReplica.dylib (Core + painel + patches + overlay) com swiftc/clang.
# Uso:
#   ./Scripts/build_dylib.sh                           # dispositivo (arm64)
#   SDK=iphonesimulator ./Scripts/build_dylib.sh       # simulador (ARCH=arm64 ou x86_64)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun não encontrado. Este script precisa ser executado em macOS com Xcode." >&2
  exit 2
fi

SDK="${SDK:-iphoneos}"
ARCH="${ARCH:-arm64}"
MIN_IOS="${MIN_IOS:-16.0}"
case "$SDK" in
  iphoneos)        TARGET="${ARCH}-apple-ios${MIN_IOS}" ;;
  iphonesimulator) TARGET="${ARCH}-apple-ios${MIN_IOS}-simulator" ;;
  *) echo "SDK inválido: $SDK (use iphoneos ou iphonesimulator)" >&2; exit 2 ;;
esac

SDK_PATH="$(xcrun --sdk "$SDK" --show-sdk-path)"
OUT="$ROOT/build/dylib/$SDK"
mkdir -p "$OUT"

# 1) constructor (C)
xcrun --sdk "$SDK" clang -target "$TARGET" -isysroot "$SDK_PATH" -c Dylib/entry.c -o "$OUT/entry.o"

# 2) dylib: Core + painel + patches + bootstrap, tudo em um único módulo
xcrun --sdk "$SDK" swiftc \
  -emit-library -parse-as-library -swift-version 5 \
  -module-name FLEXReplica \
  -target "$TARGET" -sdk "$SDK_PATH" \
  Sources/FLEXReplicaCore/*.swift \
  Sources/FLEXReplicaDemo/FLEXReplicaPanel.swift \
  Sources/FLEXReplicaDemo/PatchesView.swift \
  Dylib/*.swift \
  "$OUT/entry.o" \
  -Xlinker -install_name -Xlinker @rpath/FLEXReplica.dylib \
  -o "$OUT/FLEXReplica.dylib"

# 3) assinatura ad-hoc (o Xcode reassina com a sua identidade ao embutir no app)
codesign -f -s - "$OUT/FLEXReplica.dylib"

echo "OK: $OUT/FLEXReplica.dylib"
