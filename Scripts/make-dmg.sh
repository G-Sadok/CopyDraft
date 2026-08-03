#!/usr/bin/env bash
#
# Fabrique un .dmg distribuable à partir du build local.
#
# Ce paquet n'est **pas notarisé** : il est signé avec l'identité locale de développement,
# donc Gatekeeper le bloquera au premier lancement chez un tiers, qui devra passer par
# « Ouvrir quand même ». Pour une diffusion large, préférer Scripts/sign-notarize.sh avec un
# certificat Developer ID.
#
#   ./Scripts/make-dmg.sh [version]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$ROOT/Scripts/Info.plist")}"
APP="$ROOT/dist/CopyDraft.app"
DMG="$ROOT/dist/CopyDraft-$VERSION.dmg"
STAGING="$ROOT/dist/dmg-staging"

echo "▸ Build release…"
"$ROOT/Scripts/build-app.sh" release >/dev/null

echo "▸ Assemblage du disque…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
# Raccourci vers Applications : le glisser-déposer attendu sur macOS.
ln -s /Applications "$STAGING/Applications"

hdiutil create \
	-volname "CopyDraft $VERSION" \
	-srcfolder "$STAGING" \
	-ov -format UDZO \
	"$DMG" >/dev/null

rm -rf "$STAGING"

SIZE="$(du -h "$DMG" | cut -f1)"
echo "✓ $DMG ($SIZE)"
echo
echo "Ce paquet n'est pas notarisé : au premier lancement, l'utilisateur doit faire un clic"
echo "droit sur CopyDraft puis « Ouvrir », et confirmer. Voir la section Installation du README."
