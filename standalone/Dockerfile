# --- Builder base 
FROM alpine:3.14 AS builder-base
RUN apk add --no-cache --update git
# --- Builder base 

# --- UI builder 
FROM builder-base AS ui-builder
# install build dependencies
RUN apk add --no-cache --update git nodejs npm

ENV REPO https://github.com/joinmarket-webui/joinmarket-webui
ENV REPO_BRANCH master
ENV REPO_REF master

WORKDIR /usr/src/joinmarket-webui

# checkout and build project
RUN git clone "$REPO" . --depth=10 --branch "$REPO_BRANCH" && git checkout "$REPO_REF"
RUN npm install
RUN npm run build
# --- UI builder - end

# --- SERVER builder
FROM builder-base AS server-builder

ENV REPO https://github.com/JoinMarket-Org/joinmarket-clientserver
ENV REPO_BRANCH master
ENV REPO_REF master

WORKDIR /usr/src/joinmarket-clientserver

RUN git clone "$REPO" . --depth=10 --branch "$REPO_REF" && git checkout "$REPO_REF"

# --- SERVER builder - end

# --- RUNTIME builder
FROM python:3.9.10-slim-bullseye

RUN apt-get update \
    && apt-get install -qq --no-install-recommends gnupg curl

RUN sh -c "echo 'deb http://nginx.org/packages/mainline/debian/ bullseye nginx' > /etc/apt/sources.list.d/nginx.list" \
    && curl -s https://nginx.org/keys/nginx_signing.key | \
    gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/nginx.gpg --import \
    && chmod 644 /etc/apt/trusted.gpg.d/nginx.gpg

RUN apt-get update \
    && apt-get install -qq --no-install-recommends tini sudo procps vim iproute2 nginx \
    build-essential automake pkg-config libtool libgmp-dev libltdl-dev python3-dev virtualenv python3-pip supervisor \
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

# generate ssl certificates for jmwalletd
RUN mkdir -p "${DATADIR}/ssl/" \
    && cd "${DATADIR}/ssl/" \
    && openssl req -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out cert.pem -keyout key.pem \
    -subj "/C=US/ST=Utah/L=Lehi/O=Your Company, Inc./OU=IT/CN=example.com"

WORKDIR /src/scripts

COPY docker-entrypoint.sh .
COPY *.sh ./
COPY autostart /root/
COPY supervisor-conf/*.conf /etc/supervisor/conf.d/

COPY ./nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf

# nginx
EXPOSE 80
# jmwallet daemon
EXPOSE 28183
#EXPOSE 8080  # payjoin server
#EXPOSE 27183 # joinmarketd daemon
#EXPOSE 62601 # obwatch

ENTRYPOINT  [ "tini", "-g", "--", "./docker-entrypoint.sh" ]
