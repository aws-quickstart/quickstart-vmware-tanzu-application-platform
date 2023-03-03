#!/usr/bin/env bash

set -e
set -u
set -o pipefail

source creds/env.inc.sh

readonly RESULT_DIR="${PWD}/test-result"

cd repo
rc=0
taskcat test run \
  --skip-upload \
  --input-file ../taskcat-config/taskcat.yml \
  --regions "$REGIONS" \
  --test-names "$TEST_NAME" \
  --minimal-output \
  --no-delete \
  --output-directory "$RESULT_DIR" \
  || rc=$?

# TODO: for now, we expect only one log file, as we run the test in parallel
# concourse jobs.
sed -n '2 s/^Region: //ip'    "${RESULT_DIR}/tCaT-"*logs.txt > "${RESULT_DIR}/region"
sed -n '3 s/^StackName: //ip' "${RESULT_DIR}/tCaT-"*logs.txt > "${RESULT_DIR}/stackName"

exit $rc
