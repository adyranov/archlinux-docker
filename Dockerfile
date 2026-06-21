# syntax=docker/dockerfile:1.25.0
ARG CACHE_BUST=1

FROM --platform=$BUILDPLATFORM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS bootstrap
ARG CACHE_BUST
ARG TARGETARCH

RUN --mount=type=cache,id=apk-cache,target=/var/cache/apk \
    set -eu; \
    : "${CACHE_BUST}"; \
    apk add bash curl pacman zstd

SHELL ["/bin/bash", "-c"]

COPY rootfs /

RUN <<EOF
set -euo pipefail

buildroot=/buildroot
gpg_dir=/etc/pacman.d/gnupg
mirrorlist=/etc/pacman.d/mirrorlist
pacman_cache=/var/cache/pacman/pkg
keyrings=/usr/share/pacman/keyrings
target_arch="${TARGETARCH:-$(uname -m)}"

install -d /etc/pacman.d "${keyrings}"

case "${target_arch}" in
  arm64|aarch64)
    pacman_arch=aarch64
    keyring_package=archlinuxarm-keyring

    install -d /tmp/archlinuxarm-keyring
    curl -fsSL https://github.com/archlinuxarm/archlinuxarm-keyring/archive/refs/heads/master.tar.gz \
      | tar -C /tmp/archlinuxarm-keyring --strip-components=1 -xz
    mv /tmp/archlinuxarm-keyring/archlinuxarm* "${keyrings}/"
    printf '%s\n' \
      'SigLevel = Required DatabaseNever' \
      'Server = http://mirror.archlinuxarm.org/$arch/$repo' \
      > "${mirrorlist}"
    ;;
  amd64|x86_64)
    pacman_arch=x86_64
    keyring_package=archlinux-keyring

    install -d /tmp/archlinux-keyring
    curl -fsSL https://archlinux.org/packages/core/any/archlinux-keyring/download \
      | unzstd | tar -C /tmp/archlinux-keyring -x
    mv /tmp/archlinux-keyring/usr/share/pacman/keyrings/* "${keyrings}/"
    printf '%s\n' 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > "${mirrorlist}"
    ;;
  *)
    echo "unsupported architecture: ${target_arch}" >&2
    exit 1
    ;;
esac

install -d -m 0700 "${gpg_dir}"
pacman-key --init
pacman-key --populate

mkdir -m 0755 -p \
  "${pacman_cache}" \
  "${buildroot}"/var/{cache/pacman/pkg,lib/pacman,log} \
  "${buildroot}"/{dev,run,etc}
mkdir -m 1777 -p "${buildroot}/tmp"
mkdir -m 0555 -p "${buildroot}/sys" "${buildroot}/proc"
mknod "${buildroot}/dev/null" c 1 3

pacman \
  --config /etc/pacman.conf \
  --arch "${pacman_arch}" \
  -r "${buildroot}" \
  --gpgdir "${gpg_dir}" \
  --disable-sandbox \
  --cachedir "${pacman_cache}" \
  --cachedir "${buildroot}/var/cache/pacman/pkg" \
  -Sy --needed --noconfirm base "${keyring_package}"

rm -f "${buildroot}/dev/null" "${buildroot}/var/lib/pacman/sync/"*
cp /etc/pacman.conf "${buildroot}/etc/pacman.conf"
cp "${mirrorlist}" "${buildroot}/etc/pacman.d/mirrorlist"
EOF

FROM scratch AS configure

COPY --from=bootstrap /buildroot/ /
COPY rootfs /

SHELL ["/bin/bash", "-c"]

RUN <<EOF
set -euo pipefail

install -d -m 0700 /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate

locale-gen

mapfile -t explicit_packages < <(pacman -Qeq)
if ((${#explicit_packages[@]})); then
  pacman -D --asdeps "${explicit_packages[@]}"
fi

mapfile -t keyring_packages < <(pacman -Qq | grep -E '^(archlinux|archlinuxarm)-keyring$' || true)
pacman --disable-sandbox -Sy --asexplicit --needed --noconfirm \
  base pacman "${keyring_packages[@]}"

mapfile -t removable_packages < <(pacman -Qtdq | grep -Ev '^(base|pacman|archlinux-keyring|archlinuxarm-keyring)$' || true)
if ((${#removable_packages[@]})); then
  pacman -Rns --noconfirm "${removable_packages[@]}"
fi

rm -rf /etc/pacman.d/gnupg/{openpgp-revocs.d,private-keys-v1.d,pubring.gpg~,S.gpg-agent}*
rm -f /var/cache/pacman/pkg/* /var/lib/pacman/sync/* /var/log/pacman.log
EOF

FROM scratch

LABEL org.opencontainers.image.title="Arch Linux" \
      org.opencontainers.image.description="Minimal multi-arch Arch Linux base image" \
      org.opencontainers.image.authors="Artem Dyranov" \
      org.opencontainers.image.source="https://github.com/adyranov/archlinux-docker" \
      org.opencontainers.image.licenses="MIT"

COPY --from=configure / /

CMD ["/bin/bash"]
