FROM ubuntu:18.04

# for AWS kubectl download
ENV AWS_KUBECTL_VERSION="1.22.6/2022-03-09"

# perl is needed for shasum
RUN apt-get -y update && \
    apt-get install -y uuid-runtime vim sudo curl jq python-pip wget perl \
    ca-certificates && update-ca-certificates && rm -rf /var/lib/apt/lists/*

RUN bash -c "set -eo pipefail; wget -O- https://carvel.dev/install.sh | bash"

RUN adduser --disabled-password -q user
RUN adduser user sudo

# Ensure sudo group users are not asked for a password when using
# sudo command by ammending sudoers file
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER user
WORKDIR /home/user

# Install awscli
RUN pip install awscli --upgrade --user
RUN pip install yq

# Install kubectl
RUN curl -o kubectl  https://amazon-eks.s3-us-west-2.amazonaws.com/${AWS_KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
  chmod +x kubectl && \
  sudo mv kubectl /usr/local/bin/

# Install Docker in Docker
RUN curl -sSL https://get.docker.com/ | sh

# print all versions
# RUN ytt version && kapp version && kbld version && kwt version && \
#     imgpkg version && vendir version && aws --version && \
#     kubectl version --client

LABEL maintainer="Satya Dillikar <satya.dillikar@gmail.com>" \
      version="0.0.1"

ENV PATH /usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/user/.local/bin
COPY --chown=user:user ./src /home/user/src
COPY --chown=user:user ./downloads /home/user/downloads

ENV cmd="install"

ENTRYPOINT ["./src/tap-main.sh"]

# Keep the container running or alive
# CMD tail -f /dev/null
