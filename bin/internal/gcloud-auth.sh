#!/usr/bin/env zsh
set -euo pipefail

# Authenticate everything Google-related for local dev in one shot:
#   1. gcloud CLI itself (needed for gcloud commands, e.g. WIF setup scripts)
#   2. Application Default Credentials with scopes for Sheets/Drive/Firebase
#   3. ADC quota project (required for Google Sheets API billing)
#   4. Google Workspace CLI (gws) — separate OAuth client, bundled for convenience

echo "==> Authenticating gcloud CLI..."
gcloud auth login

echo "==> Setting up Application Default Credentials (ADC)..."
# Scopes cover: Google Sheets (savival-kit), Firebase Admin SDK (pypack seeding),
# and general GCP API access.
gcloud auth application-default login \
    --scopes=https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/spreadsheets

echo "==> Setting ADC quota project to savi-security-dev..."
gcloud auth application-default set-quota-project savi-security-dev

echo "==> Authenticating Google Workspace CLI (gws)..."
gws auth login
