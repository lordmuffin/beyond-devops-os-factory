# Kairos Versioning Guide

This document explains the semantic versioning system used for Kairos image builds.

## Versioning Strategy

This project uses **Semantic Versioning** (SemVer) with automatic version generation based on git tags.

### Version Format

- **Release versions**: `v1.0.0`, `v1.2.1`, `v2.0.0`
- **Development versions**: `v1.0.1-alpha.123`, `v1.1.1-alpha.456`

### How It Works

1. **Tagged commits** → Official release versions (e.g., `v1.2.0`)
2. **Untagged commits** → Development versions (e.g., `v1.0.1-alpha.123`)
3. **Manual builds** → User-specified version (via workflow dispatch)

## Creating Releases

### 1. Development Workflow

Regular development work automatically creates development versions:

```bash
# Make changes
git add .
git commit -m "Add new feature"
git push origin main

# → Builds version: v1.0.1-alpha.123
```

### 2. Official Release Workflow

Create official releases using git tags:

```bash
# Create a release tag
git tag v1.1.0
git push origin v1.1.0

# → Builds version: v1.1.0 (official release)
```

### 3. Manual Release Workflow

Use GitHub Actions workflow dispatch for custom versions:

1. Go to **Actions** tab → **Build Kairos Images with Factory Action**
2. Click **"Run workflow"**
3. Enter desired version (e.g., `1.2.0-beta.1`)
4. Click **"Run workflow"**

## Semantic Versioning Guidelines

Follow semantic versioning principles:

### MAJOR version (X.y.z)
- Breaking changes
- Incompatible API changes
- Major architecture changes

**Example**: `v1.0.0` → `v2.0.0`

```bash
git tag v2.0.0 -m "Major release: New Kairos version with breaking changes"
git push origin v2.0.0
```

### MINOR version (x.Y.z)
- New features (backwards compatible)
- New software bundles
- Configuration enhancements

**Example**: `v1.0.0` → `v1.1.0`

```bash
git tag v1.1.0 -m "Minor release: Add Prometheus and Grafana bundles"
git push origin v1.1.0
```

### PATCH version (x.y.Z)
- Bug fixes
- Security patches
- Minor improvements

**Example**: `v1.1.0` → `v1.1.1`

```bash
git tag v1.1.1 -m "Patch release: Fix K3s configuration issue"
git push origin v1.1.1
```

## Pre-release Versions

Use pre-release identifiers for testing:

### Alpha releases
```bash
git tag v1.2.0-alpha.1 -m "Alpha release for testing"
git push origin v1.2.0-alpha.1
```

### Beta releases
```bash
git tag v1.2.0-beta.1 -m "Beta release for user testing"
git push origin v1.2.0-beta.1
```

### Release candidates
```bash
git tag v1.2.0-rc.1 -m "Release candidate"
git push origin v1.2.0-rc.1
```

## Version Examples

| Git State | Generated Version | Release Type | Artifacts |
|-----------|------------------|---------------|-----------|
| `git tag v1.0.0` | `v1.0.0` | Official Release | ✅ GitHub Release |
| Untagged commit | `v1.0.1-alpha.123` | Development | ✅ Workflow Artifacts |
| Manual: `1.2.0-beta.1` | `v1.2.0-beta.1` | Official Release | ✅ GitHub Release |
| `git tag v2.0.0-rc.1` | `v2.0.0-rc.1` | Official Release | ✅ GitHub Release |

## Best Practices

### 1. **Tag Management**
- Use annotated tags with descriptive messages
- Always push tags to trigger builds
- Don't delete published tags

```bash
# Good: Annotated tag with message
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release"

# Avoid: Lightweight tag without message
git tag v1.0.0
```

### 2. **Release Planning**
- Plan version bumps based on changes
- Document breaking changes for major versions
- Use pre-releases for testing

### 3. **Branch Strategy**
- Main releases from `main` branch
- Hotfixes from `main` or release branches
- Feature development in feature branches

### 4. **Changelog Management**
Keep a CHANGELOG.md with version history:

```markdown
## [1.1.0] - 2024-01-15
### Added
- Prometheus monitoring bundle
- Grafana dashboard bundle
- Enterprise health check scripts

### Changed
- Updated base image to Ubuntu 24.04
- Improved K3s configuration

### Fixed
- Fixed KubeVIP load balancer configuration
```

## Troubleshooting

### Issue: Wrong version generated
**Problem**: Version doesn't match expectation
**Solution**: 
- Check git tags: `git tag -l`
- Verify tag is pushed: `git ls-remote --tags origin`
- Review workflow logs in GitHub Actions

### Issue: No releases created
**Problem**: GitHub release not created automatically
**Solution**:
- Ensure the commit is tagged
- Check that tag push triggered workflow
- Verify release conditions in workflow

### Issue: Development version on tagged commit
**Problem**: Tagged commit shows dev version
**Solution**:
- Ensure tag is pushed to remote: `git push origin v1.0.0`
- Check tag format follows `vX.Y.Z` pattern
- Verify workflow has `fetch-depth: 0` for full git history

## Automated Workflows

### Push to Main/Develop
```
git push → Automatic Build → Development Version → Workflow Artifacts
```

### Tag Push
```
git tag v1.0.0 → git push origin v1.0.0 → Official Build → GitHub Release
```

### Manual Trigger
```
GitHub Actions → Run Workflow → Custom Version → Official Release
```

## Integration with CI/CD

The versioning system integrates seamlessly with:
- **GitHub Releases**: Automatic release creation for tagged versions
- **Artifact Naming**: Consistent naming across ISO/RAW images
- **Security Scanning**: Version-tagged security reports
- **Container Registries**: Semantic version container tags

---

## Summary

This semantic versioning system provides:
- **Automatic version management** based on git workflow
- **Clear release vs development distinction**
- **Professional version numbering**
- **Integration with GitHub releases**
- **Traceability** from version to exact git commit

For questions or issues, refer to the troubleshooting section above or check the GitHub Actions workflow logs.