#!/bin/bash
set -e

source "src/functions.sh"

function bootstrapEC2 {
  banner "BootstrapEC2 with tools ..."
  installTools
  installDocker
  readUserInputs
  readTAPInternalValues
  installTanzuCLI
  verifyTools
  echo "BootstrapEC2 Done ..."
}

export GITHUB_HOME=$PWD
echo COMMAND=$cmd SKIPINIT=$skipinit GITHUB_HOME=$GITHUB_HOME
export DOWNLOADS=$GITHUB_HOME/downloads
export INPUTS=$GITHUB_HOME/src/inputs
export GENERATED=$GITHUB_HOME/generated
export RESOURCES=$GITHUB_HOME/src/resources
bootstrapEC2