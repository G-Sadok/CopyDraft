#!/usr/bin/env bash
#
# Assemble CopyDraft.app à partir du paquet Swift.
#
#   ./Scripts/build-app.sh            → build release universel (arm64 + x86_64)
#   ./Scripts/build-app.sh debug      → build debug, architecture native (itération rapide)
#
# Le bundle produit est signé ad hoc : suffisant pour un lancement local.
# La signature Developer ID et la notarisation sont traitées par sign-notarize.sh (S-9.3).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# SwiftPM des Command Line Tools seuls est inutilisable (PackageDescription désynchronisé) :
# on sélectionne une installation d'Xcode, sans exiger de `sudo xcode-select`.
if [ -z "${DEVELOPER_DIR:-}" ]; then
	for candidate in \
		"$(xcode-select -p 2>/dev/null || true)" \
		/Applications/Xcode.app/Contents/Developer \
		/Volumes/Apps/MACAPPS/Xcode.app/Contents/Developer; do
		if [ -n "$candidate" ] && [ -d "$candidate/Toolchains" ]; then
			export DEVELOPER_DIR="$candidate"
			break
		fi
	done
fi
if [ -z "${DEVELOPER_DIR:-}" ]; then
	echo "✗ Aucune installation d'Xcode trouvée. Définissez DEVELOPER_DIR." >&2
	exit 1
fi
echo "▸ Toolchain : $DEVELOPER_DIR"
CONFIGURATION="${1:-release}"
APP_NAME="CopyDraft"
APP="$ROOT/dist/$APP_NAME.app"

BUILD_FLAGS=(--package-path "$ROOT" -c "$CONFIGURATION")
if [ "$CONFIGURATION" = "release" ]; then
	BUILD_FLAGS+=(--arch arm64 --arch x86_64)
fi

echo "▸ Compilation ($CONFIGURATION)…"
swift build "${BUILD_FLAGS[@]}"
BIN_PATH="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

echo "▸ Assemblage du bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Scripts/Info.plist" "$APP/Contents/Info.plist"

# Bundles de ressources produits par SwiftPM (chaînes localisées, assets)
for bundle in "$BIN_PATH"/*.bundle; do
	[ -e "$bundle" ] || continue
	cp -R "$bundle" "$APP/Contents/Resources/"
done

# Icône d'application, générée d'après le design system §9 plutôt que versionnée en binaire.
echo "▸ Icône…"
ICONSET="$ROOT/dist/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$ROOT/Scripts/make-icon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Identité stable si elle existe (voir make-dev-identity.sh), signature ad hoc sinon.
# Une signature ad hoc change d'empreinte à chaque build : macOS révoque alors
# l'autorisation d'accessibilité déjà accordée, et l'onboarding réapparaît.
if security find-certificate -c "${DEV_IDENTITY_NAME:-CopyDraft Dev}" >/dev/null 2>&1; then
	echo "▸ Signature avec « ${DEV_IDENTITY_NAME:-CopyDraft Dev} »…"
	# Ni entitlements ni hardened runtime ici : l'entitlement de groupe de trousseau contient
	# le jeton $(AppIdentifierPrefix), que seul Xcode substitue, et launchd refuse de lancer
	# une application dont les entitlements ne sont pas résolus. Ces deux options sont le
	# propre du build de distribution (sign-notarize.sh).
	codesign --force --timestamp=none \
		--sign "${DEV_IDENTITY_NAME:-CopyDraft Dev}" "$APP" >/dev/null
else
	echo "▸ Signature ad hoc (autorisation d'accessibilité perdue à chaque build —"
	echo "  lancez ./Scripts/make-dev-identity.sh une fois pour y remédier)…"
	codesign --force --sign - --timestamp=none "$APP" >/dev/null
fi

echo "✓ $APP"
