#!/bin/bash

set -ex

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

kubectl delete deployment inflate