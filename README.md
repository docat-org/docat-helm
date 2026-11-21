# docat helm

[![CI](https://github.com/docat-org/docat-helm/actions/workflows/ci.yaml/badge.svg)](https://github.com/docat-org/docat-helm/actions/workflows/ci.yaml)

![](https://raw.githubusercontent.com/docat-org/.github/main/logo.png)

## Install chart

```bash
cd docat-helm-chart
helm upgrade --install docat .
```

Docat stores its docs and database on a single `ReadWriteOnce` volume mounted at `/var/docat`,
so the chart runs one replica with the `Recreate` strategy.

The volume survives pod restarts and, by default, `helm uninstall` too (`persistence.keep`).
To delete the docs after uninstalling, delete the PersistentVolumeClaim:

```bash
kubectl delete pvc docat
```

## Values

| Key | Default | Description |
|---|---|---|
| `image.repository` | `ghcr.io/docat-org/docat` | Docat image |
| `image.tag` | `""` | Image tag, defaults to the chart `appVersion` |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `env` | `[]` | Extra environment variables, e.g. `MAX_UPLOAD_SIZE` (default `100M` in the image) |
| `envFrom` | `[]` | Extra environment variables from ConfigMaps or Secrets |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port (the container always listens on `80`) |
| `ingress.enabled` | `false` | Create an Ingress |
| `ingress.className` | `""` | IngressClass name |
| `ingress.annotations` | `{}` | Ingress annotations, e.g. auth middleware or max body size |
| `ingress.hosts` | `chart-example.local` | Ingress hosts and paths |
| `ingress.tls` | `[]` | Ingress TLS |
| `persistence.enabled` | `true` | Store docs in a PersistentVolumeClaim; when `false` they are lost on restart |
| `persistence.existingClaim` | `""` | Use an existing PersistentVolumeClaim instead of creating one |
| `persistence.keep` | `true` | Keep the PersistentVolumeClaim on `helm uninstall`; installing again with the same release name reuses it |
| `persistence.storageClass` | `""` | StorageClass; empty uses the cluster default, `-` disables dynamic provisioning |
| `persistence.accessModes` | `[ReadWriteOnce]` | Volume access modes |
| `persistence.size` | `8Gi` | Volume size |
| `persistence.annotations` | `{}` | PersistentVolumeClaim annotations |
| `livenessProbe` / `readinessProbe` | HTTP `GET /` | Container probes |
| `resources` | `{}` | Container resources |
| `podAnnotations` | `{}` | Pod annotations |
| `podSecurityContext` / `securityContext` | `{}` | Pod and container security contexts |
| `serviceAccount.create` | `true` | Create a ServiceAccount |
| `nodeSelector` / `tolerations` / `affinity` | empty | Pod scheduling |

## Upgrading from 0.x

Chart `1.0.0` replaces the `StatefulSet` with a `Deployment` and removes the `replicaCount` and `autoscaling` values
(the HPA never worked, as it targeted a `Deployment`).

The `StatefulSet` volume is not deleted by the upgrade, so reuse it with `persistence.existingClaim`.
Its name is `<fullname>-<fullname>-0`, which is `docat-docat-0` for a release named `docat`:

```bash
kubectl get pvc   # find the existing claim
helm upgrade docat ./docat-helm-chart --set persistence.existingClaim=docat-docat-0
```

The CI tests this upgrade path.

## CI

Every pull request, push to `main` and a weekly schedule run [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml):

1. `helm lint` and [kubeconform](https://github.com/yannh/kubeconform) validation of the rendered manifests.
2. Install the chart on a [k3s](https://k3s.io) cluster (via [k3d](https://k3d.io)) with the chart `appVersion`
   and the `latest` Docat image, then run `helm test` and [`ci/smoke-test.sh`](ci/smoke-test.sh), which uploads docs
   through the API, reads them back and checks they survive a pod restart and a `helm uninstall` and install.
3. Install chart `0.0.1`, upload docs, upgrade to the current chart following [Upgrading from 0.x](#upgrading-from-0x)
   and check the docs are still there.

A specific Docat image tag can be tested by running the workflow manually (`workflow_dispatch`).

The smoke test also runs against any cluster where the chart is installed:

```bash
helm upgrade --install docat ./docat-helm-chart --wait
./ci/smoke-test.sh
```
