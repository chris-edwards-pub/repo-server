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

# Create entrypoint script to handle missing repositories
RUN echo '#!/bin/bash\n\
set -e\n\
# Check if any published repositories exist\n\
if ! aptly publish list -config=/root/.aptly/aptly.conf 2>/dev/null | grep -q "."; then\n\
    echo "No published repositories yet. Waiting for initial sync..."\n\
    # Keep container running but don'\''t serve\n\
    while true; do\n\
        if aptly publish list -config=/root/.aptly/aptly.conf 2>/dev/null | grep -q "."; then\n\
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
