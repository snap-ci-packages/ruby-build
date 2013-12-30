#!/bin/bash
set -x
BUNDLE_PATH=/tmp/.bundle-$(basename $(pwd))
if [ -z "$BUNDLE_PATH" ]
then
   BUNDLE_PATH=".bundle"
fi
bundle install --path $BUNDLE_PATH --binstubs --clean
