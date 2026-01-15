#!/usr/bin/env bash

TOKEN_SOURCE=/home/guc/next-app/goldies-next/.env
REFRESH_ENDPOINT=https://graph.instagram.com/refresh_access_token
# use the following endpoint for testing
# REFRESH_ENDPOINT=https://dummyjson.com/c/6ad4-af8a-4a3c-a049
TEMP_JAR=$(mktemp)
TEMP_ENV=$(mktemp)

function send_notification {
  local TAG
  local PRIO

  if [ "${2}" = "info" ]; then
    TAG="Tags: white_check_mark"
    PRIO="Priority: default"
  else
    TAG="Tags: warning"
    PRIO="Priority: high"
  fi
  curl -sS --fail \
       -H "$TAG" \
       -H "$PRIO" \
       -H "Title: IG Token Update" \
       -d "${1}" \
       "https://ntfy.sh/${TOPIC_KEY}"
}

# read current token
source "${TOKEN_SOURCE}"

# calling token refresh endpoint
if ! curl -sS --fail "${REFRESH_ENDPOINT}?grant_type=ig_refresh_token&access_token=${INSTAGRAM_ACCESS_TOKEN}" -o "${TEMP_JAR}"
then
  send_notification "Refresh failed! Next-js is probably still running but the token might expire" "warning"
  exit 1
fi

# retrieving token and validity duration from response
NEW_TOKEN=$(jq -r '.access_token' "${TEMP_JAR}")
EXPIRES=$(jq -r '.expires_in' "${TEMP_JAR}")

# computing new expiration date
TODAY_EPOCH=$(date +'%s')
EXPIRES_AT_EPOCH=$((TODAY_EPOCH + EXPIRES))
EXPIRES_AT=$(date -d @$EXPIRES_AT_EPOCH)

cat <<EOF > "${TEMP_ENV}"
INSTAGRAM_ACCESS_TOKEN=${NEW_TOKEN}
INSTAGRAM_CLIENT_TOKEN=${INSTAGRAM_CLIENT_TOKEN}
EOF

# Copy the new env file to its final path
cp -b "${TEMP_ENV}" "${TOKEN_SOURCE}"

# clean up 
rm "${TEMP_ENV}" "${TEMP_JAR}"

# restart nextjs
if ! supervisorctl restart goldies-next
then
  send_notification "Token refreshed but restarting application failed!" "warning"
  exit 1
fi

SUCCESS_MESSAGE=$(printf "Refresh succeeded!\nNew token is valid until %s" "${EXPIRES_AT}")
send_notification "${SUCCESS_MESSAGE}" "info"
