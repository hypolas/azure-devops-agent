#!/bin/bash

# Script de test pour l'image Azure DevOps Agent
# Usage: ./test-docker-hub-image.sh

set -e

echo "🐳 Test de l'image Azure DevOps Agent depuis Docker Hub"
echo "=================================================="

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérifier si Docker est disponible
if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé ou n'est pas dans le PATH"
    exit 1
fi

# Vérifier si Docker Compose est disponible
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose n'est pas installé"
    exit 1
fi

# Détecter la commande docker compose
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

log_info "Utilisation de: $DOCKER_COMPOSE"

# Vérifier si le fichier .env existe
if [ ! -f ".env" ]; then
    log_warning "Fichier .env non trouvé"
    if [ -f ".env.test" ]; then
        log_info "Copie de .env.test vers .env"
        cp .env.test .env
        log_warning "⚠️  IMPORTANT: Éditez le fichier .env avec vos vraies valeurs Azure DevOps"
        echo ""
        echo "Vous devez configurer au minimum :"
        echo "  - AZP_URL=https://dev.azure.com/votre-organisation"
        echo "  - AZP_TOKEN=votre-personal-access-token"
        echo ""
        read -p "Appuyez sur Entrée après avoir édité .env, ou Ctrl+C pour annuler..."
    else
        log_error "Fichier .env.test non trouvé"
        exit 1
    fi
fi

echo ""
log_info "Pulling de l'image depuis Docker Hub..."
docker pull hypolas/azure-devops-agent:latest

echo ""
log_info "Vérification de l'image..."
docker inspect hypolas/azure-devops-agent:latest > /dev/null

echo ""
log_info "Affichage des informations de l'image..."
docker images hypolas/azure-devops-agent:latest

echo ""
log_info "Nettoyage des anciens conteneurs de test..."
$DOCKER_COMPOSE -f docker-compose.test.yml down --remove-orphans 2>/dev/null || true

echo ""
log_info "Démarrage du conteneur de test..."
$DOCKER_COMPOSE -f docker-compose.test.yml --env-file .env up -d

echo ""
log_info "Attente du démarrage du conteneur..."
sleep 10

echo ""
log_info "Vérification du statut du conteneur..."
if docker ps | grep azure-agent-test > /dev/null; then
    log_success "Conteneur en cours d'exécution"
else
    log_error "Conteneur non démarré"
    echo ""
    log_info "Logs du conteneur :"
    docker logs azure-agent-test
    exit 1
fi

echo ""
log_info "Affichage des logs (10 dernières lignes)..."
docker logs --tail 10 azure-agent-test

echo ""
log_info "Test de la connectivité aws-ssm..."
if docker exec azure-agent-test aws-ssm --version > /dev/null 2>&1; then
    log_success "aws-ssm installé et fonctionnel"
else
    log_warning "aws-ssm non accessible (peut être normal selon la configuration)"
fi

echo ""
log_info "Test de la connectivité Docker..."
if docker exec azure-agent-test docker --version > /dev/null 2>&1; then
    log_success "Docker CLI installé et fonctionnel"
else
    log_error "Docker CLI non accessible"
fi

echo ""
log_info "Vérification de l'utilisateur..."
USER_INFO=$(docker exec azure-agent-test whoami)
log_info "Utilisateur actuel: $USER_INFO"

echo ""
log_info "Vérification des processus..."
docker exec azure-agent-test ps aux | head -10

echo ""
echo "=================================================="
log_success "Test terminé !"
echo ""
echo "Commandes utiles :"
echo "  • Voir les logs en temps réel :  docker logs -f azure-agent-test"
echo "  • Entrer dans le conteneur :     docker exec -it azure-agent-test bash"
echo "  • Arrêter le test :              $DOCKER_COMPOSE -f docker-compose.test.yml down"
echo "  • Supprimer les volumes :        $DOCKER_COMPOSE -f docker-compose.test.yml down -v"
echo ""

# Optionnel: démarrer le service de test nginx
read -p "Voulez-vous démarrer le service nginx de test ? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Démarrage du service nginx de test..."
    $DOCKER_COMPOSE -f docker-compose.test.yml --profile test up -d
    log_success "Service nginx démarré sur http://localhost:8080"
fi