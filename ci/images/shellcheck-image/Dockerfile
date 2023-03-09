ARG BASE=paketobuildpacks/run-jammy-base:latest
ARG SHELLCHECK=koalaman/shellcheck:stable

FROM "${SHELLCHECK}" AS shellcheck

FROM "${BASE}"

COPY --from=shellcheck /bin/shellcheck /bin/shellcheck

WORKDIR /src
USER nobody

ENTRYPOINT [ "bash", "-c", "find . -path ./submodules -prune -o -name '*.sh' -print0 | xargs -0 -r shellcheck" ]
