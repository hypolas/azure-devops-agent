# Stage 1: Extract agent version
FROM ubuntu:22.04 AS temp-version

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    grep \
    && rm -rf /var/lib/apt/lists/*

RUN AGENT_VERSION=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | grep -oP '"tag_name": "v\K(.*)(?=")') && \
    echo "$AGENT_VERSION" > /tmp/agent_version.txt && \
    echo "Detected version: $AGENT_VERSION"

# Stage 2: Download Azure DevOps agent
FROM ubuntu:22.04 AS agent-downloader

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    tar \
    && rm -rf /var/lib/apt/lists/*

COPY --from=temp-version /tmp/agent_version.txt /tmp/agent_version.txt

RUN AGENT_VERSION=$(cat /tmp/agent_version.txt) && \
    echo "Downloading Azure DevOps agent..." && \
    echo "Detected version: $AGENT_VERSION" && \
    \
    # Detect architecture to choose the right agent
    ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m) && \
    case "$ARCH" in \
        amd64|x86_64) AGENT_ARCH="x64" ;; \
        arm64|aarch64) AGENT_ARCH="arm64" ;; \
        armhf|armv7l|armv7) AGENT_ARCH="arm" ;; \
        *) echo "⚠️ Unsupported architecture: $ARCH, using x64 by default" && AGENT_ARCH="x64" ;; \
    esac && \
    \
    echo "Detected architecture: $ARCH -> Agent: linux-$AGENT_ARCH" && \
    mkdir -p /opt/dl && \
    curl -fsSL "https://download.agent.dev.azure.com/agent/$AGENT_VERSION/vsts-agent-linux-$AGENT_ARCH-$AGENT_VERSION.tar.gz" -o "/tmp/agent.tar.gz" && \
    tar xzf "/tmp/agent.tar.gz" -C /opt/dl && \
    rm "/tmp/agent.tar.gz"

# Stage 3: Download aws-ssm
FROM ubuntu:22.04 AS aws-ssm-downloader

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    jq \
    file \
    unzip \
    tar \
    && rm -rf /var/lib/apt/lists/*

COPY download-github-binary.sh /tmp/
RUN chmod +x /tmp/download-github-binary.sh && \
    /tmp/download-github-binary.sh "hypolas/aws-ssm-lite" "aws-ssm"

# Stage 4: Download Docker CLI
FROM ubuntu:22.04 AS docker-downloader

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Final stage: Minimal runtime image
FROM ubuntu:22.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
# Install only necessary runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    jq \
    git \
    # .NET runtime dependencies for Azure DevOps agent
    libicu70 \
    liblttng-ust1 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy binaries from build stages
COPY --from=temp-version /tmp/agent_version.txt /tmp/agent_version.txt
COPY --from=agent-downloader /opt/dl /opt/dl
# COPY --from=agent-downloader /opt/azagent/agent/ /opt/azagent/agent/
COPY --from=aws-ssm-downloader /usr/local/bin/aws-ssm /usr/local/bin/aws-ssm
COPY --from=docker-downloader /usr/bin/docker /usr/bin/docker
COPY --from=docker-downloader /usr/libexec/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose

# Create azureagent user
RUN useradd -m -s /bin/bash azureagent \
    && usermod -aG sudo azureagent \
    && echo "azureagent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates

# Create necessary directories and adjust permissions
RUN mkdir -p /opt/setup-scripts \
    && mkdir -p /cache \
    && mkdir -p /data \
    && mkdir -p /usr/libexec/docker/cli-plugins \
    && chown -R azureagent:azureagent /opt/dl \
    && chown -R azureagent:azureagent /opt/setup-scripts \
    && chmod +x /usr/local/bin/aws-ssm \
    && chmod +x /usr/bin/docker \
    && chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# Install .NET dependencies for Azure DevOps agent at build time
WORKDIR /opt/azagent
RUN if [ -f "./bin/installdependencies.sh" ]; then \
        echo "Installing .NET dependencies for Azure DevOps agent..." && \
        ./bin/installdependencies.sh; \
    fi && \
    chown -R azureagent:azureagent /opt/azagent

# Copy configuration scripts
COPY scripts/ /opt/setup-scripts/
RUN chmod +x /opt/setup-scripts/*.sh \
    && chown -R azureagent:azureagent /opt/setup-scripts

# Default environment variables
ENV INSTALL_FOLDER="/opt/azagent"
ENV AZP_URL=""
ENV AZP_TOKEN=""
ENV AZP_POOL=""
ENV AZP_AGENT_NAME=""
ENV AGENT_NUMBER=""
ENV INSTANCE_ID=""
ENV AWS_REGION=""
ENV AZURE_DEVOPS_TOKEN_SECRET_ARN=""
ENV DEFAULT_CONTAINER_IMAGE="ubuntu:22.04"
ENV DEFAULT_VOLUMES="/var/run/docker.sock:/var/run/docker.sock,/cache:/cache,/data:/data"

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R azureagent:azureagent /opt/azagent

# Add labels with agent version
RUN AGENT_VERSION=$(cat /tmp/agent_version.txt 2>/dev/null || echo "unknown") && \
    echo "LABEL agent.version=$AGENT_VERSION" >> /tmp/labels.txt

# Metadata labels
LABEL maintainer="Nicolas HYPOLITE" \
      description="Azure DevOps Agent with AWS Secrets Manager integration" \
      org.opencontainers.image.source="https://github.com/hypolas/azure-agent"

USER azureagent

ENTRYPOINT ["/entrypoint.sh"]