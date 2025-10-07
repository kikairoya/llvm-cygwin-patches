set -ex
[[ -v BUILD_NAME ]]
if [[ $(uname) != CYGWIN* ]]; then
  [[ -v CYGWINROOT ]]
  r="$(cygpath -ua "$CYGWINROOT")"
  unset CYGWINROOT
  exec env PATH="$r/bin:$PATH" env bash "$0" "$@"
fi
[[ $(uname) = CYGWIN* ]]
cd $(cygpath -ua $GITHUB_WORKSPACE)

if [ -f llvm-cygwin-$BUILD_NAME.tar ]; then
  tar xf llvm-cygwin-$BUILD_NAME.tar
  rm llvm-cygwin-$BUILD_NAME.tar
fi

set -o pipefail
if [ -z "$CONFIG" ]; then
  export LIT_OPTS="-q --no-execute --ignore-fail --xunit-xml-output=$PWD/dryrun-$BUILD_NAME.xml --timeout ${PER_TEST_TIMEOUT:-180} --max-time $(( ${TOTAL_TIMEOUT_MINUTES:-180} * 60 )) $*"
  bash build-$BUILD_NAME/CMakeFiles/check-all-*.sh
  exit
fi

if [ -f patches/xfail-$CONFIG.txt ]; then
  export LIT_XFAIL="$(sed '2,$s/^/;/' < patches/xfail-$CONFIG.txt | tr -d '\n')"
fi
if [ -f patches/filter-out-$CONFIG.txt ]; then
  export LIT_FILTER_OUT="($(sed '2,$s/^/)|(/' < patches/filter-out-$CONFIG.txt | tr -d '\n'))"
fi
export LIT_OPTS="-sv --xunit-xml-output=$PWD/result-$CONFIG-$BUILD_NAME.xml --timeout ${PER_TEST_TIMEOUT:-180} --max-time $(( ${TOTAL_TIMEOUT_MINUTES:-180} * 60 )) $*"
env | grep ^LIT > env-$BUILD_NAME.txt || true
result=
if ! bash build-$BUILD_NAME/CMakeFiles/check-all-*.sh | tee testlog-$CONFIG-$BUILD_NAME.txt; then
  result=1
fi
if [ -f patches/xfail-$CONFIG.txt ]; then
  echo additional XFAIL:
  cat patches/xfail-$CONFIG.txt
fi
if [ -f patches/filter-out-$CONFIG.txt ]; then
  echo additional FILTER_OUT:
  cat patches/filter-out-$CONFIG.txt
fi
exit $result
