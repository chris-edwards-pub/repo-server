# Claude Code Instructions

This file contains durable instructions for Claude Code when working with this repository.

## Project Overview

This is a **repository mirror server** project that provides dual RPM and DEB package mirrors with full multi-architecture support (x86_64/amd64 and aarch64/arm64). The server mirrors:
- Rocky Linux 10 and EPEL (RPM)
- Ubuntu 24.04, Docker CE, and NVIDIA CUDA (DEB)

**Key Technologies:**
- Ansible for deployment automation
- RPM tools (dnf, createrepo_c) for native RPM mirroring
- Aptly (containerized with Podman) for DEB mirroring
- NGINX for web serving
- Systemd timers for automated synchronization
- Prometheus for monitoring

## Documentation Requirements

### ⚠️ CRITICAL: Documentation Updates Before Commits

**ALWAYS update README.md and all relevant documentation BEFORE creating any final commits.**

When making changes to the project:

1. **Update README.md if**:
   - Architecture changes (new repos, removed repos, architecture support)
   - Feature additions or removals
   - Configuration options change
   - Prerequisites or requirements change
   - Directory structure changes

2. **Update CLIENT_SETUP.md if**:
   - Client configuration procedures change
   - New client scripts or options added
   - Troubleshooting steps change
   - Repository URLs or access methods change

3. **Update ansible/README.md if**:
   - Deployment procedures change
   - New Ansible roles or playbooks added
   - Inventory structure changes
   - Prerequisites or requirements change
   - Configuration variables change

4. **Update client-scripts/README.md if**:
   - Script options or behavior changes
   - New scripts added
   - Usage examples need updating

5. **Check for cross-references**:
   - Ensure all internal links work
   - Update links if files are moved or renamed
   - Verify section anchors are correct

### Documentation Standards

- **Keep README.md comprehensive** - It's the main entry point
- **Keep CLIENT_SETUP.md focused** - End-user audience, detailed troubleshooting
- **Be concise but complete** - Include examples where helpful
- **Use consistent formatting** - Follow existing markdown style
- **Update "Last Updated" dates** - When making significant changes
- **Test all commands** - Don't document untested procedures

## Project Structure

```
repo-server/
├── ansible/                    # Deployment automation
│   ├── inventory/             # Inventory configurations
│   │   ├── localhost/         # Local deployment (default)
│   │   └── production/        # Remote deployment
│   ├── playbooks/             # Ansible playbooks
│   └── roles/                 # Ansible roles
├── client-scripts/            # Client configuration scripts
├── docs/                      # Historical/archived documentation
├── CLIENT_SETUP.md            # User-facing client guide
└── README.md                  # Main project documentation
```

## Working with Inventories

This project supports two deployment modes:

### Localhost Inventory (Default)

Located in `ansible/inventory/localhost/`:
- Uses `ansible_connection: local` for direct execution
- No SSH required
- Fastest deployment option
- Ideal for same-server deployment

### Production Inventory (Remote)

Located in `ansible/inventory/production/`:
- Uses SSH connection to remote servers
- Requires SSH key authentication
- For deploying from control node to remote servers
- Accessible via `-i inventory/production/hosts.yml` flag

### Shared Configuration

Both inventories share `group_vars/repo_servers.yml` via symlink. Changes to repository configuration, sync schedules, architectures, etc., apply to both deployment modes.

### When to Edit Each File

**Edit `inventory/localhost/hosts.yml` to:**
- Adjust Python interpreter path
- Modify localhost connection settings

**Edit `inventory/production/hosts.yml` to:**
- Add/remove remote servers
- Update SSH connection details
- Change remote hostnames/IPs

**Edit `inventory/production/group_vars/repo_servers.yml` to:**
- Configure repository lists
- Adjust sync schedules
- Modify architectures
- Change monitoring settings
- Update any repository-specific variables

### Environment Configuration File

For environment-specific and sensitive values, use `ansible/repo.conf`:
- Copy `ansible/repo.conf.example` to `ansible/repo.conf`
- Set values for your environment (server hostname, IPs, proxy)
- Pass to Ansible with `-e @repo.conf`
- File is gitignored and won't be committed

This approach keeps sensitive data out of the repository while maintaining a documented template.

**Variables to put in repo.conf:**
- `repo_server_hostname` - Server FQDN/IP for client access
- `ansible_host` - Remote server IP (for remote deployment)
- `ansible_user` - SSH user (for remote deployment)
- `proxy_http`, `proxy_https`, `proxy_no` - Proxy settings

**Usage:**
```bash
ansible-playbook playbooks/deploy-repo-mirror.yml -e @repo.conf
```

## Code Standards

### Shell Scripts

- Use `#!/bin/bash` for bash scripts
- Include error handling with `set -euo pipefail`
- Add descriptive comments for complex logic
- Validate user inputs
- Provide clear error messages
- Use color coding for user-facing scripts (green=success, red=error, yellow=warning)
- Make scripts idempotent where possible

### Ansible

- **Idempotency**: All tasks should be idempotent
- **Tags**: Use tags for selective execution
- **Variables**: Define in appropriate group_vars/host_vars
- **Templates**: Use Jinja2 templates for configuration files
- **Handlers**: Use handlers for service restarts
- **Error handling**: Use `failed_when`, `changed_when`, `ignore_errors` appropriately
- **Documentation**: Comment complex tasks and logic

### Configuration Files

- Use `.j2` templates for files that need variable substitution
- Keep default values in `ansible/inventory/group_vars/all.yml`
- Allow overrides in `group_vars/repo_servers.yml` or host_vars
- Use `*.local.yml` files for local development overrides (gitignored)

## Working with Multi-Architecture

This project fully supports both x86_64/amd64 and aarch64/arm64 architectures:

- **RPM**: Uses `$basearch` variable (resolves to x86_64 or aarch64)
- **DEB**: Aptly manages multiple architectures in single repository
- **Testing**: Always consider both architectures when making changes
- **Documentation**: Update architecture matrix when adding/removing repos

## Security Considerations

- **Never commit secrets**: Private keys, passwords, vault keys
- **Use Ansible Vault**: For sensitive variables
- **GPG verification**: Always enable GPG checking for repositories
- **HTTPS**: Prefer HTTPS where available (though HTTP is current default)
- **Least privilege**: Run services with minimal required permissions

## Testing Before Commits

Before committing changes:

1. **Syntax check Ansible**:
   ```bash
   ansible-playbook playbooks/deploy-repo-mirror.yml --syntax-check
   ```

2. **Lint shell scripts** (if shellcheck available):
   ```bash
   shellcheck client-scripts/*.sh
   ```

3. **Test in dry-run mode**:
   ```bash
   ansible-playbook playbooks/deploy-repo-mirror.yml --check
   ```

4. **Verify documentation**:
   - Check all markdown files render correctly
   - Verify internal links work
   - Ensure code examples are accurate

5. **Update documentation** as described above

## Git Workflow

### Commit Messages

Follow conventional commit format:
```
<type>: <subject>

<body>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Types**: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `style`

**Examples**:
- `feat: add support for Rocky Linux 9 repositories`
- `fix: correct architecture detection in Ubuntu client script`
- `docs: update README.md with new monitoring section`
- `refactor: simplify rpm-sync.sh error handling`

### Before Creating Commits

1. ✅ Review all changes with `git diff`
2. ✅ Update relevant documentation
3. ✅ Test changes in appropriate environment
4. ✅ Check for sensitive information
5. ✅ Stage specific files (avoid `git add -A`)
6. ✅ Write descriptive commit message

### Files to Never Commit

- Repository data (`/repos/`, `*.rpm`, `*.deb`)
- Private keys (`*.key`, `*.pem`, except public.key)
- Vault passwords
- Local overrides (`*.local.yml`)
- Log files (`*.log`)
- Temporary files

See `.gitignore` for complete list.

## Common Tasks

### Adding a New Repository

1. Update `ansible/inventory/production/group_vars/repo_servers.yml` (shared by both localhost and remote inventories)
2. Update sync script templates (rpm-sync.sh.j2 or aptly-sync.sh.j2)
3. Test sync manually
4. Update README.md architecture matrix
5. Update storage requirements
6. Update CLIENT_SETUP.md if client configuration changes
7. Commit with documentation updates

### Modifying Client Scripts

1. Update script in `client-scripts/`
2. Test on target distribution (Rocky or Ubuntu)
3. Update `client-scripts/README.md`
4. Update CLIENT_SETUP.md if user-facing changes
5. Update examples if behavior changes
6. Commit with documentation updates

### Adding Ansible Role or Playbook

1. Create role in `ansible/roles/` with standard structure
2. Add tasks, handlers, templates as needed
3. Update `ansible/README.md` with role purpose
4. Add example usage
5. Update main playbook if needed
6. Tag appropriately for selective execution
7. Commit with documentation updates

## Troubleshooting Tips

### Ansible Issues

- Check syntax: `ansible-playbook <playbook> --syntax-check`
- Dry run: `ansible-playbook <playbook> --check`
- Verbose output: `ansible-playbook <playbook> -vvv`
- Test connectivity: `ansible repo_servers -m ping`

### Repository Sync Issues

- Check logs: `/var/log/repo-sync/rpm-sync.log` or `deb-sync.log`
- Manual sync: `sudo systemctl start rpm-sync.service`
- Check timer status: `sudo systemctl status rpm-sync.timer`
- Verify disk space: `df -h /repos`

### Client Configuration Issues

- Test mirror connectivity: `curl http://repo-mirror.local/health`
- Verify architecture: `uname -m` (Rocky) or `dpkg --print-architecture` (Ubuntu)
- Check GPG keys: `/etc/pki/rpm-gpg/` (Rocky) or `/usr/share/keyrings/` (Ubuntu)

## Documentation References

- **Main Documentation**: [README.md](README.md)
- **Client Setup**: [CLIENT_SETUP.md](CLIENT_SETUP.md)
- **Deployment**: [ansible/README.md](ansible/README.md)
- **Client Scripts**: [client-scripts/README.md](client-scripts/README.md)
- **Historical**: [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)

## AI Assistant Notes

When working with this project:

- **Be architecture-aware**: Consider both x86_64/amd64 and aarch64/arm64
- **Test comprehensively**: RPM and DEB are different ecosystems
- **Document thoroughly**: This is production infrastructure
- **Preserve idempotency**: Ansible tasks must be rerunnable
- **Security first**: Never compromise on key management or GPG verification
- **Update docs proactively**: Don't wait for user reminder

## Questions or Issues?

- Review existing documentation first
- Check log files for error details
- Test in non-production environment
- Update documentation with solutions found

---

**Last Updated**: 2026-04-09

**Note**: This file provides guidance to Claude Code. Human contributors should also follow these guidelines for consistency.
