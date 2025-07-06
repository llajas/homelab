# Homelab Docs Helm Chart

This Helm chart deploys the homelab-docs application to a Kubernetes cluster with support for multiple replicas and load balancing.

## Features

- **Multi-replica deployment** with configurable replica count
- **Auto-scaling** support with HPA (Horizontal Pod Autoscaler)
- **Load balancing** across multiple pods
- **Health checks** for liveness and readiness probes
- **Pod anti-affinity** to spread replicas across different nodes
- **Rolling updates** with configurable strategy
- **Ingress support** for external access
- **Resource limits and requests**
- **Security context** with non-root user
- **Optional persistent storage** for caching

## Prerequisites

- Kubernetes 1.16+
- Helm 3.2.0+

## Installation

### Quick Start

```bash
# Install with default values
helm install homelab-docs ./helm/homelab-docs

# Install with custom repository URL
helm install homelab-docs ./helm/homelab-docs \
  --set config.repoUrl=https://github.com/yourusername/your-repo

# Install with multiple replicas
helm install homelab-docs ./helm/homelab-docs \
  --set replicaCount=3
```

### Using Makefile

```bash
# Build and push image, then install with Helm
make build push helm-install

# Upgrade existing deployment
make helm-upgrade

# Uninstall
make helm-uninstall

# Preview generated manifests
make helm-template
```

## Configuration

The following table lists the configurable parameters and their default values.

### Application Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `2` |
| `config.repoUrl` | Repository URL to clone | `https://github.com/llajas/homelab` |
| `config.updateInterval` | Update check interval (seconds) | `120` |

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Image repository | `registry.lajas.tech/homelab-documenatation` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `80` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts[0].host` | Hostname | `homelab-docs.local` |

### Resource Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |

### Auto-scaling Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `2` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU % | `80` |

## Examples

### Production Deployment with Ingress

```yaml
# values-prod.yaml
replicaCount: 3

image:
  tag: "v1.0.0"

config:
  repoUrl: "https://github.com/llajas/homelab"
  updateInterval: 300

service:
  type: ClusterIP

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - host: docs.lajas.tech
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: homelab-docs-tls
      hosts:
        - docs.lajas.tech

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi
```

Deploy with:
```bash
helm install homelab-docs ./helm/homelab-docs -f values-prod.yaml
```

### Development Deployment

```yaml
# values-dev.yaml
replicaCount: 1

config:
  repoUrl: "https://github.com/yourusername/homelab-dev"
  updateInterval: 60

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

## High Availability Features

### Pod Anti-Affinity
The chart includes pod anti-affinity rules to spread replicas across different nodes:

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - homelab-docs
        topologyKey: kubernetes.io/hostname
```

### Rolling Updates
Configured for zero-downtime deployments:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%
    maxSurge: 25%
```

### Health Checks
Includes both liveness and readiness probes:

```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 30
```

## Monitoring and Observability

### Viewing Logs
```bash
# View logs from all replicas
kubectl logs -l app.kubernetes.io/name=homelab-docs

# Follow logs
kubectl logs -f -l app.kubernetes.io/name=homelab-docs

# View logs from specific pod
kubectl logs <pod-name>
```

### Checking Status
```bash
# Check deployment status
kubectl get deployment homelab-docs

# Check pods
kubectl get pods -l app.kubernetes.io/name=homelab-docs

# Check service
kubectl get service homelab-docs

# Check HPA (if enabled)
kubectl get hpa homelab-docs
```

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits and image availability
2. **Service not accessible**: Verify service and ingress configuration
3. **High memory usage**: Adjust `UPDATE_INTERVAL` or add resource limits
4. **Git clone failures**: Check repository URL and network connectivity

### Debug Commands

```bash
# Describe deployment
kubectl describe deployment homelab-docs

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Port forward for local testing
kubectl port-forward service/homelab-docs 8080:80
```

## Uninstalling

```bash
# Using Helm
helm uninstall homelab-docs

# Using Makefile
make helm-uninstall
```
