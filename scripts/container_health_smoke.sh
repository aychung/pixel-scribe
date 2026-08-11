#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
container_name="pixel-scribe-backend-health-smoke-$$"
temporary_tag_directory=$(mktemp -d)
remove_image=false

index_body="$temporary_tag_directory/index.html"
index_headers="$temporary_tag_directory/index.headers"
styles_body="$temporary_tag_directory/styles.css"
styles_headers="$temporary_tag_directory/styles.headers"
bundle_body="$temporary_tag_directory/pixel_scribe_frontend.js"
bundle_headers="$temporary_tag_directory/pixel_scribe_frontend.headers"

if [ -n "${PIXEL_SCRIBE_SMOKE_IMAGE:-}" ]; then
  image_name="$PIXEL_SCRIBE_SMOKE_IMAGE"
else
  image_name="pixel-scribe-backend-health-smoke:$(basename "$temporary_tag_directory")"
  remove_image=true
fi

cleanup() {
  docker rm --force "$container_name" >/dev/null 2>&1 || true
  if [ "$remove_image" = true ]; then
    docker image rm --force "$image_name" >/dev/null 2>&1 || true
  fi
  rm -f \
    "$index_body" \
    "$index_headers" \
    "$styles_body" \
    "$styles_headers" \
    "$bundle_body" \
    "$bundle_headers"
  rmdir "$temporary_tag_directory" >/dev/null 2>&1 || true
}
trap cleanup EXIT

smoke_failure() {
  printf 'container_health_smoke: %s\n' "$1" >&2
  docker logs "$container_name" >&2 || true
  exit 1
}

printf 'Building production image %s\n' "$image_name"
docker build --tag "$image_name" "$repo_root"

printf 'Starting production container %s\n' "$container_name"
docker run --detach \
  --name "$container_name" \
  --publish 127.0.0.1::80 \
  --env ENVIRONMENT=production \
  "$image_name" >/dev/null

published_port=$(docker port "$container_name" 80/tcp | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p')
if [ -z "$published_port" ]; then
  printf 'container_health_smoke: could not determine published port\n' >&2
  docker logs "$container_name" >&2 || true
  exit 1
fi

health_url="http://127.0.0.1:$published_port/healthz"
health_ready=false
for _ in $(seq 1 40); do
  if curl --fail --silent "$health_url" >/dev/null 2>&1; then
    health_ready=true
    break
  fi
  sleep 0.25
done

if [ "$health_ready" != true ]; then
  smoke_failure "health check failed: $health_url"
fi

printf 'Production health check passed: %s\n' "$health_url"

check_generated_artifact() {
  local endpoint="$1"
  local expected_content_type="$2"
  local marker="$3"
  local response_body="$4"
  local response_headers="$5"
  local status_code
  local content_type

  if ! curl \
    --fail \
    --silent \
    --show-error \
    --dump-header "$response_headers" \
    --output "$response_body" \
    "http://127.0.0.1:$published_port$endpoint"; then
    smoke_failure "generated artifact request failed: $endpoint"
  fi

  status_code=$(awk '$1 ~ /^HTTP\// { code=$2 } END { print code }' "$response_headers")
  case "$status_code" in
    2[0-9][0-9]) ;;
    *) smoke_failure "generated artifact returned HTTP $status_code: $endpoint" ;;
  esac

  content_type=$(awk -F: 'tolower($1) == "content-type" {
    sub(/^[[:space:]]*/, "", $2)
    sub(/\r$/, "", $2)
    print $2
    exit
  }' "$response_headers")
  if [ "$content_type" != "$expected_content_type" ]; then
    smoke_failure "generated artifact content type mismatch for $endpoint: expected $expected_content_type, got ${content_type:-<missing>}"
  fi

  if ! grep --fixed-strings --quiet -- "$marker" "$response_body"; then
    smoke_failure "generated artifact marker missing for $endpoint: $marker"
  fi
}

check_generated_artifact \
  "/" \
  "text/html; charset=utf-8" \
  "<title>Pixel Scribe</title>" \
  "$index_body" \
  "$index_headers"
check_generated_artifact \
  "/styles.css" \
  "text/css; charset=utf-8" \
  "--chat-rail-width" \
  "$styles_body" \
  "$styles_headers"
check_generated_artifact \
  "/pixel_scribe_frontend.js" \
  "text/javascript; charset=utf-8" \
  "Pixel Scribe" \
  "$bundle_body" \
  "$bundle_headers"

printf 'Production generated-artifact checks passed: /, /styles.css, /pixel_scribe_frontend.js\n'
