#!/bin/bash
set -e

source "src/functions.sh"

function tapInstallMain {
  banner "TAP Install..."
  readUserInputs
  readTAPInternalValues
  verifyK8ClusterAccess
  parseUserInputs

  if [[ $skipinit == "true" ]]
  then
    echo "Skipping prerequisite..."
  else
    echo "Setup prerequisite..."
    installTanzuClusterEssentials
    createTapNamespace
    createTapRegistrySecret
    loadPackageRepository
  fi
  tapInstallFull
  tapWorkloadInstallFull
  printOutputParams
  echo "TAP Install Done ..."
}

function tapUninstallMain {
  banner "TAP Uninstall..."
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

  echo "TAP Uninstall Done ..."
}

function tapRelocateMain {
  banner "TAP Relocate..."
  readUserInputs
  readTAPInternalValues
  parseUserInputs
  relocateTAPPackages
  echo "TAP Relocate Done ..."
}


function bootstrapEC2 {
  banner "BootstrapEC2 with tools ..."
  installTools
  readUserInputs
  readTAPInternalValues
  installTanzuCLI
  verifyTools
  echo "BootstrapEC2 Done ..."
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

export GITHUB_HOME=$PWD
echo COMMAND=$cmd SKIPINIT=$skipinit GITHUB_HOME=$GITHUB_HOME

export DOWNLOADS=$GITHUB_HOME/downloads
export INPUTS=$GITHUB_HOME/src/inputs
export GENERATED=$GITHUB_HOME/generated
export RESOURCES=$GITHUB_HOME/src/resources

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
