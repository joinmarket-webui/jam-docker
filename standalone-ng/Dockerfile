
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG JM_NG_REPO=https://github.com/joinmarket-ng/joinmarket-ng
ARG JM_NG_REPO_REF=main

ARG SKIP_RELEASE_VERIFICATION=false

ARG S6_OVERLAY_VERSION=3.2.3.2
ARG S6_OVERLAY_NOARCH_HASH=5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12
ARG S6_OVERLAY_X86_64_HASH=e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408
ARG S6_OVERLAY_AARCH64_HASH=b17f17a82e7a515c682a91edaf2ffdabb73f891981b6c1fd712115693a2f8b4c
ARG S6_OVERLAY_ARMHF_HASH=64fc0a4d8917658e6da5f5878e2e410e92b60faf3d39a9bef1452dabe031dd40

ARG NODE_IMAGE_VERSION=26.7.0-alpine3.24
ARG NODE_IMAGE_HASH=aadf416b2cdce311a8811ba3f0608a61b77dbf997500e2eafe781b51f6a0b019
ARG NODE_IMAGE=node:${NODE_IMAGE_VERSION}@sha256:${NODE_IMAGE_HASH}
ARG ALPINE_IMAGE_VERSION=3.24.1
ARG ALPINE_IMAGE_HASH=28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b
ARG ALPINE_IMAGE=alpine:${ALPINE_IMAGE_VERSION}@sha256:${ALPINE_IMAGE_HASH}
ARG DEBIAN_IMAGE_VERSION=trixie-20260803-slim
ARG DEBIAN_IMAGE_HASH=3a39a0592364683e6bab97937b72cad5a8fa6dcbbee90edb3bb48c7f8e94f258
ARG DEBIAN_IMAGE=debian:${DEBIAN_IMAGE_VERSION}@sha256:${DEBIAN_IMAGE_HASH}

FROM ${NODE_IMAGE} AS node

FROM ${ALPINE_IMAGE} AS builder-base

COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

COPY pubkeys/ /pubkeys

# install build dependencies
RUN apk add --no-cache --update git gnupg

# --- UI builder
FROM builder-base AS ui-builder
ARG JAM_REPO
ARG JAM_REPO_REF
ARG SKIP_RELEASE_VERIFICATION

# Set working directory
WORKDIR /usr/src/jam

# Clone Jam repository and verify GPG signature
RUN git clone "${JAM_REPO}" . --depth=1 --branch "${JAM_REPO_REF}" \
    && if [ "${SKIP_RELEASE_VERIFICATION}" != "true" ]; then \
        echo "Importing GPG keys for Jam release verification..." \
        && find /pubkeys -type f -iname '*.asc' -exec gpg --import "{}" + \
        && if [ "$(git cat-file -t "refs/tags/${JAM_REPO_REF}" 2>/dev/null)" = "tag" ]; then \
            echo "Verifying GPG signature for tag: '${JAM_REPO_REF}'" \
            && git verify-tag "${JAM_REPO_REF}"; \
        else \
            echo "Ref '${JAM_REPO_REF}' is not an annotated tag; Trying to verify commit..." \
            && git verify-commit "$(git rev-parse --verify HEAD)"; \
        fi; \
    else \
        echo "Skipping GPG release verification (SKIP_RELEASE_VERIFICATION=true)"; \
    fi

RUN npm clean-install --no-fund --no-audit \
    && npm run build
# --- UI builder - end

# --- Venv builder
# Use the same Debian base as the runtime to ensure glibc compatibility
FROM ${DEBIAN_IMAGE} AS venv-builder
ARG JM_NG_REPO
ARG JM_NG_REPO_REF
ARG SKIP_RELEASE_VERIFICATION

# Install Python, build dependencies, git, and gnupg
RUN apt-get update \
    && apt-get install --quiet --no-install-recommends --no-install-suggests --yes \
        python3 \
        python3-venv \
        python3-pip \
        python3-dev \
        git \
        gnupg \
        build-essential \
        libsodium-dev \
        libsecp256k1-dev \
        pkg-config \
        cmake \
    && rm --recursive --force /var/lib/apt/lists/* \
    && rm --recursive --force /var/log/dpkg.log /var/log/apt/*

# Copy GPG public keys from builder-base
COPY --from=builder-base /pubkeys /pubkeys

# Set working directory
WORKDIR /build

# Clone joinmarket-ng repository and verify GPG signature
RUN git clone "${JM_NG_REPO}" . --depth=1 --branch "${JM_NG_REPO_REF}" \
    && if [ "${SKIP_RELEASE_VERIFICATION}" != "true" ]; then \
        echo "Importing GPG keys for joinmarket-ng release verification..." \
        && find /pubkeys -type f -iname '*.asc' -exec gpg --import "{}" + \
        && if [ "$(git cat-file -t "refs/tags/${JM_NG_REPO_REF}" 2>/dev/null)" = "tag" ]; then \
            echo "Verifying GPG signature for tag: '${JM_NG_REPO_REF}'" \
            && git verify-tag "${JM_NG_REPO_REF}"; \
        else \
            echo "Ref '${JM_NG_REPO_REF}' is not an annotated tag; Trying to verify commit..." \
            && git verify-commit "$(git rev-parse --verify HEAD)"; \
        fi; \
    else \
        echo "Skipping GPG release verification (SKIP_RELEASE_VERIFICATION=true)"; \
    fi

# Create Python virtual environment at /opt/venv
RUN python3 -m venv /opt/venv

# Activate virtual environment and install joinmarket-ng via pip
RUN . /opt/venv/bin/activate \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir \
        ./jmcore ./jmwallet ./maker ./taker \
        ./orderbook_watcher ./jmwalletd ./tumbler
# --- Venv builder - end

# --- Runtime stage
FROM ${DEBIAN_IMAGE} AS runtime
ARG MAINTAINER
ARG JAM_REPO_REF
ARG JM_NG_REPO_REF
ARG S6_OVERLAY_VERSION
ARG S6_OVERLAY_NOARCH_HASH
ARG S6_OVERLAY_X86_64_HASH
ARG S6_OVERLAY_AARCH64_HASH
ARG S6_OVERLAY_ARMHF_HASH

# Set Docker labels
LABEL maintainer="${MAINTAINER}"
LABEL ui-version="${JAM_REPO_REF}"
LABEL server-version="${JM_NG_REPO_REF}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install runtime dependencies (includes python3 so the venv symlinks resolve)
RUN apt-get update \
    && apt-get install --quiet --no-install-recommends --no-install-suggests --yes \
        nginx \
        curl \
        gnupg \
        xz-utils \
        procps \
        logrotate \
        ca-certificates \
        openssl \
        python3 \
        python3-venv \
        libsodium23 \
        libsecp256k1-2 \
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/* \
    && rm --recursive --force /var/log/dpkg.log /var/log/apt/*

# Enable the Tor Project's signed repository after installing ca-certificates.
# Archive key fingerprint: A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89
# https://support.torproject.org/little-t-tor/getting-started/installing/
RUN curl --fail --silent --show-error --location \
        https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc \
    | gpg --batch --dearmor --output /usr/share/keyrings/deb.torproject.org-keyring.gpg

COPY apt/tor.sources /etc/apt/sources.list.d/tor.sources

RUN apt-get update \
    && apt-get install --quiet --no-install-recommends --no-install-suggests --yes \
        tor \
        deb.torproject.org-keyring \
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/* \
    && rm --recursive --force /var/log/dpkg.log /var/log/apt/*

# Install s6-overlay
# Determine architecture for s6-overlay
RUN case "$(uname -m)" in \
        x86_64) S6_ARCH=x86_64; S6_HASH=${S6_OVERLAY_X86_64_HASH} ;; \
        aarch64) S6_ARCH=aarch64; S6_HASH=${S6_OVERLAY_AARCH64_HASH} ;; \
        armv7l) S6_ARCH=armhf; S6_HASH=${S6_OVERLAY_ARMHF_HASH} ;; \
        *) echo "Unsupported architecture: $(uname -m)" && exit 1 ;; \
    esac \
    && curl --fail --silent --show-error --location --remote-name "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
    && curl --fail --silent --show-error --location --remote-name "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
    && echo "${S6_OVERLAY_NOARCH_HASH}  s6-overlay-noarch.tar.xz" | sha256sum -c - \
    && echo "${S6_HASH}  s6-overlay-${S6_ARCH}.tar.xz" | sha256sum -c - \
    && tar --directory / --extract --xz --preserve-permissions --file s6-overlay-noarch.tar.xz \
    && tar --directory / --extract --xz --preserve-permissions --file "s6-overlay-${S6_ARCH}.tar.xz" \
    && rm --force s6-overlay-*.tar.xz

# Copy UI build artifacts from ui-builder
# Modern Jam (>=v2.0.0) uses Vite and outputs to dist/
# Legacy Jam (<v2.0.0) uses CRA and outputs to build/
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

# Copy Python virtual environment from venv-builder
COPY --from=venv-builder /opt/venv /opt/venv

# Configure PATH to include /opt/venv/bin
ENV PATH="/opt/venv/bin:${PATH}"
ENV JOINMARKET_DATA_DIR=/root/.joinmarket-ng
ENV DATADIR=/root/.joinmarket-ng
ENV JMWALLETD_HOST=127.0.0.1
ENV TOR__SOCKS_HOST=127.0.0.1
ENV TOR__SOCKS_PORT=9050
ENV TOR__CONTROL_HOST=127.0.0.1
ENV TOR__CONTROL_PORT=9051
ENV TOR__COOKIE_PATH=/var/lib/tor/control_auth_cookie
ENV ORDERBOOK_WATCHER__HTTP_HOST=127.0.0.1
ENV ORDERBOOK_WATCHER__HTTP_PORT=8000
ENV OBWATCH_URL=http://${ORDERBOOK_WATCHER__HTTP_HOST}:${ORDERBOOK_WATCHER__HTTP_PORT}

# Copy upstream service definitions from joinmarket-ng repository
COPY --from=venv-builder /build/jmwalletd/rootfs/etc/s6-overlay /etc/s6-overlay

# Copy local nginx service definition
COPY s6-overlay/ /etc/s6-overlay/

# Ensure all run scripts are executable.
# Upstream joinmarket-ng scripts (tor/run, jmwalletd-svc/run, obwatcher/run) are
# copied from the venv-builder stage and may not have the execute bit set.
# Local scripts (logger services, tor-ready/up, nginx-svc/run) are also made executable here.
RUN chmod +x \
    /etc/s6-overlay/s6-rc.d/tor/run \
    /etc/s6-overlay/s6-rc.d/tor-ready/up \
    /etc/s6-overlay/s6-rc.d/tor-log/run \
    /etc/s6-overlay/s6-rc.d/jmwalletd-svc/run \
    /etc/s6-overlay/s6-rc.d/jmwalletd-svc-log/run \
    /etc/s6-overlay/s6-rc.d/obwatcher/run \
    /etc/s6-overlay/s6-rc.d/obwatcher-log/run \
    /etc/s6-overlay/s6-rc.d/nginx-svc/run \
    /etc/s6-overlay/s6-rc.d/logrotate-svc/run

# Copy nginx configuration
COPY nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
COPY nginx/snippets/security-headers.conf /etc/nginx/snippets/security-headers.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

RUN sed --in-place "s|__BACKEND_VERSION__|${JM_NG_REPO_REF}|g" /etc/nginx/conf.d/default.conf \
  # Remove the default nginx site that conflicts with our config
  && rm --force /etc/nginx/sites-enabled/default

# Copy logrotate configuration
COPY --chmod=0644 logrotate/ /etc/logrotate.d/

# Copy torrc configuration
COPY torrc /etc/tor/torrc

# Copy entrypoint script
COPY jam-ng-entrypoint.sh /usr/local/bin/jam-ng-entrypoint.sh
RUN chmod +x /usr/local/bin/jam-ng-entrypoint.sh

# Create log directories and fix tor data directory ownership
# (Debian's tor package creates /var/lib/tor owned by debian-tor; we run tor as root)
RUN mkdir --parents /var/log/jam-ng/jmwalletd \
    && mkdir --parents /var/log/jam-ng/obwatcher \
    && mkdir --parents /var/log/jam-ng/tor \
    && mkdir --parents /var/log/jam-ng/nginx \
    && mkdir --parents /var/lib/logrotate \
    && chown root:root /var/lib/tor \
    && chmod 700 /var/lib/tor

EXPOSE 80

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/jam-ng-entrypoint.sh"]
# --- Runtime stage - end
