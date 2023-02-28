#!/usr/bin/env bash

set -e
set -u
set -o pipefail

readonly BUILD_DIR="$PWD"

# shellcheck disable=SC1091
source "${BUILD_DIR}/creds/env.inc.sh"
# shellcheck disable=SC1091
source "${BUILD_DIR}/ci-repo/ci/tasks/lib/misc.lib.sh"

readonly IMAGE_CACHE_FILE="${BUILD_DIR}/image-cache/images.tar.gz"
readonly TASKCAT_CONFIG_FILE="${BUILD_DIR}/taskcat-config/taskcat.yml"

main() {
  cd repo

  local bucketCoords
  mapfile -t -d $'\t' bucketCoords < <( bucket::getCoords "$TASKCAT_CONFIG_FILE" )

  ensurePackageZips "${bucketCoords[0]}"

  run::logged 'running taskcat upload' \
    taskcat upload --config-file "$TASKCAT_CONFIG_FILE" --disable-lambda-packaging

  run::logged 'quick create' \
    bucket::printDetails "${bucketCoords[0]}" "${bucketCoords[1]}" "${bucketCoords[2]}"
}

# `ensurePackageZips` makes sure we have the correct package zips in the project repo.
# It tries to find them in the bucket, prebuild versions for the version of the
# quickstart-amazon-eks we have submodul'ed in.
# When we don't have a cached/prebuilt version available, we built it on the
# fly and make sure to put it into the cache.
#
# This is a bit weird, as this task does create side-effect; it doesn't use a
# resource to manage these packages.
#
# If we ever introduce additional top-level submodules, we also need to ensure
# to package those up too, similar as we do right now for the eks packages.
ensurePackageZips() {
  local bucket="$1"

  local submodulePath='submodules/quickstart-amazon-eks'
  local name rev

  name="$(basename "$submodulePath")"
  rev="$( cd "$submodulePath" && git rev-parse HEAD )"

  local tarball="${name}-${rev}.tar.gz"
  local s3Path="s3://${bucket}/ci/cached-packages/${tarball}"

  local scratchDir="${SCRATCH_DIR:-/scratch}"

  if aws s3 ls "$s3Path" >/dev/null ; then
    {
      echo "## found cached packages at '$s3Path'"
      echo "## will download and unpack them over the current repo"
    } >&2

    (
      cd "$scratchDir"
      aws s3 cp "$s3Path" .
      aws s3 cp "${s3Path}.sha256" .
      sha256sum --check "${tarball}.sha256"
    )
    tar -xzvf "${scratchDir}/${tarball}"
  else
    {
      echo "## couldn't find prebuilt packages at '$s3Path'"
      echo "## will build the packages locally and upload them to the cache"
    } >&2

    # `execute` is the wrapper that starts the niumbus VM and wires up docker
    # we need that when building the packages
    # because `execute` forks a process, we put the building code into it's
    # separate script
    (
      cd "$BUILD_DIR"
      execute ci-repo/ci/tasks/taskcat-build-upload/build.sh \
        "${BUILD_DIR}/repo" \
        "$IMAGE_CACHE_FILE" \
        "$TASKCAT_CONFIG_FILE"
    )

    tar -cf - --null -T <(find . -iname '*.zip' -print0) | pigz > "${scratchDir}/${tarball}"
    (
      cd "$scratchDir"
      sha256sum "$tarball" > "${tarball}.sha256"
      aws s3 cp "${tarball}.sha256" "${s3Path}.sha256"
      aws s3 cp "${tarball}" "$s3Path"
    )
  fi
}

main "$@"
