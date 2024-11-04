
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG NODE_IMAGE_VERSION=22.11.0
ARG NODE_IMAGE_HASH=f265794478aa0b1a23d85a492c8311ed795bc527c3fe7e43453b3c872dcd71a3
ARG NODE_IMAGE=node:${NODE_IMAGE_VERSION}-alpine@sha256:${NODE_IMAGE_HASH}
ARG ALPINE_IMAGE_VERSION=3.20.3
ARG ALPINE_IMAGE_HASH=beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d
ARG ALPINE_IMAGE=alpine:${ALPINE_IMAGE_VERSION}@sha256:${ALPINE_IMAGE_HASH}
ARG NGINX_IMAGE_VERSION=1.25.4
ARG NGINX_IMAGE_HASH=b841779b72c127bdcb6e58b2ae3d810f890e020460858d84c7bd38d15cf26ddf
ARG NGINX_IMAGE=nginx:${NGINX_IMAGE_VERSION}-alpine3.18-slim@sha256:${NGINX_IMAGE_HASH}

FROM ${NODE_IMAGE} AS node

FROM ${ALPINE_IMAGE} AS builder-base

COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

# install build dependencies
RUN apk add --no-cache --update git

# ---
FROM builder-base AS builder
ARG JAM_REPO
ARG JAM_REPO_REF

WORKDIR /usr/src/app

# checkout and build project
RUN git clone "$JAM_REPO" . --depth=1 --branch "$JAM_REPO_REF" \
    && npm install --no-fund --no-audit \
    && npm run build

# ---
FROM ${NGINX_IMAGE} AS runtime

# ---
FROM runtime
ARG MAINTAINER
ARG JAM_REPO_REF

LABEL maintainer="$MAINTAINER"
LABEL ui-version="$JAM_REPO_REF"

WORKDIR /

COPY --from=builder /usr/src/app/build /app

COPY nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
# each time nginx is started it will perform variable substition in all template
# files found in `/etc/nginx/templates/*.template`, and copy the results (without
# the `.template` suffix) into `/etc/nginx/conf.d/`.
COPY nginx/templates/default.conf.template /etc/nginx/templates/default.conf.template

COPY --chmod=0755 jam-entrypoint.sh /

ENTRYPOINT  [ "/jam-entrypoint.sh" ]

# the default parameters to ENTRYPOINT (unless overruled on the command line)
CMD ["nginx", "-g", "daemon off;"]
