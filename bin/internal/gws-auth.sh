#!/usr/bin/env zsh
set -euo pipefail

echo "==> Authenticating Google Workspace CLI (gws)..."
gws auth login
