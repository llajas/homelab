# Unbound

[Unbound](https://www.nlnetlabs.nl/projects/unbound/about/) is a validating, recursive, caching DNS resolver.


## Prerequisites

-	Kubernetes 1.21 or later

## Installing the Chart

The chart can be installed as follows:

```console
$ helm repo add unbound https://pixelfederation.github.io/unbound
$ helm --namespace=unbound install unbound pixelfederation/unbound
```

To uninstall/delete the `unbound` deployment:

```console
$ helm uninstall unbound
```
The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

See `values.yaml` for configuration notes. Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

See [man](https://www.nlnetlabs.nl/documentation/unbound/unbound.conf/) and configmap for posible configuration options.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install unbound pixelfederation/unbound -f values.yaml
```
