#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck disable=SC1091
source creds/env.inc.sh

ensureSingleTrailingSlash() {
  sed 's,/*$,/,g'
}

main() {
  local region srcBucket
  local destBucket destBucketName destBucketPrefix
  local url

  region="$(
    yq -r '.project.parameters.QSS3BucketRegion' taskcat-config/taskcat.yml
  )"
  srcBucket="$(
    yq -r '.project.parameters | "\(.QSS3BucketName)/\(.QSS3KeyPrefix)"' taskcat-config/taskcat.yml
  )"

  srcBucket="$( ensureSingleTrailingSlash <<< "$srcBucket" )"
  destBucket="$( ensureSingleTrailingSlash <<< "${DESTINATION_BUCKET?}" )"
  destBucketName="${destBucket%%/*}"
  destBucketPrefix="${destBucket#*/}"

  aws s3 sync "s3://${srcBucket}" "s3://${destBucket}"

  echo
  echo "Published to 's3://${destBucket}'"
  echo

  url=(
    "https://${region}.console.aws.amazon.com/cloudformation/home?region=${region}#/stacks/create"
    "?stackName=vmware-tap-internal"
    "&templateURL=https://${destBucketName}.s3.${region}.amazonaws.com/${destBucketPrefix}templates/aws-tap-entrypoint-new-vpc.template.yaml"
    "&param_QSS3BucketName=${destBucketName}"
    "&param_QSS3BucketRegion=${region}"
    "&param_QSS3KeyPrefix=${destBucketPrefix}"
  )

  echo "Stack can be deployed via:"

  echo
  printf '%s' '  ' "${url[@]}" $'\n'
  echo

  echo "    QSS3BucketName:   ${destBucketName}"
  echo "    QSS3KeyPrefix:    ${destBucketPrefix}"
  echo "    QSS3BucketRegion: ${region}"
}

main "$@"
