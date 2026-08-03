#!/usr/bin/env bash
#
# Crée une identité de signature locale et stable pour les builds de développement.
#
# Pourquoi : un bundle signé « ad hoc » change d'empreinte à chaque compilation. macOS
# considère alors qu'il s'agit d'une autre application et **révoque l'autorisation
# d'accessibilité** déjà accordée — la case peut rester cochée dans les Réglages système
# alors que l'application n'est plus reconnue. Avec une identité stable, l'autorisation
# survit aux recompilations.
#
# À exécuter une seule fois. Demande le mot de passe du Trousseau pour l'import.
#
#   ./Scripts/make-dev-identity.sh
#
# Puis rebâtir : ./Scripts/build-app.sh
# Il faudra accorder l'accessibilité une dernière fois, après quoi elle tiendra.

set -euo pipefail

NAME="${DEV_IDENTITY_NAME:-CopyDraft Dev}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
	echo "✓ Identité « $NAME » déjà présente"
	exit 0
fi

echo "▸ Génération du certificat auto-signé « $NAME »…"
cat > "$WORK/openssl.cnf" <<'CONF'
[ req ]
distinguished_name = dn
prompt = no
x509_extensions = ext

[ dn ]
CN = CopyDraft Dev

[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONF

# LibreSSL du système plutôt qu'un OpenSSL 3 de Homebrew : ce dernier chiffre les .p12 avec
# des algorithmes que le Trousseau refuse (« MAC verification failed during PKCS12 import »).
OPENSSL="/usr/bin/openssl"

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 \
	-keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/openssl.cnf" 2>/dev/null

"$OPENSSL" pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
	-out "$WORK/identity.p12" -passout pass:copydraft \
	-certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 2>/dev/null

echo "▸ Import dans le trousseau de session…"
security import "$WORK/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
	-P copydraft -T /usr/bin/codesign -A

# Sans cette étape, le certificat existe mais n'est pas une identité de signature valide
# (`security find-identity -v -p codesigning` ne le voit pas) et `codesign` ouvre un dialogue.
echo "▸ Déclaration du certificat comme racine de confiance (mot de passe demandé)…"
security add-trusted-cert -r trustRoot -p codeSign \
	-k "$HOME/Library/Keychains/login.keychain-db" "$WORK/cert.pem"

echo "▸ Vérification…"
if security find-identity -v -p codesigning | grep -q "$NAME"; then
	echo "✓ Identité « $NAME » prête. Rebâtissez avec ./Scripts/build-app.sh"
else
	echo "✗ L'identité n'est pas reconnue comme valide pour la signature." >&2
	echo "  Ouvrez « Trousseaux d'accès », cherchez « $NAME », double-cliquez," >&2
	echo "  dépliez « Confiance » et réglez « Signature de code » sur « Toujours approuver »." >&2
	exit 1
fi
