ARG BASE=paketobuildpacks/run-jammy-tiny:latest
ARG WOKE=getwoke/woke:latest

FROM "${WOKE}" AS woke

FROM "${BASE}"

COPY woke.yml /etc/
COPY --from=woke /usr/bin/woke /usr/bin/woke

WORKDIR /src
USER nobody

ENTRYPOINT [ "woke", "--config", "/etc/woke.yml" ]
