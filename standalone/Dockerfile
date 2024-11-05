
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG JM_SERVER_REPO=https://github.com/JoinMarket-Org/joinmarket-clientserver
ARG JM_SERVER_REPO_REF=master

ARG SKIP_RELEASE_VERIFICATION=false

ARG NODE_IMAGE_VERSION=22.11.0
ARG NODE_IMAGE_HASH=f265794478aa0b1a23d85a492c8311ed795bc527c3fe7e43453b3c872dcd71a3
ARG NODE_IMAGE=node:${NODE_IMAGE_VERSION}-alpine@sha256:${NODE_IMAGE_HASH}
ARG ALPINE_IMAGE_VERSION=3.20.3
ARG ALPINE_IMAGE_HASH=beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d
ARG ALPINE_IMAGE=alpine:${ALPINE_IMAGE_VERSION}@sha256:${ALPINE_IMAGE_HASH}
ARG DEBIAN_IMAGE_VERSION=bullseye-20240926-slim
ARG DEBIAN_IMAGE_HASH=3f9e53602537cc817d96f0ebb131a39bdb16fa8b422137659a9a597e7e3853c1
ARG DEBIAN_IMAGE=debian:${DEBIAN_IMAGE_VERSION}@sha256:${DEBIAN_IMAGE_HASH}

ARG DINIT_VERSION=0.19.0

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


# --- dinit builder
FROM ${DEBIAN_IMAGE} AS dinit-builder
ARG DINIT_VERSION

# install build dependencies
RUN apt-get update \
    && apt-get install -qq --no-install-recommends --no-install-suggests -y ca-certificates git gcc make m4 g++

WORKDIR /usr/src/dinit

# checkout and build project
# see: https://github.com/davmac314/dinit/releases
RUN git clone "https://github.com/davmac314/dinit" . --depth=1 --branch "v$DINIT_VERSION" \
    && make \
    && export ASAN_OPTIONS=detect_leaks=0 \
    && make check \
    && make check-igr \
    && mkdir dinit-bin \
    && make DESTDIR="$(pwd)/dinit-bin" install
# --- dinit builder - end

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

RUN addgroup --system tor \
    && adduser --system --disabled-login --ingroup tor --gecos 'tor user' tor \
    && apt-get update \
    && apt-get install -qq --no-install-recommends --no-install-suggests -y gnupg curl apt-transport-https ca-certificates \
    # add nginx debian repo
    && curl --silent https://nginx.org/keys/nginx_signing.key | \
    gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null \
    && sh -c "echo 'deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/mainline/debian/ bullseye nginx' > /etc/apt/sources.list.d/nginx.list" \
    # add tor debian repo
    && curl --silent https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | \
    gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg > /dev/null \
    && sh -c "echo 'deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org bullseye main' > /etc/apt/sources.list.d/tor.list" \
    # install dependencies
    && apt-get update \
    && apt-get install -qq --no-install-recommends --no-install-suggests -y \
    # image dependencies
    tini iproute2 procps vim jq \
    # servers dependencies (see `install.sh`)
    build-essential automake pkg-config libtool libltdl-dev python3-dev python3-pip python3-setuptools python3-venv \
    # tor
    tor \
    deb.torproject.org-keyring \
    # ui dependencies
    nginx \
    # cleanup 
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/*

COPY --from=dinit-builder /usr/src/dinit/dinit-bin/sbin /sbin
COPY --from=ui-builder /usr/src/jam/build /app
COPY --from=server-builder /usr/src/joinmarket-clientserver /src

ENV DATADIR=/root/.joinmarket
ENV CONFIG=${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG=/root/default.cfg
ENV PATH=/src/scripts:$PATH

WORKDIR /src

# compile and install JoinMarket
RUN ./install.sh --docker-install --without-qt \
    && rm --recursive --force install.sh deps/cache/ test/ .git/ .gitignore .github/ .coveragerc joinmarket-qt.desktop

# cleanup and remove ephemeral dependencies
RUN apt-get remove --purge --auto-remove -y gnupg python3-pip apt-transport-https \
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
