#!/usr/bin/env bash

set -e
set -u
set -o pipefail

source creds/env.inc.sh

cd repo
taskcat test run \
  --skip-upload \
  --input-file ../taskcat-config/taskcat.yml \
  --test-names "$TEST_NAME" \
  --minimal-output \
  --no-delete \
  --output-directory ../test-result/
