# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

ARG RUST_VERSION=1.76.0
ARG APP_NAME=electrs

################################################################################
# Create a stage for building the application.

FROM rust:${RUST_VERSION}-slim-bookworm as build

ARG APP_NAME
WORKDIR /build

# Install host build dependencies.
RUN apt-get update
RUN apt-get install -y git clang cmake build-essential libsnappy-dev
RUN apt-get install -y librocksdb-dev

# Clone the source code into the container to build.
RUN git clone https://github.com/mempool/electrs .
RUN git checkout mempool

# cargo under QEMU building for ARM can consumes 10s of GBs of RAM...
# Solution: https://users.rust-lang.org/t/cargo-uses-too-much-memory-being-run-in-qemu/76531/2
ENV CARGO_NET_GIT_FETCH_WITH_CLI true

# Build the application.
# Leverage a cache mount to /usr/local/cargo/registry/
# for downloaded dependencies, a cache mount to /usr/local/cargo/git/db
# for git repository dependencies, and a cache mount to /app/target/ for
# compiled dependencies which will speed up subsequent builds.
RUN --mount=type=cache,target=/app/target/ \
    --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/ \
    cargo build --locked --release --bin ${APP_NAME}

################################################################################
# Create a new stage for running the application that contains the minimal
# runtime dependencies for the application. This often uses a different base
# image from the build stage where the necessary files are copied from the build
# stage.
FROM debian:bookworm-slim as final

# Create a non-privileged user that the app will run under.
# See https://docs.docker.com/go/dockerfile-user-best-practices/
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/data" \
    --shell "/sbin/nologin" \
    --uid "${UID}" \
    appuser
USER appuser

WORKDIR /data

# Copy the executable from the "build" stage.
COPY --from=build /build/target/release/${APP_NAME} /bin/${APP_NAME}

# Mainnet
# Electrum RPC 
EXPOSE 50001
# Electrum Rest API
EXPOSE 3000
# Monitoring
EXPOSE 4224

# Testnet
# Electrum RPC
EXPOSE 60001
# Electrum Rest API
EXPOSE 3001
# Monitoring
EXPOSE 14224

# Regtest
# Electrum RPC
EXPOSE 60401
# Electrum Rest API
EXPOSE 3002
# Monitoring
EXPOSE 24224

ENTRYPOINT ["/bin/electrs"]
