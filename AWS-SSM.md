# Binaire AWS SSM

**aws-ssm** est automatiquement installé depuis le dépôt `hypolas/aws-ssm-light`.

## Avantages du binaire aws-ssm
- ✅ **Léger** : ~10MB vs ~100MB+ pour AWS CLI
- ✅ **Rapide** : ~50ms vs ~1-2s pour AWS CLI
- ✅ **Sécurisé** : Tests automatisés, checksums SHA256
- ✅ **Maintenu** : Dépôt avec CI/CD
- ✅ **Compatible** : Syntaxe simple `aws-ssm <secret-id> [region]`

## Installation

L'installation est automatique avec `INSTALL_AWS_SSM=true` (par défaut) :

```bash
# Build standard avec aws-ssm
podman build -t azure-agent .

# Ou désactiver aws-ssm
podman build --build-arg INSTALL_AWS_SSM=false -t azure-agent .
```

## Configuration via docker-compose

```yaml
build:
  context: .
  args:
    INSTALL_AWS_SSM: "true"  # Installer aws-ssm (défaut)
```

## Utilisation dans l'agent

L'agent utilisera automatiquement `aws-ssm` si disponible :

```bash
# Au lieu de AWS CLI (100MB+, lent) :
aws secretsmanager get-secret-value --region us-east-1 --secret-id "my-secret" --query SecretString --output text

# L'agent utilisera aws-ssm (10MB, rapide) :
aws-ssm "my-secret" "us-east-1"
```

### Performance

| Outil | Taille | RAM | Temps |
|-------|--------|-----|-------|
| AWS CLI | ~100MB+ | ~50MB+ | ~1-2s |
| aws-ssm | ~10MB | ~5MB | ~50ms |

## Utilisation dans l'agent

L'agent utilisera automatiquement `aws-ssm` si disponible :

```bash
# Au lieu de AWS CLI (100MB+, lent) :
aws secretsmanager get-secret-value --region us-east-1 --secret-id "my-secret" --query SecretString --output text

# L'agent utilisera aws-ssm (10MB, rapide) :
aws-ssm "my-secret" "us-east-1"
```

## Performance

| Outil | Taille | RAM | Temps |
|-------|--------|-----|-------|
| AWS CLI | ~100MB+ | ~50MB+ | ~1-2s |
| aws-ssm | ~10MB | ~5MB | ~50ms |