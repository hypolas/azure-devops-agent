# Docker Hub Configuration

## 🐳 Repository Information

**Docker Hub Repository**: `hypolas/azure-devops-agent`
**Registry**: `docker.io`
**Visibility**: Public

## 🔑 Required Secrets

For GitHub Actions to push to Docker Hub, configure these repository secrets:

### `DOCKERHUB_USERNAME`
- **Value**: `hypolas`
- **Description**: Docker Hub username

### `DOCKERHUB_TOKEN`
- **Value**: Your Docker Hub access token
- **Description**: Authentication token for pushing images

## 📋 Setup Steps

### 1. Create Docker Hub Access Token

1. Go to [Docker Hub](https://hub.docker.com/)
2. Sign in to account `hypolas`
3. Navigate to **Account Settings** → **Security**
4. Click **New Access Token**
5. Configure token:
   - **Description**: `GitHub Actions - Azure DevOps Agent`
   - **Permissions**: `Read, Write, Delete`
6. Copy the generated token (save it securely!)

### 2. Configure GitHub Repository Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add both secrets:

```
Name: DOCKERHUB_USERNAME
Value: hypolas

Name: DOCKERHUB_TOKEN  
Value: [paste your access token here]
```

## 🚀 Available Images

Once configured, images will be available at:

```bash
# Latest stable release
docker pull hypolas/azure-devops-agent:latest

# Specific version
docker pull hypolas/azure-devops-agent:v1.0.0

# Development branch
docker pull hypolas/azure-devops-agent:main

# Platform-specific images
docker pull hypolas/azure-devops-agent:latest-amd64
docker pull hypolas/azure-devops-agent:latest-arm64
docker pull hypolas/azure-devops-agent:latest-armv7

# Windows containers
docker pull hypolas/azure-devops-agent:latest-windows-amd64
```

## 📊 Image Tags Strategy

| Trigger | Tag Pattern | Example |
|---------|-------------|---------|
| Release tag | `v*.*.*` | `v1.2.3`, `latest` |
| Main branch | `main` | `main` |
| Develop branch | `develop` | `develop` |
| Pull request | `pr-*` | `pr-123` |
| Commit SHA | `sha-*` | `sha-abc1234` |

## 🔧 Manual Push (if needed)

For manual testing or one-off pushes:

```bash
# Build locally
docker build -t hypolas/azure-devops-agent:test .

# Login to Docker Hub
docker login

# Push
docker push hypolas/azure-devops-agent:test
```

## 📈 Repository Management

### Auto-Description
The repository description will be:
> "Lightweight Azure DevOps agent with AWS Secrets Manager integration - Optimized for modern CI/CD pipelines and DevOps automation."

### Tags
- `azure-devops`
- `docker-agent`
- `ci-cd`
- `aws-secrets-manager`
- `container-orchestration`
- `devops-automation`

### README
The Docker Hub README will sync automatically from this repository's README.md file.

---

*This configuration enables automated publishing of multi-platform Docker images to Docker Hub under the `hypolas` organization.*