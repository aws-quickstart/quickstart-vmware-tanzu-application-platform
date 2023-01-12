#!/usr/bin/env bash

set -e
set -u
set -o pipefail

source creds/env.inc.sh
source ci-repo/ci/tasks/lib/docker.lib.sh
source ci-repo/ci/tasks/lib/misc.lib.sh

readonly IMAGE_CACHE_FILE="${PWD}/image-cache/images.tar.gz"
readonly TASKCAT_CONFIG_OUTPUT="${PWD}/output/taskcat.yml"

main() {
  cd repo

  local gitSha="$( git rev-parse HEAD )"

  # To upload into a different subdirectory inside the bucket, we need to
  # change the taskcat name and pass that bucket subdirectory into our stack as
  # a paramater. Thus we patch taskcat's config here and later use that for the
  # output of our task.
  local patchedTaskcatConfig="$(
    yq -y --arg gitSha "$gitSha" \
      '.project.name = $gitSha | .project.parameters.QSS3KeyPrefix = $gitSha + "/"' \
      .taskcat.yml
  )"
  echo "$patchedTaskcatConfig" > .taskcat.yml

  taskcat upload

  # produce the output, so other tasks can pick it up
  cp .taskcat.yml "${TASKCAT_CONFIG_OUTPUT}"
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
