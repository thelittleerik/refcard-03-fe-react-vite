#!/usr/bin/env bash
# Legt die Frontend-Infrastruktur von RefCard 05 im AWS Academy Learner Lab an:
# ECR-Repository, Log-Group, Target Group, Default-Regel am Load Balancer und den ECS-Service.
# Idempotent: bereits vorhandene Ressourcen werden wiederverwendet.
#
# Voraussetzung: Das Backend-Repo hat mit seinem infra/setup-aws.sh bereits Cluster, Load Balancer
# und Security Groups angelegt, und ~/.aws/credentials enthält gültige Learner-Lab-Zugangsdaten.
set -euo pipefail

cd "$(dirname "$0")"
source ./config.sh

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { echo "Fehler: $*" >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=availability-zone,Values=$(IFS=,; echo "${AZS[*]}")" \
  --query 'Subnets[].SubnetId' --output text)

log "Gemeinsame Infrastruktur prüfen"
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null) \
  || die "Load Balancer '$ALB_NAME' fehlt. Zuerst infra/setup-aws.sh im Backend-Repo ausführen."
ALB_DNS=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query 'LoadBalancers[0].DNSName' --output text)
LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" \
  --query 'Listeners[?Port==`80`].ListenerArn | [0]' --output text)
SG_FRONTEND=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$SG_FRONTEND_NAME" \
  --query 'SecurityGroups[0].GroupId' --output text)
[[ "$LISTENER_ARN" != "None" && "$SG_FRONTEND" != "None" ]] \
  || die "Listener oder Security Group '$SG_FRONTEND_NAME' fehlt. Zuerst infra/setup-aws.sh im Backend-Repo ausführen."
[[ $(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --query 'clusters[0].status' --output text) == "ACTIVE" ]] \
  || die "ECS-Cluster '$CLUSTER_NAME' fehlt. Zuerst infra/setup-aws.sh im Backend-Repo ausführen."
echo "ok"

log "ECR-Repository ($FRONTEND_ECR_REPO)"
if ! aws ecr describe-repositories --repository-names "$FRONTEND_ECR_REPO" >/dev/null 2>&1; then
  aws ecr create-repository --repository-name "$FRONTEND_ECR_REPO" \
    --image-scanning-configuration scanOnPush=true >/dev/null
fi
aws ecr put-lifecycle-policy --repository-name "$FRONTEND_ECR_REPO" \
  --lifecycle-policy-text file://ecr-lifecycle-policy.json >/dev/null

log "CloudWatch-Log-Group ($FRONTEND_LOG_GROUP)"
aws logs create-log-group --log-group-name "$FRONTEND_LOG_GROUP" 2>/dev/null || true
aws logs put-retention-policy --log-group-name "$FRONTEND_LOG_GROUP" --retention-in-days 7

log "Target Group ($TG_FRONTEND_NAME)"
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_FRONTEND_NAME" \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)
if [[ -z "$TG_ARN" || "$TG_ARN" == "None" ]]; then
  TG_ARN=$(aws elbv2 create-target-group --name "$TG_FRONTEND_NAME" \
    --protocol HTTP --port 80 --vpc-id "$VPC_ID" --target-type ip \
    --health-check-path /healthz --health-check-interval-seconds 15 \
    --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3 \
    --matcher HttpCode=200 \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
fi
aws elbv2 modify-target-group-attributes --target-group-arn "$TG_ARN" \
  --attributes Key=deregistration_delay.timeout_seconds,Value=15 >/dev/null

log "Load Balancer: alles ausser der API geht ans Frontend"
aws elbv2 modify-listener --listener-arn "$LISTENER_ARN" \
  --default-actions "Type=forward,TargetGroupArn=$TG_ARN" >/dev/null

log "ECS-Service ($FRONTEND_SERVICE)"
if [[ $(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$FRONTEND_SERVICE" \
  --query 'services[0].status' --output text) != "ACTIVE" ]]; then
  aws ecs register-task-definition --cli-input-json file://../task-definition.json >/dev/null
  # Start mit 0 Tasks: das erste Image liefert die Pipeline, sie setzt danach auch die Task-Anzahl.
  aws ecs create-service --cluster "$CLUSTER_NAME" --service-name "$FRONTEND_SERVICE" \
    --task-definition "$FRONTEND_FAMILY" --desired-count 0 --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_IDS//$'\t'/,}],securityGroups=[$SG_FRONTEND],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=$TG_ARN,containerName=$FRONTEND_FAMILY,containerPort=80" \
    --health-check-grace-period-seconds 30 \
    --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},minimumHealthyPercent=100,maximumPercent=200" \
    --tags key=project,value=refcard05 >/dev/null
fi

log "Fertig"
cat <<EOF

Account         : $ACCOUNT_ID
Applikation     : http://$ALB_DNS
ECR (Frontend)  : $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$FRONTEND_ECR_REPO

Backend-URL fürs Frontend als Repository-Variable setzen (wird beim Build fest ins Bundle kompiliert):
  gh variable set VITE_API_BASE_URL --body "http://$ALB_DNS/"
EOF
