# syntax=docker/dockerfile:1.4
FROM alpine:3.17 AS builder

RUN apk add arch-install-scripts pacman-makepkg curl zstd

WORKDIR /buildroot

SHELL ["/bin/bash", "-c"]

COPY rootfs /

RUN mkdir -p /etc/pacman.d && \
    cat /etc/pacman-conf.d-noextract.conf >> /etc/pacman.conf

RUN [[ "$(uname -m)" == "aarch64" ]] || exit 0 && \
    curl -L https://github.com/archlinuxarm/archlinuxarm-keyring/archive/refs/heads/master.zip | unzip -d /tmp/archlinuxarm-keyring - && \
    mkdir /usr/share/pacman/keyrings && \
    mv /tmp/archlinuxarm-keyring/*/archlinuxarm* /usr/share/pacman/keyrings/ && \
    echo 'Server = http://mirror.archlinuxarm.org/$arch/$repo' > /etc/pacman.d/mirrorlist

RUN [[ "$(uname -m)" == "x86_64" ]] || exit 0 && \
    mkdir /tmp/archlinux-keyring && \
    curl -L https://archlinux.org/packages/core/any/archlinux-keyring/download | unzstd | tar -C /tmp/archlinux-keyring -xv && \
    mv /tmp/archlinux-keyring/usr/share/pacman/keyrings /usr/share/pacman/ && \
    echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' > /etc/pacman.d/mirrorlist

RUN pacman-key --init && pacman-key --populate

RUN mkdir -m 0755 -p /buildroot/var/{cache/pacman/pkg,lib/pacman,log} /buildroot/{dev,run,etc} && \
    mkdir -m 1777 -p /buildroot/tmp && \
    mkdir -m 0555 -p /buildroot/{sys,proc} && \
    mknod /buildroot/dev/null c 1 3 && \
    pacman -r /buildroot -Sy --noconfirm base && \
    rm /buildroot/dev/null && \
    rm /buildroot/var/lib/pacman/sync/*

RUN cat /etc/pacman-conf.d-noextract.conf >> /buildroot/etc/pacman.conf && \
    cp /etc/pacman.d/mirrorlist /buildroot/etc/pacman.d/mirrorlist && \
    cp /usr/share/pacman/keyrings/* /buildroot/usr/share/pacman/keyrings/

FROM scratch as configurer

COPY --from=builder /buildroot/ /

SHELL ["/bin/bash", "-c"]

RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Sy --noconfirm --needed --overwrite "*" archlinux-keyring

RUN [[ "$(uname -m)" == "aarch64" ]] || exit 0 && \
    pacman-key --populate archlinuxarm && \
    pacman -Sy --noconfirm --needed --overwrite "*" archlinuxarm-keyring

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
	echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    locale-gen

RUN pacman -Qeq |  grep -q ^ && pacman -D --asdeps $(pacman -Qeq) || echo "nothing to set as dependency"

RUN pacman -S --asexplicit --needed --noconfirm base lsb-release pacman

RUN pacman -Qtdq | grep -v base && pacman -Rsunc --noconfirm  $(pacman -Qtdq | grep -v base) systemd || echo "nothing to remove"

RUN rm -rf etc/pacman.d/gnupg/{openpgp-revocs.d/,private-keys-v1.d/,pubring.gpg~,gnupg.S.}*

RUN rm -f /var/cache/pacman/pkg/* /var/lib/pacman/sync/*

FROM scratch as base

COPY --from=configurer / /

CMD /bin/bash

FROM base as base-devel

RUN pacman -Sy --noconfirm --needed base-devel && \
    rm -f /var/cache/pacman/pkg/* /var/lib/pacman/sync/*
