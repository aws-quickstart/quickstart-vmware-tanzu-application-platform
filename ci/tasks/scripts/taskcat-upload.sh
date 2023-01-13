#!/usr/bin/env bash

set -e
set -u
set -o pipefail

source creds/env.inc.sh
source ci-repo/ci/tasks/lib/docker.lib.sh
source ci-repo/ci/tasks/lib/misc.lib.sh

readonly IMAGE_CACHE_FILE="${PWD}/image-cache/images.tar.gz"
readonly TASKCAT_CONFIG_FILE="${PWD}/taskcat-config/taskcat.yml"

main() {
  cd repo

  taskcat upload --config-file "$TASKCAT_CONFIG_FILE"
}

run::logged 'load images from cache' \
  docker::imageCacheLoad "$IMAGE_CACHE_FILE" || true
run::logged 'preload images from Dockerfiles through proxy' \
  docker::loadDockerfileFroms repo || true

rc=0
run::logged 'main task' main || rc=$?

run::logged 'save images to cache' \
  docker::imageCacheSave "$IMAGE_CACHE_FILE" || true

exit $rc
