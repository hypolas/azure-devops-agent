# Stage 1: Extraire la version de l'agent
FROM ubuntu:22.04 AS temp-version

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    grep \
    && rm -rf /var/lib/apt/lists/*

RUN AGENT_VERSION=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | grep -oP '"tag_name": "v\K(.*)(?=")') && \
    echo "$AGENT_VERSION" > /tmp/agent_version.txt && \
    echo "Version détectée: $AGENT_VERSION"

# Stage 2: Télécharger l'agent Azure DevOps
FROM ubuntu:22.04 AS agent-downloader

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    tar \
    && rm -rf /var/lib/apt/lists/*

COPY --from=temp-version /tmp/agent_version.txt /tmp/agent_version.txt

RUN AGENT_VERSION=$(cat /tmp/agent_version.txt) && \
    echo "Téléchargement de l'agent Azure DevOps..." && \
    echo "Version détectée: $AGENT_VERSION" && \
    \
    # Détecter l'architecture pour choisir le bon agent
    ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m) && \
    case "$ARCH" in \
        amd64|x86_64) AGENT_ARCH="x64" ;; \
        arm64|aarch64) AGENT_ARCH="arm64" ;; \
        armhf|armv7l|armv7) AGENT_ARCH="arm" ;; \
        *) echo "⚠️ Architecture non supportée: $ARCH, utilisation de x64 par défaut" && AGENT_ARCH="x64" ;; \
    esac && \
    \
    echo "Architecture détectée: $ARCH -> Agent: linux-$AGENT_ARCH" && \
    mkdir -p /opt/azagent/agent && \
    curl -fsSL "https://download.agent.dev.azure.com/agent/$AGENT_VERSION/vsts-agent-linux-$AGENT_ARCH-$AGENT_VERSION.tar.gz" -o "/tmp/agent.tar.gz" && \
    tar xzf "/tmp/agent.tar.gz" -C /opt/azagent/agent && \
    rm "/tmp/agent.tar.gz"

# Stage 3: Télécharger aws-ssm
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
    /tmp/download-github-binary.sh "hypolas/aws-ssm-light" "aws-ssm"

# Stage 4: Télécharger Docker CLI
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

# Stage final: Image runtime minimale
FROM ubuntu:22.04

# Éviter les questions interactives pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive
# Installer seulement les dépendances runtime nécessaires
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    jq \
    git \
    # Dépendances .NET runtime pour l'agent Azure DevOps
    libicu70 \
    liblttng-ust1 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copier les binaires depuis les stages de build
COPY --from=temp-version /tmp/agent_version.txt /tmp/agent_version.txt
COPY --from=agent-downloader /opt/azagent/ /opt/azagent/
COPY --from=agent-downloader /opt/azagent/agent/ /opt/azagent/agent/
COPY --from=aws-ssm-downloader /usr/local/bin/aws-ssm /usr/local/bin/aws-ssm
COPY --from=docker-downloader /usr/bin/docker /usr/bin/docker
COPY --from=docker-downloader /usr/libexec/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose

# Créer l'utilisateur azureagent
RUN useradd -m -s /bin/bash azureagent \
    && usermod -aG sudo azureagent \
    && echo "azureagent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates

# Créer les répertoires nécessaires et ajuster les permissions
RUN mkdir -p /opt/setup-scripts \
    && mkdir -p /cache \
    && mkdir -p /data \
    && mkdir -p /usr/libexec/docker/cli-plugins \
    && chown -R azureagent:azureagent /opt/azagent \
    && chown -R azureagent:azureagent /opt/setup-scripts \
    && chmod +x /usr/local/bin/aws-ssm \
    && chmod +x /usr/bin/docker \
    && chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# Installer les dépendances .NET de l'agent Azure DevOps au build
WORKDIR /opt/azagent
RUN if [ -f "./bin/installdependencies.sh" ]; then \
        echo "Installation des dépendances .NET de l'agent Azure DevOps..." && \
        ./bin/installdependencies.sh; \
    fi && \
    chown -R azureagent:azureagent /opt/azagent

# Copier les scripts de configuration
COPY scripts/ /opt/setup-scripts/
RUN chmod +x /opt/setup-scripts/*.sh \
    && chown -R azureagent:azureagent /opt/setup-scripts

# Variables d'environnement par défaut
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

# Exposer le répertoire de travail
VOLUME ["/cache", "/data"]

# Script d'entrée
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chown -R azureagent:azureagent /opt/azagent

# Ajouter des labels avec la version de l'agent
RUN AGENT_VERSION=$(cat /tmp/agent_version.txt 2>/dev/null || echo "unknown") && \
    echo "LABEL agent.version=$AGENT_VERSION" >> /tmp/labels.txt

# Labels pour métadonnées
LABEL maintainer="hypolas" \
      description="Azure DevOps Agent avec intégration AWS Secrets Manager" \
      org.opencontainers.image.source="https://github.com/hypolas/azure-agent"

USER azureagent
WORKDIR /opt/azagent

ENTRYPOINT ["/entrypoint.sh"]