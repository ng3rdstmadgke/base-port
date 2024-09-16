#!/bin/bash
set -eu

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR
for manifest in $(ls $SCRIPT_DIR/tmp/*.yaml); do
  kubectl apply -f $manifest
done