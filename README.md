# docat helm

[![CI](https://github.com/docat-org/docat-helm/actions/workflows/ci.yaml/badge.svg)](https://github.com/docat-org/docat-helm/actions/workflows/ci.yaml)

![](https://raw.githubusercontent.com/docat-org/.github/main/logo.png)

## Install chart

```bash
cd docat-helm-chart
helm upgrade --install docat .
```

## CI

Every pull request, push to `main` and a weekly schedule run [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml):

1. `helm lint` and [kubeconform](https://github.com/yannh/kubeconform) validation of the rendered manifests.
2. Install the chart on a [k3s](https://k3s.io) cluster (via [k3d](https://k3d.io)) with the chart `appVersion`
   and the `latest` Docat image, then run `helm test` and [`ci/smoke-test.sh`](ci/smoke-test.sh), which uploads docs
   through the API, reads them back and checks they survive a pod restart.

A specific Docat image tag can be tested by running the workflow manually (`workflow_dispatch`).

The smoke test also runs against any cluster where the chart is installed:

```bash
helm upgrade --install docat ./docat-helm-chart --wait
./ci/smoke-test.sh
```
