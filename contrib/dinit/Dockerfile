
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG DEBIAN_IMAGE_VERSION=bookworm-20250224-slim
ARG DEBIAN_IMAGE_HASH=12c396bd585df7ec21d5679bb6a83d4878bc4415ce926c9e5ea6426d23c60bdc
ARG DEBIAN_IMAGE=debian:${DEBIAN_IMAGE_VERSION}@sha256:${DEBIAN_IMAGE_HASH}

ARG DINIT_VERSION=0.19.3

FROM ${DEBIAN_IMAGE} AS builder
ARG DINIT_VERSION

# install build dependencies
RUN apt-get update \
    && apt-get install --quiet --no-install-recommends --no-install-suggests --yes ca-certificates git gcc make m4 g++

WORKDIR /usr/src/dinit

# checkout and build project
# see: https://github.com/davmac314/dinit/releases
RUN git clone "https://github.com/davmac314/dinit" . --depth=1 --branch "v$DINIT_VERSION" \
    && make \
    && export ASAN_OPTIONS=detect_leaks=0 \
    && make check \
    && make check-igr \
    && mkdir dinit-bin \
    && make DESTDIR="$(pwd)/dinit-bin" install

FROM scratch
COPY --from=builder /usr/src/dinit/dinit-bin/sbin /out
