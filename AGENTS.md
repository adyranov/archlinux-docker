# Repository Guidelines

## General

- Update `AGENTS.md` directly instead of its symlinks (`.clinerules`, `.cursor/rules`, `CLAUDE.md`, `GEMINI.md`, or `.github/copilot-instructions.md`).
- Focus: Building minimal Arch Linux base images for `linux/amd64` and `linux/arm64`.

## Project Structure

- `Dockerfile` — multi-stage build (`alpine` builder → `scratch` configurer → final `scratch` export).
- `rootfs/etc/` — static files copied into the image (e.g., `pacman.conf`, `locale.conf`, `locale.gen`). Add configuration here rather than inline echoes.
- `scripts/build-container.sh` — primary test tool for agents and multi-architecture local build script.
- `.github/workflows/build.yaml` — GitHub Actions workflow for building and publishing.

## Build & Test

- **Disk Space**: `CheckSpace` must be disabled in `rootfs/etc/pacman.conf` to prevent `pacman` from failing due to incorrect disk space reporting in some Docker/emulation environments.

```bash
# Default build (linux/amd64)
./scripts/build-container.sh

# Target specific architecture
./scripts/build-container.sh --platform linux/arm64

# Custom tag & cache bust
./scripts/build-container.sh --tag ghcr.io/adyranov/archlinux-docker:latest --cache-bust $(date +%s)
```

## Coding Style

- **Dockerfile**: Group commands logically. Use `RUN <<EOF` (heredocs) for multi-line scripts. Reference `CACHE_BUST` for deterministic rebuilding.
- **Shell scripts**: `UPPER_SNAKE_CASE` for environment variables, `lower_snake_case` for locals.
