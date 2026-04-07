#!/bin/bash
#
# Ubuntu / Debian Repository Mirror Client Configuration Script
#
# This script configures Ubuntu or Debian systems to use a local
# repository mirror instead of upstream repositories.
#
# Usage: sudo ./configure-ubuntu-client.sh [OPTIONS] <mirror-server>
#
# Options:
#   --dry-run            Preview changes without applying them
#   --disable-upstream   Disable upstream repositories (air-gapped mode)
#   --keep-upstream      Keep upstream repositories enabled (default)
#   --enable-nvidia      Enable NVIDIA CUDA repository
#   --enable-docker      Enable Docker CE repository
#   --verbose            Show detailed output
#   --help               Show this help message
#
# Example:
#   sudo ./configure-ubuntu-client.sh repo-mirror.local
#   sudo ./configure-ubuntu-client.sh --dry-run --disable-upstream 192.168.1.100
#   sudo ./configure-ubuntu-client.sh --enable-nvidia --enable-docker repo-mirror.local
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
DISABLE_UPSTREAM=false
VERBOSE=false
ENABLE_NVIDIA=false
ENABLE_DOCKER=false
MIRROR_SERVER=""
BACKUP_DIR="/etc/apt/sources.list.d/backup"
SOURCES_FILE="/etc/apt/sources.list.d/local-mirror.list"
NVIDIA_SOURCES_FILE="/etc/apt/sources.list.d/local-mirror-nvidia.list"
DOCKER_SOURCES_FILE="/etc/apt/sources.list.d/local-mirror-docker.list"
GPG_KEYRING="/usr/share/keyrings/local-mirror.gpg"

# Print functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Show usage
show_usage() {
    cat << EOF
Ubuntu / Debian Repository Mirror Client Configuration Script

Usage: sudo $0 [OPTIONS] <mirror-server>

Options:
    --dry-run            Preview changes without applying them
    --disable-upstream   Disable upstream repositories (air-gapped mode)
    --keep-upstream      Keep upstream repositories enabled (default)
    --enable-nvidia      Enable NVIDIA CUDA repository configuration
    --enable-docker      Enable Docker CE repository configuration
    --verbose            Show detailed output
    --help               Show this help message

Arguments:
    mirror-server        Hostname or IP address of the repository mirror server

Examples:
    # Basic usage
    sudo $0 repo-mirror.local

    # Preview changes without applying
    sudo $0 --dry-run repo-mirror.local

    # Configure for air-gapped environment
    sudo $0 --disable-upstream 192.168.1.100

    # Enable NVIDIA CUDA and Docker repositories
    sudo $0 --enable-nvidia --enable-docker repo-mirror.local

    # Verbose output
    sudo $0 --verbose repo-mirror.local

EOF
    exit 0
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --disable-upstream)
                DISABLE_UPSTREAM=true
                shift
                ;;
            --keep-upstream)
                DISABLE_UPSTREAM=false
                shift
                ;;
            --enable-nvidia)
                ENABLE_NVIDIA=true
                shift
                ;;
            --enable-docker)
                ENABLE_DOCKER=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                if [ -z "$MIRROR_SERVER" ]; then
                    MIRROR_SERVER="$1"
                else
                    print_error "Multiple mirror servers specified"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$MIRROR_SERVER" ]; then
        print_error "Mirror server hostname or IP is required"
        echo "Use --help for usage information"
        exit 1
    fi
}

# Detect distribution and version
detect_distribution() {
    if [ ! -f /etc/os-release ]; then
        print_error "Cannot detect distribution: /etc/os-release not found"
        exit 1
    fi

    source /etc/os-release

    print_verbose "Detected OS: $NAME"
    print_verbose "Version: $VERSION_ID"
    print_verbose "Codename: $VERSION_CODENAME"

    case "$ID" in
        ubuntu)
            RELEASE_CODENAME="$VERSION_CODENAME"
            if [ "$VERSION_CODENAME" != "noble" ]; then
                print_warning "This script is designed for Ubuntu 24.04 (noble), but detected $VERSION_CODENAME"
                read -p "Continue anyway? (y/N) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
            ;;
        debian)
            RELEASE_CODENAME="$VERSION_CODENAME"
            print_warning "This script is designed for Ubuntu, but will attempt configuration for Debian"
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported distribution: $ID"
            print_error "This script supports Ubuntu and Debian"
            exit 1
            ;;
    esac
}

# Detect system architecture
detect_architecture() {
    ARCH=$(dpkg --print-architecture)
    print_verbose "Detected architecture: $ARCH"

    case "$ARCH" in
        amd64|arm64)
            print_info "Architecture: $ARCH"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            print_error "This script supports amd64 and arm64"
            exit 1
            ;;
    esac
}

# Check connectivity to mirror server
check_connectivity() {
    print_info "Checking connectivity to mirror server: $MIRROR_SERVER"

    # Check if curl is available
    if ! command -v curl > /dev/null 2>&1; then
        print_error "curl is not installed. Please install it first: apt install curl"
        exit 1
    fi

    # Test HTTP connectivity
    if ! curl -s -f -m 10 "http://${MIRROR_SERVER}/health" > /dev/null 2>&1; then
        print_warning "Cannot reach http://${MIRROR_SERVER}/health"
        print_info "Trying to reach repository metadata..."

        # Try to reach repository Release file as fallback
        if ! curl -s -f -m 10 "http://${MIRROR_SERVER}/deb/dists/${RELEASE_CODENAME}/Release" > /dev/null 2>&1; then
            print_error "Cannot reach mirror server at http://${MIRROR_SERVER}"
            print_error "Please verify:"
            print_error "  1. The mirror server is running"
            print_error "  2. The hostname/IP is correct"
            print_error "  3. Network connectivity exists"
            exit 1
        fi
    fi

    print_success "Mirror server is reachable"
}

# Download and import GPG key
download_gpg_key() {
    print_info "Downloading GPG public key from mirror server..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would download GPG key from: http://${MIRROR_SERVER}/public.key"
        print_info "[DRY-RUN] Would save to: $GPG_KEYRING"
        return
    fi

    # Create keyring directory if it doesn't exist
    mkdir -p "$(dirname "$GPG_KEYRING")"

    # Download and convert GPG key
    if curl -fsSL "http://${MIRROR_SERVER}/public.key" | gpg --dearmor -o "$GPG_KEYRING" 2>/dev/null; then
        chmod 644 "$GPG_KEYRING"
        print_success "GPG key downloaded and installed"
        print_verbose "GPG key location: $GPG_KEYRING"
    else
        print_error "Failed to download or import GPG key"
        print_error "Please verify the mirror server is serving the public key at /public.key"
        exit 1
    fi
}

# Backup existing sources
backup_existing_sources() {
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would backup existing sources to: $BACKUP_DIR"
        return
    fi

    print_info "Backing up existing sources..."

    # Create backup directory with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR_TIMESTAMPED="${BACKUP_DIR}/${TIMESTAMP}"

    mkdir -p "$BACKUP_DIR_TIMESTAMPED"

    # Backup sources.list
    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list "$BACKUP_DIR_TIMESTAMPED/sources.list"
        print_success "Backed up /etc/apt/sources.list"
    fi

    # Backup sources.list.d
    if [ -d /etc/apt/sources.list.d ] && [ -n "$(ls -A /etc/apt/sources.list.d/*.list 2>/dev/null)" ]; then
        cp /etc/apt/sources.list.d/*.list "$BACKUP_DIR_TIMESTAMPED/" 2>/dev/null || true
        print_success "Backed up sources.list.d files"
    fi

    print_success "Backups saved to: $BACKUP_DIR_TIMESTAMPED"
}

# Create local mirror sources configuration
create_mirror_sources() {
    print_info "Creating local mirror sources configuration..."

    SOURCES_CONTENT="# Local Repository Mirror
# Generated by configure-ubuntu-client.sh on $(date)
# Mirror Server: $MIRROR_SERVER

deb [signed-by=${GPG_KEYRING}] http://${MIRROR_SERVER}/deb/ ${RELEASE_CODENAME} main
"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would create: $SOURCES_FILE"
        echo "$SOURCES_CONTENT"
        return
    fi

    # Create sources.list.d directory if it doesn't exist
    mkdir -p /etc/apt/sources.list.d

    echo "$SOURCES_CONTENT" > "$SOURCES_FILE"
    chmod 644 "$SOURCES_FILE"
    print_success "Created: $SOURCES_FILE"

    print_verbose "Sources configuration:"
    print_verbose "$(cat $SOURCES_FILE)"
}

# Create NVIDIA CUDA sources configuration
create_nvidia_sources() {
    if [ "$ENABLE_NVIDIA" != true ]; then
        return
    fi

    print_info "Creating NVIDIA CUDA repository configuration..."

    # NVIDIA uses different upstream paths for amd64 vs arm64
    # amd64: ubuntu2404/x86_64
    # arm64: ubuntu2404/sbsa
    NVIDIA_DIST_PATH="ubuntu2404"
    if [ "$ARCH" = "arm64" ]; then
        NVIDIA_ARCH_PATH="sbsa"
    else
        NVIDIA_ARCH_PATH="x86_64"
    fi

    NVIDIA_CONTENT="# NVIDIA CUDA Repository (Local Mirror)
# Generated by configure-ubuntu-client.sh on $(date)
# Mirror Server: $MIRROR_SERVER

deb [signed-by=${GPG_KEYRING}] http://${MIRROR_SERVER}/deb/nvidia-${ARCH} /
"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would create: $NVIDIA_SOURCES_FILE"
        echo "$NVIDIA_CONTENT"
        return
    fi

    mkdir -p /etc/apt/sources.list.d
    echo "$NVIDIA_CONTENT" > "$NVIDIA_SOURCES_FILE"
    chmod 644 "$NVIDIA_SOURCES_FILE"
    print_success "Created: $NVIDIA_SOURCES_FILE"

    print_verbose "NVIDIA sources configuration:"
    print_verbose "$(cat $NVIDIA_SOURCES_FILE)"
}

# Create Docker CE sources configuration
create_docker_sources() {
    if [ "$ENABLE_DOCKER" != true ]; then
        return
    fi

    print_info "Creating Docker CE repository configuration..."

    DOCKER_CONTENT="# Docker CE Repository (Local Mirror)
# Generated by configure-ubuntu-client.sh on $(date)
# Mirror Server: $MIRROR_SERVER

deb [signed-by=${GPG_KEYRING}] http://${MIRROR_SERVER}/deb/docker-${RELEASE_CODENAME} ${RELEASE_CODENAME} stable
"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would create: $DOCKER_SOURCES_FILE"
        echo "$DOCKER_CONTENT"
        return
    fi

    mkdir -p /etc/apt/sources.list.d
    echo "$DOCKER_CONTENT" > "$DOCKER_SOURCES_FILE"
    chmod 644 "$DOCKER_SOURCES_FILE"
    print_success "Created: $DOCKER_SOURCES_FILE"

    print_verbose "Docker sources configuration:"
    print_verbose "$(cat $DOCKER_SOURCES_FILE)"
}

# Disable upstream repositories
disable_upstream_sources() {
    if [ "$DISABLE_UPSTREAM" != true ]; then
        print_info "Keeping upstream repositories enabled (use --disable-upstream to disable)"
        return
    fi

    print_info "Disabling upstream repositories..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would disable upstream repositories in /etc/apt/sources.list"
        return
    fi

    # Disable sources in sources.list by commenting them out
    if [ -f /etc/apt/sources.list ]; then
        print_verbose "Disabling entries in: /etc/apt/sources.list"
        sed -i 's/^deb /#deb /g' /etc/apt/sources.list
        sed -i 's/^deb-src /#deb-src /g' /etc/apt/sources.list
        print_success "Upstream repositories disabled in sources.list"
    fi

    # Disable other sources (except our local mirror)
    for source_file in /etc/apt/sources.list.d/*.list; do
        if [ -f "$source_file" ] && [ "$source_file" != "$SOURCES_FILE" ]; then
            print_verbose "Disabling: $source_file"
            sed -i 's/^deb /#deb /g' "$source_file"
            sed -i 's/^deb-src /#deb-src /g' "$source_file"
        fi
    done

    print_success "Upstream repositories disabled"
}

# Refresh package lists
refresh_cache() {
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would run: apt update"
        return
    fi

    print_info "Refreshing package lists..."

    if apt update; then
        print_success "Package lists updated successfully"
    else
        print_error "Failed to update package lists"
        print_error "Please check the mirror server configuration"
        exit 1
    fi
}

# Verify configuration
verify_configuration() {
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would verify repository configuration"
        return
    fi

    print_info "Verifying repository configuration..."

    # Check if our mirror is in the sources
    if apt-cache policy | grep -q "http://${MIRROR_SERVER}"; then
        print_success "Local mirror repository is active"

        if [ "$VERBOSE" = true ]; then
            echo
            apt-cache policy
        fi
    else
        print_warning "Local mirror repository not found in apt sources"
        print_warning "Run 'apt-cache policy' to verify configuration"
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "Ubuntu Repository Mirror Configuration"
    echo "=========================================="
    echo

    parse_args "$@"
    check_root

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY-RUN MODE: No changes will be applied"
        echo
    fi

    detect_distribution
    detect_architecture
    check_connectivity
    backup_existing_sources
    download_gpg_key
    create_mirror_sources
    create_nvidia_sources
    create_docker_sources
    disable_upstream_sources
    refresh_cache
    verify_configuration

    echo
    print_success "Configuration complete!"

    if [ "$DRY_RUN" = true ]; then
        print_info "Run without --dry-run to apply changes"
    else
        echo
        print_info "Your system is now configured to use the local repository mirror"

        if [ "$ENABLE_NVIDIA" = true ]; then
            print_info "✓ NVIDIA CUDA repository enabled"
        fi

        if [ "$ENABLE_DOCKER" = true ]; then
            print_info "✓ Docker CE repository enabled"
        fi

        echo
        print_info "Test with: apt install -y vim"

        if [ "$DISABLE_UPSTREAM" != true ]; then
            echo
            print_warning "Upstream repositories are still enabled"
            print_info "Use --disable-upstream flag for air-gapped environments"
        fi

        echo
        print_info "To revert to upstream repositories:"
        print_info "  1. Remove: $SOURCES_FILE"
        if [ "$ENABLE_NVIDIA" = true ]; then
            print_info "  2. Remove: $NVIDIA_SOURCES_FILE"
        fi
        if [ "$ENABLE_DOCKER" = true ]; then
            print_info "  3. Remove: $DOCKER_SOURCES_FILE"
        fi
        print_info "  4. Remove: $GPG_KEYRING"
        print_info "  5. Restore from: $BACKUP_DIR"
        print_info "  6. Run: apt update"
    fi
}

# Run main function
main "$@"
