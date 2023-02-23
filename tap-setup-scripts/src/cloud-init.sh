#!/usr/bin/env bash

set -ex

arch=$(dpkg --print-architecture)
user=ubuntu
tap_dir=/home/$user/tap-setup-scripts
uname=$(uname -m)
set -a

echo "Installing python dependencies for $user..."
su - $user -c "mkdir -p /home/$user/.local/bin; source /home/$user/.profile; python3 -m pip install --upgrade pip setuptools wheel yq"
echo "Updating certificate authority certificates..."
update-ca-certificates
echo "Installing Amazon CloudWatch agent..."
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
cat <<EOF >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "append_dimensions": {
      "ImageId": "\${aws:ImageId}",
      "InstanceId": "\${aws:InstanceId}",
      "InstanceType": "\${aws:InstanceType}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "${TAPLogGroup}",
            "log_stream_name": "{instance_id}_/var/log/cloud-init-output.log"
          }
        ]
      }
    }
  }
}
EOF


pushd /tmp
aws s3 cp --no-progress "s3://amazoncloudwatch-agent-${AWS_REGION}/ubuntu/${arch}/latest/amazon-cloudwatch-agent.deb" ./amazon-cloudwatch-agent.deb
dpkg -i ./amazon-cloudwatch-agent.deb
popd
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
systemctl enable amazon-cloudwatch-agent.service
systemctl start amazon-cloudwatch-agent.service
systemctl status amazon-cloudwatch-agent.service
echo "Installing kubectl..."
pushd /tmp
# aws s3 cp --no-progress "s3://amazon-eks/${AwsKubectlVersion}/bin/linux/$arch/kubectl" ./kubectl
# aws s3 cp --no-progress "s3://amazon-eks/${AwsKubectlVersion}/bin/linux/$arch/kubectl.sha256" ./kubectl.sha256
#The following commands work from 1.21 to latest as of Feb 22 2023
#Check this url when updating k8s versions - see https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
curl --retry 5 -o ./kubectl "https://s3.us-west-2.amazonaws.com/amazon-eks/${AwsKubectlVersion}/2023-01-30/bin/linux/$arch/kubectl"
curl --retry 5 -o ./kubectl.sha256 "https://s3.us-west-2.amazonaws.com/amazon-eks/${AwsKubectlVersion}/2023-01-30/bin/linux/$arch/kubectl.sha256"
openssl sha1 -sha256 ./kubectl
chmod 755 ./kubectl
mv ./kubectl /usr/local/bin/
kubectl completion bash > /etc/bash_completion.d/kubectl
popd
echo "Configuring Docker..."
getent group docker || groupadd docker
usermod -aG docker $user
mkdir -p /root/.docker
su - $user -c "mkdir -p /home/$user/.docker"
dockerCredHelperURI="https://github.com/docker/docker-credential-helpers/releases/download/v${DockerCredPassVersion}/docker-credential-pass-v${DockerCredPassVersion}.linux-${arch}"
install -m 0750 <( curl -fsSL "$dockerCredHelperURI" ) /usr/local/bin/docker-credential-pass


cat <<EOF > /root/.docker/config.json
{
  "credHelpers": {
    "${AWSAccountId}.dkr.ecr.${AWS_REGION}.amazonaws.com": "ecr-login",
    "public.ecr.aws": "ecr-login"
  }
}
EOF
cp /root/.docker/config.json /home/$user/.docker/
chown $user:$user /home/$user/.docker/config.json
echo "Configuring the SSH listening port..."
printf "Port ${LinuxBastionSshPort}\n" > /etc/ssh/sshd_config.d/port.conf
systemctl restart sshd.service
systemctl status sshd.service
echo "Downloading the VMware Tanzu Application Platform Quick Start scripts..."
su - $user -c "mkdir -p \"$tap_dir/downloads\" \"$tap_dir/generated\" \"$tap_dir/src/inputs\" \"$tap_dir/src/resources\""
pushd "$tap_dir/src"
aws s3 cp --no-progress "${QSS3BucketPath}/src/tap-main.sh" ./tap-main.sh
chmod +x ./tap-main.sh
aws s3 cp --no-progress "${QSS3BucketPath}/src/tap-relocate.sh" ./tap-relocate.sh
chmod +x ./tap-relocate.sh
aws s3 cp --no-progress "${QSS3BucketPath}/src/install-tools.sh" ./install-tools.sh
chmod +x ./install-tools.sh
aws s3 cp --no-progress "${QSS3BucketPath}/src/functions.sh" ./functions.sh
popd



pushd "$tap_dir/src/inputs"
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-build.yaml" ./tap-values-build.yaml
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-run.yaml" ./tap-values-run.yaml
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-iterate.yaml" ./tap-values-iterate.yaml
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-view.yaml" ./tap-values-view.yaml
aws s3 cp --no-progress "${QSS3BucketPath}/src/inputs/tap-values-single.yaml" ./tap-values-single.yaml
echo "Logging script input parameters"
echo ClusterArch ${ClusterArch}
echo BuildClusterBuildServiceArn ${BuildClusterBuildServiceArn}
echo BuildClusterWorkloadArn ${BuildClusterWorkloadArn}
echo IterateClusterBuildServiceArn ${IterateClusterBuildServiceArn}
echo IterateClusterWorkloadArn ${IterateClusterWorkloadArn}
echo BuildClusterName ${BuildClusterName}
echo RunClusterName ${RunClusterName}
echo ViewClusterName ${ViewClusterName}
echo IterateClusterName ${IterateClusterName}
cat <<EOF > ./user-input-values.yaml
#@data/values
---
tanzunet:
  server: ${TanzuNetRegistryServer}
  relocate_images: "${TanzuNetRelocateImages}"
  secrets:
    credentials_arn: ${TanzuNetSecretCredentials}
cluster_essentials_bundle:
  bundle: ${TanzuNetRegistryServer}/${ClusterEssentialsBundleRepo}
  file_hash: ${ClusterEssentialsBundleFileHash}
  version: ${ClusterEssentialsBundleVersion}
tap:
  name: tap
  namespace: tap-install
  repository: ${TanzuNetRegistryServer}/${TAPRepo}
  version: ${TAPVersion}
cluster:
  arch: ${ClusterArch}
  name: ${EKSClusterName}
buildservice:
  build_cluster_arn: ${BuildClusterBuildServiceArn}
  iterate_cluster_arn: ${IterateClusterBuildServiceArn}
dns:
  domain_name: ${TAPDomainName}
  zone_id: ${PrivateHostedZone}
repositories:
  tap_packages: ${TAPPackagesRepo_RepositoryUri}
  cluster_essentials: ${TAPClusterEssentialsBundleRepo_RepositoryUri}
  build_service: ${TAPBuildServiceRepo_RepositoryUri}
  workload:
    name: ${SampleAppName}
    namespace: ${SampleAppNamespace}
    repository: ${TAPWorkloadRepo_RepositoryUri}
    bundle_repository: ${TAPWorkloadBundleRepo_RepositoryUri}
    build_cluster_arn: ${BuildClusterWorkloadArn}
    iterate_cluster_arn: ${IterateClusterWorkloadArn}
EOF
popd
pushd "$tap_dir/src/resources"
aws s3 cp --no-progress --recursive --exclude '*' --include '*.yaml' "${QSS3BucketPath}/src/resources/" .
cat <<EOF > ./workload-aws.yaml
${SampleAppConfig}
EOF
popd
chown -R $user:$user "$tap_dir"
echo "Installing pivnet CLI..."
wget -O "$tap_dir/downloads/pivnet" "https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PivNetVersion}/pivnet-linux-$(dpkg --print-architecture)-${PivNetVersion}"
install -o $user -g $user -m 0755 "$tap_dir/downloads/pivnet" /usr/local/bin/pivnet
echo "Installing Tanzu CLI and Staging Tanzu-cluster-essentials..."
su - $user -c "$tap_dir/src/install-tools.sh"
echo TanzuNetRelocateImages ${TanzuNetRelocateImages}
if [[ "${TanzuNetRelocateImages}" == "Yes" ]]
then
  echo "Creating local copies of key TAP container repos per VMware best practices..."
  su - $user -c "$tap_dir/src/tap-relocate.sh"
fi

echo "Installing Tanzu Application Platform..."
echo ClusterArch ${ClusterArch}
if [[ "${ClusterArch}" == "multi" ]]
then
  echo "Setup TAP Multiple Clusters..."
  su - $user -c "$tap_dir/src/tap-main.sh -c install view"
  su - $user -c "$tap_dir/src/tap-main.sh -c install run"
  su - $user -c "$tap_dir/src/tap-main.sh -c install build"
  su - $user -c "$tap_dir/src/tap-main.sh -c install iterate"
  su - $user -c "$tap_dir/src/tap-main.sh -c prepview view"
  cfnSignal 0 "${TAPInstallHandle}"

  su - $user -c "$tap_dir/src/tap-main.sh -c installwk iterate"
  su - $user -c "$tap_dir/src/tap-main.sh -c installwk build"
  su - $user -c "$tap_dir/src/tap-main.sh -c installwk run"
  echo "wait till the workload to go through the supply-chain (8mins)"
  sleep 480
  cfnSignal 0 "${TAPWorkloadInstallHandle}"

  su - $user -c "$tap_dir/src/tap-main.sh -c runtests run"
  su - $user -c "$tap_dir/src/tap-main.sh -c runtests iterate"
  cfnSignal 0 "${TAPTestsHandle}"
else
  echo "Setup TAP Single Cluster..."
  su - $user -c "$tap_dir/src/tap-main.sh -c install single"
  cfnSignal 0 "${TAPInstallHandle}"

  su - $user -c "$tap_dir/src/tap-main.sh -c installwk single"
  echo "wait till the workload to go through the supply-chain (8mins)"
  sleep 480
  cfnSignal 0 "${TAPWorkloadInstallHandle}"

  su - $user -c "$tap_dir/src/tap-main.sh -c runtests single"
  cfnSignal 0 "${TAPTestsHandle}"
fi

echo "Completed successfully!"
