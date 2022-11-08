#!/bin/bash
set -e

export SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/functions.sh"

function tapRelocateMain {
  banner "TAP relocate..."
  readUserInputs
  relocateTAPPackages
  echo "TAP relocate done..."
}


export DOWNLOADS="$(dirname "$SCRIPT_DIR")/downloads"
export INPUTS="$SCRIPT_DIR/inputs"
export GENERATED="$(dirname "$SCRIPT_DIR")/generated"
export RESOURCES="$SCRIPT_DIR/resources"
tapRelocateMain
