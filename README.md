# Azure DevOps Docker Agent

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

## Optional Environment Variables

- `INSTALL_FOLDER`: Agent installation directory (default: /opt/azagent)
- `INSTANCE_ID`: AWS instance ID (automatically retrieved with IMDSv2 if not provided)
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
docker run -d --name agent-1 -v /host/agent-data:/opt/azagent azure-agent
docker run -d --name agent-2 -v /host/agent-data:/opt/azagent azure-agent
# ↑ Both agents will conflict over the same configuration directory
```

### Correct Volume Configuration (✅ Right)
```bash
# DO THIS - AGENT_NUMBER ensures isolation
docker run -d --name agent-1 -e AGENT_NUMBER="1" -v /host/agent-1:/opt/azagent azure-agent
docker run -d --name agent-2 -e AGENT_NUMBER="2" -v /host/agent-2:/opt/azagent azure-agent
# ↑ Each agent has its own isolated configuration space
```

## Building the Image

```bash
docker build -t azure-agent .
```

## Running a Single Agent

```bash
docker run -d \
  --name azure-agent-1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/cache:/cache \
  -v $(pwd)/data:/data \
  -e AZP_URL="https://dev.azure.com/your-org" \
  -e AZP_TOKEN="your-token" \
  -e AZP_POOL="your-pool" \
  -e AZP_AGENT_NAME="my-agent" \
  -e AGENT_NUMBER="1" \
  azure-agent
```

## Multi-Agent Deployment

### With Docker Compose (Recommended)

The provided `docker-compose.yml` file automatically configures 7 agents (instances 1 to 7):

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
docker run -d --name azure-agent-1 -e AGENT_NUMBER="1" [other options] azure-agent

# Agent 2  
docker run -d --name azure-agent-2 -e AGENT_NUMBER="2" [other options] azure-agent

# Agent 3
docker run -d --name azure-agent-3 -e AGENT_NUMBER="3" [other options] azure-agent

# etc...
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

### ⚡ Optimized aws-ssm Binary (hypolas/aws-ssm-light)

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
    --secret-string "your-azure-devops-token"

# Launch agent with Secrets Manager
docker run -d \
  --name azure-agent-1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e AZP_URL="https://dev.azure.com/your-org" \
  -e AZP_POOL="your-pool" \
  -e AZP_AGENT_NAME="my-agent" \
  -e AGENT_NUMBER="1" \
  -e AWS_REGION="eu-west-1" \
  -e AZURE_DEVOPS_TOKEN_SECRET_ARN="arn:aws:secretsmanager:eu-west-1:123456789012:secret:azure-devops-token-AbCdEf" \
  azure-agent
```

### Automatic AWS Metadata Retrieval

The image uses IMDSv2 (Instance Metadata Service v2) to securely retrieve AWS instance ID.

## Architecture

- **One container = One agent** with unique AGENT_NUMBER (1-7)
- **Configuration Isolation**: AGENT_NUMBER prevents config conflicts in mounted volumes
- **Automatic Naming**: Agents are named `${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID}`
- **AWS Integration**: INSTANCE_ID is automatically retrieved from AWS metadata (IMDSv2)
- **Independent Operation**: Each agent operates independently with isolated configurations
- **Horizontal Scaling**: Deploy more containers with different AGENT_NUMBERs for scaling
- **Volume Safety**: AGENT_NUMBER ensures safe volume mounting without configuration overwrites

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