- https://www.keycloak.org/getting-started/getting-started-kube
- https://www.keycloak.org/getting-started/getting-started-docker
- https://www.keycloak.org/server/containers
- https://www.keycloak.org/server/configuration-production


```bash
kubectl apply -f ${CONTAINER_PROJECT_ROOT}/scripts/keycloak/keycloak.yaml
```

```bash
kubectl delete -f ${CONTAINER_PROJECT_ROOT}/scripts/keycloak/keycloak.yaml
```