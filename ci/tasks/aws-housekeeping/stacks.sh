#!/usr/bin/env bash

set -e
set -u
set -o pipefail

. creds/env.inc.sh

# TODO: auto-cleanup failed stacks; for now, just report
main() {
  local rc=0

  echo >&2 -e '⚠️ failed stacks:'
  failedStacks || rc=$(( rc | $? ))

  echo >&2
  echo >&2 -e '🕧 old stacks:'
  oldStacks || rc=$(( rc | $? ))

  return $rc
}

cleanStackList() {
  jq 'map(del(.TemplateDescription, .DriftInformation))'
}

isEmpty() {
  jq -e 'length < 1' >/dev/null
}

oldStacks() {
  local cutOffDate="$( date -u --date "${OLD_AFTER:-3 days} ago" '+%F' )"
  listStacks \
    'StackSummaries[?CreationTime<=`'"$cutOffDate"'`]' \
    'CREATE_COMPLETE'
}

failedStacks() {
  listStacks \
    'StackSummaries[]' \
    'CREATE_FAILED' 'DELETE_FAILED' 'ROLLBACK_FAILED' 'UPDATE_FAILED'
}

listStacks() {
  local query="$1" ; shift

  local res='[]'

  for r in ${REGIONS:-us-east-1} ; do
    regionData="$(
      aws cloudformation list-stacks \
        --region "$r" \
        --stack-status-filter "$@" \
        --query "$query" \
        --output json \
        | jq --arg region "$r" '.[].Region = $region'
    )"

    isEmpty <<< "$regionData" && continue

    res="$( jq --argjson new "$regionData" '. + $new' <<< "$res" )"
  done

  cleanStackList <<< "$res"

  isEmpty <<< "$res" && {
    return 1
  }
}

main "$@"
