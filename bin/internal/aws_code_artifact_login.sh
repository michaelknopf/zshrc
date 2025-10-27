#!/usr/bin/env bash

set -euo pipefail

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") TOOL [ENV]

Login to AWS CodeArtifact for the specified tool and environment.

Arguments:
    TOOL    The package manager tool (npm, pip, twine, etc.)
    ENV     Environment: 'test' or 'release' (default: test)

Examples:
    $(basename "$0") npm
    $(basename "$0") npm test
    $(basename "$0") pip release

EOF
    exit 1
}

# Check for help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    usage
fi

# Validate tool argument
if [[ $# -lt 1 ]]; then
    echo "Error: TOOL argument is required" >&2
    usage
fi

TOOL="$1"
ENV="${2:-test}"
DOMAIN="savi"

# Validate environment
if [[ "$ENV" != "test" ]] && [[ "$ENV" != "release" ]]; then
    echo "Error: ENV must be 'test' or 'release', got '$ENV'" >&2
    exit 1
fi

# Set TOOL to pip for Python-related tools
case "$TOOL" in
    python|pip|pypi)
        TOOL="pip"
        REPO="pypi-${ENV}"
        ;;
    node|npm|pnpm)
        TOOL="npm"
        REPO="npm-${ENV}"
        ;;
esac

echo "Logging in to CodeArtifact..."
echo "  Domain: $DOMAIN"
echo "  Repository: $REPO"
echo "  Tool: $TOOL"
echo

aws codeartifact login \
    --profile "infra-admin" \
    --domain-owner "073835883885" \
    --domain "$DOMAIN" \
    --repository "$REPO" \
    --tool "$TOOL"
