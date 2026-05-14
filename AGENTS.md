# Repository Guidelines

## General

- Update `AGENTS.md` directly instead of its symlinks (`.clinerules`, `.cursor/rules`, `CLAUDE.md`, `GEMINI.md`, or `.github/copilot-instructions.md`).
- Focus: Building minimal Arch Linux base images for `linux/amd64` and `linux/arm64`.

## Project Structure

- `Dockerfile` — multi-stage build (`alpine` builder → `scratch` configurer → final `scratch` export).
- `rootfs/etc/` — static files copied into the image (e.g., `pacman.conf`, `locale.conf`, `locale.gen`). Add configuration here rather than inline echoes.
- `scripts/build-containers.sh` — multi-architecture local build script.
- `.github/workflows/build.yaml` — GitHub Actions workflow for building and publishing.

## Build & Test

```bash
# Default multi-arch build
./scripts/build-containers.sh

# Single arch
PLATFORMS=linux/amd64 ./scripts/build-containers.sh

# Custom tag & cache bust
IMAGE_NAME=ghcr.io/adyranov/archlinux-docker:latest CACHE_BUST=$(date +%s) ./scripts/build-containers.sh
```

## Coding Style

- **Dockerfile**: Group commands logically. Use `RUN <<EOF` (heredocs) for multi-line scripts. Reference `CACHE_BUST` for deterministic rebuilding.
- **Shell scripts**: `UPPER_SNAKE_CASE` for environment variables, `lower_snake_case` for locals.
