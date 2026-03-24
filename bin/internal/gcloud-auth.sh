#!/usr/bin/env zsh
set -euo pipefail

# Authenticate gcloud for local dev:
#   1. gcloud CLI itself (needed for gcloud commands, e.g. WIF setup scripts)
#   2. Application Default Credentials with scopes for Sheets/Drive/Firebase
#      Uses a custom OAuth client (~/.config/gcloud/adc_client_secret.json) because
#      Google blocks Drive/Sheets scopes on the default gcloud client ID.
#   3. ADC quota project (required for Google Sheets API billing)

echo "==> Authenticating gcloud CLI..."
gcloud auth login

echo "==> Setting up Application Default Credentials (ADC)..."
# Scopes cover: Google Sheets (savival-kit), Firebase Admin SDK (pypack seeding),
# and general GCP API access.
gcloud auth application-default login \
    --client-id-file="$HOME/.config/gcloud/adc_client_secret.json" \
    --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/spreadsheets

echo "==> Setting ADC quota project to savi-security-dev..."
gcloud auth application-default set-quota-project savi-security-dev

