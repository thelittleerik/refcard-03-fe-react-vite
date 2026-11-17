#!/usr/bin/env bash
# Überträgt die temporären Learner-Lab-Zugangsdaten aus der lokalen AWS-CLI-Konfiguration
# als GitHub Secrets (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN).
# Nach jedem Neustart der Lab-Session ausführen - die alten Werte sind dann ungültig.
#
#   ./scripts/refresh-lab-secrets.sh                      # nur dieses Repo
#   ./scripts/refresh-lab-secrets.sh owner/repo-a owner/repo-b
#
# Vorher: Werte aus "AWS Details -> AWS CLI" nach ~/.aws/credentials kopieren.
# Die Werte werden nie ausgegeben und nie als Kommandozeilenargument übergeben.
set -euo pipefail

if (( $# )); then
  repos=("$@")
else
  origin=$(git -C "$(dirname "$0")/.." remote get-url origin)
  origin=${origin%.git}
  repos=("${origin#*github.com[:/]}")
fi

if ! identity=$(aws sts get-caller-identity --query Arn --output text 2>&1); then
  echo "Die lokalen AWS-Zugangsdaten sind ungültig oder abgelaufen:" >&2
  echo "  $identity" >&2
  echo "Lab starten und die Werte aus 'AWS Details -> AWS CLI' nach ~/.aws/credentials kopieren." >&2
  exit 1
fi
echo "Lab-Session gültig: $identity"

for repo in "${repos[@]}"; do
  for name in aws_access_key_id aws_secret_access_key aws_session_token; do
    value=$(aws configure get "$name") || { echo "$name fehlt in der AWS-CLI-Konfiguration" >&2; exit 1; }
    printf '%s' "$value" | gh secret set "${name^^}" --repo "$repo"
  done
  unset value
  echo "Secrets aktualisiert: $repo"
done
