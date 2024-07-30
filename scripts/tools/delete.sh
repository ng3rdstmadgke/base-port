#!/bin/bash

if [ -f "${CONTAINER_PROJECT_ROOT}/scripts/tools/tmp/app.yaml" ]; then
  kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/tools/tmp/app.yaml
fi