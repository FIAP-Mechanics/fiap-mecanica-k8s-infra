#!/usr/bin/env bash
set -euo pipefail

env=${1:?uso: aws-lab-secrets.sh <homologacao|producao>}
org=${GITHUB_ORG:-FIAP-Mechanics}
region=${AWS_REGION:-us-east-1}
account=$(aws sts get-caller-identity --query Account --output text)

k8s=fiap-mecanica-k8s-infra
dbs=fiap-mecanica-infra-dbs
lambda=fiap-mecanica-lambda
app=fiap-mecanica

eval "$(aws configure export-credentials --format env)"

set_var() { gh variable set "$2" --env "$env" --repo "$org/$1" --body "$3"; }
set_secret() { gh secret set "$2" --env "$env" --repo "$org/$1" --body "$3"; }

for repo in $k8s $dbs $lambda $app; do
  gh api -X PUT "repos/$org/$repo/environments/$env" > /dev/null
  set_var $repo TF_STATE_BUCKET "mecanica-tfstate-$account"
  set_var $repo AWS_REGION "$region"
  set_secret $repo AWS_ACCESS_KEY_ID "$AWS_ACCESS_KEY_ID"
  set_secret $repo AWS_SECRET_ACCESS_KEY "$AWS_SECRET_ACCESS_KEY"
  set_secret $repo AWS_SESSION_TOKEN "$AWS_SESSION_TOKEN"
done

if [ "${RENOVAR_APENAS_CREDENCIAIS:-}" = 1 ]; then
  echo "Credenciais da sessão atualizadas em $env nos 4 repositórios"
  exit 0
fi

rand() { openssl rand -hex "$1"; }
JWT_SECRET=${JWT_SECRET:-$(rand 32)}
DATABASE_PASSWORD=${DATABASE_PASSWORD:-$(rand 16)}
AUTH_CPF_DB_PASSWORD=${AUTH_CPF_DB_PASSWORD:-$(rand 16)}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(rand 8)}

set_secret $dbs DATABASE_PASSWORD "$DATABASE_PASSWORD"

set_secret $lambda JWT_SECRET "$JWT_SECRET"
set_secret $lambda AUTH_CPF_DB_PASSWORD "$AUTH_CPF_DB_PASSWORD"

set_secret $app JWT_SECRET "$JWT_SECRET"
set_secret $app DATABASE_PASSWORD "$DATABASE_PASSWORD"
set_secret $app AUTH_CPF_DB_PASSWORD "$AUTH_CPF_DB_PASSWORD"
set_secret $app ADMIN_PASSWORD "$ADMIN_PASSWORD"

if [ -n "${NEW_RELIC_LICENSE_KEY:-}" ]; then
  set_secret $app NEW_RELIC_LICENSE_KEY "$NEW_RELIC_LICENSE_KEY"
fi
for nome in NEW_RELIC_API_KEY NEW_RELIC_ACCOUNT_ID; do
  if [ -n "${!nome:-}" ]; then
    set_secret $k8s "$nome" "${!nome}"
  fi
done
if [ -n "${ALERT_EMAIL:-}" ]; then
  set_var $k8s ALERT_EMAIL "$ALERT_EMAIL"
fi

echo "Secrets de $env criados nos 4 repositórios. Guarde a senha do administrador: admin@mecanica.com / $ADMIN_PASSWORD"
