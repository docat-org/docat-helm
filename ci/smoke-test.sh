#!/usr/bin/env bash
# Smoke test an installed Docat release:
# upload docs through the API, read them back through nginx,
# restart the workload and check the docs survived (persistent volume).
#
# Usage: smoke-test.sh [all|upload|check]
#   all     upload, check, restart and check again (default)
#   upload  only upload the docs
#   check   only check the docs are served, e.g. after a chart upgrade
set -euo pipefail

MODE="${1:-all}"
RELEASE="${RELEASE:-docat}"
NAMESPACE="${NAMESPACE:-default}"
WORKLOAD="${WORKLOAD:-deployment/${RELEASE}}"
LOCAL_PORT="${LOCAL_PORT:-8080}"
PROJECT="ci-smoke-test"
VERSION="1.0.0"
MARKER="docat-helm-ci-smoke-test"

BASE_URL="http://127.0.0.1:${LOCAL_PORT}"
WORKDIR="$(mktemp -d)"
PF_PID=""

stop_port_forward() {
  if [[ -n "${PF_PID}" ]]; then
    kill "${PF_PID}" 2>/dev/null || true
    wait "${PF_PID}" 2>/dev/null || true
    PF_PID=""
  fi
}

cleanup() {
  stop_port_forward
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

start_port_forward() {
  stop_port_forward
  kubectl -n "${NAMESPACE}" port-forward "svc/${RELEASE}" "${LOCAL_PORT}:80" >"${WORKDIR}/port-forward.log" 2>&1 &
  PF_PID=$!
  for _ in $(seq 30); do
    if curl -fsS -o /dev/null "${BASE_URL}/"; then
      return 0
    fi
    sleep 1
  done
  echo "Port-forward to svc/${RELEASE} did not become ready:" >&2
  cat "${WORKDIR}/port-forward.log" >&2
  return 1
}

check_docs() {
  local body
  body="$(curl -fsS "${BASE_URL}/doc/${PROJECT}/${VERSION}/index.html")"
  if ! grep -q "${MARKER}" <<<"${body}"; then
    echo "Uploaded docs not served correctly, got:" >&2
    echo "${body}" >&2
    return 1
  fi
}

upload_docs() {
  echo "==> Building test docs archive"
  mkdir -p "${WORKDIR}/docs"
  echo "<html><body>${MARKER}</body></html>" >"${WORKDIR}/docs/index.html"
  (cd "${WORKDIR}/docs" && zip -q ../docs.zip index.html)

  echo "==> Uploading ${PROJECT}/${VERSION}"
  curl -fsS -X POST -F "file=@${WORKDIR}/docs.zip" "${BASE_URL}/api/${PROJECT}/${VERSION}"
  echo
}

case "${MODE}" in
  all | upload | check) ;;
  *)
    echo "Unknown mode: ${MODE} (expected all, upload or check)" >&2
    exit 1
    ;;
esac

start_port_forward

if [[ "${MODE}" != "check" ]]; then
  upload_docs
fi

if [[ "${MODE}" == "upload" ]]; then
  echo "==> Upload done"
  exit 0
fi

echo "==> Reading docs back"
check_docs

if [[ "${MODE}" == "check" ]]; then
  echo "==> Check passed"
  exit 0
fi

echo "==> Restarting ${WORKLOAD} to check persistence"
kubectl -n "${NAMESPACE}" rollout restart "${WORKLOAD}"
kubectl -n "${NAMESPACE}" rollout status "${WORKLOAD}" --timeout=180s

start_port_forward

echo "==> Reading docs back after restart"
check_docs

echo "==> Smoke test passed"
