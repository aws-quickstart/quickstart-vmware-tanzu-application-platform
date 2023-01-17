#!/usr/bin/env bash

set -e
set -u
set -o pipefail

main() {
  # Some submodules are modul'ed in as `git@github.com:...`, which means we'd
  # need an
  #  - ssh key
  #  - host key verification
  # set up.
  #
  # The github-pr-resource can't really handle that, thus we pull the PR in
  # without syncing the submodules and, with this task, we force git to use
  # https instead of ssh+git.
  #
  # For now, at least, we only use publicly available submodules from github,
  # this this should work for now.
  git config --global --replace-all 'url.https://github.com/.insteadof' 'git@github.com:'

  cd repo
  git submodule update --init --recursive --force
}

main "$@"
