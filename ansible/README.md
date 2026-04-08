# Repository Mirror Server - Ansible Deployment

Automated deployment of a dual RPM/DEB repository mirror server for Rocky Linux 10 and Ubuntu 24.04.

## Overview

This Ansible project deploys a complete **multi-architecture** repository mirror server.

### 📦 What Gets Mirrored

**RPM Repositories:**
- Rocky Linux 10: BaseOS, AppStream, Extras
- EPEL 10
- **Architectures**: x86_64 + aarch64 (ARM64)

**DEB Repositories:**
- Ubuntu 24.04 (Noble): main, restricted, universe, multiverse + updates + security
- Docker CE repository
- NVIDIA CUDA repositories
- xtradeb/apps PPA
- **Architectures**: amd64 + arm64

**Total Architecture Support**: Full multi-arch for both x86_64/amd64 and aarch64/arm64 systems!

> 📘 **See [README.md - Architecture](../README.md#architecture) for complete multi-architecture documentation**

### 🏗️ Architecture

- **RPM repos**: Managed natively on Rocky Linux using `dnf reposync` + `createrepo_c`
- **DEB repos**: Containerized Aptly running in Podman
- **Web server**: NGINX (serves RPM directly, proxies to Aptly for DEB)
- **Monitoring**: Prometheus node_exporter with custom metrics
- **Automation**: Systemd timers for daily sync (2 AM RPM, 3 AM DEB)

## Prerequisites

### Control Node (Your Workstation)
```bash
# Install Ansible
sudo dnf install -y ansible-core
# OR
pip install ansible

# Install required collections
ansible-galaxy collection install -r requirements.yml
```

### Target Server
- Rocky Linux 10 (Rocky 9 or RHEL 9+ also supported)
- Minimum 1.5TB disk space (recommended: 2TB for multi-arch)
- Sudo access for deployment user
- SSH key authentication configured

## Quick Start

### 1. Configure Inventory

Edit `inventory/production/hosts.yml`:
```yaml
all:
  children:
    repo_servers:
      hosts:
        repo-mirror-01:                    # CHANGE THIS to match your server hostname
          ansible_host: 192.168.1.100      # CHANGE THIS to your server IP
          ansible_user: ec2-user            # CHANGE THIS if using different user
```

### 2. Configure Variables

Edit `inventory/production/group_vars/repo_servers.yml`:
```yaml
repo_server_hostname: repo-mirror.local  # CHANGE THIS
```

Review and adjust other settings as needed (architectures, schedules, etc.)

### 3. Test Connectivity

```bash
ansible repo_servers -m ping
```

### 4. Deploy

```bash
# Full deployment
ansible-playbook playbooks/deploy-repo-mirror.yml

# Dry-run first (check mode)
ansible-playbook playbooks/deploy-repo-mirror.yml --check

# With verbose output
ansible-playbook playbooks/deploy-repo-mirror.yml -vvv
```

## Deployment Options

### Partial Deployment (Tags)

Deploy only specific components:

```bash
# Only RPM mirror setup
ansible-playbook playbooks/deploy-repo-mirror.yml --tags rpm

# Only DEB mirror setup
ansible-playbook playbooks/deploy-repo-mirror.yml --tags deb

# Only NGINX configuration
ansible-playbook playbooks/deploy-repo-mirror.yml --tags nginx

# Only monitoring
ansible-playbook playbooks/deploy-repo-mirror.yml --tags monitoring
```

Available tags:
- `common` - Base system setup (packages, firewall, SELinux)
- `storage` - Directory structure creation
- `rpm` - RPM mirror configuration (Rocky + EPEL)
- `deb` - DEB mirror configuration (Aptly container + Ubuntu/Docker/NVIDIA)
- `nginx` - Web server configuration
- `monitoring` - Prometheus metrics and exporters
- `validate` - Post-deployment validation

Component-level tags (for fine-grained control):
- `packages` - Install system packages only
- `firewall` - Configure firewall rules only
- `selinux` - Configure SELinux contexts only
- `gpg` - GPG key generation only
- `container` - Podman container setup only

### Skip Components

```bash
# Skip monitoring setup
ansible-playbook playbooks/deploy-repo-mirror.yml --skip-tags monitoring
```

## Post-Deployment

### Access Your Repository Mirror

- **RPM repos**: `http://<server-ip>/rpm/`
- **DEB repos**: `http://<server-ip>/deb/`
- **GPG Public Key**: `http://<server-ip>/public.key`
- **Health Check**: `http://<server-ip>/health`
- **RPM Status**: `http://<server-ip>/status/rpm`
- **DEB Status**: `http://<server-ip>/status/deb`

### Manual Sync

Trigger syncs manually:
```bash
# RPM sync (runs on target server)
sudo systemctl start rpm-sync.service

# DEB sync (runs on target server)
sudo systemctl start aptly-sync.service
```

### Check Sync Logs

```bash
# Watch RPM sync log
sudo journalctl -u rpm-sync.service -f

# Watch DEB sync log
sudo journalctl -u aptly-sync.service -f

# Or read log files directly
sudo tail -f /repos/logs/rpm-sync.log
sudo tail -f /repos/logs/aptly-sync.log
```

### Check Sync Status

```bash
# Check timers
systemctl list-timers | grep sync

# Check services
systemctl status rpm-sync.timer
systemctl status aptly-sync.timer
systemctl status container-aptly
systemctl status nginx
```

## Client Configuration

### Rocky Linux / RHEL Clients

**Note**: The `$basearch` variable automatically resolves to the correct architecture:
- x86_64 systems → `/rpm/rocky/10/BaseOS/x86_64/`
- aarch64 systems → `/rpm/rocky/10/BaseOS/aarch64/`

Create `/etc/yum.repos.d/local-mirror.repo`:
```ini
[local-baseos]
name=Local Mirror - Rocky Linux BaseOS
baseurl=http://repo-mirror.local/rpm/rocky/10/BaseOS/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[local-appstream]
name=Local Mirror - Rocky Linux AppStream
baseurl=http://repo-mirror.local/rpm/rocky/10/AppStream/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[local-extras]
name=Local Mirror - Rocky Linux Extras
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

### Ubuntu / Debian Clients

```bash
# Download and install GPG key
curl http://repo-mirror.local/public.key | sudo gpg --dearmor -o /usr/share/keyrings/local-mirror.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/ noble main" | \
  sudo tee /etc/apt/sources.list.d/local-mirror.list

# Update package list
sudo apt update
```

## Monitoring

### Prometheus Metrics

Metrics are exposed via node_exporter on port 9100:
```bash
curl http://<server-ip>:9100/metrics | grep -E '(rpm_sync|deb_sync)'
```

Available metrics:
- `rpm_sync_success` - Whether last RPM sync succeeded (1=yes, 0=no)
- `rpm_sync_age_seconds` - Time since last RPM sync
- `deb_sync_success` - Whether last DEB sync succeeded (1=yes, 0=no)
- `deb_sync_age_seconds` - Time since last DEB sync

### Alerting Rules (Example for Prometheus)

```yaml
groups:
  - name: repo_mirror
    rules:
      - alert: RPMSyncFailed
        expr: rpm_sync_success == 0
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "RPM repository sync failed"

      - alert: DEBSyncFailed
        expr: deb_sync_success == 0
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "DEB repository sync failed"

      - alert: RPMSyncStale
        expr: rpm_sync_age_seconds > 86400
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "RPM sync is stale (>24 hours)"

      - alert: DEBSyncStale
        expr: deb_sync_age_seconds > 86400
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "DEB sync is stale (>24 hours)"
```

## Storage Requirements

**RPM Repositories:**
- **Rocky Linux 10** (BaseOS + AppStream + Extras):
  - x86_64: ~50-60 GB
  - aarch64: ~50-60 GB
  - **Subtotal**: ~100-120 GB
- **EPEL 10**:
  - x86_64: ~30-40 GB
  - aarch64: ~30-40 GB
  - **Subtotal**: ~60-80 GB
- **RPM Total**: ~160-200 GB

**DEB Repositories:**
- **Ubuntu 24.04** (base + updates + security):
  - amd64 + arm64: ~200-300 GB (both architectures included)
- **Docker CE** (amd64 + arm64): ~20-30 GB
- **NVIDIA CUDA** (amd64 + arm64): ~50-100 GB
- **xtradeb PPA** (amd64 only): ~5-10 GB
- **DEB Total**: ~300-450 GB

**Overhead:**
- **Buffer (20-30%)**: ~150-200 GB
- **Logs and metadata**: ~10-20 GB

**Total Recommended**: 1.5TB - 2TB (with both x86_64 and aarch64)

## Sync Schedules

Default schedules (can be changed in group_vars):
- **RPM sync**: 2:00 AM daily (02:00:00)
- **DEB sync**: 3:00 AM daily (03:00:00)

Systemd timers include a 15-minute randomized delay to avoid clock-exact loads.

## Troubleshooting

### Check System Requirements
```bash
# Disk space
df -h /repos

# OS version
cat /etc/os-release

# SELinux status
getenforce
```

### Common Issues

**Issue**: Container fails to start
```bash
# Check container status
podman ps -a
podman logs aptly

# Restart container
systemctl restart container-aptly
```

**Issue**: NGINX can't proxy to Aptly
```bash
# Check SELinux boolean
getsebool httpd_can_network_connect

# If false, set it:
sudo setsebool -P httpd_can_network_connect on
```

**Issue**: Sync fails due to disk space
```bash
# Check available space
df -h /repos

# Clean old Aptly snapshots
podman exec aptly aptly snapshot list
podman exec aptly aptly snapshot drop <snapshot-name>
```

### Re-running Deployment

The playbook is idempotent - you can run it multiple times safely:
```bash
ansible-playbook playbooks/deploy-repo-mirror.yml
```

## Project Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── requirements.yml         # Galaxy collection dependencies
├── README.md               # This file
├── playbooks/
│   └── deploy-repo-mirror.yml    # Main deployment playbook
├── roles/
│   ├── common/             # Base system setup
│   ├── repo-storage/       # Directory structure
│   ├── rpm-mirror/         # RPM sync scripts & systemd
│   ├── deb-mirror/         # Aptly container & DEB sync
│   ├── nginx/              # Web server configuration
│   └── monitoring/         # Prometheus metrics
└── inventory/
    └── production/
        ├── hosts.yml       # Target servers
        └── group_vars/
            └── repo_servers.yml # Configuration variables
```

## Security Considerations

- GPG keys are generated on first deployment and stored in `/repos/aptly/config/`
- Backup private key: `/repos/aptly/config/private.key`
- SELinux is enforced with appropriate contexts
- Firewall only exposes HTTP/HTTPS (ports 80/443)
- Container runs with security restrictions (no-new-privileges, dropped capabilities)
- NGINX serves with security headers

## Backup Recommendations

**Critical files to backup**:
- `/repos/aptly/config/private.key` - GPG private key for signing
- `/repos/aptly/config/aptly.conf` - Aptly configuration
- Ansible inventory and group_vars (this directory)

**Optional**:
- Repository data can be re-synced from upstream
- Consider backing up `/repos` if bandwidth is limited

## Support

For issues, questions, or contributions:
- Check logs: `/repos/logs/*.log`
- Review systemd journals: `journalctl -u <service-name>`
- Check service status: `systemctl status <service-name>`

## License

Internal use - modify as needed for your organization.
