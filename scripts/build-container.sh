#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Defaults
IMAGE_NAME="archlinux-docker:latest"
PLATFORM="linux/amd64"
CACHE_BUST="$(date +%Y%m%d%H%M%S)"
DOCKERFILE="${REPO_ROOT}/Dockerfile"
NO_CACHE=false

function print_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Primary build and test tool for Arch Linux Docker images."
  echo ""
  echo "Options:"
  echo "  -t, --tag <name>        Image tag (default: archlinux-docker:latest)"
  echo "  -p, --platform <name>   Target platform (default: linux/amd64)"
  echo "  -c, --cache-bust <val>  Cache bust argument (default: current timestamp)"
  echo "  -f, --file <path>       Path to Dockerfile (default: ./Dockerfile)"
  echo "  --no-cache              Build without using any cache"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --platform linux/amd64"
  echo "  $0 -t my-arch-image:test -p linux/arm64"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--tag)
      IMAGE_NAME="$2"
      shift 2
      ;;
    -p|--platform)
      PLATFORM="$2"
      shift 2
      ;;
    -c|--cache-bust)
      CACHE_BUST="$2"
      shift 2
      ;;
    -f|--file)
      DOCKERFILE="$2"
      shift 2
      ;;
    --no-cache)
      NO_CACHE=true
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found. Install Docker Desktop or Docker Engine." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "Docker buildx is required. Ensure Docker has BuildKit enabled." >&2
  exit 1
fi

# Ensure builder exists
if ! docker buildx inspect archlinux-builder >/dev/null 2>&1; then
  docker buildx create --name archlinux-builder --driver docker-container >/dev/null
fi
docker buildx use archlinux-builder
docker buildx inspect --bootstrap >/dev/null

CMD=(docker buildx build)
CMD+=("--platform" "${PLATFORM}")
CMD+=("--tag" "${IMAGE_NAME}")
CMD+=("--file" "${DOCKERFILE}")
CMD+=("--build-arg" "CACHE_BUST=${CACHE_BUST}")

if [ "${NO_CACHE}" = "true" ]; then
  CMD+=("--no-cache")
fi

CMD+=("--load")

CMD+=("${REPO_ROOT}")

echo "Running: ${CMD[*]}"
DOCKER_BUILDKIT=1 "${CMD[@]}"
