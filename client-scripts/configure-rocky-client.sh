#!/bin/bash
#
# Rocky Linux / RHEL Repository Mirror Client Configuration Script
#
# This script configures Rocky Linux, RHEL, or CentOS systems to use a local
# repository mirror instead of upstream repositories.
#
# Usage: sudo ./configure-rocky-client.sh [OPTIONS] <mirror-server>
#
# Options:
#   --dry-run            Preview changes without applying them
#   --disable-upstream   Disable upstream repositories (air-gapped mode)
#   --keep-upstream      Keep upstream repositories enabled (default)
#   --verbose            Show detailed output
#   --help               Show this help message
#
# Example:
#   sudo ./configure-rocky-client.sh repo-mirror.local
#   sudo ./configure-rocky-client.sh --dry-run --disable-upstream 192.168.1.100
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
MIRROR_SERVER=""
BACKUP_DIR="/etc/yum.repos.d/backup"
REPO_FILE="/etc/yum.repos.d/local-mirror.repo"

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
Rocky Linux / RHEL Repository Mirror Client Configuration Script

Usage: sudo $0 [OPTIONS] <mirror-server>

Options:
    --dry-run            Preview changes without applying them
    --disable-upstream   Disable upstream repositories (air-gapped mode)
    --keep-upstream      Keep upstream repositories enabled (default)
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

    case "$ID" in
        rocky|rhel|centos)
            if [ "${VERSION_ID%%.*}" != "10" ]; then
                print_warning "This script is designed for version 10, but detected version $VERSION_ID"
                read -p "Continue anyway? (y/N) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
            ;;
        *)
            print_error "Unsupported distribution: $ID"
            print_error "This script supports Rocky Linux, RHEL, and CentOS"
            exit 1
            ;;
    esac
}

# Detect system architecture
detect_architecture() {
    ARCH=$(uname -m)
    print_verbose "Detected architecture: $ARCH"

    case "$ARCH" in
        x86_64|aarch64)
            print_info "Architecture: $ARCH"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            print_error "This script supports x86_64 and aarch64"
            exit 1
            ;;
    esac
}

# Check connectivity to mirror server
check_connectivity() {
    print_info "Checking connectivity to mirror server: $MIRROR_SERVER"

    # Test HTTP connectivity
    if ! curl -s -f -m 10 "http://${MIRROR_SERVER}/health" > /dev/null 2>&1; then
        print_warning "Cannot reach http://${MIRROR_SERVER}/health"
        print_info "Trying to reach repository metadata..."

        # Try to reach repository metadata as fallback
        if ! curl -s -f -m 10 "http://${MIRROR_SERVER}/rpm/rocky/10/BaseOS/${ARCH}/repodata/repomd.xml" > /dev/null 2>&1; then
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

# Backup existing repository files
backup_existing_repos() {
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would backup existing repo files to: $BACKUP_DIR"
        return
    fi

    print_info "Backing up existing repository files..."

    # Create backup directory with timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR_TIMESTAMPED="${BACKUP_DIR}/${TIMESTAMP}"

    mkdir -p "$BACKUP_DIR_TIMESTAMPED"

    # Backup all .repo files
    if ls /etc/yum.repos.d/*.repo > /dev/null 2>&1; then
        cp /etc/yum.repos.d/*.repo "$BACKUP_DIR_TIMESTAMPED/" 2>/dev/null || true
        print_success "Backed up repository files to: $BACKUP_DIR_TIMESTAMPED"
    else
        print_warning "No existing .repo files found to backup"
    fi
}

# Create local mirror repository configuration
create_mirror_repo() {
    print_info "Creating local mirror repository configuration..."

    REPO_CONTENT="# Local Repository Mirror
# Generated by configure-rocky-client.sh on $(date)
# Mirror Server: $MIRROR_SERVER

[local-baseos]
name=Local Mirror - Rocky Linux 10 BaseOS
baseurl=http://${MIRROR_SERVER}/rpm/rocky/10/BaseOS/\$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[local-appstream]
name=Local Mirror - Rocky Linux 10 AppStream
baseurl=http://${MIRROR_SERVER}/rpm/rocky/10/AppStream/\$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[local-extras]
name=Local Mirror - Rocky Linux 10 Extras
baseurl=http://${MIRROR_SERVER}/rpm/rocky/10/extras/\$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[local-epel]
name=Local Mirror - EPEL 10
baseurl=http://${MIRROR_SERVER}/rpm/epel/10/\$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-10
"

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would create: $REPO_FILE"
        echo "$REPO_CONTENT"
        return
    fi

    echo "$REPO_CONTENT" > "$REPO_FILE"
    chmod 644 "$REPO_FILE"
    print_success "Created: $REPO_FILE"

    print_verbose "Repository configuration:"
    print_verbose "$(cat $REPO_FILE)"
}

# Disable upstream repositories
disable_upstream_repos() {
    if [ "$DISABLE_UPSTREAM" != true ]; then
        print_info "Keeping upstream repositories enabled (use --disable-upstream to disable)"
        return
    fi

    print_info "Disabling upstream repositories..."

    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would disable upstream repositories"
        return
    fi

    # Disable Rocky/RHEL base repos
    for repo_file in /etc/yum.repos.d/rocky*.repo /etc/yum.repos.d/rhel*.repo; do
        if [ -f "$repo_file" ] && [ "$repo_file" != "$REPO_FILE" ]; then
            print_verbose "Disabling: $repo_file"
            sed -i 's/^enabled=1/enabled=0/g' "$repo_file"
        fi
    done

    # Disable EPEL repo
    if [ -f /etc/yum.repos.d/epel.repo ]; then
        print_verbose "Disabling: /etc/yum.repos.d/epel.repo"
        sed -i 's/^enabled=1/enabled=0/g' /etc/yum.repos.d/epel.repo
    fi

    print_success "Upstream repositories disabled"
}

# Refresh repository cache
refresh_cache() {
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY-RUN] Would run: dnf clean all && dnf makecache"
        return
    fi

    print_info "Refreshing repository cache..."

    dnf clean all > /dev/null 2>&1 || true

    if dnf makecache; then
        print_success "Repository cache refreshed successfully"
    else
        print_error "Failed to refresh repository cache"
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

    if dnf repolist | grep -q "local-"; then
        print_success "Local mirror repositories are active"

        if [ "$VERBOSE" = true ]; then
            echo
            dnf repolist
        fi
    else
        print_warning "Local mirror repositories not found in repolist"
        print_warning "Run 'dnf repolist' to verify configuration"
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "Rocky Linux Repository Mirror Configuration"
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
    backup_existing_repos
    create_mirror_repo
    disable_upstream_repos
    refresh_cache
    verify_configuration

    echo
    print_success "Configuration complete!"

    if [ "$DRY_RUN" = true ]; then
        print_info "Run without --dry-run to apply changes"
    else
        echo
        print_info "Your system is now configured to use the local repository mirror"
        print_info "Test with: dnf install -y vim"

        if [ "$DISABLE_UPSTREAM" != true ]; then
            echo
            print_warning "Upstream repositories are still enabled"
            print_info "Use --disable-upstream flag for air-gapped environments"
        fi

        echo
        print_info "To revert to upstream repositories:"
        print_info "  1. Remove: $REPO_FILE"
        print_info "  2. Restore from: $BACKUP_DIR"
        print_info "  3. Run: dnf clean all && dnf makecache"
    fi
}

# Run main function
main "$@"
