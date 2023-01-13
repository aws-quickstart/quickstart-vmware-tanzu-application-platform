#!/usr/bin/env bash

set -e
set -u
set -o pipefail

readonly BUILD_DIR="$PWD"

source "${BUILD_DIR}/ci-repo/ci/tasks/lib/docker.lib.sh"
source "${BUILD_DIR}/ci-repo/ci/tasks/lib/misc.lib.sh"

main() {
  local repoDir="${1?needs to be the directory of the repository}"
  local imageCache="${2?needs to be the path to the image cache tarball}"
  local taskcatConfig="${3?needs to be the taskcat config}"

  cd "$repoDir"

  run::logged 'load images from cache' \
    docker::imageCacheLoad "$imageCache" || true

  run::logged 'preload images from Dockerfiles through proxy' \
    docker::loadDockerfileFroms . || true

  local rc=0
  run::logged 'taskcat package' \
    taskcat package \
      --source-folder functions/source \
      --zip-folder functions/packages \
      --config-file "$taskcatConfig" \
    || rc=$?

  run::logged 'save images to cache' \
    docker::imageCacheSave "$imageCache" || true
}

main "$@"
