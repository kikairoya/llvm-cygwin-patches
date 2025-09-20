#!/bin/bash

set -e
shopt -s extglob

help() {
  cat <<EOF
usage:
  $0 configfile {options...} {build-or-install-targets...}
options:
 combinations of
  -c|--config   perform configure (usually automatically done)
  -r|--fresh    force reconfigure
  -b|--build    perform build (default if nothing specified)
  -i|--install  perform install
  -v|--verbose  echo cmake being to run
EOF
}

abort() { echo "$*" >&2; exit 1; }
unknown() { help; abort "unrecognized option '$1'"; }
required() { [ $# -gt 1 ] || abort "option '$1' requires an argument"; }
run() { [ "$verbose" ] && echo "$@" || true; "$@"; }

config=
fresh=
build=
install=
verbose=
declare -a args

while [ $# -gt 0 ]; do
  case $1 in
    -c | --config ) config=1 ;;
    -r | --fresh ) fresh=1 ;;
    -b | --build ) build=1 ;;
    -i | --install ) install=1 ;;
    -v | --verbose ) verbose=1 ;;
    -?*) args+=("$@"); break ;;
    *) args+=("$1");;
  esac
  shift
done
if [ -z "$config$fresh$build$install" ]; then
  build=1
fi

cfgfile="${args[0]}"
[ -n "$cfgfile" ] || abort "no configuration specified"
unset args[0]
args=("${args[@]}")
[ -f "$cfgfile" ] || abort "configuration is not accessible"


declare -a ENV
declare -a OPT
GEN="Ninja"
DIR=""
SRC=""
target=cmake
while read; do
  REPLY="${REPLY@P}"
  case $REPLY in
    env) target=env ;;
    cmake) target=cmake ;;
    build) target=build ;;
    src|source) target=src ;;
    \#*) : ;;
    -G*) GEN="${REPLY##-G*( )}" ;;
    -B*) DIR="${REPLY##-B*( )}" ;;
    -S*) SRC="${REPLY##-S*( )}" ;;
    -*) OPT+=("$REPLY") ;;
    '') : ;;
    *)
      case $target in
        env)   ENV+=("$REPLY") ;;
        cmake) OPT+=("-D$REPLY") ;;
        build) DIR="$REPLY" ;;
        src)   SRC="$REPLY" ;;
      esac
      ;;
  esac
done < "$cfgfile"

cfgdir="$(dirname "$cfgfile")"
[ -z "$cfgdir" ] || cd "$cfgdir"

[ "$SRC" ] || abort "source tree '\$SRC' not set"

if [ -z "$DIR" ] && [[ $cfgfile = config-* ]]; then
  DIR="$(basename "${cfgfile#config-}")"
  DIR="${DIR%.*}"
fi
[ "$DIR" ] || abort "target directory '\$DIR' not set"

if [ "$config$fresh" ] || [ ! -r "$DIR/CMakeCache.txt" ] || [ "$cfgfile" -nt "$DIR/CMakeCache.txt" ]; then
  [ -z "$fresh" ] || fresh="--fresh"
  run env "${ENV[@]}" cmake $fresh "-G$GEN" "-B$DIR" "-S$SRC" "${OPT[@]}"
fi
if [ "$build" ]; then
  run env "${ENV[@]}" cmake --build "$DIR" "${args[@]}"
fi
if [ "$install" ]; then
  run env "${ENV[@]}" cmake --install "$DIR" "${args[@]}"
fi
