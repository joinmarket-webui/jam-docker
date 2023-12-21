
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG JM_SERVER_REPO=https://github.com/JoinMarket-Org/joinmarket-clientserver
ARG JM_SERVER_REPO_REF=master

# --- Builder base 
FROM alpine:3.18.3 AS builder-base
RUN apk add --no-cache --update git
# --- Builder base - end

# --- UI builder 
FROM builder-base AS ui-builder
ARG JAM_REPO
ARG JAM_REPO_REF

# install build dependencies
RUN apk add --no-cache --update nodejs npm

WORKDIR /usr/src/jam

# checkout and build project
RUN git clone "$JAM_REPO" . --depth=1 --branch "$JAM_REPO_REF" \
    && npm install --no-fund --no-audit \
    && npm run build
# --- UI builder - end


# --- dinit builder
FROM debian:bullseye-20230919-slim AS dinit-builder

# install build dependencies
RUN apt-get update \
    && apt-get install -qq --no-install-recommends --no-install-suggests -y ca-certificates git gcc make m4 g++

WORKDIR /usr/src/dinit

# checkout and build project
# see: https://github.com/davmac314/dinit/releases
RUN git clone "https://github.com/davmac314/dinit" . --depth=1 --branch "v0.16.1" \
    && make \
    && export ASAN_OPTIONS=detect_leaks=0 \
    && make check \
    && make check-igr \
    && mkdir dinit-bin \
    && make DESTDIR="$(pwd)/dinit-bin" install
# --- dinit builder - end

# --- SERVER builder
FROM builder-base AS server-builder
ARG JM_SERVER_REPO
ARG JM_SERVER_REPO_REF

WORKDIR /usr/src/joinmarket-clientserver

RUN git clone "$JM_SERVER_REPO" . --depth=1 --branch "$JM_SERVER_REPO_REF"
# --- SERVER builder - end

# --- RUNTIME builder
FROM debian:bullseye-20230919-slim
ARG MAINTAINER
ARG JM_SERVER_REPO_REF
ARG JAM_REPO_REF

LABEL maintainer="$MAINTAINER"
LABEL ui-version=$JAM_REPO_REF
LABEL server-version=$JM_SERVER_REPO_REF

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN adduser --uid 704704 --system --group --gecos 'tor user' tor \
    && addgroup --gid 701234 --system joinmarket \
    && useradd --uid 7012347 --system -g joinmarket --groups tor --comment 'jmwalletd user' --home-dir /data jm-w \
    && useradd --uid 7012348 --system -g joinmarket --comment 'ob-watcher user' jm-ob \
    && mkdir /data && chown :701234 /data \
    && sed "s|http://|https://|" /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -qq --no-install-recommends --no-install-suggests -y gnupg curl ca-certificates \
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
    # privilege separation dependency:
    sudo \
    # cleanup 
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/*

COPY --from=dinit-builder /usr/src/dinit/dinit-bin/sbin /sbin
COPY --from=ui-builder /usr/src/jam/build /app
COPY --from=server-builder /usr/src/joinmarket-clientserver /src

ENV DATADIR /data/.joinmarket
ENV CONFIG ${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG /data/default.cfg
ENV PATH /src/scripts:$PATH

WORKDIR /src

# compile and install JoinMarket
RUN ./install.sh --docker-install --without-qt \
    && rm --recursive --force install.sh deps/cache/ test/ .git/ .gitignore .github/ .coveragerc joinmarket-qt.desktop

# cleanup and remove ephemeral dependencies
RUN apt-get remove --purge --auto-remove -y gnupg python3-pip apt-transport-https \
    && rm --force /var/log/dpkg.log

COPY default.cfg ${DEFAULT_CONFIG}
COPY dinit-conf/* /etc/dinit.d/
COPY .bashrc /root/.bashrc
COPY --chown=tor:tor torrc /etc/tor/torrc

COPY nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

COPY jam-entrypoint.sh /
RUN chmod +x /jam-entrypoint.sh

# nginx
EXPOSE 80

WORKDIR /src/scripts

ENTRYPOINT  [ "tini", "-g", "--", "/jam-entrypoint.sh" ]
