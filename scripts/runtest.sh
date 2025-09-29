set -e
[[ -v BUILD_NAME ]]
[[ -v CYGWINROOT ]]
if [[ $(uname) != CYGWIN* ]]; then
  export CYGWINROOT="$(cygpath -ua "$CYGWINROOT")"
  export PATH="$CYGWINROOT/bin:$PATH"
  exec "$CYGWINROOT/bin/bash.exe" "$0" "$@"
  exit
fi
[[ $(uname) = CYGWIN* ]]
on_int() {
  trap - SIGINT
  for f in /proc/*; do
    t=$(tty);
    for f in /proc/*; do
      case $(readlink $f/exe 2>/dev/null) in
        *bash|*python*|*readlink|"") ;;
        *)
          if [ "$(<$f/ctty)" == $t ]; then
            kill -INT ${f##/proc/}
          fi
          ;;
      esac;
    done;
  done
  sleep 60
  kill -INT $$
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
export LIT_OPTS="-sv --xunit-xml-output=$PWD/result-$BUILD_NAME.xml"
env | grep ^LIT > env-$BUILD_NAME.txt || true
bash build-$BUILD_NAME/CMakeFiles/check-all-*.sh | tee testlog-$BUILD_NAME.txt
