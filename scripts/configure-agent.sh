#!/bin/bash
# Script de configuration de l'agent Azure DevOps
# Arguments: $1=INSTALL_FOLDER, $2=AZP_URL, $3=AZP_TOKEN, $4=AZP_POOL, $5=AZP_AGENT_NAME, $6=AGENT_NUMBER, $7=INSTANCE_ID

set -e

INSTALL_FOLDER=$1
AZP_URL=$2
AZP_TOKEN=$3
AZP_POOL=$4
AZP_AGENT_NAME=$5
AGENT_NUMBER=$6
INSTANCE_ID=$7

echo "Répertoire de l'agent: $INSTALL_FOLDER"
echo "Configuration de l'agent ${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID}..."

# Créer le répertoire pour cette instance
mkdir -p "/opt/azagent/$AGENT_NUMBER"

# Copier les fichiers de l'agent depuis le dossier agent
cp -r "$INSTALL_FOLDER/agent"/* "/opt/azagent/$AGENT_NUMBER/"

# Aller dans le répertoire de l'agent
cd "/opt/azagent/$AGENT_NUMBER"

# Configurer l'agent
./config.sh \
  --unattended \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --agent "${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID}" \
  --work "/opt/azagent/${AGENT_NUMBER}/_work" \
  --replace \
  --acceptTeeEula

echo "Agent ${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID} configuré avec succès."