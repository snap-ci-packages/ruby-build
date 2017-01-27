#!/bin/bash

set -e

if !(which rbenv &> /dev/null); then
  echo "rbenv is required to be on your \$PATH"
  exit 1
fi

readonly BUILD_TARGET_PATH="$(rbenv root)/versions"
readonly OUTPUT_DIR="$(rm -rf pkg && mkdir -p pkg && cd pkg && pwd)"

function fetch_ruby_versions() {
  cat <<LEGACY
1.8.7-p375
1.9.2-p330
1.9.3-p551
2.0.0-p648
LEGACY
  rbenv install --list | sed 's/^[ \t]*//g' | grep -E '^(jruby-)?([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)$' | grep -vE '^(1.8|1.9|2.0|jruby-1.5|jruby-1.7.7)'
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

trap cleanup ERR
trap cleanup EXIT

function build_ruby() {
  local version=$1
  local patch=""

  if (echo $version | grep -qE '^(1.8.7|1.9.2)'); then
    patch="ssl_no_ec2m.patch"
  fi

  if (echo $version | grep -qE '^(2.1.0|2.1.1)'); then
    patch="readline.patch"
  fi

  if [ -z "$patch" ]; then
    rbenv install -f $version || return 1
  else
    cat patches/$patch | rbenv install -f $version -p || return 1
  fi

  RBENV_VERSION=$version rbenv exec gem install bundler --no-ri --no-rdoc && \
    tar zcf $OUTPUT_DIR/$version.tar.gz -C $BUILD_TARGET_PATH $version && \
    (cd $OUTPUT_DIR && sha256sum $version.tar.gz > $version.tar.gz.sha256)
}

if [ $# -gt 0 ]; then
  rubies_to_build="$1"
else
  rubies_to_build=$(fetch_ruby_versions | partition_across_workers | xargs)
fi

echo "This worker will build the following ruby versions: $rubies_to_build"

cleanup

for version in $rubies_to_build; do
  build_ruby $version || failed_rubies="$failed_rubies $version"
done

if [ -n "$failed_rubies" ]; then
  echo "The following ruby versions failed to build: $failed_rubies"
  exit 1
fi

echo "Done"

echo "Contents of $OUTPUT_DIR:"
ls -l $OUTPUT_DIR
