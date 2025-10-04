#!/bin/bash
# Azure DevOps agent configuration script
# Arguments: $1=INSTALL_FOLDER, $2=AZP_URL, $3=AZP_TOKEN, $4=AZP_POOL, $5=AZP_AGENT_NAME, $6=AGENT_NUMBER, $7=INSTANCE_ID

set -e

INSTALL_FOLDER=$1
AZP_URL=$2
AZP_TOKEN=$3
AZP_POOL=$4
AZP_AGENT_NAME=$5
AGENT_NUMBER=$6
INSTANCE_ID=$7

echo "Agent directory: $INSTALL_FOLDER"
echo "Configuring agent ${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID}..."

# Create directory for this instance
sudo mkdir -p "$INSTALL_FOLDER/$AGENT_NUMBER" && sudo chown azureagent:azureagent "$INSTALL_FOLDER/$AGENT_NUMBER"

# Copy agent files from agent folder
cp -r "/opt/dl/"* "$INSTALL_FOLDER/$AGENT_NUMBER/"

# Go to agent directory
cd "$INSTALL_FOLDER/$AGENT_NUMBER"

# Configure the agent
./config.sh \
  --unattended \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --agent "${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID}" \
  --work "${INSTALL_FOLDER}/${AGENT_NUMBER}/_work" \
  --replace \
  --acceptTeeEula

echo "Agent ${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID} configured successfully."