
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_BRANCH=master
ARG JAM_REPO_REF=master

FROM alpine:3.15 AS builder-base
# install build dependencies
RUN apk add --no-cache --update git nodejs npm

# ---
FROM builder-base AS builder
ARG JAM_REPO
ARG JAM_REPO_BRANCH
ARG JAM_REPO_REF

WORKDIR /usr/src/app

# checkout and build project
RUN git clone "$JAM_REPO" . --depth=1 --branch "$JAM_REPO_BRANCH" \
    && git fetch --all --tags \
    && git checkout "$JAM_REPO_REF" \
    && npm install --no-fund --no-audit \
    && npm run build

# ---
FROM nginx:1.23.1-alpine as runtime

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
