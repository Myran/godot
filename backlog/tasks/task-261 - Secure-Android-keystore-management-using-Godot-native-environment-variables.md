---
id: task-261
title: Secure Android keystore management using Godot native environment variables
status: Done
assignee: []
created_date: '2025-11-07 08:50'
updated_date: '2025-11-11 21:38'
labels:
  - android
  - security
  - ci-cd
  - godot
  - keystore
dependencies: []
---

## Description

Replace the current insecure Android keystore setup (keystores committed to repository, no password protection) with Godot's native environment variable system for professional-grade security while maintaining excellent developer experience and CI/CD integration.

**Current Security Issues:**
- Keystore files committed to repository (`gametwo-release.keystore`, `android.keystore`)
- No password protection in export configuration
- Cannot distinguish between development and production signing
- Team security risk if repository is compromised

**Godot Native Variables to Leverage:**
- `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_DEBUG_USER`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
- `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`
- `GODOT_SCRIPT_ENCRYPTION_KEY`

## Root Cause Analysis

**Primary Issue:** Current keystore management follows poor security practices:
1. Keystore files stored in version control (binary files with private keys)
2. No password protection mechanism
3. Single keystore used for all environments
4. No team access controls
5. CI/CD cannot use different signing configurations

**Impact:**
- Security vulnerability if repository access is compromised
- Cannot implement proper release signing workflow
- Team members cannot have individual keystore access
- Production builds use same signing as development

## Proposed Solution

Implement environment-based keystore management using Godot's built-in environment variable support:

### 1. Environment Configuration
- Create `.env.template` with all required Godot variables
- Implement `.env` file loading for local development
- Add keystore validation scripts
- Update `.gitignore` to exclude sensitive files

### 2. Build System Integration
- Update Just recipes with environment validation
- Implement secure build workflows (`build-all-android-secure`)
- Add keystore setup scripts for new developers
- Integrate with existing Firebase/Sentry SDK injection system

### 3. CI/CD Pipeline Security
- Update GitHub Actions to use Godot environment variables
- Store keystore files and passwords as GitHub secrets
- Implement environment-specific signing (debug vs release)
- Add build validation and artifact security

### 4. Developer Onboarding
- Create setup scripts for keystore creation/import
- Document security best practices
- Provide troubleshooting guides for common issues
- Implement team access controls

## Success Criteria

### Security Requirements
- [ ] No keystore files committed to repository
- [ ] All passwords stored in secure environment variables
- [ ] Different signing configurations for debug/release environments
- [ ] CI/CD uses production-secure signing process
- [ ] Team access control over keystore files

### Developer Experience
- [ ] Simple one-command setup for new developers
- [ ] Clear error messages for missing/invalid configuration
- [ ] Offline development capability
- [ ] Integration with existing build workflows
- [ ] Backward compatibility with current development flow

### Build System Integration
- [ ] Environment validation before builds
- [ ] Secure build recipes replace existing ones
- [ ] CI/CD pipeline uses environment variables
- [ ] Automatic keystore path resolution
- [ ] Integration with Firebase/Sentry SDK injection

### Documentation & Training
- [ ] Complete setup guide for team members
- [ ] Security best practices documentation
- [ ] Troubleshooting guide for common issues
- [ ] CI/CD configuration documentation

## Implementation Plan

### Phase 1: Foundation (Day 1 - 3 hours)
1. **Environment Setup**
   - Create `.env.template` with Godot variables
   - Update `.gitignore` for keystore files
   - Create keystore validation script (`scripts/load_android_env.sh`)
   - Test environment variable loading

2. **Build System Updates**
   - Update Just recipes with `validate-android-env`
   - Implement `build-all-android-secure` recipe
   - Add environment validation to existing recipes
   - Test local secure builds

### Phase 2: Configuration & Migration (Day 2 - 2 hours)
1. **Export Configuration**
   - Update `project/export_presets.cfg` for environment variables
   - Remove hardcoded keystore paths
   - Test export with environment variables
   - Validate both debug and release builds

2. **Developer Tools**
   - Create keystore setup script (`scripts/setup_keystores.sh`)
   - Add `setup-android-env` Just recipe
   - Document new development workflow
   - Test onboarding process

### Phase 3: CI/CD Integration (Day 2 - 2 hours)
1. **GitHub Actions Updates**
   - Add Godot environment variables to workflow
   - Configure GitHub secrets for keystore data
   - Update build steps to use secure variables
   - Test CI/CD pipeline with new setup

2. **Migration & Cleanup**
   - Remove committed keystore files from repository
   - Add keystore files to `.gitignore`
   - Update project documentation
   - Team training on new workflow

### Phase 4: Testing & Validation (Day 2 - 1 hour)
1. **Comprehensive Testing**
   - Test local development builds
   - Validate CI/CD pipeline builds
   - Test keystore rotation process
   - Verify security requirements met

2. **Documentation Finalization**
   - Update CLAUDE.md with new workflows
   - Create security guidelines document
   - Add troubleshooting section
   - Finalize team onboarding guide

## Technical Implementation Details

### Environment Variables Structure
```bash
# Keystore file paths
GODOT_ANDROID_KEYSTORE_DEBUG_PATH="/path/to/debug.keystore"
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="/path/to/release.keystore"

# Keystore credentials
GODOT_ANDROID_KEYSTORE_DEBUG_USER="debug"
GODOT_ANDROID_KEYSTORE_RELEASE_USER="gametwo"
GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="debug_password"
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="release_password"

# Optional encryption
GODOT_SCRIPT_ENCRYPTION_KEY="encryption_key"
```

### File Structure Changes
```
project/
├── .env.template                 # NEW: Environment template
├── .env                          # NEW: Local environment (gitignored)
├── .gitignore                    # UPDATED: Add keystore exclusions
└── export_presets.cfg           # UPDATED: Remove hardcoded paths

scripts/
├── load_android_env.sh          # NEW: Environment validation
└── setup_keystores.sh           # NEW: Developer keystore setup

keystore/                         # NEW: Local keystore directory (gitignored)
├── gametwo-debug.keystore
└── gametwo-release.keystore

.github/workflows/
└── android-build.yml            # UPDATED: Godot environment variables

justfiles/
└── justfile-platform-android.justfile  # UPDATED: Secure build recipes
```

## Risk Assessment & Mitigation

### Security Risks
- **Risk**: Developers commit `.env` files accidentally
  - **Mitigation**: Strong `.gitignore` rules, pre-commit hooks
- **Risk**: Weak keystore passwords chosen
  - **Mitigation**: Password generation in setup scripts, security guidelines
- **Risk**: GitHub secrets compromised
  - **Mitigation**: Access restrictions, regular rotation, audit logging

### Operational Risks
- **Risk**: Build failures due to missing environment
  - **Mitigation**: Comprehensive validation, clear error messages
- **Risk**: Team onboarding friction
  - **Mitigation**: Automated setup scripts, detailed documentation
- **Risk**: CI/CD pipeline breakage
  - **Mitigation**: Staged rollout, backward compatibility, testing

### Compatibility Risks
- **Risk**: Godot environment variable support issues
  - **Mitigation**: Thorough testing, fallback to manual configuration
- **Risk**: Existing tool integration problems
  - **Mitigation**: Gradual migration, maintain legacy options temporarily

## Acceptance Criteria

### Must-Have Requirements
- [ ] All keystore files removed from version control
- [ ] Local development uses `.env` file with Godot variables
- [ ] CI/CD pipeline uses GitHub secrets for keystore data
- [ ] Build system validates environment before building
- [ ] Both debug and release APK/AAB generation works
- [ ] New developer onboarding takes < 10 minutes

### Should-Have Requirements
- [ ] Keystore rotation process documented and tested
- [ ] Integration with existing Firebase/Sentry SDK injection
- [ ] Automatic keystore creation in setup script
- [ ] Environment-specific build configurations
- [ ] Security audit checklist for team reviews

### Could-Have Requirements
- [ ] Multiple keystore support (different team members)
- [ ] Keystore backup and recovery procedures
- [ ] Integration with external secret management systems
- [ ] Automated security scanning of build artifacts

## Definition of Done

The task is complete when:
1. **Security**: No sensitive keystore data in repository, all credentials in environment variables
2. **Functionality**: Both local development and CI/CD builds work with new system
3. **Documentation**: Complete setup and security guides available
4. **Testing**: Comprehensive testing of all build scenarios
5. **Team Readiness**: All team members trained on new workflow
6. **Migration**: Clean migration from old system with no data loss

## Related Tasks & Documents

### Dependencies
- **task-259**: Firebase + Sentry Android SDK integration system (uses same build pipeline)
- **doc-002**: Build System Architecture & Workflows (reference for build recipes)

### Related Documentation
- `CLAUDE.md`: Update with new Android build workflows
- Build system documentation: Keystore security guidelines
- Team onboarding: Android development setup instructions

### External References
- Godot 4.x Export Documentation: Environment variable support
- Android App Signing Best Practices: Security guidelines
- GitHub Actions Security: Secrets management documentation
