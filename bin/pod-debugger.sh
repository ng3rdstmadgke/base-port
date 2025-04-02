#!/bin/bash

set -euo pipefail

# Namespaceの選択
NAMESPACE="$(kubectl get ns -o wide | sed '1d' | fzf --height 25% --header 'Select a namespace')"
NAMESPACE_NAME="$(echo $NAMESPACE | awk '{print $1}')"

# Podの選択
POD="$(kubectl get pod -n ${NAMESPACE_NAME} -o wide | sed '1d' | fzf --height 25% --header 'Select a pod')"
POD_NAME="$(echo $POD | awk '{print $1}')"

# 起動するイメージの選択
IMAGE=$(
cat <<EOF | fzf --height 25% --header "Select a image"
public.ecr.aws/aws-cli/aws-cli
nicolaka/netshoot
ubuntu:24.04
EOF
)

echo kubectl -n $NAMESPACE_NAME debug $POD_NAME -ti --image=$IMAGE -- /bin/bash
kubectl -n $NAMESPACE_NAME debug $POD_NAME -ti --image=$IMAGE -- /bin/bash
