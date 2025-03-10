# install github private runner

1. install certmanager

2. do helm install: ```helm upgrade --install --namespace actions-runner-system --set=authSecret.create=true --set=authSecret.github_token="${TOKEN}" --wait actions-runner-controller actions-runner-controller/actions-runner-controller```

3. apply the yaml for github-private-runners ```kubectl apply -f github-private-runners.yaml```

# ELK

1. (E)lasticsearch
2. (L)ogstash
3. (K)ibana

# Elastic stack (ELK) on Kubernetes

To run the ELK stack go to artifacthub.io ( https://artifacthub.io/ ) and find the official elasticsearch, logstash and kibana packages.
Official means that the packages originate from Elastic Inc.

Click the package but do not download directly. Copy the link circled in red:

![image](https://user-images.githubusercontent.com/79989908/193766672-f2b4f64e-fe92-4d64-a4f3-db3801d189d7.png)

Curl the tar and extract.

```bash
curl -O https://helm.elastic.co/helm/kibana/kibana-7.17.3.tgz

tar xzvf kibana-7.17.3.tgz
````

Now edit the values.yaml file for the desired changes and apply.

```bash
helm install kibana kibana
```

To install any of the components filebeat, kibana, elasticsearch or logstash go to the directory "elkhelmconfig".

There is a Helm chart for every component, apply them with

```
helm install/upgrade filebeat filebeat/
helm install/upgrade kibana kibana/
helm install/upgrade logstash logstash/
helm install/upgrade elasticsearch elasticsearch/
```

elasticsearch stores its data by default in /usr/share/elasticsearch, but once kube creates the directory it will have root permissions only.
To work around this is to first login to the logstash server and change ownership of the elasticsearch directory to 1000:1000

```
/usr/share/$ sudo chown -R 1000:1000 elasticsearch
```

The podsecurity in the yaml is also user 1000

```
podSecurityContext:
  runAsUser: 1000
```

# enabling ssl in ELK stack

As the ElK stack contains 3 projects, Elastic, Logstash and Kibana, once enabling SSL in elasticsearch it must be enabled in kibana and logstash as well.
Logstash uses elasticsearch to write to it and kibana reads from it. (also write in developer console)

## Enable SSL in elastic

First elastic.
In the helm chart enable protocol https. ```protocol: https```
This value is onlt used in the readinessProbe which does curl request to elastic

```curl --output /dev/null -k "$@" "{{ .Values.protocol }}://127.0.0.1:{{ .Values.httpPort }}${path}"```

This will curl to https instead of http from now on.

Also pass default credentials to curl ```set -- "$@" -u "elastic:changeme"```

Enable config settings in elasticsearch.yml with "xpack security enabled", "transport.ssl.enabled", "http.ssl.enabled" to true.

```
esConfig:
  elasticsearch.yml: |
    cluster.name: "docker-cluster"
    network.host: 0.0.0.0
    xpack.security.enabled: true
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.keystore.path: /usr/share/elasticsearch/config/certs/elastic-certificates.p12
    xpack.security.transport.ssl.truststore.path: /usr/share/elasticsearch/config/certs/elastic-certificates.p12

    xpack.security.http.ssl.enabled: true
    xpack.security.http.ssl.keystore.path: /usr/share/elasticsearch/config/certs/elastic-certificates.p12
    xpack.security.http.ssl.truststore.path: /usr/share/elasticsearch/config/certs/elastic-certificates.p12

    xpack.license.self_generated.type: basic
```

Also notice the PKCS certificate paths. That certificate must be created by first creating a CA certificate and then sign another certificate with that.

Login to the elasticsearch pod. kubectl exec -it elastic -- /bin/bash

Create CA with 10 years expiration.

```elasticsearch-certutil ca --days 3650```

Sign certificate with that CA.

```elasticsearch-certutil cert --ca elastic-stack-ca.p12 --days 3650 --out elastic-certificates.p12```

Now that we have the certificates, copy them local machine and put them in a secret in kubernetes.

```kubectl cp elasticsearch:/path/elastic-certificates.p12 .```

```kubectl cp elasticsearch:/path/elastic-stack-ca.p12 .```

```kubectl create secret generic elastic-certificates --from-file=elastic-certificates.p12 --from-file=elastic-stack-ca.p12```

Then alter the helm charts for secret volumemount to /usr/share/elasticsearch/config/certs and the certificates will appear in the pods.

```
secretMounts:
  - name: elastic-certificates
    secretName: elastic-certificates
    path: /usr/share/elasticsearch/config/certs
    defaultMode: 0755
```

***elasticsearch xpack security is enabled now***

## kibana

Then kibana must call elasticsearch over https and not http anymore.

The helm chart must point to https elastic endpoint.

```elasticsearchHosts: "https://elasticsearch-master:9200"```

Also change the readinessprobe curl request with credentials: ```-u "elastic:changeme"```

## logstash

Then last are the output filters in logstash. They need to be updated with user, password , cacert and most importantly "ssl_certificate_verification => false".

    output {
      elasticsearch {
        hosts => "https://elasticsearch-master:9200"
        ilm_rollover_alias => "odatweb"
        ilm_pattern => "{now/d}-000001"
        ilm_policy => "7-days-rollover"

        ssl => "true"
        user => "elastic"
        password => "changeme"
        cacert => "/usr/share/logstash/config/certs/elasticsearch-cert.pem"
        ssl_certificate_verification => false
      }
  }

To get the pem file the p12 certificate must be converted to pem format first.

```openssl pkcs12 -in elastic-stack-ca.p12 -clcerts -nokeys```

```
extraVolumeMounts:
  - name: elasticsearch-cert
    mountPath: /usr/share/logstash/config/certs/elasticsearch-cert.pem
    subPath: elasticsearch-cert.pem
```


# install private github runner for on premise deployment

```
helm upgrade --install --namespace actions-runner-system --create-namespace  --set=authSecret.create=true  --set=authSecret.github_token="Kn6hDQyzcf1hXKK6iAqu21QLme" --wait actions-runner-controller actions-runner-controller/actions-runner-controller
```

As of k8s 1.25 there are some restrictions in place that privileged pods are not allowed to run in all namespaces. The AdmissionController is configured like thiat.

To let the runner pod start up we must set the enforce=priviled oin the namespace label.

```kubectl label ns actions-runner-system pod-security.kubernetes.io/enforce=privileged```

# Elastic stack (ELK) on Docker

[![Elastic Stack version](https://img.shields.io/badge/Elastic%20Stack-8.3.3-00bfb3?style=flat&logo=elastic-stack)](https://www.elastic.co/blog/category/releases)
[![Build Status](https://github.com/deviantony/docker-elk/workflows/CI/badge.svg?branch=main)](https://github.com/deviantony/docker-elk/actions?query=workflow%3ACI+branch%3Amain)
[![Join the chat at https://gitter.im/deviantony/docker-elk](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/deviantony/docker-elk?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Run the latest version of the [Elastic stack][elk-stack] with Docker and Docker Compose.

It gives you the ability to analyze any data set by using the searching/aggregation capabilities of Elasticsearch and
the visualization power of Kibana.

![Animated demo](https://user-images.githubusercontent.com/3299086/155972072-0c89d6db-707a-47a1-818b-5f976565f95a.gif)

> **Note**  
> The Docker images backing this stack include [X-Pack][xpack] with [paid features][paid-features] enabled by default
> (see [How to disable paid features](#how-to-disable-paid-features) to disable them). **The [trial
> license][trial-license] is valid for 30 days**. After this license expires, you can continue using the free features
> seamlessly, without losing any data.

Based on the official Docker images from Elastic:

* [Elasticsearch](https://github.com/elastic/elasticsearch/tree/master/distribution/docker)
* [Logstash](https://github.com/elastic/logstash/tree/master/docker)
* [Kibana](https://github.com/elastic/kibana/tree/master/src/dev/build/tasks/os_packages/docker_generator)

Other available stack variants:

* [`tls`](https://github.com/deviantony/docker-elk/tree/tls): TLS encryption enabled in Elasticsearch
* [`searchguard`](https://github.com/deviantony/docker-elk/tree/searchguard): Search Guard support

---

## Contents

1. [Requirements](#requirements)
   * [Host setup](#host-setup)
   * [Docker Desktop](#docker-desktop)
     * [Windows](#windows)
     * [macOS](#macos)
1. [Usage](#usage)
   * [Bringing up the stack](#bringing-up-the-stack)
   * [Initial setup](#initial-setup)
     * [Setting up user authentication](#setting-up-user-authentication)
     * [Injecting data](#injecting-data)
   * [Cleanup](#cleanup)
   * [Version selection](#version-selection)
1. [Configuration](#configuration)
   * [How to configure Elasticsearch](#how-to-configure-elasticsearch)
   * [How to configure Kibana](#how-to-configure-kibana)
   * [How to configure Logstash](#how-to-configure-logstash)
   * [How to disable paid features](#how-to-disable-paid-features)
   * [How to scale out the Elasticsearch cluster](#how-to-scale-out-the-elasticsearch-cluster)
   * [How to reset a password programmatically](#how-to-reset-a-password-programmatically)
   * [How to add new data to ELK](#how-to-add-data-to-elk)
1. [Extensibility](#extensibility)
   * [How to add plugins](#how-to-add-plugins)
   * [How to enable the provided extensions](#how-to-enable-the-provided-extensions)
1. [JVM tuning](#jvm-tuning)
   * [How to specify the amount of memory used by a service](#how-to-specify-the-amount-of-memory-used-by-a-service)
   * [How to enable a remote JMX connection to a service](#how-to-enable-a-remote-jmx-connection-to-a-service)
1. [Going further](#going-further)
   * [Plugins and integrations](#plugins-and-integrations)

## Requirements

### Host setup

* [Docker Engine][docker-install] version **18.06.0** or newer
* [Docker Compose][compose-install] version **1.26.0** or newer (including [Compose V2][compose-v2])
* 1.5 GB of RAM

> **Warning**  
> While Compose versions between **1.22.0** and **1.25.5** can technically run this stack as well, these versions have a
> [known issue](https://github.com/deviantony/docker-elk/pull/678#issuecomment-1055555368) which prevents them from
> parsing quoted values properly inside `.env` files.

By default, the stack exposes the following ports:

* 5044: Logstash Beats input
* 50000: Logstash TCP input
* 9600: Logstash monitoring API
* 9200: Elasticsearch HTTP
* 9300: Elasticsearch TCP transport
* 5601: Kibana

> **Warning**  
> Elasticsearch's [bootstrap checks][booststap-checks] were purposely disabled to facilitate the setup of the Elastic
> stack in development environments. For production setups, we recommend users to set up their host according to the
> instructions from the Elasticsearch documentation: [Important System Configuration][es-sys-config].

### Docker Desktop

#### Windows

If you are using the legacy Hyper-V mode of _Docker Desktop for Windows_, ensure [File Sharing][win-filesharing] is
enabled for the `C:` drive.

#### macOS

The default configuration of _Docker Desktop for Mac_ allows mounting files from `/Users/`, `/Volume/`, `/private/`,
`/tmp` and `/var/folders` exclusively. Make sure the repository is cloned in one of those locations or follow the
instructions from the [documentation][mac-filesharing] to add more locations.

## Usage

> **Warning**  
> You must rebuild the stack images with `docker-compose build` whenever you switch branch or update the
> [version](#version-selection) of an already existing stack.

### Bringing up the stack

Clone this repository onto the Docker host that will run the stack, then start the stack's services locally using Docker
Compose:

```console
$ docker-compose up
```

> **Note**  
> You can also run all services in the background (detached mode) by appending the `-d` flag to the above command.

Give Kibana about a minute to initialize, then access the Kibana web UI by opening <http://localhost:5601> in a web
browser and use the following (default) credentials to log in:

* user: *elastic*
* password: *changeme*

> **Note**  
> Upon the initial startup, the `elastic`, `logstash_internal` and `kibana_system` Elasticsearch users are intialized
> with the values of the passwords defined in the [`.env`](.env) file (_"changeme"_ by default). The first one is the
> [built-in superuser][builtin-users], the other two are used by Kibana and Logstash respectively to communicate with
> Elasticsearch. This task is only performed during the _initial_ startup of the stack. To change users' passwords
> _after_ they have been initialized, please refer to the instructions in the next section.

### Initial setup

#### Setting up user authentication

> **Note**  
> Refer to [Security settings in Elasticsearch][es-security] to disable authentication.

> **Warning**  
> Starting with Elastic v8.0.0, it is no longer possible to run Kibana using the bootstraped privileged `elastic` user.

The _"changeme"_ password set by default for all aforementioned users is **unsecure**. For increased security, we will
reset the passwords of all aforementioned Elasticsearch users to random secrets.

1. Reset passwords for default users

    The commands below resets the passwords of the `elastic`, `logstash_internal` and `kibana_system` users. Take note
    of them.

    ```console
    $ docker-compose exec elasticsearch bin/elasticsearch-reset-password --batch --user elastic
    ```

    ```console
    $ docker-compose exec elasticsearch bin/elasticsearch-reset-password --batch --user logstash_internal
    ```

    ```console
    $ docker-compose exec elasticsearch bin/elasticsearch-reset-password --batch --user kibana_system
    ```

    If the need for it arises (e.g. if you want to [collect monitoring information][ls-monitoring] through Beats and
    other components), feel free to repeat this operation at any time for the rest of the [built-in
    users][builtin-users].

1. Replace usernames and passwords in configuration files

    Replace the password of the `elastic` user inside the `.env` file with the password generated in the previous step.
    Its value isn't used by any core component, but [extensions](#how-to-enable-the-provided-extensions) use it to
    connect to Elasticsearch.

    > **Note**  
    > In case you don't plan on using any of the provided [extensions](#how-to-enable-the-provided-extensions), or
    > prefer to create your own roles and users to authenticate these services, it is safe to remove the
    > `ELASTIC_PASSWORD` entry from the `.env` file altogether after the stack has been initialized.

    Replace the password of the `logstash_internal` user inside the `.env` file with the password generated in the
    previous step. Its value is referenced inside the Logstash pipeline file (`logstash/pipeline/logstash.conf`).

    Replace the password of the `kibana_system` user inside the `.env` file with the password generated in the previous
    step. Its value is referenced inside the Kibana configuration file (`kibana/config/kibana.yml`).

    See the [Configuration](#configuration) section below for more information about these configuration files.

1. Restart Logstash and Kibana to re-connect to Elasticsearch using the new passwords

    ```console
    $ docker-compose up -d logstash kibana
    ```

> **Note**  
> Learn more about the security of the Elastic stack at [Secure the Elastic Stack][sec-cluster].

#### Injecting data

Open the Kibana web UI by opening <http://localhost:5601> in a web browser and use the following credentials to log in:

* user: *elastic*
* password: *\<your generated elastic password>*

Now that the stack is fully configured, you can go ahead and inject some log entries. The shipped Logstash configuration
allows you to send content via TCP:

```console
# Using BSD netcat (Debian, Ubuntu, MacOS system, ...)
$ cat /path/to/logfile.log | nc -q0 localhost 50000
```

```console
# Using GNU netcat (CentOS, Fedora, MacOS Homebrew, ...)
$ cat /path/to/logfile.log | nc -c localhost 50000
```

You can also load the sample data provided by your Kibana installation.

### Cleanup

Elasticsearch data is persisted inside a volume by default.

In order to entirely shutdown the stack and remove all persisted data, use the following Docker Compose command:

```console
$ docker-compose down -v
```

### Version selection

This repository stays aligned with the latest version of the Elastic stack. The `main` branch tracks the current major
version (8.x).

To use a different version of the core Elastic components, simply change the version number inside the [`.env`](.env)
file. If you are upgrading an existing stack, remember to rebuild all container images using the `docker-compose build`
command.

> **Warning**  
> Always pay attention to the [official upgrade instructions][upgrade] for each individual component before performing a
> stack upgrade.

Older major versions are also supported on separate branches:

* [`release-7.x`](https://github.com/deviantony/docker-elk/tree/release-7.x): 7.x series
* [`release-6.x`](https://github.com/deviantony/docker-elk/tree/release-6.x): 6.x series (End-of-life)
* [`release-5.x`](https://github.com/deviantony/docker-elk/tree/release-5.x): 5.x series (End-of-life)

## Configuration

> **Note**  
> Configuration is not dynamically reloaded, you will need to restart individual components after any configuration
> change.

### How to configure Elasticsearch

The Elasticsearch configuration is stored in [`elasticsearch/config/elasticsearch.yml`][config-es].

You can also specify the options you want to override by setting environment variables inside the Compose file:

```yml
elasticsearch:

  environment:
    network.host: _non_loopback_
    cluster.name: my-cluster
```

Please refer to the following documentation page for more details about how to configure Elasticsearch inside Docker
containers: [Install Elasticsearch with Docker][es-docker].

### How to configure Kibana

The Kibana default configuration is stored in [`kibana/config/kibana.yml`][config-kbn].

You can also specify the options you want to override by setting environment variables inside the Compose file:

```yml
kibana:

  environment:
    SERVER_NAME: kibana.example.org
```

Please refer to the following documentation page for more details about how to configure Kibana inside Docker
containers: [Install Kibana with Docker][kbn-docker].

### How to configure Logstash

The Logstash configuration is stored in [`logstash/config/logstash.yml`][config-ls].

You can also specify the options you want to override by setting environment variables inside the Compose file:

```yml
logstash:

  environment:
    LOG_LEVEL: debug
```

Please refer to the following documentation page for more details about how to configure Logstash inside Docker
containers: [Configuring Logstash for Docker][ls-docker].

### How to disable paid features

Switch the value of Elasticsearch's `xpack.license.self_generated.type` setting from `trial` to `basic` (see [License
settings][trial-license]).

You can also cancel an ongoing trial before its expiry date — and thus revert to a basic license — either from the
[License Management][license-mngmt] panel of Kibana, or using Elasticsearch's [Licensing APIs][license-apis].

### How to scale out the Elasticsearch cluster

Follow the instructions from the Wiki: [Scaling out Elasticsearch](https://github.com/deviantony/docker-elk/wiki/Elasticsearch-cluster)

### How to reset a password programmatically

If for any reason your are unable to use Kibana to change the password of your users (including [built-in
users][builtin-users]), you can use the Elasticsearch API instead and achieve the same result.

In the example below, we reset the password of the `elastic` user (notice "/user/elastic" in the URL):

```console
$ curl -XPOST -D- 'http://localhost:9200/_security/user/elastic/_password' \
    -H 'Content-Type: application/json' \
    -u elastic:<your current elastic password> \
    -d '{"password" : "<your new password>"}'
```
## How to add data to elk
Install filebeat on the server via powershell: 
```console
.\install-service-filebeat.ps1
```

Edit the filebeat config, most likely `d:\filebeat\filebeat.yml`
change type, id, host & enabled 

  ```paths:
    #- /var/log/*.log
    - D:\FujiTT\Log files\*.log

  multiline.type: pattern
  multiline.pattern: '^[[:space:]]'
  multiline.negate: false
  multiline.match: after
  
 ============================== Filebeat modules ==============================

setup.ilm.enabled: false
setup.template.name: multiline
setup.template.pattern: multiline

 ------------------------------ Logstash Output -------------------------------
output.logstash:
  # The Logstash hosts
  hosts: ["ubdock05.fujicolor.nl:32009"]
  ```

Add a new output to elastic-logstash-kibana project (git)
```
else if "W2K16FUJIPP" in [agent][name] {
    elasticsearch {
        hosts => "http://elasticsearch-master:9200" 
        ilm_rollover_alias => "fujipp"
        ilm_pattern => "{now/d}-000001"
        ilm_policy => "7-days-rollover"
    }
}
```

Create an index template in ElasticSearch. In this case we are using an existing index lifecycle policy called '7-days-rollover'

```
PUT _index_template/fujipp
{
  "template": {
    "settings": {
      "index": {
        "lifecycle": {
          "name": "7-days-rollover",
          "rollover_alias": "fujipp"
        },
        "number_of_replicas": "0"
      }
    }
  },
  "index_patterns": [
    "fujipp-*"
  ]
}
```
Create an alias
```
PUT fujipp-2023-03-22-000001
{
  "aliases": {
    "fujipp": {
      "is_write_index": true
    }
  }
}
```

Deploy elastic-logstash-kibana project with the new output 

Start filebeat
```console
Start-Service filebeat
```

As soon the Docs count is greater than zero, create an Kibana Index Pattern.

At least 1 docs is needed to select the Timestamp field


## Extensibility

### How to add plugins

To add plugins to any ELK component you have to:

1. Add a `RUN` statement to the corresponding `Dockerfile` (eg. `RUN logstash-plugin install logstash-filter-json`)
1. Add the associated plugin code configuration to the service configuration (eg. Logstash input/output)
1. Rebuild the images using the `docker-compose build` command

### How to enable the provided extensions

A few extensions are available inside the [`extensions`](extensions) directory. These extensions provide features which
are not part of the standard Elastic stack, but can be used to enrich it with extra integrations.

The documentation for these extensions is provided inside each individual subdirectory, on a per-extension basis. Some
of them require manual changes to the default ELK configuration.

## JVM tuning

### How to specify the amount of memory used by a service

The startup scripts for Elasticsearch and Logstash can append extra JVM options from the value of an environment
variable, allowing the user to adjust the amount of memory that can be used by each component:

| Service       | Environment variable |
|---------------|----------------------|
| Elasticsearch | ES_JAVA_OPTS         |
| Logstash      | LS_JAVA_OPTS         |

To accomodate environments where memory is scarce (Docker Desktop for Mac has only 2 GB available by default), the Heap
Size allocation is capped by default in the `docker-compose.yml` file to 512 MB for Elasticsearch and 256 MB for
Logstash. If you want to override the default JVM configuration, edit the matching environment variable(s) in the
`docker-compose.yml` file.

For example, to increase the maximum JVM Heap Size for Logstash:

```yml
logstash:

  environment:
    LS_JAVA_OPTS: -Xms1g -Xmx1g
```

When these options are not set:

* Elasticsearch starts with a JVM Heap Size that is [determined automatically][es-heap].
* Logstash starts with a fixed JVM Heap Size of 1 GB.

### How to enable a remote JMX connection to a service

As for the Java Heap memory (see above), you can specify JVM options to enable JMX and map the JMX port on the Docker
host.

Update the `{ES,LS}_JAVA_OPTS` environment variable with the following content (I've mapped the JMX service on the port
18080, you can change that). Do not forget to update the `-Djava.rmi.server.hostname` option with the IP address of your
Docker host (replace **DOCKER_HOST_IP**):

```yml
logstash:

  environment:
    LS_JAVA_OPTS: -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.port=18080 -Dcom.sun.management.jmxremote.rmi.port=18080 -Djava.rmi.server.hostname=DOCKER_HOST_IP -Dcom.sun.management.jmxremote.local.only=false
```

## Going further

### Plugins and integrations

See the following Wiki pages:

* [External applications](https://github.com/deviantony/docker-elk/wiki/External-applications)
* [Popular integrations](https://github.com/deviantony/docker-elk/wiki/Popular-integrations)

[elk-stack]: https://www.elastic.co/what-is/elk-stack
[xpack]: https://www.elastic.co/what-is/open-x-pack
[paid-features]: https://www.elastic.co/subscriptions
[es-security]: https://www.elastic.co/guide/en/elasticsearch/reference/current/security-settings.html
[trial-license]: https://www.elastic.co/guide/en/elasticsearch/reference/current/license-settings.html
[license-mngmt]: https://www.elastic.co/guide/en/kibana/current/managing-licenses.html
[license-apis]: https://www.elastic.co/guide/en/elasticsearch/reference/current/licensing-apis.html

[elastdocker]: https://github.com/sherifabdlnaby/elastdocker

[docker-install]: https://docs.docker.com/get-docker/
[compose-install]: https://docs.docker.com/compose/install/
[compose-v2]: https://docs.docker.com/compose/cli-command/
[linux-postinstall]: https://docs.docker.com/engine/install/linux-postinstall/

[booststap-checks]: https://www.elastic.co/guide/en/elasticsearch/reference/current/bootstrap-checks.html
[es-sys-config]: https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html
[es-heap]: https://www.elastic.co/guide/en/elasticsearch/reference/current/important-settings.html#heap-size-settings

[win-filesharing]: https://docs.docker.com/desktop/windows/#file-sharing
[mac-filesharing]: https://docs.docker.com/desktop/mac/#file-sharing

[builtin-users]: https://www.elastic.co/guide/en/elasticsearch/reference/current/built-in-users.html
[ls-monitoring]: https://www.elastic.co/guide/en/logstash/current/monitoring-with-metricbeat.html
[sec-cluster]: https://www.elastic.co/guide/en/elasticsearch/reference/current/secure-cluster.html

[connect-kibana]: https://www.elastic.co/guide/en/kibana/current/connect-to-elasticsearch.html
[index-pattern]: https://www.elastic.co/guide/en/kibana/current/index-patterns.html

[config-es]: ./elasticsearch/config/elasticsearch.yml
[config-kbn]: ./kibana/config/kibana.yml
[config-ls]: ./logstash/config/logstash.yml

[es-docker]: https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html
[kbn-docker]: https://www.elastic.co/guide/en/kibana/current/docker.html
[ls-docker]: https://www.elastic.co/guide/en/logstash/current/docker-config.html

[upgrade]: https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-upgrade.html
