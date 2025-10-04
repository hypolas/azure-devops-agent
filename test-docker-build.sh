#!/bin/bash
# Script pour tester le build Docker avec différentes configurations
# Usage: ./test-docker-build.sh

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🐳 Test de build Docker avec différentes configurations${NC}"
echo "======================================================="

# Fonction pour tester un build
test_build() {
    local platform=$1
    local aws_ssm_flag=$2
    local test_name=$3
    
    echo ""
    echo -e "${YELLOW}🔨 Test: $test_name${NC}"
    echo "Platform: $platform"
    echo "AWS SSM: $aws_ssm_flag"
    echo "------------------------"
    
    local tag="azure-agent-test:$(echo "$platform-$aws_ssm_flag" | tr '/' '-')"
    
    if docker build \
        --platform "$platform" \
        --build-arg INSTALL_AWS_SSM="$aws_ssm_flag" \
        -t "$tag" \
        . >/dev/null 2>&1; then
        
        echo -e "${GREEN}✅ Build réussi${NC}"
        
        # Test rapide du conteneur
        if docker run --rm --platform "$platform" "$tag" bash -c "
            echo 'Architecture: \$(uname -m)'
            if [ '$aws_ssm_flag' = 'true' ]; then
                if command -v aws-ssm >/dev/null 2>&1; then
                    echo '✅ aws-ssm trouvé'
                elif command -v aws >/dev/null 2>&1; then
                    echo '✅ AWS CLI trouvé (fallback)'
                else
                    echo '❌ Aucun client AWS trouvé'
                fi
            else
                echo 'ℹ️ AWS SSM désactivé'
            fi
        " 2>/dev/null; then
            echo -e "${GREEN}✅ Test runtime réussi${NC}"
        else
            echo -e "${RED}❌ Test runtime échoué${NC}"
        fi
        
        # Nettoyer
        docker rmi "$tag" >/dev/null 2>&1
        return 0
    else
        echo -e "${RED}❌ Build échoué${NC}"
        return 1
    fi
}

# Tests de configuration
echo -e "${BLUE}🧪 Série de tests de build${NC}"

# Test 1: linux/amd64 avec aws-ssm
test_build "linux/amd64" "true" "AMD64 avec aws-ssm"

# Test 2: linux/amd64 sans aws-ssm
test_build "linux/amd64" "false" "AMD64 sans aws-ssm"

# Test 3: linux/arm64 avec aws-ssm (peut échouer)
echo ""
echo -e "${YELLOW}⚠️ Test de compatibilité ARM64 (peut échouer)${NC}"
if test_build "linux/arm64" "true" "ARM64 avec aws-ssm"; then
    echo -e "${GREEN}✅ ARM64 compatible!${NC}"
else
    echo -e "${RED}❌ ARM64 non compatible avec aws-ssm${NC}"
fi

# Test 4: Multi-stage uniquement
echo ""
echo -e "${YELLOW}🔍 Test du stage temp-version${NC}"
if docker build --target temp-version --platform linux/amd64 -t temp-version-test . >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Stage temp-version fonctionne${NC}"
    
    # Extraire la version
    VERSION=$(docker run --rm temp-version-test cat /tmp/agent_version.txt 2>/dev/null || echo "unknown")
    echo "Version de l'agent détectée: $VERSION"
    
    docker rmi temp-version-test >/dev/null 2>&1
else
    echo -e "${RED}❌ Stage temp-version échoué${NC}"
fi

# Résumé et recommandations
echo ""
echo -e "${BLUE}📋 Résumé et recommandations${NC}"
echo "================================"
echo "1. ✅ linux/amd64 est la plateforme la plus fiable"
echo "2. ⚠️ ARM64/ARM7 peuvent avoir des problèmes avec aws-ssm"
echo "3. 🎯 Pour la production, utilisez linux/amd64 uniquement"
echo "4. 🔧 Le stage temp-version doit fonctionner pour extraire la version"

echo ""
echo -e "${GREEN}✅ Tests terminés${NC}"