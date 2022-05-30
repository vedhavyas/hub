#!/bin/zsh
set -e
GOTIFY_TITLE="$1"
GOTIFY_MESSAGE="$2"
test -z $GOTIFY_TOKEN && { echo "GOTIFY_TOKEN missing"; exit 1 }
test -z $GOTIFY_TITLE && { echo "GOTIFY_TITLE missing"; exit 1 }
test -z $GOTIFY_MESSAGE && { echo "GOTIFY_MESSAGE missing"; exit 1 }

echo "sending message to notifier..."
curl --insecure -X POST "https://notifier.hub/message?token=$GOTIFY_TOKEN" -F "title=${GOTIFY_TITLE}" -F "message=${GOTIFY_MESSAGE}" &> /dev/null
echo "sent."
