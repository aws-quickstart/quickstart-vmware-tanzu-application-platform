# Project: Tanzu Application Platform on AWS

## Run Commands

Step-1:

  Fill up all the info as per below file.

  Filename: /tmp/inputs/user-input-values.yaml


  ```yaml
  # below variable are mandatory & user can modify
  aws:
    region: us-east-2
    access_key:
    secret_key:
    role: svc.service-account
    account-id:
    eks_cluster_name: auto-eks-yewubxfvpk
    route_fifty_three_domain: example.com
    route_fifty_three_zone_id:

  tap_ecr_registry:
    hostname: 19876543213.dkr.ecr.us-east-1.amazonaws.com
    region: us-east-1
    repository: private/tanzu-application-platform/tap-packages

  cluster_essentials_ecr_registry:
      hostname: 19876543213.dkr.ecr.us-east-1.amazonaws.com
      region: us-east-1
      repository: private/tanzu-cluster-essentials/bundle

  tbs_ecr_registry:
    hostname: 19876543213.dkr.ecr.us-west-1.amazonaws.com
    region: us-west-1
    repository: private/tap-build-service

  ootb_ecr_registry:
    hostname: 19876543213.dkr.ecr.us-west-1.amazonaws.com
    region: us-west-1
    repository: private/tap-supply-chain

  # below variable are optional and user can modify
  workload:
    name: tanzu-java-web-app-workload
    namespace: tap-workload
    ecr_registry:
      hostname: 19876543213.dkr.ecr.us-west-1.amazonaws.com
      region: us-west-1
      # prefix=private/
      # repository1 = ${prefix}-${name}-{namespace}
      repository1: private/tanzu-java-web-app-workload-tap-workload
      # repository2 = ${prefix}-${name}-{namespace}-bundle
      repository2: private/tanzu-java-web-app-workload-tap-workload-bundle
  ```


Step-2:


- tap install
  ```
  ./src/tap-main.sh -c install -f /tmp/inputs/user-input-values.yaml
  ```

- tap uninstall
  ```
  ./src/tap-main.sh -c uninstall -f /tmp/inputs/user-input-values.yaml
  ```

- tap relocate images
  ```
  ./src/tap-main.sh -c relocate -f /tmp/inputs/user-input-values.yaml
  ```

- tap install with skipping prerequisite (for 2nd or later runs)
  ```
  ./src/tap-main.sh -c install -f /tmp/inputs/user-input-values.yaml  -s
  ```
