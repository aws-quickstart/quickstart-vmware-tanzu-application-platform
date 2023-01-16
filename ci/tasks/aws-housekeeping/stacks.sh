#!/usr/bin/env bash

set -e
set -u
set -o pipefail

. creds/env.inc.sh

# TODO: auto-cleanup failed stacks; for now, just report
main() {
  local rc=0

  echo >&2 -e 'failed stacks:'
  failedStacks || rc=$(( rc | $? ))

  # echo >&2 -e 'old stacks:'
  # oldStacks || rc=$(( rc | $? ))

  return $rc
}

cleanStackList() {
  jq 'map(del(.TemplateDescription, .DriftInformation))'
}

oldStacks() {
  # TODO: get a list of stacks which are older than x days
  echo >&2 'not implemented yet.'
  return 0
}

failedStacks() {
  local res='[]'

  for r in $REGIONS ; do
    regionData="$(
      aws cloudformation list-stacks \
        --region "$r" \
        --stack-status-filter CREATE_FAILED DELETE_FAILED ROLLBACK_FAILED UPDATE_FAILED \
        --query 'StackSummaries[]' \
        --output json \
        | jq --arg region "$r" '.[].Region = $region'
    )"

    [[ "$regionData" == '[]' ]] && continue

    res="$( jq --argjson new "$regionData" '. + $new' <<< "$res" )"
  done

  cleanStackList <<< "$res"

  [[ "$res" != '[]' ]] && {
    return 1
  }
}

main "$@"
