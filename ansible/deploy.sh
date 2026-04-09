#!/bin/bash
# Quick deployment script for repository mirror server
# Usage: ./deploy.sh [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK="playbooks/deploy-repo-mirror.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
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

# Show usage
usage() {
    cat <<EOF
Repository Mirror Deployment Script

Usage: $0 [options]

Deployment Modes:
    Local (default)         Deploy to localhost (no SSH required)
    Remote                  Deploy to remote server (requires -i flag)

    Note: For remote deployment, pass inventory with ansible-playbook -i flag

Options:
    -h, --help              Show this help message
    -c, --check             Run in check mode (dry-run)
    -v, --verbose           Enable verbose output (-vvv)
    -t, --tags TAGS         Run only specific tags (comma-separated)
    -s, --skip-tags TAGS    Skip specific tags (comma-separated)
    --test                  Test connectivity only (ping)
    --install-deps          Install Ansible collections

Available Tags:
    Role-level tags:
      common                Base system setup (packages, firewall, SELinux)
      storage               Repository directory structure creation
      rpm                   RPM mirror setup (Rocky + EPEL sync scripts)
      deb                   DEB mirror setup (Aptly container + sync)
      nginx                 Web server configuration
      monitoring            Prometheus metrics and exporters
      validate              Post-deployment validation checks

    Component-level tags:
      packages              Install system packages only
      firewall              Configure firewall rules only
      selinux               Configure SELinux contexts only
      filesystem            Directory creation only
      gpg                   GPG key generation only
      container             Podman container setup only

Examples:
    # Localhost deployment (default)
    $0                              # Full deployment to localhost
    $0 --check                      # Localhost dry-run (no changes)
    $0 --tags rpm,nginx             # Deploy only RPM and NGINX to localhost
    $0 --verbose                    # Verbose output (-vvv)

    # Remote deployment (use ansible-playbook directly with -i flag)
    # ansible-playbook playbooks/deploy-repo-mirror.yml -i inventory/production/hosts.yml
    # ansible-playbook playbooks/deploy-repo-mirror.yml -i inventory/production/hosts.yml --check

    # Common usage
    $0 --tags deb                   # Deploy only DEB/Aptly
    $0 --tags common,storage,rpm    # Deploy base + RPM only
    $0 --skip-tags monitoring       # Skip monitoring setup
    $0 --skip-tags validate         # Skip validation checks

Common Tag Combinations:
    --tags common,storage           # Prepare system only
    --tags rpm,nginx                # RPM repos + web server
    --tags deb,nginx                # DEB repos + web server
    --tags common,storage,rpm       # Base system + RPM only
    --tags monitoring               # Add monitoring to existing setup
    --skip-tags monitoring,validate # Quick deployment without extras

EOF
    exit 0
}

# Check requirements
check_requirements() {
    print_info "Checking requirements..."

    # Check if ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed!"
        echo "Install with: sudo dnf install -y ansible-core"
        echo "Or: pip install ansible"
        exit 1
    fi

    # Check if inventory exists
    if [ ! -f "$SCRIPT_DIR/inventory/localhost/hosts.yml" ]; then
        print_error "Localhost inventory file not found!"
        echo "Create inventory/localhost/hosts.yml first"
        exit 1
    fi

    print_success "Requirements check passed"
}

# Install collections
install_deps() {
    print_info "Installing Ansible Galaxy collections..."
    cd "$SCRIPT_DIR"
    ansible-galaxy collection install -r requirements.yml
    print_success "Collections installed"
}

# Test connectivity
test_connectivity() {
    print_info "Testing connectivity to target servers..."
    cd "$SCRIPT_DIR"
    if ansible repo_servers -m ping; then
        print_success "Connectivity test passed"
    else
        print_error "Connectivity test failed"
        exit 1
    fi
}

# Main deployment
deploy() {
    local ansible_args=()

    # Add check mode if requested
    if [ "$CHECK_MODE" = true ]; then
        ansible_args+=(--check)
        print_info "Running in CHECK MODE (dry-run)"
    fi

    # Add verbose if requested
    if [ "$VERBOSE" = true ]; then
        ansible_args+=(-vvv)
    fi

    # Add tags if specified
    if [ -n "$TAGS" ]; then
        ansible_args+=(--tags "$TAGS")
        print_info "Running only tags: $TAGS"
    fi

    # Add skip-tags if specified
    if [ -n "$SKIP_TAGS" ]; then
        ansible_args+=(--skip-tags "$SKIP_TAGS")
        print_info "Skipping tags: $SKIP_TAGS"
    fi

    print_info "Starting deployment..."
    cd "$SCRIPT_DIR"

    if ansible-playbook "$PLAYBOOK" "${ansible_args[@]}"; then
        print_success "Deployment completed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Access your repository mirror:"
        echo "   - RPM repos: http://<server-ip>/rpm/"
        echo "   - DEB repos: http://<server-ip>/deb/"
        echo ""
        echo "2. Trigger initial sync:"
        echo "   ssh <server> 'sudo systemctl start rpm-sync.service'"
        echo "   ssh <server> 'sudo systemctl start aptly-sync.service'"
        echo ""
        echo "3. Monitor sync progress:"
        echo "   ssh <server> 'sudo journalctl -u rpm-sync.service -f'"
        echo ""
    else
        print_error "Deployment failed!"
        exit 1
    fi
}

# Parse arguments
CHECK_MODE=false
VERBOSE=false
TAGS=""
SKIP_TAGS=""
TEST_ONLY=false
INSTALL_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -c|--check)
            CHECK_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--tags)
            TAGS="$2"
            shift 2
            ;;
        -s|--skip-tags)
            SKIP_TAGS="$2"
            shift 2
            ;;
        --test)
            TEST_ONLY=true
            shift
            ;;
        --install-deps)
            INSTALL_ONLY=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Main execution
cd "$SCRIPT_DIR"

echo ""
echo "======================================"
echo "Repository Mirror Deployment"
echo "======================================"
echo ""

# Install dependencies if requested
if [ "$INSTALL_ONLY" = true ]; then
    install_deps
    exit 0
fi

# Check requirements
check_requirements

# Test connectivity if requested
if [ "$TEST_ONLY" = true ]; then
    test_connectivity
    exit 0
fi

# Run deployment
deploy
