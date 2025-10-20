# Arch Linux Docker Image (amd64 • arm64)

Minimal, multi‑arch Arch Linux base images — fast, reproducible, and tiny.

![Architectures](https://img.shields.io/badge/architectures-amd64%20%E2%80%A2%20arm64-0b74de?logo=docker)
![License](https://img.shields.io/badge/license-MIT-green)

## Highlights

- Multi‑platform: `linux/amd64`, `linux/arm64`
- Small final image (`FROM scratch` export)
- Fast builds with BuildKit cache for apk/pacman
- Strict, container‑friendly pacman defaults

## Pull

GHCR

```bash
docker pull ghcr.io/adyranov/archlinux-docker:latest
```

Docker Hub

```bash
docker pull docker.io/adyranov/archlinux:latest
```

## Build

Use the helper script (multi‑arch by default):

```bash
./scripts/build-containers.sh
```

Examples

```bash
# Single arch (amd64)
PLATFORMS=linux/amd64 ./scripts/build-containers.sh

# Custom tag + cache bust
IMAGE_NAME=ghcr.io/adyranov/archlinux-docker:latest \
CACHE_BUST_ARG=$(date +%s) \
./scripts/build-containers.sh
```

## Run

```bash
docker run --rm -it archlinux-docker:latest bash
```

— See `Dockerfile`, `rootfs/etc/`, and `.github/workflows/build.yaml` for details.
