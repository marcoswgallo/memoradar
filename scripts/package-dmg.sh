#!/bin/bash
# Gera dist/MemoRadar-<versão>.dmg, com o app e um atalho para a pasta Aplicativos.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/package-app.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DMG="dist/MemoRadar-$VERSION.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp -R dist/MemoRadar.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -quiet -volname "MemoRadar" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
hdiutil verify -quiet "$DMG"
echo "Gerado: $DMG"
