#!/usr/bin/env -S bash -e -o pipefail

if [ -n "$RUNNER_DEBUG" ]; then
  set -x
fi

ostype="$(uname -o)"
if [ "${ostype^^}" = "MSYS" ]; then
  test -n "$CYGWIN_ROOT"
  test -n "$ACTION_PATH"
  set +x
  set +h
  MSYS_NO_PATHCONV=1 unsudo_path="$ACTION_PATH/unsudo"
  clang --target=x86_64-w64-mingw32 "$unsudo_path.cc" -o "$unsudo_path.exe" -O -Wl,-s \
        -nodefaultlibs -nostartfiles -ladvapi32 -lkernel32 -fuse-ld=lld -e main
  . "$ACTION_PATH/pathenv" ACTION_PATH LLVM_PATH PATCH_PATH STAGE1_BINDIR
  PATH="$(/bin/cygpath -ua "$CYGWIN_ROOT")/bin:$PATH"
  unset TMP TEMP
  MSYS_NO_PATHCONV=1 exec "$unsudo_path.exe" "$CYGWIN_ROOT\\bin\\bash.exe" -e -o pipefail -o igncr "$(cygpath -ua "$(/bin/cygpath -wa "$0")")" "$@"
  exit 1
fi

test -n $BUILD_PROJECT
test -n $BUILD_NAME

if [[ $ostype != *Linux ]]; then
  sudo() {
    env "$@"
  }
fi

sudo mkdir -p /opt/w
sudo mount -obind "$(realpath .)" /opt/w
cd /opt/w
trap 'cd; sudo umount /opt/w || true' EXIT

for b in build-*-$BUILD_NAME/bin; do
  if [ "$b" != "build-$BUILD_PROJECT-$BUILD_NAME/bin" ] && [ -d "$b" ]; then
    PATH="$(realpath "$b"):$PATH"
  fi
done

if [ -n "$STAGE1_BINDIR" ] && [ -d "$STAGE1_BINDIR" ]; then
  STAGE1_BINDIR="$(realpath "$STAGE1_BINDIR")"
  PATH="$STAGE1_BINDIR:$PATH"
fi

if [[ $BUILD_TARGET = check* ]]; then
  if [[ $ostype = *Linux* ]]; then
    python -m pip install "psutil==7.1.3"
  fi

  test -n $PATCH_PATH
  test -n $CONFIG_NAME

  pushd "$PATCH_PATH/config/$CONFIG_NAME" > /dev/null
  if [ -f xfail.txt ]; then
    export LIT_XFAIL="$(sed -e '2,$s#^#;#' xfail.txt | tr -d '\n')"
  fi
  if [ -f filter-out.txt ]; then
    export LIT_FILTER_OUT="($(sed -e '2,$s#^#)|(#' filter-out.txt | tr -d '\n'))"
  fi
  if [ -f filter.txt ]; then
    export LIT_FILTER="($(sed -e '2,$s#^#)|(#' filter.txt | tr -d '\n'))"
  fi
  if [ -f gtest_filter.txt ]; then
    export GTEST_FILTER="$(sed -e '1s#^#-#;2,$s#^#:#' gtest_filter.txt | tr -d '\n')"
  fi
  popd > /dev/null

  export LIT_OPTS="$EXTRA_LIT_OPTS"
  env | grep ^LIT_ > env-$BUILD_NAME.txt || true
  env | grep ^GTEST_ >> env-$BUILD_NAME.txt || true
fi

if ! [ -f build-$BUILD_PROJECT-$BUILD_NAME/CMakeCache.txt ]; then
  echo "::group::Configure"
  cmake -GNinja -Bbuild-$BUILD_PROJECT-$BUILD_NAME -S$LLVM_PATH/$BUILD_PROJECT -C$PATCH_PATH/config/$CONFIG_NAME/init.cmake | \
    tee configlog-$BUILD_PROJECT-$BUILD_NAME.txt
  echo "::endgroup::"
fi

if [ -n "$RUNNER_DEBUG" ] && command -v free > /dev/null; then
  efree='e free -hwL'
fi

for t in ${BUILD_TARGET//,/ }; do
  cmake --build build-$BUILD_PROJECT-$BUILD_NAME -- $t | \
    tee buildlog-$t-$BUILD_PROJECT-$BUILD_NAME.txt | \
    sed -uE -e "$efree" -f$ACTION_PATH/build-grouping.sed
done

if [ -n "$INSTALL_PREFIX" ]; then
  echo "::group::Install"
  cmake --install build-$BUILD_PROJECT-$BUILD_NAME --prefix install/$INSTALL_PREFIX
  echo "::endgroup::"
fi
