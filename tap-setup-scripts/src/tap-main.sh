#!/bin/bash
set -e

source "src/functions.sh"

function tapInstallMain {
  banner "TAP Install..."
  readUserInputs
  readTAPInternalValues
  verifyK8ClusterAccess
  parseUserInputs

  # "Initailizing TAP ..."
  if [[ $skipinit == "true" ]]
  then
    echo "skipping prerequisite"
  else
    echo "setup prerequisite"
    installTanzuClusterEssentials
    createTapNamespace
    createTapRegistrySecret
    loadPackageRepository
  fi
  echo "Installing TAP & Sample Workload ..."
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

  echo "Uninstalling TAP & Sample Workload ..."
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
  verifyK8ClusterAccess
  parseUserInputs
  relocateTAPPackages
  echo "TAP Relocate Done ..."

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

if [[ -z "$cmd" ]] || [[ -z "$file" ]]
then
  cat <<EOT
  Usage: $0 -c {install | uninstall | relocate} -f {filename}  OR
      $0 -c {install} {filename} [skipinit]
EOT
  exit 1
fi

export GITHUB_HOME=$PWD
echo COMMAND=$cmd FILENAME=$file SKIPINIT=$skipinit GITHUB_HOME=$GITHUB_HOME

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
esac

