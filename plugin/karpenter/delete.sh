#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR
for manifest in $(ls $SCRIPT_DIR/tmp/*.yaml | sort -r); do
  kubectl delete -f $manifest
done