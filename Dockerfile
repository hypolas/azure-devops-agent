# Stage temporaire pour extraire la version de l'agent
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

# Stage principal
FROM ubuntu:22.04

# Éviter les questions interactives pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive
# Ne pas installer les paquets recommandés pour réduire la taille
ENV APT_GET_INSTALL="apt-get install -y --no-install-recommends"

# Installer les dépendances nécessaires + dépendances .NET
RUN apt-get update && $APT_GET_INSTALL \
    curl \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    gnupg \
    sudo \
    jq \
    git \
    unzip \
    tar \
    grep \
    libicu70 \
    liblttng-ust1 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# aws-ssm est téléchargé directement depuis hypolas/aws-ssm-light
# Binaire pré-compilé léger (~10MB) vs AWS CLI (~100MB+)

# Copier la version de l'agent depuis le stage temporaire
COPY --from=temp-version /tmp/agent_version.txt /tmp/agent_version.txt

# Télécharger des binaires depuis GitHub
COPY download-github-binary.sh /tmp/
RUN chmod +x /tmp/download-github-binary.sh

# Variables pour configurer aws-ssm
# aws-ssm sera installé depuis hypolas/aws-ssm-light
ARG INSTALL_AWS_SSM="true"

# Installer aws-ssm (remplace AWS CLI pour Secrets Manager)
RUN if [ "$INSTALL_AWS_SSM" = "true" ]; then \
        echo "📦 Installation d'aws-ssm depuis hypolas/aws-ssm-light" && \
        /tmp/download-github-binary.sh "hypolas/aws-ssm-light" "aws-ssm" && \
        echo "✅ aws-ssm installé (~10MB vs ~100MB+ pour AWS CLI)" ; \
    fi && \
    rm -f /tmp/download-github-binary.sh

# Installer Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && $APT_GET_INSTALL docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Créer l'utilisateur azureagent
RUN useradd -m -s /bin/bash azureagent \
    && usermod -aG sudo azureagent \
    && echo "azureagent ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Créer les répertoires nécessaires
RUN mkdir -p /opt/azagent \
    && mkdir -p /opt/setup-scripts \
    && mkdir -p /cache \
    && mkdir -p /data \
    && chown -R azureagent:azureagent /opt/azagent \
    && chown -R azureagent:azureagent /opt/setup-scripts

# Télécharger l'agent Azure DevOps selon agent2.txt
WORKDIR /opt/azagent
RUN AGENT_VERSION=$(cat /tmp/agent_version.txt) && \
    echo "Téléchargement de l'agent Azure DevOps..." && \
    echo "Version détectée: $AGENT_VERSION" && \
    curl -fsSL "https://download.agent.dev.azure.com/agent/$AGENT_VERSION/vsts-agent-linux-x64-$AGENT_VERSION.tar.gz" -o "vsts-agent-linux-x64-$AGENT_VERSION.tar.gz" && \
    mkdir -p agent && \
    tar xzf "vsts-agent-linux-x64-$AGENT_VERSION.tar.gz" -C agent && \
    rm "vsts-agent-linux-x64-$AGENT_VERSION.tar.gz" && \
    chown -R azureagent:azureagent /opt/azagent

# Installer les dépendances .NET de l'agent Azure DevOps au build
RUN cd /opt/azagent/agent && \
    if [ -f "./bin/installdependencies.sh" ]; then \
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