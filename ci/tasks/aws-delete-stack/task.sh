#!/usr/bin/env bash

set -e
set -u
set -o pipefail

loadCreds() {
  local -
  set +x

  . creds/env.inc.sh
}

main() {
  local -
  set -x

  local region stackName

  region="$( cat test-result/region )"
  stackName="$( cat test-result/stackName )"

  loadCreds

  aws cloudformation delete-stack \
    --stack-name "$stackName" \
    --region "$region"
}

main "$@"
