#!/usr/bin/env bash
set -Eeuo pipefail

ENVIRONMENT="${1:?Usage: deploy.sh staging|production}"
ROOT_DIR="$(git rev-parse --show-toplevel)"
CHART_PATH="$ROOT_DIR/prod-cicd-sec/helm/microchat"
IMAGE_PREFIX="${IMAGE_PREFIX:-vanbasten01}"
IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG must be set by the workflow}"
AFFECTED_SERVICES="${AFFECTED_SERVICES:?AFFECTED_SERVICES must be set by the workflow}"

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

# Define the supported services and their Helm image-value paths.
declare -A REPOSITORIES=(
  [frontend]="$IMAGE_PREFIX/prod-cicd-frontend"
  [rest-api]="$IMAGE_PREFIX/prod-cicd-rest-api"
  [websocket]="$IMAGE_PREFIX/prod-cicd-websocket"
)

declare -A HELM_KEYS=(
  [frontend]="frontend"
  [rest-api]="restApi"
  [websocket]="websocket"
)

declare -A SELECTED=(
  [frontend]=false
  [rest-api]=false
  [websocket]=false
)

IFS=',' read -r -a REQUESTED_SERVICES <<< "$AFFECTED_SERVICES"

if [[ ${#REQUESTED_SERVICES[@]} -eq 0 ]]; then
  echo "::error::No affected services were provided."
  exit 1
fi

for service in "${REQUESTED_SERVICES[@]}"; do
  service="${service//[[:space:]]/}"

  case "$service" in
    frontend|rest-api|websocket)
      SELECTED["$service"]=true
      ;;
    *)
      echo "::error::Unknown affected service: '$service'"
      exit 1
      ;;
  esac
done

echo "Environment: $ENVIRONMENT"
echo "Release: $RELEASE"
echo "Affected services: $AFFECTED_SERVICES"

# Require the namespace to exist; the deployment role must not create it.
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "::error::Namespace '$NAMESPACE' does not exist or cannot be accessed."
  echo "Create it beforehand using an authorized administrative identity."
  exit 1
fi

# Find the most recent successfully deployed Helm revision.
previous_revision="$(
  helm history "$RELEASE" -n "$NAMESPACE" -o json 2>/dev/null |
    jq -r '[.[] | select(.status == "deployed")] | last | .revision // 0' \
      2>/dev/null || echo 0
)"
previous_revision="${previous_revision:-0}"

if [[ ! "$previous_revision" =~ ^[0-9]+$ ]]; then
  previous_revision=0
fi

# Read the currently deployed image tags before changing anything.
CURRENT_VALUES=""

if (( previous_revision > 0 )); then
  CURRENT_VALUES="$(mktemp)"
  trap 'rm -f "$CURRENT_VALUES"' EXIT

  if ! helm get values "$RELEASE" \
    --namespace "$NAMESPACE" \
    --all \
    -o json > "$CURRENT_VALUES"; then
    echo "::error::Unable to read the currently deployed Helm values."
    exit 1
  fi
else
  # A selective deployment cannot safely initialize a release whose
  # unaffected images have never been deployed.
  for service in frontend rest-api websocket; do
    if [[ "${SELECTED[$service]}" != true ]]; then
      echo "::error::First deployment requires all three services."
      echo "Run a full build with AFFECTED_SERVICES=frontend,rest-api,websocket."
      exit 1
    fi
  done
fi

# Preserve the previous rollback behavior.
rollback() {
  local reason="${1:-deployment health check failed}"

  echo "::error::$reason"

  if (( previous_revision > 0 )); then
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

# Build Helm arguments using the new tag only for affected services.
# For unaffected services, preserve their existing deployed tags.
HELM_ARGS=(
  upgrade --install "$RELEASE" "$CHART_PATH"
  --namespace "$NAMESPACE"
  --values "$VALUES_FILE"
)

for service in frontend rest-api websocket; do
  key="${HELM_KEYS[$service]}"
  repository="${REPOSITORIES[$service]}"

  if [[ "${SELECTED[$service]}" == true ]]; then
    tag="$IMAGE_TAG"
    echo "Updating $service to $repository:$tag"
  else
    repository="$(
      jq -r --arg key "$key" '.[$key].image.repository // empty' \
        "$CURRENT_VALUES"
    )"

    tag="$(
      jq -r --arg key "$key" '.[$key].image.tag // empty' \
        "$CURRENT_VALUES"
    )"

    if [[ -z "$repository" || -z "$tag" ||
          "$repository" == "null" || "$tag" == "null" ]]; then
      echo "::error::Cannot determine the existing image for $service."
      echo "Refusing to change an unaffected service."
      exit 1
    fi

    echo "Preserving $service at $repository:$tag"
  fi

  HELM_ARGS+=(
    --set-string "$key.image.repository=$repository"
    --set-string "$key.image.tag=$tag"
  )
done


HELM_ARGS+=(--wait --timeout 180s)

echo "Deploying $RELEASE."

if ! helm "${HELM_ARGS[@]}"; then
  rollback "Helm upgrade failed for $RELEASE."
fi

# Only wait for rollouts of services whose images changed.
for service in frontend rest-api websocket; do
  if [[ "${SELECTED[$service]}" != true ]]; then
    echo "Skipping rollout check for unchanged service: $service"
    continue
  fi

  kubectl rollout status "deployment/$RELEASE-$service" \
    --namespace "$NAMESPACE" \
    --timeout=45s ||
    rollback "Rollout failed for $RELEASE-$service."
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

# Only smoke-test services included in this deployment.
for service in frontend rest-api websocket; do
  if [[ "${SELECTED[$service]}" != true ]]; then
    echo "Skipping smoke test for unchanged service: $service"
    continue
  fi

  case "$service" in
    frontend)
      smoke_check frontend 18080 80 /health ||
        rollback "Frontend smoke test failed."
      ;;
    rest-api)
      smoke_check rest-api 15000 5000 /api/health ||
        rollback "REST API smoke test failed."
      ;;
    websocket)
      smoke_check websocket 18002 8000 /health ||
        rollback "WebSocket smoke test failed."
      ;;
  esac
done

echo "Deployment succeeded: environment=$ENVIRONMENT release=$RELEASE affected_services=$AFFECTED_SERVICES image_tag=$IMAGE_TAG"