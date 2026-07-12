#!/usr/bin/env zsh
set -euo pipefail

# Keeps the CodeArtifact + ECR tokens fresh, unattended.
#
# Those services don't take our device cert directly — they take a bearer token
# that expires (~12h). `--skip-aws-sso` mints one via the Secure Enclave cert
# (Roles Anywhere) instead of a browser SSO session, which is the whole reason
# this can run under launchd at all: there is nothing to click.
#
# Requires the login keychain to be unlocked (the Enclave key lives there), so it
# is a LaunchAgent — user session only — not a LaunchDaemon.

# launchd hands us a bare PATH (/usr/bin:/bin:/usr/sbin:/sbin) and no profile.
# savi-login shells out to aws + aws_signing_helper, and the CodeArtifact logins
# drive npm/docker, so every tool's directory has to be named explicitly.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/.volta/bin:$PATH"

# Offline is the common case for a laptop on a timer; a failed token refresh here
# is noise, not news. Exit quietly and let the next tick handle it.
#
# TCP, not ping: AWS drops ICMP, so a ping check reports "offline" on a perfectly
# healthy network and the job silently never refreshes anything.
if ! /usr/bin/nc -z -G2 codeartifact.us-west-2.amazonaws.com 443 >/dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] offline — skipping refresh"
  exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] refreshing CodeArtifact + ECR via device cert"
savi-login --skip-aws-sso
echo "[$(date '+%Y-%m-%d %H:%M:%S')] done"
