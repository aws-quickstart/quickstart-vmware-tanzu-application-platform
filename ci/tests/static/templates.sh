#!/usr/bin/env bash

# Run some tests.
# The tests will run in serial and can produce output on either StdOut or
# StdErr. All functions starting with 'Test::' will be run as test cases.
# No magic is done, the test case just runs in a subprocess; potential side
# effects, clean-up, ... needs to be managed by the test case itself.

set -e
set -u
set -o pipefail

REPO_DIR="${REPO_DIR:-$( cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../ && pwd )}"
readonly REPO_DIR

# shellcheck disable=SC2034
readonly TEMPLATE_NEW_VPC="${REPO_DIR}/templates/aws-tap-entrypoint-new-vpc.template.yaml"
readonly TEMPLATE_EXISTING_VPC="${REPO_DIR}/templates/aws-tap-entrypoint-existing-vpc.template.yaml"

##--------------------------------------------------------------------
Test::CloudformationLint() {
  cd "$REPO_DIR"
  find templates/ -type f -iregex '.*\.ya?ml' -print0 \
    | xargs -0 -r cfn-lint
}

##--------------------------------------------------------------------
# Test if all substacks we create get configured with the correct bucket
# parameters
Test::SubstacksGetBucketConfig() {
  # shellcheck disable=SC2016
  yq -e '
    def paramMissing($param; $name):
      "`\($name)` is missing parameter `\($param)`" | halt_error(1)
    ;
    def checkParams($params; $name):
        if $params | has("QSS3BucketName")   then . else paramMissing("QSS3BucketName"; $name)   end
      | if $params | has("QSS3BucketRegion") then . else paramMissing("QSS3BucketRegion"; $name) end
      | if $params | has("QSS3KeyPrefix")    then . else paramMissing("QSS3KeyPrefix"; $name)    end
    ;

    .Resources | to_entries | map(
      # check all resources of type stack
      # explicitly exclude "EKSAdvancedConfigStack", which does not take the bucket params
      select(.value.Type == "AWS::CloudFormation::Stack" and .key != "EKSAdvancedConfigStack")
        | checkParams(.value.Properties.Parameters; .key)
    )
  ' "$TEMPLATE_EXISTING_VPC" >/dev/null
}

##--------------------------------------------------------------------
testInfra::runTestCase() (
  local testFunc="$1"
  local rc=0 output
  local ERR='❌'
  local OK='✅'

  output="$( "$testFunc" 2>&1 )" || rc=$?

  case "$rc" in
    0) echo "${OK} ${testFunc}"  ;;
    *) echo "${ERR} ${testFunc}" ;;
  esac

  [[ -n "$output" ]] && {
    # shellcheck disable=SC2001
    sed 's/^/    | /g' <<< "$output"
  }

  return $rc
)

testInfra::main() {
  local -a tests
  local test
  local rc=0

  mapfile -t tests < <(
    declare -F \
      | sed 's/^declare -f //g' \
      | grep '^Test::'
  )

  for test in "${tests[@]}" ; do
    testInfra::runTestCase "$test" || rc=$(( rc | $? ))
  done

  return $rc
}

testInfra::main "$@"
