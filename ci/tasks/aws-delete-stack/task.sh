#!/usr/bin/env bash

set -e
set -u
set -o pipefail

. creds/env.inc.sh

REGION="$( cat test-result/region )"
STACK_NAME="$( cat test-result/stackName )"

aws cloudformation delete-stack \
  --stack-name "$STACK_NAME" \
  --region "$REGION"
