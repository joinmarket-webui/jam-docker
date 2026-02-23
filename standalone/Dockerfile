
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG JM_SERVER_REPO=https://github.com/JoinMarket-Org/joinmarket-clientserver
ARG JM_SERVER_REPO_REF=master

ARG SKIP_RELEASE_VERIFICATION=false

ARG NODE_IMAGE_VERSION=22.14.0
ARG NODE_IMAGE_HASH=9bef0ef1e268f60627da9ba7d7605e8831d5b56ad07487d24d1aa386336d1944
ARG NODE_IMAGE=node:${NODE_IMAGE_VERSION}-alpine3.21@sha256:${NODE_IMAGE_HASH}
ARG ALPINE_IMAGE_VERSION=3.21.2
ARG ALPINE_IMAGE_HASH=56fa17d2a7e7f168a043a2712e63aed1f8543aeafdcee47c58dcffe38ed51099
ARG ALPINE_IMAGE=alpine:${ALPINE_IMAGE_VERSION}@sha256:${ALPINE_IMAGE_HASH}
ARG DEBIAN_IMAGE_VERSION=bookworm-20250428-slim
ARG DEBIAN_IMAGE_HASH=4b50eb66f977b4062683ff434ef18ac191da862dbe966961bc11990cf5791a8d
ARG DEBIAN_IMAGE=debian:${DEBIAN_IMAGE_VERSION}@sha256:${DEBIAN_IMAGE_HASH}
ARG DINIT_IMAGE_VERSION=0.20.0
ARG DINIT_IMAGE_HASH=5352e5896eaf2380a2671b9be8fbfb70b9f3e015e3d0f883aa58eee7f0426d9b
ARG DINIT_IMAGE=ghcr.io/joinmarket-webui/jam-contrib-dinit:${DINIT_IMAGE_VERSION}@sha256:${DINIT_IMAGE_HASH}

FROM ${NODE_IMAGE} AS node

# --- Builder base 
FROM ${ALPINE_IMAGE} AS builder-base
RUN apk add --no-cache --update git gnupg
# --- Builder base - end

# --- UI builder 
FROM builder-base AS ui-builder
ARG SKIP_RELEASE_VERIFICATION
ARG JAM_REPO
ARG JAM_REPO_REF

COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

WORKDIR /usr/src/jam

COPY pubkeys/ /pubkeys

# checkout and build project
RUN git clone "$JAM_REPO" . --depth=1 --branch "$JAM_REPO_REF" \
    && (if [ "$SKIP_RELEASE_VERIFICATION" != "true" ]; then \
        find /pubkeys -iname '*.asc' -exec gpg --import "{}" \; \
        && git verify-tag "$JAM_REPO_REF"; \
    fi) \
    && npm clean-install --no-fund --no-audit \
    && npm run build
# --- UI builder - end

FROM ${DINIT_IMAGE} AS dinit

# --- SERVER builder
FROM builder-base AS server-builder
ARG SKIP_RELEASE_VERIFICATION
ARG JM_SERVER_REPO
ARG JM_SERVER_REPO_REF

WORKDIR /usr/src/joinmarket-clientserver

COPY pubkeys/ /pubkeys

RUN git clone "$JM_SERVER_REPO" . --depth=1 --branch "$JM_SERVER_REPO_REF" \
    && (if [ "$SKIP_RELEASE_VERIFICATION" != "true" ]; then \
        find /pubkeys -iname '*.asc' -exec gpg --import "{}" \; \
        && git verify-tag "$JM_SERVER_REPO_REF"; \
    fi)
# --- SERVER builder - end

# --- RUNTIME builder
FROM ${DEBIAN_IMAGE}
ARG MAINTAINER
ARG JM_SERVER_REPO_REF
ARG JAM_REPO_REF

# package version arguments (can be overridden at build time)
ARG GNUPG_VERSION=2.2.40-1.1+deb12u2
ARG CURL_VERSION=7.88.1-10+deb12u14
ARG APT_TRANSPORT_HTTPS_VERSION=2.6.1
ARG CA_CERTIFICATES_VERSION=20230311+deb12u1
ARG TINI_VERSION=0.19.0-1+b3
ARG IPROUTE2_VERSION=6.1.0-3
ARG PROCPS_VERSION=2:4.0.2-3
ARG VIM_VERSION=2:9.0.1378-2+deb12u2
ARG JQ_VERSION=1.6-2.1+deb12u1
ARG BUILD_ESSENTIAL_VERSION=12.9
ARG AUTOMAKE_VERSION=1:1.16.5-1.3
ARG AUTOCONF_VERSION=2.71-3
ARG PKG_CONFIG_VERSION=1.8.1-1
ARG LIBTOOL_VERSION=2.4.7-7~deb12u1
ARG PYTHON3_DEV_VERSION=3.11.2-1+b1
ARG PYTHON3_PIP_VERSION=23.0.1+dfsg-1
ARG PYTHON3_SETUPTOOLS_VERSION=66.1.1-1+deb12u2
ARG PYTHON3_VENV_VERSION=3.11.2-1+b1
ARG LIBLTDL_DEV_VERSION=2.4.7-7~deb12u1
ARG TOR_VERSION=0.4.9.5-1~d12.bookworm+1
ARG DEB_TOR_KEYRING_VERSION=2025.08.08
ARG NGINX_VERSION=1.28.2-1~bookworm

LABEL maintainer="$MAINTAINER"
LABEL ui-version="$JAM_REPO_REF"
LABEL server-version="$JM_SERVER_REPO_REF"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=dinit /out/usr/bin /usr/bin
COPY --from=ui-builder /usr/src/jam/build /app
COPY --from=server-builder /usr/src/joinmarket-clientserver /src

RUN addgroup --system tor \
    && adduser --system --disabled-login --home /home/tor --ingroup tor --gecos 'tor user' tor \
    && apt-get update \
    && apt-get install --quiet --no-install-recommends --no-install-suggests --yes \
    gnupg=${GNUPG_VERSION} \
    curl=${CURL_VERSION} \
    apt-transport-https=${APT_TRANSPORT_HTTPS_VERSION} \
    ca-certificates=${CA_CERTIFICATES_VERSION} \
    # add nginx debian repo
    && curl --silent https://nginx.org/keys/nginx_signing.key | \
    gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null \
    && sh -c "echo 'deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian bookworm nginx' > /etc/apt/sources.list.d/nginx.list" \
    && echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | tee /etc/apt/preferences.d/99nginx > /dev/null \
    # add tor debian repo
    && curl --silent https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | \
    gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg > /dev/null \
    && sh -c "echo 'deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org bookworm main' > /etc/apt/sources.list.d/tor.list" \
    # install dependencies (versions pinned for reproducible builds)
    && apt-get update \
    && apt-get install --quiet --no-install-recommends --no-install-suggests --yes \
    # image dependencies
    tini=${TINI_VERSION} \
    iproute2=${IPROUTE2_VERSION} \
    procps=${PROCPS_VERSION} \
    vim=${VIM_VERSION} \
    jq=${JQ_VERSION} \
    # servers dependencies (see `install.sh`)
    build-essential=${BUILD_ESSENTIAL_VERSION} \
    automake=${AUTOMAKE_VERSION} \
    autoconf=${AUTOCONF_VERSION} \
    pkg-config=${PKG_CONFIG_VERSION} \
    libtool=${LIBTOOL_VERSION} \
    python3-dev=${PYTHON3_DEV_VERSION} \
    python3-pip=${PYTHON3_PIP_VERSION} \
    python3-setuptools=${PYTHON3_SETUPTOOLS_VERSION} \
    python3-venv=${PYTHON3_VENV_VERSION} \
    libltdl-dev=${LIBLTDL_DEV_VERSION} \
    # tor (from torproject.org repo)
    tor=${TOR_VERSION} \
    deb.torproject.org-keyring=${DEB_TOR_KEYRING_VERSION} \
    # ui dependencies (from nginx.org repo)
    nginx=${NGINX_VERSION} \
    # cleanup 
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/*

ENV DATADIR=/root/.joinmarket
ENV CONFIG=${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG=/root/default.cfg
ENV PATH=/src/scripts:$PATH

WORKDIR /src

# workaround: adjust libsodium download URL in install.sh for legacy 1.0.18 releases
# TODO: remove this once v0.9.11 is no longer supported and new releases are available
RUN set -eux \
    && if grep --quiet "sodium_version='libsodium-1.0.18'" install.sh; then \
         sed --in-place "s#sodium_url='https://download.libsodium.org/libsodium/releases'#sodium_url='https://download.libsodium.org/libsodium/releases/old'#g" install.sh; \
       fi

# compile and install JoinMarket
RUN pip3 config set global.break-system-packages true \
    && ./install.sh --docker-install --without-qt \
    && rm --recursive --force install.sh deps/cache/ test/ .git/ .gitignore .github/ .coveragerc joinmarket-qt.desktop

# cleanup and remove ephemeral dependencies
RUN apt-get remove --purge --auto-remove --yes gnupg python3-pip apt-transport-https \
    && rm --force /var/log/dpkg.log

COPY default.cfg "${DEFAULT_CONFIG}"
COPY dinit-conf/* /etc/dinit.d/
COPY .bashrc /root/.bashrc
COPY --chown=tor:tor torrc /etc/tor/torrc

COPY nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

COPY --chmod=0755 jam-entrypoint.sh /

# ensure log directory exists (dinit files depend on it)
RUN mkdir --parents /var/log/jam

# nginx default port
EXPOSE 80

WORKDIR /src/scripts

ENTRYPOINT  [ "tini", "-g", "--", "/jam-entrypoint.sh" ]
