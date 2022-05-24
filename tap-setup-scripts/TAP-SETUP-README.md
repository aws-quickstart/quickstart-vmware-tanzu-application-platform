# Project: Tanzu Application Platform on AWS

## Pre-requisite
1. EC2 Instance

    Create an EC2 Instance of Ubuntu 22.04 (ami-09d56f8956ab235b3)

1. IAM Role

    This EC2 instance should have IAM roles attached to access the EKS cluster & ECR Repos.

1. Pre-Create ECR Repos

    Use CFT to create Repos. Use the default names given here
      - tap_ecr_repository: private/tanzu-application-platform/tap-packages
      - cluster_essentials_ecr_repository: private/tanzu-cluster-essentials/bundle
      - tbs_ecr_repository: private/tap-build-service
      - workload_repository: private/tanzu-java-web-app-workload-tap-workload
      - workload_bundle_repository: private/tanzu-java-web-app-workload-tap-workload-bundle

1. Create EKS Cluster

## TAP Install Process

1. Checkout public Git Repo

    GITHUB_REPO_NAME=quickstart-vmware-tanzu-application-platform
    git clone https://github.com/satya-dillikar/$GITHUB_REPO_NAME.git

1. Change Dir to run the scripts

    cd $GITHUB_REPO_NAME/tap-setup-scripts/

1. Update Input Params Files

    Fill up all the info and copy it into the below file.
    Filename: $GITHUB_REPO_NAME/tap-setup-scripts/inputs/user-input-values.yaml

    ```yaml
    # below variable are mandatory & user can modify
    aws:
      eks_cluster_name: your-cluster-name
      route_fifty_three_domain: your-domain.com
    ```
    <br>

1. Update TanzuNet Credentials
    Fill up TanzuNet Credentials in file: $GITHUB_REPO_NAME/tap-setup-scripts/inputs/tap-config-internal-values.yaml

    ```yaml
    tanzunet:
      hostname: registry.tanzu.vmware.com
      username:
      password:
      pivnet_token:
    ```
    <br>

   Note: Don't modify ECR Repo names.

1. One Time tasks


    Run the below commands only once.

    - Prepare Bootstrap EC2 & Install tools
      ```
      ./src/tap-main.sh -c bootstrap
      ```

    - Relocate TAP images to ECR
      ```
      ./src/tap-main.sh -c relocate
      ```
    <br>

1. TAP setup


    - tap install
      ```
      ./src/tap-main.sh -c install
      ```

    - tap uninstall
      ```
      ./src/tap-main.sh -c uninstall
      ```

    - tap install with skipping prerequisite (for 2nd or later runs)
      ```
      ./src/tap-main.sh -c install -s
      ```

    <br>

1. Output Params

     - CFT to Create Route53 DNS CNAME record for *.$AWS_DOMAIN_NAME with $elb_hostname"
     - Display TAP GUI URL $tap_gui_url
