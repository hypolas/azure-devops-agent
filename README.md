# Azure DevOps Docker Agent

**GitHub Repository**: [https://github.com/hypolas/azure-devops-agent](https://github.com/hypolas/azure-devops-agent)
**Docker Hub Image**: [https://hub.docker.com/r/hypolas/azure-devops-agent](https://hub.docker.com/r/hypolas/azure-devops-agent)

[![Docker](https://img.shields.io/badge/docker-supported-blue.svg)](https://www.docker.com/)
[![Azure DevOps](https://img.shields.io/badge/azure--devops-agent-blue.svg)](https://azure.microsoft.com/services/devops/)
[![AWS](https://img.shields.io/badge/aws-secrets--manager-orange.svg)](https://aws.amazon.com/secrets-manager/)
[![CI/CD](https://img.shields.io/badge/ci%2Fcd-automation-green.svg)]()
[![Container](https://img.shields.io/badge/container-orchestration-purple.svg)]()

> **SEO Keywords**: `azure devops agent docker`, `docker container ci cd`, `aws secrets manager integration`, `azure pipelines self hosted`, `container orchestration devops`, `automated deployment pipeline`, `microservices ci cd`, `docker compose azure`, `devops automation tools`, `cloud native pipelines`

This Docker image configures and runs an Azure DevOps agent with container support and AWS Secrets Manager integration.

## Required Environment Variables

- `AZP_URL`: Your Azure DevOps organization URL (ex: https://dev.azure.com/your-org)
- `AZP_TOKEN`: Personal Access Token (PAT) for Azure DevOps
- `AZP_POOL`: Agent pool name
- `AZP_AGENT_NAME`: Base agent name (will be suffixed with -${AGENT_NUMBER})
- `AGENT_NUMBER`: **Mandatory** - Unique identifier for each agent instance. Required to avoid configuration conflicts when mounting Docker volumes on disk.
- `INSTALL_FOLDER`: **Mandatory** - Agent installation directory. Must be identical in both environment variable and volume mount path.

## Optional Environment Variables
- `INSTANCE_ID`: AWS instance ID (automatically retrieved with IMDSv2 if running on AWS, falls back to container hostname if not available)
- `AWS_REGION`: AWS region for Secrets Manager (ex: eu-west-1)
- `AZURE_DEVOPS_TOKEN_SECRET_ARN`: ARN of AWS secret containing Azure DevOps token
- `DEFAULT_CONTAINER_IMAGE`: Default container image (default: ubuntu:22.04)
- `DEFAULT_VOLUMES`: Default volumes (default: /var/run/docker.sock:/var/run/docker.sock,/cache:/cache,/data:/data)

## ⚠️ Important: AGENT_NUMBER and Volume Mounting

**AGENT_NUMBER is mandatory** when mounting Docker volumes to avoid configuration conflicts:

- **Without AGENT_NUMBER**: Multiple agent instances would share the same configuration files, causing conflicts
- **With AGENT_NUMBER**: Each agent gets isolated configuration in separate directories
- **Directory Structure**: Agent configurations are stored in `/opt/azagent/agent-${AGENT_NUMBER}/`
- **Volume Isolation**: Prevents agents from overwriting each other's settings when using persistent volumes

### Example of Volume Conflicts (❌ Wrong)
```bash
# DON'T DO THIS - Missing AGENT_NUMBER causes conflicts
docker run -d --name agent-1 -v /host/agent-data:/opt/azagent hypolas/azure-devops-agent:latest
docker run -d --name agent-2 -v /host/agent-data:/opt/azagent hypolas/azure-devops-agent:latest
# ↑ Both agents will conflict over the same configuration directory
```

### Correct Volume Configuration (✅ Right)
```bash
# DO THIS - AGENT_NUMBER ensures isolation
docker run -d --name agent-1 \
  -e AGENT_NUMBER="1" \
  -e INSTALL_FOLDER="/opt/azagent" \
  -v /opt/azagent:/opt/azagent \
  hypolas/azure-devops-agent:latest

docker run -d --name agent-2 \
  -e AGENT_NUMBER="2" \
  -e INSTALL_FOLDER="/opt/azagent" \
  -v /opt/azagent:/opt/azagent \
  hypolas/azure-devops-agent:latest
# ↑ Each agent has its own isolated configuration space
```

## Building the Image

```bash
docker build -t hypolas/azure-devops-agent:latest .
```

## Running a Single Agent

```bash
docker run -d \
  --name azure-agent-1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/azagent:/opt/azagent \
  -e AZP_URL="https://dev.azure.com/your-org" \
  -e AZP_TOKEN="your-token" \
  -e AZP_POOL="your-pool" \
  -e AZP_AGENT_NAME="my-agent" \
  -e AGENT_NUMBER="1" \
  -e INSTALL_FOLDER="/opt/azagent" \
  hypolas/azure-devops-agent:latest
```

## Multi-Agent Deployment

### With Docker Compose (Recommended)

Use the provided `docker-compose.yml` file (using environment variables):

```yaml
version: '3.8'

services:
  azure-agent:
    build:
      context: .
      args:
        # aws-ssm installed by default (hypolas/aws-ssm-lite)
        INSTALL_AWS_SSM: "true"

    container_name: azure-devops-agent
    hostname: azure-agent

    environment:
      # Azure DevOps configuration (required)
      - AZP_URL=${AZP_URL}
      - AZP_POOL=${AZP_POOL}
      - AZP_AGENT_NAME=${AZP_AGENT_NAME:-azure-agent}
      - AGENT_NUMBER=${AGENT_NUMBER:-1}
      - INSTALL_FOLDER=${INSTALL_FOLDER}

      # AWS for token retrieval (if AZP_TOKEN not provided)
      - AWS_REGION=${AWS_REGION}
      - AZURE_DEVOPS_TOKEN_SECRET_ARN=${AZURE_DEVOPS_TOKEN_SECRET_ARN}

      # Direct token (optional, takes priority over AWS)
      - AZP_TOKEN=${AZP_TOKEN}

      # Container configuration
      - DEFAULT_CONTAINER_IMAGE=ubuntu:22.04
      - DEFAULT_VOLUMES=/var/run/docker.sock:/var/run/docker.sock,/cache:/cache,/data:/data

    volumes:
      # Docker socket for builds
      - /var/run/docker.sock:/var/run/docker.sock
      - ${INSTALL_FOLDER}:${INSTALL_FOLDER}
    restart: unless-stopped

    # Healthcheck to verify agent is running
    healthcheck:
      test: ["CMD-SHELL", "pgrep -f 'Agent.Listener' || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

#### ⚠️ Critical: INSTALL_FOLDER Consistency

**The `INSTALL_FOLDER` value MUST be identical in both the environment variable and the volume mount path. This is MANDATORY for the agent to function properly.**

```yaml
# ✅ CORRECT - Same path in both places (using variable)
environment:
  - INSTALL_FOLDER=${INSTALL_FOLDER}
volumes:
  - ${INSTALL_FOLDER}:${INSTALL_FOLDER}

# Example with .env file:
# INSTALL_FOLDER=/opt/azagent

# ❌ WRONG - Different paths will cause FAILURE
environment:
  - INSTALL_FOLDER=/opt/azagent
volumes:
  - /opt/agent:/opt/azagent  # ← Different path, agent will NOT work
```

**Why this matters:**
- The agent creates its configuration inside `${INSTALL_FOLDER}/${AGENT_NUMBER}/`
- The volume mount must map to the exact same path
- Mismatched paths will prevent the agent from finding its configuration files
- **The service will FAIL to start if paths don't match**

**Deployment:**

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your values
# Then start all agents
docker-compose up -d
```

### With Individual Docker Commands

```bash
# Agent 1
docker run -d \
  --name azure-agent-1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/azagent:/opt/azagent \
  -e AZP_URL="https://dev.azure.com/your-org" \
  -e AZP_TOKEN="your-token" \
  -e AZP_POOL="your-pool" \
  -e AZP_AGENT_NAME="my-agent" \
  -e AGENT_NUMBER="1" \
  -e INSTALL_FOLDER="/opt/azagent" \
  hypolas/azure-devops-agent:latest

# Agent 2
docker run -d \
  --name azure-agent-2 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/azagent:/opt/azagent \
  -e AZP_URL="https://dev.azure.com/your-org" \
  -e AZP_TOKEN="your-token" \
  -e AZP_POOL="your-pool" \
  -e AZP_AGENT_NAME="my-agent" \
  -e AGENT_NUMBER="2" \
  -e INSTALL_FOLDER="/opt/azagent" \
  hypolas/azure-devops-agent:latest

# etc...
```

### Multi-Agent Deployment Script Example

For a server with 8 vCPUs, following the rule of **2 vCPUs per agent** (this is a subjective recommendation - adjust based on your workload requirements and performance monitoring), you can deploy **4 agents** using this script:

Create a file `deploy-agents.sh`:

```bash

#!/bin/bash
# Multi-agent deployment script
# Rule: 2 vCPUs per agent
# Automatically detects available CPUs

set -e

# Configuration
TOTAL_VCPUS=$(nproc)
VCPUS_PER_AGENT=2  # Adjust this value based on your workload needs
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
```

**Usage:**

```bash
# Make the script executable
chmod +x deploy-agents.sh

# Deploy agents
./deploy-agents.sh
```

## 🚀 Features

- ✅ **Containerized Azure DevOps Agent**: Automatic configuration per container
- 🐳 **Docker-in-Docker**: Full support for container execution
- ⚙️ **Pre-configured Capabilities**: Docker and Docker Compose ready-to-use
- 💾 **Persistent Storage**: Volumes for cache and data
- 🔐 **AWS Security**: Automatic INSTANCE_ID retrieval (IMDSv2)
- ⚡ **Lightweight aws-ssm**: Optimized client (~10MB) for AWS Secrets Manager
- 🛡️ **Secure Secret Management**: AWS Secrets Manager integration
- 📦 **Automatic Updates**: Download latest agent version
- 🔢 **Multi-instance**: Multiple agent management via AGENT_NUMBER
- 🌐 **Production-ready**: Optimized for cloud environments

### ⚡ Optimized aws-ssm Binary (hypolas/aws-ssm-lite)

The image automatically integrates the **aws-ssm binary** to replace AWS CLI:

| Tool | Size | Memory RAM | Startup Time | Performance |
|------|------|------------|--------------|-------------|
| AWS CLI | ~100MB+ | ~50MB+ | ~1-2s | ⚠️ Standard |
| aws-ssm | ~10MB | ~5MB | ~50ms | ✅ Optimized |

**Technical Advantages**:
- ✅ **Superior Performance**: 20x faster than AWS CLI
- ✅ **Reduced Footprint**: 10x smaller than AWS CLI
- 🔒 **Enhanced Security**: Automated tests, SHA256 checksums
- 🎯 **Simplified API**: Syntax `aws-ssm <secret-id> [region]`
- 🚀 **Cloud-native**: Designed for microservices architectures

## Security and Best Practices

### Token Management with AWS Secrets Manager

For optimal security, store your Azure DevOps token in AWS Secrets Manager:

```bash
# Create a secret in AWS Secrets Manager
aws secretsmanager create-secret \
    --name "azure-devops-token" \
    --description "Token for Azure DevOps agents" \
    --secret-string "your-azure-devops-token" \
    --region eu-west-1

# Launch agent with Secrets Manager
docker run -d \
  --name azure-agent-1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /opt/azagent:/opt/azagent \
  -e AZP_URL="https://dev.azure.com/your-org" \
  -e AZP_POOL="your-pool" \
  -e AZP_AGENT_NAME="my-agent" \
  -e AGENT_NUMBER="1" \
  -e INSTALL_FOLDER="/opt/azagent" \
  -e AWS_REGION="eu-west-1" \
  -e AZURE_DEVOPS_TOKEN_SECRET_ARN="arn:aws:secretsmanager:eu-west-1:123456789012:secret:azure-devops-token-AbCdEf" \
  hypolas/azure-devops-agent:latest
```

### Automatic AWS Metadata Retrieval

The image uses IMDSv2 (Instance Metadata Service v2) to securely retrieve AWS instance ID.

## Architecture

- **One container = One agent** with unique AGENT_NUMBER
- **Configuration Isolation**: AGENT_NUMBER prevents config conflicts in mounted volumes
- **Automatic Naming**: Agents are named `${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID}`
- **AWS Integration**: INSTANCE_ID is automatically retrieved from AWS metadata (IMDSv2), falls back to hostname if not on AWS
- **Independent Operation**: Each agent operates independently with isolated configurations
- **Horizontal Scaling**: Deploy more containers with different AGENT_NUMBERs for scaling
- **Volume Safety**: AGENT_NUMBER ensures safe volume mounting without configuration overwrites
- **INSTALL_FOLDER Requirement**: Must be identical in environment variable and volume mount path

## 📁 File Structure

- `Dockerfile`: Optimized Docker image definition
- `entrypoint.sh`: Main entry script with secret management
- `scripts/configure-agent.sh`: Automatic agent configuration
- `scripts/add-capabilities.sh`: Docker capabilities definition
- `AWS-SSM.md`: Technical documentation for aws-ssm binary
- `docker-compose.yml`: Multi-agent orchestration

## 🌐 Search Engine Metadata

**Core Technologies**:
- Docker, Azure DevOps, AWS Secrets Manager
- Container orchestration, CI/CD automation
- Microservices architecture, Cloud-native deployment

**Use Cases**:
- Automated CI/CD pipelines with Azure DevOps
- Secure secret management with AWS integration
- Scalable containerized build agents
- Multi-environment deployment automation
- Docker-based development workflows

**Technical Keywords**:
`azure-pipelines`, `docker-agent`, `ci-cd-automation`, `aws-secrets-integration`, `container-orchestration`, `devops-tools`, `microservices-deployment`, `cloud-native-ci`, `automated-builds`, `secure-pipelines`

---

*Docker image for Azure DevOps agents with AWS Secrets Manager integration - Optimized for modern CI/CD pipelines and DevOps automation.*

## Disclaimer

**This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.**

The developer cannot be held responsible for any problems, data loss, security issues, or any other consequences that may arise from the use of this software. Users are solely responsible for:
- Proper configuration and deployment
- Security of credentials and tokens
- Resource allocation and monitoring
- Compliance with Azure DevOps and AWS terms of service
- Any costs incurred from cloud service usage

Use at your own risk.