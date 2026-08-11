#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
container_name="pixel-scribe-backend-health-smoke-$$"
temporary_tag_directory=""
remove_image=false

if [ -n "${PIXEL_SCRIBE_SMOKE_IMAGE:-}" ]; then
  image_name="$PIXEL_SCRIBE_SMOKE_IMAGE"
else
  temporary_tag_directory=$(mktemp -d)
  image_name="pixel-scribe-backend-health-smoke:$(basename "$temporary_tag_directory")"
  remove_image=true
fi

cleanup() {
  docker rm --force "$container_name" >/dev/null 2>&1 || true
  if [ "$remove_image" = true ]; then
    docker image rm --force "$image_name" >/dev/null 2>&1 || true
  fi
  if [ -n "$temporary_tag_directory" ]; then
    rmdir "$temporary_tag_directory" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

printf 'Building production image %s\n' "$image_name"
docker build --tag "$image_name" "$repo_root"

printf 'Starting production container %s\n' "$container_name"
docker run --detach \
  --name "$container_name" \
  --publish 127.0.0.1::80 \
  --env ENVIRONMENT=production \
  --env SECRET_KEY_BASE=container-health-smoke-key-012345678901234567890123456789012345678901234567890123 \
  "$image_name" >/dev/null

published_port=$(docker port "$container_name" 80/tcp | sed -n 's/.*:\([0-9][0-9]*\)$/\1/p')
if [ -z "$published_port" ]; then
  printf 'container_health_smoke: could not determine published port\n' >&2
  docker logs "$container_name" >&2 || true
  exit 1
fi

health_url="http://127.0.0.1:$published_port/healthz"
for _ in $(seq 1 40); do
  if curl --fail --silent "$health_url" >/dev/null 2>&1; then
    printf 'Production health check passed: %s\n' "$health_url"
    exit 0
  fi
  sleep 0.25
done

printf 'container_health_smoke: health check failed: %s\n' "$health_url" >&2
docker logs "$container_name" >&2 || true
exit 1
