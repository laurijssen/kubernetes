# install github private runner

1. install certmanager

2. do helm install: ```helm upgrade --install --namespace actions-runner-system --set=authSecret.create=true --set=authSecret.github_token="${TOKEN}" --wait actions-runner-controller actions-runner-controller/actions-runner-controller```

3. apply the yaml for github-private-runners ```kubectl apply -f github-private-runners.yaml```

# setup keepalived as virtual IP system

```
ubuntu@cp-1:~$ cat /etc/keepalived/keepalived.conf

vrrp_instance VI_1 {
    state MASTER ! state BACKUP on other machines
    interface ens192
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        192.168.130.21/24
    }
}
```
