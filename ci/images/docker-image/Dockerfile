ARG BASE=devtools-docker.artifactory.eng.vmware.com/vmware/runway/resourcetypes/docker-in-nimbus-task:0.13.4

FROM ghcr.io/vmware-tanzu/carvel-docker-image AS carvel

FROM "${BASE}"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -qy update \
        && apt-get -qy install -o APT::Install-Suggests=0 -o APT::Install-Recommends=0 \
            curl \
            git \
            jq \
            less \
            locales \
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

ARG DEFAULT_LOCALE='en_US.UTF-8'

# Needs to look something like `en_US.UTF-8 UTF-8`
RUN echo "${DEFAULT_LOCALE} ${DEFAULT_LOCALE##*.}" > /etc/locale.gen \
        && locale-gen

ENV LC_ALL="${DEFAULT_LOCALE}"
ENV LANG="${DEFAULT_LOCALE}"
ENV LANGUAGE="${DEFAULT_LOCALE}"

COPY --from=carvel /usr/local/bin/ytt /usr/local/bin/ytt
