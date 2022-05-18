#!/bin/bash
set -e

source "src/functions.sh"

installTools
readUserInputs
readTAPInternalValues
installTanzuCLI
verifyTools

