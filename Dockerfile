# Docker-in-Docker enabled Ubuntu 24.04 with Ansible
# Based on geerlingguy/docker-ubuntu2404-ansible with Docker CE installed

FROM geerlingguy/docker-ubuntu2404-ansible:latest

LABEL maintainer="coderat-collective" \
      description="Ubuntu 24.04 with Ansible and Docker-in-Docker support for Molecule testing"

ARG DEBIAN_FRONTEND=noninteractive

# Install prerequisites and setup Docker repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ssh \
        ca-certificates \
        curl && \
    mkdir -p /etc/apt/keyrings && \
    chmod 0755 /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod 0644 /etc/apt/keyrings/docker.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list && \
    rm -rf /var/lib/apt/lists/*

# Install Docker and related packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-compose-plugin \
        cron \
        python3-docker && \
    rm -rf /var/lib/apt/lists/*

# Configure Docker daemon with VFS storage driver
RUN mkdir -p /etc/docker && \
    echo '{"storage-driver": "vfs"}' > /etc/docker/daemon.json

# Enable Docker and cron services to start automatically with systemd
RUN systemctl enable docker.service && \
    systemctl enable cron.service

# Inherit volumes and CMD from base image
# VOLUME ["/sys/fs/cgroup", "/tmp", "/run"]
# CMD ["/lib/systemd/systemd"]
