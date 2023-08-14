#!/bin/bash

kubectl delete -f clusterrolewatcher.yaml
kubectl delete -f clusterroleadmin.yaml

kubectl create -f clusterroleadmin.yaml
kubectl create -f clusterrolewatcher.yaml

serviceaccounts=("watcher" "fipsadmin")

function createAccount {
    account=$1-apps

    openssl genrsa -out ${account}.key 2048

    openssl req -new -key ${account}.key -out ${account}.csr -subj "/CN=${account}/O=fips"

    sudo openssl x509 -req -in ${account}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${account}.crt -days 10000

    return $?
}

function deleteAccount {
    echo $1
    account=$1
    kubectl delete sa ${account}-apps
    kubectl delete clusterrolebinding binding-${account}
    kubectl config delete-user ${account}-apps
}

for account in ${serviceaccounts[@]}; do   
    deleteAccount ${account}
    createAccount ${account}
    if [ $? -eq 1 ];
    then
        echo "[!!!] could not sign certificate for account ${account}"
        exit 1
    fi
done

rm -f *.csr

for account in ${serviceaccounts[@]}; do
    kubectl config set-credentials ${account}-apps --client-certificate=${account}-apps.crt --client-key=${account}-apps.key 

    kubectl create sa ${account}-apps

    kubectl create clusterrolebinding binding-${account} --clusterrole=${account} --user=${account}-apps
done
