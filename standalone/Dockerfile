
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
# --- Builder base - end

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
    tini supervisor iproute2 procps vim \
    # servers dependencies (see `install.sh`)
    build-essential automake pkg-config libtool libltdl-dev python3-dev python3-setuptools python3-pip \
    # ui dependencies
    nginx \
    # ---
    && apt-get clean \
    && apt-get remove --purge --auto-remove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/apt/sources.list.d/nginx.list \
    && rm -f /var/log/dpkg.log

WORKDIR /src

COPY --from=ui-builder /usr/src/joinmarket-webui/build /app
COPY --from=server-builder /usr/src/joinmarket-clientserver .

ENV DATADIR /root/.joinmarket
ENV CONFIG ${DATADIR}/joinmarket.cfg
ENV DEFAULT_CONFIG /root/default.cfg
ENV DEFAULT_AUTO_START /root/autostart
ENV AUTO_START ${DATADIR}/autostart
ENV PATH /src/scripts:$PATH

RUN ./install.sh --docker-install --without-qt
RUN rm -rf install.sh deps/cache/ test/ .git/ .gitignore .github/ .coveragerc joinmarket-qt.desktop

WORKDIR /src/scripts

COPY docker-entrypoint.sh ./
COPY .bashrc /root/.bashrc
COPY autostart ${DEFAULT_AUTO_START}
COPY default.cfg ${DEFAULT_CONFIG}
COPY supervisor-conf/*.conf /etc/supervisor/conf.d/

COPY ./nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf

# nginx
EXPOSE 80

ENTRYPOINT  [ "tini", "-g", "--", "./docker-entrypoint.sh" ]
