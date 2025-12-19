---
id: task-336
title: >-
  Setup UTM macOS VM with GitHub Actions Self-Hosted Runner for automated CI/CD
  on master merges
status: Consider
assignee: []
created_date: '2025-12-13 23:51'
updated_date: '2025-12-15 08:33'
labels:
  - infrastructure
  - ci-cd
  - automation
  - github-actions
  - self-hosted-runner
dependencies:
  - task-335
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a UTM macOS VM on the Mac Mini with a GitHub Actions self-hosted runner that automatically picks up and executes test, build, and export jobs when changes are merged to master.

## Goals
- Set up UTM macOS VM on Mac Mini with GitHub Actions self-hosted runner
- Configure runner to trigger on master branch merges (push events)
- Automate test execution (Android, desktop, macOS)
- Automate build pipelines (templates, APK, AAB, iOS, macOS exports)
- Handle export jobs for release artifacts with artifact upload

## Why macOS VM
- Required for Xcode/iOS builds
- Required for macOS .app/.dmg exports
- Native Apple toolchain access
- Consistent with host Mac Mini environment
- Self-hosted runners with macOS give full control over environment

## Repository Details
- **Repository**: https://github.com/Myran/gametwo.git
- **Branch trigger**: `master` (push events)
- **Runner labels**: `self-hosted`, `macOS`, `ARM64`, `gametwo-ci`

---

## Runner Setup Steps

### Step 1: Add Runner in GitHub Settings
1. Navigate to repository Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Select **macOS** and **ARM64** architecture
4. GitHub provides download URL and registration token

### Step 2: Install Runner in UTM VM
```bash
# Create dedicated user for runner
sudo dscl . -create /Users/gh-runner
sudo dscl . -create /Users/gh-runner UserShell /bin/zsh
sudo dscl . -create /Users/gh-runner RealName "GitHub Runner"
sudo dscl . -create /Users/gh-runner UniqueID 550
sudo dscl . -create /Users/gh-runner PrimaryGroupID 20
sudo dscl . -passwd /Users/gh-runner <password>
sudo dscl . -append /Groups/admin GroupMembership gh-runner

# Create runner directory
mkdir ~/actions-runner && cd ~/actions-runner

# Download runner (version will be shown in GitHub UI)
curl -o actions-runner-osx-arm64-2.x.x.tar.gz -L https://github.com/actions/runner/releases/download/v2.x.x/actions-runner-osx-arm64-2.x.x.tar.gz
tar xzf ./actions-runner-osx-arm64-2.x.x.tar.gz

# Configure runner with custom labels
./config.sh --url https://github.com/Myran/gametwo --token <TOKEN> --labels gametwo-ci

# Verify runner connects
./run.sh
```

### Step 3: Install as launchd Service
```bash
# Stop runner if running interactively
# Install service
./svc.sh install

# Start service
./svc.sh start

# Verify status
./svc.sh status

# Service name format: actions.runner.Myran-gametwo.<runnerName>
# Check service file: cat ~/actions-runner/.service
```

### Step 4: Troubleshooting macOS Permissions
If `./svc.sh install` fails with permission errors:
1. System Preferences → Security & Privacy → Privacy → Full Disk Access
2. Click lock to unlock, add `/bin/bash` and Terminal app
3. Grant read/write to LaunchAgents directory

---

## Workflow File Configuration

Create `.github/workflows/ci-cd.yml`:

```yaml
name: 🚀 GameTwo CI/CD

on:
  push:
    branches:
      - master

env:
  GODOT_VERSION: "4.3"

jobs:
  # Validation job
  validate:
    runs-on: [self-hosted, macOS, ARM64, gametwo-ci]
    timeout-minutes: 15
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Run CI Validation
        run: just ci-validate

  # Test jobs
  test-desktop:
    runs-on: [self-hosted, macOS, ARM64, gametwo-ci]
    needs: validate
    timeout-minutes: 30
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Run Desktop Tests
        run: just test-desktop-target development-workflow

      - name: Upload Test Logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: desktop-test-logs
          path: logs/
          retention-days: 7

  test-android:
    runs-on: [self-hosted, macOS, ARM64, gametwo-ci]
    needs: validate
    timeout-minutes: 45
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Build Android (fastbuild)
        run: just fastbuild-android

      - name: Run Android Tests
        run: just test-android-target development-workflow

      - name: Upload Test Logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: android-test-logs
          path: logs/
          retention-days: 7

  test-macos:
    runs-on: [self-hosted, macOS, ARM64, gametwo-ci]
    needs: validate
    timeout-minutes: 30
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Run macOS Tests
        run: just test-macos-target development-workflow

      - name: Upload Test Logs
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: macos-test-logs
          path: logs/
          retention-days: 7

  # Build jobs (only if tests pass)
  build-android:
    runs-on: [self-hosted, macOS, ARM64, gametwo-ci]
    needs: [test-desktop, test-android, test-macos]
    timeout-minutes: 120
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Build Android (full pipeline)
        run: just build-all-android

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: project/exports/*.apk
          retention-days: 30

      - name: Upload AAB
        uses: actions/upload-artifact@v4
        with:
          name: android-aab
          path: project/exports/*.aab
          retention-days: 30

  build-ios:
    runs-on: [self-hosted, macOS, ARM64, gametwo-ci]
    needs: [test-desktop, test-android, test-macos]
    timeout-minutes: 120
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Build iOS Pipeline
        run: just build-pipeline-ios

      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: ios-ipa
          path: project/exports/*.ipa
          retention-days: 30

  build-macos:
    runs-on: [self-hosted, macOS, ARM64, gametwo-ci]
    needs: [test-desktop, test-android, test-macos]
    timeout-minutes: 60
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Build macOS Export
        run: just export-macos

      - name: Upload macOS App
        uses: actions/upload-artifact@v4
        with:
          name: macos-app
          path: project/exports/*.dmg
          retention-days: 30
```

---

## VM Environment Requirements

### Required Software in UTM macOS VM:
- **Xcode** (latest stable) + Command Line Tools
- **Android SDK** (via Android Studio or sdkmanager)
- **Java 17** (Temurin/OpenJDK)
- **Python 3.x** + SCons
- **Homebrew** for package management
- **just** command runner (`brew install just`)
- **Godot 4.3** custom build (from project)
- **CocoaPods** (`sudo gem install cocoapods`)
- **Git** with SSH keys configured

### Environment Variables to Configure:
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin
```

### Android Device Connection:
- USB passthrough from Mac Mini host to UTM VM
- Or use `adb connect` for wireless debugging
- Verify with `adb devices` in VM

---

## Artifact Storage
- **Retention**: 30 days for builds, 7 days for logs
- **Access**: Download from GitHub Actions UI or via API
- **Size limits**: 500 artifacts per job, individual files up to 10GB

## Notifications
Configure GitHub repository settings for:
- Email notifications on workflow failure
- Slack/Discord webhook integration (optional)
- Branch protection rules requiring CI pass

## Security Considerations
- Runner registered to private repository only
- Dedicated `gh-runner` user with limited permissions
- VM isolation provides additional security layer
- Secrets stored in GitHub repository settings (not in workflow files)

## Monitoring
```bash
# Check runner service status
./svc.sh status

# View launchd logs
launchctl print user/$(id -u)/actions.runner.Myran-gametwo.<runnerName>

# Check runner diagnostic logs
cat ~/actions-runner/_diag/*.log
```
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 UTM macOS VM created and running on Mac Mini
- [ ] #2 GitHub Actions self-hosted runner registered to repository
- [ ] #3 Runner configured as launchd service (starts on boot)
- [ ] #4 Development tools installed (Xcode, Android SDK, Java 17, Python, SCons, just)
- [ ] #5 Workflow file created at .github/workflows/ci-cd.yml
- [ ] #6 Workflow triggers on push to master branch
- [ ] #7 Validation job runs just ci-validate
- [ ] #8 Test jobs run for desktop, Android, and macOS platforms
- [ ] #9 Build jobs produce APK, AAB, IPA, and DMG artifacts
- [ ] #10 Artifacts uploaded to GitHub with appropriate retention
- [ ] #11 Android device accessible from VM (USB passthrough or wireless ADB)
- [ ] #12 Runner successfully completes full CI/CD pipeline end-to-end
<!-- AC:END -->
