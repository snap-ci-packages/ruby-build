#!/bin/bash

set -e

if !(which rbenv &> /dev/null); then
  echo "rbenv is required to be on your \$PATH"
  exit 1
fi

readonly BUILD_TARGET_PATH="$(rbenv root)/versions"

function fetch_ruby_versions() {
  cat <<LEGACY
1.8.7-p375
1.9.2-p330
1.9.3-p551
2.0.0-p648
LEGACY
  rbenv install --list | sed 's/^[ \t]*//g' | grep -E '^(jruby-)?([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)$' | grep -vE '^(1.8|1.9|2.0)'
}

function partition_across_workers() {
  local total_workers="${SNAP_WORKER_TOTAL:-1}"
  local worker_index="$((${SNAP_WORKER_INDEX:-1} - 1))" # we want a zero-based index, so subtract 1

  awk "((NR + $worker_index) % $total_workers) == 0" -
}

function cleanup() {
  rm -rf $BUILD_TARGET_PATH
  mkdir -p $BUILD_TARGET_PATH
}

if [ $# -gt 0 ]; then
  rubies_to_build="$1"
else
  rubies_to_build=$(fetch_ruby_versions | partition_across_workers | xargs)
fi

echo "This worker will build the following ruby versions: $rubies_to_build"

cleanup

for version in $rubies_to_build; do
  rbenv install -f $version
done