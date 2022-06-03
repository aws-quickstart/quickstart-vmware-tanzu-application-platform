#!/bin/bash
set -e

export SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/functions.sh"

function tapInstallMain {
  banner "TAP Install..."
  readUserInputs
  readTAPInternalValues
  verifyK8ClusterAccess
  parseUserInputs

  if [[ $skipinit == "true" ]]
  then
    echo "Skipping prerequisites..."
  else
    echo "Setup prerequisites..."
    installTanzuClusterEssentials
    createTapNamespace
    createTapRegistrySecret
    loadPackageRepository
  fi
  tapInstallFull
  tapWorkloadInstallFull
  printOutputParams
  echo "TAP install done..."
}

function tapUninstallMain {
  banner "TAP uninstall..."
  readUserInputs
  readTAPInternalValues
  verifyK8ClusterAccess
  parseUserInputs

  tapWorkloadUninstallFull
  tapUninstallFull
  deleteTapRegistrySecret
  deletePackageRepository
  deleteTanzuClusterEssentials
  deleteTapNamespace

  echo "TAP uninstall done..."
}

function tapRelocateMain {
  banner "TAP relocate..."
  readUserInputs
  readTAPInternalValues
  parseUserInputs
  relocateTAPPackages
  echo "TAP relocate done..."
}


function bootstrapEC2 {
  banner "Bootstrap EC2 with tools..."
  readUserInputs
  readTAPInternalValues
  installTanzuCLI
  verifyTools
  echo "Bootstrap EC2 done..."
}

#####
##### Main code starts here
#####

while [[ "$#" -gt 0 ]]
do
  case $1 in
    -f|--file)
      file="$2"
      ;;
    -c|--cmd)
      cmd="$2"
      ;;
    -s|--skipinit)
      skipinit="true"
      ;;
  esac
  shift
done

if [[ -z "$cmd" ]]
then
  cat <<EOT
  Usage: $0 -c {install | uninstall | relocate | bootstrap } OR
      $0 -c {install} [-s | --skipinit]
EOT
  exit 1
fi

echo COMMAND=$cmd SKIPINIT=$skipinit SCRIPT_DIR=$SCRIPT_DIR

export DOWNLOADS="$(dirname "$SCRIPT_DIR")/downloads"
export INPUTS="$SCRIPT_DIR/inputs"
export GENERATED="$(dirname "$SCRIPT_DIR")/generated"
export RESOURCES="$SCRIPT_DIR/resources"

case $cmd in
"install")
  tapInstallMain
  ;;
"uninstall")
  tapUninstallMain
  ;;
"relocate")
  tapRelocateMain
  ;;
"bootstrap")
  bootstrapEC2
  ;;
esac
