#!/bin/bash

## apply-cygwin-patches upstream-ref config-name

set -ex
while read; do
  case $REPLY in
    *set*LLVM_VERSION_MAJOR*)
      [[ $REPLY =~ [0-9][1-9]* ]] && MAJOR_VER=$BASH_REMATCH;
      break ;;
  esac;
done < llvm-project/cmake/Modules/LLVMVersion.cmake
git -C llvm-project config user.name github-actions
git -C llvm-project config user.email github@github.com
git -C llvm-project config status.showuntrackedfiles no
UPSTREAM_REV=$(git -C llvm-project log -n1 --format=format:%h)
PATCH_REV=$(git -C patches log -n1 --format=format:%h)
LLVM_VERSION=$MAJOR_VER-$UPSTREAM_REV+mod-$PATCH_REV
if [ -n "$GITHUB_ENV" ]; then
  echo "LLVM_VERSION=$LLVM_VERSION" >> "$GITHUB_ENV"
  echo "UPSTREAM_REV=$UPSTREAM_REV" >> "$GITHUB_ENV"
fi
echo output version tag is set to $LLVM_VERSION
if [ -d "$PWD/patches/patches/$1" ]; then
  git -C llvm-project am --empty=drop $PWD/patches/patches/$1/*
  c="$PWD/patches/llvm-cygwin-$2-$LLVM_VERSION"
  mkdir -p "$c/diffs"
  git -C llvm-project format-patch -o "$c/diffs" $UPSTREAM_REV..HEAD
fi
