#!/usr/bin/env bash

#! This is just a temporary script to set up a S3 bucket with the QS code in
#! it.
#!
#! Currently I have issues building the zips for the lambdas, thus this
#! - sets up the bucket with the current repo
#! - copies over the zips from the upstream bucket
#!
#! This will only work until the the versions of the submodul'ed in dependencies
#! matches the version the zips in the upstream bucket match up.
#!
#! The correct thing to do is to
#! - figure out why I can't build those locally
#! - or better yet: have them built in CI
#! - and use taskcat or other tooling to manage the bucket's content

set -e
set -u
set -o pipefail

readonly DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )"
readonly CACHE="${DIR}/.cache/"
readonly DEST="s3://${DEV_BUCKET?}/"
readonly SRC='s3://aws-quickstart/quickstart-vmware-tanzu-application-platform/'

main() {
    cd "$DIR"

    echo >&2 '## sync repo'
    local repoExcludes=(
        --exclude '.git/*'
        --exclude '.taskcat/*'
        --exclude '.taskcat_overrides.yml'
        --exclude '.envrc'
        --exclude 'tmp/*'
        --exclude '*zip'
        --exclude '*/output/*'
        --exclude 'scripts/*'
        --exclude "${CACHE}*"
    )
    aws s3 sync \
        "${repoExcludes[@]}" \
        --delete \
        '.' \
        "$DEST"

    echo >&2 '## sync zips'
    # To sync from bucket to bucket, we'd need `s3:GetObjectTagging` for source
    # objects and `s3:PutObjectTagging` for destination objects; see:
    # https://repost.aws/knowledge-center/move-objects-s3-bucket#:~:text=Before%20you%20begin%2C%20consider%20the%20following
    # Therefore we copy through a local cache
    mkdir -p "$CACHE"
    aws s3 sync \
        --exclude '*' \
        --include '*.zip' \
        --delete \
        "$SRC" \
        "$CACHE"
    aws s3 sync \
        --exclude '*' \
        --include '*.zip' \
        --delete \
        "$CACHE" \
        "$DEST"
}

main "$@"
