#!/usr/bin/env bash
# Löscht die Frontend-Infrastruktur von RefCard 05 wieder (Gegenstück zu setup-aws.sh).
# Nach der Bewertung ausführen, damit das Learner Lab kein Guthaben mehr verbraucht.
#
#   ./infra/teardown-aws.sh
#
# Reihenfolge: zuerst dieses Skript, danach infra/teardown-aws.sh im Backend-Repo
# (dort werden Load Balancer, Cluster und Security Groups gelöscht).
set -euo pipefail

cd "$(dirname "$0")"
source ./config.sh

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat <<EOF
Folgende Ressourcen im Account $ACCOUNT_ID ($AWS_REGION) werden gelöscht:

  ECS-Service      $FRONTEND_SERVICE
  Target Group     $TG_FRONTEND_NAME
  ECR-Repository   $FRONTEND_ECR_REPO  (alle Images)
  Log-Group        $FRONTEND_LOG_GROUP

EOF
read -r -p "Zum Bestätigen die Account-ID eingeben: " answer
[[ "$answer" == "$ACCOUNT_ID" ]] || { echo "Abgebrochen - nichts gelöscht."; exit 1; }

log "ECS-Service"
if [[ $(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$FRONTEND_SERVICE" \
  --query 'services[0].status' --output text 2>/dev/null) == "ACTIVE" ]]; then
  aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$FRONTEND_SERVICE" --force >/dev/null
  aws ecs wait services-inactive --cluster "$CLUSTER_NAME" --services "$FRONTEND_SERVICE"
fi

log "Load Balancer: Default-Regel zurücksetzen"
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)
if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
  LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" \
    --query 'Listeners[?Port==`80`].ListenerArn | [0]' --output text)
  # Eine Target Group lässt sich erst löschen, wenn kein Listener mehr auf sie verweist.
  aws elbv2 modify-listener --listener-arn "$LISTENER_ARN" \
    --default-actions 'Type=fixed-response,FixedResponseConfig={StatusCode=503,ContentType=text/plain,MessageBody=Frontend nicht deployt}' >/dev/null
fi

log "Target Group"
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_FRONTEND_NAME" \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)
if [[ -n "$TG_ARN" && "$TG_ARN" != "None" ]]; then
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
fi

log "ECR-Repository und Log-Group"
aws ecr delete-repository --repository-name "$FRONTEND_ECR_REPO" --force >/dev/null 2>&1 || true
aws logs delete-log-group --log-group-name "$FRONTEND_LOG_GROUP" 2>/dev/null || true

log "Fertig - jetzt infra/teardown-aws.sh im Backend-Repo ausführen."
