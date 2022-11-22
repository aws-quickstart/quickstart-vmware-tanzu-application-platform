#!/usr/bin/env bash

set -xe

stash_child_directories() {
  local parent_directory=$1

  pushd $parent_directory

  for child_directory in *
  do
    if [ -d "${child_directory}" ]
    then
      pushd "${child_directory}"

      git stash --include-untracked

      popd
    fi
  done

  popd
}

stash_child_directories './submodules/quickstart-amazon-eks/submodules'
stash_child_directories './submodules'

git submodule update --init --recursive
