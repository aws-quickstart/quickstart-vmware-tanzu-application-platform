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
  aws eks update-kubeconfig --name ${TAP_CLUSTER_NAME}

  parseUserInputs $CLUSTER_NAME_SUFFIX

  if [[ $skipinit == "true" ]]
  then
    echo "Skipping prerequisites..."
  else
    echo "Setup prerequisites..."
    installTanzuClusterEssentials
    createTapNamespace
    if [[ $TANZUNET_RELOCATE_IMAGES != "Yes" ]]
    then
      createTapRegistrySecret
    fi
    loadPackageRepository
  fi

  tapInstallFull "tap-values-$CLUSTER_NAME_SUFFIX.yaml"

  createRoute53Record $CLUSTER_NAME_SUFFIX

  case $CLUSTER_NAME_SUFFIX in
    build)
      kubectl create -f $RESOURCES/tap-gui-viewer-service-account-rbac.yaml || true
      kubectl create -f $RESOURCES/tap-gui-viewer-secret.yaml || true
      ytt -f $RESOURCES/metadata-store-exportsecret.yaml  \
        --data-value workload.namespace=$DEVELOPER_NAMESPACE \
        --ignore-unknown-comments > $GENERATED/metadata-store-exportsecret.yaml

      kubectl apply -f $GENERATED/metadata-store-exportsecret.yaml
      ;;
    run)
      kubectl create -f $RESOURCES/tap-gui-viewer-service-account-rbac.yaml || true
      kubectl create -f $RESOURCES/tap-gui-viewer-secret.yaml || true
      ytt -f $RESOURCES/metadata-store-exportsecret.yaml  \
        --data-value workload.namespace=$DEVELOPER_NAMESPACE \
        --ignore-unknown-comments > $GENERATED/metadata-store-exportsecret.yaml

      kubectl apply -f $GENERATED/metadata-store-exportsecret.yaml
      ;;
    iterate)
      kubectl create -f $RESOURCES/tap-gui-viewer-service-account-rbac.yaml || true
      kubectl create -f $RESOURCES/tap-gui-viewer-secret.yaml || true
      ytt -f $RESOURCES/metadata-store-exportsecret.yaml  \
        --data-value workload.namespace=$DEVELOPER_NAMESPACE \
        --ignore-unknown-comments > $GENERATED/metadata-store-exportsecret.yaml

      kubectl apply -f $GENERATED/metadata-store-exportsecret.yaml
      ;;
    view)
      kubectl apply -f $RESOURCES/metadata-store-read-only.yaml
      CA_CERT=$(kubectl get secret -n metadata-store ingress-cert -o json | jq -r ".data.\"ca.crt\"")
      # echo CA_CERT $CA_CERT
      ytt -f $RESOURCES/store_ca.yaml  \
      --data-value view_cluster.ca_cert=$CA_CERT \
      --ignore-unknown-comments > $GENERATED/store_ca.yaml
      ;;
    single)
      ;;
  esac
  echo "TAP install done..."
}


function tapUninstallMain {
  banner "TAP uninstall ..."
  readUserInputs
  aws eks update-kubeconfig --name ${TAP_CLUSTER_NAME}
  case $CLUSTER_NAME_SUFFIX in
    build)
      kubectl delete -f $RESOURCES/tap-gui-viewer-service-account-rbac.yaml || true
      kubectl delete -f $RESOURCES/tap-gui-viewer-secret.yaml || true

      kubectl delete -f $GENERATED/store_ca.yaml || true
      kubectl delete secret generic store-auth-token -n metadata-store-secrets || true
      ;;
    run)
      kubectl delete -f $RESOURCES/tap-gui-viewer-service-account-rbac.yaml || true
      kubectl delete -f $RESOURCES/tap-gui-viewer-secret.yaml || true
      kubectl delete -f $GENERATED/store_ca.yaml || true
      kubectl delete secret generic store-auth-token -n metadata-store-secrets || true
      ;;
    iterate)
      kubectl delete -f $RESOURCES/tap-gui-viewer-service-account-rbac.yaml || true
      kubectl delete -f $RESOURCES/tap-gui-viewer-secret.yaml || true
      kubectl delete -f $GENERATED/store_ca.yaml || true
      kubectl delete secret generic store-auth-token -n metadata-store-secrets || true
      ;;
    view)
      kubectl delete -f $RESOURCES/metadata-store-read-only.yaml || true
      kubectl delete secret ingress-cert -n metadata-store || true
      ;;
  esac

  deleteRoute53Record $CLUSTER_NAME_SUFFIX
  tapUninstallFull
  deleteTapRegistrySecret
  deletePackageRepository
  deleteTanzuClusterEssentials
  deleteTapNamespace

  echo "TAP uninstall done..."
}



function tapInstallWorkloadMain {
  echo "tapInstallWorkloadMain ..."
  readUserInputs
  aws eks update-kubeconfig --name ${TAP_CLUSTER_NAME}
  tapPrepWorkloadInstall

  echo DEVELOPER_NAMESPACE $DEVELOPER_NAMESPACE

  case $CLUSTER_NAME_SUFFIX in
    build)
      DEV_NAMESPACE_ARN=$(yq -r .repositories.workload.build_cluster_arn $INPUTS/user-input-values.yaml)
      echo DEV_NAMESPACE_ARN $DEV_NAMESPACE_ARN

      kubectl -n $DEVELOPER_NAMESPACE apply -f $RESOURCES/scan-policy.yaml
      kubectl -n $DEVELOPER_NAMESPACE annotate serviceaccount default eks.amazonaws.com/role-arn=$DEV_NAMESPACE_ARN --overwrite

      kubectl -n $DEVELOPER_NAMESPACE apply -f $RESOURCES/pipeline.yaml
      banner "Installing Sample Workload on Build Cluster"
      tanzu apps workload apply -f $RESOURCES/workload-aws.yaml -n $DEVELOPER_NAMESPACE --yes
      # let the supply-chain to complete before generating deliverable
      sleep 60
      tapWorkloadGenerateDeliverable
      ;;
    run)
      tapWorkloadApplyDeliverable
      ;;
    iterate)
      DEV_NAMESPACE_ARN=$(yq -r .repositories.workload.iterate_cluster_arn $INPUTS/user-input-values.yaml)
      echo DEV_NAMESPACE_ARN $DEV_NAMESPACE_ARN
      kubectl -n $DEVELOPER_NAMESPACE annotate serviceaccount default eks.amazonaws.com/role-arn=$DEV_NAMESPACE_ARN --overwrite

      #note: scan-policy cannot work in iterate-cluster
      kubectl -n $DEVELOPER_NAMESPACE apply -f $RESOURCES/pipeline.yaml
      banner "Installing Sample Workload on Iterate Cluster"
      tanzu apps workload apply -f $RESOURCES/workload-aws.yaml -n $DEVELOPER_NAMESPACE --yes
      ;;
    view)
      ;;
    single)
      DEV_NAMESPACE_ARN=$(yq -r .repositories.workload.build_cluster_arn $INPUTS/user-input-values.yaml)
      echo DEV_NAMESPACE_ARN $DEV_NAMESPACE_ARN

      kubectl -n $DEVELOPER_NAMESPACE apply -f $RESOURCES/scan-policy.yaml
      kubectl -n $DEVELOPER_NAMESPACE annotate serviceaccount default eks.amazonaws.com/role-arn=$DEV_NAMESPACE_ARN --overwrite

      kubectl -n $DEVELOPER_NAMESPACE apply -f $RESOURCES/pipeline.yaml
      banner "Installing Sample Workload in Single Cluster"
      tanzu apps workload apply -f $RESOURCES/workload-aws.yaml -n $DEVELOPER_NAMESPACE --yes
      ;;
  esac
}

function tapUninstallWorkloadMain {
  echo "tapUninstallWorkloadMain ..."
  readUserInputs
  aws eks update-kubeconfig --name ${TAP_CLUSTER_NAME}

  case $CLUSTER_NAME_SUFFIX in
    build)
      banner "Deleting workload $SAMPLE_APP_NAME from Build Cluster"
      tanzu apps workload delete $SAMPLE_APP_NAME -n $DEVELOPER_NAMESPACE --yes || true
      kubectl -n $DEVELOPER_NAMESPACE delete -f $RESOURCES/pipeline.yaml || true
      kubectl -n $DEVELOPER_NAMESPACE delete -f $RESOURCES/scan-policy.yaml || true
      ;;
    run)
      kubectl delete -f ${GENERATED}/${SAMPLE_APP_NAME}-delivery.yaml -n $DEVELOPER_NAMESPACE || true
      ;;
    iterate)
      banner "Deleting workload $SAMPLE_APP_NAME from Iterate Cluster"
      tanzu apps workload delete $SAMPLE_APP_NAME -n $DEVELOPER_NAMESPACE --yes || true
      kubectl -n $DEVELOPER_NAMESPACE delete -f $RESOURCES/pipeline.yaml || true
      # Note: scan-policy is not present on iteate-cluster
      ;;
    view)
      ;;
    single)
      banner "Deleting workload $SAMPLE_APP_NAME from Single Cluster"
      tanzu apps workload delete $SAMPLE_APP_NAME -n $DEVELOPER_NAMESPACE --yes || true
      kubectl -n $DEVELOPER_NAMESPACE delete -f $RESOURCES/pipeline.yaml || true
      kubectl -n $DEVELOPER_NAMESPACE delete -f $RESOURCES/scan-policy.yaml || true
      ;;
  esac
}

function tapTestPreReqs {
  banner "TAP test prerequisites..."
  verifyK8ClusterAccess $TAP_CLUSTER_NAME
  echo "TAP test prerequisites done..."
}

function tapPrepViewCluster  {
  banner "tapPrepViewCluster ..."
  readUserInputs
  tapPrepViewClusterToken
  tapPrepIterateClusterToken
  tapPrepBuildClusterToken
  tapPrepRunClusterToken
  parseUserInputsViewCluster
  aws eks update-kubeconfig --name ${TAP_CLUSTER_NAME}
  tapInstallFull "tap-values-$CLUSTER_NAME_SUFFIX.yaml"  
}

function tapRunTestsMain {
  echo "tapRunTestsMain ..."
  readUserInputs
  aws eks update-kubeconfig --name ${TAP_CLUSTER_NAME}

  TAP_GUI_URL="None"
  WORKLOAD_URL="None"
  case $CLUSTER_NAME_SUFFIX in
    build)
      ;;
    run)
      TAP_GUI_URL="https://tap-gui.view.${DOMAIN_NAME}"
      WORKLOAD_URL="http://${SAMPLE_APP_NAME}.${DEVELOPER_NAMESPACE}.run.${DOMAIN_NAME}"
      echo "Running Tests on Run Cluster"
      runTestCasesTAPGUI $TAP_GUI_URL
      runTestCasesTAPWK $WORKLOAD_URL
      ;;
    iterate)
      TAP_GUI_URL="https://tap-gui.iterate.${DOMAIN_NAME}"
      WORKLOAD_URL="http://${SAMPLE_APP_NAME}.${DEVELOPER_NAMESPACE}.iterate.${DOMAIN_NAME}"
      echo "Running Tests on Iterate Cluster"
      runTestCasesTAPWK  $WORKLOAD_URL
      ;;
    view)
      ;;
    single)
      TAP_GUI_URL="https://tap-gui.${DOMAIN_NAME}"
      WORKLOAD_URL="http://${SAMPLE_APP_NAME}.${DEVELOPER_NAMESPACE}.${DOMAIN_NAME}"
      echo "Running Tests on Single Cluster"
      runTestCasesTAPGUI $TAP_GUI_URL
      runTestCasesTAPWK $WORKLOAD_URL
      ;;
  esac
}

#####
##### Main code starts here
#####

while [[ "$#" -gt 0 ]]
do
  case $1 in
    single)
      CLUSTER_NAME_SUFFIX="single"
      ;;
    build)
      CLUSTER_NAME_SUFFIX="build"
      ;;
    run)
      CLUSTER_NAME_SUFFIX="run"
      ;;
    view)
      CLUSTER_NAME_SUFFIX="view"
      ;;
    iterate)
      CLUSTER_NAME_SUFFIX="iterate"
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

if [[ -z "$cmd" || -z "$CLUSTER_NAME_SUFFIX" ]]
then
  cat <<EOT
  Usage: $0 -c {install | uninstall | prereqs} { build | run | view | iterate | single } [-s | --skipinit]
EOT
  fail "Try Again"
fi

echo COMMAND=$cmd SKIPINIT=$skipinit CLUTER_SUFFIX=$CLUSTER_NAME_SUFFIX SCRIPT_DIR=$SCRIPT_DIR
echo "This script is running as group $(id -gn)"
export DOWNLOADS="$(dirname "$SCRIPT_DIR")/downloads"
export INPUTS="$SCRIPT_DIR/inputs"
export GENERATED="$(dirname "$SCRIPT_DIR")/generated"
export RESOURCES="$SCRIPT_DIR/resources"
export CLUSTER_NAME_PREFIX=$(yq -r .cluster.name $INPUTS/user-input-values.yaml)
export CLUSTER_ARCH=$(yq -r .cluster.arch $INPUTS/user-input-values.yaml)
if [[ $CLUSTER_ARCH == "single" ]]
then
  export TAP_CLUSTER_NAME="$CLUSTER_NAME_PREFIX"
else
  export TAP_CLUSTER_NAME="$CLUSTER_NAME_PREFIX-$CLUSTER_NAME_SUFFIX"
fi
echo TAP_CLUSTER_NAME $TAP_CLUSTER_NAME
case $cmd in
"runtests")
  tapRunTestsMain
  ;;
"installwk")
  tapInstallWorkloadMain
  ;;
"uninstallwk")
  tapUninstallWorkloadMain
  ;;
"install")
  tapInstallMain
  ;;
"uninstall")
  tapUninstallMain
  ;;
"prereqs")
  tapTestPreReqs
  ;;
"prepview")
  tapPrepViewCluster
  ;;
esac
