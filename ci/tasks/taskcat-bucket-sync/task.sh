#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# shellcheck disable=SC1091
source creds/env.inc.sh

ensureSingleTrailingSlash() {
  sed 's,/*$,/,g'
}

uriEncode() {
  jq -rn --arg data "$1" '$data | @uri'
}

main() {
  local region srcBucket
  local destBucket destBucketName destBucketPrefix
  local urlParts urlTemplate stackName

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

  stackName='tap-internal'
  urlTemplate="https://${destBucketName}.s3.amazonaws.com/${destBucketPrefix}templates/aws-tap-entrypoint-new-vpc.template.yaml"
  urlParts=(
    "https://console.aws.amazon.com/cloudformation/home#/stacks/quickcreate"
    "?templateURL=$( uriEncode "$urlTemplate" )"
    "&stackName=$( uriEncode "$stackName" )"
    "&param_EKSClusterName=$( uriEncode "$stackName" )"
    "&param_QSS3BucketName=$( uriEncode "$destBucketName" )"
    "&param_QSS3BucketRegion=$( uriEncode "$region" )"
    "&param_QSS3KeyPrefix=$( uriEncode "$destBucketPrefix" )"
  )

  echo "Stack can be deployed via:"

  echo
  printf '%s' '  ' "${urlParts[@]}" $'\n'
  echo

  echo "    QSS3BucketName:   ${destBucketName}"
  echo "    QSS3KeyPrefix:    ${destBucketPrefix}"
  echo "    QSS3BucketRegion: ${region}"
}

main "$@"
