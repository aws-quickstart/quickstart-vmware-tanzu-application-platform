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

# Wait until there is no (non-error) output from a command
function waitForRemoval() {
  while [[ -n $("$@" 2> /dev/null || true) ]]
  do
    message "Waiting for resource to disappear ..."
    sleep 5
  done
}

function setupAWSConfig() {
  requireValue AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_ACCOUNT AWS_ROLE

  banner "Configuring AWS credentials..."

  rm -rf ~/.aws
  mkdir -p ~/.aws
  touch ~/.aws/credentials
  touch ~/.aws/config

  cat << EOF > ~/.aws/credentials
[$AWS_ROLE]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF

  cat << EOF > ~/.aws/config
[profile $AWS_ROLE]
region = $AWS_REGION
output = json

[profile $AWS_ACCOUNT]
role_arn = arn:aws:iam::$AWS_ACCOUNT:role/$AWS_ROLE
source_profile = $AWS_ROLE
region = $AWS_REGION
EOF

  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY

  aws sts get-caller-identity --profile $AWS_ACCOUNT
}

function verifyTools() {

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
}

function readUserInputs() {

  banner "Reading inputs/user-input-values.yaml"
  # tanzu-cluster-essentials install.sh script needs INSTALL_REGISTRY_xxx values
  export INSTALL_REGISTRY_HOSTNAME=$(yq -r .tanzunet.hostname inputs/user-input-values.yaml)
  export INSTALL_REGISTRY_USERNAME=$(yq -r .tanzunet.username inputs/user-input-values.yaml)
  export INSTALL_REGISTRY_PASSWORD=$(yq -r .tanzunet.password inputs/user-input-values.yaml)
  export PIVNET_TOKEN=$(yq -r .tanzunet.pivnet_token inputs/user-input-values.yaml)

  # tap_ecr_registry values
  export TAP_ECR_REGISTRY_HOSTNAME=$(yq -r .tap_ecr_registry.hostname inputs/user-input-values.yaml)
  export TAP_ECR_REGISTRY_REPOSITORY=$(yq -r .tap_ecr_registry.repository inputs/user-input-values.yaml)
  export TAP_ECR_REGISTRY_REGION=$(yq -r .tap_ecr_registry.region inputs/user-input-values.yaml)

  # container_tbs_ecr_registry values
  export TBS_ECR_REGISTRY_HOSTNAME=$(yq -r .container_tbs_ecr_registry.hostname inputs/user-input-values.yaml)
  export TBS_ECR_REGISTRY_REPOSITORY=$(yq -r .container_tbs_ecr_registry.repository inputs/user-input-values.yaml)
  export TBS_ECR_REGISTRY_REGION=$(yq -r .container_tbs_ecr_registry.region inputs/user-input-values.yaml)

  # container_workload_ecr_registry values
  export WRK_ECR_REGISTRY_HOSTNAME=$(yq -r .container_workload_ecr_registry.hostname inputs/user-input-values.yaml)
  export WRK_ECR_REGISTRY_REPOSITORY=$(yq -r .container_workload_ecr_registry.repository inputs/user-input-values.yaml)
  export WRK_ECR_REGISTRY_REGION=$(yq -r .container_workload_ecr_registry.region inputs/user-input-values.yaml)


  AWS_REGION=$(yq -r .aws.region inputs/user-input-values.yaml)
  AWS_ACCOUNT=$(yq -r .aws.account inputs/user-input-values.yaml)
  AWS_ROLE=$(yq -r .aws.role inputs/user-input-values.yaml)
  AWS_ACCESS_KEY_ID=$(yq -r .aws.access_key inputs/user-input-values.yaml)
  AWS_SECRET_ACCESS_KEY=$(yq -r .aws.secret_key inputs/user-input-values.yaml)
  CLUSTER_NAME=$(yq -r .aws.eks_cluster_name inputs/user-input-values.yaml)

  AWS_ROUTE53_ZONE_ID=$(yq -r .aws.route_fifty_three_zone_id inputs/user-input-values.yaml)
  AWS_DOMAIN_NAME=$(yq -r .ingress.domain inputs/user-input-values.yaml)
}

function readTAPInternalValues() {

  banner "Reading inputs/tap-config-internal-values.yaml"

  TAP_VERSION=$(yq -r .tap.version inputs/tap-config-internal-values.yaml)
  TAP_PACKAGE_NAME=$(yq -r .tap.name inputs/tap-config-internal-values.yaml)
  TAP_NAMESPACE=$(yq -r .tap.namespace inputs/tap-config-internal-values.yaml)

  # tanzu-cluster-essentials install.sh script needs INSTALL_BUNDLE
  export INSTALL_BUNDLE=$(yq -r .tap.install_bundle inputs/tap-config-internal-values.yaml)

  DEVELOPER_NAMESPACE=$(yq -r .workload.namespace inputs/tap-config-internal-values.yaml)
  SAMPLE_APP_NAME=$(yq -r .workload.name inputs/tap-config-internal-values.yaml)
}

# call this function after setupAWSConfig
function parseUserInputs() {

  banner "getting ECR registry credentials"

  export TAP_ECR_REGISTRY_USERNAME=AWS
  export TAP_ECR_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $TAP_ECR_REGISTRY_REGION --profile $AWS_ACCOUNT)

  export TBS_ECR_REGISTRY_USERNAME=AWS
  export TBS_ECR_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $TBS_ECR_REGISTRY_REGION --profile $AWS_ACCOUNT)

  export WRK_ECR_REGISTRY_USERNAME=AWS
  export WRK_ECR_REGISTRY_PASSWORD=$(aws ecr get-login-password --region $WRK_ECR_REGISTRY_REGION --profile $AWS_ACCOUNT)

  export CONTAINER_REGISTRY_HOSTNAME=$WRK_ECR_REGISTRY_HOSTNAME
  export CONTAINER_REGISTRY_USERNAME=$WRK_ECR_REGISTRY_USERNAME
  export CONTAINER_REGISTRY_PASSWORD=$WRK_ECR_REGISTRY_PASSWORD


  GENERATED=$HOME/generated
  rm -rf $GENERATED
  mkdir -p $GENERATED

  cat inputs/tap-config-internal-values.yaml inputs/user-input-values.yaml > $GENERATED/user-input-values.yaml

  banner "Generating tap-values.yaml"

  ytt -f inputs/tap-values.yaml -f $GENERATED/user-input-values.yaml \
  	--data-value container_tbs_ecr_registry.username=$TBS_ECR_REGISTRY_USERNAME \
  	--data-value container_tbs_ecr_registry.password=$TBS_ECR_REGISTRY_PASSWORD \
    --ignore-unknown-comments > $GENERATED/tap-values.yaml
}


function setupTanzuCLIandDeployKapp() {
  requireValue TAP_VERSION AWS_REGION AWS_ACCOUNT AWS_ROLE \
    INSTALL_BUNDLE INSTALL_REGISTRY_HOSTNAME INSTALL_REGISTRY_USERNAME INSTALL_REGISTRY_PASSWORD

  banner "Deploy kapp, secretgen configuration bundle & install tanzu CLI"

  DOWNLOADS=$HOME/downloads
  sudo install -o user -g user -m 0755 $DOWNLOADS/pivnet /usr/local/bin/pivnet
  ESSENTIALS_VERSION=$TAP_VERSION
  ESSENTIALS_FILE_NAME=tanzu-cluster-essentials-linux-amd64-$ESSENTIALS_VERSION.tgz
  cd $DOWNLOADS/tanzu-cluster-essentials
  ./install.sh --yes
  cd ../..

  export TANZU_CLI_NO_INIT=true
  TANZU_DIR=$DOWNLOADS/tanzu
  MOST_RECENT_CLI=$(find $TANZU_DIR/cli/core/ -name tanzu-core-linux_amd64 | xargs ls -t | head -n 1)
  echo "Installing Tanzu CLI"
  sudo install -m 0755 $MOST_RECENT_CLI /usr/local/bin/tanzu
  cd $TANZU_DIR
  tanzu plugin install --local cli all
  cd ../..
  tanzu version
  tanzu plugin list
}

function verifyK8ClusterAccess() {
  requireValue CLUSTER_NAME AWS_REGION AWS_ACCOUNT AWS_ROLE

  rm -rf ~/.kube
  mkdir -p ~/.kube
  touch ~/.kube/config

  banner "Verify EKS Cluster ${CLUSTER_NAME} access"
  aws eks --region ${AWS_REGION} update-kubeconfig --name ${CLUSTER_NAME} --profile $AWS_ACCOUNT
  kubectl config current-context
  kubectl get nodes
}

function createTapNamespace() {

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

function tapInstallFull(){
  requireValue TAP_PACKAGE_NAME TAP_VERSION TAP_NAMESPACE

  banner "Installing TAP ..."

  tanzu package installed delete $TAP_PACKAGE_NAME -n $TAP_NAMESPACE --yes || true

  tanzu package install $TAP_PACKAGE_NAME -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file $GENERATED/tap-values.yaml -n 
  banner "Checking state of all packages"

  tanzu package installed get tap -n tap-install

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

  banner "Setup complete."


}

function tapWorkloadInstallFull(){

  requireValue CONTAINER_REGISTRY_USERNAME CONTAINER_REGISTRY_PASSWORD CONTAINER_REGISTRY_HOSTNAME \
    DEVELOPER_NAMESPACE SAMPLE_APP_NAME

  banner "Installing sample workload"

  tanzu secret registry add registry-credentials --username ${CONTAINER_REGISTRY_USERNAME} --password ${CONTAINER_REGISTRY_PASSWORD} --server ${CONTAINER_REGISTRY_HOSTNAME} --namespace ${DEVELOPER_NAMESPACE}

  kubectl -n $DEVELOPER_NAMESPACE apply -f resources/developer-namespace.yaml
  kubectl -n $DEVELOPER_NAMESPACE apply -f resources/pipeline.yaml
  kubectl -n $DEVELOPER_NAMESPACE apply -f resources/scan-policy.yaml
  # kubectl -n $DEVELOPER_NAMESPACE apply -f resources/git-ssh-basic-auth.yaml

  (tanzu apps workload get $SAMPLE_APP_NAME -n $DEVELOPER_NAMESPACE -o json 2> /dev/null) || \
  tanzu apps workload apply -f resources/workload-aws.yaml -n $DEVELOPER_NAMESPACE --yes

}

function createDnsRecord {

  requireValue AWS_DOMAIN_NAME AWS_ACCOUNT
  # requireValue AWS_ROUTE53_ZONE_ID

  fqdn=$AWS_DOMAIN_NAME
  zone_id=$AWS_ROUTE53_ZONE_ID

  # envoy loadbalancer ip
  elb_hostname=$(kubectl get svc envoy -n tanzu-system-ingress -o jsonpath='{ .status.loadBalancer.ingress[0].hostname }' || true)

  elb_zone_id=$(aws elb describe-load-balancers --profile $AWS_ACCOUNT | jq --arg DNSNAME "${elb_hostname}" '.LoadBalancerDescriptions[] | select( .DNSName == $DNSNAME ) | .CanonicalHostedZoneNameID ' | sed s/\"//g)

  file="$fqdn.json"
  cat > "$file" << EOF
{
    "Comment": "Creating $fqdn Alias resource record sets in Route 53",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "*.$fqdn",
                "Type": "CNAME",
                "AliasTarget": {
                    "HostedZoneId": "$elb_zone_id",
                    "DNSName": "$elb_hostname",
                    "EvaluateTargetHealth": false
                }
            }
        }
    ]
}
EOF
  banner "Creating Route53 DNS entry for $fqdn, hostname=$elb_hostname"

  aws route53 change-resource-record-sets --hosted-zone-id ${zone_id}  --change-batch "file://$file" --profile $AWS_ACCOUNT
}



function tapWorkloadUninstallFull() {
  requireValue DEVELOPER_NAMESPACE SAMPLE_APP_NAME

  banner "Deleting workload $SAMPLE_APP_NAME from Developer namespace"
  tanzu apps workload delete $SAMPLE_APP_NAME -n $DEVELOPER_NAMESPACE --yes || true

  banner "Removing registry-credentials secret from Developer namespace"
  tanzu secret registry delete registry-credentials --namespace $DEVELOPER_NAMESPACE --yes || true
  waitForRemoval kubectl get secret registry-credentials --namespace $DEVELOPER_NAMESPACE -o json

  kubectl -n $DEVELOPER_NAMESPACE delete -f resources/developer-namespace.yaml || true
  kubectl -n $DEVELOPER_NAMESPACE delete -f resources/pipeline.yaml || true
  kubectl -n $DEVELOPER_NAMESPACE delete -f resources/scan-policy.yaml || true
  # kubectl -n $DEVELOPER_NAMESPACE delete -f resources/git-ssh-basic-auth.yaml || true
}

function deleteDnsRecord() {
  requireValue

  banner "Deleting DNS Records"
}

function tapUninstallFull() {
  requireValue TAP_PACKAGE_NAME TAP_NAMESPACE

  banner "Uninstalling TAP ..."
  tanzu package installed delete $TAP_PACKAGE_NAME -n $TAP_NAMESPACE --yes || true
  waitForRemoval tanzu package installed get $TAP_PACKAGE_NAME -n $TAP_NAMESPACE -o json

}

function deleteTapRegistrySecret() {
  requireValue  TAP_NAMESPACE

  banner "Removing tap-registry registry secret"

  tanzu secret registry delete tap-registry --namespace $TAP_NAMESPACE -y || true
  waitForRemoval kubectl get secret tap-registry --namespace $TAP_NAMESPACE -o json
}

function deletePackageRepository() {
  requireValue TAP_NAMESPACE

  banner "Removing current TAP package repository"

  tanzu package repository delete tanzu-tap-repository -n $TAP_NAMESPACE --yes || true
  waitForRemoval tanzu package repository get tanzu-tap-repository -n $TAP_NAMESPACE -o json
}

function deleteTanzuCLIandKapp() {

  banner "Removing kapp-controller & secretgen-controller"
  DOWNLOADS=$HOME/downloads
  cd $DOWNLOADS/tanzu-cluster-essentials
  ./uninstall.sh --yes
  cd ../..
}

function deleteTapNamespace() {
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

  requireValue INSTALL_REGISTRY_USERNAME INSTALL_REGISTRY_PASSWORD INSTALL_REGISTRY_HOSTNAME  \
    TAP_VERSION \
    TAP_ECR_REGISTRY_HOSTNAME TAP_ECR_REGISTRY_REPOSITORY \
    TAP_ECR_REGISTRY_USERNAME TAP_ECR_REGISTRY_PASSWORD

  banner "Relocating TAP images, this will take time in minutes (30-45min) ..."

  docker login --username $TAP_ECR_REGISTRY_USERNAME --password $TAP_ECR_REGISTRY_PASSWORD $TAP_ECR_REGISTRY_HOSTNAME

  docker login --username $INSTALL_REGISTRY_USERNAME --password $INSTALL_REGISTRY_PASSWORD $INSTALL_REGISTRY_HOSTNAME

  # --concurrency 2 is required for AWS
  imgpkg copy --concurrency 2 -b ${INSTALL_REGISTRY_HOSTNAME}/tanzu-application-platform/tap-packages:${TAP_VERSION} \
   --to-repo ${TAP_ECR_REGISTRY_HOSTNAME}/${TAP_ECR_REGISTRY_REPOSITORY}
}

function downloadAndSetupTanzuCLIandDeployKapp() {
  requireValue TAP_VERSION AWS_REGION AWS_ACCOUNT AWS_ROLE

  banner "Downloading kapp, secretgen configuration bundle & tanzu cli"

  DOWNLOADS=$HOME/downloads
  mkdir -p $DOWNLOADS

  if [[ ! -f $DOWNLOADS/pivnet ]]
  then
    echo "Installing pivnet CLI"

    curl -Lo $DOWNLOADS/pivnet https://github.com/pivotal-cf/pivnet-cli/releases/download/v3.0.1/pivnet-linux-amd64-3.0.1
    sudo install -o user -g user -m 0755 $DOWNLOADS/pivnet /usr/local/bin/pivnet
  else
    echo "pivnet CLI already present"
  fi

  if [[ ! -d $DOWNLOADS/tanzu-cluster-essentials ]]
  then
    pivnet login --api-token="$PIVNET_TOKEN"

    ESSENTIALS_VERSION=$TAP_VERSION
    ESSENTIALS_FILE_NAME=tanzu-cluster-essentials-linux-amd64-$ESSENTIALS_VERSION.tgz
    ESSENTIALS_FILE_ID=1191987

    pivnet download-product-files \
      --download-dir $DOWNLOADS \
      --product-slug='tanzu-cluster-essentials' \
      --release-version=$ESSENTIALS_VERSION \
      --product-file-id=$ESSENTIALS_FILE_ID


    cd $DOWNLOADS
    mkdir -p tanzu-cluster-essentials
    tar -xvf $ESSENTIALS_FILE_NAME -C tanzu-cluster-essentials
    cd tanzu-cluster-essentials
    ./install.sh --yes
  else
    echo "tanzu-cluster-essentials already present"
  fi

  TANZU_DIR=$HOME/tanzu
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
    MOST_RECENT_CLI=$(find $TANZU_DIR/cli/core/ -name tanzu-core-linux_amd64 | xargs ls -t | head -n 1)
    echo "Installing Tanzu CLI"
    sudo install -m 0755 $MOST_RECENT_CLI /usr/local/bin/tanzu
    cd $HOME/tanzu
    tanzu plugin install --local cli all
  else
  echo "tanzu-framework-linux already present"
  fi

  # tanzu config set features.global.context-aware-cli-for-plugins false
  tanzu version
  cd $HOME

  tanzu version
  tanzu plugin list
}