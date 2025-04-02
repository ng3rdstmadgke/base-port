#!/bin/bash

set -euo pipefail

# ノードの選択
NODE="$(kubectl get node -o wide | sed '1d' | fzf --height 25% --header 'Select a node')"
NODE_NAME="$(echo $NODE | awk '{print $1}')"

# 起動するイメージの選択
IMAGE=$(
cat <<EOF | fzf --height 25% --header "Select a image"
public.ecr.aws/aws-cli/aws-cli
nicolaka/netshoot
ubuntu:24.04
EOF
)

# ノードデバッガーのPodを起動
echo kubectl debug node/${NODE_NAME} -ti --image=$IMAGE -- /bin/bash
kubectl debug node/${NODE_NAME} -ti --image=$IMAGE -- /bin/bash

# ノードデバッガーのPodを削除
for pod in $(kubectl get po -o json | jq -r ".items[].metadata.name" | grep -e "^node-debugger"); do
  kubectl delete po $pod
done