```bash
kubectl apply -f sample/storageclass.yaml
kubectl apply -f sample/claim.yaml
kubectl apply -f sample/pod.yaml
```

```bash
kubectl delete -f sample/pod.yaml
kubectl delete -f sample/claim.yaml
kubectl delete -f sample/storageclass.yaml
```