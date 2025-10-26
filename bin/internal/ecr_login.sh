#!/usr/bin/env zsh
set -euo pipefail

export AWS_PROFILE='infra-admin'

# get region from current profile
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
  echo "No region set in the current AWS profile" >&2
  exit 1
fi

# get account ID from current credentials
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

echo "Logging into ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region "$REGION" \
| docker login \
    --username AWS \
    --password-stdin \
    "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
