#!/usr/bin/env bash
set -euo pipefail

org=${GITHUB_ORG:-FIAP-Mechanics}
avaliador=${AVALIADOR:-soat-architecture}
aprovacoes=${APROVACOES_OBRIGATORIAS:-0}
repos=(fiap-mecanica fiap-mecanica-lambda fiap-mecanica-k8s-infra fiap-mecanica-infra-dbs)

ruleset=$(cat <<JSON
{
  "name": "proteger-main-e-homologacao",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/main", "refs/heads/homologacao"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": $aprovacoes,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false } }
  ]
}
JSON
)

for repo in "${repos[@]}"; do
  existente=$(gh api "repos/$org/$repo/rulesets" --jq '.[] | select(.name == "proteger-main-e-homologacao") | .id')
  if [ -n "$existente" ]; then
    echo "$ruleset" | gh api -X PUT "repos/$org/$repo/rulesets/$existente" --input - > /dev/null
  else
    echo "$ruleset" | gh api -X POST "repos/$org/$repo/rulesets" --input - > /dev/null
  fi
  gh api -X PUT "repos/$org/$repo/collaborators/$avaliador" -f permission=pull > /dev/null
  echo "$repo: ruleset aplicado e convite enviado a $avaliador"
done
