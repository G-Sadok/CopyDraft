#!/usr/bin/env bash
#
# Signe, notarise et empaquette CopyDraft pour distribution hors App Store (S-9.3).
#
# Prérequis :
#   - un certificat « Developer ID Application » dans le Trousseau ;
#   - un profil de notarisation enregistré une fois pour toutes :
#       xcrun notarytool store-credentials copydraft \
#           --apple-id <identifiant> --team-id <équipe> --password <mot de passe d'application>
#
# Usage :
#   CODESIGN_IDENTITY="Developer ID Application: Nom (TEAMID)" \
#   NOTARY_PROFILE="copydraft" \
#   ./Scripts/sign-notarize.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/CopyDraft.app"
DMG="$ROOT/dist/CopyDraft.dmg"
STAGING="$ROOT/dist/dmg-staging"

: "${CODESIGN_IDENTITY:?Définissez CODESIGN_IDENTITY (Developer ID Application)}"
: "${NOTARY_PROFILE:?Définissez NOTARY_PROFILE (profil notarytool)}"

echo "▸ Build release universel…"
"$ROOT/Scripts/build-app.sh" release

echo "▸ Signature Developer ID…"
# Les bibliothèques et bundles embarqués se signent avant l'exécutable qui les contient.
find "$APP/Contents" -name "*.dylib" -o -name "*.framework" | while read -r item; do
	codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$item"
done
codesign --force --options runtime --timestamp \
	--entitlements "$ROOT/Scripts/CopyDraft.entitlements" \
	--sign "$CODESIGN_IDENTITY" "$APP"

echo "▸ Vérification de la signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "▸ Fabrication du .dmg…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "CopyDraft" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "▸ Signature du .dmg…"
codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG"

echo "▸ Notarisation (peut prendre quelques minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Agrafage du ticket…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "▸ Contrôle Gatekeeper…"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo "✓ $DMG prêt à distribuer"
