#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck disable=SC1091
source creds/env.inc.sh
# shellcheck disable=SC1091
source ci-repo/ci/tasks/lib/misc.lib.sh

ensureSingleTrailingSlash() {
  sed 's,/*$,/,g'
}

main() {
  local srcBucketCoords
  local destBucket destBucketName destBucketPrefix

  mapfile -t -d $'\t' srcBucketCoords \
    < <( bucket::getCoords taskcat-config/taskcat.yml )

  destBucket="$( ensureSingleTrailingSlash <<< "${DESTINATION_BUCKET?}" )"
  destBucketName="${destBucket%%/*}"
  destBucketPrefix="${destBucket#*/}"

  aws s3 sync "s3://${srcBucketCoords[0]}/${srcBucketCoords[1]}" "s3://${destBucket}"

  bucket::printDetails "$destBucketName" "$destBucketPrefix" "${srcBucketCoords[2]}"
}

main "$@"
