#!/usr/bin/env bash

set -e
set -u
set -o pipefail

find test-result/ -type f -name '*logs.txt' \
  -exec bash -c '
    echo "##---- ${1} ----"
    cat "${1}"
    echo
  ' -- '{}' \;
