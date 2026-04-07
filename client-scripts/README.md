# Client Configuration Scripts

Automated scripts for configuring client systems to use the local repository mirror.

## Quick Start

### Rocky Linux / RHEL

```bash
sudo ./configure-rocky-client.sh repo-mirror.local
```

### Ubuntu / Debian

```bash
sudo ./configure-ubuntu-client.sh repo-mirror.local
```

Replace `repo-mirror.local` with your mirror server's hostname or IP address.

## Available Scripts

| Script | Description |
|--------|-------------|
| `configure-rocky-client.sh` | Configure Rocky Linux, RHEL, or CentOS clients |
| `configure-ubuntu-client.sh` | Configure Ubuntu or Debian clients |

## Features

- ✅ Automated client configuration
- ✅ Automatic backup of existing configurations
- ✅ Support for both x86_64/aarch64 (Rocky) and amd64/arm64 (Ubuntu)
- ✅ Optional NVIDIA CUDA repository (Ubuntu)
- ✅ Optional Docker CE repository (Ubuntu)
- ✅ Dry-run mode for previewing changes
- ✅ Air-gapped environment support
- ✅ Verbose debugging output
- ✅ Idempotent (safe to run multiple times)
- ✅ Color-coded output
- ✅ Comprehensive error handling

## Common Options

**All scripts:**
- `--dry-run` - Preview changes without applying them
- `--disable-upstream` - Disable upstream repositories (air-gapped mode)
- `--verbose` - Show detailed debug output
- `--help` - Display help message

**Ubuntu script only:**
- `--enable-nvidia` - Enable NVIDIA CUDA repository
- `--enable-docker` - Enable Docker CE repository

## Examples

### Preview Changes (Dry-Run)

```bash
# Rocky/RHEL
sudo ./configure-rocky-client.sh --dry-run repo-mirror.local

# Ubuntu
sudo ./configure-ubuntu-client.sh --dry-run repo-mirror.local
```

### Air-Gapped Configuration

```bash
# Rocky/RHEL
sudo ./configure-rocky-client.sh --disable-upstream 192.168.1.100

# Ubuntu
sudo ./configure-ubuntu-client.sh --disable-upstream 192.168.1.100
```

### Verbose Output

```bash
# Rocky/RHEL
sudo ./configure-rocky-client.sh --verbose repo-mirror.local

# Ubuntu
sudo ./configure-ubuntu-client.sh --verbose repo-mirror.local
```

### Ubuntu with NVIDIA and Docker

```bash
# Enable NVIDIA CUDA repository (for GPU workloads)
sudo ./configure-ubuntu-client.sh --enable-nvidia repo-mirror.local

# Enable Docker CE repository (for containers)
sudo ./configure-ubuntu-client.sh --enable-docker repo-mirror.local

# Enable both (ideal for GPU-accelerated containers)
sudo ./configure-ubuntu-client.sh --enable-nvidia --enable-docker repo-mirror.local
```

## Documentation

For comprehensive documentation, troubleshooting, and manual configuration instructions, see:

📖 **[CLIENT_SETUP.md](../CLIENT_SETUP.md)**

## What the Scripts Do

### Rocky Linux / RHEL Script

1. Validates environment (root access, distribution, architecture)
2. Tests connectivity to mirror server
3. Backs up existing repository files
4. Creates `/etc/yum.repos.d/local-mirror.repo` with:
   - Rocky Linux BaseOS
   - Rocky Linux AppStream
   - Rocky Linux Extras
   - EPEL
5. Optionally disables upstream repositories
6. Refreshes repository cache
7. Verifies configuration

### Ubuntu / Debian Script

1. Validates environment (root access, distribution, architecture)
2. Tests connectivity to mirror server
3. Downloads and imports GPG key from mirror
4. Backs up existing sources
5. Creates `/etc/apt/sources.list.d/local-mirror.list`
6. Optionally disables upstream repositories
7. Updates package lists
8. Verifies configuration

## Prerequisites

### Rocky Linux / RHEL

- Rocky Linux 10, RHEL 10, or CentOS 10
- Root or sudo access
- Network connectivity to mirror server
- Architecture: x86_64 or aarch64

### Ubuntu / Debian

- Ubuntu 24.04 (noble) or compatible Debian
- Root or sudo access
- curl installed (`apt install curl`)
- Network connectivity to mirror server
- Architecture: amd64 or arm64

## Verification

After running the scripts, verify the configuration:

### Rocky/RHEL

```bash
dnf repolist
dnf install -y vim
```

### Ubuntu

```bash
apt-cache policy
apt install -y vim
```

## Reverting to Upstream

### Rocky/RHEL

```bash
sudo rm /etc/yum.repos.d/local-mirror.repo
sudo cp /etc/yum.repos.d/backup/*/*.repo /etc/yum.repos.d/
sudo dnf clean all && sudo dnf makecache
```

### Ubuntu

```bash
sudo rm /etc/apt/sources.list.d/local-mirror.list
sudo rm /usr/share/keyrings/local-mirror.gpg
sudo cp /etc/apt/sources.list.d/backup/*/sources.list /etc/apt/sources.list
sudo apt update
```

## Manual Configuration

If the automated scripts don't work for your environment, see the manual configuration examples in:

- `examples/rocky-manual-config.txt`
- `examples/ubuntu-manual-config.txt`

Or refer to the comprehensive guide: [CLIENT_SETUP.md](../CLIENT_SETUP.md#manual-configuration)

## Troubleshooting

Common issues and solutions are documented in [CLIENT_SETUP.md - Troubleshooting](../CLIENT_SETUP.md#troubleshooting).

Quick troubleshooting steps:

1. **Verify mirror server is accessible:**
   ```bash
   curl http://repo-mirror.local/health
   ```

2. **Run in verbose mode:**
   ```bash
   sudo ./configure-*-client.sh --verbose repo-mirror.local
   ```

3. **Check backups:**
   ```bash
   ls -la /etc/yum.repos.d/backup/  # Rocky/RHEL
   ls -la /etc/apt/sources.list.d/backup/  # Ubuntu
   ```

## Support

For detailed information, examples, and troubleshooting:

- 📖 [CLIENT_SETUP.md](../CLIENT_SETUP.md) - Complete documentation
- 📁 [examples/](examples/) - Manual configuration examples
- 📁 [ansible/README.md](../ansible/README.md) - Mirror server documentation

## License

These scripts are provided as-is for configuring systems to use local repository mirrors.
