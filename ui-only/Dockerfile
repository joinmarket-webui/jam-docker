FROM alpine:3.14 AS builder-base
# install build dependencies
RUN apk add --no-cache --update git nodejs npm

# ---
FROM builder-base AS builder
ENV REPO https://github.com/joinmarket-webui/joinmarket-webui
ENV REPO_BRANCH master
ENV REPO_REF master

WORKDIR /usr/src/app

# checkout and build project
RUN git clone "$REPO" . --depth=10 --branch "$REPO_BRANCH" && git checkout "$REPO_REF"
RUN npm install
RUN npm run build

# ---
FROM nginx:1.21.5-alpine as runtime

# ---
FROM runtime
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