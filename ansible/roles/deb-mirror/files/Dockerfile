FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

# Install dependencies and download aptly binary
RUN microdnf install -y \
        tar \
        xz \
        gzip \
        gnupg2 \
        ca-certificates && \
    microdnf clean all

# Download and install aptly binary (no external registry pull needed)
RUN curl -L https://github.com/aptly-dev/aptly/releases/download/v1.5.0/aptly_1.5.0_linux_amd64.tar.gz -o /tmp/aptly.tar.gz && \
    tar xzf /tmp/aptly.tar.gz -C /usr/local/bin --strip-components=1 && \
    rm /tmp/aptly.tar.gz && \
    chmod +x /usr/local/bin/aptly

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
