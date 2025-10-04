#!/bin/bash
# Script to add capabilities
# Arguments: $1=DEFAULT_CONTAINER_IMAGE, $2=DEFAULT_VOLUMES, $3=AGENT_NUMBER

set -e

DEFAULT_CONTAINER_IMAGE=$1
DEFAULT_VOLUMES=$2
AGENT_NUMBER=$3
INSTALL_FOLDER=$4

echo "Adding capabilities with:"
echo "  Default container: $DEFAULT_CONTAINER_IMAGE"
echo "  Default volumes: $DEFAULT_VOLUMES"

# Add capabilities for this instance's agent
echo "Adding capabilities for agent $AGENT_NUMBER..."

cd "$INSTALL_FOLDER/$AGENT_NUMBER"

# Create .capabilities file
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

echo "Capabilities added for agent $AGENT_NUMBER."