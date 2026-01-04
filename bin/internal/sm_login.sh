#!/bin/zsh

export AWS_PROFILE=${AWS_PROFILE:-test-sso-admin}

# Get pre-signed login URL for Sagemaker Studio
URL=$(
    aws sagemaker create-presigned-domain-url \
    --domain-id d-6x9psqzq2ixo \
    --user-profile-name mknopf \
    --region us-west-2 \
    | jq -r .AuthorizedUrl
)

# Open URL in browser
open "$URL"

# Now your cookies are set!
