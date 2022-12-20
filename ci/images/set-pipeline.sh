#!/usr/bin/env bash

set -e
set -u
set -o pipefail

readonly DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"

main() {
    # the default pipeline name is the basename of this directory
    local defaultPipelineName="${DIR##*/}"

    fly --target "${FLY_TARGET:-tappc}" \
        set-pipeline \
            --pipeline "${PIPELINE_NAME:-${defaultPipelineName}}" \
            --config "${DIR}/pipeline.yml" \
            --load-vars-from "${DIR}/pipeline.vars.yml" \
            --check-creds
}

main "$@"
