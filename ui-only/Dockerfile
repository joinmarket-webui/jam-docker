
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG SKIP_RELEASE_VERIFICATION=false

ARG NODE_IMAGE_VERSION=22.14.0
ARG NODE_IMAGE_HASH=9bef0ef1e268f60627da9ba7d7605e8831d5b56ad07487d24d1aa386336d1944
ARG NODE_IMAGE=node:${NODE_IMAGE_VERSION}-alpine3.21@sha256:${NODE_IMAGE_HASH}
ARG ALPINE_IMAGE_VERSION=3.21.2
ARG ALPINE_IMAGE_HASH=56fa17d2a7e7f168a043a2712e63aed1f8543aeafdcee47c58dcffe38ed51099
ARG ALPINE_IMAGE=alpine:${ALPINE_IMAGE_VERSION}@sha256:${ALPINE_IMAGE_HASH}
ARG NGINX_IMAGE_VERSION=1.27.4
ARG NGINX_IMAGE_HASH=d7a882db5450b0f95c8ccf6797d9c4a0c14b9d34f4d4fd66289e6125b95e7989
ARG NGINX_IMAGE=nginx:${NGINX_IMAGE_VERSION}-alpine3.21-slim@sha256:${NGINX_IMAGE_HASH}

FROM ${NODE_IMAGE} AS node

FROM ${ALPINE_IMAGE} AS builder-base

COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

# install build dependencies
RUN apk add --no-cache --update git gnupg

# --- UI builder 
FROM builder-base AS builder
ARG SKIP_RELEASE_VERIFICATION
ARG JAM_REPO
ARG JAM_REPO_REF

WORKDIR /usr/src/app

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
