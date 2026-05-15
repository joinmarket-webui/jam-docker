
# global arguments
ARG MAINTAINER='Jam https://github.com/joinmarket-webui'

ARG JAM_REPO=https://github.com/joinmarket-webui/jam
ARG JAM_REPO_REF=master

ARG JM_NG_REPO=https://github.com/joinmarket-ng/joinmarket-ng
ARG JM_NG_REPO_REF=main

ARG SKIP_RELEASE_VERIFICATION=false

ARG NODE_IMAGE_VERSION=24.11.1
ARG NODE_IMAGE_HASH=b8f7c9056af700568c1ce76173f1c93743fb64ca1343e18cdf3a6ded8985ad3d
ARG NODE_IMAGE=node:${NODE_IMAGE_VERSION}-alpine3.21@sha256:${NODE_IMAGE_HASH}
ARG ALPINE_IMAGE_VERSION=3.21.2
ARG ALPINE_IMAGE_HASH=56fa17d2a7e7f168a043a2712e63aed1f8543aeafdcee47c58dcffe38ed51099
ARG ALPINE_IMAGE=alpine:${ALPINE_IMAGE_VERSION}@sha256:${ALPINE_IMAGE_HASH}
ARG DEBIAN_IMAGE_VERSION=bookworm-20250428-slim
ARG DEBIAN_IMAGE_HASH=4b50eb66f977b4062683ff434ef18ac191da862dbe966961bc11990cf5791a8d
ARG DEBIAN_IMAGE=debian:${DEBIAN_IMAGE_VERSION}@sha256:${DEBIAN_IMAGE_HASH}

# --- Builder base 
FROM ${ALPINE_IMAGE} AS builder-base
RUN apk add --no-cache --update git gnupg
COPY pubkeys/ /pubkeys
# --- Builder base - end

# --- UI builder
FROM ${NODE_IMAGE} AS ui-builder
ARG JAM_REPO
ARG JAM_REPO_REF
ARG SKIP_RELEASE_VERIFICATION

# Install git and gnupg for cloning and verification
RUN apk add --no-cache --update git gnupg

# Copy GPG public keys from builder-base
COPY --from=builder-base /pubkeys /pubkeys

# Set working directory
WORKDIR /usr/src/jam

# Clone Jam repository and verify GPG signature
RUN git clone "$JAM_REPO" . --depth=1 --branch "$JAM_REPO_REF" \
    && if [ "$SKIP_RELEASE_VERIFICATION" != "true" ]; then \
        echo "Importing GPG keys for Jam release verification..." \
        && find /pubkeys -iname '*.asc' -exec gpg --import "{}" \; \
        && if git rev-parse -q --verify "refs/tags/$JAM_REPO_REF" >/dev/null; then \
            echo "Verifying GPG signature for tag: $JAM_REPO_REF" \
            && git verify-tag "$JAM_REPO_REF"; \
        else \
            echo "Ref $JAM_REPO_REF is not a tag; skipping verify-tag."; \
        fi; \
    else \
        echo "Skipping GPG release verification (SKIP_RELEASE_VERIFICATION=true)"; \
    fi

# Build the Jam UI with NG backend enabled
RUN npm ci && VITE_BACKEND=ng npm run build
# --- UI builder - end

# --- Venv builder
# Use the same Debian base as the runtime to ensure glibc compatibility
FROM ${DEBIAN_IMAGE} AS venv-builder
ARG JM_NG_REPO
ARG JM_NG_REPO_REF
ARG SKIP_RELEASE_VERIFICATION

# Install Python, build dependencies, git, and gnupg
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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
    && rm -rf /var/lib/apt/lists/*

# Copy GPG public keys from builder-base
COPY --from=builder-base /pubkeys /pubkeys

# Set working directory
WORKDIR /build

# Clone joinmarket-ng repository and verify GPG signature
RUN git clone "$JM_NG_REPO" . --depth=1 --branch "$JM_NG_REPO_REF" \
    && if [ "$SKIP_RELEASE_VERIFICATION" != "true" ]; then \
        echo "Importing GPG keys for joinmarket-ng release verification..." \
        && find /pubkeys -iname '*.asc' -exec gpg --import "{}" \; \
        && if git rev-parse -q --verify "refs/tags/$JM_NG_REPO_REF" >/dev/null; then \
            echo "Verifying GPG signature for tag: $JM_NG_REPO_REF" \
            && git verify-tag "$JM_NG_REPO_REF"; \
        else \
            echo "Ref $JM_NG_REPO_REF is not a tag; skipping verify-tag."; \
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

# Install runtime dependencies (includes python3 so the venv symlinks resolve)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        tor \
        curl \
        xz-utils \
        procps \
        logrotate \
        ca-certificates \
        openssl \
        python3 \
        python3-venv \
        libsodium23 \
        libsecp256k1-1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install s6-overlay
ARG S6_OVERLAY_VERSION=3.2.0.2
# Determine architecture for s6-overlay
RUN case "$(uname -m)" in \
        x86_64) S6_ARCH=x86_64 ;; \
        aarch64) S6_ARCH=aarch64 ;; \
        armv7l) S6_ARCH=armhf ;; \
        *) echo "Unsupported architecture: $(uname -m)" && exit 1 ;; \
    esac \
    && curl -fsSLO "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
    && curl -fsSLO "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
    && tar -C / -Jxpf s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf s6-overlay-${S6_ARCH}.tar.xz \
    && rm s6-overlay-*.tar.xz

# Install bitcoin-cli (from Bitcoin Core)
ARG BITCOIN_VERSION=28.0
RUN case "$(uname -m)" in \
        x86_64) BITCOIN_ARCH=x86_64 ;; \
        aarch64) BITCOIN_ARCH=aarch64 ;; \
        armv7l) BITCOIN_ARCH=arm ;; \
        *) echo "Unsupported architecture for bitcoin-cli: $(uname -m)" && exit 1 ;; \
    esac \
    && curl -fsSLO "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}-linux-gnu.tar.gz" \
    && tar -xzf "bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}-linux-gnu.tar.gz" -C /tmp \
    && install -m 0755 -o root -g root -t /usr/local/bin /tmp/bitcoin-${BITCOIN_VERSION}/bin/bitcoin-cli \
    && rm -rf /tmp/bitcoin-${BITCOIN_VERSION} "bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}-linux-gnu.tar.gz"

# Copy UI build artifacts from ui-builder
COPY --from=ui-builder /usr/src/jam/build /app

# Copy Python virtual environment from venv-builder
COPY --from=venv-builder /opt/venv /opt/venv

# Configure PATH to include /opt/venv/bin
ENV PATH="/opt/venv/bin:${PATH}"
ENV DATADIR=/root/.joinmarket-ng
ENV JMWALLETD_HOST=0.0.0.0
ENV JMWALLETD_NO_TLS=true
ENV TOR__SOCKS_HOST=127.0.0.1
ENV TOR__SOCKS_PORT=9050
ENV TOR__CONTROL_HOST=127.0.0.1
ENV TOR__CONTROL_PORT=9051
ENV TOR__COOKIE_PATH=/var/lib/tor/control_auth_cookie
ENV OBWATCH_URL=http://127.0.0.1:8000

# Copy upstream service definitions from joinmarket-ng repository
COPY --from=venv-builder /build/jmwalletd/rootfs/etc/s6-overlay /etc/s6-overlay

# Copy local nginx service definition
COPY s6-overlay/ /etc/s6-overlay/

# Ensure all run scripts are executable
RUN chmod +x \
    /etc/s6-overlay/s6-rc.d/tor/run \
    /etc/s6-overlay/s6-rc.d/tor-ready/up \
    /etc/s6-overlay/s6-rc.d/jmwalletd-svc/run \
    /etc/s6-overlay/s6-rc.d/obwatcher/run \
    /etc/s6-overlay/s6-rc.d/nginx-svc/run

# Copy nginx configuration
COPY nginx/snippets/proxy-params.conf /etc/nginx/snippets/proxy-params.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
# Remove the default nginx site that conflicts with our config
RUN rm -f /etc/nginx/sites-enabled/default

# Copy logrotate configuration
COPY --chmod=0644 logrotate/ /etc/logrotate.d/

# Copy torrc configuration
COPY torrc /etc/tor/torrc

# Copy entrypoint script
COPY jam-ng-entrypoint.sh /usr/local/bin/jam-ng-entrypoint.sh
RUN chmod +x /usr/local/bin/jam-ng-entrypoint.sh

# Create log directories and fix tor data directory ownership
# (Debian's tor package creates /var/lib/tor owned by debian-tor; we run tor as root)
RUN mkdir -p /var/log/jam-ng/jmwalletd \
    && mkdir -p /var/log/jam-ng/obwatcher \
    && mkdir -p /var/log/jam-ng/tor \
    && mkdir -p /var/lib/logrotate \
    && chown root:root /var/lib/tor \
    && chmod 700 /var/lib/tor

# Expose HTTP port
EXPOSE 80

# Set Docker labels
LABEL maintainer="${MAINTAINER}"
LABEL ui-version="${JAM_REPO_REF}"
LABEL server-version="${JM_NG_REPO_REF}"

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/jam-ng-entrypoint.sh"]
# --- Runtime stage - end
