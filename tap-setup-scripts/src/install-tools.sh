#!/bin/bash
set -e

export GITHUB_HOME=$HOME/tap-setup-scripts

source "$GITHUB_HOME/src/functions.sh"

installTools
readUserInputs
readTAPInternalValues
installTanzuCLI
verifyTools

