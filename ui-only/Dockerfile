
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG SKIP_RELEASE_VERIFICATION=false

ARG NODE_IMAGE_VERSION=${NODE_IMAGE_VERSION:-26.3.0-alpine3.24}
ARG NODE_IMAGE_HASH=${NODE_IMAGE_HASH:-9c0e1e52125d6b67d505cf75b4880fcf1290ccea5c480849910e1d57b2cf72b5}
ARG NODE_IMAGE=node:${NODE_IMAGE_VERSION}@sha256:${NODE_IMAGE_HASH}
ARG ALPINE_IMAGE_VERSION=3.21.2
ARG ALPINE_IMAGE_HASH=56fa17d2a7e7f168a043a2712e63aed1f8543aeafdcee47c58dcffe38ed51099
ARG ALPINE_IMAGE=alpine:${ALPINE_IMAGE_VERSION}@sha256:${ALPINE_IMAGE_HASH}
ARG NGINX_IMAGE_VERSION=${NGINX_IMAGE_VERSION:-1.31.2-alpine3.23-slim}
ARG NGINX_IMAGE_HASH=${NGINX_IMAGE_HASH:-dd722b8ee8794f3c273bfaf8b5351b0652a68ccd73c17e5f0d029857a58f25ef}
ARG NGINX_IMAGE=nginx:${NGINX_IMAGE_VERSION}@sha256:${NGINX_IMAGE_HASH}

FROM ${NODE_IMAGE} AS node

FROM ${ALPINE_IMAGE} AS builder-base

COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

# install build dependencies
RUN apk add --no-cache --update git gnupg

# --- UI builder 
FROM builder-base AS ui-builder
ARG SKIP_RELEASE_VERIFICATION
ARG JAM_REPO
ARG JAM_REPO_REF

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

# ---
FROM ${NGINX_IMAGE} AS runtime

# ---
FROM runtime
ARG MAINTAINER
ARG JAM_REPO_REF

LABEL maintainer="$MAINTAINER"
LABEL ui-version="$JAM_REPO_REF"

WORKDIR /

# Copy UI build artifacts from ui-builder
# Modern Jam (devel) uses Vite and outputs to dist/
# Legacy Jam (v0.4.1+) uses CRA and outputs to build/
RUN --mount=type=bind,from=ui-builder,source=/usr/src/jam,target=/tmp/jam \
    if [ -d /tmp/jam/dist ]; then \
        echo "Detected Vite build output (dist/)"; \
        cp --recursive /tmp/jam/dist /app; \
    elif [ -d /tmp/jam/build ]; then \
        echo "Detected CRA build output (build/)"; \
        cp --recursive /tmp/jam/build /app; \
    else \
        echo "ERROR: No UI build output found!"; \
        echo "Checked directories:"; \
        ls --all -l /tmp/jam/ || true; \
        exit 1; \
    fi

COPY nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
# each time nginx is started it will perform variable substition in all template
# files found in `/etc/nginx/templates/*.template`, and copy the results (without
# the `.template` suffix) into `/etc/nginx/conf.d/`.
COPY nginx/templates/default.conf.template /etc/nginx/templates/default.conf.template

COPY --chmod=0755 jam-entrypoint.sh /

ENTRYPOINT  [ "/jam-entrypoint.sh" ]

# the default parameters to ENTRYPOINT (unless overruled on the command line)
CMD ["nginx", "-g", "daemon off;"]
