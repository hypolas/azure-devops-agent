#!/bin/bash
set -e

# Vérification des variables d'environnement obligatoires
if [ -z "$AZP_URL" ]; then
    echo "Erreur: AZP_URL doit être défini"
    exit 1
fi

# Récupération du token Azure DevOps via AWS Secrets Manager si pas de token fourni
if [ -z "$AZP_TOKEN" ]; then
    if [ -n "$AZURE_DEVOPS_TOKEN_SECRET_ARN" ] && [ -n "$AWS_REGION" ]; then
        echo "Récupération du token Azure DevOps depuis AWS Secrets Manager..."
        
        # Utiliser aws-ssm officiel (hypolas/aws-ssm-light) en priorité
        if command -v aws-ssm >/dev/null 2>&1; then
            echo "Utilisation d'aws-ssm (hypolas/aws-ssm-light)..."
            # Syntaxe: aws-ssm <secret-id> [region]
            SECRET_TOKEN=$(aws-ssm "$AZURE_DEVOPS_TOKEN_SECRET_ARN" "$AWS_REGION" 2>/dev/null)
        elif command -v light_ssm >/dev/null 2>&1; then
            echo "Utilisation de light_ssm (fallback)..."
            SECRET_TOKEN=$(light_ssm "$AZURE_DEVOPS_TOKEN_SECRET_ARN" "$AWS_REGION" 2>/dev/null)
        else
            echo "❌ Aucun client AWS Secrets Manager disponible (aws-ssm ou light_ssm)"
            echo "Installez aws-ssm depuis hypolas/aws-ssm-light ou activez INSTALL_AWS_SSM=true"
            exit 1
        fi
        
        if [ -n "$SECRET_TOKEN" ] && [ "$SECRET_TOKEN" != "null" ]; then
            AZP_TOKEN="$SECRET_TOKEN"
            echo "✅ Token récupéré depuis AWS Secrets Manager"
        else
            echo "❌ Échec de récupération du token depuis Secrets Manager"
            exit 1
        fi
    else
        echo "❌ AZP_TOKEN non fourni et AWS Secrets Manager non configuré"
        echo "Fournissez soit AZP_TOKEN, soit AWS_REGION + AZURE_DEVOPS_TOKEN_SECRET_ARN"
        exit 1
    fi
else
    echo "✅ Token Azure DevOps fourni directement"
fi

if [ -z "$AZP_POOL" ]; then
    echo "Erreur: AZP_POOL doit être défini"
    exit 1
fi

if [ -z "$AGENT_NUMBER" ]; then
    echo "Erreur: AGENT_NUMBER doit être défini"
    exit 1
fi

# Définir les valeurs par défaut si nécessaire
INSTALL_FOLDER=${INSTALL_FOLDER:-"/opt/azagent"}
DEFAULT_CONTAINER_IMAGE=${DEFAULT_CONTAINER_IMAGE:-"ubuntu:22.04"}
DEFAULT_VOLUMES=${DEFAULT_VOLUMES:-"/var/run/docker.sock:/var/run/docker.sock,/cache:/cache,/data:/data"}

# Récupérer l'INSTANCE_ID depuis les métadonnées AWS si non fourni
if [ -z "$INSTANCE_ID" ]; then
    echo "Récupération de l'INSTANCE_ID depuis AWS avec IMDSv2..."
    
    # Récupérer le token IMDSv2 pour sécuriser l'accès aux métadonnées
    IMDS_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
        -s 2>/dev/null)
    
    if [ -n "$IMDS_TOKEN" ]; then
        # Utiliser le token pour récupérer l'instance ID
        INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
            -s "http://169.254.169.254/latest/meta-data/instance-id" 2>/dev/null)
    fi
    
    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "" ]; then
        echo "Attention: Impossible de récupérer l'INSTANCE_ID AWS, utilisation de 'local'"
        INSTANCE_ID="local"
    else
        echo "INSTANCE_ID récupéré: $INSTANCE_ID"
    fi
fi

echo "=========================================="
echo "Configuration de l'agent Azure DevOps"
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

# Configurer l'agent
echo "Configuration de l'agent Azure DevOps..."
/opt/setup-scripts/configure-agent.sh \
    "$INSTALL_FOLDER" \
    "$AZP_URL" \
    "$AZP_TOKEN" \
    "$AZP_POOL" \
    "$AZP_AGENT_NAME" \
    "$AGENT_NUMBER" \
    "$INSTANCE_ID"

# Ajouter les capabilities
echo "Ajout des capabilities..."
/opt/setup-scripts/add-capabilities.sh \
    "$DEFAULT_CONTAINER_IMAGE" \
    "$DEFAULT_VOLUMES" \
    "$AGENT_NUMBER"

echo "Configuration terminée. Démarrage de l'agent..."

# Démarrer l'agent
echo "Démarrage de l'agent ${AZP_AGENT_NAME}-${AGENT_NUMBER}-${INSTANCE_ID}..."
cd "/opt/azagent/$AGENT_NUMBER"
./run.sh