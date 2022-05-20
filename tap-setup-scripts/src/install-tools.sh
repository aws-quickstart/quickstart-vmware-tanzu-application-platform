#!/bin/bash
set -e

source "src/functions.sh"

export GITHUB_HOME=$PWD
echo COMMAND=$cmd FILENAME=$file SKIPINIT=$skipinit GITHUB_HOME=$GITHUB_HOME

export DOWNLOADS=$GITHUB_HOME/downloads
export INPUTS=$GITHUB_HOME/src/inputs
export GENERATED=$GITHUB_HOME/generated
export RESOURCES=$GITHUB_HOME/src/resources

installTools
readUserInputs
readTAPInternalValues
installTanzuCLI
verifyTools

