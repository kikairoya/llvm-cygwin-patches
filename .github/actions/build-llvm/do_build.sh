#!/usr/bin/env -S bash -e -o pipefail

if [ -n "$RUNNER_DEBUG" ]; then
  set -x
fi

if [ "$(uname -o)" = "Msys" ] && [ -n "$CYGWIN_ROOT" ]; then
  set +h
  . "$ACTION_PATH/pathenv" ACTION_PATH LLVM_PATH PATCH_PATH STAGE1_BINDIR
  PATH="$CYGWIN_ROOT/bin:$PATH"
  exec MSYS_NO_PATHCONV=1 /usr/bin/env env bash -e -o pipefail -o igncr "$(cygpath -u "$(/bin/cygpath -w "$0")")" "$@"
  exit
fi

for b in build-*-$BUILD_NAME/bin "$STAGE1_BINDIR"; do
  if [ "$b" != "build-$BUILD_PROJECT-$BUILD_NAME/bin" ] && [ -n "$b" ]; then
    PATH="$b:$PATH"
  fi
done

if [[ $BUILD_TARGET = check* ]]; then
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
  
  export LIT_OPTS="-v --xunit-xml-output=$(realpath result-$BUILD_TARGET-$BUILD_PROJECT-$BUILD_NAME.xml) $EXTRA_LIT_OPTS"
  env | grep ^LIT_ > env-$BUILD_NAME.txt || true
  env | grep ^GTEST_ >> env-$BUILD_NAME.txt || true
fi

if ! [ -f build-$BUILD_PROJECT-$BUILD_NAME/CMakeCache.txt ]; then
  echo "::group::Configure"
  cmake -GNinja -Bbuild-$BUILD_PROJECT-$BUILD_NAME -S$LLVM_PATH/$BUILD_PROJECT -C$PATCH_PATH/config/$CONFIG_NAME/init.cmake | tee configlog-$BUILD_PROJECT-$BUILD_NAME.txt
  echo "::endgroup::"
fi

nice cmake --build build-$BUILD_PROJECT-$BUILD_NAME -- $BUILD_TARGET | tee buildlog-$BUILD_TARGET-$BUILD_PROJECT-$BUILD_NAME.txt | sed -uE -f$ACTION_PATH/build-grouping.sed
