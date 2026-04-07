# Repository Mirror Server

Enterprise-grade repository mirror server providing dual RPM and DEB package mirrors with full multi-architecture support for local networks.

## Overview

This project deploys and manages a centralized repository mirror server that hosts both Rocky Linux 10 (RPM) and Ubuntu 24.04 (DEB) repositories. It eliminates external bandwidth usage for package installations and updates while providing consistent, reliable package access for both air-gapped and internet-connected environments.

**Key Capabilities:**
- **Dual Repository Type Support**: Native RPM and containerized DEB repositories
- **Multi-Architecture**: Full support for x86_64/amd64 and aarch64/arm64
- **Automated Synchronization**: Daily scheduled updates from upstream mirrors
- **Production-Ready**: Monitoring, alerting, and automated management
- **Client Automation**: Scripts for easy client configuration

## Features

- **RPM Repositories** (Native on Rocky Linux)
  - Rocky Linux 10: BaseOS, AppStream, Extras
  - EPEL 10
  - Managed with `dnf reposync` and `createrepo_c`

- **DEB Repositories** (Containerized Aptly)
  - Ubuntu 24.04 (Noble): main, restricted, universe, multiverse + updates + security
  - Docker CE repository
  - NVIDIA CUDA repositories
  - xtradeb/apps PPA

- **Multi-Architecture Support**
  - x86_64/amd64: Intel/AMD 64-bit processors
  - aarch64/arm64: ARM 64-bit processors (AWS Graviton, Ampere Altra)
  - Automatic architecture detection on clients

- **Infrastructure**
  - NGINX web server (direct serving + Aptly proxy)
  - Podman containers for DEB repository management
  - Systemd timers for automated synchronization
  - Prometheus monitoring with custom metrics
  - Ansible automation for deployment

## Quick Start

### Deploy the Mirror Server

```bash
# On your control node/workstation
cd ansible

# Configure inventory
vim inventory/production/hosts.yml

# Configure variables
vim inventory/group_vars/repo_servers.yml

# Deploy
ansible-playbook playbooks/deploy-repo-mirror.yml
```

See [ansible/README.md](ansible/README.md) for detailed deployment instructions.

### Configure Client Systems

**Rocky Linux / RHEL:**
```bash
curl -O http://repo-mirror.local/configure-rocky-client.sh
chmod +x configure-rocky-client.sh
sudo ./configure-rocky-client.sh repo-mirror.local
```

**Ubuntu / Debian:**
```bash
curl -O http://repo-mirror.local/configure-ubuntu-client.sh
chmod +x configure-ubuntu-client.sh
sudo ./configure-ubuntu-client.sh repo-mirror.local
```

See [CLIENT_SETUP.md](CLIENT_SETUP.md) for detailed client configuration instructions.

## Architecture

### Multi-Architecture Support

This repository mirror server provides **full multi-architecture support** for both RPM and DEB repositories.

#### Architecture Matrix

| Repository | x86_64/amd64 | aarch64/arm64 | Notes |
|------------|:------------:|:-------------:|-------|
| **RPM Repositories** ||||
| Rocky Linux 10 BaseOS | ✅ | ✅ | Full mirror |
| Rocky Linux 10 AppStream | ✅ | ✅ | Full mirror |
| Rocky Linux 10 Extras | ✅ | ✅ | Full mirror |
| EPEL 10 | ✅ | ✅ | Full mirror |
| **DEB Repositories** ||||
| Ubuntu 24.04 (noble) | ✅ | ✅ | All components |
| Ubuntu Updates | ✅ | ✅ | All components |
| Ubuntu Security | ✅ | ✅ | All components |
| Docker CE | ✅ | ✅ | Official Docker repo |
| NVIDIA CUDA | ✅ | ✅ | Separate repos per arch |
| xtradeb/apps PPA | ✅ | ❌ | amd64 only (upstream limitation) |

#### Storage Requirements by Architecture

**RPM Repositories:**
```
Rocky Linux 10:
  x86_64:   ~50-60 GB
  aarch64:  ~50-60 GB
  Total:    ~100-120 GB

EPEL 10:
  x86_64:   ~30-40 GB
  aarch64:  ~30-40 GB
  Total:    ~60-80 GB

RPM Grand Total: ~160-200 GB
```

**DEB Repositories:**
```
Ubuntu 24.04 (all components + updates + security):
  Combined amd64 + arm64: ~200-300 GB

Docker CE:
  Combined amd64 + arm64: ~20-30 GB

NVIDIA CUDA:
  amd64:  ~25-50 GB
  arm64:  ~25-50 GB
  Total:  ~50-100 GB

xtradeb/apps PPA:
  amd64:  ~5-10 GB
  (arm64 not available)

DEB Grand Total: ~300-450 GB
```

**Overall Total:**
- **RPM**: ~160-200 GB
- **DEB**: ~300-450 GB
- **Buffer**: ~150-200 GB
- **Grand Total**: **1.5TB - 2TB recommended**

#### Bandwidth Estimates

**Initial Sync (both architectures):**
- Rocky 10 (x86_64 + aarch64): ~100-120 GB (3-6 hours @ 100Mbps)
- EPEL 10 (x86_64 + aarch64): ~60-80 GB (2-4 hours @ 100Mbps)
- Ubuntu 24.04 (amd64 + arm64): ~200-300 GB (6-10 hours @ 100Mbps)
- Docker CE: ~20-30 GB (1-2 hours @ 100Mbps)
- NVIDIA CUDA: ~50-100 GB (2-4 hours @ 100Mbps)
- **Total**: ~550-750 GB (16-30 hours @ 100Mbps)

**Daily Updates (both architectures):**
- Rocky 10: ~1-4 GB
- EPEL 10: ~0.5-2 GB
- Ubuntu 24.04: ~1-3 GB
- Docker CE: ~0.1-0.5 GB
- NVIDIA CUDA: ~0.2-0.8 GB
- **Total**: ~3-10 GB/day

#### Benefits of Multi-Architecture Support

✅ **Single Mirror** - One server serves both x86_64 and ARM64 clients
✅ **Unified Management** - Same sync schedule for all architectures
✅ **Consistent Versions** - All architectures get the same package versions
✅ **Automatic Detection** - Clients automatically get correct architecture
✅ **Future-Proof** - Ready for ARM server adoption
✅ **Cost Effective** - Shared infrastructure and bandwidth

#### How Architecture Selection Works

**RPM Clients (Rocky/RHEL):**

The `$basearch` variable automatically resolves to the correct architecture:

```bash
# Configuration works for both architectures
baseurl=http://repo-mirror.local/rpm/rocky/10/BaseOS/$basearch

# On x86_64 systems resolves to: /rpm/rocky/10/BaseOS/x86_64/
# On aarch64 systems resolves to: /rpm/rocky/10/BaseOS/aarch64/
```

**DEB Clients (Ubuntu/Debian):**

Aptly automatically serves the correct architecture based on the client's `dpkg --print-architecture`:

```bash
# Configuration works for both architectures
deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/ noble main

# APT automatically selects:
# - amd64 packages on x86_64 systems
# - arm64 packages on aarch64 systems
```

### Hybrid Architecture Design

The server uses a hybrid approach optimized for each repository type:

- **RPM repositories**: Managed natively on Rocky Linux host
  - Uses `dnf reposync` and `createrepo_c`
  - Zero overhead, direct filesystem access
  - Easier troubleshooting and native performance

- **DEB repositories**: Containerized using Podman + Aptly
  - Aptly requires Debian-based dependencies
  - Well-tested on Ubuntu, maintains compatibility
  - Isolation from host system
  - Runs in Ubuntu container via Podman

- **Web serving**: NGINX
  - Directly serves RPM repositories from filesystem
  - Proxies DEB requests to containerized Aptly
  - Single endpoint for all clients

## Repository Details

### RPM Repository Structure

```
/repos/rpm/
├── rocky/10/
│   ├── BaseOS/
│   │   ├── x86_64/
│   │   └── aarch64/
│   ├── AppStream/
│   │   ├── x86_64/
│   │   └── aarch64/
│   └── extras/
│       ├── x86_64/
│       └── aarch64/
└── epel/10/
    ├── x86_64/
    └── aarch64/
```

**Synchronization:**
- Automated via systemd timer (daily at 2 AM)
- Script: `/usr/local/bin/rpm-sync.sh`
- Logs: `/var/log/repo-sync/rpm-sync.log`

### DEB Repository Structure

```
/repos/deb/
├── ubuntu-noble/       # Main Ubuntu 24.04 mirror
├── docker-noble/       # Docker CE packages
├── nvidia-amd64/       # NVIDIA CUDA (x86_64)
├── nvidia-arm64/       # NVIDIA CUDA (ARM64)
└── xtradeb-apps/       # xtradeb/apps PPA
```

**Synchronization:**
- Automated via systemd timer (daily at 3 AM)
- Script: `/usr/local/bin/deb-sync.sh`
- Logs: `/var/log/repo-sync/deb-sync.log`

### Client Access URLs

**RPM Repositories:**
- Rocky BaseOS: `http://repo-mirror.local/rpm/rocky/10/BaseOS/$basearch`
- Rocky AppStream: `http://repo-mirror.local/rpm/rocky/10/AppStream/$basearch`
- Rocky Extras: `http://repo-mirror.local/rpm/rocky/10/extras/$basearch`
- EPEL: `http://repo-mirror.local/rpm/epel/10/$basearch`

**DEB Repositories:**
- Ubuntu 24.04: `http://repo-mirror.local/deb/ noble main`
- Docker CE: `http://repo-mirror.local/deb/docker-noble noble stable`
- NVIDIA CUDA (amd64): `http://repo-mirror.local/deb/nvidia-amd64 /`
- NVIDIA CUDA (arm64): `http://repo-mirror.local/deb/nvidia-arm64 /`

## Directory Structure

```
repo-server/
├── ansible/                    # Ansible deployment automation
│   ├── inventory/             # Inventory configuration
│   ├── playbooks/             # Ansible playbooks
│   ├── roles/                 # Ansible roles
│   └── README.md              # Deployment guide
│
├── client-scripts/            # Client configuration scripts
│   ├── configure-rocky-client.sh
│   ├── configure-ubuntu-client.sh
│   └── README.md              # Client script reference
│
├── docs/                      # Historical documentation
│   └── IMPLEMENTATION_PLAN.md # Original design document
│
├── CLAUDE.md                  # Claude Code instructions
├── CLIENT_SETUP.md            # Client configuration guide
└── README.md                  # This file
```

## Documentation

- **[ansible/README.md](ansible/README.md)** - Server deployment with Ansible
  - Prerequisites and requirements
  - Deployment instructions
  - Configuration options
  - Troubleshooting

- **[CLIENT_SETUP.md](CLIENT_SETUP.md)** - Client configuration guide
  - Quick start for Rocky Linux and Ubuntu clients
  - Manual configuration instructions
  - Verification steps
  - Troubleshooting common issues

- **[client-scripts/README.md](client-scripts/README.md)** - Client scripts reference
  - Script usage and options
  - Advanced features
  - Examples

- **[CLAUDE.md](CLAUDE.md)** - Claude Code instructions
  - Project context and guidelines
  - Code standards and best practices
  - Documentation requirements
  - Testing and commit workflow

- **[docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)** - Historical design document
  - Original implementation planning
  - Architecture decisions
  - Design rationale

## Monitoring & Maintenance

### Monitoring

The mirror server includes Prometheus monitoring with:
- **Node Exporter**: System metrics (CPU, memory, disk, network)
- **Custom Metrics**: Repository sync status and statistics
  - Last sync timestamp
  - Sync duration
  - Repository size
  - Sync success/failure status

Metrics endpoint: `http://repo-mirror.local:9100/metrics`

### Health Checks

**Quick health check:**
```bash
curl http://repo-mirror.local/health
```

**Check repository availability:**
```bash
# RPM
curl -I http://repo-mirror.local/rpm/rocky/10/BaseOS/x86_64/repodata/repomd.xml

# DEB
curl -I http://repo-mirror.local/deb/dists/noble/Release
```

### Log Files

- **RPM sync logs**: `/var/log/repo-sync/rpm-sync.log`
- **DEB sync logs**: `/var/log/repo-sync/deb-sync.log`
- **NGINX access logs**: `/var/log/nginx/access.log`
- **NGINX error logs**: `/var/log/nginx/error.log`
- **Aptly container logs**: `podman logs aptly-server`

### Manual Synchronization

**Trigger RPM sync:**
```bash
sudo systemctl start rpm-sync.service
```

**Trigger DEB sync:**
```bash
sudo systemctl start deb-sync.service
```

**Check sync status:**
```bash
sudo systemctl status rpm-sync.service
sudo systemctl status deb-sync.service
```

## Configuration

### Modifying Mirrored Architectures

To add or remove architectures, edit `ansible/inventory/group_vars/repo_servers.yml`:

```yaml
# RPM architectures
repo_rpm_architectures:
  - x86_64
  - aarch64

# DEB architectures
repo_deb_architectures:
  - amd64
  - arm64
```

Then re-run the Ansible playbook to apply changes.

### Modifying Sync Schedule

Edit `ansible/inventory/group_vars/repo_servers.yml`:

```yaml
# Sync schedule (systemd timer format)
repo_rpm_sync_schedule: "02:00"  # 2 AM daily
repo_deb_sync_schedule: "03:00"  # 3 AM daily
```

Then re-run the Ansible playbook to update timers.

## Prerequisites

### For Mirror Server

- **OS**: Rocky Linux 10 (or Rocky 9, RHEL 9+)
- **Storage**: 1.5TB minimum (2TB recommended for multi-arch)
- **RAM**: 8GB minimum (16GB recommended)
- **CPU**: 4 cores minimum
- **Network**: 100Mbps+ internet connection
- **Ports**: 80 (HTTP), 9100 (Prometheus metrics)

### For Control Node (Deployment)

- **Ansible**: 2.9+ (ansible-core)
- **SSH**: Key-based authentication to target server
- **Python**: 3.6+ with required modules

### For Client Systems

- **Rocky Linux**: Version 10 (or 9, 8)
- **Ubuntu**: Version 24.04 (Noble)
- **Architectures**: x86_64/amd64 or aarch64/arm64
- **Network**: Access to mirror server

## Contributing

Contributions are welcome! Please ensure:

1. Test changes thoroughly in a non-production environment
2. Update documentation to reflect changes
3. Follow existing code style and conventions
4. Add comments for complex logic

## Support

For issues, questions, or contributions:

1. Check existing documentation in this repository
2. Review log files for error messages
3. Test connectivity and configuration
4. File detailed issue reports with:
   - System information (OS, version, architecture)
   - Error messages and logs
   - Steps to reproduce
   - Expected vs actual behavior

## License

This project is provided as-is for internal use. Adjust licensing as appropriate for your organization.

---

**Last Updated**: 2026-04-07
