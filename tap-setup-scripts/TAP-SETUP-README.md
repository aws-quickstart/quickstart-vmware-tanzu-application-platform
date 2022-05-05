# Project: Tanzu Application Platform on EKS in AWS


## Documentation
  I have created these documents in this repo to illustrate the TAP installation process. For a complete guide with details instructions, search on VMware Docs.

1. [TAP-Installation-Tanzu-Specifics-Guide.md](docs/TAP-Installation-Tanzu-Specifics-Guide.md) – This is to capture the details of the TAP Basic Supply Chain
1. [TAP-Installation-Tanzu-SCC-specifics-Guide.md](docs/TAP-Installation-Tanzu-SCC-specifics-Guide.md) – This is to capture the details of the TAP Testing_Scanning Supply Chain


## Build Commands
  ```
  docker build -t username/tap-boot-image:0.0.1 .
  ```


## Run Commands

Step-1:
  fill up all the info as per below file.

  Filename: user-input-values.yaml
  ```yaml
  # below variable are mandatory
  tanzunet:
    hostname: registry.tanzu.vmware.com
    username:
    password:
    pivnet_token:

  tap_ecr_registry:
    hostname: 1234567890.dkr.ecr.us-east-1.amazonaws.com
    region: us-east-1
    repository: private/tanzu-application-platform/tap-packages

  container_tbs_ecr_registry:
    hostname: 1234567890.dkr.ecr.us-west-1.amazonaws.com
    region: us-west-1
    repository: private/tap-build-service

  container_workload_ecr_registry:
    hostname: 1234567890.dkr.ecr.us-west-1.amazonaws.com
    region: us-west-1
    repository: private/tap-supply-chain

  aws:
    region: us-east-2
    access_key:
    secret_key:
    role: svc.service-account
    account-id:
    eks_cluster_name: auto-eks-yewubxfvpk
    route_fifty_three_domain: example.com
    route_fifty_three_zone_id:

  ```

  copy input file to /tmp/inputs

  ```
  cp user-input-values.yaml /tmp/inputs
  ```

Step-2:
  mount /tmp/inputs into the and work in $PWD dir


- tap install
  ```
  docker run --name=tap-boot-image -v "/tmp/inputs:/tmp/inputs" -e cmd="install" -e file="user-input-values.yaml" username/tap-boot-image:0.0.1
  ```

- tap uninstall
  ```
  docker run --name=tap-boot-image -v "/tmp/inputs:/tmp/inputs" -e cmd="uninstall" -e file="user-input-values.yaml" username/tap-boot-image:0.0.1
  ```

- tap relocate images
  ```
  docker run --name=tap-boot-image -v "/tmp/inputs:/tmp/inputs" -e cmd="relocate" -e file="user-input-values.yaml" username/tap-boot-image:0.0.1
  ```

- tap install with skipping prerequisite (for 2nd or later runs)
  ```
  docker run --name=tap-boot-image -v "/tmp/inputs:/tmp/inputs" -e cmd="install" -e file="user-input-values.yaml" -e skipinit="true" username/tap-test
  ```

## Troubleshoot
  Troubleshoot or Run AWS or Tanzu CLI in container

  To get inside the container & play with scripts, modify the Dockerfile to add the tail CMD.
  
  File:Dockerfile
  ```
  ...
  # ENTRYPOINT ["./src/tap-main.sh"]

  # Keep the container running or alive
  CMD tail -f /dev/null
  ```
 
  ```
  docker exec -it tap-boot-image /bin/bash
  cd /home/user/code/src
  ./tap-main.sh install  /tmp/inputs/user-input-values.yaml
  ./tap-main.sh install  /tmp/inputs/user-input-values.yaml skipinit

  ./tap-main.sh uninstall  /tmp/inputs/user-input-values.yaml
  ./tap-main.sh relocate  /tmp/inputs/user-input-values.yaml
  ```

 - remove the stale running image
  ```
  docker stop tap-boot-image
  docker rm -f tap-boot-image
  ```
