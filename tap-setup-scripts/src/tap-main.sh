#!/bin/bash
set -e
group=docker
if [ $(id -gn) != $group ]; then
  echo "Executing as group '$group'..."
  exec sg $group "$0 $*"
fi

export SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/functions.sh"

function tapInstallMain {
  banner "TAP Install..."
  readUserInputs
  verifyK8ClusterAccess
  parseUserInputs

  if [[ $skipinit == "true" ]]
  then
    echo "Skipping prerequisites..."
  else
    echo "Setup prerequisites..."
    installTanzuClusterEssentials
    createTapNamespace
    # EKS nodes have read-only access, hence tap-registry secret is not necessary
    # createTapRegistrySecret
    loadPackageRepository
  fi
  tapInstallFull
  tapWorkloadInstallFull
  printOutputParams
  # wait till the workload to go through the supply-chain
  sleep 240
  runTestCases
  echo "TAP install done..."
}

function tapUninstallMain {
  banner "TAP uninstall..."
  readUserInputs
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
  parseUserInputs
  relocateTAPPackages
  echo "TAP relocate done..."
}

function tapTestPreReqs {
  banner "TAP test prerequisites..."

  readUserInputs
  parseUserInputs

  verifyK8ClusterAccess

  echo "TAP test prerequisites done..."
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
  Usage: $0 -c {install | uninstall | relocate | prereqs } OR
      $0 -c {install} [-s | --skipinit]
EOT
  exit 1
fi

echo COMMAND=$cmd SKIPINIT=$skipinit SCRIPT_DIR=$SCRIPT_DIR
echo "This script is running as group $(id -gn)"
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
"prereqs")
  tapTestPreReqs
  ;;
esac
