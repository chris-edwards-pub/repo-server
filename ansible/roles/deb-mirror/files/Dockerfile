FROM rockylinux:9

# Install EPEL and aptly
RUN dnf install -y epel-release && \
    dnf install -y aptly gnupg2 && \
    dnf clean all

# Create aptly user
RUN useradd -r -s /bin/false -d /aptly aptly

# Create directories
RUN mkdir -p /aptly /root/.aptly && \
    chown -R aptly:aptly /aptly

# Expose aptly API port
EXPOSE 8080

# Set working directory
WORKDIR /aptly

# Default command
CMD ["aptly", "serve", "-listen=:8080"]
