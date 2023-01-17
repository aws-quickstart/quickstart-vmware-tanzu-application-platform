#!/usr/bin/env bash

set -e
set -u
set -o pipefail

main() {
  local token="$(
    curl --silent --fail --location --request POST "${CLOUDGATE_BASE_URL}/authn/token" \
      --user "${CLOUDGATE_CLIENT_ID}:${CLOUDGATE_CLIENT_SECRET}" \
      --header 'Content-Type: application/json' \
      --data-raw '{ "grant_type": "client_credentials" }' \
      | jq -r .access_token
  )"

  curl --silent --fail --location --request POST "${CLOUDGATE_BASE_URL}/access/access" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $token" \
    --data-raw "{
          \"masterAccountId\": \"${CLOUDGATE_MASTER_ACCOUNT_ID}\",
          \"orgAccountId\": \"${CLOUDGATE_ORG_ACCOUNT_ID}\",
          \"ouId\": \"${CLOUDGATE_OU_ID}\",
          \"role\": \"PowerUser\",
          \"ttl\": ${CLOUDGATE_TTL}
    }" \
    > creds/access.json

  {
    jq -r '"export AWS_ACCESS_KEY_ID=\(.credentials.accessKeyId)"' creds/access.json
    jq -r '"export AWS_SECRET_ACCESS_KEY=\(.credentials.secretAccessKey)"' creds/access.json
    jq -r '"export AWS_SESSION_TOKEN=\(.credentials.sessionToken)"' creds/access.json
  } > creds/env.inc.sh
}

main "$@"
