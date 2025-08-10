# Dependency Installation Guide

This guide helps you install the required tools for the Proxmox-AuroraBoot-Kairos deployment pipeline.

## Quick Install (Recommended)

### macOS Users

Due to HashiCorp's BUSL license change, Packer is no longer available via Homebrew. Use these manual steps:

```bash
# 1. Install most tools via Homebrew
brew install jq yq gh curl docker

# 2. Install Terraform via Homebrew tap (still available)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# 3. Manually install Packer (last MPL version)
mkdir -p ~/.local/bin
curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_darwin_arm64.zip
cd /tmp && unzip -o packer.zip && mv packer ~/.local/bin/ && chmod +x ~/.local/bin/packer

# 4. Add to PATH (add to your ~/.zshrc or ~/.bashrc)
export PATH="$PATH:$HOME/.local/bin"

# 5. Reload shell or source your profile
source ~/.zshrc  # or ~/.bashrc
```

### Linux Users (Ubuntu/Debian)

```bash
# 1. Update package list
sudo apt-get update

# 2. Install common tools
sudo apt-get install -y curl wget jq git docker.io

# 3. Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# 4. Install yq
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# 5. Install GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt-get update && sudo apt-get install gh

# 6. Install Packer manually
curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
cd /tmp && unzip -o packer.zip && sudo mv packer /usr/local/bin/ && sudo chmod +x /usr/local/bin/packer

# 7. Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

## Alternative: Using the Provided Script

You can use the automated script we've provided:

```bash
# Install all dependencies
./scripts/install-dependencies.sh all

# Install only specific tools
./scripts/install-dependencies.sh packer
./scripts/install-dependencies.sh terraform
```

## Required Tools Overview

| Tool | Purpose | Version Notes |
|------|---------|---------------|
| **Terraform** | Infrastructure provisioning | Latest stable version |
| **Packer** | VM template creation | v1.9.4 (last MPL license) |
| **Docker** | Container runtime | Latest stable version |
| **jq** | JSON processing | Latest version |
| **yq** | YAML processing | Latest version |
| **gh** | GitHub CLI | Latest version |
| **curl** | HTTP requests | Usually pre-installed |

## Verification

After installation, verify all tools are working:

```bash
# Run the validation script
./scripts/test/validate-deployment.sh dependencies

# Or check manually
terraform version
packer version
docker --version
jq --version
yq --version
gh --version
curl --version
```

Expected output should show all tools installed without errors.

## Troubleshooting

### Packer License Issues

**Problem**: `brew install packer` fails with "disabled because it will change its license to BUSL"

**Solution**: Use manual installation as shown above. We install Packer v1.9.4, which is the last version under the Mozilla Public License (MPL).

### PATH Issues

**Problem**: Commands not found after installation

**Solution**: 
```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export PATH="$PATH:$HOME/.local/bin"

# Reload your shell
source ~/.zshrc  # or ~/.bashrc
```

### Docker Permission Issues (Linux)

**Problem**: `docker: permission denied`

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in, then test
docker run hello-world
```

### GitHub CLI Authentication

**Problem**: GitHub API rate limiting or authentication errors

**Solution**:
```bash
# Authenticate with GitHub
gh auth login

# Follow the prompts to authenticate via web browser
```

## Next Steps

Once all dependencies are installed:

1. **Configure Environment Variables**:
   ```bash
   export PROXMOX_API_URL="https://your-proxmox:8006/api2/json"
   export PROXMOX_API_TOKEN="user@realm!token=secret"
   export GITHUB_REPO="your-org/beyond-devops-os-factory"
   ```

2. **Run Validation**:
   ```bash
   ./scripts/test/validate-deployment.sh
   ```

3. **Start Your First Deployment**:
   ```bash
   ./scripts/proxmox/deploy-kairos-vm.sh full-deploy
   ```

## Manual Installation Commands Summary

### For macOS (Intel):
```bash
curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_darwin_amd64.zip
```

### For macOS (Apple Silicon):
```bash
curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_darwin_arm64.zip
```

### For Linux (x86_64):
```bash
curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
```

### For Linux (ARM64):
```bash
curl -L -o /tmp/packer.zip https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_arm64.zip
```

Then extract and install:
```bash
cd /tmp && unzip -o packer.zip
# System-wide (requires sudo):
sudo mv packer /usr/local/bin/ && sudo chmod +x /usr/local/bin/packer
# Or user-only:
mkdir -p ~/.local/bin && mv packer ~/.local/bin/ && chmod +x ~/.local/bin/packer
```