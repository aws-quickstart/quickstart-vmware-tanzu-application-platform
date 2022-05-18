# Project: Tanzu Application Platform on AWS

Create an EC2 Instance of Ubuntu 22.04
```
cat /etc/lsb-release
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=22.04
DISTRIB_CODENAME=jammy
DISTRIB_DESCRIPTION="Ubuntu 22.04 LTS"
```

 This EC2 instance to have IAM roles attached to access EKS cluster.

 Install iam-authenticator

## TAP Install Process

    <br>
1. Input Params

    Fill up all the info as per below file.

    Filename: /tmp/inputs/user-input-values.yaml

    *aws.eks_cluster_name is mandatory and rest of aws.* are optional params*

    ```yaml
    # below variable are mandatory & user can modify
    aws:
      <!-- region: us-east-2 -->
      <!-- access_key:
      secret_key:
      role: svc.service-account
      account-id: -->
      eks_cluster_name: auto-eks-yewubxfvpk
      route_fifty_three_domain: example.com
      <!-- route_fifty_three_zone_id: -->

    tap_ecr_registry:
      <!-- hostname: 19876543213.dkr.ecr.us-east-1.amazonaws.com -->
      <!-- region: us-east-1 -->
      repository: private/tanzu-application-platform/tap-packages

    cluster_essentials_ecr_registry:
        hostname: 19876543213.dkr.ecr.us-east-1.amazonaws.com
        region: us-east-1
        repository: private/tanzu-cluster-essentials/bundle

    tbs_ecr_registry:
      hostname: 19876543213.dkr.ecr.us-west-1.amazonaws.com
      region: us-west-1
      #This repository is a prefix used in workload repos
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
        # repository1 = ${ootb_ecr_registry.repository}-${name}-{namespace}
        repository1: private/tap-supply-chain/tanzu-java-web-app-workload-tap-workload
        # repository2 = ${ootb_ecr_registry.repository}-${name}-{namespace}-bundle
        repository2: private/tap-supply-chain/tanzu-java-web-app-workload-tap-workload-bundle
    ```
    <br>

1. Pre-Create ECR Repos

    Use CFT to create Repos. Use the default names given above

    - tap_ecr_registry.repository
    - cluster_essentials_ecr_registry.repository
    - tbs_ecr_registry.repository
    - ootb_ecr_registry.repository
    - workload.ecr_registry.repository1
    - workload.ecr_registry.repository2


    <br>

1. One Time tasks


    Run the below commands only once.

    - Install tools
      ```
      ./src/install-tools.sh
      ```

    - relocate TAP images to ECR
      ```
      ./src/tap-main.sh -c relocate -f /tmp/inputs/user-input-values.yaml
      ```
    <br>

1. TAP setup


    - tap install
      ```
      ./src/tap-main.sh -c install -f /tmp/inputs/user-input-values.yaml
      ```

    - tap uninstall
      ```
      ./src/tap-main.sh -c uninstall -f /tmp/inputs/user-input-values.yaml
      ```

    - tap install with skipping prerequisite (for 2nd or later runs)
      ```
      ./src/tap-main.sh -c install -f /tmp/inputs/user-input-values.yaml  -s
      ```

    <br>

1. Output Params

     - CFT to Create Route53 DNS CNAME record for *.$AWS_DOMAIN_NAME with $elb_hostname"
     - Display TAP GUI URL $tap_gui_url
