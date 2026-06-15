FROM ubuntu:24.04

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Core tools
RUN apt-get update && apt-get upgrade -y 
RUN apt-get install -y --no-install-recommends \
    git curl wget ca-certificates openssh-server \
    ripgrep fd-find sudo locales \
    gnome-keyring dbus-x11 libsecret-1-0 \
    vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# Fix locale (prevents weird terminal issues)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# fd-find installs as fdfind on Ubuntu
RUN ln -s $(which fdfind) /usr/local/bin/fd

# GitHub CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Node.js (required for Codex CLI)
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
       | tee /etc/apt/sources.list.d/nodesource.list > /dev/null \
    && apt-get update && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Codex CLI
RUN npm install -g @openai/codex

# SSH server setup (key-based auth only)
RUN mkdir -p /run/sshd && \
    sed -i 's/#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# Non-root dev user
RUN useradd -m -s /bin/bash -G sudo dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/dev

# SSH authorized_keys directory + Copilot CLI extension (gh extensions are per-user)
USER dev
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh && mkdir ~/code \
    && gh extension install github/gh-copilot

USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
