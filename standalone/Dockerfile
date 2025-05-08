
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
ARG DEBIAN_IMAGE_VERSION=bookworm-20250224-slim
ARG DEBIAN_IMAGE_HASH=12c396bd585df7ec21d5679bb6a83d4878bc4415ce926c9e5ea6426d23c60bdc
ARG DEBIAN_IMAGE=debian:${DEBIAN_IMAGE_VERSION}@sha256:${DEBIAN_IMAGE_HASH}

ARG DINIT_IMAGE_VERSION=0.19.3
ARG DINIT_IMAGE_HASH=632163119c6cd10e825b3fa60d6bcee11c99828a8f430dec02c85b484b9b11dc
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
    && npm install --no-fund --no-audit \
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

LABEL maintainer="$MAINTAINER"
LABEL ui-version="$JAM_REPO_REF"
LABEL server-version="$JM_SERVER_REPO_REF"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=dinit /out /sbin
COPY --from=ui-builder /usr/src/jam/build /app
COPY --from=server-builder /usr/src/joinmarket-clientserver /src

RUN addgroup --system tor \
    && adduser --system --disabled-login --home /home/tor --ingroup tor --gecos 'tor user' tor \
    && apt-get update \
    && apt-get install --quiet --no-install-recommends --no-install-suggests --yes gnupg curl apt-transport-https ca-certificates \
    # add nginx debian repo
    && curl --silent https://nginx.org/keys/nginx_signing.key | \
    gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null \
    && sh -c "echo 'deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian bookworm nginx' > /etc/apt/sources.list.d/nginx.list" \
    # add tor debian repo
    && curl --silent https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | \
    gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg > /dev/null \
    && sh -c "echo 'deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org bookworm main' > /etc/apt/sources.list.d/tor.list"
# install dependencies
RUN apt-get update \
    && apt-get install --quiet --no-install-recommends --no-install-suggests --yes \
    # image dependencies
    tini iproute2 procps vim jq \
    # servers dependencies (see `install.sh`)
    build-essential automake autoconf pkg-config libtool python3-dev python3-pip python3-setuptools python3-venv libltdl-dev \
    # tor
    tor \
    deb.torproject.org-keyring \
    # ui dependencies
    nginx \
    # cleanup 
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/*

ENV DATADIR=/root/.joinmarket
ENV CONFIG=${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG=/root/default.cfg
ENV PATH=/src/scripts:$PATH

WORKDIR /src

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

# nginx
EXPOSE 80

WORKDIR /src/scripts

ENTRYPOINT  [ "tini", "-g", "--", "/jam-entrypoint.sh" ]
