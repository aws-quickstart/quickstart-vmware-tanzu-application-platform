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

# tanzunet::getFile downloads a product file from tanzunet, given the product
# slug, the product release version & the product filename glob; it will placce
# the artefact to the provided file path.
# Special care is taken in handling the tanzunet token:
#   The token is expected to be provided on StdIn and it is only used in a
#   subshell where `xtrace` & `verbose` is explicitly disabled. This is done,
#   so that we don't leak the token in some debug output, logs, ... even if the
#   caller would run with `xtrace` or `verbose` enabled.
tanzunet::getFile() (
  local -
  set -e
  set -u
  set -o pipefail

  local slug="$1"
  local version="$2"
  local fileGlob="$3"
  local dest="$4"

  downloadDir="$( mktemp --directory --suffix=-tanzunet-download )"
  trap 'rm -rf -- "$downloadDir"' EXIT

  cd "$downloadDir"

  (
    set +xv # disable `verbose` & `xtrace` so we don't leak the token
    om download-product \
      --pivnet-api-token="$(</dev/stdin)" \
      --pivnet-product-slug="${slug}" \
      --product-version="${version}" \
      --file-glob="${fileGlob}" \
      --output-directory='.'
  )

  local filePath

  filePath="$( jq -er '.product_path' ./download-file.json )"

  echo >&2 "moving '$(basename "$filePath")' to '$dest'"
  mv "$filePath" "$dest"
)

function installTanzuCLI {
  requireValue ESSENTIALS_VERSION TAP_VERSION

  banner "Downloading kapp, secretgen configuration bundle & tanzu cli"

  mkdir -p "$DOWNLOADS"

  local file arch rc

  arch="$(dpkg --print-architecture)"

  if [[ ! -f $DOWNLOADS/tanzu-cluster-essentials/install.sh ]]
  then
    file="${DOWNLOADS}/cluster-essentials.tgz"

    tanzunet::getFile \
      'tanzu-cluster-essentials' "${ESSENTIALS_VERSION}" "tanzu-cluster-essentials-linux-${arch}-*.tgz" \
      "$file" \
      <<< "$TANZUNET_REFRESH_TOKEN" \
    || {
      rc=$?
      echo >&2 'Could not download cluster essentials'
      return $rc
    }

    mkdir -p "${DOWNLOADS}/tanzu-cluster-essentials"
    tar xvf "$file" -C "${DOWNLOADS}/tanzu-cluster-essentials"
    sudo cp "${DOWNLOADS}/tanzu-cluster-essentials/imgpkg" /usr/local/bin/
    sudo cp "${DOWNLOADS}/tanzu-cluster-essentials/kapp"   /usr/local/bin/
    sudo cp "${DOWNLOADS}/tanzu-cluster-essentials/kbld"   /usr/local/bin/
    sudo cp "${DOWNLOADS}/tanzu-cluster-essentials/ytt"    /usr/local/bin/
  else
    echo "tanzu-cluster-essentials already present"
  fi

  TANZU_DIR="${DOWNLOADS}/tanzu"
  if [[ ! -f /usr/local/bin/tanzu ]]
  then
    mkdir -p "${TANZU_DIR}"

    file="${DOWNLOADS}/tap-bundle.tar"

    tanzunet::getFile \
      'tanzu-application-platform' "${TAP_VERSION}" "tanzu-framework-linux-${arch}-*" \
      "$file" \
      <<< "$TANZUNET_REFRESH_TOKEN" \
    || {
      rc=$?
      echo >&2 'Could not download the tanzu CLI / tanzu framework'
      return $rc
    }

    tar xvf "$file" -C "$TANZU_DIR"
    export TANZU_CLI_NO_INIT=true
    MOST_RECENT_CLI="$(
      find "${TANZU_DIR}/cli/core/" -name "tanzu-core-linux_${arch}" \
        | xargs ls -t \
        | head -n 1
    )"
    echo "Installing Tanzu CLI"
    sudo install -m 0755 "$MOST_RECENT_CLI" /usr/local/bin/tanzu
    pushd "$TANZU_DIR"
    tanzu plugin install --local cli all
    popd
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
  imgpkg version
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
  tanzu version
  tanzu plugin list
  echo ''
}

function readUserInputs {
  banner "Reading $INPUTS/user-input-values.yaml"

  AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
  DOMAIN_NAME=$(yq -r .dns.domain_name $INPUTS/user-input-values.yaml)
  ZONE_ID=$(yq -r .dns.zone_id $INPUTS/user-input-values.yaml)

  TANZUNET_REGISTRY_SECRETS_MANAGER_ARN=$(yq -r .tanzunet.secrets.credentials_arn $INPUTS/user-input-values.yaml)
  TANZUNET_REGISTRY_USERNAME=$(aws secretsmanager get-secret-value --secret-id "$TANZUNET_REGISTRY_SECRETS_MANAGER_ARN" --query "SecretString" --output text | jq -r .username)
  TANZUNET_REGISTRY_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$TANZUNET_REGISTRY_SECRETS_MANAGER_ARN" --query "SecretString" --output text | jq -r .password)
  TANZUNET_REFRESH_TOKEN=$(aws secretsmanager get-secret-value --secret-id "$TANZUNET_REGISTRY_SECRETS_MANAGER_ARN" --query "SecretString" --output text | jq -r .token)

  TANZUNET_REGISTRY_SERVER=$(yq -r .tanzunet.server $INPUTS/user-input-values.yaml)
  TANZUNET_RELOCATE_IMAGES=$(yq -r .tanzunet.relocate_images $INPUTS/user-input-values.yaml)
  ESSENTIALS_BUNDLE=$(yq -r .cluster_essentials_bundle.bundle $INPUTS/user-input-values.yaml)
  ESSENTIALS_FILE_HASH=$(yq -r .cluster_essentials_bundle.file_hash $INPUTS/user-input-values.yaml)
  ESSENTIALS_VERSION=$(yq -r .cluster_essentials_bundle.version $INPUTS/user-input-values.yaml)

  ESSENTIALS_URI="$ESSENTIALS_BUNDLE@$ESSENTIALS_FILE_HASH"

  TAP_PACKAGE_NAME=$(yq -r .tap.name $INPUTS/user-input-values.yaml)
  TAP_NAMESPACE=$(yq -r .tap.namespace $INPUTS/user-input-values.yaml)
  TAP_REPOSITORY=$(yq -r .tap.repository $INPUTS/user-input-values.yaml)
  TAP_VERSION=$(yq -r .tap.version $INPUTS/user-input-values.yaml)

  TAP_URI="$TAP_REPOSITORY:$TAP_VERSION"

  TAP_ECR_REGISTRY_REPOSITORY=$(yq -r .repositories.tap_packages $INPUTS/user-input-values.yaml)
  ESSENTIALS_ECR_REGISTRY_REPOSITORY=$(yq -r .repositories.cluster_essentials $INPUTS/user-input-values.yaml)
  TBS_ECR_REGISTRY_REPOSITORY=$(yq -r .repositories.build_service $INPUTS/user-input-values.yaml)

  SAMPLE_APP_NAME=$(yq -r .repositories.workload.name $INPUTS/user-input-values.yaml)
  DEVELOPER_NAMESPACE=$(yq -r .repositories.workload.namespace $INPUTS/user-input-values.yaml)
  SAMPLE_APP_ECR_REGISTRY_REPOSITORY=$(yq -r .repositories.workload.repository $INPUTS/user-input-values.yaml)
  SAMPLE_APP_BUNDLE_ECR_REGISTRY_REPOSITORY=$(yq -r .repositories.workload.bundle_repository $INPUTS/user-input-values.yaml)
}


function parseUserInputsSC {
  requireValue AWS_ACCOUNT GENERATED INPUTS \
    SAMPLE_APP_ECR_REGISTRY_REPOSITORY

  rm -rf $GENERATED/tap-values-single.yaml
  mkdir -p $GENERATED

  cat $INPUTS/user-input-values.yaml > $GENERATED/user-input-values.yaml

  kubectl apply -f $RESOURCES/metadata-store-read-only.yaml
  METADATA_STORE_ACCESS_TOKEN=$(kubectl get secret \
    $(kubectl get sa -n metadata-store metadata-store-read-client -o json \
    | jq -r '.secrets[0].name') -n metadata-store -o json \
    | jq -r '.data.token' \
    | base64 -d)

  banner "Generating tap-values-single.yaml"

  ytt -f $INPUTS/tap-values-single.yaml -f $GENERATED/user-input-values.yaml \
    --data-value repositories.workload.server=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f1) \
    --data-value repositories.workload.ootb_repo_prefix=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f2-3) \
    --data-value metadata_store.access_token="Bearer $METADATA_STORE_ACCESS_TOKEN" \
    --ignore-unknown-comments > $GENERATED/tap-values-single.yaml
}

function parseUserInputsMC {
  requireValue AWS_ACCOUNT GENERATED INPUTS \
    SAMPLE_APP_ECR_REGISTRY_REPOSITORY

  rm -rf $GENERATED/tap-values-build.yaml
  rm -rf $GENERATED/tap-values-run.yaml
  rm -rf $GENERATED/tap-values-view.yaml
  rm -rf $GENERATED/tap-values-iterate.yaml

  mkdir -p $GENERATED

  cat $INPUTS/user-input-values.yaml > $GENERATED/user-input-values.yaml

  banner "Generating tap-values.yaml for all clusters"

  ytt -f $INPUTS/tap-values-build.yaml -f $GENERATED/user-input-values.yaml \
    --data-value repositories.workload.server=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f1) \
    --data-value repositories.workload.ootb_repo_prefix=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f2-3) \
    --ignore-unknown-comments > $GENERATED/tap-values-build.yaml

  ytt -f $INPUTS/tap-values-run.yaml -f $GENERATED/user-input-values.yaml \
    --data-value repositories.workload.server=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f1) \
    --data-value repositories.workload.ootb_repo_prefix=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f2-3) \
    --ignore-unknown-comments > $GENERATED/tap-values-run.yaml

  METADATA_STORE_ACCESS_TOKEN=""
  RUN_CLUSTER_URL=""
  BUILD_CLUSTER_URL=""
  ITERATE_CLUSTER_URL=""
  RUN_CLUSTER_TOKEN=""
  BUILD_CLUSTER_TOKEN=""
  ITERATE_CLUSTER_TOKEN=""
  ytt -f $INPUTS/tap-values-view.yaml -f $GENERATED/user-input-values.yaml \
    --data-value cluster.run.url=$RUN_CLUSTER_URL \
    --data-value cluster.run.token=$RUN_CLUSTER_TOKEN \
    --data-value cluster.build.url=$BUILD_CLUSTER_URL \
    --data-value cluster.build.token=$BUILD_CLUSTER_TOKEN \
    --data-value cluster.iterate.url=$ITERATE_CLUSTER_URL \
    --data-value cluster.iterate.token=$ITERATE_CLUSTER_TOKEN \
    --data-value metadata_store.access_token="Bearer $METADATA_STORE_ACCESS_TOKEN" \
    --data-value repositories.workload.server=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f1) \
    --data-value repositories.workload.ootb_repo_prefix=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f2-3) \
    --ignore-unknown-comments > $GENERATED/tap-values-view.yaml

  ytt -f $INPUTS/tap-values-iterate.yaml -f $GENERATED/user-input-values.yaml \
    --data-value repositories.workload.server=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f1) \
    --data-value repositories.workload.ootb_repo_prefix=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f2-3) \
    --ignore-unknown-comments > $GENERATED/tap-values-iterate.yaml
}

function parseUserInputsViewCluster {
  requireValue GENERATED INPUTS \
    SAMPLE_APP_ECR_REGISTRY_REPOSITORY

  rm -rf $GENERATED/tap-values-view.yaml
  mkdir -p $GENERATED
  cat $INPUTS/user-input-values.yaml > $GENERATED/user-input-values.yaml

  banner "Generating tap-values.yaml for View cluster"

  ITERATE_CLUSTER_URL=`cat $GENERATED/iterate-cluster-url.txt`
  ITERATE_CLUSTER_TOKEN=`cat $GENERATED/iterate-cluster-token.txt`
  BUILD_CLUSTER_URL=`cat $GENERATED/build-cluster-url.txt`
  BUILD_CLUSTER_TOKEN=`cat $GENERATED/build-cluster-token.txt`
  RUN_CLUSTER_URL=`cat $GENERATED/run-cluster-url.txt`
  RUN_CLUSTER_TOKEN=`cat $GENERATED/run-cluster-token.txt`
  METADATA_STORE_ACCESS_TOKEN=`cat $GENERATED/view-cluster-metadata-token.txt`

  # echo ITERATE_CLUSTER_URL: $ITERATE_CLUSTER_URL
  # echo ITERATE_CLUSTER_TOKEN: $ITERATE_CLUSTER_TOKEN
  # echo BUILD_CLUSTER_URL: $BUILD_CLUSTER_URL
  # echo BUILD_CLUSTER_TOKEN: $BUILD_CLUSTER_TOKEN
  # echo RUN_CLUSTER_URL: $RUN_CLUSTER_URL
  # echo RUN_CLUSTER_TOKEN: $RUN_CLUSTER_TOKEN
  # echo METADATA_STORE_ACCESS_TOKEN $METADATA_STORE_ACCESS_TOKEN

  ytt -f $INPUTS/tap-values-view.yaml -f $GENERATED/user-input-values.yaml \
    --data-value cluster.run.url=$RUN_CLUSTER_URL \
    --data-value cluster.run.token=$RUN_CLUSTER_TOKEN \
    --data-value cluster.build.url=$BUILD_CLUSTER_URL \
    --data-value cluster.build.token=$BUILD_CLUSTER_TOKEN \
    --data-value cluster.iterate.url=$ITERATE_CLUSTER_URL \
    --data-value cluster.iterate.token=$ITERATE_CLUSTER_TOKEN \
    --data-value metadata_store.access_token="Bearer $METADATA_STORE_ACCESS_TOKEN" \
    --data-value repositories.workload.server=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f1) \
    --data-value repositories.workload.ootb_repo_prefix=$(echo $SAMPLE_APP_ECR_REGISTRY_REPOSITORY | cut -d '/' -f2-3) \
    --ignore-unknown-comments > $GENERATED/tap-values-view.yaml
}

function parseUserInputs {
    MY_CLUSTER_NAME_SUFFIX=$1
    if [[ $MY_CLUSTER_NAME_SUFFIX == "single" ]]
    then
      parseUserInputsSC
    else
      parseUserInputsMC
    fi
}
function installTanzuClusterEssentials {
  requireValue TAP_VERSION ESSENTIALS_ECR_REGISTRY_REPOSITORY \
    ESSENTIALS_FILE_HASH TANZUNET_RELOCATE_IMAGES \
    ESSENTIALS_BUNDLE TANZUNET_REGISTRY_SERVER \
    TANZUNET_REGISTRY_USERNAME TANZUNET_REGISTRY_PASSWORD \
    AWS_REGION

  banner "Deploy kapp, secretgen configuration bundle & install tanzu CLI"

  pushd $DOWNLOADS/tanzu-cluster-essentials
  # tanzu-cluster-essentials install.sh script needs INSTALL_BUNDLE & below INSTALL_XXX params

  ESSENTIALS_REGISTRY_REPOSITORY=$ESSENTIALS_BUNDLE
  ESSENTIALS_REGISTRY_HOSTNAME=$TANZUNET_REGISTRY_SERVER
  ESSENTIALS_REGISTRY_USERNAME=$TANZUNET_REGISTRY_USERNAME
  ESSENTIALS_REGISTRY_PASSWORD=$TANZUNET_REGISTRY_PASSWORD

  if [[ $TANZUNET_RELOCATE_IMAGES == "Yes" ]]
  then
    echo "Changed ESSENTIALS_REGISTRY_REPOSITORY to ECR Repository"
    ESSENTIALS_REGISTRY_REPOSITORY=$ESSENTIALS_ECR_REGISTRY_REPOSITORY
    ESSENTIALS_REGISTRY_HOSTNAME=${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
    ESSENTIALS_REGISTRY_USERNAME=AWS
    ESSENTIALS_REGISTRY_PASSWORD=$(aws ecr get-login-password)
  fi

  INSTALL_BUNDLE=$ESSENTIALS_REGISTRY_REPOSITORY@$ESSENTIALS_FILE_HASH \
    INSTALL_REGISTRY_HOSTNAME=$ESSENTIALS_REGISTRY_HOSTNAME \
    INSTALL_REGISTRY_USERNAME=$ESSENTIALS_REGISTRY_USERNAME \
    INSTALL_REGISTRY_PASSWORD=$ESSENTIALS_REGISTRY_PASSWORD ./install.sh --yes
  popd
}

function verifyK8ClusterAccess {
  MY_CLUSTER_NAME=$1
  banner "Verify EKS Cluster ${MY_CLUSTER_NAME} access"
  aws eks update-kubeconfig --name ${MY_CLUSTER_NAME}
  kubectl config current-context
  kubectl get nodes
}

function createTapNamespace {
  requireValue TAP_NAMESPACE DEVELOPER_NAMESPACE

  banner "Creating $TAP_NAMESPACE namespace"

  (kubectl get ns $TAP_NAMESPACE 2> /dev/null) ||
    kubectl create ns $TAP_NAMESPACE

  banner "Creating $DEVELOPER_NAMESPACE namespace"

  ensureDevNamespace "$DEVELOPER_NAMESPACE"
}

ensureDevNamespace() {
  local name="$1"

  kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $name
  labels:
    apps.tanzu.vmware.com/tap-ns: ""
EOF
}

function loadPackageRepository {
  requireValue TAP_REPOSITORY TAP_ECR_REGISTRY_REPOSITORY TAP_VERSION \
  TAP_NAMESPACE TANZUNET_RELOCATE_IMAGES

  TAP_REGISTRY_REPOSITORY=$TAP_REPOSITORY
  if [[ $TANZUNET_RELOCATE_IMAGES == "Yes" ]]
  then
    echo "Changed TAP_REGISTRY_REPOSITORY to ECR Repository"
    TAP_REGISTRY_REPOSITORY=$TAP_ECR_REGISTRY_REPOSITORY
  fi

  kubectl -n "$TAP_NAMESPACE" apply -f - <<EOF
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: tanzu-tap-repository
spec:
  fetch:
    imgpkgBundle:
      image: ${TAP_REGISTRY_REPOSITORY}:${TAP_VERSION}
EOF

  sleep 3s

  kubectl -n "$TAP_NAMESPACE" wait PackageRepository/tanzu-tap-repository --for=condition=ReconcileSucceeded=true

  echo 'TAP repository updated & reconciled'
}

function createTapRegistrySecret {
  requireValue TANZUNET_REGISTRY_USERNAME TANZUNET_REGISTRY_PASSWORD TANZUNET_REGISTRY_SERVER TAP_NAMESPACE

  banner "Creating tap-registry registry secret"

  tanzu secret registry delete tap-registry --namespace $TAP_NAMESPACE -y
  waitForRemoval kubectl get secret tap-registry --namespace $TAP_NAMESPACE -o json

  tanzu secret registry add tap-registry \
    --username "$TANZUNET_REGISTRY_USERNAME" --password "$TANZUNET_REGISTRY_PASSWORD" \
    --server $TANZUNET_REGISTRY_SERVER \
    --export-to-all-namespaces --namespace $TAP_NAMESPACE --yes
}

function ensurePackageOverlays() {
  local -
  set -e
  set -u
  set -o pipefail

  local tapVersion="${1?needs to be the TAP version}"
  local tapNamespace="${2?needs to be the namespace where TAPs pkgis get deployed into}"
  local resourcesDir="${3?needs to be the directory with additional resource files}"
  local tapValuesFile="${4?needs to be the path to the TAP data values file}"

  local olSecrets="${resourcesDir}/package_overlay_secrets.yaml"
  local olApply="${resourcesDir}/package_overlay_apply.yaml"

  local f
  for f in "$olSecrets" "$olApply" ; do
    [ -e "$f" ] || {
      echo >&2 "$f does not exist, skipping applying package overlays"
      return 0
    }
  done

  banner 'Adding package overlays'

  # create the overlay secrets in the tap-install namespace
  ytt \
    -f "$olSecrets" \
    -v tapVersion="$tapVersion" \
    -v tapNamespace="$tapNamespace" \
    | kubectl apply -f -

  # patch the tap data values with the package overlays
  local newTapValues
  newTapValues="$( ytt -f "$tapValuesFile" -f "$olApply" )"
  echo "$newTapValues" > "$tapValuesFile"
}

function tapInstallFull {
  requireValue TAP_PACKAGE_NAME TAP_VERSION TAP_NAMESPACE

  TAP_VALUES_FILE=$1
  banner "Installing TAP values from $GENERATED/$TAP_VALUES_FILE for TAP_VERSION $TAP_VERSION ..."

  first_time="$(tanzu package installed get $TAP_PACKAGE_NAME -n $TAP_NAMESPACE -o json 2>/dev/null || true)"

  ensurePackageOverlays "$TAP_VERSION" "$TAP_NAMESPACE" "$RESOURCES" "${GENERATED}/${TAP_VALUES_FILE}"

  local installArgs=(
    --package tap.tanzu.vmware.com
    --version "${TAP_VERSION}"
    --values-file "${GENERATED}/${TAP_VALUES_FILE}"
    --namespace "${TAP_NAMESPACE}"
  )

  if [[ -z $first_time ]]
  then
    tanzu package install "${TAP_PACKAGE_NAME}" "${installArgs[@]}" \
      || true
  else
    tanzu package installed update "${TAP_PACKAGE_NAME}" "${installArgs[@]}" \
      || true
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
    tanzu package installed list --namespace $TAP_NAMESPACE -o json |
      jq -r '.[] | (.name + " " + .status)' > $GENERATED/tap-packages-installed-list.txt || true

    while read package status
    do
      if [ "$status" != "Reconcile succeeded" ]
      then
        message "package($package) failed to reconcile ($status), waiting for reconcile"
        # reconcilePackageInstall $TAP_NAMESPACE $package
        # kctrl package installed kick -i $package -n $TAP_NAMESPACE -y
        EXIT="false"
      fi
    done < $GENERATED/tap-packages-installed-list.txt
    ((RETRIES=RETRIES-1))
    sleep $DELAY
  done

  banner "Checking for ERRORs in all packages"
  # Add some delay before checking status again
  sleep 60
  tanzu package installed list --namespace $TAP_NAMESPACE -o json |
    jq -r '.[] | (.name + " " + .status)' |
    while read package status
    do
      if [ "$status" != "Reconcile succeeded" ]
      then
        fatal "ERROR: At least one package ($package) failed to reconcile ($status)"
      fi
    done
  banner "TAP Installation is Complete."
}

function tapUninstallFull {
  requireValue TAP_PACKAGE_NAME TAP_NAMESPACE

  banner "Uninstalling TAP from cluster ..."
  tanzu package installed delete $TAP_PACKAGE_NAME -n $TAP_NAMESPACE --yes || true
}

function deleteTapRegistrySecret {
  requireValue TAP_NAMESPACE

  banner "Removing tap-registry registry secret"

  tanzu secret registry delete tap-registry --namespace $TAP_NAMESPACE -y || true
}

function deletePackageRepository {
  requireValue TAP_NAMESPACE

  banner "Removing current TAP package repository"

  tanzu package repository delete tanzu-tap-repository -n $TAP_NAMESPACE --yes || true
}

function deleteTanzuClusterEssentials {

  banner "Removing kapp-controller & secretgen-controller"
  pushd $DOWNLOADS/tanzu-cluster-essentials
  ./uninstall.sh --yes
  popd
}

function deleteTapNamespace {
  requireValue TAP_NAMESPACE

  banner "Removing TAP namespace"
  kubectl delete namespace $TAP_NAMESPACE || true
  waitForRemoval kubectl get namespace $TAP_NAMESPACE -o json
}


function relocateTAPPackages {
  # Relocate the images with the Carvel tool imgpkg
  # ECR_REPOSITORY to be pre-created

  requireValue TANZUNET_REGISTRY_USERNAME TANZUNET_REGISTRY_PASSWORD TANZUNET_REGISTRY_SERVER \
    ESSENTIALS_URI ESSENTIALS_ECR_REGISTRY_REPOSITORY \
    TAP_URI TAP_ECR_REGISTRY_REPOSITORY

  banner "Relocating images, this will take time in minutes (30-45min)..."

  # Replace “docker login” with IMGPKG_REGISTRY_HOSTNAME_0;
  # see details https://carvel.dev/imgpkg/docs/v0.29.0/auth/#via-environment-variables.

  export IMGPKG_REGISTRY_HOSTNAME_0="$TANZUNET_REGISTRY_SERVER"
  export IMGPKG_REGISTRY_USERNAME_0="$TANZUNET_REGISTRY_USERNAME"
  export IMGPKG_REGISTRY_PASSWORD_0="$TANZUNET_REGISTRY_PASSWORD"

  # --concurrency 2 or 1 is required for ECR
  echo "Relocating Tanzu Cluster Essentials Bundle"
  imgpkg copy --concurrency 2 -b ${ESSENTIALS_URI} --to-repo ${ESSENTIALS_ECR_REGISTRY_REPOSITORY}

  echo "Relocating TAP packages"
  imgpkg copy --concurrency 1 -b ${TAP_URI} --to-repo ${TAP_ECR_REGISTRY_REPOSITORY}
  echo "Ignore the non-distributable skipped layer warning- non-issue"

}

function createRoute53Record {
  # envoy loadbalancer ip
  requireValue INPUTS GENERATED DOMAIN_NAME ZONE_ID

  MY_CLUSTER_NAME_SUFFIX=$1
  if [[ $MY_CLUSTER_NAME_SUFFIX == "single" ]]
  then
    export ROUTE53_RECORD_NAME="*.$DOMAIN_NAME"
  else
    export ROUTE53_RECORD_NAME="*.$MY_CLUSTER_NAME_SUFFIX.$DOMAIN_NAME"
  fi

  elb_hostname=$(kubectl get svc envoy -n tanzu-system-ingress -o jsonpath='{ .status.loadBalancer.ingress[0].hostname }')
  echo "Create Route53 DNS CNAME record for $ROUTE53_RECORD_NAME with $elb_hostname"

  pushd $GENERATED
  cat <<EOF > ./cluster-$MY_CLUSTER_NAME_SUFFIX-tap-gui-route53-wildcard-resource-record-set-config.json
{
  "Comment": "UPSERT TAP GUI records",
  "Changes": [
    {
      "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "$ROUTE53_RECORD_NAME",
          "Type": "CNAME",
          "TTL": 300,
        "ResourceRecords": [{ "Value": "$elb_hostname"}]
      }
    }
  ]
}
EOF
  aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "file://./cluster-$MY_CLUSTER_NAME_SUFFIX-tap-gui-route53-wildcard-resource-record-set-config.json"
  popd

}

function deleteRoute53Record {
  # envoy loadbalancer ip
  requireValue GENERATED DOMAIN_NAME ZONE_ID

  MY_CLUSTER_NAME_SUFFIX=$1
  if [[ $MY_CLUSTER_NAME_SUFFIX == "single" ]]
  then
    export ROUTE53_RECORD_NAME="*.$DOMAIN_NAME"
  else
    export ROUTE53_RECORD_NAME="*.$MY_CLUSTER_NAME_SUFFIX.$DOMAIN_NAME"
  fi
  elb_hostname=$(kubectl get svc envoy -n tanzu-system-ingress -o jsonpath='{ .status.loadBalancer.ingress[0].hostname }') || true
  echo "Delete Route53 DNS CNAME record for $ROUTE53_RECORD_NAME with $elb_hostname"

  pushd $GENERATED
  cat <<EOF > ./cluster-$MY_CLUSTER_NAME_SUFFIX-tap-gui-route53-wildcard-resource-record-delete-config.json
{
  "Comment": "DELETE TAP GUI records",
  "Changes": [
    {
      "Action": "DELETE",
        "ResourceRecordSet": {
          "Name": "$ROUTE53_RECORD_NAME",
          "Type": "CNAME",
          "TTL": 300,
        "ResourceRecords": [{ "Value": "$elb_hostname"}]
      }
    }
  ]
}
EOF
  aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch "file://./cluster-$MY_CLUSTER_NAME_SUFFIX-tap-gui-route53-wildcard-resource-record-delete-config.json" || true
  popd
}


function runTestCasesTAPGUI {
  TAP_GUI_URL=$1
  echo TAP_GUI_URL $TAP_GUI_URL

  #test-1:
  rx_str=`curl -LIk $TAP_GUI_URL  -o /dev/null -w '%{http_code}\n' -s` || true
  expected_str="200"

  echo "Test1: Access TAP GUI"
  if [[ "$rx_str" == "$expected_str" ]]
  then
    echo "Test1 Pass"
  else
    echo "Test1 Fail"
  fi
}

function runTestCasesTAPWK {
  WORKLOAD_URL=$1
  echo WORKLOAD_URL $WORKLOAD_URL

  #test-2:
  rx_str=`curl -LIk $WORKLOAD_URL -o /dev/null -w '%{http_code}\n' -s` || true
  expected_str="200"

  echo "Test2: Access Sample Workload GUI"
  if [[ "$rx_str" == "$expected_str" ]]
  then
    echo "Test2 Pass"
  else
    echo "Test2 Fail"
  fi

  #test-3: workload output
  rx_str=`curl -Lsk $WORKLOAD_URL` || true
  expected_str="Greetings from Spring Boot + Tanzu!"

  echo "Test3: Verify Sample Workload Output"
  if [[ "$rx_str" == "$expected_str" ]]
  then
    echo "Test3 Pass"
  else
    echo "Test3 Fail"
  fi
}


function tapPrepIterateClusterToken {
  MY_CLUSTER_NAME="$CLUSTER_NAME_PREFIX-iterate"
  aws eks update-kubeconfig --name ${MY_CLUSTER_NAME}

  ITERATE_CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  ITERATE_CLUSTER_TOKEN=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json \
   | jq -r '.data["token"]' \
   | base64 --decode)
  echo $ITERATE_CLUSTER_URL > $GENERATED/iterate-cluster-url.txt
  echo $ITERATE_CLUSTER_TOKEN > $GENERATED/iterate-cluster-token.txt

  #store_ca.yaml and view-cluster-metadata-token.txt are generated in function tapPrepViewClusterToken
  kubectl apply -f $GENERATED/store_ca.yaml
  METADATA_STORE_ACCESS_TOKEN=`cat $GENERATED/view-cluster-metadata-token.txt`
  kubectl delete secret store-auth-token -n metadata-store-secrets || true
  kubectl create secret generic store-auth-token --from-literal=auth_token=$METADATA_STORE_ACCESS_TOKEN -n metadata-store-secrets

}

function tapPrepBuildClusterToken {
  MY_CLUSTER_NAME="$CLUSTER_NAME_PREFIX-build"
  aws eks update-kubeconfig --name ${MY_CLUSTER_NAME}

  BUILD_CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  BUILD_CLUSTER_TOKEN=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json \
   | jq -r '.data["token"]' \
   | base64 --decode)

  echo $BUILD_CLUSTER_URL > $GENERATED/build-cluster-url.txt
  echo $BUILD_CLUSTER_TOKEN > $GENERATED/build-cluster-token.txt

  #store_ca.yaml and view-cluster-metadata-token.txt are generated in function tapPrepViewClusterToken
  kubectl apply -f $GENERATED/store_ca.yaml
  METADATA_STORE_ACCESS_TOKEN=`cat $GENERATED/view-cluster-metadata-token.txt`
  kubectl delete secret store-auth-token -n metadata-store-secrets || true
  kubectl create secret generic store-auth-token --from-literal=auth_token=$METADATA_STORE_ACCESS_TOKEN -n metadata-store-secrets

}

function tapPrepRunClusterToken {
  MY_CLUSTER_NAME="$CLUSTER_NAME_PREFIX-run"
  aws eks update-kubeconfig --name ${MY_CLUSTER_NAME}

  RUN_CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  RUN_CLUSTER_TOKEN=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json \
   | jq -r '.data["token"]' \
   | base64 --decode)

  echo $RUN_CLUSTER_URL > $GENERATED/run-cluster-url.txt
  echo $RUN_CLUSTER_TOKEN > $GENERATED/run-cluster-token.txt

  #store_ca.yaml and view-cluster-metadata-token.txt are generated in function tapPrepViewClusterToken
  kubectl apply -f $GENERATED/store_ca.yaml
  METADATA_STORE_ACCESS_TOKEN=`cat $GENERATED/view-cluster-metadata-token.txt`
  kubectl delete secret store-auth-token -n metadata-store-secrets || true
  kubectl create secret generic store-auth-token --from-literal=auth_token=$METADATA_STORE_ACCESS_TOKEN -n metadata-store-secrets

}

function tapPrepViewClusterToken {
  MY_CLUSTER_NAME="$CLUSTER_NAME_PREFIX-view"
  aws eks update-kubeconfig --name ${MY_CLUSTER_NAME}

  METADATA_STORE_ACCESS_TOKEN=$(kubectl get secrets -n metadata-store -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='metadata-store-read-write-client')].data.token}" | cut -f1 -d' '| base64 -d)

  echo $METADATA_STORE_ACCESS_TOKEN > $GENERATED/view-cluster-metadata-token.txt

  kubectl get secret ingress-cert -n metadata-store -o json | jq -r '.data."ca.crt"' | base64 -d > $GENERATED/insight-ca.crt

  METADATA_STORE_DOMAIN="https://metadata-store.view.$DOMAIN_NAME"
  rm -rf $HOME/.config/tanzu/insight/config.yaml
  tanzu insight config set-target $METADATA_STORE_DOMAIN --ca-cert $GENERATED/insight-ca.crt
}


function tapPrepWorkloadInstall {
  requireValue DEVELOPER_NAMESPACE SAMPLE_APP_NAME

  banner "Creating $DEVELOPER_NAMESPACE namespace"
  ensureDevNamespace "$DEVELOPER_NAMESPACE"
}

function tapWorkloadGenerateDeliverable {
  requireValue  DEVELOPER_NAMESPACE SAMPLE_APP_NAME GENERATED

  echo "Generating ${GENERATED}/${SAMPLE_APP_NAME}-delivery.yaml "

  kubectl get configmap "${SAMPLE_APP_NAME}-deliverable"  -n $DEVELOPER_NAMESPACE  -o go-template='{{.data.deliverable}}' > "${GENERATED}/${SAMPLE_APP_NAME}-delivery.yaml"

  cat ${GENERATED}/${SAMPLE_APP_NAME}-delivery.yaml

}

function tapWorkloadApplyDeliverable {
  requireValue  DEVELOPER_NAMESPACE SAMPLE_APP_NAME GENERATED

  banner "Creating $DEVELOPER_NAMESPACE namespace"

  ensureDevNamespace "$DEVELOPER_NAMESPACE"

  echo "Applying ${GENERATED}/${SAMPLE_APP_NAME}-delivery.yaml "

  kubectl apply -f ${GENERATED}/${SAMPLE_APP_NAME}-delivery.yaml -n $DEVELOPER_NAMESPACE
  # let the service be up
  sleep 60
  kubectl get deliverable -n $DEVELOPER_NAMESPACE

  echo "get app URL and copy into browser to test the app"
  kubectl get ksvc -n $DEVELOPER_NAMESPACE

  # workaround to see target-cluster in tap-gui
  kubectl patch deliverable ${SAMPLE_APP_NAME} -n ${DEVELOPER_NAMESPACE} --type merge --patch "{\"metadata\":{\"labels\":{\"carto.run/workload-name\":\"${SAMPLE_APP_NAME}\",\"carto.run/workload-namespace\":\"${DEVELOPER_NAMESPACE}\"}}}"

}
