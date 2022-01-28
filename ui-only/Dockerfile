
# global arguments
ARG MAINTAINER='joinmarket-webui https://github.com/joinmarket-webui'

ARG JM_UI_REPO=https://github.com/joinmarket-webui/joinmarket-webui
ARG JM_UI_REPO_BRANCH=master
ARG JM_UI_REPO_REF=master

FROM alpine:3.15 AS builder-base
# install build dependencies
RUN apk add --no-cache --update git nodejs npm

# ---
FROM builder-base AS builder
ARG JM_UI_REPO
ARG JM_UI_REPO_BRANCH
ARG JM_UI_REPO_REF

WORKDIR /usr/src/app

# checkout and build project
RUN git clone "$JM_UI_REPO" . --depth=1 --branch "$JM_UI_REPO_BRANCH" \
    && git fetch --all --tags \
    && git checkout "$JM_UI_REPO_REF"
RUN npm install --no-fund --no-audit
RUN npm run build

# ---
FROM nginx:1.21.6-alpine as runtime

# ---
FROM runtime
ARG MAINTAINER
ARG JM_UI_REPO_REF

LABEL maintainer="$MAINTAINER"
LABEL ui_version=$JM_UI_REPO_REF

WORKDIR /
COPY --from=builder /usr/src/app/build /app

COPY ./nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
# each time nginx is started it will perform variable substition in all template
# files found in `/etc/nginx/templates/*.template`, and copy the results (without
# the `.template` suffix) into `/etc/nginx/conf.d/`.
COPY ./nginx/templates/default.conf.template /etc/nginx/templates/default.conf.template

COPY ./jmwebui-entrypoint.sh .
RUN chmod +x ./jmwebui-entrypoint.sh

ENTRYPOINT  [ "./jmwebui-entrypoint.sh" ]

# the default parameters to ENTRYPOINT (unless overruled on the command line)
CMD ["nginx", "-g", "daemon off;"]