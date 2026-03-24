#!/usr/bin/env zsh
set -euo pipefail

# Upload a markdown file to Google Docs (pageless mode).
#
# Usage:
#   push-to-gdoc <file.md> [--name "Doc Title"] [--parent FOLDER_ID]
#
# If --name is not provided, the filename (without extension) is used as the doc title.
# The file is converted from markdown to a Google Doc via Drive's built-in conversion.

local file=""
local name=""
local parent=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            name="$2"
            shift 2
            ;;
        --parent)
            parent="$2"
            shift 2
            ;;
        -*)
            echo "Unknown flag: $1" >&2
            exit 1
            ;;
        *)
            if [[ -z "$file" ]]; then
                file="$1"
            else
                echo "Unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$file" ]]; then
    echo "Usage: push-to-gdoc <file.md> [--name \"Doc Title\"] [--parent FOLDER_ID]" >&2
    exit 1
fi

if [[ ! -f "$file" ]]; then
    echo "File not found: $file" >&2
    exit 1
fi

# Default doc title to filename without extension
if [[ -z "$name" ]]; then
    name="${$(basename "$file")%.*}"
fi

# Build the metadata JSON for the Drive API
local metadata='{"name": "'"$name"'", "mimeType": "application/vnd.google-apps.document"}'
if [[ -n "$parent" ]]; then
    metadata='{"name": "'"$name"'", "mimeType": "application/vnd.google-apps.document", "parents": ["'"$parent"'"]}'
fi

# Upload markdown file, converting to Google Doc
echo "Uploading '$file' as Google Doc: $name"
local response
response=$(
    gws drive files create \
        --params '{"uploadType": "multipart", "supportsAllDrives": true}' \
        --json "$metadata" \
        --upload "$file" \
        --upload-content-type text/markdown
)

local doc_id
doc_id=$(echo "$response" | jq -r '.id')

if [[ -z "$doc_id" || "$doc_id" == "null" ]]; then
    echo "Failed to create Google Doc" >&2
    echo "$response" >&2
    exit 1
fi

# Set pageless mode
gws docs documents batchUpdate \
    --params '{"documentId": "'"$doc_id"'"}' \
    --json '{"requests": [{"updateDocumentStyle": {"documentStyle": {"documentFormat": {"documentMode": "PAGELESS"}}, "fields": "documentFormat"}}]}' \
    > /dev/null

local url="https://docs.google.com/document/d/$doc_id/edit"
echo "Created: $url"
