#!/bin/bash
# Script pour tester manuellement les différentes plateformes Docker
# Usage: ./test-platforms.sh

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="azure-agent-test"
PLATFORMS=("linux/amd64" "linux/arm64" "linux/arm/v7")

echo -e "${BLUE}🧪 Test des plateformes Docker pour Azure DevOps Agent${NC}"
echo "=================================================="

# Fonction pour tester une plateforme
test_platform() {
    local platform=$1
    local platform_safe=$(echo "$platform" | tr '/' '-')
    
    echo ""
    echo -e "${YELLOW}📦 Test de la plateforme: $platform${NC}"
    echo "----------------------------------------"
    
    # Construire l'image pour la plateforme spécifique
    echo -e "${BLUE}🔨 Construction de l'image...${NC}"
    if docker buildx build --platform "$platform" -t "${IMAGE_NAME}:${platform_safe}" . --load 2>/dev/null; then
        echo -e "${GREEN}✅ Construction réussie pour $platform${NC}"
        
        # Tester l'image
        echo -e "${BLUE}🧪 Test de l'image...${NC}"
        if docker run --rm --platform "$platform" "${IMAGE_NAME}:${platform_safe}" bash -c "
            echo 'Architecture: \$(uname -m)'
            echo 'OS: \$(uname -s)'
            echo 'Kernel: \$(uname -r)'
            if command -v aws-ssm >/dev/null 2>&1; then
                echo '✅ aws-ssm trouvé'
                aws-ssm --version 2>/dev/null || echo 'Version aws-ssm non disponible'
            else
                echo '❌ aws-ssm non trouvé'
            fi
            if command -v docker >/dev/null 2>&1; then
                echo '✅ Docker CLI trouvé'
                docker --version
            else
                echo '❌ Docker CLI non trouvé'
            fi
            echo 'Test terminé pour $platform'
        " 2>/dev/null; then
            echo -e "${GREEN}✅ Test runtime réussi pour $platform${NC}"
            
            # Nettoyer l'image
            docker rmi "${IMAGE_NAME}:${platform_safe}" >/dev/null 2>&1
            return 0
        else
            echo -e "${RED}❌ Test runtime échoué pour $platform${NC}"
            docker rmi "${IMAGE_NAME}:${platform_safe}" >/dev/null 2>&1
            return 1
        fi
    else
        echo -e "${RED}❌ Construction échouée pour $platform${NC}"
        return 1
    fi
}

# Fonction pour tester aws-ssm uniquement
test_aws_ssm_availability() {
    echo ""
    echo -e "${YELLOW}🔍 Test de disponibilité d'aws-ssm pour les plateformes${NC}"
    echo "--------------------------------------------------------"
    
    for platform in "${PLATFORMS[@]}"; do
        platform_safe=$(echo "$platform" | tr '/' '-')
        echo -e "${BLUE}Testing aws-ssm pour $platform...${NC}"
        
        # Créer un Dockerfile temporaire minimal pour tester aws-ssm
        cat > Dockerfile.test << EOF
FROM --platform=$platform ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \\
    curl ca-certificates jq file unzip && \\
    rm -rf /var/lib/apt/lists/*
COPY download-github-binary.sh /tmp/
RUN chmod +x /tmp/download-github-binary.sh
RUN echo "Testing aws-ssm download for $platform..." && \\
    if /tmp/download-github-binary.sh "hypolas/aws-ssm-light" "aws-ssm"; then \\
        echo "✅ aws-ssm disponible pour $platform"; \\
        aws-ssm --version 2>/dev/null || echo "Installed but version not available"; \\
    else \\
        echo "❌ aws-ssm non disponible pour $platform"; \\
    fi
EOF
        
        if docker buildx build --platform "$platform" -f Dockerfile.test -t "test-aws-ssm:${platform_safe}" . --load >/dev/null 2>&1; then
            docker run --rm --platform "$platform" "test-aws-ssm:${platform_safe}" 2>/dev/null || echo -e "${RED}❌ Runtime failed for $platform${NC}"
            docker rmi "test-aws-ssm:${platform_safe}" >/dev/null 2>&1
        else
            echo -e "${RED}❌ Build failed for $platform${NC}"
        fi
        
        rm -f Dockerfile.test
        echo ""
    done
}

# Vérifier les prérequis
echo -e "${BLUE}🔍 Vérification des prérequis...${NC}"
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker non trouvé${NC}"
    exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker Buildx non trouvé${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prérequis satisfaits${NC}"

# Créer un builder multiplateforme si nécessaire
echo -e "${BLUE}🔧 Configuration du builder multiplateforme...${NC}"
if ! docker buildx inspect multiplatform >/dev/null 2>&1; then
    docker buildx create --name multiplatform --driver docker-container --bootstrap >/dev/null 2>&1
fi
docker buildx use multiplatform >/dev/null 2>&1
echo -e "${GREEN}✅ Builder multiplateforme configuré${NC}"

# Test rapide d'aws-ssm
echo ""
echo -e "${YELLOW}🎯 Test rapide: disponibilité d'aws-ssm${NC}"
test_aws_ssm_availability

# Menu interactif
while true; do
    echo ""
    echo -e "${YELLOW}🎛️ Menu de test${NC}"
    echo "1. Tester toutes les plateformes"
    echo "2. Tester linux/amd64 uniquement"
    echo "3. Tester linux/arm64 uniquement"
    echo "4. Tester linux/arm/v7 uniquement"
    echo "5. Test aws-ssm seulement"
    echo "6. Quitter"
    echo ""
    read -p "Choisissez une option (1-6): " choice
    
    case $choice in
        1)
            echo -e "${BLUE}🚀 Test de toutes les plateformes...${NC}"
            success_count=0
            for platform in "${PLATFORMS[@]}"; do
                if test_platform "$platform"; then
                    ((success_count++))
                fi
            done
            echo ""
            echo -e "${YELLOW}📊 Résumé: $success_count/${#PLATFORMS[@]} plateformes réussies${NC}"
            ;;
        2)
            test_platform "linux/amd64"
            ;;
        3)
            test_platform "linux/arm64"
            ;;
        4)
            test_platform "linux/arm/v7"
            ;;
        5)
            test_aws_ssm_availability
            ;;
        6)
            echo -e "${GREEN}👋 Au revoir!${NC}"
            break
            ;;
        *)
            echo -e "${RED}❌ Option invalide${NC}"
            ;;
    esac
done

# Nettoyage
echo -e "${BLUE}🧹 Nettoyage...${NC}"
docker buildx use default >/dev/null 2>&1
echo -e "${GREEN}✅ Terminé${NC}"