#!/usr/bin/env bash

set -e
set -u
set -o pipefail

main() {
  local -a tests
  local t
  local rc=0

  tests=(
    "${PWD}/ci-repo/ci/tests/static/templates.sh"
  )

  cd repo

  for t in "${tests[@]}" ; do
    REPO_DIR="${PWD}" "$t" || rc=$(( rc | $? ))
  done

  return $rc
}

main "$@"
