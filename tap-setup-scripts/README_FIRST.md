
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