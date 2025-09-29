set -e
[[ -v BUILD_NAME ]]
[[ -v TIMEOUT ]]
if [[ $(uname) != CYGWIN* ]]; then
  [[ -v CYGWINROOT ]]
  r="$(cygpath -ua "$CYGWINROOT")"
  unset CYGWINROOT
  exec env PATH="$r/bin:$PATH" env timeout -s INT $TIMEOUT bash "$0" "$@"
fi
[[ $(uname) = CYGWIN* ]]
cd $(cygpath -ua $GITHUB_WORKSPACE)
send_signal() {
  s=$1
  (
    set +e
    cd /proc
    for f in *; do
      case $(readlink $f/exe 2>/dev/null) in
        /usr/bin/*|"")
          ;;
        *)
          kill $s $f
          ;;
      esac
    done
  )
}
on_int() {
  trap - SIGINT
  send_signal -INT
  sleep 10
  send_signal -INT
  sleep 3
  kill -INT $$
  return 1
}
trap on_int SIGINT

tar xf llvm-cygwin-$BUILD_NAME.tar
rm llvm-cygwin-$BUILD_NAME.tar

export LIT_OPTS="-q --no-execute --ignore-fail --xunit-xml-output=$PWD/dryrun-$BUILD_NAME.xml"
bash build-$BUILD_NAME/CMakeFiles/check-all-*.sh

if [ -f patches/xfail-$CONFIG.txt ]; then
  export LIT_XFAIL="$(sed '2,$s/^/;/' < patches/xfail-$CONFIG.txt | tr -d '\n')"
fi
if [ -f patches/filter-out-$CONFIG.txt ]; then
  export LIT_FILTER_OUT="($(sed '2,$s/^/)|(/' < patches/filter-out-$CONFIG.txt | tr -d '\n'))"
fi
if [ -f patches/filter-$CONFIG.txt ]; then
  export LIT_FILTER="($(sed '2,$s/^/)|(/' < patches/filter-$CONFIG.txt | tr -d '\n'))"
fi
export LIT_OPTS="-sv -j2 --xunit-xml-output=$PWD/result-$BUILD_NAME.xml"
env | grep ^LIT > env-$BUILD_NAME.txt || true

set -o pipefail
result=
if ! bash build-$BUILD_NAME/CMakeFiles/check-all-*.sh | tee testlog-$BUILD_NAME.txt; then
  result=1
fi

if [ -f patches/xfail-$CONFIG.txt ]; then
  echo XFAIL:
  cat patches/xfail-$CONFIG.txt
fi
if [ -f patches/filter-out-$CONFIG.txt ]; then
  echo FILTER_OUT:
  cat patches/filter-out-$CONFIG.txt
fi
if [ -f patches/filter-$CONFIG.txt ]; then
  echo FILTER:
  cat patches/filter-$CONFIG.txt
fi

exit $result
