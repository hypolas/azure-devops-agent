#!/bin/bash
# Script pour télécharger un binaire depuis GitHub selon la plateforme
# Usage: ./download-github-binary.sh <owner/repo> <binary-name> [tag]

set -e

GITHUB_REPO=${1:-""}
BINARY_NAME=${2:-""}
TAG=${3:-"latest"}

if [ -z "$GITHUB_REPO" ] || [ -z "$BINARY_NAME" ]; then
    echo "Usage: $0 <owner/repo> <binary-name> [tag]"
    echo "Exemple: $0 cli/cli gh latest"
    exit 1
fi

# Détecter l'architecture
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo "Détection: OS=$OS, Architecture=$ARCH"

# Mapper les architectures
case "$ARCH" in
    amd64|x86_64) GITHUB_ARCH="x86_64" ;;
    arm64|aarch64) GITHUB_ARCH="aarch64" ;;
    armhf|armv7l) GITHUB_ARCH="armv7" ;;
    arm*) GITHUB_ARCH="arm" ;;
    *) echo "⚠️ Architecture non standard détectée: $ARCH" && GITHUB_ARCH="$ARCH" ;;
esac

# Récupérer les informations de release
if [ "$TAG" = "latest" ]; then
    RELEASE_URL="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
    TAG=$(curl -s "$RELEASE_URL" | jq -r .tag_name)
else
    RELEASE_URL="https://api.github.com/repos/$GITHUB_REPO/releases/tags/$TAG"
fi

echo "📦 Récupération de la release $TAG..."

# Récupérer la liste des assets
ASSETS=$(curl -s "$RELEASE_URL" | jq -r '.assets[].browser_download_url')

if [ -z "$ASSETS" ]; then
    echo "❌ Aucun asset trouvé pour la release $TAG"
    exit 1
fi

echo "🔍 Assets disponibles:"
echo "$ASSETS"

# Patterns de recherche possibles (du plus spécifique au plus général)
PATTERNS=(
    "${BINARY_NAME}-${OS}-${GITHUB_ARCH}"
    "${BINARY_NAME}-${OS}-${ARCH}"
    "${BINARY_NAME}_${OS}_${GITHUB_ARCH}"
    "${BINARY_NAME}_${OS}_${ARCH}"
    "${OS}-${GITHUB_ARCH}"
    "${OS}_${GITHUB_ARCH}"
    "${GITHUB_ARCH}"
    "${ARCH}"
)

FOUND_URL=""
for pattern in "${PATTERNS[@]}"; do
    echo "🔍 Recherche du pattern: $pattern"
    # Recherche en ignorant les fichiers .sha256
    FOUND_URL=$(echo "$ASSETS" | grep -v '\.sha256$' | grep -i "$pattern" | head -1 || true)
    if [ -n "$FOUND_URL" ]; then
        echo "✅ Trouvé avec le pattern: $pattern"
        break
    fi
done

if [ -z "$FOUND_URL" ]; then
    echo "❌ Aucun binaire compatible trouvé pour $OS/$GITHUB_ARCH"
    echo "Assets disponibles:"
    echo "$ASSETS" | head -10
    echo "⚠️ Plateforme non supportée: $OS/$GITHUB_ARCH"
    exit 2  # Code d'erreur spécifique pour plateforme non supportée
fi

echo "⬇️ Téléchargement: $FOUND_URL"

# Télécharger et installer
TEMP_FILE="/tmp/${BINARY_NAME}_download"
curl -L "$FOUND_URL" -o "$TEMP_FILE"

# Vérifier si c'est une archive
FILE_TYPE=$(file "$TEMP_FILE" 2>/dev/null || echo "unknown")

if echo "$FILE_TYPE" | grep -qi "gzip\|tar\|zip"; then
    echo "📦 Archive détectée, extraction..."
    TEMP_DIR="/tmp/${BINARY_NAME}_extract"
    mkdir -p "$TEMP_DIR"
    
    if echo "$FILE_TYPE" | grep -qi "gzip\|tar"; then
        tar -xzf "$TEMP_FILE" -C "$TEMP_DIR"
    elif echo "$FILE_TYPE" | grep -qi "zip"; then
        unzip -q "$TEMP_FILE" -d "$TEMP_DIR"
    fi
    
    # Chercher le binaire dans l'archive
    BINARY_PATH=$(find "$TEMP_DIR" -name "$BINARY_NAME" -type f | head -1)
    if [ -z "$BINARY_PATH" ]; then
        echo "❌ Binaire $BINARY_NAME non trouvé dans l'archive"
        exit 1
    fi
    
    cp "$BINARY_PATH" "/usr/local/bin/$BINARY_NAME"
    rm -rf "$TEMP_DIR"
else
    # Fichier binaire direct
    mv "$TEMP_FILE" "/usr/local/bin/$BINARY_NAME"
fi

chmod +x "/usr/local/bin/$BINARY_NAME"
rm -f "$TEMP_FILE"

echo "✅ $BINARY_NAME installé dans /usr/local/bin/"

# Test rapide
if command -v "$BINARY_NAME" >/dev/null 2>&1; then
    echo "🚀 $BINARY_NAME est prêt à l'usage"
    "$BINARY_NAME" --version 2>/dev/null || "$BINARY_NAME" version 2>/dev/null || echo "Version non affichable mais binaire fonctionnel"
else
    echo "⚠️ $BINARY_NAME installé mais non trouvé dans PATH"
fi