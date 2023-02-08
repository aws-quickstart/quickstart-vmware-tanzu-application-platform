#!/usr/bin/env bash

set -e
set -u
set -o pipefail

readonly DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"

main() {
    # the default pipeline name is the basename of this directory
    local defaultPipelineName="${DIR##*/}"
    local setPipelineArgs=(
        --pipeline "${PIPELINE_NAME:-${defaultPipelineName}}" \
        --config "${DIR}/pipeline.yml" \
        --check-creds
    )

    local varsFile="${DIR}/pipeline.vars.yml"
    [[ -e "${varsFile}" ]] && {
        setPipelineArgs+=( --load-vars-from "${varsFile}" )
    }

    fly --target "${FLY_TARGET:-tappc}" \
        set-pipeline "${setPipelineArgs[@]}"
}

main "$@"
