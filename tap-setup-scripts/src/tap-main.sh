#!/bin/bash
set -e

source "src/functions.sh"

function tapInstallMain() {
  banner "TAP Install..."

  verifyTools
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
    # downloadAndSetupTanzuCLIandDeployKapp - Or use setupTanzuCLIandDeployKapp
    setupTanzuCLIandDeployKapp
    createTapNamespace
    createTapRegistrySecret
    loadPackageRepository
  fi
  # "Installing TAP & Sample Workload ..."
  tapInstallFull
  # createDnsRecord
  tapWorkloadInstallFull
  echo "TAP Install Done ..."

}

function tapUninstallMain() {

  banner "TAP Uninstall..."
  verifyTools
  readUserInputs
  readTAPInternalValues
  setupAWSConfig
  verifyK8ClusterAccess
  parseUserInputs

  # "Uninstalling TAP & Sample Workload ..."
  tapWorkloadUninstallFull
  # deleteDnsRecord
  tapUninstallFull
  deleteTapRegistrySecret
  deletePackageRepository
  deleteTanzuCLIandKapp
  deleteTapNamespace

  echo "TAP Uninstall Done ..."

}

function tapRelocateMain() {
  banner "TAP Relocate..."
  verifyTools
  readUserInputs
  readTAPInternalValues
  setupAWSConfig
  parseUserInputs
  relocateTAPPackages
  echo "TAP Relocate Done ..."

}

#####
##### Main code starts here
#####

echo COMMAND=$cmd FILENAME=$file SKIPINIT=$skipinit

[ -z "$cmd" ] && { echo "'cmd' env var must not be empty"; exit 1; }
[ -z "$file" ] && { echo "'file' env var must not be empty"; exit 1; }


cd $PWD/src
rm -rf inputs/user-input-values.yaml
cp  /tmp/inputs/$file  inputs/user-input-values.yaml

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
*)
  cat <<EOT
  Usage: $0 {install | uninstall | relocate} {filename}  OR
      $0 {install} {filename} [skipinit]
EOT
  exit 1
  ;;
esac