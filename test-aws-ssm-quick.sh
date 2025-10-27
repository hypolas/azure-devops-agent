#!/bin/bash
# Script rapide pour tester aws-ssm sur différentes plateformes
# Usage: ./test-aws-ssm-quick.sh

set -e

echo "🧪 Test rapide d'aws-ssm sur différentes plateformes"
echo "===================================================="

# Platforms à tester
PLATFORMS=("linux/amd64" "linux/arm64" "linux/arm/v7")

for platform in "${PLATFORMS[@]}"; do
    echo ""
    echo "📦 Test aws-ssm pour $platform..."
    
    # Créer un conteneur temporaire pour tester
    docker run --rm --platform "$platform" ubuntu:22.04 bash -c "
        apt-get update -qq && apt-get install -y -qq curl jq file
        
        # Détecter l'architecture
        ARCH=\$(dpkg --print-architecture 2>/dev/null || uname -m)
        OS=\$(uname -s | tr '[:upper:]' '[:lower:]')
        
        echo 'Architecture détectée: '\$ARCH' sur '\$OS
        
        # Mapper les architectures comme dans notre script
        case \"\$ARCH\" in
            amd64|x86_64) GITHUB_ARCH=\"x86_64\" ;;
            arm64|aarch64) GITHUB_ARCH=\"aarch64\" ;;
            armhf|armv7l) GITHUB_ARCH=\"armv7\" ;;
            arm*) GITHUB_ARCH=\"arm\" ;;
            *) GITHUB_ARCH=\"\$ARCH\" ;;
        esac
        
        echo 'Recherche de aws-ssm pour: '\$OS'-'\$GITHUB_ARCH
        
        # Récupérer les assets depuis GitHub
        ASSETS=\$(curl -s https://api.github.com/repos/hypolas/aws-ssm-lite/releases/latest | jq -r '.assets[].browser_download_url')
        
        echo 'Assets disponibles:'
        echo \"\$ASSETS\"
        
        # Chercher un asset compatible
        FOUND=\$(echo \"\$ASSETS\" | grep -i \"\$GITHUB_ARCH\" | head -1 || true)
        
        if [ -n \"\$FOUND\" ]; then
            echo '✅ aws-ssm disponible: '\$FOUND
        else
            echo '❌ aws-ssm non disponible pour cette architecture'
        fi
    " 2>/dev/null || echo "❌ Erreur lors du test pour $platform"
done

echo ""
echo "🎯 Recommandation: Utilisez uniquement linux/amd64 pour une compatibilité garantie"