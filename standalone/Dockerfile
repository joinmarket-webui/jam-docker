
# global arguments
ARG MAINTAINER='joinmarket-webui https://github.com/joinmarket-webui'

ARG JM_UI_REPO=https://github.com/joinmarket-webui/joinmarket-webui
ARG JM_UI_REPO_BRANCH=master
ARG JM_UI_REPO_REF=master

ARG JM_SERVER_REPO=https://github.com/JoinMarket-Org/joinmarket-clientserver
ARG JM_SERVER_REPO_BRANCH=master
ARG JM_SERVER_REPO_REF=master

# --- Builder base 
FROM alpine:3.15 AS builder-base
RUN apk add --no-cache --update git
# --- Builder base 

# --- UI builder 
FROM builder-base AS ui-builder
ARG JM_UI_REPO
ARG JM_UI_REPO_BRANCH
ARG JM_UI_REPO_REF

# install build dependencies
RUN apk add --no-cache --update nodejs npm

WORKDIR /usr/src/joinmarket-webui

# checkout and build project
RUN git clone "$JM_UI_REPO" . --depth=1 --branch "$JM_UI_REPO_BRANCH" \
    && git fetch --all --tags \
    && git checkout "$JM_UI_REPO_REF"
RUN npm install --no-fund --no-audit
RUN npm run build
# --- UI builder - end

# --- SERVER builder
FROM builder-base AS server-builder
ARG JM_SERVER_REPO
ARG JM_SERVER_REPO_BRANCH
ARG JM_SERVER_REPO_REF

WORKDIR /usr/src/joinmarket-clientserver

RUN git clone "$JM_SERVER_REPO" . --depth=1 --branch "$JM_SERVER_REPO_BRANCH" \
    && git fetch --all --tags \
    && git checkout "$JM_SERVER_REPO_REF"
# --- SERVER builder - end

# --- RUNTIME builder
FROM python:3.9.10-slim-bullseye
ARG MAINTAINER
ARG JM_SERVER_REPO_REF
ARG JM_UI_REPO_REF

LABEL maintainer="$MAINTAINER"
LABEL ui_version=$JM_UI_REPO_REF
LABEL server_version=$JM_SERVER_REPO_REF

RUN apt-get update \
    && apt-get install -qq --no-install-recommends --no-install-suggests -y gnupg curl \
    && sh -c "echo 'deb http://nginx.org/packages/mainline/debian/ bullseye nginx' > /etc/apt/sources.list.d/nginx.list" \
    && curl -s https://nginx.org/keys/nginx_signing.key | \
    gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/nginx.gpg --import \
    && chmod 644 /etc/apt/trusted.gpg.d/nginx.gpg \
    && apt-get remove --purge --auto-remove -y gnupg

RUN apt-get update \
    && apt-get install -qq --no-install-recommends --no-install-suggests -y \
    # ---
    # image dependencies
    tini supervisor iproute2 \
    # servers dependencies (see `install.sh`)
    sudo build-essential automake pkg-config libtool libltdl-dev python3-dev virtualenv python3-pip \
    # ui dependencies
    nginx \
    # ---
    && apt-get remove --purge --auto-remove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/apt/sources.list.d/nginx.list

WORKDIR /src

COPY --from=server-builder /usr/src/joinmarket-clientserver .
COPY --from=ui-builder /usr/src/joinmarket-webui/build /app

ENV DATADIR /root/.joinmarket
ENV CONFIG ${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG /root/default.cfg
ENV DEFAULT_AUTO_START /root/autostart
ENV AUTO_START ${DATADIR}/autostart
ENV ENV_FILE "${DATADIR}/.env"
ENV PATH /src/scripts:$PATH

RUN ./install.sh --disable-secp-check --without-qt

RUN . jmvenv/bin/activate \
    && cd /src/scripts \
    # without `matplotlib` charts won't be available - not important for the ui (enable on demand)
    # && pip install matplotlib \
    && (python wallet-tool.py generate || true) \
    && cp "${CONFIG}" "${DEFAULT_CONFIG}"

WORKDIR /src/scripts

COPY docker-entrypoint.sh .
COPY *.sh ./
COPY autostart /root/
COPY supervisor-conf/*.conf /etc/supervisor/conf.d/

COPY ./nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf

# nginx
EXPOSE 80
#EXPOSE 28183 # jmwallet daemon
#EXPOSE 8080  # payjoin server
#EXPOSE 27183 # joinmarketd daemon
#EXPOSE 62601 # obwatch

ENTRYPOINT  [ "tini", "-g", "--", "./docker-entrypoint.sh" ]
