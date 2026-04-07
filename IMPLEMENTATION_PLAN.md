# Rocky Linux 10 Dual Repository Mirror Server - Implementation Plan

## Context

You need to set up a Rocky Linux server to host both Rocky Linux 10 (RPM) and Ubuntu (DEB) repositories for your local network servers. This will:
- Eliminate external bandwidth usage for package installations/updates
- Provide consistent, reliable package access for air-gapped or restricted networks
- Enable centralized control over package versions and updates
- Support both your Rocky Linux and Ubuntu server infrastructure

Your existing document outlines a solid Aptly setup for Ubuntu/DEB repos. This plan extends that to create a comprehensive dual-repository solution with Ansible automation for **remote execution** from a control node.

**Deployment Model:** Ansible playbook executed manually from a remote control node (your workstation or CI/CD server) to configure an existing Rocky Linux target server.

**Important Note on Rocky Linux 10:**
- Rocky Linux 10 is based on RHEL 10 (release expected in 2025)
- Repository URLs and package names will be adjusted to match Rocky 10 structure
- If Rocky 10 is not yet available in your environment, the Ansible templates can be easily adjusted for Rocky 9 by changing version variables

## Architecture Decision: Hybrid Approach

**Selected Architecture: RPM Tools on Host + DEB in Container**

**Rationale:**
- **RPM repos** will be managed natively on Rocky Linux using `dnf reposync` and `createrepo_c`
  - Zero overhead, native performance
  - Direct filesystem access without container complexity
  - Easier troubleshooting and debugging
- **DEB repos** will remain containerized using Podman + Aptly (Ubuntu container)
  - Aptly requires Debian-based dependencies (dpkg, apt-utils)
  - Well-tested on Ubuntu, maintains compatibility
  - Isolation from host system
  - Your existing document already outlines this approach well

**Why not alternatives:**
- Single container with both tools would create cross-distribution dependency conflicts
- Separate containers for RPM would add unnecessary overhead since RPM tools run perfectly on Rocky Linux

## Directory Structure

```
/repos/
├── rpm/                          # RPM repositories (served directly by NGINX)
│   ├── rocky/
│   │   └── 10/
│   │       ├── BaseOS/
│   │       │   └── x86_64/
│   │       ├── AppStream/
│   │       │   └── x86_64/
│   │       ├── extras/
│   │       │   └── x86_64/
│   │       └── status.json
│   ├── epel/
│   │   └── 10/
│   │       └── x86_64/
│   └── custom/                   # Optional: internal custom RPMs
├── aptly/                        # DEB repositories (your existing structure)
│   ├── config/
│   │   ├── aptly.conf
│   │   ├── public.key
│   │   └── private.key
│   ├── data/
│   └── public/
└── logs/
    ├── rpm-sync.log
    └── aptly-sync.log
```

## Storage Requirements

**RPM Repositories (x86_64 + aarch64):**
- **Rocky Linux 10** (BaseOS + AppStream + Extras):
  - x86_64: ~50-60 GB
  - aarch64: ~50-60 GB
  - **Subtotal**: ~100-120 GB
- **EPEL 10**:
  - x86_64: ~30-40 GB
  - aarch64: ~30-40 GB
  - **Subtotal**: ~60-80 GB
- **RPM Total**: ~160-200 GB

**DEB Repositories (amd64 + arm64):**
- **Ubuntu 24.04** (noble + updates + security):
  - amd64 + arm64: ~200-300 GB (both architectures included)
- **Docker CE** repository (amd64 + arm64): ~20-30 GB
- **NVIDIA CUDA** (amd64 + arm64): ~50-100 GB
- **xtradeb/apps PPA** (amd64 only): ~5-10 GB
- **DEB Total**: ~300-450 GB

**Overhead:**
- **Snapshots & Buffer**: 20-30% additional space
- **Logs and metadata**: ~10-20 GB

**Recommended Total**: 1.5TB - 2TB minimum
**Filesystem**: XFS (recommended) or ext4 with noatime mount option

## Implementation Components

### 1. RPM Mirror Setup (Native on Rocky Linux)

**Packages Required:**
```bash
sudo dnf install -y dnf-plugins-core createrepo_c yum-utils nginx podman
```

**Critical Files:**

#### `/usr/local/bin/rpm-sync.sh`
- Purpose: Syncs Rocky Linux and EPEL repositories using dnf reposync
- Features:
  - Lock file to prevent concurrent runs
  - Uses `--newest-only` flag to save space
  - Regenerates metadata with `createrepo_c --update`
  - Generates status.json for monitoring
  - Comprehensive logging

#### `/etc/systemd/system/rpm-sync.service`
- Service definition for RPM sync
- Includes resource limits (CPU, Memory, I/O)
- Hardening options (PrivateTmp, ProtectSystem, NoNewPrivileges)

#### `/etc/systemd/system/rpm-sync.timer`
- Scheduled at 2:00 AM daily (offset from DEB sync at 3:00 AM)
- 15-minute randomized delay to avoid clock-exact loads
- Persistent=true to catch up after downtime

### 2. DEB Mirror Setup (Containerized Aptly)

**Container Configuration:**
- Ubuntu-based Podman container running Aptly
- Volume mounts: `/repos/aptly/data`, `/repos/aptly/config`, `/repos/aptly/public`
- Systemd service generated via `podman generate systemd --name aptly --files --new`
- Daily sync script at 3:00 AM via systemd timer

**Repositories to Mirror:**

#### Ubuntu 24.04 (Noble) - Base Distribution
```bash
# Inside Aptly container
aptly mirror create -architectures=amd64,arm64 ubuntu-noble \
  http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse

aptly mirror create -architectures=amd64,arm64 ubuntu-noble-updates \
  http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse

aptly mirror create -architectures=amd64,arm64 ubuntu-noble-security \
  http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
```

#### Docker CE Repository
```bash
# Import Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor > /tmp/docker.gpg
gpg --import /tmp/docker.gpg

# Create mirror
aptly mirror create -architectures=amd64,arm64 docker-noble \
  https://download.docker.com/linux/ubuntu noble stable
```

#### NVIDIA CUDA Repositories
```bash
# AMD64/x86_64
aptly mirror create -architectures=amd64 nvidia-amd64 \
  https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64 /

# ARM64/sbsa
aptly mirror create -architectures=arm64 nvidia-arm64 \
  https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa /
```

#### xtradeb/apps PPA
```bash
aptly mirror create -architectures=amd64 xtradeb \
  http://ppa.launchpad.net/xtradeb/apps/ubuntu noble main
```

**Key Enhancements:**
- All mirror configurations templated via Ansible for consistency
- GPG keys managed through Ansible Vault
- Automated mirror creation during initial setup
- Sync script updates all mirrors daily

#### `/usr/local/bin/aptly-sync.sh` - Example Structure
```bash
#!/bin/bash
DATE=$(date +%Y-%m-%d)
LOG="/var/log/aptly-sync.log"

echo "==== START $DATE ====" >> $LOG

# Update all mirrors
aptly mirror update ubuntu-noble >> $LOG 2>&1
aptly mirror update ubuntu-noble-updates >> $LOG 2>&1
aptly mirror update ubuntu-noble-security >> $LOG 2>&1
aptly mirror update docker-noble >> $LOG 2>&1
aptly mirror update nvidia-amd64 >> $LOG 2>&1
aptly mirror update nvidia-arm64 >> $LOG 2>&1
aptly mirror update xtradeb >> $LOG 2>&1

# Create dated snapshots
for repo in ubuntu-noble ubuntu-noble-updates ubuntu-noble-security \
            docker-noble nvidia-amd64 nvidia-arm64 xtradeb; do
  aptly snapshot create ${repo}-$DATE from mirror $repo >> $LOG 2>&1
done

# Merge Ubuntu base repos into one unified snapshot
aptly snapshot merge ubuntu-full-$DATE \
  ubuntu-noble-$DATE \
  ubuntu-noble-updates-$DATE \
  ubuntu-noble-security-$DATE >> $LOG 2>&1

# Publish the merged snapshot with GPG signing
aptly publish snapshot \
  -distribution=noble \
  -architectures="amd64,arm64" \
  -gpg-key="Offline Mirror" \
  ubuntu-full-$DATE >> $LOG 2>&1

# Status reporting
if [ $? -eq 0 ]; then
  echo '{"status":"ok","last_run":"'$(date -Iseconds)'"}' > /repos/aptly/status.json
else
  echo '{"status":"failed","last_run":"'$(date -Iseconds)'"}' > /repos/aptly/status.json
fi

echo "==== END $DATE ====" >> $LOG
```

**Storage Impact:**
- Ubuntu repos: ~200-300 GB
- Docker repo: ~20-30 GB
- NVIDIA CUDA repos: ~50-100 GB (both architectures)
- xtradeb PPA: ~5-10 GB
- **Total DEB storage**: ~300-450 GB

### 3. Unified NGINX Configuration

**Critical File:** `/etc/nginx/conf.d/repo-mirror.conf`

**Structure:**
```nginx
# RPM repos - served directly from filesystem
location /rpm/ {
    alias /repos/rpm/;
    autoindex on;
    # Cache .rpm files aggressively (immutable)
    # Don't cache metadata (repomd.xml, etc.)
}

# DEB repos - proxied to Aptly container
location /deb/ {
    proxy_pass http://localhost:8080/;
    # Don't cache Packages/Release files
    # Cache .deb files aggressively
}

# Monitoring endpoints
location /status/rpm { alias /repos/rpm/status.json; }
location /status/deb { alias /repos/aptly/status.json; }
location /health { return 200 '{"status":"ok"}'; }
```

**Features:**
- Unified access point for both repo types
- Proper caching strategies (cache packages, not metadata)
- gzip compression for metadata files
- Health/status endpoints for monitoring
- Stub status for Prometheus nginx exporter

### 4. Client Configuration

**For RPM Clients (Rocky Linux/RHEL):**
```ini
# /etc/yum.repos.d/local-mirror.repo
[local-baseos]
name=Local Mirror - Rocky Linux BaseOS
baseurl=http://repo-mirror.local/rpm/rocky/10/BaseOS/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10
```

**For DEB Clients (Ubuntu):**
```bash
# Copy GPG key and configure apt
curl http://repo-mirror.local/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/local-mirror.gpg

# /etc/apt/sources.list.d/local-mirror.list
deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/ noble main
```

### 5. Monitoring Setup

**Components:**
- Prometheus node_exporter for system metrics
- Custom metrics exporters for both RPM and DEB sync status
- NGINX stub_status for web server metrics
- Alerting rules:
  - Sync failures (critical)
  - Stale syncs (>24 hours old - warning)
  - Disk space monitoring (warning at 80%, critical at 90%)

**Metrics Files:**
- `/usr/local/bin/rpm-metrics.sh` - Generates Prometheus metrics from rpm status.json
- `/usr/local/bin/deb-metrics.sh` - Generates Prometheus metrics from deb status.json
- Systemd timers to run metrics exporters every minute

### 6. Remote Ansible Execution Setup

**Prerequisites on Control Node (your workstation/CI server):**
```bash
# Install Ansible
sudo dnf install -y ansible-core  # or pip install ansible

# Install required collections
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install containers.podman
```

**SSH Key Setup:**
```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "ansible-control"

# Copy to target server
ssh-copy-id user@repo-server-ip

# Test connection
ssh user@repo-server-ip 'echo "Connection successful"'
```

**Critical Files for Remote Execution:**

#### `ansible.cfg`
- Configures Ansible behavior for remote execution
- Sets SSH settings, privilege escalation, inventory path
- Disables host key checking for local networks (optional)

#### `inventory/production/hosts.yml`
- Defines target server(s) IP/hostname
- Specifies connection parameters (user, become method)
- Groups servers by role (repo_servers)

Example structure:
```yaml
all:
  children:
    repo_servers:
      hosts:
        repo-mirror-01:
          ansible_host: 192.168.1.100
          ansible_user: admin
          ansible_become: true
          ansible_become_method: sudo
```

**Execution from Control Node:**
```bash
# Test connectivity
ansible repo_servers -m ping

# Run playbook
ansible-playbook playbooks/deploy-repo-mirror.yml

# Run with tags (partial deployment)
ansible-playbook playbooks/deploy-repo-mirror.yml --tags rpm,nginx

# Check mode (dry-run)
ansible-playbook playbooks/deploy-repo-mirror.yml --check

# Verbose output for debugging
ansible-playbook playbooks/deploy-repo-mirror.yml -vvv
```

### 7. Ansible Deployment Structure

```
ansible/
├── ansible.cfg                          # Ansible configuration for remote execution
├── README.md                            # Deployment instructions
├── requirements.yml                     # Ansible Galaxy dependencies
├── playbooks/
│   └── deploy-repo-mirror.yml          # Main deployment playbook
├── roles/
│   ├── common/                          # Base system setup
│   ├── repo-storage/                    # Storage/directory setup
│   ├── rpm-mirror/                      # RPM sync setup
│   │   ├── tasks/main.yml
│   │   ├── templates/
│   │   │   ├── rpm-sync.sh.j2
│   │   │   ├── rpm-sync.service.j2
│   │   │   └── rpm-sync.timer.j2
│   │   └── defaults/main.yml
│   ├── deb-mirror/                      # Aptly container setup
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── container.yml
│   │   │   └── gpg-setup.yml
│   │   ├── templates/
│   │   │   ├── aptly.conf.j2
│   │   │   ├── aptly-sync.sh.j2
│   │   │   └── aptly-sync.timer.j2
│   │   └── defaults/main.yml
│   ├── nginx/                           # NGINX setup
│   │   ├── tasks/main.yml
│   │   ├── templates/
│   │   │   └── repo-mirror.conf.j2
│   │   └── handlers/main.yml
│   └── monitoring/                      # Monitoring setup
│       ├── tasks/
│       │   ├── main.yml
│       │   ├── prometheus.yml
│       │   └── node-exporter.yml
│       └── templates/
│           ├── rpm-metrics.sh.j2
│           └── deb-metrics.sh.j2
└── inventory/
    ├── production/
    │   └── hosts.yml
    └── group_vars/
        └── repo_servers.yml            # Variables: repo URLs, architectures, schedules
```

**Key Ansible Features:**
- Idempotent operations (can run multiple times safely)
- Validates prerequisites (OS version, disk space, network)
- Manages Podman containers through systemd integration
- Templates allow customization per environment
- Handlers for service restarts only when needed
- Tags for selective execution (`--tags rpm`, `--tags nginx`, etc.)

**Inventory Variables:**
```yaml
# group_vars/repo_servers.yml
repo_base_path: /repos
repo_server_hostname: repo-mirror.local

# RPM repository configuration
repo_rpm_architectures:
  - x86_64
repo_rocky_version: 10
repo_epel_version: 10

# DEB repository configuration
repo_deb_architectures:
  - amd64
  - arm64
repo_ubuntu_release: noble
repo_ubuntu_version: "24.04"

# Mirror list for DEB repositories
deb_mirrors:
  - name: ubuntu-noble
    url: "http://archive.ubuntu.com/ubuntu"
    distribution: noble
    components: "main restricted universe multiverse"
  - name: ubuntu-noble-updates
    url: "http://archive.ubuntu.com/ubuntu"
    distribution: noble-updates
    components: "main restricted universe multiverse"
  - name: ubuntu-noble-security
    url: "http://security.ubuntu.com/ubuntu"
    distribution: noble-security
    components: "main restricted universe multiverse"
  - name: docker-noble
    url: "https://download.docker.com/linux/ubuntu"
    distribution: noble
    components: "stable"
  - name: nvidia-amd64
    url: "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64"
    distribution: "/"
    architectures: ["amd64"]
  - name: nvidia-arm64
    url: "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa"
    distribution: "/"
    architectures: ["arm64"]
  - name: xtradeb
    url: "http://ppa.launchpad.net/xtradeb/apps/ubuntu"
    distribution: noble
    components: "main"
    architectures: ["amd64"]

# Sync schedules
rpm_sync_schedule: "*-*-* 02:00:00"
deb_sync_schedule: "*-*-* 03:00:00"

# Monitoring
monitoring_enabled: true
```

## Implementation Phases

### Phase 1: Foundation (Day 1)
1. Storage setup (create /repos directory structure, set permissions)
2. Install base packages (podman, nginx, dnf-utils, createrepo_c, jq)
3. Configure firewall (allow http/https)
4. Configure SELinux contexts for /repos directories
5. Deploy basic NGINX configuration

### Phase 2: RPM Mirror (Day 1-2)
1. Create rpm-sync.sh script
2. Deploy systemd service and timer for RPM sync
3. Execute initial manual sync (can take 2-4 hours)
4. Verify repository metadata with `dnf repolist`
5. Test from a Rocky Linux client
6. Deploy monitoring for RPM sync

### Phase 3: DEB Mirror (Day 2-3)
1. Deploy Aptly container with volume mounts
2. Configure GPG keys:
   - Generate signing key for published repos
   - Import Docker GPG key for Docker CE repository
   - Import NVIDIA GPG key if required
   - Store private keys in Ansible Vault
3. Initialize Aptly mirrors:
   - Ubuntu base, updates, security
   - Docker CE repository
   - NVIDIA CUDA repositories (amd64 + arm64)
   - xtradeb/apps PPA
4. Create aptly-sync.sh script (updates all mirrors)
5. Deploy systemd service/timer for Aptly
6. Execute initial manual sync (can take 12-24 hours for all repos)
7. Integrate with NGINX reverse proxy
8. Test from Ubuntu client
9. Deploy monitoring for DEB sync

### Phase 4: Monitoring & Documentation (Day 3)
1. Install Prometheus node_exporter
2. Deploy custom metrics exporters
3. Configure alerting rules
4. Document client configuration procedures
5. Create operational runbooks

### Phase 5: Ansible Automation (Day 4-5)
1. Create Ansible role structure
2. Implement roles incrementally (storage -> rpm -> deb -> nginx -> monitoring)
3. Test in development/staging environment
4. Refine templates and variables
5. Document deployment procedure

## Critical Files to Create

### Ansible Control Files (created in this repo):

1. **`ansible/ansible.cfg`** - Ansible configuration for remote execution (SSH settings, privilege escalation, inventory path)
2. **`ansible/requirements.yml`** - Ansible Galaxy collection dependencies (ansible.posix, containers.podman)
3. **`ansible/inventory/production/hosts.yml`** - Target server inventory with IP, SSH user, connection parameters
4. **`ansible/playbooks/deploy-repo-mirror.yml`** - Master orchestration playbook with role ordering and validation
5. **`ansible/roles/rpm-mirror/templates/rpm-sync.sh.j2`** - Templated RPM sync script with configurable repos and schedules
6. **`ansible/roles/deb-mirror/tasks/container.yml`** - Podman container deployment and systemd integration
7. **`ansible/roles/nginx/templates/repo-mirror.conf.j2`** - Templated NGINX configuration for unified repo serving
8. **`ansible/README.md`** - Deployment instructions and usage examples

### Target Server Files (deployed by Ansible):

1. **`/usr/local/bin/rpm-sync.sh`** - Core RPM sync logic with dnf reposync, createrepo_c, status reporting
2. **`/etc/nginx/conf.d/repo-mirror.conf`** - Unified web server config for both RPM (static) and DEB (proxied)
3. **`/etc/systemd/system/rpm-sync.service`** - RPM sync systemd service with resource limits
4. **`/etc/systemd/system/rpm-sync.timer`** - Daily schedule for RPM sync (2 AM)
5. **`/usr/local/bin/aptly-sync.sh`** - DEB sync script for Aptly container
6. **`/etc/systemd/system/aptly-sync.timer`** - Daily schedule for DEB sync (3 AM)

## Verification & Testing

### Post-Deployment Validation

**1. Service Status:**
```bash
sudo systemctl status rpm-sync.timer
sudo systemctl status aptly-sync.timer
sudo systemctl status container-aptly
sudo systemctl status nginx
```

**2. Repository Access:**
```bash
# Test RPM repo
curl http://localhost/rpm/rocky/10/BaseOS/x86_64/repodata/repomd.xml

# Test DEB repo
curl http://localhost/deb/dists/noble/Release
```

**3. Client Configuration:**
- Configure a test Rocky Linux VM with local mirror
- Configure a test Ubuntu VM with local mirror
- Execute package installations to verify functionality

**4. Monitoring:**
```bash
# Check metrics
curl http://localhost/status/rpm
curl http://localhost/status/deb

# Prometheus metrics
curl http://localhost:9100/metrics | grep aptly
curl http://localhost:9100/metrics | grep rpm
```

**5. Sync Testing:**
```bash
# Trigger manual sync
sudo systemctl start rpm-sync.service
sudo systemctl start aptly-sync.service

# Monitor logs
sudo journalctl -u rpm-sync.service -f
sudo journalctl -u aptly-sync.service -f
```

### End-to-End Test Plan

1. **Initial Deployment:**
   - From control node: Test SSH connectivity to target server
   - Run Ansible playbook remotely: `ansible-playbook playbooks/deploy-repo-mirror.yml`
   - Validate all services start successfully on target server
   - Verify directory structure and permissions on target server

2. **Repository Sync:**
   - Wait for initial syncs to complete
   - Verify repository metadata is valid
   - Check disk space usage

3. **Client Testing:**
   - Configure Rocky Linux client to use mirror
   - Install/update packages successfully
   - Configure Ubuntu client to use mirror
   - Install/update packages successfully

4. **Monitoring:**
   - Verify Prometheus scrapes metrics successfully
   - Test alerting (simulate sync failure)
   - Check log aggregation

5. **Failure Recovery:**
   - Test behavior when sync fails (disconnect network)
   - Verify alerts fire correctly
   - Validate recovery after network restoration

## Security Considerations

**Container Security:**
- Run Aptly container with `--security-opt no-new-privileges`
- Drop all capabilities except NET_BIND_SERVICE
- Consider read-only root filesystem with tmpfs for /tmp
- Bind to 127.0.0.1:8080 (not public interface)

**SELinux:**
- Set proper contexts: `container_file_t` for /repos/aptly
- Set `httpd_sys_content_t` for /repos/rpm
- Use `restorecon -Rv /repos` after setup

**Firewall:**
- Only expose HTTP/HTTPS externally
- Consider restricting to local network ranges only
- Block direct access to ports 8080 (Aptly), 9100 (node_exporter)

**GPG Key Management:**
- Store private keys encrypted with Ansible Vault
- Rotate keys periodically
- Use separate keys for production vs development

**Bandwidth Management:**
- Schedule syncs during off-peak hours (2-3 AM)
- Consider rate limiting: `dnf reposync --downloadrate=10M`
- Implement systemd resource limits in service files

## Bandwidth & Performance Estimates

**Initial Sync (x86_64 + aarch64):**
- Rocky Linux 10 (BaseOS + AppStream + Extras):
  - x86_64: 50-60 GB
  - aarch64: 50-60 GB
  - **Subtotal**: 100-120 GB (3-6 hours on 100Mbps)
- EPEL 10:
  - x86_64: 30-40 GB
  - aarch64: 30-40 GB
  - **Subtotal**: 60-80 GB (2-4 hours)
- Ubuntu 24.04 (base + updates + security): 200-300 GB (6-10 hours)
- Docker CE repository: 20-30 GB (1-2 hours)
- NVIDIA CUDA (amd64 + arm64): 50-100 GB (2-4 hours)
- xtradeb/apps PPA: 5-10 GB (0.5-1 hour)
- **Total Initial**: ~550-750 GB (16-30 hours on 100Mbps connection)

**Daily Updates:**
- Rocky Linux (both arch): 1-4 GB
- EPEL (both arch): 500 MB - 2 GB
- Ubuntu base: 1-3 GB
- Docker: 100-500 MB
- NVIDIA CUDA: 200-800 MB
- xtradeb: 50-200 MB
- **Total Daily**: ~3-10 GB

**Optimization:**
- Use `--newest-only` to keep only latest package versions
- Exclude debug packages unless needed: `--exclude='*-debuginfo'`
- Limit architectures to only what you need (x86_64 only if no ARM)
- Use aptly snapshots to minimize storage for historical versions

## Success Criteria

✅ Both RPM and DEB repositories accessible via HTTP
✅ Clients can install/update packages from mirror
✅ Automated daily syncs running successfully
✅ Monitoring and alerting functional
✅ Ansible playbook deploys entire stack idempotently
✅ Documentation complete for operations and troubleshooting
✅ Disk space usage within expected parameters
✅ Services survive reboots (enabled in systemd)

## Next Steps After Deployment

1. **Monitoring Integration**: Connect to existing Grafana/Prometheus infrastructure
2. **Client Automation**: Create Ansible playbooks to configure clients automatically
3. **Backup Strategy**: Implement backup for GPG keys and configuration
4. **Capacity Planning**: Monitor growth and plan disk expansion
5. **Additional Mirrors**: Consider adding more distributions (Debian, AlmaLinux, etc.)
6. **High Availability**: Plan for redundancy if critical to operations
