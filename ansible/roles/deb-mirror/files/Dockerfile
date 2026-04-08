FROM localhost/debian:13-slim

# Install aptly and dependencies
RUN apt-get update && \
    apt-get install -y \
        aptly \
        gnupg2 \
        gpgv \
        ca-certificates \
        xz-utils \
        bzip2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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
