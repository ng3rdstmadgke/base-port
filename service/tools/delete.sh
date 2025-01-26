#!/bin/bash

if [ -f "${PROJECT_DIR}/service/tools/tmp/app.yaml" ]; then
  kubectl delete -f ${PROJECT_DIR}/service/tools/tmp/app.yaml
fi