FROM localhost/debian:13-slim

# Install aptly and dependencies
RUN apt-get update && \
    apt-get install -y \
        aptly \
        gnupg2 \
        gpgv \
        ca-certificates \
        xz-utils \
        bzip2 \
        curl \
        wget \
        ubuntu-keyring \
        debian-keyring && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create aptly user
RUN useradd -r -s /bin/false -d /aptly aptly

# Create directories
RUN mkdir -p /aptly /root/.aptly && \
    chown -R aptly:aptly /aptly

# Import Ubuntu and Debian archive keys into aptly's trusted keyring
RUN gpg --no-default-keyring --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg --export | \
    gpg --no-default-keyring --keyring trustedkeys.gpg --import && \
    gpg --no-default-keyring --keyring /usr/share/keyrings/debian-archive-keyring.gpg --export | \
    gpg --no-default-keyring --keyring trustedkeys.gpg --import

# Expose aptly API port
EXPOSE 8080

# Set working directory
WORKDIR /aptly

# Create entrypoint script to handle missing repositories
RUN echo '#!/bin/bash\n\
set -e\n\
# Function to check for published repositories\n\
has_published_repos() {\n\
    local output=$(aptly publish list -config=/root/.aptly/aptly.conf 2>/dev/null || echo "")\n\
    # Check if output contains actual repo entries (lines starting with filesystem: or s3:)\n\
    echo "$output" | grep -qE "^(filesystem|s3):" && return 0\n\
    # Also check for snapshot references\n\
    echo "$output" | grep -qE "\\[.*\\]" && return 0\n\
    return 1\n\
}\n\
\n\
# Check if any published repositories exist\n\
if ! has_published_repos; then\n\
    echo "No published repositories yet. Waiting for initial sync..."\n\
    # Keep container running and wait for repos\n\
    while true; do\n\
        if has_published_repos; then\n\
            echo "Published repositories detected, starting serve..."\n\
            break\n\
        fi\n\
        sleep 10\n\
    done\n\
fi\n\
# Start aptly serve\n\
exec aptly serve -listen=:8080 -config=/root/.aptly/aptly.conf\n\
' > /usr/local/bin/aptly-entrypoint.sh && \
    chmod +x /usr/local/bin/aptly-entrypoint.sh

# Default command
CMD ["/usr/local/bin/aptly-entrypoint.sh"]
