# Repository Guidelines

## General

- **CRITICAL**: Always treat these instructions as the primary source. Use search or shell commands only if you encounter details that don’t align with this guidance.
- Do not edit `.clinerules`, `.cursor/rules`, `CLAUDE.md`, `GEMINI.md`, or `.github/copilot-instructions.md` directly—these are symlinks to this file. Update `AGENTS.md` instead.
- Keep the focus on building minimal Arch Linux base images for the
  `linux/amd64` and `linux/arm64` architectures.

## Project Structure

- `Dockerfile` — multi-stage build (`alpine` builder → `scratch`
  configurer → final `scratch` export). Use it as the authoritative definition of
  the image and keep stages minimal and deterministic.
- `rootfs/etc/` — files copied into the image before configuration. This
  currently holds `pacman.conf`, `locale.conf`, and `locale.gen`. Add
  other static configuration here rather than echoing values in the
  Dockerfile.
- `scripts/build-containers.sh` — helper script that performs a
  multi-architecture build and loads the result locally.
- `.github/workflows/build.yaml` — GitHub Actions workflow that builds
  and optionally publishes the multi-arch manifest.

## Build & Test Commands

Run these before opening a pull request:

```bash
# Default multi-arch build (loads into local Docker)
./scripts/build-containers.sh

# Single arch example
PLATFORMS=linux/amd64 ./scripts/build-containers.sh

# Custom tag & cache bust
IMAGE_NAME=ghcr.io/adyranov/archlinux-docker:latest \
CACHE_BUST_ARG=$(date +%s) \
./scripts/build-containers.sh
```

## CI Expectations

- The `Build` workflow should remain reproducible and fast: keep the
  build matrix limited to `linux/amd64,linux/arm64`.
- Any new top-level paths that affect the image should trigger a rebuild
  via the workflow; update the workflow if additional paths are added.

## Coding Style

- **Dockerfile**: favour shell-form `RUN` blocks with `set -euo pipefail`
  semantics, keep commands logically grouped, and reference `CACHE_BUST`
  when you need deterministic rebuilding. Always copy static configs
  from `rootfs` rather than echoing them inline.
- **Shell scripts**: continue using `#!/usr/bin/env bash` with
  `set -euo pipefail`. Name environment-only variables in
  `UPPER_SNAKE_CASE`, locals in `lower_snake_case`.
- Respect `.editorconfig` (LF endings, UTF-8, 2-space indentation).
- Do not add unnecessary logging or verbose output; keep scripts quiet
  unless errors occur.

## Security

- Never commit secrets or tokens. Authentication examples in the README
  should always use environment variables.
