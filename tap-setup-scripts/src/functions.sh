#!/bin/bash

function banner {
  local line
  # echo ""
  for line in "$@"
  do
    echo "### $line"
  done
  echo ""
}

function message {
  local line
  for line in "$@"
  do
    echo ">>> $line"
  done
}

function fatal {
  message "ERROR: $*"
  exit 1
}

function requireValue {
  local varName

  for varName in $*
  do
    if [[ -z "${!varName}" ]]
    then
      fatal "Variable $varName is missing at line $(caller)"
    fi
  done
}

function fail {
  echo $1 >&2
  exit 1
}
# Wait until there is no (non-error) output from a command
function waitForRemoval {
  local n=1
  local max=5
  local delay=5
  echo "Waiting for $@"
  while [[ -n $("$@" 2> /dev/null || true) ]]
  do
    if [[ $n -lt $max ]]; then
      ((n++))
      echo "Command failed. Attempt $n/$max:"
      sleep $delay;
    else
     fail "The command has failed after $n attempts."
    fi
  done
}

function installTools {
  # install tools required in the scripts
  sudo apt-get -y update
  sudo apt-get install -y uuid-runtime vim sudo curl wget
  sudo apt-get install -y jq python3-pip

  # install awscli
  sudo pip3 install yq
  # sudo apt install -y awscli
  sudo pip3 install awscli --upgrade

  #install yq
  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod a+x /usr/local/bin/yq

  #install carvel tools
  # perl is needed for shasum
  sudo apt-get -y update
  sudo apt-get install -y  perl ca-certificates
  sudo update-ca-certificates
  sudo rm -rf /var/lib/apt/lists/*
  sudo bash -c "set -eo pipefail; wget -O- https://carvel.dev/install.sh | bash"

  # install kubectl
  export AWS_KUBECTL_VERSION="1.22.6/2022-03-09"
  sudo curl -o kubectl  https://amazon-eks.s3-us-west-2.amazonaws.com/${AWS_KUBECTL_VERSION}/bin/linux/amd64/kubectl
  sudo chmod +x kubectl
  sudo mv kubectl /usr/local/bin/

  # install Docker
  sudo curl -sSL https://get.docker.com/ | sh
  sudo groupadd docker 2>/dev/null || true
  sudo usermod -aG docker ${USER} 2>/dev/null || true
  newgrp docker || true

  # aws-iam-authenticator
  curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator
  chmod +x ./aws-iam-authenticator
  sudo mv ./aws-iam-authenticator /usr/local/bin/

}


function installTanzuCLI {
  banner "Downloading kapp, secretgen configuration bundle & tanzu cli"

  mkdir -p $DOWNLOADS

  if [[ ! -f $DOWNLOADS/pivnet ]]
  then
    echo "Installing pivnet CLI"

    curl -Lo $DOWNLOADS/pivnet https://github.com/pivotal-cf/pivnet-cli/releases/download/v3.0.1/pivnet-linux-amd64-3.0.1
    # sudo install -o user -g user -m 0755 $DOWNLOADS/pivnet /usr/local/bin/pivnet
    sudo install -o ubuntu -g ubuntu -m 0755 $DOWNLOADS/pivnet /usr/local/bin/pivnet
  else
    echo "pivnet CLI already present"
  fi

  if [[ ! -d $DOWNLOADS/tanzu-cluster-essentials ]]
  then
    pivnet login --api-token="$PIVNET_TOKEN"

    ESSENTIALS_VERSION=1.1.0
    ESSENTIALS_FILE_NAME=tanzu-cluster-essentials-linux-amd64-$ESSENTIALS_VERSION.tgz
    ESSENTIALS_FILE_ID=1191987

    pivnet download-product-files \
      --download-dir $DOWNLOADS \
      --product-slug='tanzu-cluster-essentials' \
      --release-version=$ESSENTIALS_VERSION \
      --product-file-id=$ESSENTIALS_FILE_ID

    mkdir -p $DOWNLOADS/tanzu-cluster-essentials
    tar xvf $DOWNLOADS/$ESSENTIALS_FILE_NAME -C $DOWNLOADS/tanzu-cluster-essentials
  else
    echo "tanzu-cluster-essentials already present"
  fi

  TANZU_DIR=$DOWNLOADS/tanzu
  if [[ ! -d $TANZU_DIR ]]
  then
    mkdir -p $TANZU_DIR
    export TANZU_CLI_NO_INIT=true

    pivnet login --api-token="$PIVNET_TOKEN"

    TANZUCLI_FILE_NAME=tanzu-framework-linux-amd64.tar
    TANZUCLI_FILE_ID=$(pivnet product-files \
      -p tanzu-application-platform \
      -r $TAP_VERSION \
      --format=json | jq '.[] | select(.name == "tanzu-framework-bundle-linux").id' )

    pivnet download-product-files \
      --download-dir $DOWNLOADS \
      --product-slug='tanzu-application-platform' \
      --release-version=$TAP_VERSION \
      --product-file-id=$TANZUCLI_FILE_ID

    tar xvf $DOWNLOADS/$TANZUCLI_FILE_NAME -C $TANZU_DIR
    export TANZU_CLI_NO_INIT=true
    MOST_RECENT_CLI=$(find $TANZU_DIR/cli/core/ -name tanzu-core-linux_amd64 | xargs ls -t | head -n 1)
    echo "Installing Tanzu CLI"
    sudo install -m 0755 $MOST_RECENT_CLI /usr/local/bin/tanzu
    cd $TANZU_DIR
    tanzu plugin install --local cli all
    cd ../..

  else
    echo "tanzu-framework-linux already present"
  fi
}

function verifyTools {

  banner "echo all tool versions"

  ytt version
  echo ''
  kapp version
  echo ''
  kbld version
  echo ''
  kwt version
  echo ''
  imgpkg version
  echo ''
  vendir version
  echo ''
  aws --version
  echo ''
  kubectl version --client
  echo ''
  uuidgen --version
  echo ''
  jq --version
  echo ''
  yq --version
  echo ''
  curl --version
  echo ''
  docker --version
  echo ''
  tanzu version
  tanzu plugin list
  echo ''
}

function readUserInputs {

  banner "Reading $INPUTS/user-input-values.yaml"

  # tap_ecr_registry values
  export TAP_ECR_REGISTRY_HOSTNAME=$(yq .tap_ecr_registry.hostname $INPUTS/user-input-values.yaml)
  export TAP_ECR_REGISTRY_REPOSITORY=$(yq .tap_ecr_registry.repository $INPUTS/user-input-values.yaml)
  export TAP_ECR_REGISTRY_REGION=$(yq .tap_ecr_registry.region $INPUTS/user-input-values.yaml)

  # tap_ecr_registry values
  export ESSENTIALS_ECR_REGISTRY_HOSTNAME=$(yq .cluster_essentials_ecr_registry.hostname $INPUTS/user-input-values.yaml)
  export ESSENTIALS_ECR_REGISTRY_REPOSITORY=$(yq .cluster_essentials_ecr_registry.repository $INPUTS/user-input-values.yaml)
  export ESSENTIALS_ECR_REGISTRY_REGION=$(yq .cluster_essentials_ecr_registry.region $INPUTS/user-input-values.yaml)

  # tbs_ecr_registry values
  export TBS_ECR_REGISTRY_HOSTNAME=$(yq .tbs_ecr_registry.hostname $INPUTS/user-input-values.yaml)
  export TBS_ECR_REGISTRY_REPOSITORY=$(yq .tbs_ecr_registry.repository $INPUTS/user-input-values.yaml)
  export TBS_ECR_REGISTRY_REGION=$(yq .tbs_ecr_registry.region $INPUTS/user-input-values.yaml)

  # ootb_ecr_registry values
  export OOTB_ECR_REGISTRY_HOSTNAME=$(yq .ootb_ecr_registry.hostname $INPUTS/user-input-values.yaml)
  export OOTB_ECR_REGISTRY_REPOSITORY=$(yq .ootb_ecr_registry.repository $INPUTS/user-input-values.yaml)
  export OOTB_ECR_REGISTRY_REGION=$(yq .ootb_ecr_registry.region $INPUTS/user-input-values.yaml)

  DEVELOPER_NAMESPACE=$(yq .workload.namespace $INPUTS/user-input-values.yaml)
  SAMPLE_APP_NAME=$(yq .workload.name $INPUTS/user-input-values.yaml)

  AWS_REGION=`curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region`
  AWS_ACCOUNT=`curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId`
  CLUSTER_NAME=$(yq .aws.eks_cluster_name $INPUTS/user-input-values.yaml)
  AWS_DOMAIN_NAME=$(yq .aws.domain $INPUTS/user-input-values.yaml)
}

function readTAPInternalValues {

  banner "Reading $INPUTS/tap-config-internal-values.yaml"
  export TANZUNET_REGISTRY_HOSTNAME=$(yq .tanzunet.hostname $INPUTS/tap-config-internal-values.yaml)
  export TANZUNET_REGISTRY_USERNAME=$(yq .tanzunet.username $INPUTS/tap-config-internal-values.yaml)
  export TANZUNET_REGISTRY_PASSWORD=$(yq .tanzunet.password $INPUTS/tap-config-internal-values.yaml)
  export PIVNET_TOKEN=$(yq .tanzunet.pivnet_token $INPUTS/tap-config-internal-values.yaml)

  TAP_VERSION=$(yq .tap.version $INPUTS/tap-config-internal-values.yaml)
  TAP_PACKAGE_NAME=$(yq .tap.name $INPUTS/tap-config-internal-values.yaml)
  TAP_NAMESPACE=$(yq .tap.namespace $INPUTS/tap-config-internal-values.yaml)

  export ESSENTIALS_BUNDLE=$(yq .cluster_essentials_bundle.bundle $INPUTS/tap-config-internal-values.yaml)
  export ESSENTIALS_BUNDLE_SHA256=$(yq .cluster_essentials_bundle.bundle_sha256 $INPUTS/tap-config-internal-values.yaml)

}

function parseUserInputs {

  banner "getting ECR registry credentials"

  export TAP_ECR_REGISTRY_USERNAME=AWS
  export TAP_ECR_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $TAP_ECR_REGISTRY_REGION)

  export ESSENTIALS_ECR_REGISTRY_USERNAME=AWS
  export ESSENTIALS_ECR_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $ESSENTIALS_ECR_REGISTRY_REGION)

  export TBS_ECR_REGISTRY_USERNAME=AWS
  export TBS_ECR_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $TBS_ECR_REGISTRY_REGION)

  export OOTB_ECR_REGISTRY_USERNAME=AWS
  export OOTB_ECR_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $OOTB_ECR_REGISTRY_REGION)

  # echo TAP_ECR_REGISTRY_PASSWORD $TAP_ECR_REGISTRY_PASSWORD
  # echo ESSENTIALS_ECR_REGISTRY_PASSWORD $ESSENTIALS_ECR_REGISTRY_PASSWORD
  # echo TBS_ECR_REGISTRY_PASSWORD $TBS_ECR_REGISTRY_PASSWORD
  # echo OOTB_ECR_REGISTRY_PASSWORD $OOTB_ECR_REGISTRY_PASSWORD
  rm -rf $GENERATED
  mkdir -p $GENERATED

  cat $INPUTS/tap-config-internal-values.yaml $INPUTS/user-input-values.yaml > $GENERATED/user-input-values.yaml

  banner "Generating tap-values.yaml"

  ytt -f $INPUTS/tap-values.yaml -f $GENERATED/user-input-values.yaml \
  	--data-value tbs_ecr_registry.username=$TBS_ECR_REGISTRY_USERNAME \
  	--data-value tbs_ecr_registry.password=$TBS_ECR_REGISTRY_PASSWORD \
    --ignore-unknown-comments > $GENERATED/tap-values.yaml
}


function installTanzuClusterEssentials {
  requireValue TAP_VERSION  \
    ESSENTIALS_ECR_REGISTRY_HOSTNAME ESSENTIALS_ECR_REGISTRY_REPOSITORY \
    ESSENTIALS_ECR_REGISTRY_USERNAME ESSENTIALS_ECR_REGISTRY_PASSWORD

  # tanzu-cluster-essentials install.sh script needs INSTALL_BUNDLE & below INSTALL_XXX params
  export INSTALL_BUNDLE=$ESSENTIALS_ECR_REGISTRY_HOSTNAME/$ESSENTIALS_ECR_REGISTRY_REPOSITORY@$ESSENTIALS_BUNDLE_SHA256
  export INSTALL_REGISTRY_HOSTNAME=$ESSENTIALS_ECR_REGISTRY_HOSTNAME
  export INSTALL_REGISTRY_USERNAME=$ESSENTIALS_ECR_REGISTRY_USERNAME
  export INSTALL_REGISTRY_PASSWORD=$ESSENTIALS_ECR_REGISTRY_PASSWORD
  # echo INSTALL_BUNDLE $INSTALL_BUNDLE
  # echo INSTALL_REGISTRY_HOSTNAME $INSTALL_REGISTRY_HOSTNAME
  # echo INSTALL_REGISTRY_USERNAME $INSTALL_REGISTRY_USERNAME
  # echo INSTALL_REGISTRY_PASSWORD $INSTALL_REGISTRY_PASSWORD

  banner "Deploy kapp, secretgen configuration bundle & install tanzu CLI"

  cd $DOWNLOADS/tanzu-cluster-essentials
  ./install.sh --yes
  cd ../..

}

function verifyK8ClusterAccess {
  requireValue CLUSTER_NAME AWS_REGION

  rm -rf ~/.kube
  mkdir -p ~/.kube
  touch ~/.kube/config

  banner "Verify EKS Cluster ${CLUSTER_NAME} access"
  aws sts get-caller-identity
  aws eks --region ${AWS_REGION} update-kubeconfig --name ${CLUSTER_NAME}
  kubectl config current-context
  kubectl get nodes
}

function createTapNamespace {

  requireValue TAP_NAMESPACE DEVELOPER_NAMESPACE

  banner "Creating $TAP_NAMESPACE namespace"

  (kubectl get ns $TAP_NAMESPACE 2> /dev/null) || \
    kubectl create ns $TAP_NAMESPACE

  banner "Creating $DEVELOPER_NAMESPACE namespace"

  (kubectl get ns $DEVELOPER_NAMESPACE 2> /dev/null) || \
    kubectl create ns $DEVELOPER_NAMESPACE
}


function loadPackageRepository {
  requireValue TAP_VERSION TAP_NAMESPACE \
    TAP_ECR_REGISTRY_HOSTNAME TAP_ECR_REGISTRY_REPOSITORY

  banner "Removing any current TAP package repository"

  tanzu package repository delete tanzu-tap-repository -n $TAP_NAMESPACE --yes || true
  waitForRemoval tanzu package repository get tanzu-tap-repository -n $TAP_NAMESPACE -o json

  banner "Adding TAP package repository"

  tanzu package repository add tanzu-tap-repository \
      --url $TAP_ECR_REGISTRY_HOSTNAME/$TAP_ECR_REGISTRY_REPOSITORY:$TAP_VERSION \
      --namespace $TAP_NAMESPACE
  tanzu package repository get tanzu-tap-repository --namespace $TAP_NAMESPACE
  while [[ $(tanzu package available list --namespace $TAP_NAMESPACE -o json) == '[]' ]]
  do
    message "Waiting for packages ..."
    sleep 5
  done
}

function createTapRegistrySecret {
  requireValue TAP_ECR_REGISTRY_USERNAME TAP_ECR_REGISTRY_PASSWORD TAP_ECR_REGISTRY_HOSTNAME TAP_NAMESPACE

  banner "Creating tap-registry registry secret"

  tanzu secret registry delete tap-registry --namespace $TAP_NAMESPACE -y || true
  waitForRemoval kubectl get secret tap-registry --namespace $TAP_NAMESPACE -o json

  tanzu secret registry add tap-registry \
    --username "$TAP_ECR_REGISTRY_USERNAME" --password "$TAP_ECR_REGISTRY_PASSWORD" \
    --server $TAP_ECR_REGISTRY_HOSTNAME \
    --export-to-all-namespaces --namespace $TAP_NAMESPACE --yes
}

function tapInstallFull {
  requireValue TAP_PACKAGE_NAME TAP_VERSION TAP_NAMESPACE

  banner "Installing TAP values from $GENERATED/tap-values.yaml..."

  first_time=$(tanzu package installed get $TAP_PACKAGE_NAME  -n $TAP_NAMESPACE  -o json 2>/dev/null)

  if [[ -z $first_time ]]
  then
    tanzu package install $TAP_PACKAGE_NAME -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file $GENERATED/tap-values.yaml -n $TAP_NAMESPACE || true
  else
    tanzu package installed update $TAP_PACKAGE_NAME -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file $GENERATED/tap-values.yaml -n $TAP_NAMESPACE || true
  fi

  banner "Checking state of all packages"
  local RETRIES=10
  local DELAY=15
  local EXIT="false"

  while [[ $RETRIES -gt 0 && $EXIT == "false" ]]
  do
    echo "Number of RETRIES=$RETRIES"
    EXIT="true"
    rm -rf $GENERATED/tap-packages-installed-list.txt
    tanzu package installed list --namespace $TAP_NAMESPACE  -o json | \
      jq -r '.[] | (.name + " " + .status)' > $GENERATED/tap-packages-installed-list.txt
      while read package status
      do
        if [[ "$status" != "Reconcile succeeded" ]]
        then
          message "package($package) failed to reconcile ($status), waiting for reconcile"
          # reconcilePackageInstall $TAP_NAMESPACE $package
          kctrl package installed kick -i $package -n $TAP_NAMESPACE
          sleep $DELAY
          EXIT="false"
        fi
      done < $GENERATED/tap-packages-installed-list.txt
      ((RETRIES=RETRIES-1))
  done
  sleep $DELAY

  banner "Checking for ERRORs in all packages"
  tanzu package installed list --namespace $TAP_NAMESPACE  -o json | \
    jq -r '.[] | (.name + " " + .status)' | \
    while read package status
    do
      if [[ "$status" != "Reconcile succeeded" ]]
      then
        message "ERROR: At least one package ($package) failed to reconcile ($status)"
        exit 1
      fi
    done
  banner "TAP Installation is Complete."
}

function tapWorkloadInstallFull {

  requireValue OOTB_ECR_REGISTRY_USERNAME OOTB_ECR_REGISTRY_PASSWORD OOTB_ECR_REGISTRY_HOSTNAME \
    DEVELOPER_NAMESPACE SAMPLE_APP_NAME

  banner "Installing Sample Workload"

  # 'registry-credentials' is used in tap-values.yaml & developer-namespace.yaml files
  tanzu secret registry add registry-credentials --username ${OOTB_ECR_REGISTRY_USERNAME} --password ${OOTB_ECR_REGISTRY_PASSWORD} --server ${OOTB_ECR_REGISTRY_HOSTNAME} --namespace ${DEVELOPER_NAMESPACE}


  kubectl -n $DEVELOPER_NAMESPACE apply -f $RESOURCES/developer-namespace.yaml
  kubectl -n $DEVELOPER_NAMESPACE apply -f $RESOURCES/pipeline.yaml
  kubectl -n $DEVELOPER_NAMESPACE apply -f $RESOURCES/scan-policy.yaml

  tanzu apps workload apply -f $RESOURCES/workload-aws.yaml -n $DEVELOPER_NAMESPACE --yes

}

function tapWorkloadUninstallFull {
  requireValue DEVELOPER_NAMESPACE SAMPLE_APP_NAME

  banner "Deleting workload $SAMPLE_APP_NAME from Developer namespace"
  tanzu apps workload delete $SAMPLE_APP_NAME -n $DEVELOPER_NAMESPACE --yes || true

  banner "Removing registry-credentials secret from Developer namespace"
  tanzu secret registry delete registry-credentials --namespace $DEVELOPER_NAMESPACE --yes || true
  waitForRemoval kubectl get secret registry-credentials --namespace $DEVELOPER_NAMESPACE -o json

  kubectl -n $DEVELOPER_NAMESPACE delete -f $RESOURCES/developer-namespace.yaml || true
  kubectl -n $DEVELOPER_NAMESPACE delete -f $RESOURCES/pipeline.yaml || true
  kubectl -n $DEVELOPER_NAMESPACE delete -f $RESOURCES/scan-policy.yaml || true
}

function tapUninstallFull {
  requireValue TAP_PACKAGE_NAME TAP_NAMESPACE

  banner "Uninstalling TAP ..."
  tanzu package installed delete $TAP_PACKAGE_NAME -n $TAP_NAMESPACE --yes || true
  waitForRemoval tanzu package installed get $TAP_PACKAGE_NAME -n $TAP_NAMESPACE -o json

}

function deleteTapRegistrySecret {
  requireValue  TAP_NAMESPACE

  banner "Removing tap-registry registry secret"

  tanzu secret registry delete tap-registry --namespace $TAP_NAMESPACE -y || true
  waitForRemoval kubectl get secret tap-registry --namespace $TAP_NAMESPACE -o json
}

function deletePackageRepository {
  requireValue TAP_NAMESPACE

  banner "Removing current TAP package repository"

  tanzu package repository delete tanzu-tap-repository -n $TAP_NAMESPACE --yes || true
  waitForRemoval tanzu package repository get tanzu-tap-repository -n $TAP_NAMESPACE -o json
}

function deleteTanzuClusterEssentials {

  banner "Removing kapp-controller & secretgen-controller"
  cd $DOWNLOADS/tanzu-cluster-essentials
  ./uninstall.sh --yes
  cd ../..
}

function deleteTapNamespace {
  requireValue TAP_NAMESPACE

  banner "Removing Developer namespace"
  kubectl delete ns $DEVELOPER_NAMESPACE || true
  waitForRemoval kubectl get ns $DEVELOPER_NAMESPACE -o json

  banner "Removing TAP namespace"
  kubectl delete namespace $TAP_NAMESPACE || true
  waitForRemoval kubectl get namespace $TAP_NAMESPACE -o json
}


function relocateTAPPackages {
  # Relocate the images with the Carvel tool imgpkg
  # ECR_REPOSITORY to be pre-created

  requireValue TANZUNET_REGISTRY_USERNAME TANZUNET_REGISTRY_PASSWORD \
    TANZUNET_REGISTRY_HOSTNAME TAP_VERSION ESSENTIALS_BUNDLE ESSENTIALS_BUNDLE_SHA256 \
    TAP_ECR_REGISTRY_HOSTNAME TAP_ECR_REGISTRY_REPOSITORY \
    TAP_ECR_REGISTRY_USERNAME TAP_ECR_REGISTRY_PASSWORD  \
    ESSENTIALS_ECR_REGISTRY_HOSTNAME ESSENTIALS_ECR_REGISTRY_REPOSITORY \
    ESSENTIALS_ECR_REGISTRY_USERNAME ESSENTIALS_ECR_REGISTRY_PASSWORD

  banner "Relocating TAP images, this will take time in minutes (30-45min) ..."

  docker login --username $TAP_ECR_REGISTRY_USERNAME --password $TAP_ECR_REGISTRY_PASSWORD $TAP_ECR_REGISTRY_HOSTNAME

  docker login --username $TANZUNET_REGISTRY_USERNAME --password $TANZUNET_REGISTRY_PASSWORD $TANZUNET_REGISTRY_HOSTNAME

  docker login --username $ESSENTIALS_ECR_REGISTRY_USERNAME --password $ESSENTIALS_ECR_REGISTRY_PASSWORD $ESSENTIALS_ECR_REGISTRY_HOSTNAME

  # --concurrency 2 is required for AWS
  echo "Relocating Tanzu Cluster Essentials Bundle"
  imgpkg copy --concurrency 2 -b ${ESSENTIALS_BUNDLE}@${ESSENTIALS_BUNDLE_SHA256} \
  --to-repo ${ESSENTIALS_ECR_REGISTRY_HOSTNAME}/${ESSENTIALS_ECR_REGISTRY_REPOSITORY}

  echo "Relocating TAP packages"
  imgpkg copy --concurrency 2 -b ${TANZUNET_REGISTRY_HOSTNAME}/tanzu-application-platform/tap-packages:${TAP_VERSION} \
   --to-repo ${TAP_ECR_REGISTRY_HOSTNAME}/${TAP_ECR_REGISTRY_REPOSITORY}
}

function printOutputParams {
  # envoy loadbalancer ip
  requireValue AWS_DOMAIN_NAME

  elb_hostname=$(kubectl get svc envoy -n tanzu-system-ingress -o jsonpath='{ .status.loadBalancer.ingress[0].hostname }' || true)
  echo "Create Route53 DNS CNAME record for *.$AWS_DOMAIN_NAME with $elb_hostname"

  tap_gui_url=$(yq .tap_gui.app_config.backend.baseUrl $GENERATED/tap-values.yaml)
  echo "TAP GUI URL $tap_gui_url"

}
