#!/usr/bin/env bash

set -e
set -u
set -o pipefail

. creds/env.inc.sh

readonly STACK_LIST="${SCRATCH_DIR:-/scratch}/stacks.json"

# ignore nothing, by using an RE that does never match
readonly IGNORE_OLD_STACKS_RE="${IGNORE_OLD_STACKS_RE:-$^}"
readonly IGNORE_FAILED_STACKS_RE="${IGNORE_FAILED_STACKS_RE:-$^}"


# TODO: auto-cleanup failed stacks; for now, just report
main() {
  local rc=0

  getStackList "$STACK_LIST"

  echo >&2 -e '⚠️ failed stacks:'
  failedStacks "$STACK_LIST" || rc=$(( rc | $? ))

  echo >&2
  echo >&2 -e '🕧 old stacks:'
  oldStacks "$STACK_LIST" || rc=$(( rc | $? ))

  return $rc
}

printCleanedStacks() {
  jq 'map(del(.TemplateDescription, .DriftInformation))'
}

isEmpty() {
  jq -e 'length < 1' >/dev/null
}

oldStacks() {
  local stacks
  local cutOffDate="$( date -u --date "${OLD_AFTER:-3 days} ago" '+%F' )"

  stacks="$(
    jq \
      --arg ignoreRe "$IGNORE_OLD_STACKS_RE" \
      --arg cutOffDate "$cutOffDate" \
      '[ .[] | select(.StackName|test($ignoreRe)|not) | select(.CreationTime < $cutOffDate) ]' \
      "$1"
  )"

  printCleanedStacks <<< "$stacks"

  isEmpty <<< "$stacks" || return 1
}

failedStacks() {
  local stacks

  stacks="$(
    jq \
      --arg ignoreRe "$IGNORE_FAILED_STACKS_RE" \
      '[ .[] | select(.StackName|test($ignoreRe)|not) | select(.StackStatus|contains("FAILED")) ]'  \
      "$1"
  )"

  printCleanedStacks <<< "$stacks"

  isEmpty <<< "$stacks" || return 1
}

getStackList() {
  local query='StackSummaries[?StackStatus!=`DELETE_COMPLETE`]'
  local res='[]'

  for r in ${REGIONS:-us-east-1} ; do
    regionData="$(
      aws cloudformation list-stacks \
        --region "$r" \
        --query "$query" \
        --output json \
        | jq --arg region "$r" '.[].Region = $region'
    )"

    isEmpty <<< "$regionData" && continue

    res="$( jq --argjson new "$regionData" '. + $new' <<< "$res" )"
  done

  cat > "$1" <<< "$res"
}

main "$@"
