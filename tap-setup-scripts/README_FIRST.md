
# Note: Run all commands from the top-level working directory

## For Multi cluster

update file user-input-values-mc.yaml with below params

- the cluster name is a prefix of all 4 clusters
- both build_cluster_arn & iterate_cluster_arn are required

```
cluster:
  arch: multi
  name: tap-prefix
buildservice:
  build_cluster_arn: arn:aws:iam::188471332253:role/TAPBuildServiceIamRoleBuildCluster-eksctl
  iterate_cluster_arn: arn:aws:iam::188471332253:role/TAPBuildServiceIamRoleIterateTest-eksctl
  workload:
    name: tanzu-java-web-app-workload
    ...
    build_cluster_arn: arn:aws:iam::188471332253:role/TAPWorkloadIamRoleBuildCluster-eksctl
    iterate_cluster_arn: arn:aws:iam::188471332253:role/TAPBuildServiceIamRoleIterateTestWK-eksctl
```

Install
```
echo "Starting Installation..."
$SCRIPT_DIR/tap-main.sh -c install view
$SCRIPT_DIR/tap-main.sh -c install run
$SCRIPT_DIR/tap-main.sh -c install build
$SCRIPT_DIR/tap-main.sh -c install iterate

$SCRIPT_DIR/tap-main.sh -c prepview view

$SCRIPT_DIR/tap-main.sh -c installwk iterate
# workload build and run
$SCRIPT_DIR/tap-main.sh -c installwk build
$SCRIPT_DIR/tap-main.sh -c installwk run
# wait till the workload to go through the supply-chain (8mins)
sleep 480
$SCRIPT_DIR/tap-main.sh -c runtests run
$SCRIPT_DIR/tap-main.sh -c runtests iterate

```

Uninstall
```
echo "Starting Uninstallation..."
$SCRIPT_DIR/tap-main.sh -c uninstallwk run
$SCRIPT_DIR/tap-main.sh -c uninstallwk build
$SCRIPT_DIR/tap-main.sh -c uninstallwk iterate

$SCRIPT_DIR/tap-main.sh -c uninstall view
$SCRIPT_DIR/tap-main.sh -c uninstall run
$SCRIPT_DIR/tap-main.sh -c uninstall build
$SCRIPT_DIR/tap-main.sh -c uninstall iterate
```


## For Single cluster

update file user-input-values-mc.yaml with below params

- the cluster name is a full-name
- only build_cluster_arn is required

```
cluster:
  arch: single
  name: tap-full-name
buildservice:
  build_cluster_arn: arn:aws:iam::188471332253:role/TAPBuildServiceIamRoleBuildCluster-eksctl
  workload:
    name: tanzu-java-web-app-workload
    ...
    build_cluster_arn: arn:aws:iam::188471332253:role/TAPWorkloadIamRoleBuildCluster-eksctl
```


Install
```
echo "Starting Installation..."
$SCRIPT_DIR/tap-main.sh -c install single
$SCRIPT_DIR/tap-main.sh -c installwk single
# wait till the workload to go through the supply-chain (8mins)
sleep 480
$SCRIPT_DIR/tap-main.sh -c runtests single
```

Uninstall
```
echo "Starting Uninstallation..."
$SCRIPT_DIR/tap-main.sh -c uninstallwk single
$SCRIPT_DIR/tap-main.sh -c uninstall single
```


## TODO:
1. update user-input-values.yaml
    ```
    repositories:
      build_cluster_build_service: 012345678901.dkr.ecr.us-east-1.amazonaws.com/621187b4-c917-46c0-9341-f5067b3afd97/tap-build-service
      iterate_cluster_build_service: 012345678901.dkr.ecr.us-east-1.amazonaws.com/621187b4-c917-46c0-9341-f5067b3afd97/tap-build-service
      workload:
        name: tanzu-java-web-app-workload
        namespace: tap-workload
        build_cluster_repository: 012345678901.dkr.ecr.us-east-1.amazonaws.com/621187b4-c917-46c0-9341-f5067b3afd97/tap-supply-chain/tanzu-java-web-app-workload-tap-workload
        build_cluster_bundle_repository: 012345678901.dkr.ecr.us-east-1.amazonaws.com/621187b4-c917-46c0-9341-f5067b3afd97/tap-supply-chain/tanzu-java-web-app-workload-tap-workload-bundle
        iterate_cluster_repository: 012345678901.dkr.ecr.us-east-1.amazonaws.com/621187b4-c917-46c0-9341-f5067b3afd97/tap-supply-chain/tanzu-java-web-app-workload-tap-workload
        iterate_cluster_bundle_repository: 012345678901.dkr.ecr.us-east-1.amazonaws.com/621187b4-c917-46c0-9341-f5067b3afd97/tap-supply-chain/tanzu-java-web-app-workload-tap-workload-bundle
        build_cluster_arn: arn:aws:iam::188471332253:role/TAPWorkloadIamRoleBuildCluster-eksctl
        iterate_cluster_arn: arn:aws:iam::188471332253:role/TAPBuildServiceIamRoleIterateTestWK-eksctl
    ```

2. aws-tap-entrypoint-existing-vpc.mulit-cluster.yaml is a temporary file with all new resources. This needs to be merged with aws-tap-entrypoint-existing-vpc.template.yaml


3. Cloudformation Template testing

    aws cloudformation validate-template --template-body file://aws-tap-entrypoint-existing-vpc.mulit-cluster.yaml --region us-east-1

    aws cloudformation deploy --template-file aws-tap-entrypoint-existing-vpc.mulit-cluster.yaml --stack-name cli-4eks-try1   --region us-east-1 --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND --disable-rollback

    aws cloudformation delete-stack --stack-name cli-4eks-try1 --region us-east-1
