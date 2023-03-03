# shellcheck shell=bash

run::logged() {
  local msg="$1" ; shift
  local rc=0

  echo >&2 "## ---- ${msg}"
  "$@" || rc=$?

  if [[ $rc == 0 ]] ; then
    echo >&2 "## ---- ${msg} done."
  else
    echo >&2 "## ---- ${msg} failed! (rc: $rc)"
  fi
  echo >&2

  return $rc
}

uri::encode() {
  jq -rn --arg data "$1" '$data | @uri'
}

bucket::printDetails() {
  local bucket="${1?}"
  local prefix="${2?}"
  local region="${3?}"

  local stackName="${4:-tap-internal}"

  local urlTemplate urlParts

  echo
  echo "Published to 's3://${bucket}/${prefix}'"
  echo

  urlTemplate="https://${bucket}.s3.amazonaws.com/${prefix}templates/aws-tap-entrypoint-new-vpc.template.yaml"
  urlParts=(
    "https://console.aws.amazon.com/cloudformation/home#/stacks/quickcreate"
    "?templateURL=$( uri::encode "$urlTemplate" )"
    "&stackName=$( uri::encode "$stackName" )"
    "&param_EKSClusterName=$( uri::encode "$stackName" )"
    "&param_QSS3BucketName=$( uri::encode "$bucket" )"
    "&param_QSS3BucketRegion=$( uri::encode "$region" )"
    "&param_QSS3KeyPrefix=$( uri::encode "$prefix" )"
  )

  echo "Stack can be deployed via:"

  echo
  printf '%s' '  ' "${urlParts[@]}" $'\n'
  echo

  echo "    QSS3BucketName:   ${bucket}"
  echo "    QSS3KeyPrefix:    ${prefix}"
  echo "    QSS3BucketRegion: ${region}"
}

# Pulls bucket coordinates from a taskcat file and prints them, the bucket
# name, the bucket prefix, and the region comma separated.
# Can be consumed like this:
#   mapfile -t -d $'\t' coords < <( bucket::getCoords .taskcat.yml )
bucket::getCoords() {
  local taskcatConfig="${1?}"
  yq -jer '
    .project
    | .s3_regional_buckets as $regional
    | .s3_bucket as $bucket
    | .regions[0] as $region
    | .name as $prefix
    | if $bucket == null then error("bucket name missing")   else . end
    | if $region == null then error("bucket region missing") else . end
    | if $regional
      then
        [ "\($bucket)-\($region)", "\($prefix)/", $region ]
      else
        [ $bucket, "\($prefix)/", $region ]
      end
    | @tsv
  ' "$taskcatConfig"
}
