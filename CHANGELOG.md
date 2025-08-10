# Changelog

All notable changes to the beyond-devops-os-factory project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2025-08-10

### Fixed
- **Login Credentials**: Fixed plaintext passwords with proper SHA512 hashing in cloud-config files
- **Template Syntax**: Corrected template syntax from Go templates ({{ }}) to cloud-init format (${})
- **User Privileges**: Added required admin groups (wheel, sudo) for proper privilege escalation
- **Authentication**: Enabled password authentication with lock_passwd: false setting
- **GitHub Actions Workflow**: Removed unsupported qcow2 build parameter causing validation errors

### Added
- **Login Validation Test**: Comprehensive test script to validate Kairos VM login credentials
- **Authentication Testing**: Tests for SSH key auth, password auth, connectivity, and user permissions
- **Cloud-config Validation**: Automated validation to catch common configuration errors
- **Individual Image Files**: GitHub releases now include downloadable ISO and RAW files with checksums

### Changed
- **Release Artifacts**: Enhanced release documentation with detailed usage instructions for each image format
- **Cloud Configuration**: Updated both osartifact.yaml and cloud-config.yaml for consistency
- **Build Process**: Workflow now properly uploads individual image files to GitHub releases

### Security
- **Password Security**: Replaced plaintext passwords with SHA512 hashed passwords
- **Authentication Hardening**: Improved user account security with proper group assignments

## [1.0.1] - 2025-08-10

### Added
- Automatic semantic versioning with git tags
- Dynamic version generation based on git repository state
- Development vs release build differentiation
- VERSION.md comprehensive versioning guide
- CHANGELOG.md for tracking project changes

### Changed
- Workflow now uses dynamic versioning instead of static defaults
- Release creation only occurs for official tagged versions
- Improved release notes with version type indicators

### Fixed
- Simplified development version format for Kairos Factory Action compatibility
- Changed from complex version strings to standard semantic versions (e.g., 1.0.1-alpha.123)
- Updated release tag generation for cleaner version handling
- Use proper semantic versioning pre-release format (alpha) instead of custom dev suffix

## [1.0.0] - 2024-01-XX (Upcoming)

### Added
- **Kairos Factory Action Integration**: Simplified build process using official Kairos Factory Action
- **Enterprise Configuration**: Pre-configured with system-upgrade-controller and cert-manager bundles
- **Multi-format Support**: Automated generation of ISO, RAW, and QCOW2 images
- **Security Scanning**: Built-in vulnerability scanning with Grype and Trivy
- **Multi-platform Builds**: Support for both amd64 and arm64 architectures
- **Comprehensive Documentation**: Complete installation and customization guide (INSTALL-KAIROS.md)
- **Cloud-config Integration**: Enterprise-ready system configuration with K3s HA setup
- **Automated GitHub Releases**: Automatic release creation for tagged versions

### Enterprise Features
- **P2P Mesh Networking**: Configured for enterprise mesh token networking
- **KubeVIP Load Balancing**: High availability load balancer configuration
- **Enterprise Monitoring**: Health check scripts and compliance configurations
- **Hardened Security**: Enterprise-grade security policies and audit logging

### CI/CD Pipeline
- **GitHub Actions Workflow**: Streamlined build process with Kairos Factory Action
- **Automated Security Scanning**: Integrated vulnerability assessment
- **Artifact Management**: Organized artifact storage and release distribution
- **Permission Management**: Properly scoped permissions for security

### Configuration Files
- `packer/kairos/osartifact.yaml`: Kairos build specification with enterprise bundles
- `packer/kairos/cloud-config.yaml`: System configuration with K3s and networking
- `.github/workflows/kairos-factory.yml`: Simplified build workflow
- `INSTALL-KAIROS.md`: Comprehensive installation and customization guide

### Breaking Changes from Legacy System
- **Removed Complex Packer Templates**: Eliminated 315-line custom Packer configuration
- **Simplified Workflow**: Reduced from 403 to ~150 lines of workflow configuration
- **Changed Build Approach**: Moved from custom Packer builds to Kairos Factory Action

## [0.9.0] - 2024-01-XX (Legacy System)

### Removed
- **Complex Packer Configuration**: Removed `packer/kairos.pkr.hcl` (315 lines)
- **Complex GitHub Workflow**: Removed `build-kairos.yml` (403 lines)
- **Manual Plugin Management**: Eliminated manual Packer plugin installations
- **Custom Container Builds**: Removed multi-stage Docker/QEMU build process

### Migration Notes
- Projects using the legacy Packer-based system should migrate to the new Factory Action approach
- Custom bundles and configurations are preserved and enhanced
- Build times significantly improved with Factory Action
- Security scanning is now automated and integrated

---

## Version History Overview

| Version | Date | Type | Key Changes |
|---------|------|------|-------------|
| v1.0.0 | TBD | Major | Kairos Factory Action integration, enterprise features |
| v0.9.0 | TBD | Legacy | Removal of complex Packer system |

---

## How to Use This Changelog

### For Developers
- Review changes before upgrading
- Check for breaking changes in major versions
- Use version information for compatibility planning

### For Users
- Understand new features and capabilities
- Plan upgrade paths for existing deployments
- Identify when to rebuild images for security updates

### For Contributors
- Follow the changelog format for new entries
- Document all user-facing changes
- Include migration notes for breaking changes

---

## Changelog Format Guidelines

This project follows [Keep a Changelog](https://keepachangelog.com/) format:

### Change Types
- **Added** for new features
- **Changed** for changes in existing functionality
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** for vulnerability fixes

### Version Format
- **Major (X.y.z)**: Breaking changes, major new features
- **Minor (x.Y.z)**: New features, backwards compatible
- **Patch (x.y.Z)**: Bug fixes, security patches
- **Pre-release**: Alpha, beta, rc versions for testing

### Example Entry Format
```markdown
## [1.1.0] - 2024-02-15

### Added
- New monitoring bundle with Prometheus and Grafana
- Support for custom storage configurations
- Enhanced security compliance checks

### Changed
- Updated base image from Ubuntu 22.04 to 24.04
- Improved K3s configuration for better performance

### Fixed
- Resolved KubeVIP configuration issue
- Fixed cloud-config validation errors

### Security
- Updated all base packages to latest versions
- Enhanced network security policies
```

---

## Release Planning

### Upcoming Features (Future Versions)
- **v1.1.0**: Enhanced monitoring stack (Prometheus, Grafana, Longhorn)
- **v1.2.0**: Multi-cloud deployment support (AWS, GCP, Azure)
- **v2.0.0**: Next-generation Kairos integration with breaking changes

### Security Updates
- Regular security patches will be released as patch versions
- Critical security fixes may trigger immediate releases
- All releases include automated vulnerability scanning

### Community Contributions
- Feature requests and bug reports tracked via GitHub Issues
- Community contributions documented in changelog
- Breaking changes require discussion and migration guides

---

For more information about versioning strategy, see [VERSION.md](VERSION.md).
For installation and usage instructions, see [INSTALL-KAIROS.md](INSTALL-KAIROS.md).