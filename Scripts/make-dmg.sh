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

# Notice d'installation, visible dès l'ouverture du disque : sans elle, l'utilisateur tombe
# sur le refus de Gatekeeper et son bouton « Déplacer vers la corbeille », sans savoir que
# la marche à suivre passe par les Réglages système.
cp "$ROOT/Scripts/dmg-readme.txt" "$STAGING/⚠️ LISEZ-MOI — À LIRE EN PREMIER.txt"

hdiutil create \
	-volname "CopyDraft $VERSION" \
	-srcfolder "$STAGING" \
	-ov -format UDZO \
	"$DMG" >/dev/null

rm -rf "$STAGING"

SIZE="$(du -h "$DMG" | cut -f1)"
echo "✓ $DMG ($SIZE)"
echo
echo "Ce paquet n'est pas notarise. Au premier lancement, macOS refuse d'ouvrir l'application"
echo "et propose de la mettre a la corbeille : il faut passer par Reglages Systeme >"
echo "Confidentialite et securite > Ouvrir quand meme. La notice LISEZ-MOI incluse dans le"
echo "disque detaille toute la procedure."
