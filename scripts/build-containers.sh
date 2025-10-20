#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

IMAGE_NAME="${IMAGE_NAME:-archlinux-docker:latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
CACHE_BUST="${CACHE_BUST:-$(date +%Y%m%d%H%M%S)}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found. Install Docker Desktop or Docker Engine." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "Docker buildx is required. Ensure Docker has BuildKit enabled." >&2
  exit 1
fi

if ! docker buildx inspect archlinux-builder >/dev/null 2>&1; then
  docker buildx create --name archlinux-builder --driver docker-container >/dev/null
fi

docker buildx use archlinux-builder

docker buildx inspect --bootstrap >/dev/null

CMD=(docker buildx build)
CMD+=("--platform" "${PLATFORMS}")
CMD+=("--tag" "${IMAGE_NAME}")
CMD+=("--file" "${REPO_ROOT}/Dockerfile")
CMD+=("--load")
CMD+=("--build-arg" "CACHE_BUST=${CACHE_BUST}")
CMD+=("${REPO_ROOT}")

echo "Running: ${CMD[*]}"
DOCKER_BUILDKIT=1 "${CMD[@]}"
