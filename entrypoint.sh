#!/bin/bash
set -e

# Function to be called on shutdown
cleanup() {
    echo "Container stopped. Running cleanup..."
    cd "$INSTALL_FOLDER/$AGENT_NUMBER"
    ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN"
    echo "Agent successfully unregistered."
    exit 0
}

# Trap SIGTERM and call cleanup
trap cleanup SIGTERM

# Add azureagent user to Docker group if /var/run/docker.sock exists
if [ -S /var/run/docker.sock ]; then
    DOCKER_SOCK_GID=$(stat -c '%g' /var/run/docker.sock)
    echo "Adding azureagent user to GID $DOCKER_SOCK_GID for Docker access..."
    sudo groupadd -g "$DOCKER_SOCK_GID" -f dockerhost 2>/dev/null || true
    sudo usermod -aG "$DOCKER_SOCK_GID" azureagent 2>/dev/null || true
    # sudo groupadd -g "$DOCKER_SOCK_GID" docker|| true
fi

# Verify required environment variables
if [ -z "$AZP_URL" ]; then
    echo "Error: AZP_URL must be defined"
    exit 1
fi

# Retrieve Azure DevOps token from AWS Secrets Manager if not provided
if [ -z "$AZP_TOKEN" ]; then
    if [ -n "$AZURE_DEVOPS_TOKEN_SECRET_ARN" ] && [ -n "$AWS_REGION" ]; then
        echo "Retrieving Azure DevOps token from AWS Secrets Manager..."

        # Use official aws-ssm (hypolas/aws-ssm-light) first
        if command -v aws-ssm >/dev/null 2>&1; then
            echo "Using aws-ssm (hypolas/aws-ssm-light)..."
            # Syntax: aws-ssm <secret-id> [region]
            SECRET_TOKEN=$(aws-ssm "$AZURE_DEVOPS_TOKEN_SECRET_ARN" "$AWS_REGION" 2>/dev/null)
        elif command -v light_ssm >/dev/null 2>&1; then
            echo "Using light_ssm (fallback)..."
            SECRET_TOKEN=$(light_ssm "$AZURE_DEVOPS_TOKEN_SECRET_ARN" "$AWS_REGION" 2>/dev/null)
        else
            echo "❌ No AWS Secrets Manager client available (aws-ssm or light_ssm)"
            echo "Install aws-ssm from hypolas/aws-ssm-light or enable INSTALL_AWS_SSM=true"
            exit 1
        fi

        if [ -n "$SECRET_TOKEN" ] && [ "$SECRET_TOKEN" != "null" ]; then
            AZP_TOKEN="$SECRET_TOKEN"
            echo "✅ Token retrieved from AWS Secrets Manager"
        else
            echo "❌ Failed to retrieve token from Secrets Manager"
            exit 1
        fi
    else
        echo "❌ AZP_TOKEN not provided and AWS Secrets Manager not configured"
        echo "Provide either AZP_TOKEN, or AWS_REGION + AZURE_DEVOPS_TOKEN_SECRET_ARN"
        exit 1
    fi
else
    echo "✅ Azure DevOps token provided directly"
fi

if [ -z "$AZP_POOL" ]; then
    echo "Error: AZP_POOL must be defined"
    exit 1
fi

if [ -z "$AGENT_NUMBER" ]; then
    echo "Error: AGENT_NUMBER must be defined"
    exit 1
fi

# Set default values if necessary
INSTALL_FOLDER=${INSTALL_FOLDER:-"/opt/azagent"}
DEFAULT_CONTAINER_IMAGE=${DEFAULT_CONTAINER_IMAGE:-"ubuntu:22.04"}
DEFAULT_VOLUMES=${DEFAULT_VOLUMES:-"/var/run/docker.sock:/var/run/docker.sock,/cache:/cache,/data:/data"}

# Retrieve INSTANCE_ID from AWS metadata if not provided
if [ -z "$INSTANCE_ID" ]; then
    echo "Retrieving INSTANCE_ID from AWS using IMDSv2..."

    # Retrieve IMDSv2 token to secure metadata access
    IMDS_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
        -s 2>/dev/null) || true

    if [ -n "$IMDS_TOKEN" ]; then
        # Use token to retrieve instance ID
        INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
            -s "http://169.254.169.254/latest/meta-data/instance-id" 2>/dev/null) || true
    fi

    echo "INSTANCE_ID from IMDSv2: $INSTANCE_ID"

    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "" ]; then
        echo "Warning: Unable to retrieve AWS INSTANCE_ID, using hostname"
        INSTANCE_ID=$(hostname)
    else
        echo "INSTANCE_ID retrieved from AWS: $INSTANCE_ID"
    fi
else
    echo "INSTANCE_ID provided: $INSTANCE_ID"
fi

echo "=========================================="
echo "Azure DevOps Agent Configuration"
echo "=========================================="
echo "URL: $AZP_URL"
echo "Pool: $AZP_POOL"
echo "Agent Name: $AZP_AGENT_NAME-$AGENT_NUMBER-$INSTANCE_ID"
echo "Install Folder: $INSTALL_FOLDER"
echo "Agent Number: $AGENT_NUMBER"
echo "Instance ID: $INSTANCE_ID"
echo "Default Container: $DEFAULT_CONTAINER_IMAGE"
echo "Default Volumes: $DEFAULT_VOLUMES"
echo "=========================================="

# Configure the agent
echo "Configuring Azure DevOps agent..."
/opt/setup-scripts/configure-agent.sh \
    "$INSTALL_FOLDER" \
    "$AZP_URL" \
    "$AZP_TOKEN" \
    "$AZP_POOL" \
    "$AZP_AGENT_NAME" \
    "$AGENT_NUMBER" \
    "$INSTANCE_ID"

# Add capabilities
echo "Adding capabilities..."
/opt/setup-scripts/add-capabilities.sh \
    "$DEFAULT_CONTAINER_IMAGE" \
    "$DEFAULT_VOLUMES" \
    "$AGENT_NUMBER" \
    "$INSTALL_FOLDER"

echo "Configuration complete. Starting agent..."

# Start the agent
echo "Starting agent ${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID}..."
cd "$INSTALL_FOLDER/$AGENT_NUMBER"
./run.sh &
wait $!