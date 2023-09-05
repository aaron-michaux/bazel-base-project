#!/bin/bash

set -euo pipefail

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [queries...]*

      Bazel provides no way to use a wildcard as a dependency:

         myrule(name = "example", deps = "//source/...") # <-- forbidden

      Yet this is probably what you want to do for selecting targets for 
      clang-tidy, clang-format, and refresh_compile_commands.

      Bazel makes it impossible to create an "in-process" work-around.
      For example, a `genquery` rule cannot have a wildcard, and furthermore,
      it's impossible to run `bazel query` inside of a repository_rule:
      bazel will hang!

   Examples:

      # Generate skylark list: ["//source/:foo", ...]
      > $(basename $0) //source/... 
   
      # Generate a list for multiple queries:
      > $(basename $0) //source/... //include...

EOF
}

# -- Parse the command line

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

workspace_dir()
{
    while true ; do    
        [ -f "WORKSPACE" ] && pwd -P && return 0
        local D="$(pwd)"
        cd ..
        [ "$D" = "$(pwd)" ] && echo "Could not find WORKSPACE file, aborting" 1>&2 && exit 1
    done
}

TMPD="$(mktemp -d /tmp/$(basename "$0").XXXXXX)"
trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPD"
}

query_targets()
{
    for QUERY in "$@" ; do
        if ! bazel query "$QUERY" 2>"$TMPD/stderr" ; then
            echo "ERROR executing query:" 1>&2
            echo 1>&2
            echo "   bazel query $QUERY" 1>&2
            echo 1>&2
            cat "$TMPD/stderr" 1>&2
            exit 1
        fi
    done | sort | uniq 
}

target_list()
{
    query_targets "$@" | sed 's,^,   ",' | sed 's/$/",/' 
}

target_list "$@" > "$TMPD/list"
if [ "$(cat $TMPD/list)" = "" ] ; then
    echo "[]"
else
    printf "[\n%s\n]" "$(cat "$TMPD/list")"
fi

