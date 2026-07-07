#!/usr/bin/env zsh
set -euo pipefail

echo "==> Authenticating Google Workspace CLI (gws)..."

# gws auth login's default scope set omits gmail.settings.basic, which the
# Gmail settings API (filters, forwarding, vacation) requires. --scopes replaces
# the default set rather than adding to it, so the full list must be enumerated.
# Note: gws 0.22.5 still shows its interactive scope picker on login and does not
# persist a selection, so gmail.settings.basic must be confirmed each time.
scopes=(
  email
  profile
  openid
  https://www.googleapis.com/auth/userinfo.email
  https://www.googleapis.com/auth/userinfo.profile
  https://www.googleapis.com/auth/calendar
  https://www.googleapis.com/auth/cloud-platform
  https://www.googleapis.com/auth/documents
  https://www.googleapis.com/auth/drive
  https://www.googleapis.com/auth/gmail.modify
  https://www.googleapis.com/auth/gmail.settings.basic
  https://www.googleapis.com/auth/presentations
  https://www.googleapis.com/auth/spreadsheets
  https://www.googleapis.com/auth/tasks
)
gws auth login --scopes "${(j:,:)scopes}"
