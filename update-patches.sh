#!/bin/bash

# usage: ./update-patches ${clone of llvm-project} branches...

set -e

patchdir="$(realpath "$(dirname "$0")")"
clone="$1"
git -C "$clone" rev-parse HEAD > /dev/null
isrepo="$(git -C "$patchdir/.git" rev-parse HEAD 2> /dev/null)"

shift

while (( "$#" != 0 )); do
  b="$1"
  shift
  if [ -n "$isrepo" ] && [ -d "$patchdir/patches/$b" ]; then
    git -C "$patchdir" rm -rf "patches/$b"
  else
    rm -rf "$patchdir/patches/$b"
  fi
  git -C "$clone" format-patch --full-index -o "$patchdir/patches/$b" origin/main..$b
  if [ -n "$isrepo" ]; then
    git -C "$patchdir" add "patches/$b"
  fi
done
