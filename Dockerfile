# syntax=docker/dockerfile:1.24.0
ARG CACHE_BUST=1
FROM alpine:3.19@sha256:6baf43584bcb78f2e5847d1de515f23499913ac9f12bdf834811a3145eb11ca1 AS builder
ARG CACHE_BUST

RUN --mount=type=cache,id=apk-cache,target=/var/cache/apk \
    set -eu; \
    : "${CACHE_BUST}"; \
    apk add arch-install-scripts curl pacman-makepkg zstd

WORKDIR /buildroot

SHELL ["/bin/bash", "-c"]

COPY rootfs /

RUN <<EOF
  set -euo pipefail
  mkdir -p /etc/pacman.d /usr/share/pacman/keyrings
  arch="$(uname -m)"
  if [ "${arch}" = "aarch64" ]; then
    curl -fsSL https://github.com/archlinuxarm/archlinuxarm-keyring/archive/refs/heads/master.zip \
      | unzip -d /tmp/archlinuxarm-keyring -
    mv /tmp/archlinuxarm-keyring/*/archlinuxarm* /usr/share/pacman/keyrings/
    echo 'Server = http://mirror.archlinuxarm.org/$arch/$repo' > /etc/pacman.d/mirrorlist
  elif [ "${arch}" = "x86_64" ]; then
    mkdir /tmp/archlinux-keyring
    curl -fsSL https://archlinux.org/packages/core/any/archlinux-keyring/download \
      | unzstd | tar -C /tmp/archlinux-keyring -xv
    mv /tmp/archlinux-keyring/usr/share/pacman/keyrings/* /usr/share/pacman/keyrings/
    echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist
  fi
  rm -rf /etc/pacman.d/gnupg && mkdir -p /etc/pacman.d/gnupg
  echo "allow-weak-key-signatures" >> /etc/pacman.d/gnupg/gpg.conf
  pacman-key --init
  pacman-key --populate
EOF

RUN --mount=type=cache,id=pacman-pkg,target=/var/cache/pacman/pkg,sharing=locked <<EOF
  set -euo pipefail
  mkdir -m 0755 -p /buildroot/var/{cache/pacman/pkg,lib/pacman,log} /buildroot/{dev,run,etc}
  mkdir -m 1777 -p /buildroot/tmp
  mkdir -m 0555 -p /buildroot/{sys,proc}
  mknod /buildroot/dev/null c 1 3
  pacman -r /buildroot --cachedir /var/cache/pacman/pkg --cachedir /buildroot/var/cache/pacman/pkg \
    -Sy --noconfirm base
  arch="$(uname -m)"
  if [ "${arch}" = "aarch64" ]; then
    pacman -r /buildroot --cachedir /var/cache/pacman/pkg --cachedir /buildroot/var/cache/pacman/pkg \
      -Sy --noconfirm archlinuxarm-keyring
  elif [ "${arch}" = "x86_64" ]; then
    pacman -r /buildroot --cachedir /var/cache/pacman/pkg --cachedir /buildroot/var/cache/pacman/pkg \
      -Sy --noconfirm archlinux-keyring
  fi
  rm /buildroot/dev/null
  rm /buildroot/var/lib/pacman/sync/*
  cp /etc/pacman.conf /buildroot/etc/pacman.conf
  cp /etc/pacman.d/mirrorlist /buildroot/etc/pacman.d/mirrorlist
EOF

FROM scratch AS configurer

COPY --from=builder /buildroot/ /
COPY rootfs /

SHELL ["/bin/bash", "-c"]

RUN <<EOF
  set -euo pipefail
  rm -rf /etc/pacman.d/gnupg && mkdir -p /etc/pacman.d/gnupg
  echo "allow-weak-key-signatures" >> /etc/pacman.d/gnupg/gpg.conf
  pacman-key --init
  pacman-key --populate
  locale-gen
  pacman -Qeq | grep -q ^ && pacman -D --asdeps $(pacman -Qeq) || echo "nothing to set as dependency"
  pacman -Sy --asexplicit --needed --noconfirm base pacman
  pacman -Qtdq | grep -v base && pacman -Rsunc --noconfirm $(pacman -Qtdq | grep -v base) systemd || echo "nothing to remove"
  rm -rf etc/pacman.d/gnupg/{openpgp-revocs.d/,private-keys-v1.d/,pubring.gpg~,gnupg.S.}*
  rm -f /var/cache/pacman/pkg/* /var/lib/pacman/sync/* /var/log/pacman.log
EOF

FROM scratch

LABEL org.opencontainers.image.title="Arch Linux" \
      org.opencontainers.image.description="Minimal multi-arch Arch Linux base image" \
      org.opencontainers.image.authors="Artem Dyranov" \
      org.opencontainers.image.source="https://github.com/adyranov/archlinux-docker" \
      org.opencontainers.image.licenses="MIT"

COPY --from=configurer / /

CMD ["/bin/bash"]
