#!/bin/bash
set -euo pipefail

MORI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MORI_VERSION="${MORI_VERSION:-0.1.2}"
MORI_SHA="${MORI_SHA:-development}"
MORI_OUTPUT="${MORI_OUTPUT:-$MORI_ROOT/build}"
MORI_SCRATCH="${MORI_SCRATCH:-$MORI_ROOT/.build/release-packaging}"
MORI_UNIVERSAL="${MORI_UNIVERSAL:-1}"
MORI_APP="$MORI_OUTPUT/Mori.app"

cd "$MORI_ROOT"
if ! command -v npm >/dev/null; then
  echo "请先安装 Node.js 20+，让 node 与 npm 出现在 PATH 中。" >&2
  exit 1
fi
if [ ! -d Web/node_modules ]; then (cd Web && npm ci --no-audit --no-fund); fi
(cd Web && npm run check && npm run build)

mkdir -p "$MORI_OUTPUT" "$MORI_SCRATCH"
swift build -c release --triple arm64-apple-macosx14.0 --scratch-path "$MORI_SCRATCH/arm64"
MORI_ARM_BIN="$(swift build -c release --triple arm64-apple-macosx14.0 --scratch-path "$MORI_SCRATCH/arm64" --show-bin-path)"

if [ "$MORI_UNIVERSAL" = 1 ]; then
  swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path "$MORI_SCRATCH/x86_64"
  MORI_INTEL_BIN="$(swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path "$MORI_SCRATCH/x86_64" --show-bin-path)"
fi

rm -rf "$MORI_APP"
mkdir -p "$MORI_APP/Contents/MacOS" "$MORI_APP/Contents/Resources"
if [ "$MORI_UNIVERSAL" = 1 ]; then
  lipo -create "$MORI_ARM_BIN/Mori" "$MORI_INTEL_BIN/Mori" -output "$MORI_APP/Contents/MacOS/Mori"
else
  cp "$MORI_ARM_BIN/Mori" "$MORI_APP/Contents/MacOS/Mori"
fi
cp -R "$MORI_ARM_BIN/Mori_Mori.bundle" "$MORI_APP/Contents/Resources/"
cp assets/Info.plist "$MORI_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MORI_VERSION" "$MORI_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :MoriCommit string $MORI_SHA" "$MORI_APP/Contents/Info.plist"

MORI_ICONSET="$MORI_SCRATCH/AppIcon.iconset"
mkdir -p "$MORI_ICONSET"
for MORI_SIZE in 16 32 128 256 512; do
  sips -z "$MORI_SIZE" "$MORI_SIZE" assets/AppIcon.png --out "$MORI_ICONSET/icon_${MORI_SIZE}x${MORI_SIZE}.png" >/dev/null
  MORI_DOUBLE=$((MORI_SIZE * 2))
  sips -z "$MORI_DOUBLE" "$MORI_DOUBLE" assets/AppIcon.png --out "$MORI_ICONSET/icon_${MORI_SIZE}x${MORI_SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$MORI_ICONSET" -o "$MORI_APP/Contents/Resources/AppIcon.icns"
cp THIRD_PARTY_NOTICES.md "$MORI_APP/Contents/Resources/"
if [ -n "${MORI_SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$MORI_SIGN_IDENTITY" "$MORI_APP"
else
  codesign --force --timestamp=none --sign - "$MORI_APP"
fi
codesign --verify --deep --strict "$MORI_APP"
plutil -lint "$MORI_APP/Contents/Info.plist"
lipo -archs "$MORI_APP/Contents/MacOS/Mori"
echo "Mori 应用已生成：$MORI_APP"
