# install github private runner

1. install certmanager

2. do helm install: ```helm upgrade --install --namespace actions-runner-system --set=authSecret.create=true --set=authSecret.github_token="${TOKEN}" --wait actions-runner-controller actions-runner-controller/actions-runner-controller```

3. apply the yaml for github-private-runners ```kubectl apply -f github-private-runners.yaml```
