#!/usr/bin/env bash

set -e
set -u
set -o pipefail

REGION="$( cat test-result/region )"
STACK_NAME="$( cat test-result/stackName )"
readonly STACK_NAME REGION

readonly -A PHASES=(
  # LogicalResourceId => OutputName
  ["$STACK_NAME"]='FullStack'
  ['PhaseCloudInit']=''
  ['PhaseTAPInstall']=''
  ['PhaseTAPWorkloadInstall']=''
  ['PhaseTAPTests']=''
)

main() {
  local logicalId outputName
  local -a phaseTimes
  local start end duration
  local durations='{}'

  local logFile="test-result/${STACK_NAME}-${REGION}-cfnlogs.txt"

  for logicalId in "${!PHASES[@]}" ; do
    outputName="${PHASES[$logicalId]}"
    test -z "$outputName" && outputName="$logicalId"

    # collect all event logs' times, sort them and push them into an array
    # log lines look something like that:
    # ```
    #   [...]
    # 2023-01-30 12:39:41.514000+00:00  CREATE_COMPLETE     AWS::CloudFormation::WaitCondition        PhaseTAPTests
    # 2023-01-30 12:39:41.033000+00:00  CREATE_IN_PROGRESS  AWS::CloudFormation::WaitCondition        PhaseTAPTests                                   Resource creation Initiated
    # 2023-01-30 12:39:40.786000+00:00  CREATE_IN_PROGRESS  AWS::CloudFormation::WaitCondition        PhaseTAPTests
    #   [...]
    # ```
    mapfile -t phaseTimes < <(
      awk -v phase="${logicalId}" '$5 == phase { print $1 " " $2 }' "$logFile" \
        | sort
    )

    # convert from datetime to epoch seconds
    start="$( date -d "${phaseTimes[0]}" '+%s' )" || {
      echo >&2 "⚠️ Could not pull start time for '${logicalId}' from taskcat logs"
      continue
    }
    end="$( date -d "${phaseTimes[-1]}" '+%s' )" || {
      echo >&2 "⚠️ Could not pull end time for '${logicalId}' from taskcat logs"
      continue
    }

    # convert to rounded minutes
    duration="$( awk '{printf("%.2f", ($1/60))}' <<< "$(( end - start ))" )"

    # add the duration to the durations object
    durations="$(
      jq \
        --argjson duration "$duration" \
        --arg phase "${outputName}" \
        '. + { "\($phase)" : $duration }' \
        <<< "$durations"
    )"
  done

  # For now, we only print the durations of the different phases. We could also
  # push them out somewhere if we wanted to.
  echo >&2 '# Durations in minutes:'
  jq . <<< "$durations"
}

main "$@"
