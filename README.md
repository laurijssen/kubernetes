# kind-k8s

## setup kind cluster

### install docker

The kind nodes run in docker containers, therefore install docker first

Install curl + gpg if not installed yet

```bash
 sudo apt-get update

 sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```   

Add docker's gpg key

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

Add docker package to the apt repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

The update apt repos and install the docker components.

```
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io
```

### install kind

Now install kind

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.12.0/kind-linux-amd64
chmod +x ./kind
mv ./kind /some-dir-in-your-PATH/kind
```

Create the cluster

The ambassador loadbalancer does not seem to work on k8s 1.23, so use image v1.18 as wel want to use ambassador later.
Use the cluster-config yaml.

```
kind create cluster --name=cnnp --config=cluster-config.yaml --image=kindnode:v1.18.4
```

