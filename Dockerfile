FROM didstopia/base:nodejs-steamcmd-ubuntu-16.04
LABEL maintainer "Didstopia <support@didstopia.com>"

# Fix apt-get warnings
ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    expect \
    tcl \
    libgdiplus && \
    rm -rf /var/lib/apt/lists/*

# Create and set the steamcmd folder as a volume
RUN mkdir -p /steamcmd/rust
VOLUME ["/steamcmd/rust"]

# Setup Node scripts and install dependencies
ADD rust_docker_control/ /rust_docker_control/
WORKDIR /rust_docker_control
RUN npm install

# Add the steamcmd installation script
ADD install.txt /install.txt

# Copy the Rust startup script
ADD start_rust.sh /start_rust.sh

# Copy the Rust update check script
ADD update_check.sh /update_check.sh

# Set the current working directory
WORKDIR /

# Expose necessary ports
EXPOSE 28015
EXPOSE 28016

# Setup default environment variables for the server
ENV RUST_SERVER_STARTUP_ARGUMENTS "-batchmode -load +server.secure 1"
ENV RUST_SERVER_IDENTITY "docker"
ENV RUST_SERVER_SEED "12345"
ENV RUST_SERVER_NAME "Rust Server [DOCKER]"
ENV RUST_SERVER_DESCRIPTION "This is a Rust server running inside a Docker container!"
ENV RUST_SERVER_URL "https://hub.docker.com/r/didstopia/rust-server/"
ENV RUST_SERVER_BANNER_URL ""
ENV RUST_RCON_WEB "1"
ENV RUST_RCON_PORT "28016"
ENV RUST_RCON_PASSWORD "docker"
ENV RUST_UPDATE_CHECKING "0"
ENV RUST_UPDATE_BRANCH "public"
ENV RUST_START_MODE "0"
ENV RUST_OXIDE_ENABLED "0"
ENV RUST_OXIDE_UPDATE_ON_BOOT "1"
ENV RUST_SERVER_WORLDSIZE "3500"
ENV RUST_SERVER_MAXPLAYERS "500"
ENV RUST_SERVER_SAVE_INTERVAL "600"

# Start the server
ENTRYPOINT ["./start_rust.sh"]
