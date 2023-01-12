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

imageCache="${PWD}/image-cache/images.tar.gz"

main() {
  taskcat package -s functions/source -z functions/packages
}

cd repo

run::logged 'load images from cache' \
  docker::imageCacheLoad "$imageCache" || true
run::logged 'preload images from Dockerfiles through proxy' \
  docker::loadDockerfileFroms . || true

rc=0
run::logged 'main task' main || rc=$?

run::logged 'save images to cache' \
  docker::imageCacheSave "$imageCache" || true

exit $rc
