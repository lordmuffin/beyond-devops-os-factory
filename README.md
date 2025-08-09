# beyond-devops-os-factory

An enterprise-grade OS image management automation framework that builds reproducible Windows 11 Pro and SteamOS images using Infrastructure as Code (IaC) principles. This security-first framework combines Packer, Ansible, and GitHub Actions to deliver consistent, auditable, and scalable image deployment pipelines.

## 🏗️ Architecture Overview

This project implements a complete Windows image build automation pipeline:

- **Packer**: Core image building and automation engine
- **Ansible**: Configuration management and software provisioning
- **GitHub Actions**: Automated CI/CD pipeline with QEMU/KVM virtualization
- **PowerShell Scripts**: Windows-specific bootstrapping and finalization
- **Security Integration**: Built-in hardening and compliance validation

## 📁 Project Structure

```
beyond-devops-os-factory/
├── .github/workflows/
│   └── build-windows.yml          # CI/CD pipeline for automated builds
├── ansible/
│   ├── packages.txt               # Software packages to install
│   ├── playbook.yml               # Main Ansible playbook
│   └── roles/chocolatey-packages/ # Package installation role
├── packer/                        # Packer templates (to be created)
└── scripts/
    ├── prepare-windows.ps1        # Initial system preparation
    └── finalize-windows.ps1       # Final image preparation & Sysprep
```

## 🚀 Quick Start

### Prerequisites

- Packer >= 1.8
- Ansible >= 2.9
- PowerShell (for Windows builds)
- QEMU/KVM (for CI/CD builds)

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/beyond-devops-os-factory.git
   cd beyond-devops-os-factory
   ```

2. **Initialize Packer plugins**
   ```bash
   cd packer
   packer init .
   ```

3. **Validate configuration**
   ```bash
   packer validate .
   ```

4. **Build image locally** (requires Packer template)
   ```bash
   packer build .
   ```

### Automated Builds

The GitHub Actions workflow automatically triggers on:
- Push to `main` branch with changes to `packer/`, `scripts/`, or `ansible/` directories
- Manual workflow dispatch

## 🔧 Configuration

### Software Packages

Edit `ansible/packages.txt` to customize installed software:
```
git
notepadplusplus
vscode
# Add additional Chocolatey packages here
```

### Build Customization

The build process follows this sequence:

1. **Bootstrap** (`scripts/prepare-windows.ps1`)
   - Disables UAC for automation
   - Installs Chocolatey package manager
   - Sets execution policies

2. **Provision** (`ansible/playbook.yml`)
   - Installs software packages
   - Applies system configurations
   - Runs security hardening (extensible)

3. **Finalize** (`scripts/finalize-windows.ps1`)
   - Cleans temporary files and caches
   - Re-enables security settings
   - Runs Sysprep for image generalization

## 🛡️ Security Features

- **Security-First Design**: UAC properly managed during build process
- **Least Privilege**: GitHub Actions use minimal required permissions
- **Clean Images**: Automated cleanup removes build artifacts
- **Audit Trail**: Complete build logging and artifact retention
- **Compliance Ready**: Extensible framework for security policies

## 🔄 CI/CD Pipeline

The GitHub Actions workflow provides:

- **QEMU/KVM Virtualization**: Linux runners with full virtualization support
- **Caching**: Packer plugins cached for faster builds
- **Artifact Management**: Built images stored as workflow artifacts
- **Concurrency Control**: Prevents conflicting simultaneous builds
- **Security**: Minimal permissions and secret management

## 📋 Extensibility

The framework is designed for easy extension:

### Adding New Roles
```yaml
# In ansible/playbook.yml
roles:
  - chocolatey-packages
  - windows-features      # Enable/disable Windows features
  - system-hardening      # Security configurations
  - user-configuration    # Default user settings
```

### Custom Build Steps
- Add PowerShell scripts to `scripts/` directory
- Reference in Packer provisioners
- Update GitHub Actions workflow if needed

## 🏢 Enterprise Features

- **Reproducible Builds**: Identical images across environments
- **Version Control**: All configurations stored in Git
- **Compliance Tracking**: Audit trails for all changes
- **Scalable Architecture**: Supports multiple image variants
- **Integration Ready**: Compatible with existing deployment tools

## 📖 Best Practices

1. **Version Control**: All image definitions are code
2. **Testing**: Validate configurations before building
3. **Security**: Regular updates and security scanning
4. **Documentation**: Maintain clear build procedures
5. **Monitoring**: Track build success and performance metrics

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following existing patterns
4. Test locally before submitting
5. Submit pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built for DevOps professionals who demand enterprise-grade automation with security and compliance at the core.**
