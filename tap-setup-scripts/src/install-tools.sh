#!/bin/bash
set -e

export SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/functions.sh"

function bootstrapEC2 {
  banner "Bootstrap EC2 instance with tools..."
  readUserInputs
  readTAPInternalValues
  installTanzuCLI
  verifyTools
  echo "Bootstrap EC2 instance done..."
}

echo COMMAND=$cmd SKIPINIT=$skipinit SCRIPT_DIR=$SCRIPT_DIR
export DOWNLOADS="$(dirname "$SCRIPT_DIR")/downloads"
export INPUTS="$(dirname "$SCRIPT_DIR")/src/inputs"
export GENERATED="$(dirname "$SCRIPT_DIR")/generated"
export RESOURCES="$(dirname "$SCRIPT_DIR")/src/resources"
bootstrapEC2
