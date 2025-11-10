FROM ubuntu:22.04

# Build arguments
ARG RUNNER_VERSION=2.329.0
ARG DOCKER_VERSION=24.0.7
ARG DEBIAN_FRONTEND=noninteractive

# Labels
LABEL org.opencontainers.image.title="GitHub Self-Hosted Runner"
LABEL org.opencontainers.image.description="Universal self-hosted GitHub Actions runner with GitHub App support"
LABEL org.opencontainers.image.version="${RUNNER_VERSION}"
LABEL org.opencontainers.image.source="https://github.com/pv-udpv/github-selfhosted-runner"

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    jq \
    ca-certificates \
    sudo \
    openssl \
    libssl-dev \
    libicu-dev \
    libkrb5-3 \
    zlib1g \
    unzip \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for Docker-in-Docker)
RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
    | tar xzvf - --strip 1 -C /usr/local/bin docker/docker && \
    chmod +x /usr/local/bin/docker

# Create runner user
RUN useradd -m -s /bin/bash runner && \
    usermod -aG sudo runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to runner user
USER runner
WORKDIR /home/runner

# Download and extract GitHub Actions Runner
RUN curl -o actions-runner.tar.gz -L \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" && \
    tar xzf actions-runner.tar.gz -C /home/runner && \
    rm actions-runner.tar.gz

# Install runner dependencies
RUN sudo ./bin/installdependencies.sh

# Copy entrypoint script
COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

# Set environment variables
ENV RUNNER_ALLOW_RUNASROOT=0
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV DISABLE_AUTO_UPDATE=true

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "Runner.Listener" || exit 1

# Entrypoint
ENTRYPOINT ["/home/runner/entrypoint.sh"]
