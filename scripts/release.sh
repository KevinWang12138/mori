#!/bin/bash
set -euo pipefail
MORI_VERSION="${1:?用法：scripts/release.sh 版本 完整SHA}"
MORI_SHA="${2:?请指定完整提交 SHA}"
MORI_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MORI_REPOSITORY="KevinWang12138/mori"
cd "$MORI_ROOT"

if ! [[ "$MORI_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$MORI_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "版本或 SHA 格式无效。" >&2; exit 1
fi
git fetch origin main
if [ "$(git rev-parse origin/main)" != "$MORI_SHA" ]; then
  echo "远端 main 已变化，请先审计并使用最新精确提交。" >&2; exit 1
fi
if gh release view "v$MORI_VERSION" --repo "$MORI_REPOSITORY" >/dev/null 2>&1; then
  echo "此版本已发布，请使用新版本号。" >&2; exit 1
fi

MORI_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mori-release.XXXXXX")"
trap 'rm -rf "$MORI_TEMP"' EXIT
mkdir -p "$MORI_TEMP/source" "$MORI_TEMP/artifacts"
git archive "$MORI_SHA" | tar -x -C "$MORI_TEMP/source"
(
  cd "$MORI_TEMP/source"
  export MORI_VERSION MORI_SHA
  export MORI_OUTPUT="$MORI_TEMP/artifacts"
  export MORI_SCRATCH="$MORI_TEMP/build-cache"
  scripts/build-app.sh
)
MORI_ZIP="Mori-$MORI_VERSION-universal.zip"
MORI_DMG="Mori-$MORI_VERSION-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$MORI_TEMP/artifacts/Mori.app" "$MORI_TEMP/artifacts/$MORI_ZIP"
if [ -n "${MORI_NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$MORI_TEMP/artifacts/$MORI_ZIP" --keychain-profile "$MORI_NOTARY_PROFILE" --wait
  xcrun stapler staple "$MORI_TEMP/artifacts/Mori.app"
  rm "$MORI_TEMP/artifacts/$MORI_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$MORI_TEMP/artifacts/Mori.app" "$MORI_TEMP/artifacts/$MORI_ZIP"
fi
mkdir "$MORI_TEMP/dmg"
cp -R "$MORI_TEMP/artifacts/Mori.app" "$MORI_TEMP/dmg/Mori.app"
ln -s /Applications "$MORI_TEMP/dmg/Applications"
hdiutil create -volname "Mori $MORI_VERSION" -srcfolder "$MORI_TEMP/dmg" -ov -format UDZO "$MORI_TEMP/artifacts/$MORI_DMG" >/dev/null
(
  cd "$MORI_TEMP/artifacts"
  shasum -a 256 "$MORI_ZIP" "$MORI_DMG" > SHA256SUMS.txt
)
git fetch origin main
if [ "$(git rev-parse origin/main)" != "$MORI_SHA" ]; then echo "构建期间 main 已更新，已停止发布旧提交。" >&2; exit 1; fi
gh release create "v$MORI_VERSION" "$MORI_TEMP/artifacts/$MORI_ZIP" "$MORI_TEMP/artifacts/$MORI_DMG" "$MORI_TEMP/artifacts/SHA256SUMS.txt" \
  --repo "$MORI_REPOSITORY" --target "$MORI_SHA" --title "Mori $MORI_VERSION · 为博客而写" --notes-file "$MORI_TEMP/source/docs/RELEASE_NOTES.md"
gh release view "v$MORI_VERSION" --repo "$MORI_REPOSITORY" --json url,tagName,assets
python3 "$MORI_TEMP/source/scripts/verify-release.py" "$MORI_VERSION" "$MORI_SHA" "$MORI_TEMP/artifacts" "$MORI_ROOT"
mkdir -p "$MORI_ROOT/build"
rm -rf "$MORI_ROOT/build/Mori.app"
cp -R "$MORI_TEMP/artifacts/Mori.app" "$MORI_ROOT/build/Mori.app"
echo "精确提交的应用已保留在 build/Mori.app，临时源码与发布产物将在退出时清理。"
