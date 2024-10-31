
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG NODE_VERSION=22.11.0
ARG ALPINE_VERSION=3.20.3

FROM node:${NODE_VERSION}-alpine AS node

FROM alpine:${ALPINE_VERSION} AS builder-base

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
FROM nginx:1.25.4-alpine3.18-slim AS runtime

# ---
FROM runtime
ARG MAINTAINER
ARG JAM_REPO_REF

LABEL maintainer="$MAINTAINER"
LABEL ui-version=$JAM_REPO_REF

WORKDIR /

COPY --from=builder /usr/src/app/build /app

COPY nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
# each time nginx is started it will perform variable substition in all template
# files found in `/etc/nginx/templates/*.template`, and copy the results (without
# the `.template` suffix) into `/etc/nginx/conf.d/`.
COPY nginx/templates/default.conf.template /etc/nginx/templates/default.conf.template

COPY jam-entrypoint.sh /
RUN chmod +x /jam-entrypoint.sh

ENTRYPOINT  [ "/jam-entrypoint.sh" ]

# the default parameters to ENTRYPOINT (unless overruled on the command line)
CMD ["nginx", "-g", "daemon off;"]
