#!/usr/bin/env bash
set -Eeuo pipefail

ENVIRONMENT="${1:?Usage: deploy.sh staging|production}"
ROOT_DIR="$(git rev-parse --show-toplevel)"
CHART_PATH="$ROOT_DIR/prod-cicd-sec/helm/microchat"
IMAGE_PREFIX="${IMAGE_PREFIX:-vanbasten01}"
IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG must be set by the workflow}"

case "$ENVIRONMENT" in
  staging)
    RELEASE="microchat-staging"
    NAMESPACE="microchat-staging"
    VALUES_FILE="$CHART_PATH/values-staging.yaml"
    ;;
  production)
    RELEASE="microchat-prod"
    NAMESPACE="microchat-prod"
    VALUES_FILE="$CHART_PATH/values-prod.yaml"
    ;;
  *)
    echo "Unknown environment: $ENVIRONMENT" >&2
    exit 2
    ;;
esac

: "${REDIS_PASSWORD:?Set REDIS_PASSWORD in the GitHub environment secrets}"
: "${MONGODB_USERNAME:?Set MONGODB_USERNAME in the GitHub environment secrets}"
: "${MONGODB_PASSWORD:?Set MONGODB_PASSWORD in the GitHub environment secrets}"

for command in kubectl helm curl jq git; do
  command -v "$command" >/dev/null || {
    echo "Required command not found: $command" >&2
    exit 127
  }
done

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "Values file not found: $VALUES_FILE" >&2
  exit 1
fi

# Select the most recent successfully deployed Helm revision.
previous_revision="$(
  helm history "$RELEASE" -n "$NAMESPACE" -o json 2>/dev/null |
    jq -r '[.[] | select(.status == "deployed")] | last | .revision // 0' \
      2>/dev/null || echo 0
)"
previous_revision="${previous_revision:-0}"

rollback() {
  local reason="${1:-deployment health check failed}"

  echo "::error::$reason"

  if [[ "$previous_revision" =~ ^[0-9]+$ ]] &&
    (( previous_revision > 0 )); then
    echo "Rolling back $RELEASE to deployed Helm revision $previous_revision."

    helm rollback "$RELEASE" "$previous_revision" \
      --namespace "$NAMESPACE" \
      --wait \
      --timeout 120s ||
      echo "::error::Helm rollback command failed"
  else
    echo "No previous successful revision; uninstalling failed first installation."

    helm uninstall "$RELEASE" \
      --namespace "$NAMESPACE" \
      --wait \
      --timeout 120s ||
      echo "::warning::No release to uninstall or uninstall failed"
  fi

  exit 1
}

echo "Preparing namespace-scoped credentials for $NAMESPACE."

kubectl create namespace "$NAMESPACE" \
  --dry-run=client -o yaml |
  kubectl apply -f -

# Use temporary files so secret values do not appear in kubectl arguments.
SECRET_DIR="$(mktemp -d)"
chmod 700 "$SECRET_DIR"
umask 077

cleanup_secrets() {
  rm -rf "$SECRET_DIR"
}

trap cleanup_secrets EXIT

printf '%s' "$REDIS_PASSWORD" > "$SECRET_DIR/redis-password"
printf '%s' "$MONGODB_USERNAME" > "$SECRET_DIR/mongodb-username"
printf '%s' "$MONGODB_PASSWORD" > "$SECRET_DIR/mongodb-password"

kubectl create secret generic microchat-redis-secret \
  --namespace "$NAMESPACE" \
  --from-file=password="$SECRET_DIR/redis-password" \
  --dry-run=client -o yaml |
  kubectl apply -f -

kubectl create secret generic microchat-mongodb-secret \
  --namespace "$NAMESPACE" \
  --from-file=username="$SECRET_DIR/mongodb-username" \
  --from-file=password="$SECRET_DIR/mongodb-password" \
  --dry-run=client -o yaml |
  kubectl apply -f -

unset REDIS_PASSWORD MONGODB_USERNAME MONGODB_PASSWORD

cleanup_secrets
trap - EXIT

echo "Deploying $RELEASE with image tag $IMAGE_TAG."

if ! helm upgrade --install "$RELEASE" "$CHART_PATH" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values "$VALUES_FILE" \
  --set-string "frontend.image.repository=$IMAGE_PREFIX/prod-cicd-frontend" \
  --set-string "frontend.image.tag=$IMAGE_TAG" \
  --set-string "restApi.image.repository=$IMAGE_PREFIX/prod-cicd-rest-api" \
  --set-string "restApi.image.tag=$IMAGE_TAG" \
  --set-string "websocket.image.repository=$IMAGE_PREFIX/prod-cicd-websocket" \
  --set-string "websocket.image.tag=$IMAGE_TAG" \
  --wait \
  --timeout 180s; then
  rollback "Helm upgrade failed for $RELEASE."
fi

for deployment in frontend rest-api websocket; do
  kubectl rollout status "deployment/$RELEASE-$deployment" \
    --namespace "$NAMESPACE" \
    --timeout=45s ||
    rollback "Rollout failed for $RELEASE-$deployment."
done

smoke_check() {
  local service="$1"
  local local_port="$2"
  local service_port="$3"
  local path="$4"
  local log_file="/tmp/${RELEASE}-${service}-port-forward.log"
  local pid=""

  kubectl port-forward \
    --namespace "$NAMESPACE" \
    "service/$RELEASE-$service" \
    "${local_port}:${service_port}" \
    >"$log_file" 2>&1 &
  pid=$!

  for _ in $(seq 1 20); do
    if curl --silent --show-error --fail --max-time 3 \
      "http://127.0.0.1:${local_port}${path}" >/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "Smoke test passed: $service $path"
      return 0
    fi

    if ! kill -0 "$pid" 2>/dev/null; then
      cat "$log_file" >&2 || true
      return 1
    fi

    sleep 1
  done

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  cat "$log_file" >&2 || true
  return 1
}

smoke_check frontend 18080 80 /health ||
  rollback "Frontend smoke test failed."

smoke_check rest-api 15000 5000 /api/health ||
  rollback "REST API smoke test failed."

smoke_check websocket 18002 8000 /health ||
  rollback "WebSocket smoke test failed."

echo "Deployment succeeded: environment=$ENVIRONMENT release=$RELEASE namespace=$NAMESPACE image_tag=$IMAGE_TAG"
