# [Concourse] CI

This directory holds the configuration, tasks and helpers for [concourse],
which we, VMware, use for continuous testing. This is **different** to what is
used by AWS when we merge our changes into the [upstream repo].

Cursious users can use this as long as they have a [concourse] with a
[credential manager] and other related infra (container registry, slack, ...)
available.

Otherwise, this can be ignored; nothing here is used at deployment- or runtime
by the [VMware Tanzu Application Platform on AWS Quick Start][qs].

[concourse]: https://concourse-ci.org/
[credential manager]: https://concourse-ci.org/creds.html
[qs]: https://aws.amazon.com/quickstart/architecture/vmware-tanzu-application-platform/
[upstream repo]: https://github.com/aws-quickstart/quickstart-vmware-tanzu-application-platform

## Contents

- [`images`] and [`qs-test`] pipelines
  - [`images`] is the pipeline which builds the image(s) we use in other pipelines
  - [`qs-test`] is the "main" pipeline which tests the [Quick Start][qs] on a regular bases and on PRs
- custom pipeline [`tasks`] our pipeline(s) are build from
- [`tests`] which we run either in the pipeline or locally before pushing a PR

[`images`]: ./images/
[`qs-test`]: ./qs-test/
[`tasks`]: ./tasks/
[`tests`]: ./tests/
