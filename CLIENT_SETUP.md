# Client Configuration Guide

Complete guide for configuring client systems to use the local repository mirror.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Rocky Linux / RHEL Configuration](#rocky-linux--rhel-configuration)
- [Ubuntu / Debian Configuration](#ubuntu--debian-configuration)
- [Advanced Usage](#advanced-usage)
- [Manual Configuration](#manual-configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Reverting to Upstream](#reverting-to-upstream)

---

## Download Methods

Client configuration scripts can be downloaded in two ways:

**Method 1: Direct Download (Recommended)**
```bash
curl -O http://repo-mirror.local/configure-rocky-client.sh
curl -O http://repo-mirror.local/configure-ubuntu-client.sh
```

**Method 2: From Git Repository**
```bash
git clone https://github.com/chris-edwards-pub/repo-server.git
cd repo-server/client-scripts
# Scripts are in this directory
```

---

## Quick Start

### Rocky Linux / RHEL

```bash
# Download the script
curl -O http://repo-mirror.local/configure-rocky-client.sh
chmod +x configure-rocky-client.sh

# Run the configuration (replace repo-mirror.local with your mirror server)
sudo ./configure-rocky-client.sh repo-mirror.local

# Test the configuration
sudo dnf install -y vim
```

### Ubuntu / Debian

```bash
# Download the script
curl -O http://repo-mirror.local/configure-ubuntu-client.sh
chmod +x configure-ubuntu-client.sh

# Run the configuration (replace repo-mirror.local with your mirror server)
sudo ./configure-ubuntu-client.sh repo-mirror.local

# Test the configuration
sudo apt install -y vim
```

---

## Prerequisites

### Required

- **Root or sudo privileges**: Scripts must run with administrative access
- **Network connectivity**: Client must be able to reach the mirror server
- **Supported distributions**:
  - Rocky Linux 10 (x86_64, aarch64)
  - RHEL 10 (x86_64, aarch64)
  - Ubuntu 24.04 (amd64, arm64)

### Optional

- **curl**: Required for downloading scripts and GPG keys (Ubuntu/Debian)
- **Backup space**: Scripts create backups of existing configurations

---

## Rocky Linux / RHEL Configuration

### Automated Configuration

The `configure-rocky-client.sh` script automates the entire configuration process.

#### Basic Usage

```bash
sudo ./configure-rocky-client.sh <mirror-server>
```

**Example:**
```bash
sudo ./configure-rocky-client.sh repo-mirror.local
```

#### Available Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without applying them |
| `--disable-upstream` | Disable upstream repositories (air-gapped mode) |
| `--keep-upstream` | Keep upstream repositories enabled (default) |
| `--verbose` | Show detailed debug output |
| `--help` | Display help message |

#### Usage Examples

**Preview changes before applying:**
```bash
sudo ./configure-rocky-client.sh --dry-run repo-mirror.local
```

**Configure for air-gapped environment:**
```bash
sudo ./configure-rocky-client.sh --disable-upstream 192.168.1.100
```

**Verbose output for debugging:**
```bash
sudo ./configure-rocky-client.sh --verbose repo-mirror.local
```

**Using IP address instead of hostname:**
```bash
sudo ./configure-rocky-client.sh 10.0.1.50
```

### What the Script Does

1. **Validates environment**:
   - Checks for root/sudo privileges
   - Detects distribution (Rocky/RHEL/CentOS) and version
   - Detects architecture (x86_64 or aarch64)

2. **Tests connectivity**:
   - Verifies mirror server is reachable
   - Tests repository metadata availability

3. **Backs up existing configuration**:
   - Creates timestamped backup in `/etc/yum.repos.d/backup/`
   - Preserves all existing `.repo` files

4. **Creates mirror configuration**:
   - Generates `/etc/yum.repos.d/local-mirror.repo`
   - Configures repositories:
     - `local-baseos` - Rocky Linux BaseOS
     - `local-appstream` - Rocky Linux AppStream
     - `local-extras` - Rocky Linux Extras
     - `local-epel` - EPEL packages

5. **Updates repository cache**:
   - Runs `dnf clean all`
   - Runs `dnf makecache`

6. **Verifies configuration**:
   - Checks that local mirror repositories are active

### Repository Configuration

The script creates `/etc/yum.repos.d/local-mirror.repo` with the following content:

```ini
[local-baseos]
name=Local Mirror - Rocky Linux 10 BaseOS
baseurl=http://repo-mirror.local/rpm/rocky/10/BaseOS/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[local-appstream]
name=Local Mirror - Rocky Linux 10 AppStream
baseurl=http://repo-mirror.local/rpm/rocky/10/AppStream/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[local-extras]
name=Local Mirror - Rocky Linux 10 Extras
baseurl=http://repo-mirror.local/rpm/rocky/10/extras/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[local-epel]
name=Local Mirror - EPEL 10
baseurl=http://repo-mirror.local/rpm/epel/10/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-10
```

**Note**: The `$basearch` variable automatically resolves to your system architecture:
- `x86_64` systems → `/rpm/rocky/10/BaseOS/x86_64/`
- `aarch64` systems → `/rpm/rocky/10/BaseOS/aarch64/`

---

## Ubuntu / Debian Configuration

### Automated Configuration

The `configure-ubuntu-client.sh` script automates the entire configuration process.

#### Basic Usage

```bash
sudo ./configure-ubuntu-client.sh <mirror-server>
```

**Example:**
```bash
sudo ./configure-ubuntu-client.sh repo-mirror.local
```

#### Available Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without applying them |
| `--disable-upstream` | Disable upstream repositories (air-gapped mode) |
| `--keep-upstream` | Keep upstream repositories enabled (default) |
| `--enable-nvidia` | Enable NVIDIA CUDA repository (requires server-side setup) |
| `--enable-docker` | Enable Docker CE repository (requires server-side setup) |
| `--verbose` | Show detailed debug output |
| `--help` | Display help message |

#### Usage Examples

**Preview changes before applying:**
```bash
sudo ./configure-ubuntu-client.sh --dry-run repo-mirror.local
```

**Configure for air-gapped environment:**
```bash
sudo ./configure-ubuntu-client.sh --disable-upstream 192.168.1.100
```

**Verbose output for debugging:**
```bash
sudo ./configure-ubuntu-client.sh --verbose repo-mirror.local
```

**Using IP address instead of hostname:**
```bash
sudo ./configure-ubuntu-client.sh 10.0.1.50
```

**Enable NVIDIA CUDA and Docker repositories:**
```bash
sudo ./configure-ubuntu-client.sh --enable-nvidia --enable-docker repo-mirror.local
```

**NVIDIA repository only (for GPU workloads):**
```bash
sudo ./configure-ubuntu-client.sh --enable-nvidia repo-mirror.local
```

**Docker repository only (for container workloads):**
```bash
sudo ./configure-ubuntu-client.sh --enable-docker repo-mirror.local
```

### What the Script Does

1. **Validates environment**:
   - Checks for root/sudo privileges
   - Detects distribution (Ubuntu/Debian) and version
   - Detects architecture (amd64 or arm64)

2. **Tests connectivity**:
   - Verifies mirror server is reachable
   - Tests repository Release file availability

3. **Downloads GPG key**:
   - Fetches public key from mirror server
   - Imports key to `/usr/share/keyrings/local-mirror.gpg`

4. **Backs up existing configuration**:
   - Creates timestamped backup in `/etc/apt/sources.list.d/backup/`
   - Preserves existing sources.list and sources.list.d files

5. **Creates mirror configuration**:
   - Generates `/etc/apt/sources.list.d/local-mirror.list`
   - Optionally generates `/etc/apt/sources.list.d/local-mirror-nvidia.list` (if `--enable-nvidia`)
   - Optionally generates `/etc/apt/sources.list.d/local-mirror-docker.list` (if `--enable-docker`)
   - Configures repositories with GPG verification

6. **Updates package lists**:
   - Runs `apt update`

7. **Verifies configuration**:
   - Checks that local mirror is in active sources

### Repository Configuration

The script creates `/etc/apt/sources.list.d/local-mirror.list`:

```
deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/ noble main
```

And downloads the GPG key to `/usr/share/keyrings/local-mirror.gpg`.

> **⚠️ Server Prerequisites for Optional Repositories**
>
> The NVIDIA and Docker repositories must be enabled and synchronized on the mirror server before configuring clients to use them.
>
> **These repositories are disabled by default.** To enable:
>
> 1. On the mirror server, edit `ansible/inventory/production/group_vars/repo_servers.yml`
> 2. Uncomment the desired repository entries under `deb_mirrors:` section
> 3. Re-run the Ansible deployment:
>    ```bash
>    ansible-playbook -i inventory/production/hosts.yml playbooks/deploy-repo-mirror.yml
>    ```
> 4. Manually trigger the first DEB sync or wait for the scheduled sync:
>    ```bash
>    sudo systemctl start aptly-sync.service
>    ```
> 5. Verify repositories are available at:
>    - `http://repo-mirror.local/deb/docker-noble/`
>    - `http://repo-mirror.local/deb/nvidia-amd64/`
>    - `http://repo-mirror.local/deb/nvidia-arm64/`
> 6. Only after verification, configure clients with `--enable-nvidia` or `--enable-docker`

### Optional Repositories

#### NVIDIA CUDA Repository (`--enable-nvidia`)

For systems with NVIDIA GPUs, enable the CUDA repository:

```bash
sudo ./configure-ubuntu-client.sh --enable-nvidia repo-mirror.local
```

This creates `/etc/apt/sources.list.d/local-mirror-nvidia.list`:

```
# amd64 systems:
deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/nvidia-amd64 /

# arm64 systems:
deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/nvidia-arm64 /
```

**Supported Architectures:**
- **amd64**: x86_64 systems with NVIDIA GPUs
- **arm64**: ARM64 systems with NVIDIA GPUs (e.g., NVIDIA Grace-Hopper)

**Use Cases:**
- Machine learning and AI workloads
- GPU computing (CUDA, cuDNN, TensorRT)
- High-performance computing
- Graphics and rendering

**Example - Install CUDA Toolkit:**
```bash
apt install -y cuda-toolkit
```

#### Docker CE Repository (`--enable-docker`)

For systems requiring Docker, enable the Docker CE repository:

```bash
sudo ./configure-ubuntu-client.sh --enable-docker repo-mirror.local
```

This creates `/etc/apt/sources.list.d/local-mirror-docker.list`:

```
deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/docker-noble noble stable
```

**Supported Architectures:**
- **amd64**: x86_64 systems
- **arm64**: ARM64 systems

**Use Cases:**
- Container orchestration
- Microservices deployment
- Development environments
- CI/CD pipelines

**Example - Install Docker:**
```bash
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### Combined Configuration

Enable both NVIDIA and Docker repositories together:

```bash
sudo ./configure-ubuntu-client.sh --enable-nvidia --enable-docker repo-mirror.local
```

This is ideal for:
- GPU-accelerated containerized workloads
- ML/AI development environments
- NVIDIA Container Toolkit integration

---

## Advanced Usage

### Air-Gapped Environments

For systems without internet access, use the `--disable-upstream` flag to disable all upstream repositories:

**Rocky Linux:**
```bash
sudo ./configure-rocky-client.sh --disable-upstream repo-mirror.local
```

**Ubuntu:**
```bash
sudo ./configure-ubuntu-client.sh --disable-upstream repo-mirror.local
```

This ensures all packages are fetched exclusively from the local mirror.

### Dry-Run Mode

Test configuration changes before applying them:

```bash
# Rocky Linux
sudo ./configure-rocky-client.sh --dry-run repo-mirror.local

# Ubuntu
sudo ./configure-ubuntu-client.sh --dry-run repo-mirror.local
```

Dry-run mode shows:
- Configuration files that would be created
- Backups that would be made
- Commands that would be executed
- No actual changes are applied

### Verbose Debugging

Enable detailed output for troubleshooting:

```bash
# Rocky Linux
sudo ./configure-rocky-client.sh --verbose repo-mirror.local

# Ubuntu
sudo ./configure-ubuntu-client.sh --verbose repo-mirror.local
```

Verbose mode shows:
- Distribution and version detection details
- Architecture detection
- Connectivity test results
- File operations
- Repository verification details

### Using with Automation

Scripts are designed to be idempotent and safe for automation:

```bash
# Ansible example
- name: Configure Rocky Linux clients for local mirror
  script: configure-rocky-client.sh repo-mirror.local
  become: yes

# Shell script example
for host in client1 client2 client3; do
    ssh root@$host 'bash -s' < configure-rocky-client.sh repo-mirror.local
done
```

---

## Manual Configuration

If you prefer to configure clients manually or if the automated scripts don't work for your environment, follow these instructions.

### Rocky Linux / RHEL Manual Configuration

1. **Backup existing repositories:**
   ```bash
   sudo mkdir -p /etc/yum.repos.d/backup
   sudo cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/
   ```

2. **Create local mirror repository file:**
   ```bash
   sudo tee /etc/yum.repos.d/local-mirror.repo > /dev/null << 'EOF'
   [local-baseos]
   name=Local Mirror - Rocky Linux 10 BaseOS
   baseurl=http://repo-mirror.local/rpm/rocky/10/BaseOS/$basearch
   enabled=1
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

   [local-appstream]
   name=Local Mirror - Rocky Linux 10 AppStream
   baseurl=http://repo-mirror.local/rpm/rocky/10/AppStream/$basearch
   enabled=1
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

   [local-extras]
   name=Local Mirror - Rocky Linux 10 Extras
   baseurl=http://repo-mirror.local/rpm/rocky/10/extras/$basearch
   enabled=1
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

   [local-epel]
   name=Local Mirror - EPEL 10
   baseurl=http://repo-mirror.local/rpm/epel/10/$basearch
   enabled=1
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-10
   EOF
   ```

3. **Disable upstream repositories (optional):**
   ```bash
   sudo sed -i 's/^enabled=1/enabled=0/g' /etc/yum.repos.d/rocky*.repo
   sudo sed -i 's/^enabled=1/enabled=0/g' /etc/yum.repos.d/epel.repo
   ```

4. **Refresh repository cache:**
   ```bash
   sudo dnf clean all
   sudo dnf makecache
   ```

5. **Verify configuration:**
   ```bash
   sudo dnf repolist
   ```

### Ubuntu / Debian Manual Configuration

1. **Backup existing sources:**
   ```bash
   sudo mkdir -p /etc/apt/sources.list.d/backup
   sudo cp /etc/apt/sources.list /etc/apt/sources.list.d/backup/
   ```

2. **Download and install GPG key:**
   ```bash
   curl http://repo-mirror.local/public.key | \
     sudo gpg --dearmor -o /usr/share/keyrings/local-mirror.gpg
   ```

3. **Create local mirror source:**
   ```bash
   echo "deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/ noble main" | \
     sudo tee /etc/apt/sources.list.d/local-mirror.list
   ```

4. **Disable upstream repositories (optional):**
   ```bash
   sudo sed -i 's/^deb /#deb /g' /etc/apt/sources.list
   sudo sed -i 's/^deb-src /#deb-src /g' /etc/apt/sources.list
   ```

5. **Update package lists:**
   ```bash
   sudo apt update
   ```

6. **Verify configuration:**
   ```bash
   apt-cache policy
   ```

---

## Verification

### Rocky Linux / RHEL Verification

**1. Check repository list:**
```bash
dnf repolist
```

Expected output should include:
- `local-baseos`
- `local-appstream`
- `local-extras`
- `local-epel`

**2. Check repository configuration:**
```bash
dnf repolist -v | grep baseurl
```

Should show URLs pointing to your mirror server.

**3. Test package installation:**
```bash
sudo dnf install --downloadonly vim
```

**4. Verify package source:**
```bash
dnf info vim | grep "From repo"
```

Should show `local-baseos` or `local-appstream`.

### Ubuntu / Debian Verification

**1. Check package sources:**
```bash
apt-cache policy
```

Should show your mirror server in the package files list.

**2. Check specific package source:**
```bash
apt-cache policy vim
```

Should show URLs pointing to your mirror server.

**3. Test package installation:**
```bash
sudo apt install --download-only vim
```

**4. Verify GPG key:**
```bash
ls -l /usr/share/keyrings/local-mirror.gpg
```

Should show the imported GPG key file.

---

## Troubleshooting

### Common Issues

#### Cannot Reach Mirror Server

**Symptoms:**
- Script fails with "Cannot reach mirror server" error
- Connection timeout errors

**Solutions:**
1. Verify mirror server is running:
   ```bash
   curl http://repo-mirror.local/health
   ```

2. Check network connectivity:
   ```bash
   ping repo-mirror.local
   ```

3. Verify firewall rules:
   ```bash
   # On mirror server
   sudo firewall-cmd --list-all
   ```

4. Check DNS resolution:
   ```bash
   nslookup repo-mirror.local
   # or
   host repo-mirror.local
   ```

#### GPG Key Verification Failed (Rocky/RHEL)

**Symptoms:**
- `dnf` commands fail with GPG verification errors
- "GPG key retrieval failed" messages

**Solutions:**
1. Verify GPG keys are present:
   ```bash
   ls -l /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10
   ls -l /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-10
   ```

2. Import keys manually if missing:
   ```bash
   sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10
   sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-10
   ```

3. Temporarily disable GPG check (not recommended for production):
   ```bash
   # Edit /etc/yum.repos.d/local-mirror.repo
   # Change gpgcheck=1 to gpgcheck=0
   ```

#### GPG Key Import Failed (Ubuntu/Debian)

**Symptoms:**
- Cannot download public key from mirror
- `apt update` fails with GPG errors

**Solutions:**
1. Manually download and inspect the key:
   ```bash
   curl http://repo-mirror.local/public.key
   ```

2. Verify key format and import:
   ```bash
   curl http://repo-mirror.local/public.key | \
     sudo gpg --dearmor -o /usr/share/keyrings/local-mirror.gpg
   ```

3. Check permissions:
   ```bash
   sudo chmod 644 /usr/share/keyrings/local-mirror.gpg
   ```

#### Repository Metadata Not Found

**Symptoms:**
- `dnf makecache` fails
- `apt update` fails with 404 errors

**Solutions:**
1. Verify repository structure on mirror server:
   ```bash
   # Rocky/RHEL
   curl http://repo-mirror.local/rpm/rocky/10/BaseOS/x86_64/repodata/repomd.xml

   # Ubuntu
   curl http://repo-mirror.local/deb/dists/noble/Release
   ```

2. Check mirror synchronization status on mirror server

3. Verify architecture matches:
   ```bash
   # Rocky/RHEL
   uname -m

   # Ubuntu
   dpkg --print-architecture
   ```

#### Wrong Architecture

**Symptoms:**
- Packages not found
- Architecture mismatch errors

**Solutions:**
1. Verify your system architecture:
   ```bash
   # Rocky/RHEL
   uname -m  # Should be x86_64 or aarch64

   # Ubuntu
   dpkg --print-architecture  # Should be amd64 or arm64
   ```

2. Check repository configuration uses `$basearch` (Rocky/RHEL)

3. Verify mirror has packages for your architecture

#### Script Permission Denied

**Symptoms:**
- "Permission denied" when running script
- Script won't execute

**Solutions:**
1. Make script executable:
   ```bash
   chmod +x configure-rocky-client.sh
   # or
   chmod +x configure-ubuntu-client.sh
   ```

2. Run with sudo:
   ```bash
   sudo ./configure-rocky-client.sh repo-mirror.local
   ```

### Testing Connectivity

#### Test Mirror Server Health

```bash
# General health check
curl http://repo-mirror.local/health

# Rocky/RHEL repository check
curl -I http://repo-mirror.local/rpm/rocky/10/BaseOS/x86_64/repodata/repomd.xml

# Ubuntu repository check
curl -I http://repo-mirror.local/deb/dists/noble/Release

# GPG key check
curl -I http://repo-mirror.local/public.key
```

#### Test Package Installation

**Rocky/RHEL:**
```bash
# Download only (doesn't install)
sudo dnf install --downloadonly --downloaddir=/tmp vim

# Full installation
sudo dnf install -y vim
```

**Ubuntu:**
```bash
# Download only
sudo apt install --download-only vim

# Full installation
sudo apt install -y vim
```

### Getting Help

If you continue to experience issues:

1. **Enable verbose mode:**
   ```bash
   sudo ./configure-rocky-client.sh --verbose repo-mirror.local
   sudo ./configure-ubuntu-client.sh --verbose repo-mirror.local
   ```

2. **Check system logs:**
   ```bash
   # Rocky/RHEL
   sudo journalctl -u dnf -n 50

   # Ubuntu
   sudo cat /var/log/apt/term.log
   ```

3. **Verify configuration files:**
   ```bash
   # Rocky/RHEL
   cat /etc/yum.repos.d/local-mirror.repo

   # Ubuntu
   cat /etc/apt/sources.list.d/local-mirror.list
   ```

---

## Reverting to Upstream

If you need to revert to using upstream repositories:

### Rocky Linux / RHEL

**Option 1: Remove local mirror configuration**
```bash
# Remove local mirror repo file
sudo rm /etc/yum.repos.d/local-mirror.repo

# Re-enable upstream repos (if they were disabled)
sudo sed -i 's/^enabled=0/enabled=1/g' /etc/yum.repos.d/rocky*.repo
sudo sed -i 's/^enabled=0/enabled=1/g' /etc/yum.repos.d/epel.repo

# Refresh cache
sudo dnf clean all
sudo dnf makecache
```

**Option 2: Restore from backup**
```bash
# Find your backup
ls -lt /etc/yum.repos.d/backup/

# Restore all repo files (adjust timestamp as needed)
sudo cp /etc/yum.repos.d/backup/20260407_120000/*.repo /etc/yum.repos.d/

# Remove local mirror configuration
sudo rm /etc/yum.repos.d/local-mirror.repo

# Refresh cache
sudo dnf clean all
sudo dnf makecache
```

### Ubuntu / Debian

**Option 1: Remove local mirror configuration**
```bash
# Remove local mirror source
sudo rm /etc/apt/sources.list.d/local-mirror.list

# Remove GPG key
sudo rm /usr/share/keyrings/local-mirror.gpg

# Re-enable upstream repos (if they were disabled)
sudo sed -i 's/^#deb /deb /g' /etc/apt/sources.list

# Update package lists
sudo apt update
```

**Option 2: Restore from backup**
```bash
# Find your backup
ls -lt /etc/apt/sources.list.d/backup/

# Restore sources.list (adjust timestamp as needed)
sudo cp /etc/apt/sources.list.d/backup/20260407_120000/sources.list /etc/apt/sources.list

# Remove local mirror configuration
sudo rm /etc/apt/sources.list.d/local-mirror.list
sudo rm /usr/share/keyrings/local-mirror.gpg

# Update package lists
sudo apt update
```

### Verification After Revert

**Rocky/RHEL:**
```bash
dnf repolist
# Should show upstream repositories (rocky-baseos, rocky-appstream, etc.)
```

**Ubuntu:**
```bash
apt-cache policy
# Should show official Ubuntu mirrors
```

---

## Architecture Support

### Rocky Linux / RHEL

- **x86_64**: Full support for Intel/AMD 64-bit processors
- **aarch64**: Full support for ARM 64-bit processors (e.g., AWS Graviton, Ampere Altra)

The `$basearch` variable in repository URLs automatically resolves to the correct architecture.

### Ubuntu / Debian

- **amd64**: Full support for Intel/AMD 64-bit processors
- **arm64**: Full support for ARM 64-bit processors

The scripts automatically detect and configure for the appropriate architecture.

---

## Security Considerations

### GPG Verification

Both automated scripts enable GPG verification by default:

- **Rocky/RHEL**: Uses system GPG keys in `/etc/pki/rpm-gpg/`
- **Ubuntu**: Downloads and verifies GPG key from mirror server

**Important**: Always verify GPG keys are properly configured to prevent package tampering.

### Air-Gapped Environments

For secure, isolated environments:

1. Use `--disable-upstream` flag to prevent internet access
2. Verify all required packages are available on local mirror
3. Test package installation before full deployment
4. Implement network policies to block external repository access

### HTTPS Support

The scripts currently use HTTP. To enable HTTPS:

1. Configure mirror server with SSL/TLS certificates
2. Update repository URLs to use `https://` instead of `http://`
3. Ensure SSL certificates are trusted on client systems

---

## Additional Resources

- **Repository Mirror Documentation**: See `ansible/README.md` for mirror server setup
- **Script Source**: All scripts are available in `client-scripts/` directory
- **Manual Configuration Examples**: See `client-scripts/examples/` directory

---

**Last Updated**: 2026-04-14
