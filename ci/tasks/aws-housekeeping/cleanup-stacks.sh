#!/usr/bin/env bash

# Cleaning up stacks with well-known errors
#
# We want to be sure that we only clean up stacks with errors we really know
# about, so that we don't hide errors.
# When we find new errors (surfaced by the housekeeping task) and we consider
# them 'well-known' and want to clean up those too, we "just" need to implement
# more `cleaner::` functions.
#
# The cleaner functions will be called with
# - a file path holding all the stacks with `DELETE_FAILED` state (from an `aws
#  cloudformation desrcibe-stacks` call)
# - a list of stack names of root stacks that need cleanup
#
# Environment variables:
#   REGIONS
#     defaults to 'us-east-1' but can be set to a space-separated list of
#     multiple regions
#   IGNORE_ROOT_STACK_RE
#     defaults to not exclude / ignore any root stack, but can be set to a
#     regular expression to match against stack names
#   REALLY_DELETE
#     if set will actually run commands that delete resources
#     if not set, it will only log the command it would run
#   SCRATCH_DIR
#     defaults to '/scratch' (to align with concourse) and can be set to a
#     different directory to change where temporary files should be put

set -e
set -u
set -o pipefail

# shellcheck disable=SC1091
. creds/env.inc.sh

##------------------------------------------------------------
main() {
  local -a cleaners
  local failedStacksFile failedRootStackNames cleaner

  # Get all functions prefixed with 'cleaner::'
  mapfile -t cleaners < <(
    declare -F | sed -n 's/declare -f \(cleaner::.*\)/\1/gp'
  )

  for cleaner in "${cleaners[@]}" ; do
    # refresh the list of stacks, so we don't see stacks handled by previous
    # cleaners anymore
    failedStacksFile="${SCRATCH_DIR:-/scratch}/failedStacks.json"
    getDeleteFailedStacks > "$failedStacksFile"

    # for convenience we pass in the root stacks' names to the cleaner
    mapfile -td $'\t' failedRootStackNames < <(
      jq -jr \
        --arg ignoreRootStacks "${IGNORE_ROOT_STACK_RE:-$^}" '
          [ .[] | select(has("RootId") | not) | .StackName ]
            | map(select(. | test($ignoreRootStacks) | not))
            | @tsv
        ' "$failedStacksFile"
    )

    # run the cleaner
    rc=0
    {
      echo "## ---- $cleaner start ----"
      "$cleaner" "$failedStacksFile" "${failedRootStackNames[@]}" || rc=$?
      echo "## ---- $cleaner done (rc: $rc) ----"
    } >&2
  done
}

##------------------------------------------------------------
cleaner::VpcWithLeftoverResources() {
  local allStacksFile="$1" ; shift

  local rootStackName
  local allRelatedStackCount
  local vpcStackCount vpcStackName region
  local vpcId secGroupIds secGroupId

  for rootStackName in "$@" ; do
    echo >&2 -e "\nrunning for root stack '$rootStackName'\n"

    # We expect 2 stacks to have failed, the root stack and the vpc stack.
    # Let's check on that and bail out if that's not the case.
    allRelatedStackCount="$(
      jq -r \
        --arg rootStackName "$rootStackName" \
        '[ .[] | select(.StackName | test("^\($rootStackName)")) ] | length' \
        "$allStacksFile"
    )"

    (( allRelatedStackCount != 2 )) && {
      echo >&2 "Expected to find 2 stacks (root & vpc) for '$rootStackName', found $allRelatedStackCount; thus not touching '$rootStackName'"
      continue
    }

    # Let's find the VPC stack and ensure we really only found one.
    read -r vpcStackCount vpcStackName region < <(
      jq -r \
        --arg rootStackName "$rootStackName" \
        '[ .[] | select(.StackName | test("^\($rootStackName)-VPCStack-[^-]+$")) ] | [ length, .[0].StackName, .[0].Region ] | @tsv' \
        "$allStacksFile"
    )

    (( vpcStackCount != 1 )) && {
      echo >&2 "Expected to find one stack for root stack '$rootStackName', but found $vpcStackCount; thus not touching '$rootStackName'"
      continue
    }

    # Let's ensure we find the expected error event and extract the VPC ID from there
    vpcId="$(
      # shellcheck disable=SC2016
      aws cloudformation describe-stack-events \
        --stack-name "$vpcStackName" \
        --region "$region" \
        --query 'StackEvents[?ResourceStatus==`DELETE_FAILED` && ResourceStatusReason && contains(ResourceStatusReason, `has dependencies and cannot be deleted.`)].PhysicalResourceId' \
        | jq -r '.[0] // empty'
    )"

    [[ -z "$vpcId" ]] && {
      echo >&2 "Cloud not find the expected error event on '$vpcStackName'; thus not touching '$rootStackName'"
      continue
    }

    # For now, I have only seen security groups to be left over

    # Collect the seciruty groups
    mapfile -td $'\t' secGroupIds < <(
      # shellcheck disable=SC2016
      aws ec2 describe-security-groups \
        --region "$region" \
        --query 'SecurityGroups[?VpcId==`'"$vpcId"'` && GroupId!=`default` && Description==`EKS created security group applied to ENI that is attached to EKS Control Plane master nodes, as well as any managed workloads.`].GroupId' \
        | jq -jr '. | @tsv'
    )

    for secGroupId in "${secGroupIds[@]}" ; do
      echo >&2 "Deleting security group '$secGroupId'"
      runGuarded aws ec2 delete-security-group --region "$region" --group-id "$secGroupId"
    done

    echo >&2 "Deleting root stack '$rootStackName'"
    runGuarded aws cloudformation delete-stack --region "$region" --stack-name "$rootStackName"
  done
}

##------------------------------------------------------------
runGuarded() {
  if [[ -v REALLY_DELETE ]] ; then
    "$@"
  else
    echo '[wouldRun]' "$@"
  fi
}

isEmpty() {
  jq -e 'length < 1' >/dev/null
}

getDeleteFailedStacks() {
  local r
  local allStacks='[]'
  local regionalStacks

  for r in ${REGIONS:-us-east-1}; do
    regionalStacks="$(
      # shellcheck disable=SC2016
      aws cloudformation describe-stacks \
        --query 'Stacks[?StackStatus == `DELETE_FAILED`]' \
        --region "$r" \
        --output json \
        | jq --arg region "$r" '.[].Region = $region'
    )"

    isEmpty <<< "$regionalStacks" && continue

    allStacks="$( jq --argjson new "$regionalStacks" '. + $new' <<< "$allStacks" )"
  done

  echo "$allStacks"
}

main "$@"
