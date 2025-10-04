#!/bin/bash
# Script d'ajout des capabilities
# Arguments: $1=DEFAULT_CONTAINER_IMAGE, $2=DEFAULT_VOLUMES, $3=AGENT_NUMBER

set -e

DEFAULT_CONTAINER_IMAGE=$1
DEFAULT_VOLUMES=$2
AGENT_NUMBER=$3

echo "Ajout des capabilities avec:"
echo "  Container par défaut: $DEFAULT_CONTAINER_IMAGE"
echo "  Volumes par défaut: $DEFAULT_VOLUMES"

# Ajouter les capabilities pour l'agent de cette instance
echo "Ajout des capabilities pour l'agent $AGENT_NUMBER..."

cd "/opt/azagent/$AGENT_NUMBER"

# Créer le fichier .capabilities
cat > .capabilities << EOF
docker=true
docker-compose=true
kubectl=false
helm=false
default-shell=sh
container-only=true
default-container=$DEFAULT_CONTAINER_IMAGE
default-volumes=$DEFAULT_VOLUMES
auto-mount-volumes=true
EOF

echo "Capabilities ajoutées pour l'agent $AGENT_NUMBER."