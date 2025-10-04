
#!/bin/bash
# Multi-agent deployment script
# Rule: 2 vCPUs per agent
# Automatically detects available CPUs

set -e

# Configuration
TOTAL_VCPUS=$(nproc)
VCPUS_PER_AGENT=2
MAX_AGENTS=$((TOTAL_VCPUS / VCPUS_PER_AGENT))

echo "Detected $TOTAL_VCPUS vCPUs on this server"
echo "Deploying $MAX_AGENTS agents with $VCPUS_PER_AGENT vCPUs each"

# Load environment variables from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

# Check required variables
if [ -z "$AZP_URL" ] || [ -z "$AZP_POOL" ] || [ -z "$AZP_AGENT_NAME" ] || [ -z "$INSTALL_FOLDER" ]; then
    echo "Error: Required variables not set in .env (AZP_URL, AZP_POOL, AZP_AGENT_NAME, INSTALL_FOLDER)"
    exit 1
fi

echo "=========================================="
echo "Deploying $MAX_AGENTS agents (${VCPUS_PER_AGENT} vCPUs each)"
echo "=========================================="

# Deploy agents in a loop
for i in $(seq 1 $MAX_AGENTS); do
    AGENT_NAME="azure-agent-$i"

    echo "Starting agent $i/$MAX_AGENTS: $AGENT_NAME"

    docker run -d \
        --name "$AGENT_NAME" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "${INSTALL_FOLDER}:${INSTALL_FOLDER}" \
        -e AZP_URL="$AZP_URL" \
        -e AZP_TOKEN="$AZP_TOKEN" \
        -e AZP_POOL="$AZP_POOL" \
        -e AZP_AGENT_NAME="$AZP_AGENT_NAME" \
        -e AGENT_NUMBER="$i" \
        -e INSTALL_FOLDER="${INSTALL_FOLDER}" \
        -e AWS_REGION="$AWS_REGION" \
        -e DEFAULT_CONTAINER_IMAGE="${DEFAULT_CONTAINER_IMAGE:-ubuntu:22.04}" \
        -e DEFAULT_VOLUMES="${DEFAULT_VOLUMES:-/var/run/docker.sock:/var/run/docker.sock,/cache:/cache,/data:/data}" \
        --restart unless-stopped \
        hypolas/azure-devops-agent:latest

    echo "✅ Agent $i started: $AGENT_NAME"
done