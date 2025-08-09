# Dockerfile for building custom Kairos base image
# This follows the official Kairos documentation for creating custom cloud images
# Integrates storage and enterprise features from existing homelab configuration

FROM quay.io/kairos/ubuntu:24.04-standard-amd64-generic-v3.2.0-k3sv1.32.3-k3s1

# Set environment variables
ENV KAIROS_VERSION=v3.2.0
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
ENV KAIROS_CUSTOM=true

# Configure timezone (America/Chicago)
RUN truncate -s0 /tmp/preseed.cfg; \
    echo "tzdata tzdata/Areas select America" >> /tmp/preseed.cfg; \
    echo "tzdata tzdata/Zones/America select Chicago" >> /tmp/preseed.cfg; \
    debconf-set-selections /tmp/preseed.cfg && \
    rm -f /etc/timezone /etc/localtime && \
    apt-get update && \
    apt-get install -y tzdata

# Install essential packages including storage and enterprise tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    ca-certificates \
    software-properties-common \
    systemd \
    systemd-resolved \
    dbus \
    openssh-server \
    cloud-init \
    cifs-utils \
    nfs-common \
    open-iscsi \
    lsscsi \
    sg3-utils \
    multipath-tools \
    scsitools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure multipath for storage (from original Dockerfile)
RUN tee /etc/multipath.conf <<-'EOF'
defaults {
    user_friendly_names yes
    find_multipaths yes
}
EOF

# Install Kairos init system (not needed for official Kairos base images)
# RUN curl -sfL https://raw.githubusercontent.com/kairos-io/kairos/master/install.sh | sh

# Configure systemd for container usage
RUN systemctl enable systemd-networkd \
    && systemctl enable systemd-resolved \
    && systemctl enable ssh \
    && systemctl enable cloud-init \
    && systemctl enable open-iscsi \
    && systemctl enable multipathd

# Create kairos user
RUN useradd -m -s /bin/bash kairos \
    && echo "kairos:kairos" | chpasswd \
    && usermod -aG sudo kairos \
    && echo "kairos ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Configure SSH
RUN mkdir -p /home/kairos/.ssh \
    && chown kairos:kairos /home/kairos/.ssh \
    && chmod 700 /home/kairos/.ssh

# Create Kairos directories
RUN mkdir -p /etc/kairos \
    && mkdir -p /var/lib/kairos \
    && mkdir -p /opt/kairos \
    && mkdir -p /system/oem

# Copy enterprise configuration templates
COPY scripts/ /opt/kairos/scripts/
RUN chmod +x /opt/kairos/scripts/*.sh

# Set up cloud-init for Kairos
RUN mkdir -p /etc/cloud/cloud.cfg.d
COPY kairos/cloud-config.yaml /etc/cloud/cloud.cfg.d/99-kairos-custom.cfg

# Configure Kairos for enterprise use
RUN echo "enterprise_mode: true" > /etc/kairos/config.yaml \
    && echo "auto_install: true" >> /etc/kairos/config.yaml \
    && echo "k3s_enabled: true" >> /etc/kairos/config.yaml

# Set working directory
WORKDIR /

# Configure container to run systemd
CMD ["/sbin/init"]

# Final cleanup (from original Dockerfile)
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Labels for image identification
LABEL org.opencontainers.image.title="Custom Kairos Enterprise Base"
LABEL org.opencontainers.image.description="Enterprise-ready Kairos base image with K3s HA support and storage features"
LABEL org.opencontainers.image.version="${KAIROS_VERSION}"
LABEL org.opencontainers.image.vendor="Beyond DevOps OS Factory"
LABEL org.opencontainers.image.source="https://github.com/beyond-devops-os-factory"
LABEL org.opencontainers.image.licenses="Apache-2.0"