#!/usr/bin/env bash
# Namen der AWS-Ressourcen des Frontends (RefCard 05).
# Cluster, Load Balancer und Security Groups legt das Backend-Repo an (infra/setup-aws.sh dort) -
# die Namen hier müssen mit dessen infra/config.sh übereinstimmen.
# Enthält bewusst keine Zugangsdaten und keine Account-ID.

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_PAGER=""

PROJECT="biztrips"

# Gemeinsam genutzt (vom Backend-Repo angelegt)
CLUSTER_NAME="${PROJECT}-cluster"
ALB_NAME="${PROJECT}-alb"
SG_FRONTEND_NAME="${PROJECT}-frontend-sg"
AZS=("us-east-1a" "us-east-1b" "us-east-1c")

# Nur Frontend
FRONTEND_ECR_REPO="${PROJECT}-frontend"
FRONTEND_SERVICE="${PROJECT}-frontend-service"
FRONTEND_FAMILY="${PROJECT}-frontend"
FRONTEND_LOG_GROUP="/ecs/${PROJECT}-frontend"
TG_FRONTEND_NAME="${PROJECT}-frontend-tg"
