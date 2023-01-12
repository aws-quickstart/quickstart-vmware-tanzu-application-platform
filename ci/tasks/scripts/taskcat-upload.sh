#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# TODO move to image
apt-get -y update
apt-get -y install pigz

source creds/env.inc.sh
source ci-repo/ci/tasks/lib/docker.lib.sh
source ci-repo/ci/tasks/lib/misc.lib.sh

readonly IMAGE_CACHE_FILE="${PWD}/image-cache/images.tar.gz"

main() {
  cd repo

  # Runs `taskcat package -s functions/source -z functions/packages` internally
  taskcat upload
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
