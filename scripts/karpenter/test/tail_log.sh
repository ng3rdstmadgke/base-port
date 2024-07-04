#!/bin/bash
kubectl logs -f -n kube-system -l app.kubernetes.io/name=karpenter -c controller