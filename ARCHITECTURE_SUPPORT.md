# Multi-Architecture Support

This repository mirror server provides **full multi-architecture support** for both RPM and DEB repositories.

## Architecture Matrix

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

## Storage Breakdown by Architecture

### RPM Repositories
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

### DEB Repositories
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

### Overall Total
- **RPM**: ~160-200 GB
- **DEB**: ~300-450 GB
- **Buffer**: ~150-200 GB
- **Grand Total**: **1.5TB - 2TB recommended**

## Client Configuration

### RPM Clients (Rocky/RHEL)

The `$basearch` variable automatically resolves to the correct architecture:

**On x86_64 systems:**
```bash
baseurl=http://repo-mirror.local/rpm/rocky/10/BaseOS/$basearch
# Resolves to: /rpm/rocky/10/BaseOS/x86_64/
```

**On aarch64 systems:**
```bash
baseurl=http://repo-mirror.local/rpm/rocky/10/BaseOS/$basearch
# Resolves to: /rpm/rocky/10/BaseOS/aarch64/
```

### DEB Clients (Ubuntu/Debian)

Aptly automatically serves the correct architecture based on the client's `dpkg --print-architecture`:

**Configuration (works for both architectures):**
```bash
deb [signed-by=/usr/share/keyrings/local-mirror.gpg] http://repo-mirror.local/deb/ noble main
```

**APT automatically selects:**
- amd64 packages on x86_64 systems
- arm64 packages on aarch64 systems

## How It Works

### RPM Architecture Handling
The `rpm-sync.sh` script loops through all configured architectures:

```bash
ARCHITECTURES=(x86_64 aarch64)

for arch in "${ARCHITECTURES[@]}"; do
    sync_repo "baseos" "$REPO_BASE/rocky/10/BaseOS" "$arch" "Rocky Linux 10 BaseOS"
    sync_repo "appstream" "$REPO_BASE/rocky/10/AppStream" "$arch" "Rocky Linux 10 AppStream"
    # ... etc
done
```

### DEB Architecture Handling
Aptly mirrors are created with architecture specification:

```bash
aptly mirror create \
    -architectures=amd64,arm64 \
    ubuntu-noble \
    http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
```

## Bandwidth Estimates

### Initial Sync (both architectures)
- Rocky 10 (x86_64 + aarch64): ~100-120 GB (3-6 hours @ 100Mbps)
- EPEL 10 (x86_64 + aarch64): ~60-80 GB (2-4 hours @ 100Mbps)
- Ubuntu 24.04 (amd64 + arm64): ~200-300 GB (6-10 hours @ 100Mbps)
- Docker CE: ~20-30 GB (1-2 hours @ 100Mbps)
- NVIDIA CUDA: ~50-100 GB (2-4 hours @ 100Mbps)
- **Total**: ~550-750 GB (16-30 hours @ 100Mbps)

### Daily Updates (both architectures)
- Rocky 10: ~1-4 GB
- EPEL 10: ~0.5-2 GB
- Ubuntu 24.04: ~1-3 GB
- Docker CE: ~0.1-0.5 GB
- NVIDIA CUDA: ~0.2-0.8 GB
- **Total**: ~3-10 GB/day

## Benefits of Multi-Architecture Support

✅ **Single Mirror** - One server serves both x86_64 and ARM64 clients
✅ **Unified Management** - Same sync schedule for all architectures
✅ **Consistent Versions** - All architectures get the same package versions
✅ **Automatic Detection** - Clients automatically get correct architecture
✅ **Future-Proof** - Ready for ARM server adoption
✅ **Cost Effective** - Shared infrastructure and bandwidth

## Testing Both Architectures

### Test x86_64 Client
```bash
# On an x86_64 Rocky Linux machine
curl http://repo-mirror.local/rpm/rocky/10/BaseOS/x86_64/repodata/repomd.xml
```

### Test aarch64 Client
```bash
# On an aarch64 Rocky Linux machine
curl http://repo-mirror.local/rpm/rocky/10/BaseOS/aarch64/repodata/repomd.xml
```

### Test Ubuntu (both architectures)
```bash
# amd64
curl http://repo-mirror.local/deb/pool/main/ | grep amd64

# arm64
curl http://repo-mirror.local/deb/pool/main/ | grep arm64
```

## Configuration Reference

To modify which architectures are mirrored, edit:

**File**: `ansible/inventory/group_vars/repo_servers.yml`

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

To add or remove architectures, simply update these lists and re-run the playbook!
