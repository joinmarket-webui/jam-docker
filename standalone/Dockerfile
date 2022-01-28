

# global arguments
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
ARG JM_SERVER_REPO_REF
ARG JM_UI_REPO_REF

LABEL ui_version=$JM_UI_REPO_REF
LABEL server_version=$JM_SERVER_REPO_REF

RUN apt-get update \
    && apt-get install -qq --no-install-recommends gnupg curl

RUN sh -c "echo 'deb http://nginx.org/packages/mainline/debian/ bullseye nginx' > /etc/apt/sources.list.d/nginx.list" \
    && curl -s https://nginx.org/keys/nginx_signing.key | \
    gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/nginx.gpg --import \
    && chmod 644 /etc/apt/trusted.gpg.d/nginx.gpg

RUN apt-get update \
    && apt-get install -qq --no-install-recommends tini sudo procps vim iproute2 \
    build-essential automake pkg-config libtool libgmp-dev libltdl-dev python3-dev virtualenv python3-pip supervisor \
    && apt-get install -qq --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*

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
RUN . jmvenv/bin/activate && cd /src/scripts \
    && pip install matplotlib \
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
