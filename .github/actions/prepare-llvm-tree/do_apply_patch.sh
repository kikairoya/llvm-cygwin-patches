#!/usr/bin/env -S bash -e -o pipefail

pushd $INPUTS_PATCH_PATH > /dev/null
  PATCH_PATH=$PWD
  PATCH_REV=$(git log -n1 --format=format:%h HEAD)
popd > /dev/null

pushd $INPUTS_LLVM_PATH > /dev/null
  LLVM_PATH=$PWD
  UPSTREAM_REV=$(git log -n1 --format=format:%h HEAD)
  BUILD_NAME=$UPSTREAM_REV+mod-$PATCH_REV
  echo build-name=$BUILD_NAME >> "$GITHUB_OUTPUT"

  if [ -z "$(git config user.name)" ]; then
    git config user.name github-actions
    git config user.email github@github.com
    git config status.showuntrackedfiles no
  fi
  notifyerror() {
    local c=0
    "$@" 2>&1 | tee cmd.log || c=$?
    if [ "$c" -ne 0 ]; then
      echo -n "::error ::"
      sed 's/$/%0A/' < cmd.log | tr -d '\n'
    fi
    rm cmd.log
    return $c
  }
  for p in ${INPUTS_PATCH_SERIES//,/ }; do
    test -d "$PATCH_PATH/patches/$p"
    git checkout --detach $UPSTREAM_REV
    notifyerror git am -3 --empty=drop $PATCH_PATH/patches/$p/*
    git branch -f $p
  done
  if [ -n "${INPUTS_PATCH_SERIES}" ]; then
    git checkout --detach $UPSTREAM_REV
    notifyerror git merge -mmerge --no-ff ${INPUTS_PATCH_SERIES//,/ }
  fi
popd > /dev/null

tar -cf llvm-source-$BUILD_NAME.tar --exclude=.git $INPUTS_LLVM_PATH

mkdir -p llvm-patches
git -C $LLVM_PATH format-patch --full-index -o $PWD/llvm-patches $UPSTREAM_REV..HEAD

if [ "$RUNNER_OS" == Windows ] && [ -n "$CYGWIN_ROOT" ]; then
  set +h
  pushd "$CYGWIN_ROOT" > /dev/null
    cd bin
    export PATH=$PWD:$PATH
  popd > /dev/null
fi

tar -cf llvm-patches-$BUILD_NAME.tar llvm-patches
