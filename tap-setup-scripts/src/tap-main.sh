#!/bin/bash
set -e

export GITHUB_HOME=$HOME/tap-setup-scripts

source "$GITHUB_HOME/src/functions.sh"

function tapInstallMain {
  banner "TAP Install..."
  readUserInputs
  readTAPInternalValues
  setupAWSConfig
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
  # createDnsRecord
  tapWorkloadInstallFull
  printOutputParams
  echo "TAP Install Done ..."

}

function tapUninstallMain {

  banner "TAP Uninstall..."
  readUserInputs
  readTAPInternalValues
  setupAWSConfig
  verifyK8ClusterAccess
  parseUserInputs

  echo "Uninstalling TAP & Sample Workload ..."
  tapWorkloadUninstallFull
  # deleteDnsRecord
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
  setupAWSConfig
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

echo COMMAND=$cmd FILENAME=$file SKIPINIT=$skipinit

export GITHUB_HOME=$HOME/tap-setup-scripts/
cd $GITHUB_HOME/src
rm -rf inputs/user-input-values.yaml
cp  $file  inputs/user-input-values.yaml

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

