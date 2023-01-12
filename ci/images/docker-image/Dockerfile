ARG BASE=devtools-docker.artifactory.eng.vmware.com/vmware/runway/resourcetypes/docker-in-nimbus-task:0.13.1
FROM "${BASE}"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -qy update \
        && apt-get -qy install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 \
            curl \
            git \
            jq \
            less \
            pigz \
            python3-pip \
        && pip3 --no-cache-dir install --upgrade \
            pip \
            setuptools \
        && python3 -m pip --no-cache-dir install \
            awscli \
            taskcat \
            yq \
        && rm -rf /var/lib/apt/lists/*
