---
id: task-279
title: Setup Tart macOS VM as GitLab CI/CD Runner for Multi-Platform Builds
status: To Do
assignee: []
created_date: '2025-11-12 21:32'
updated_date: '2025-11-12 23:15'
labels:
  - infrastructure
  - ci-cd
  - build-system
  - multi-platform
dependencies: []
priority: high
---

## Description

Set up a Tart macOS VM as a GitLab CI/CD runner to automate building, testing, and packaging GameTwo for all target platforms (iOS, Android, macOS, Windows). The VM will start from a clean snapshot for each job, ensuring reproducible builds.

**Business Value:**
- Automated cross-platform builds and testing
- Reproducible CI/CD environment via snapshots
- Faster iteration cycles with parallel builds
- Automated deployment via Fastlane
- Reduced manual build/test overhead

**On-Demand Orchestration (Mac mini):**
- Mac mini runs GitLab runner service 24/7 (lightweight, ~50MB RAM)
- VMs are created **only when GitLab jobs trigger**
- Each job gets a fresh VM cloned from snapshot
- VMs are automatically deleted after job completes
- Mac mini returns to idle state between builds (no VMs running)
- Zero manual intervention required

## GitLab Job Queue & Runner Lifecycle

**IMPORTANT: Jobs wait for runners - you can set up the runner at any time!**

### Job States & Timeline

```
Timeline:
---------
T+0min:   Push code → Pipeline triggers → Jobs created
T+0min:   Jobs enter "pending" state (waiting for runner)
          Status: "This job is stuck because you don't have any active runners"

          ... Jobs wait here indefinitely ...
          ... (or until timeout, default: no timeout) ...

T+3days:  Mac mini runner comes online and registers
T+3days:  Runner polls GitLab, discovers pending jobs
T+3days:  Jobs automatically transition to "running" state
T+3days:  Builds execute normally

Result: No jobs lost, everything works as expected!
```

### Common Scenarios

**Scenario 1: Runner Not Set Up Yet**
```
✅ SAFE to push code before runner exists
→ Jobs queue up in GitLab
→ Set up runner whenever ready (hours/days/weeks later)
→ Jobs execute automatically once runner registers
```

**Scenario 2: Mac mini Powered Off**
```
✅ SAFE to trigger pipelines while Mac mini offline
→ Jobs wait in pending state
→ Turn on Mac mini / start runner service
→ Jobs execute automatically
```

**Scenario 3: Multiple Pipelines (Sequential Execution)**
```
Pipeline A triggers → 5 jobs created
Pipeline B triggers → 5 jobs created (10 total queued)

Runner (concurrent=1) executes:
→ Pipeline A Job 1 (iOS build)     [20 min]
→ Pipeline A Job 2 (Android build) [15 min]
→ Pipeline A Job 3 (macOS build)   [10 min]
→ Pipeline B Job 1 (iOS build)     [20 min]
... etc ...

Total time: ~165 min for 10 jobs
```

**Scenario 4: Runner Configuration Changes**
```
✅ SAFE to update runner config while jobs pending
→ Stop runner: sudo gitlab-runner stop
→ Edit config: nano ~/.gitlab-runner/config.toml
→ Restart runner: sudo gitlab-runner start
→ Pending jobs pick up new configuration
```

### Job Timeout Configuration

**Default Behavior:**
- Jobs wait indefinitely for runner (no timeout)
- Can be configured per job or globally

**Optional Timeout (in .gitlab-ci.yml):**
```yaml
# Fail job if no runner available within 1 hour
ci-validate:
  stage: validate
  timeout: 1h
  tags:
    - macos
    - tart
```

**Project-Level Timeout:**
- GitLab UI: Settings → CI/CD → General pipelines → Timeout
- Default: 60 minutes (can be increased)

### Development Workflow Flexibility

This means you can:

1. **Develop `.gitlab-ci.yml` first**
   - Push pipeline configurations
   - See what jobs would run (they'll be pending)
   - Set up runner later when ready

2. **Test runner setup incrementally**
   - Trigger test pipeline
   - Set up runner
   - See if it picks up jobs
   - Iterate on configuration

3. **Gradual rollout**
   - Start with basic runner (shell executor)
   - See jobs execute
   - Upgrade to custom executor with Tart later
   - Jobs continue working throughout

4. **Maintenance windows**
   - Stop runner for Mac mini updates
   - Jobs queue up during maintenance
   - Start runner when ready
   - Jobs resume automatically

### Monitoring Pending Jobs

**GitLab UI:**
- Project → CI/CD → Pipelines
- Jobs show "pending" with reason (waiting for runner)

**GitLab CLI (optional):**
```bash
# Install glab CLI
brew install glab

# List pending jobs
glab ci view

# Check runner status from GitLab's perspective
glab runner list
```

**Mac mini Runner Logs:**
```bash
# Watch runner pick up jobs
sudo tail -f /var/log/gitlab-runner.log

# You'll see:
# "Checking for jobs... received" (when job assigned)
# "Job succeeded" (when job completes)
```

## Technical Requirements

**Host System:**
- macOS host (Apple Silicon or Intel)
- Tart installed (`brew install cirruslabs/cli/tart`)
- Sufficient storage for VM snapshots (~100GB+)
- GitLab runner binary

**Build Dependencies:**
- Xcode (iOS/macOS builds)
- Android SDK/NDK (currently in `extras/android-sdk/`)
- Godot custom engine build toolchain (SCons, compilers)
- Fastlane (deployment automation)
- Cross-compilation tools for Windows (if building from macOS)

**GitLab Integration:**
- GitLab repository with `.gitlab-ci.yml`
- Runner registration token
- Artifact storage configuration

## Implementation Plan

**IMPORTANT: Follow phases sequentially. Each phase validates the previous one works before moving forward.**

### Phase 1: Tart Installation & First VM

**Goal:** Get Tart installed and a basic macOS VM running on Mac mini.

**1.1 Install Tart**
```bash
# On Mac mini host
brew install cirruslabs/cli/tart

# Verify installation
tart --version
```

**1.2 Pull macOS Base Image**
```bash
# Download official macOS Sonoma image (~12 GB, takes 10-20 min)
tart clone ghcr.io/cirruslabs/macos-sonoma-vanilla:latest gametwo-builder

# Verify image downloaded
tart list
# Should show: gametwo-builder
```

**1.3 Start VM for First Time**
```bash
# Start VM (opens in new window)
tart run gametwo-builder

# Wait for VM to boot (1-2 min)
# You should see macOS desktop
```

**1.4 Configure VM Networking & SSH**
Inside VM (using GUI):
```bash
# Open Terminal in VM

# Get VM IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# Enable Remote Login (SSH)
# System Settings → General → Sharing → Remote Login → Enable

# Create/set admin user password
sudo passwd admin
```

**1.5 Test SSH Access from Host**
```bash
# On Mac mini host (NOT in VM)
# Get VM IP
tart ip gametwo-builder
# Example: 192.168.64.3

# SSH into VM
ssh admin@192.168.64.3

# If successful, you're now in the VM via SSH!
# Exit SSH: exit
```

**✅ VALIDATION: Can SSH into VM from Mac mini host**

**1.6 (OPTIONAL) Easy SSH Access - Create Helper Script**

Instead of `tart ip` → copy → paste, create a quick SSH helper:

```bash
# On Mac mini host
cat > /usr/local/bin/tart-ssh <<'EOF'
#!/bin/bash
# Easy SSH into Tart VMs
VM_NAME="${1:-gametwo-builder}"

if ! tart list | grep -q "^$VM_NAME"; then
  echo "❌ VM not found: $VM_NAME"
  echo "Available VMs:"
  tart list
  exit 1
fi

VM_IP=$(tart ip "$VM_NAME" 2>/dev/null)
if [ -z "$VM_IP" ]; then
  echo "❌ VM not running: $VM_NAME"
  exit 1
fi

echo "🔌 Connecting to $VM_NAME at $VM_IP..."
ssh -o StrictHostKeyChecking=no admin@$VM_IP
EOF

chmod +x /usr/local/bin/tart-ssh

# Now you can just:
tart-ssh gametwo-builder
# Or for any VM:
tart-ssh gametwo-builder-configured
```

**1.7 (OPTIONAL) Tailscale Integration - Access VM from Anywhere**

**Why Tailscale?**
- Stable hostname/IP that doesn't change
- Access VM from your laptop, not just Mac mini
- Debug CI jobs remotely
- Secure mesh network (encrypted)

**Setup Tailscale in VM:**

```bash
# Inside VM (via tart-ssh or GUI)

# Install Tailscale
brew install tailscale

# Start Tailscale daemon
sudo brew services start tailscale

# Authenticate (opens browser)
sudo tailscale up

# Follow the browser link to authenticate with your Tailscale account

# Get Tailscale IP
tailscale ip -4
# Example: 100.101.102.103

# Set a hostname (optional but recommended)
sudo tailscale set --hostname gametwo-vm
```

**Configure Tailscale to persist across VM clones:**

```bash
# Inside VM

# Enable key persistence (so cloned VMs don't need re-auth)
sudo tailscale set --advertise-tags=tag:ci

# Or use an auth key for automatic re-auth
# Get reusable auth key from: https://login.tailscale.com/admin/settings/keys
# Then add to VM startup script
```

**Update SSH config on your laptop/Mac mini:**

```bash
# On Mac mini host (or your laptop)
cat >> ~/.ssh/config <<EOF

# GameTwo Tart VMs (via Tailscale)
Host gametwo-vm
  HostName 100.101.102.103  # Your VM's Tailscale IP
  User admin
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

# Or use Tailscale hostname
Host gametwo-vm
  HostName gametwo-vm.your-tailnet.ts.net
  User admin
EOF

# Now SSH from anywhere:
ssh gametwo-vm
```

**Tailscale for CI/CD Debugging:**

```bash
# During a CI job, check job logs for VM name
# Example: gametwo-builder-job-12345

# From your laptop (with Tailscale running):
tailscale status | grep gametwo
# Find the running VM

# SSH directly
ssh admin@gametwo-vm.your-tailnet.ts.net

# Debug inside running CI job
cd ~/workspace/gametwo
just build-status
tail -f logs/*.log
```

**✅ Benefits:**
- One-time setup, works forever
- Access from anywhere (laptop, phone, etc.)
- No need for `tart ip` lookups
- Stable hostname even across VM clones (if configured properly)

**⚠️ Considerations:**
- Requires Tailscale account (free tier sufficient)
- Cloned VMs inherit Tailscale config (may need re-auth strategy)
- For ephemeral CI VMs, simpler to stick with local SSH

**1.8 Create Base Snapshot**
```bash
# On Mac mini host
tart stop gametwo-builder

# Create base snapshot (takes 2-3 min)
tart clone gametwo-builder gametwo-builder-base

# Verify
tart list
# Should show both: gametwo-builder, gametwo-builder-base
```

---

### Phase 2: VM Build Environment Setup

**Goal:** Install all dependencies needed to build GameTwo and validate builds work.

**2.1 Install Xcode**

Inside VM (via SSH or GUI):
```bash
# Option A: Download from App Store (recommended)
# Open App Store → Search "Xcode" → Install (12 GB, takes 30-60 min)

# Option B: Download from Apple Developer
# https://developer.apple.com/download/all/
# Download Xcode 15.x xip file → Extract → Move to /Applications

# Accept license
sudo xcodebuild -license accept

# Install command line tools
xcode-select --install

# Verify
xcodebuild -version
# Should show: Xcode 15.x
```

**2.2 Install Homebrew & Build Tools**
```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (follow Homebrew's instructions)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install build tools
brew install git scons cmake just python@3.11

# Verify
git --version
scons --version
just --version
```

**2.3 Install Platform SDKs**

**Android SDK Setup:**
```bash
# GameTwo uses Android SDK in extras/android-sdk/
# We'll set this up after cloning the repo
```

**iOS/macOS SDK:**
```bash
# Already included with Xcode (no extra steps)
```

**Windows Cross-Compilation (optional):**
```bash
# Only if building Windows from macOS
brew install mingw-w64
```

**2.4 Clone GameTwo Repository**
```bash
# Inside VM

# Create workspace
mkdir -p ~/workspace
cd ~/workspace

# Clone repo (replace with your repo URL)
git clone <your-gametwo-repo-url> gametwo
cd gametwo

# Initialize submodules (Firebase C++ SDK, Godot, etc.)
git submodule update --init --recursive

# This takes 5-10 min depending on submodule sizes
```

**2.5 Install GameTwo Dependencies**
```bash
cd ~/workspace/gametwo

# Install Python dependencies (if any)
pip3 install -r requirements.txt || echo "No requirements.txt"

# Verify build system
just --list

# Should show all GameTwo build commands
```

**2.6 Validate Build System**

**CRITICAL: This step proves the VM can actually build GameTwo**

```bash
cd ~/workspace/gametwo

# Step 1: Check build status
just build-status

# Should show:
# ✅ Godot engine: Ready
# ✅ Android SDK: Found
# ✅ Build tools: Installed

# Step 2: Run CI validation
just ci-validate

# Should pass all format/lint/syntax checks
# If fails: Fix issues before proceeding
```

**2.7 Test Full Android Build (CRITICAL VALIDATION)**
```bash
cd ~/workspace/gametwo

# This is the BIG test - can we actually build?
just build-all-android

# This takes 15-60 min depending on:
# - First build: ~60 min (compiles Godot engine)
# - Subsequent builds: ~15 min (uses cache)

# Expected output:
# 📦 Building Godot templates...
# 🔨 Building Android APK...
# ✅ Build complete: platform/android/build/outputs/
```

**✅ VALIDATION CHECKLIST:**
- [ ] `just build-status` shows all dependencies found
- [ ] `just ci-validate` passes without errors
- [ ] `just build-all-android` completes successfully
- [ ] APK file exists: `ls platform/android/build/outputs/*.apk`

**If any validation fails, STOP and fix issues before Phase 3.**

**2.8 Create Configured Snapshot**
```bash
# On Mac mini host (NOT in VM)

# Stop the VM
tart stop gametwo-builder

# Create snapshot with full build environment
tart clone gametwo-builder gametwo-builder-configured

# Verify
tart list
# Should show: gametwo-builder-base, gametwo-builder-configured
```

---

### Phase 3: Basic GitLab Runner Setup

**Goal:** Get GitLab runner working with basic shell executor, test one simple job.

**3.1 Get GitLab Runner Token**

In GitLab web UI:
```
Your Project → Settings → CI/CD → Runners → Expand

→ Click "New project runner"
→ Select "macOS" platform
→ Tags: macos, shell
→ Copy the registration token (glrt-...)
```

**3.2 Install GitLab Runner on Mac mini**
```bash
# On Mac mini host (NOT in VM)

# Download runner binary
sudo curl -L "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-darwin-arm64" -o /usr/local/bin/gitlab-runner

# Make executable
sudo chmod +x /usr/local/bin/gitlab-runner

# Verify
gitlab-runner --version
```

**3.3 Register Runner (Shell Executor - Simple)**
```bash
# On Mac mini host

gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "YOUR_TOKEN_FROM_STEP_3.1" \
  --executor "shell" \
  --description "gametwo-macos-shell" \
  --tag-list "macos,shell"

# Verify registration
gitlab-runner verify
# Should show: Runner registered successfully
```

**3.4 Start Runner Service**
```bash
# Install as system service
sudo gitlab-runner install --user=$(whoami)

# Start service
sudo gitlab-runner start

# Verify running
sudo gitlab-runner status
# Should show: Service is running
```

**3.5 Create Simple Test Pipeline**

Create `.gitlab-ci.yml` in your repo:
```yaml
# Simple test - just verify runner works
stages:
  - test

hello-world:
  stage: test
  tags:
    - macos
    - shell
  script:
    - echo "Hello from GitLab runner!"
    - hostname
    - whoami
    - pwd
```

**3.6 Test First Job**
```bash
# Commit and push
git add .gitlab-ci.yml
git commit -m "Test: Basic GitLab CI"
git push

# Watch in GitLab UI:
# Project → CI/CD → Pipelines
#
# Job should:
# ✅ Status: "pending" → "running" → "passed"
# ✅ Output shows: hostname, username, current directory
```

**✅ VALIDATION: First job runs successfully on Mac mini**

**3.7 Test Build Job (Validation Before Tart)**

Update `.gitlab-ci.yml`:
```yaml
stages:
  - validate
  - build

ci-validate:
  stage: validate
  tags:
    - macos
    - shell
  script:
    - cd ~/workspace/gametwo
    - git pull
    - just ci-validate

build-android:
  stage: build
  tags:
    - macos
    - shell
  script:
    - cd ~/workspace/gametwo
    - git pull
    - git submodule update --recursive
    - just build-all-android
  artifacts:
    paths:
      - platform/android/build/outputs/
    expire_in: 1 day
```

Push and verify both jobs complete successfully.

**✅ VALIDATION CHECKPOINT:**
- [ ] GitLab runner service running on Mac mini
- [ ] Simple hello-world job passes
- [ ] Build job compiles Android successfully
- [ ] Artifacts appear in GitLab UI

**STOP: Do not proceed to Phase 4 until all validations pass.**

---

### Phase 4: GitLab Tart Executor Integration

**Goal:** Upgrade from shell executor to Tart executor for isolated VM-per-job builds.

**4.1 Install GitLab Tart Executor**
```bash
# On Mac mini host
brew install cirruslabs/cli/gitlab-tart-executor

# Verify installation
gitlab-tart-executor --version
```

**4.2 Unregister Shell Runner**
```bash
# On Mac mini host

# List current runners
gitlab-runner list

# Unregister shell runner (we'll use Tart executor instead)
gitlab-runner unregister --name gametwo-macos-shell

# Verify removed
gitlab-runner list
# Should show empty or no runners
```

**4.3 Register Tart Executor Runner**
```bash
# On Mac mini host

gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "YOUR_TOKEN" \
  --executor "custom" \
  --description "gametwo-tart-executor" \
  --tag-list "tart,macos"

# Verify
gitlab-runner verify
```

**4.4 Configure Custom Executor**

Edit `~/.gitlab-runner/config.toml`:
```toml
concurrent = 1  # Start with 1, increase later for parallel builds

[[runners]]
  name = "gametwo-tart-executor"
  url = "https://gitlab.com/"
  token = "RUNNER_TOKEN_AUTO_GENERATED"
  executor = "custom"

  [runners.custom]
    config_exec = "gitlab-tart-executor"
    config_args = ["config"]

    prepare_exec = "gitlab-tart-executor"
    prepare_args = [
      "prepare",
      "--default-image", "localhost/gametwo-builder-configured",
      "--concurrency", "1",
      "--cpu", "auto",
      "--memory", "auto"
    ]

    run_exec = "gitlab-tart-executor"
    run_args = ["run"]

    cleanup_exec = "gitlab-tart-executor"
    cleanup_args = ["cleanup"]
```

**4.5 Restart Runner**
```bash
# Apply new configuration
sudo gitlab-runner restart

# Verify
sudo gitlab-runner status
gitlab-runner verify
```

**4.6 Update .gitlab-ci.yml for Tart**
```yaml
# Specify VM image to use
image: localhost/gametwo-builder-configured

stages:
  - validate
  - build

ci-validate:
  stage: validate
  tags:
    - tart  # Changed from: macos, shell
  script:
    - cd ~/workspace/gametwo
    - git fetch origin
    - git checkout ${CI_COMMIT_SHA}
    - just ci-validate

build-android:
  stage: build
  tags:
    - tart
  script:
    - cd ~/workspace/gametwo
    - git fetch origin
    - git checkout ${CI_COMMIT_SHA}
    - git submodule update --recursive
    - just build-all-android
  artifacts:
    paths:
      - platform/android/build/outputs/
    expire_in: 1 day
```

**4.7 Test Tart Executor**
```bash
# Push changes
git add .gitlab-ci.yml
git commit -m "CI: Switch to Tart executor"
git push

# Watch in GitLab UI for:
# 1. Job picks up on "tart" tagged runner
# 2. Check job logs show VM cloning
# 3. Build completes successfully
# 4. Check Mac mini: tart list (VM should be deleted after job)
```

**✅ VALIDATION:**
- [ ] Job runs in isolated VM (check logs for "Cloning VM...")
- [ ] Build completes successfully
- [ ] VM automatically deleted after job (`tart list` shows only snapshots)
- [ ] Artifacts uploaded to GitLab

**4.8 Verify VM Lifecycle**
```bash
# On Mac mini, watch VM lifecycle during job

# Terminal 1: Watch Tart VMs
watch -n 2 tart list

# Terminal 2: Watch runner logs
sudo tail -f /var/log/gitlab-runner.log

# You should see:
# - VM appears when job starts
# - VM disappears when job completes
# - Snapshots remain (gametwo-builder-*)
```

---

### Phase 5: Multi-Platform Build Pipeline

**Goal:** Add builds for all platforms (iOS, macOS, Windows).

**5.1 Add iOS/macOS Build Commands to Justfile**

First, ensure GameTwo has build commands for all platforms. Add to `justfile` if missing:

```justfile
# iOS build
build-ios:
    scons platform=ios target=template_debug
    # Add iOS-specific build steps

# macOS build
build-macos:
    scons platform=macos target=template_debug
    # Add macOS-specific build steps

# Windows cross-compile build
build-windows:
    scons platform=windows target=template_debug
    # Add Windows cross-compile steps
```

**5.2 Expand .gitlab-ci.yml for Multi-Platform**
```yaml
image: localhost/gametwo-builder-configured

stages:
  - validate
  - build
  - test

variables:
  GIT_SUBMODULE_STRATEGY: recursive

# CI Validation
ci-validate:
  stage: validate
  tags: [tart]
  script:
    - cd ~/workspace/gametwo
    - git fetch origin
    - git checkout ${CI_COMMIT_SHA}
    - just ci-validate
  only:
    - merge_requests
    - main

# Android Build
build-android:
  stage: build
  tags: [tart]
  script:
    - cd ~/workspace/gametwo
    - git fetch origin
    - git checkout ${CI_COMMIT_SHA}
    - git submodule update --recursive
    - just build-all-android
  artifacts:
    paths:
      - platform/android/build/outputs/
    expire_in: 1 week
  only:
    - main
    - merge_requests

# iOS Build
build-ios:
  stage: build
  tags: [tart]
  script:
    - cd ~/workspace/gametwo
    - git fetch origin
    - git checkout ${CI_COMMIT_SHA}
    - git submodule update --recursive
    - just build-ios
  artifacts:
    paths:
      - platform/ios/build/
    expire_in: 1 week
  only:
    - main
    - merge_requests

# macOS Build
build-macos:
  stage: build
  tags: [tart]
  script:
    - cd ~/workspace/gametwo
    - git fetch origin
    - git checkout ${CI_COMMIT_SHA}
    - just build-macos
  artifacts:
    paths:
      - platform/macos/build/
    expire_in: 1 week
  only:
    - main

# Windows Cross-Compile Build (optional)
build-windows:
  stage: build
  tags: [tart]
  script:
    - cd ~/workspace/gametwo
    - git fetch origin
    - git checkout ${CI_COMMIT_SHA}
    - just build-windows
  artifacts:
    paths:
      - platform/windows/build/
    expire_in: 1 week
  only:
    - main
  allow_failure: true  # Windows cross-compile may have limitations

# Comprehensive Testing
test-all-platforms:
  stage: test
  tags: [tart]
  script:
    - cd ~/workspace/gametwo
    - git fetch origin
    - git checkout ${CI_COMMIT_SHA}
    - just log-run-silent test
    - just test-desktop-target development-workflow
  dependencies:
    - build-android
  artifacts:
    paths:
      - logs/
    when: always
  only:
    - main
    - merge_requests
```

**5.3 Test Multi-Platform Pipeline**
```bash
git add .gitlab-ci.yml justfile
git commit -m "CI: Add multi-platform builds"
git push

# Watch pipeline in GitLab UI
# All build jobs should run sequentially (concurrent=1)
```

**✅ VALIDATION:**
- [ ] All platform build jobs complete successfully
- [ ] Artifacts uploaded for each platform
- [ ] Test job runs after builds complete
- [ ] Total pipeline time reasonable (<60 min)

**5.4 Enable Parallel Builds (Optional Optimization)**

If Mac mini has sufficient resources (16GB+ RAM, 8+ cores):

```toml
# Edit ~/.gitlab-runner/config.toml
concurrent = 2  # Allow 2 jobs in parallel

[[runners]]
  # ... existing config ...
  [runners.custom]
    prepare_args = [
      "prepare",
      "--concurrency", "2",  # Match concurrent setting
      "--cpu", "auto",       # Auto-split CPUs
      "--memory", "auto"     # Auto-split RAM
    ]
```

Restart runner and test:
```bash
sudo gitlab-runner restart

# Push a commit
# iOS and Android builds should run in parallel now
```

---

### Phase 6: Smart Incremental Snapshot Strategy (ADVANCED)

**Goal:** Optimize build times by detecting dependency changes and only rebuilding when necessary.

**Prerequisites:** Phases 1-5 must be working reliably before implementing this.

**6.1 Add Host Runner for Snapshot Management**

We need a runner on the Mac mini HOST (not in VM) to manage snapshot updates.

```bash
# On Mac mini host

# Register host runner (in addition to Tart executor)
gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "YOUR_TOKEN" \
  --executor "shell" \
  --description "gametwo-macos-host" \
  --tag-list "macos-host,orchestrator"

# Verify both runners registered
gitlab-runner list
# Should show:
# 1. gametwo-tart-executor (custom executor)
# 2. gametwo-macos-host (shell executor)
```

**6.2 Create Snapshot Management Script**

Create `/usr/local/bin/rebuild-and-snapshot.sh`:
```bash
#!/bin/bash
# Rebuild dependencies and update snapshot

set -e

REBUILD_STRATEGY="${1:-full}"
CI_COMMIT_SHA="${2:-HEAD}"

echo "🔧 Rebuild strategy: ${REBUILD_STRATEGY}"
echo "📋 Commit SHA: ${CI_COMMIT_SHA}"

# Create temporary VM for rebuild
VM_NAME="gametwo-rebuild-$(date +%s)"
echo "📦 Cloning VM: gametwo-builder-configured → ${VM_NAME}"
tart clone gametwo-builder-configured "${VM_NAME}"

# Start VM and run rebuild
echo "▶️  Starting VM for rebuild..."
tart run "${VM_NAME}" &
sleep 30  # Wait for VM to boot

# Get VM IP
VM_IP=$(tart ip "${VM_NAME}")
echo "✅ VM ready at ${VM_IP}"

# Execute rebuild inside VM
echo "🔨 Running rebuild inside VM..."
ssh -o StrictHostKeyChecking=no "admin@${VM_IP}" bash <<EOF
  set -e
  cd ~/workspace/gametwo
  git fetch origin
  git checkout ${CI_COMMIT_SHA}
  git submodule update --recursive

  case "${REBUILD_STRATEGY}" in
    full)
      echo "🔨 Full rebuild (Godot + all platforms)"
      just clean-all
      just build-godot-engine
      just build-all-android
      just build-ios
      just ci-validate
      ;;
    firebase_only)
      echo "🔨 Firebase rebuild only"
      just rebuild-firebase
      just build-all-android
      ;;
    android_only)
      echo "🔨 Android rebuild only"
      just build-all-android
      ;;
  esac

  echo "✅ Rebuild complete"
EOF

# Stop VM (don't delete yet)
echo "⏹️  Stopping VM..."
tart stop "${VM_NAME}"

# Backup current snapshot
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "💾 Backing up current snapshot..."
tart clone gametwo-builder-configured "gametwo-builder-backup-${TIMESTAMP}"

# Update snapshot with rebuilt VM
echo "💾 Updating snapshot from ${VM_NAME}..."
tart clone "${VM_NAME}" gametwo-builder-configured --force

# Delete rebuild VM
echo "🗑️  Deleting temporary VM..."
tart delete "${VM_NAME}"

echo "✅ Snapshot updated successfully"
tart list | grep gametwo-builder
```

Make executable:
```bash
chmod +x /usr/local/bin/rebuild-and-snapshot.sh
```

**6.3 Update .gitlab-ci.yml with Change Detection**

See **Section 2.3.6** (already documented above) for the complete smart incremental strategy implementation.

Key additions:
- `detect-dependency-changes` stage
- `rebuild-dependencies` job (runs on `macos-host`)
- Conditional snapshot updates
- Automatic backups

**6.4 Test the Strategy**

**Test 1: Regular code change (fast path)**
```bash
vim project/game/battle.gd
git commit -am "Fix battle logic"
git push

# Expected:
# - detect-dependency-changes: No rebuild needed
# - build-android: ~5 min (warm cache)
# Total: ~18 min
```

**Test 2: Godot update (slow path)**
```bash
cd godot
git checkout newer-version
cd ..
git add godot
git commit -m "Update Godot submodule"
git push

# Expected:
# - detect-dependency-changes: Godot changed!
# - rebuild-dependencies: ~100 min (full rebuild + snapshot)
# - build-android: ~5 min (uses fresh snapshot)
# Total: ~120 min, but next builds will be fast
```

---

### Phase 7: Fastlane Deployment Integration

**Goal:** Automate deployment to TestFlight (iOS) and Play Store (Android).

**7.1 Install Fastlane in VM**

SSH into running VM (or update snapshot):
```bash
# Inside VM
brew install fastlane

# Verify
fastlane --version
```

Update snapshot after installing Fastlane.

**7.2 Configure Fastlane for iOS**

See **Section 5.1** (already documented above) for complete Fastfile examples.

**7.3 Configure Fastlane for Android**

See **Section 5.2** (already documented above) for complete Fastfile examples.

**7.4 Add Deployment Jobs to .gitlab-ci.yml**

```yaml
# Add deployment stage
stages:
  - validate
  - build
  - test
  - deploy  # NEW

# iOS TestFlight deployment
deploy-ios-beta:
  stage: deploy
  tags: [tart]
  script:
    - cd ~/workspace/gametwo/platform/ios
    - fastlane beta
  dependencies:
    - build-ios
    - test-all-platforms
  only:
    - main
  when: manual  # Require manual approval

# Android Play Store Beta
deploy-android-beta:
  stage: deploy
  tags: [tart]
  script:
    - cd ~/workspace/gametwo/platform/android
    - fastlane beta
  dependencies:
    - build-android
    - test-all-platforms
  only:
    - main
  when: manual
```

**7.5 Configure Secrets in GitLab**

GitLab UI: Settings → CI/CD → Variables

Add:
- `APPLE_ID` - Your Apple ID
- `APPLE_PASSWORD` - App-specific password
- `MATCH_PASSWORD` - Fastlane Match password
- `PLAY_STORE_JSON_KEY` - Google Play service account JSON

**7.6 Test Manual Deployment**
```bash
# Push to main branch
git push origin main

# In GitLab UI:
# - Wait for build/test to complete
# - Navigate to pipeline
# - Click "deploy-ios-beta" or "deploy-android-beta"
# - Click "Run job" (manual approval)
# - Watch deployment execute
```

---

### Phase 8: Monitoring & Maintenance

**Goal:** Set up monitoring and maintenance procedures.

**8.1 Runner Health Monitoring**
```bash
# Daily health check script
cat > ~/check-runner-health.sh <<'EOF'
#!/bin/bash
echo "=== GitLab Runner Health Check ==="
echo "Runner status:"
gitlab-runner status

echo -e "\nRegistered runners:"
gitlab-runner list

echo -e "\nTart VMs (should be empty when idle):"
tart list

echo -e "\nSnapshot storage:"
du -sh ~/.tart/vms/gametwo-builder* | sort -h

echo -e "\nDisk space:"
df -h | grep -E "Filesystem|/System/Volumes/Data"
EOF

chmod +x ~/check-runner-health.sh
./check-runner-health.sh
```

**8.2 Automated Cleanup**

See **Section 2.5** (already documented) for cleanup scripts.

**8.3 Snapshot Backup Strategy**
```bash
# Weekly: Clean old backups, keep last 3
cat > ~/cleanup-old-snapshots.sh <<'EOF'
#!/bin/bash
tart list | grep "gametwo-builder-backup-" | sort -r | tail -n +4 | while read vm rest; do
  echo "Deleting old backup: $vm"
  tart delete "$vm"
done
EOF

chmod +x ~/cleanup-old-snapshots.sh

# Add to crontab: Run Sundays at 2am
crontab -e
# Add: 0 2 * * 0 ~/cleanup-old-snapshots.sh >> /var/log/tart-cleanup.log 2>&1
```

**8.4 Performance Monitoring**
- Track build times in GitLab UI (CI/CD → Pipelines → Analytics)
- Monitor Mac mini resource usage (Activity Monitor)
- Watch for orphaned VMs: `tart list`
- Check logs: `tail -f /var/log/gitlab-runner.log`

**8.5 Troubleshooting Common Issues**

**Issue: Jobs stuck in "pending"**
```bash
# Check runner is running
gitlab-runner status

# Verify runner can reach GitLab
gitlab-runner verify

# Check logs
tail -50 /var/log/gitlab-runner.log
```

**Issue: VM fails to clone**
```bash
# Check snapshot exists
tart list | grep gametwo-builder-configured

# Check disk space
df -h

# Try manual clone
tart clone gametwo-builder-configured test-vm
tart delete test-vm
```

**Issue: Builds fail in CI but work locally**
```bash
# SSH into a running job VM
tart list  # Find running VM
tart ip VM_NAME
ssh admin@VM_IP

# Debug inside VM
cd ~/workspace/gametwo
just ci-validate
just build-status
```

---

## Implementation Options (Advanced Strategies)
```
Mac mini (always running):
├── Orchestration Runner (tags: orchestrator, macos-host)
│   ├── Handles: setup-vm-runner, cleanup-vm-runner jobs
│   └── Manages: VM lifecycle only
└── Resource usage: ~50MB RAM when idle

VM (created per pipeline):
├── Build Runner (tags: macos, tart, multi-platform)
│   ├── Dynamically registered at pipeline start
│   ├── Handles: All build/test/deploy jobs
│   └── Deregistered and deleted at pipeline end
└── Resource usage: 8GB RAM, 4 CPUs during pipeline
```

**Orchestration Flow:**
```
Pipeline Triggers
    ↓
[setup-vm-runner] job runs on Mac mini orchestrator
    ↓ 1. Clone VM from snapshot
    ↓ 2. Start VM
    ↓ 3. VM registers itself as GitLab runner
    ↓ 4. VM runner becomes available
    ↓
[build/test/deploy] jobs run on VM runner
    ↓ Multiple jobs execute on same VM instance
    ↓
[cleanup-vm-runner] job runs on Mac mini orchestrator
    ↓ 1. Unregister VM runner from GitLab
    ↓ 2. Stop and delete VM
    ↓
Mac mini returns to idle (no VMs running)
```

## Implementation Options

### **2.3 Option A: GitLab Tart Executor (RECOMMENDED - Official Tool)**

Use the official GitLab Tart Executor from Cirrus Labs - a maintained solution that handles VM lifecycle automatically.

**What It Does:**
- Automatically creates ephemeral VMs per job from Tart images
- Handles VM cloning, execution, and cleanup
- Supports concurrent jobs with automatic resource distribution
- Integrates directly with `.gitlab-ci.yml` image specifications
- No custom scripts or manual orchestration needed

**Installation:**
```bash
# On Mac mini host
brew install cirruslabs/cli/gitlab-tart-executor
```

**GitLab Runner Configuration (`~/.gitlab-runner/config.toml`):**
```toml
concurrent = 2  # Run up to 2 jobs in parallel

[[runners]]
  name = "gametwo-tart-runner"
  url = "https://gitlab.com/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "custom"

  # Use Tart executor for VM lifecycle management
  [runners.custom]
    config_exec = "gitlab-tart-executor"
    config_args = ["config"]

    prepare_exec = "gitlab-tart-executor"
    prepare_args = [
      "prepare",
      "--concurrency", "2",          # Match concurrent setting
      "--cpu", "auto",                # Auto-distribute CPUs
      "--memory", "auto"              # Auto-distribute RAM
    ]

    run_exec = "gitlab-tart-executor"
    run_args = ["run"]

    cleanup_exec = "gitlab-tart-executor"
    cleanup_args = ["cleanup"]
```

**Pipeline Configuration (`.gitlab-ci.yml`):**
```yaml
# Specify Tart VM image directly (like Docker)
image: ghcr.io/cirruslabs/macos-ventura-base:latest
# Or use your custom snapshot: localhost/gametwo-builder-base

stages:
  - validate
  - build
  - test
  - deploy

variables:
  GIT_SUBMODULE_STRATEGY: recursive

  # Tart executor configuration
  TART_EXECUTOR_ALWAYS_PULL: "false"  # Use local snapshots
  TART_EXECUTOR_HOST_DIR: "true"      # Speed up via host mounting

# All jobs run in isolated VMs automatically
ci-validate:
  stage: validate
  tags:
    - tart
  script:
    - cd ~/gametwo
    - just ci-validate

build-android:
  stage: build
  tags:
    - tart
  script:
    - cd ~/gametwo
    - just build-all-android
  artifacts:
    paths:
      - platform/android/build/outputs/
    expire_in: 1 week

build-ios:
  stage: build
  tags:
    - tart
  script:
    - cd ~/gametwo
    - just build-ios
  artifacts:
    paths:
      - platform/ios/build/
    expire_in: 1 week

test-all:
  stage: test
  tags:
    - tart
  script:
    - cd ~/gametwo
    - just log-run-silent test
  artifacts:
    paths:
      - logs/
    expire_in: 1 week
```

**Using Custom Snapshots:**

Instead of remote images, use your local Tart snapshots:

```yaml
# In .gitlab-ci.yml
image: localhost/gametwo-builder-base  # Your local snapshot

# Or override per job
build-android:
  image: localhost/gametwo-builder-with-cache
  script:
    - just build-all-android
```

**Advanced Configuration:**

```toml
# In prepare_args, add these options:

# Use specific snapshot as default
prepare_args = [
  "prepare",
  "--default-image", "localhost/gametwo-builder-base",
  "--concurrency", "2"
]

# Restrict which images can be used (security)
prepare_args = [
  "prepare",
  "--allow-image", "localhost/gametwo-*",    # Only local snapshots
  "--allow-image", "ghcr.io/cirruslabs/*"    # Official images
]

# Enable nested virtualization (if needed for Android emulator)
prepare_args = ["prepare", "--nested"]

# Configure resource limits per VM
prepare_args = [
  "prepare",
  "--cpu", "4",      # Fixed 4 CPUs per VM
  "--memory", "8192" # Fixed 8GB RAM per VM
]
```

**Mac mini Service Setup:**
```bash
# Register runner
gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --token "YOUR_TOKEN" \
  --executor "custom" \
  --description "gametwo-tart-executor" \
  --tag-list "tart,macos"

# Install as service
sudo gitlab-runner install --user=$(whoami)
sudo gitlab-runner start

# Verify
gitlab-runner verify
```

**Advantages:**
- ✅ **Official tool** - maintained by Cirrus Labs
- ✅ **Simple setup** - ~15 lines of config vs 200+ lines of scripts
- ✅ **Automatic VM lifecycle** - no manual orchestration
- ✅ **Concurrent jobs** - auto resource distribution
- ✅ **Image flexibility** - remote or local snapshots
- ✅ **Standard GitLab pattern** - works like Docker executor
- ✅ **macOS Sequoia support** - actively maintained

**Disadvantages:**
- ❌ **One VM per job** - cannot persist VM across multiple jobs in a pipeline
- ❌ **Less control** - executor manages lifecycle, not custom scripts
- ❌ **Image-based** - requires image/snapshot per configuration

**Best For:**
- Standard build pipelines with independent jobs
- Teams wanting official supported tools
- Minimal custom orchestration requirements

---

### **2.4 Option B: Manual Dynamic VM Runner Registration**

The VM itself registers as a GitLab runner during the pipeline, handles all build/test jobs, then is deregistered and deleted.

**Architecture:**
```
Mac mini:
├── Orchestration Runner (always registered, tags: orchestrator, macos-host)
└── Manages VM lifecycle only

VM (ephemeral):
├── Build Runner (dynamically registered, tags: macos, tart, multi-platform)
└── Handles all build/test jobs
```

**Pipeline Flow:**
```yaml
# .gitlab-ci.yml
stages:
  - setup      # Runs on Mac mini orchestrator
  - build      # Runs on VM runner
  - test       # Runs on VM runner
  - deploy     # Runs on VM runner
  - cleanup    # Runs on Mac mini orchestrator

variables:
  VM_NAME: "gametwo-builder-${CI_PIPELINE_ID}"
  VM_SNAPSHOT: "gametwo-builder-base"

# Stage 1: Setup VM and register as runner
setup-vm-runner:
  stage: setup
  tags:
    - orchestrator
    - macos-host
  script:
    - /usr/local/bin/vm-runner-lifecycle.sh start
  artifacts:
    reports:
      dotenv: vm-runner.env  # Pass VM_RUNNER_ID to next jobs

# Stage 2-4: Build/test jobs run on VM runner
build-android:
  stage: build
  tags:
    - macos
    - tart
    - multi-platform
  script:
    - cd ~/gametwo
    - just build-all-android
  needs:
    - setup-vm-runner

build-ios:
  stage: build
  tags:
    - macos
    - tart
    - multi-platform
  script:
    - cd ~/gametwo
    - just build-ios
  needs:
    - setup-vm-runner

# ... more build/test jobs ...

# Final stage: Cleanup VM and deregister runner
cleanup-vm-runner:
  stage: cleanup
  tags:
    - orchestrator
    - macos-host
  script:
    - /usr/local/bin/vm-runner-lifecycle.sh stop
  when: always  # Always cleanup, even if pipeline fails
```

**VM Lifecycle Script: `/usr/local/bin/vm-runner-lifecycle.sh`**
```bash
#!/bin/bash
# Manages VM runner registration and lifecycle

set -e

ACTION="$1"
VM_NAME="${VM_NAME:-gametwo-builder-${CI_PIPELINE_ID}}"
VM_SNAPSHOT="${VM_SNAPSHOT:-gametwo-builder-base}"
GITLAB_URL="${CI_SERVER_URL:-https://gitlab.com}"
RUNNER_TOKEN="${GITLAB_VM_RUNNER_TOKEN}"  # Set in CI/CD variables

case "$ACTION" in
  start)
    echo "🚀 Starting VM runner lifecycle..."

    # 1. Clone VM from snapshot
    echo "📦 Cloning VM: $VM_SNAPSHOT → $VM_NAME"
    tart clone "$VM_SNAPSHOT" "$VM_NAME"

    # 2. Start VM
    echo "▶️  Starting VM..."
    tart run "$VM_NAME" &
    VM_PID=$!

    # 3. Wait for VM to be ready
    echo "⏳ Waiting for VM to boot..."
    for i in {1..60}; do
      if tart ip "$VM_NAME" &>/dev/null; then
        VM_IP=$(tart ip "$VM_NAME")
        if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "admin@$VM_IP" "echo ready" &>/dev/null; then
          echo "✅ VM ready at $VM_IP"
          break
        fi
      fi
      sleep 3
    done

    # 4. Register VM as GitLab runner
    echo "📝 Registering VM as GitLab runner..."
    RUNNER_ID=$(ssh -o StrictHostKeyChecking=no "admin@$VM_IP" bash <<EOF
      gitlab-runner register \\
        --non-interactive \\
        --url "$GITLAB_URL" \\
        --registration-token "$RUNNER_TOKEN" \\
        --executor "shell" \\
        --description "gametwo-vm-runner-${CI_PIPELINE_ID}" \\
        --tag-list "macos,tart,multi-platform" \\
        --run-untagged="false" \\
        --locked="false"

      # Start the runner
      gitlab-runner start

      # Get runner ID for cleanup
      gitlab-runner verify 2>&1 | grep -oE 'runner=[a-zA-Z0-9]+' | cut -d= -f2
EOF
    )

    # 5. Export runner info for cleanup
    echo "VM_RUNNER_ID=$RUNNER_ID" >> vm-runner.env
    echo "VM_NAME=$VM_NAME" >> vm-runner.env
    echo "VM_IP=$VM_IP" >> vm-runner.env

    echo "✅ VM runner registered: $RUNNER_ID"
    echo "🎯 VM is ready to accept jobs with tags: macos, tart, multi-platform"
    ;;

  stop)
    echo "🧹 Cleaning up VM runner..."

    # Get VM IP
    VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || echo "")

    if [ -n "$VM_IP" ]; then
      # 1. Unregister runner from GitLab
      echo "📝 Unregistering runner from GitLab..."
      ssh -o StrictHostKeyChecking=no "admin@$VM_IP" "gitlab-runner unregister --all-runners" || true

      # 2. Stop runner service
      echo "⏹️  Stopping runner service..."
      ssh -o StrictHostKeyChecking=no "admin@$VM_IP" "gitlab-runner stop" || true
    fi

    # 3. Stop VM
    if tart list | grep "$VM_NAME" | grep -q "running"; then
      echo "⏹️  Stopping VM..."
      tart stop "$VM_NAME" || true
      sleep 2
    fi

    # 4. Delete VM
    if tart list | grep -q "$VM_NAME"; then
      echo "🗑️  Deleting VM..."
      tart delete "$VM_NAME" || true
    fi

    echo "✅ Cleanup complete"
    ;;

  *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac
```

**Mac mini Orchestrator Runner Setup:**
```bash
# On Mac mini, register the orchestration runner
gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "YOUR_ORCHESTRATOR_TOKEN" \
  --executor "shell" \
  --description "gametwo-mac-mini-orchestrator" \
  --tag-list "orchestrator,macos-host" \
  --run-untagged="false"

# Start the orchestrator runner
sudo gitlab-runner install --user=$(whoami)
sudo gitlab-runner start
```

**GitLab CI/CD Variables (Required):**
```
Settings → CI/CD → Variables:
├── GITLAB_VM_RUNNER_TOKEN (protected, masked) - Runner registration token
└── VM_SNAPSHOT (optional) - Override default snapshot name
```

**Advantages of This Approach:**
1. ✅ **VM is a full runner** - can handle multiple jobs in same pipeline
2. ✅ **Cleaner separation** - orchestrator vs builder responsibilities
3. ✅ **Standard GitLab pattern** - similar to autoscaling setups
4. ✅ **Better resource utilization** - VM stays alive during entire pipeline
5. ✅ **Explicit lifecycle** - clear setup/cleanup stages in pipeline

**Disadvantages:**
1. ❌ **More complex** - requires managing runner registration tokens
2. ❌ **Race conditions** - need to ensure VM runner registers before build jobs start
3. ❌ **Runner pollution** - failed cleanups leave registered runners in GitLab

**Best Practices:**
- Use `needs: [setup-vm-runner]` on all build/test jobs to ensure dependency
- Always use `when: always` on cleanup job to ensure VM is deleted
- Set job timeout on setup job (fail fast if VM doesn't register)
- Monitor for orphaned runners in GitLab UI periodically

---

## **2.3.5 Detailed Analysis: Does GitLab Tart Executor Cover GameTwo's Use Case?**

Let's analyze if Option A (GitLab Tart Executor) fully supports GameTwo's specific requirements.

### **GameTwo Requirements**

1. **Multi-platform builds** (iOS, Android, macOS, Windows)
2. **Custom Godot 4.3 engine** with Firebase integration
3. **Complex build system** using justfile commands
4. **Fastlane integration** for app deployment
5. **Snapshot-based reproducible builds**
6. **Resource efficiency** on Mac mini
7. **GameTwo repository** with submodules (Firebase C++ SDK)
8. **Testing framework** with comprehensive validation
9. **Mac mini on-demand** execution (idle when not building)

### **Requirement Analysis**

#### **1. Multi-Platform Builds ✅ FULLY SUPPORTED**

**How it works:**
```yaml
# Each platform can be a separate job
build-android:
  image: localhost/gametwo-builder-base
  tags: [tart]
  script:
    - just build-all-android

build-ios:
  image: localhost/gametwo-builder-base
  tags: [tart]
  script:
    - just build-ios

build-macos:
  image: localhost/gametwo-builder-base
  tags: [tart]
  script:
    - just build-macos

build-windows:
  image: localhost/gametwo-builder-windows  # Different snapshot for cross-compile
  tags: [tart]
  script:
    - just build-windows
```

**✅ Works perfectly** - each job gets its own isolated VM from the appropriate snapshot.

**Key advantage:** Concurrent builds! If Mac mini has enough resources (concurrency=2), iOS and Android can build simultaneously.

---

#### **2. Custom Godot Engine + Firebase ✅ FULLY SUPPORTED**

**How it works:**
- Create Tart snapshot with **all dependencies pre-installed**:
  - Custom Godot 4.3 engine (built from source)
  - Firebase C++ SDK (submodule)
  - SCons build tools
  - Xcode, Android SDK/NDK
  - All GameTwo build dependencies

**Snapshot creation (one-time setup):**
```bash
# Inside base VM
cd ~/gametwo
git submodule update --init --recursive
just build-status  # Verify dependencies

# Create snapshot
tart stop gametwo-builder
tart clone gametwo-builder gametwo-builder-base
```

**✅ Works perfectly** - executor clones this snapshot for every job, guaranteeing identical build environment.

---

#### **3. Complex Justfile Commands ✅ FULLY SUPPORTED**

**How it works:**
```yaml
ci-validate:
  image: localhost/gametwo-builder-base
  script:
    - cd ~/gametwo
    - just ci-validate

build-android:
  script:
    - cd ~/gametwo
    - just build-all-android   # ~25 min build

test-android:
  script:
    - cd ~/gametwo
    - just log-run-silent test-android-target development-workflow
```

**✅ Works perfectly** - justfile is installed in snapshot, all commands work identically.

**⚠️ CAVEAT:** Each job gets a fresh VM, so:
- `build-android` job: VM created → build → VM deleted
- `test-android` job: **NEW VM created** → needs to rebuild OR use artifacts

**Solution 1: Artifacts (recommended)**
```yaml
build-android:
  artifacts:
    paths:
      - platform/android/build/
    expire_in: 1 hour

test-android:
  needs: [build-android]  # Downloads artifacts from build-android
  script:
    - just test-android-target prebuilt  # Uses downloaded artifacts
```

**Solution 2: Combined Job**
```yaml
build-and-test-android:
  script:
    - just build-all-android
    - just test-android-target development-workflow
```

---

#### **4. Fastlane Integration ✅ FULLY SUPPORTED**

**How it works:**
```yaml
deploy-ios-testflight:
  image: localhost/gametwo-builder-base  # Has Fastlane installed
  stage: deploy
  tags: [tart]
  script:
    - cd ~/gametwo/platform/ios
    - fastlane beta
  needs: [build-ios]
  when: manual
  only: [main]
```

**✅ Works perfectly** - Fastlane installed in snapshot, credentials via GitLab CI/CD variables.

**Secrets handling:**
```yaml
variables:
  FASTLANE_USER: $APPLE_ID              # From GitLab CI/CD variables
  FASTLANE_PASSWORD: $APPLE_PASSWORD
  MATCH_PASSWORD: $MATCH_PASSWORD
```

---

#### **5. Snapshot-Based Reproducible Builds ✅ FULLY SUPPORTED**

**How it works:**
- Tart executor clones from `localhost/gametwo-builder-base` snapshot
- Every job gets **identical environment**
- No drift between builds

**Snapshot versioning:**
```bash
# Create versioned snapshots for different configs
tart clone gametwo-builder-base gametwo-builder-v1.0
tart clone gametwo-builder-base gametwo-builder-v1.1-new-firebase

# Use in .gitlab-ci.yml
build-stable:
  image: localhost/gametwo-builder-v1.0

build-experimental:
  image: localhost/gametwo-builder-v1.1-new-firebase
```

**✅ Perfect for reproducibility** - GitLab Tart Executor's core strength.

---

#### **6. Mac Mini Resource Efficiency ✅ FULLY SUPPORTED**

**How it works:**

**Idle state:**
- gitlab-runner service: ~50MB RAM
- gitlab-tart-executor: ~0MB (not running)
- No VMs running

**During build (concurrent=2):**
```toml
prepare_args = [
  "prepare",
  "--concurrency", "2",
  "--cpu", "auto",      # Distributes available CPUs
  "--memory", "auto"    # Distributes available RAM
]
```

**Example on Mac mini M2 (8-core, 16GB RAM):**
- Job 1 VM: 4 CPUs, 8GB RAM
- Job 2 VM: 4 CPUs, 8GB RAM
- Automatic resource distribution

**After jobs complete:**
- VMs automatically deleted
- Mac mini returns to idle state

**✅ Excellent resource management** - better than manual approach!

---

#### **7. GameTwo Repository + Submodules ⚠️ PARTIALLY SUPPORTED**

**How it works:**
```yaml
variables:
  GIT_SUBMODULE_STRATEGY: recursive  # GitLab clones repo into VM
```

**⚠️ ISSUE:** Repository cloned fresh for every job!

**Problem scenario:**
- `build-android` job: Clone 500MB repo + submodules → build → delete
- `build-ios` job: **Clone 500MB repo again** → build → delete
- `test-android` job: **Clone 500MB repo again** → test → delete

**Impact:** Adds ~2-3 min per job for repository cloning.

**✅ SOLUTION 1: Pre-clone in snapshot (recommended)**
```bash
# Inside base VM during snapshot creation
git clone <repo-url> ~/gametwo
cd ~/gametwo
git submodule update --init --recursive

# Jobs just do git pull
```

Then in `.gitlab-ci.yml`:
```yaml
variables:
  GIT_STRATEGY: none  # Don't clone, use snapshot's repo

before_script:
  - cd ~/gametwo
  - git fetch origin
  - git checkout $CI_COMMIT_SHA
  - git submodule update --recursive
```

**✅ SOLUTION 2: Host directory mounting**
```yaml
variables:
  TART_EXECUTOR_HOST_DIR: "true"
```

Mounts host directory into VM - faster I/O, but loses isolation benefits.

---

#### **8. Testing Framework ✅ FULLY SUPPORTED**

**How it works:**
```yaml
test-desktop:
  image: localhost/gametwo-builder-base
  script:
    - cd ~/gametwo
    - just test-desktop-target development-workflow
    - just logs-errors $CI_JOB_ID
  artifacts:
    paths:
      - logs/
    when: always  # Save logs even if test fails

test-android:
  script:
    - just fastbuild-android  # If repo pre-cloned in snapshot
    - just test-android-target comprehensive
    - just logs-errors $CI_JOB_ID
  artifacts:
    paths:
      - logs/
      - "platform/android/debug/*.apk"
```

**✅ Works perfectly** - all testing tools available in snapshot.

---

#### **9. On-Demand Execution ✅ FULLY SUPPORTED**

**How it works:**
- Mac mini runs only `gitlab-runner` service
- GitLab Tart Executor binary called only when job triggers
- VM created on-demand → executes → deleted

**Timeline:**
```
T+0s:   Pipeline triggers
T+0s:   gitlab-runner receives job
T+1s:   gitlab-tart-executor prepare starts
T+10s:  VM cloned from snapshot
T+15s:  VM booted and ready
T+20s:  Job executes (build/test)
T+25m:  Job completes
T+25m:  gitlab-tart-executor cleanup runs
T+26m:  VM deleted
T+26m:  Mac mini returns to idle
```

**✅ Perfect on-demand behavior** - identical to your requirements!

---

### **Critical Differences: Option A vs Option B**

| Aspect | Option A (Tart Executor) | Option B (Manual Registration) |
|--------|--------------------------|--------------------------------|
| **VM per** | Job | Pipeline |
| **iOS build VM lifetime** | 20 min | 90 min (entire pipeline) |
| **Android build VM lifetime** | 15 min | 90 min (shared with iOS) |
| **Total VM uptime** | 35 min (sequential) or 20 min (parallel) | 90 min (one VM for all) |
| **Repo clone overhead** | Per job (3 min × 5 = 15 min) | Once (3 min total) |
| **Concurrent builds** | ✅ Yes (iOS + Android parallel) | ❌ No (all jobs in one VM) |
| **VM startup overhead** | 5 × 15s = 75s | 1 × 15s = 15s |
| **Cleanup reliability** | ✅ Automatic per job | ⚠️ Depends on cleanup job |

---

### **Performance Comparison: Real Pipeline**

**GameTwo pipeline:** validate → build (iOS, Android, macOS) → test → deploy

**Option A (Tart Executor, concurrent=2):**
```
[validate]         3 min  (VM 1)
[build-ios]       20 min  (VM 1) ──┐
[build-android]   15 min  (VM 2) ──┤ Parallel!
[build-macos]     10 min  (VM 1) ──┘ Waits for iOS
[test-all]         8 min  (VM 1)
[deploy]           5 min  (VM 1)

Total: 46 min (with parallelism)
VM count: 5 VMs created/deleted
```

**Option B (Manual Registration, one VM for pipeline):**
```
[setup-vm]         1 min  (Mac mini starts VM)
[validate]         3 min  (VM)
[build-ios]       20 min  (VM)
[build-android]   15 min  (VM)  Sequential!
[build-macos]     10 min  (VM)
[test-all]         8 min  (VM)
[deploy]           5 min  (VM)
[cleanup-vm]       1 min  (Mac mini stops VM)

Total: 63 min (no parallelism)
VM count: 1 VM for entire pipeline
```

**✅ Option A is FASTER with concurrent builds** (46 min vs 63 min)

**But:** If repo cloning adds 3 min per job × 5 jobs = 15 min overhead:
- Option A: 46 + 15 = **61 min**
- Option B: 63 min (clone once)

**They're roughly equivalent** if repo is not pre-cloned in snapshot.

---

### **Final Recommendation**

**Use Option A (GitLab Tart Executor) IF:**
- ✅ You want official supported tooling
- ✅ You want concurrent builds (iOS + Android parallel)
- ✅ You pre-clone repo in snapshot (eliminates clone overhead)
- ✅ You prefer simplicity (~15 lines config vs 200+ lines scripts)
- ✅ Jobs are independent (don't share state within pipeline)

**Use Option B (Manual Registration) IF:**
- ✅ You need to persist VM across multiple jobs (share build artifacts in VM filesystem)
- ✅ You have very large repo (>1GB) and can't fit in snapshot
- ✅ You need custom VM lifecycle logic
- ✅ You want to minimize VM startup overhead (one VM for entire pipeline)

**For GameTwo: Option A is RECOMMENDED** because:
1. Official tool (less maintenance)
2. Concurrent builds (faster pipelines)
3. Simpler configuration
4. Better resource management
5. Pre-cloning repo in snapshot solves the main weakness

---

## **2.3.6 Smart Incremental Snapshot Strategy (OPTIMAL)**

### **Overview**

The best approach combines GitLab Tart Executor with **intelligent snapshot updates**: always pull latest code, detect if critical dependencies changed, and automatically rebuild + snapshot only when needed.

**This is the optimal strategy for GameTwo.**

### **How It Works**

```
Every commit triggers pipeline
  ↓
Pull latest code (git fetch)
  ↓
Detect: Did Godot/Firebase/submodules change?
  ↓
NO (90% of commits):         YES (10% of commits):
  Build with warm cache        Full rebuild + test
  ~18 min total                ~100 min, creates new snapshot
  ↓                            ↓
Both paths continue to test/deploy
```

### **Performance Comparison**

| Scenario | Frequency | Time | Snapshot Updated? |
|----------|-----------|------|-------------------|
| **Regular code change** (GDScript, assets) | 90% | ~18 min | No - uses existing cache |
| **Godot submodule update** | 5% | ~100 min | Yes - full rebuild + snapshot |
| **Firebase SDK update** | 3% | ~60 min | Yes - partial rebuild + snapshot |
| **Submodule config change** | 2% | ~80 min | Yes - full rebuild + snapshot |

**Key insight:** Most builds are fast (18 min), but the occasional slow build (100 min) updates the snapshot so the next 20 builds are fast again!

### **Complete Implementation**

```yaml
# .gitlab-ci.yml

variables:
  GIT_STRATEGY: fetch  # Always fetch latest
  GIT_SUBMODULE_STRATEGY: normal

stages:
  - detect
  - rebuild-if-needed
  - build
  - test
  - deploy

# Stage 1: Detect if critical dependencies changed
detect-dependency-changes:
  stage: detect
  image: localhost/gametwo-builder-cache
  tags: [tart]
  script:
    - cd ~/gametwo

    # Fetch latest and checkout current commit
    - git fetch origin
    - PREVIOUS_COMMIT=$(git rev-parse HEAD)
    - git checkout ${CI_COMMIT_SHA}

    # Check if Godot submodule changed
    - |
      if git diff ${PREVIOUS_COMMIT} ${CI_COMMIT_SHA} --name-only | grep -q "^godot$"; then
        echo "🔴 Godot submodule changed - full rebuild required"
        echo "REBUILD_REQUIRED=true" >> rebuild.env
        echo "CHANGED_COMPONENT=godot" >> rebuild.env
        echo "REBUILD_STRATEGY=full" >> rebuild.env
      fi

    # Check if Firebase SDK changed
    - |
      if git diff ${PREVIOUS_COMMIT} ${CI_COMMIT_SHA} --name-only | grep -q "^extras/firebase-sdk/"; then
        echo "🔴 Firebase SDK changed - rebuild required"
        echo "REBUILD_REQUIRED=true" >> rebuild.env
        echo "CHANGED_COMPONENT=firebase" >> rebuild.env
        echo "REBUILD_STRATEGY=firebase_only" >> rebuild.env
      fi

    # Check if submodule configuration changed
    - |
      if git diff ${PREVIOUS_COMMIT} ${CI_COMMIT_SHA} --name-only | grep -q "\.gitmodules"; then
        echo "🔴 Submodule configuration changed - full rebuild required"
        echo "REBUILD_REQUIRED=true" >> rebuild.env
        echo "CHANGED_COMPONENT=submodules" >> rebuild.env
        echo "REBUILD_STRATEGY=full" >> rebuild.env
      fi

    # Check if Android SDK changed
    - |
      if git diff ${PREVIOUS_COMMIT} ${CI_COMMIT_SHA} --name-only | grep -q "^extras/android-sdk/"; then
        echo "🔴 Android SDK changed - Android rebuild required"
        echo "REBUILD_REQUIRED=true" >> rebuild.env
        echo "CHANGED_COMPONENT=android-sdk" >> rebuild.env
        echo "REBUILD_STRATEGY=android_only" >> rebuild.env
      fi

    # If nothing critical changed, use existing cache
    - |
      if [ ! -f rebuild.env ]; then
        echo "✅ No critical dependencies changed - using cached snapshot"
        echo "REBUILD_REQUIRED=false" >> rebuild.env
        echo "REBUILD_STRATEGY=none" >> rebuild.env
      fi

    - cat rebuild.env
  artifacts:
    reports:
      dotenv: rebuild.env
    expire_in: 1 hour

# Stage 2: Full rebuild if dependencies changed
# IMPORTANT: Runs on Mac mini HOST, not in Tart VM
rebuild-dependencies:
  stage: rebuild-if-needed
  tags: [macos-host]  # Runs on host for VM control
  script:
    - echo "🔧 Rebuild triggered by: ${CHANGED_COMPONENT}"
    - echo "📋 Rebuild strategy: ${REBUILD_STRATEGY}"

    # Create temporary VM for rebuild
    - VM_NAME="gametwo-rebuild-$(date +%s)"
    - tart clone gametwo-builder-cache ${VM_NAME}

    # Run rebuild inside VM based on strategy
    - |
      case "${REBUILD_STRATEGY}" in
        full)
          echo "🔨 Full rebuild (Godot + all platforms)"
          tart run ${VM_NAME} -- bash -c "
            set -e
            cd ~/gametwo
            git fetch origin
            git checkout ${CI_COMMIT_SHA}
            git submodule update --init --recursive

            echo '🧹 Cleaning previous builds...'
            just clean-all

            echo '📦 Rebuilding Godot engine...'
            just build-godot-engine  # ~30 min

            echo '🔥 Warming build caches...'
            just build-all-android   # ~25 min
            just build-ios           # ~20 min

            echo '🧪 Validating builds...'
            just ci-validate
            just test-desktop-target development-workflow

            echo '✅ Full rebuild complete and validated'
          "
          ;;

        firebase_only)
          echo "🔨 Firebase-only rebuild"
          tart run ${VM_NAME} -- bash -c "
            set -e
            cd ~/gametwo
            git checkout ${CI_COMMIT_SHA}
            git submodule update --recursive

            echo '🔥 Rebuilding Firebase integration...'
            just rebuild-firebase  # Custom command
            just build-all-android

            echo '🧪 Validating Firebase build...'
            just test-android-target firebase-all

            echo '✅ Firebase rebuild complete'
          "
          ;;

        android_only)
          echo "🔨 Android-only rebuild"
          tart run ${VM_NAME} -- bash -c "
            cd ~/gametwo
            git checkout ${CI_COMMIT_SHA}

            echo '🔥 Rebuilding Android...'
            just build-all-android

            echo '✅ Android rebuild complete'
          "
          ;;
      esac

    # Stop VM (don't delete yet - need to snapshot)
    - tart stop ${VM_NAME}

    # Backup current cache snapshot
    - TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    - tart clone gametwo-builder-cache gametwo-builder-cache-backup-${TIMESTAMP}

    # Update cache snapshot with rebuilt VM
    - echo "💾 Creating new cache snapshot from ${VM_NAME}"
    - tart clone ${VM_NAME} gametwo-builder-cache --force

    # Clean up rebuild VM
    - tart delete ${VM_NAME}

    # Verify and report
    - echo "✅ Cache snapshot updated successfully"
    - tart list | grep gametwo-builder-cache
    - du -sh ~/.tart/vms/gametwo-builder-cache*

    # Export snapshot info for later jobs
    - echo "SNAPSHOT_UPDATED=true" >> snapshot.env
    - echo "SNAPSHOT_VERSION=${TIMESTAMP}" >> snapshot.env
  artifacts:
    reports:
      dotenv: snapshot.env
  rules:
    - if: '$REBUILD_REQUIRED == "true"'
  needs:
    - detect-dependency-changes
  timeout: 2 hours

# Stage 3: Regular builds (use cache, fast)
build-android:
  stage: build
  image: localhost/gametwo-builder-cache
  tags: [tart]
  script:
    - cd ~/gametwo
    - git checkout ${CI_COMMIT_SHA}
    - git submodule update --recursive

    # If rebuild happened, artifacts already exist in snapshot
    - |
      if [ "${REBUILD_REQUIRED}" == "true" ]; then
        echo "✅ Using pre-built artifacts from snapshot"
        ls -lah platform/android/build/outputs/ || echo "Building fresh..."
      fi

    # Incremental build (fast with warm cache)
    - just build-all-android  # ~5 min with cache, ~25 min cold
  artifacts:
    paths:
      - platform/android/build/outputs/
    expire_in: 1 week
  needs:
    - detect-dependency-changes
    - job: rebuild-dependencies
      optional: true  # Wait if rebuild happened

build-ios:
  stage: build
  image: localhost/gametwo-builder-cache
  tags: [tart]
  script:
    - cd ~/gametwo
    - git checkout ${CI_COMMIT_SHA}
    - git submodule update --recursive

    - just build-ios  # ~5 min with cache
  artifacts:
    paths:
      - platform/ios/build/
    expire_in: 1 week
  needs:
    - detect-dependency-changes
    - job: rebuild-dependencies
      optional: true

build-macos:
  stage: build
  image: localhost/gametwo-builder-cache
  tags: [tart]
  script:
    - cd ~/gametwo
    - git checkout ${CI_COMMIT_SHA}

    - just build-macos  # Fast with cache
  artifacts:
    paths:
      - platform/macos/build/
    expire_in: 1 week
  needs:
    - detect-dependency-changes
    - job: rebuild-dependencies
      optional: true

# Stage 4: Comprehensive testing
test-all-platforms:
  stage: test
  image: localhost/gametwo-builder-cache
  tags: [tart]
  script:
    - cd ~/gametwo
    - git checkout ${CI_COMMIT_SHA}

    # Run comprehensive test suite
    - just log-run-silent test
    - just test-desktop-target comprehensive
    - just test-android-target development-workflow
  artifacts:
    paths:
      - logs/
    when: always
  needs:
    - build-android
    - build-ios
    - build-macos

# Cleanup old snapshot backups (weekly)
cleanup-snapshot-backups:
  stage: deploy
  tags: [macos-host]
  script:
    - echo "🧹 Cleaning up old snapshot backups..."

    # Keep only last 3 backups
    - |
      tart list | grep "gametwo-builder-cache-backup-" | sort -r | tail -n +4 | while read vm rest; do
        echo "Deleting old backup: $vm"
        tart delete "$vm" || true
      done

    - echo "📊 Current snapshots:"
    - tart list | grep gametwo-builder
    - du -sh ~/.tart/vms/gametwo-builder* | sort -h
  when: always
  only:
    - schedules  # Weekly cleanup
```

### **Key Features**

**1. Intelligent Change Detection**
```bash
# Detects changes to critical dependencies
git diff ${PREVIOUS_COMMIT} ${CI_COMMIT_SHA} --name-only | grep -q "^godot$"
```

**2. Granular Rebuild Strategies**
- `full`: Godot changed → rebuild engine + all platforms (~80 min)
- `firebase_only`: Firebase SDK changed → rebuild Firebase integration (~30 min)
- `android_only`: Android SDK changed → rebuild Android only (~15 min)
- `none`: Regular code change → use cache (~5 min per platform)

**3. Host-Controlled Rebuilds**
```yaml
rebuild-dependencies:
  tags: [macos-host]  # NOT in Tart VM
```

Running on host gives full VM lifecycle control:
- Create VM for rebuild
- Run build/test inside VM
- Stop VM (don't let executor delete it)
- Snapshot the VM
- Delete temporary VM

**4. Validation Before Snapshot**
```bash
# Inside rebuild VM
just ci-validate
just test-desktop-target development-workflow
```

Snapshot is **only created if tests pass**. This ensures snapshots are always in a known-good state.

**5. Automatic Backup**
```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
tart clone gametwo-builder-cache gametwo-builder-cache-backup-${TIMESTAMP}
```

Before updating cache, previous version is backed up. Can rollback if needed.

### **Performance Analysis**

**Typical 10-commit sequence:**

```
Commit 1: GDScript change           → 18 min (cache)
Commit 2: Assets update             → 18 min (cache)
Commit 3: Battle logic fix          → 18 min (cache)
Commit 4: Godot submodule update    → 100 min (full rebuild + snapshot)
Commit 5: UI improvements           → 18 min (NEW cache from commit 4)
Commit 6: Firebase integration      → 18 min (cache)
Commit 7: Test additions            → 18 min (cache)
Commit 8: Bug fixes                 → 18 min (cache)
Commit 9: Documentation             → 18 min (cache)
Commit 10: Performance optimization → 18 min (cache)

Total time for 10 commits: 262 min
Average per commit: 26.2 min

Without smart strategy (always rebuild): 1000 min (100 min × 10)
Time saved: 738 min (73.8% faster!)
```

### **Storage Management**

**Snapshot versions:**
```
~/.tart/vms/
├── gametwo-builder-cache                      [50GB] Current cache
├── gametwo-builder-cache-backup-20250113_1430 [50GB] Yesterday
├── gametwo-builder-cache-backup-20250112_0920 [50GB] 2 days ago
└── gametwo-builder-cache-backup-20250111_1605 [50GB] 3 days ago (deleted weekly)

Total: ~150GB (keeps rolling 3-day history)
```

**Cleanup strategy:**
- Keep last 3 backups
- Weekly cleanup job deletes older backups
- Can manually restore from backup if needed

### **Rollback Procedure**

If a snapshot update breaks builds:

```bash
# On Mac mini
tart list | grep gametwo-builder-cache

# Restore previous backup
tart clone gametwo-builder-cache-backup-20250113_1430 gametwo-builder-cache --force

# Verify
tart run gametwo-builder-cache -- "cd ~/gametwo && just ci-validate"

# Next CI job uses restored snapshot
```

### **Testing the Strategy**

**Test 1: Regular code change (expect fast path)**
```bash
# Make GDScript change
vim project/game/battle.gd
git commit -am "Fix battle bug"
git push

# Watch pipeline:
# ✅ detect-dependency-changes: No critical changes
# ⏭️  rebuild-dependencies: SKIPPED
# ✅ build-android: 5 min (warm cache)
# ✅ build-ios: 5 min (warm cache)
# ✅ test-all: 8 min
# Total: ~18 min
```

**Test 2: Godot submodule update (expect full rebuild)**
```bash
# Update Godot
cd godot
git checkout v4.3-stable
cd ..
git add godot
git commit -m "Update Godot to v4.3-stable"
git push

# Watch pipeline:
# ✅ detect-dependency-changes: Godot changed!
# 🔨 rebuild-dependencies: 100 min (rebuild Godot + warm caches)
# 💾 snapshot-updated-cache: 2 min (create new snapshot)
# ✅ build-android: 5 min (uses rebuilt artifacts)
# ✅ build-ios: 5 min
# ✅ test-all: 8 min
# Total: ~120 min

# NEXT commit will be fast again (uses new snapshot)
```

### **Why This Strategy is Optimal for GameTwo**

1. ✅ **90% fast, 10% thorough** - Most builds are fast, critical builds are thorough
2. ✅ **Self-healing** - Snapshots always validated before saving
3. ✅ **Automatic** - No manual intervention needed
4. ✅ **Efficient** - Only rebuilds what changed
5. ✅ **Safe** - Automatic backups, easy rollback
6. ✅ **Scalable** - Works for team of 1 or 100
7. ✅ **Cost-effective** - Minimal Mac mini resource usage

### **Recommendation**

**Use this smart incremental strategy as the primary approach:**

- Start with this from day 1
- Adjust change detection rules based on actual patterns
- Add more granular rebuild strategies as needed
- Monitor snapshot sizes and cleanup frequency

This combines the best aspects of all previous strategies and is **purpose-built for GameTwo's workflow**.

---

**2.4 Mac mini Service Setup**

Install GitLab runner as a system service that starts on boot:

```bash
# On the Mac mini host (NOT inside VM)

# Install runner as LaunchDaemon (runs at boot)
sudo gitlab-runner install --user=YOUR_USER

# Start the service
sudo gitlab-runner start

# Verify it's running
sudo gitlab-runner status

# Enable runner to start on Mac mini boot
sudo launchctl load /Library/LaunchDaemons/gitlab-runner.plist
```

**2.5 Resource Management & Monitoring**

**Automatic Cleanup Cron Job** (safety net for orphaned VMs):
```bash
# Add to Mac mini crontab: crontab -e
# Clean up VMs older than 4 hours every hour
0 * * * * /usr/local/bin/cleanup-orphaned-vms.sh >> /var/log/tart-cleanup.log 2>&1
```

**Cleanup Script: `/usr/local/bin/cleanup-orphaned-vms.sh`**
```bash
#!/bin/bash
# Clean up orphaned job VMs (safety net)

CUTOFF_HOURS=4

tart list | grep "gametwo-builder-job-" | while read -r VM_NAME _; do
  # Check VM age (Tart doesn't expose creation time easily)
  # For now, just delete any job VMs that aren't running
  if ! tart list | grep "$VM_NAME" | grep -q "running"; then
    echo "$(date): Deleting orphaned VM: $VM_NAME"
    tart delete "$VM_NAME" || true
  fi
done
```

**Monitoring Dashboard** (optional):
```bash
# Check runner status
gitlab-runner status

# List all VMs (should be empty when idle)
tart list

# Check disk usage (snapshots consume space)
du -sh ~/Library/Containers/com.github.cirruslabs.tart/Data/

# Monitor active jobs
tail -f /var/log/gitlab-runner.log
```

**2.6 Mac mini Power & Network Configuration**

**Keep Mac mini awake during builds:**
```bash
# Prevent sleep while powered
sudo pmset -c sleep 0
sudo pmset -c disksleep 0

# Allow sleep on battery (if using UPS)
sudo pmset -b sleep 30

# Disable sleep during network activity
sudo systemsetup -setwakeonnetworkaccess on
```

**Ensure network accessibility:**
- Set static IP or DHCP reservation for Mac mini
- Configure router to forward traffic if needed
- Ensure Mac mini can reach gitlab.com (or your GitLab instance)

**2.7 Start Runner Service**
```bash
# On Mac mini host
sudo gitlab-runner install --user=$(whoami)
sudo gitlab-runner start

# Verify runner registered with GitLab
gitlab-runner verify
```

### Phase 3: Build Environment Setup

**3.1 Godot Build Dependencies**
Inside VM:
```bash
# Install SCons and build tools
brew install scons

# Install platform-specific SDKs
# Android: Copy from extras/android-sdk/ or download fresh
# iOS/macOS: Xcode already installed
# Windows: Install MinGW or cross-compilation toolchain
brew install mingw-w64
```

**3.2 GameTwo Repository Setup**
```bash
# Clone repository
git clone <repository-url> ~/gametwo
cd ~/gametwo

# Initialize submodules (Firebase SDK, etc.)
git submodule update --init --recursive

# Test build system
just build-status
```

**3.3 Fastlane Setup**
```bash
# Install Fastlane
brew install fastlane

# Configure Fastlane for iOS
cd ~/gametwo/platform/ios
fastlane init

# Configure Fastlane for Android
cd ~/gametwo/platform/android
fastlane init
```

**3.4 Create Configured Snapshot**
```bash
# Exit VM, create new snapshot
tart stop gametwo-builder
tart clone gametwo-builder gametwo-builder-configured
```

### Phase 4: Multi-Platform Build Pipeline

**4.1 Create `.gitlab-ci.yml`**
```yaml
stages:
  - validate
  - build
  - test
  - deploy

variables:
  GIT_SUBMODULE_STRATEGY: recursive

# Validation stage
ci-validate:
  stage: validate
  tags:
    - macos
    - tart
  script:
    - cd ~/gametwo
    - just ci-validate
  only:
    - merge_requests
    - main

# Android build
build-android:
  stage: build
  tags:
    - macos
    - tart
  script:
    - cd ~/gametwo
    - just build-all-android
  artifacts:
    paths:
      - platform/android/build/outputs/
    expire_in: 1 week

# iOS build
build-ios:
  stage: build
  tags:
    - macos
    - tart
  script:
    - cd ~/gametwo
    - just build-ios  # Need to add this command
  artifacts:
    paths:
      - platform/ios/build/
    expire_in: 1 week

# macOS build
build-macos:
  stage: build
  tags:
    - macos
    - tart
  script:
    - cd ~/gametwo
    - just build-macos  # Need to add this command
  artifacts:
    paths:
      - platform/macos/build/
    expire_in: 1 week

# Windows build (cross-compile)
build-windows:
  stage: build
  tags:
    - macos
    - tart
  script:
    - cd ~/gametwo
    - just build-windows  # Need to add this command
  artifacts:
    paths:
      - platform/windows/build/
    expire_in: 1 week

# Testing stage
test-all-platforms:
  stage: test
  tags:
    - macos
    - tart
  script:
    - cd ~/gametwo
    - just log-run-silent test
    - just test-desktop-target development-workflow
  dependencies:
    - build-android
  artifacts:
    paths:
      - logs/
    expire_in: 1 week
```

**4.2 Add Missing Justfile Commands**
Need to create:
- `just build-ios` - iOS compilation pipeline
- `just build-macos` - macOS compilation pipeline
- `just build-windows` - Windows cross-compilation pipeline

### Phase 5: Fastlane Integration

**5.1 iOS Deployment Fastfile**
`platform/ios/fastlane/Fastfile`:
```ruby
default_platform(:ios)

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    build_app(
      scheme: "GameTwo",
      export_method: "app-store"
    )
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end

  desc "Build and upload to App Store"
  lane :release do
    build_app(
      scheme: "GameTwo",
      export_method: "app-store"
    )
    upload_to_app_store(
      skip_metadata: false,
      skip_screenshots: false
    )
  end
end
```

**5.2 Android Deployment Fastfile**
`platform/android/fastlane/Fastfile`:
```ruby
default_platform(:android)

platform :android do
  desc "Build and upload to Play Store Beta"
  lane :beta do
    gradle(
      task: "bundle",
      build_type: "Release"
    )
    upload_to_play_store(
      track: "beta",
      aab: "build/outputs/bundle/release/gametwo-release.aab"
    )
  end

  desc "Build and upload to Play Store Production"
  lane :release do
    gradle(
      task: "bundle",
      build_type: "Release"
    )
    upload_to_play_store(
      track: "production",
      aab: "build/outputs/bundle/release/gametwo-release.aab"
    )
  end
end
```

**5.3 GitLab CI Deployment Jobs**
Add to `.gitlab-ci.yml`:
```yaml
# Deploy iOS to TestFlight
deploy-ios-beta:
  stage: deploy
  tags:
    - macos
    - tart
  script:
    - cd ~/gametwo/platform/ios
    - fastlane beta
  dependencies:
    - build-ios
    - test-all-platforms
  only:
    - main
  when: manual

# Deploy Android to Play Store Beta
deploy-android-beta:
  stage: deploy
  tags:
    - macos
    - tart
  script:
    - cd ~/gametwo/platform/android
    - fastlane beta
  dependencies:
    - build-android
    - test-all-platforms
  only:
    - main
  when: manual
```

### Phase 6: Snapshot & Restore Workflow

**6.1 On-Demand Snapshot Strategy**

The Mac mini maintains **persistent snapshots** but creates **ephemeral VMs** only when needed.

```
Mac mini Disk Storage:
├── gametwo-builder-base         [PERSISTENT] 40GB - Clean macOS + Xcode + build tools
├── gametwo-builder-configured   [PERSISTENT] 45GB - + GameTwo repo + dependencies
└── gametwo-builder-with-cache   [PERSISTENT] 50GB - + pre-built Godot artifacts (optional)

Mac mini RAM/CPU:
├── gitlab-runner service        [ALWAYS RUNNING] ~50MB RAM
└── (no VMs when idle)           [IDLE STATE] 0 GB RAM

During GitLab Job:
├── gitlab-runner service        [ACTIVE] ~50MB RAM
└── gametwo-builder-job-67890    [EPHEMERAL] 8GB RAM, 4 CPUs
                                 ↓
                                 Cloned from snapshot
                                 ↓
                                 Job executes (build/test)
                                 ↓
                                 VM deleted automatically
                                 ↓
                                 Mac mini returns to IDLE
```

**Key Insight:** The Mac mini only consumes significant resources during active builds. When idle, only the lightweight runner service runs (~50MB).

**6.2 Snapshot Lifecycle Management**

**Initial Setup:**
```bash
# Create base snapshot (Phase 1)
tart clone ghcr.io/cirruslabs/macos-sonoma-vanilla:latest gametwo-builder
# ... configure VM ...
tart stop gametwo-builder
tart clone gametwo-builder gametwo-builder-base
```

**Monthly Maintenance (Update Dependencies):**
```bash
# Start from base snapshot
tart run gametwo-builder-base

# Inside VM: Update everything
brew update && brew upgrade
# Update Xcode via App Store if needed
# Update Android SDK
cd ~/gametwo && git pull && git submodule update

# Exit VM and update snapshot
exit
tart stop gametwo-builder-base
tart clone gametwo-builder-base gametwo-builder-base-backup  # Safety backup
# Now gametwo-builder-base has latest dependencies
```

**Per-Job Workflow (Automatic via GitLab Runner):**
```bash
# GitLab runner automatically does this for each job:

# 1. PREPARE (before job)
tart clone gametwo-builder-base gametwo-builder-job-67890

# 2. RUN (during job)
tart run gametwo-builder-job-67890
# ... build commands execute ...

# 3. CLEANUP (after job, even if failed)
tart stop gametwo-builder-job-67890
tart delete gametwo-builder-job-67890

# Mac mini is now idle again (no VMs running)
```

**6.3 Resource Optimization Strategies**

**Option A: Single Base Snapshot (Simplest)**
- Only maintain `gametwo-builder-base`
- Clone fresh for every job
- Slower builds (~5-10 min overhead) but guaranteed clean state
- Recommended for starting out

**Option B: Cached Snapshot (Faster)**
- Maintain `gametwo-builder-base` (clean) AND `gametwo-builder-with-cache` (pre-built Godot)
- Clone from cached snapshot for speed
- Update cache snapshot weekly after successful builds
- Faster builds (~2 min overhead) but needs maintenance

**Disk Space Management:**
```bash
# Check snapshot sizes
tart list

# Clean up old snapshots
tart delete gametwo-builder-old-backup

# Compact snapshot storage (if supported)
# Tart handles this automatically
```

**6.4 Cache Optimization**

**GitLab CI Cache (Recommended):**
```yaml
# In .gitlab-ci.yml
cache:
  key: "$CI_COMMIT_REF_SLUG"
  paths:
    - .scons_cache/           # Godot build cache
    - platform/android/.gradle/  # Android Gradle cache
    - platform/ios/Pods/      # CocoaPods cache
```

**Pre-built Snapshot Cache (Advanced):**
```bash
# After successful full build, create cached snapshot
# (Do this manually, not automated)

tart run gametwo-builder-job-12345  # Access a successful build VM
# Verify build artifacts exist
ls ~/gametwo/bin/
exit

# Save this as cached snapshot
tart clone gametwo-builder-job-12345 gametwo-builder-with-cache

# Update runner to use cached snapshot
# Edit ~/.gitlab-runner/config.toml
# Change prepare_args to clone from gametwo-builder-with-cache instead
```

### Phase 7: Monitoring & Debugging

**7.1 Runner Health Checks**
```bash
# On host
gitlab-runner verify
gitlab-runner status
tart list  # Check for orphaned VMs
```

**7.2 Job Debugging**
```bash
# Access running job VM
tart ip gametwo-builder-job-12345
ssh user@<vm-ip>

# Check logs
tail -f ~/gametwo/logs/*.log
```

**7.3 Performance Monitoring**
- Track build times per platform
- Monitor VM resource usage
- Optimize parallel job execution

## Success Criteria

- [ ] Tart VM created and configured with all build dependencies
- [ ] GitLab runner registered and communicating with GitLab
- [ ] Snapshot workflow operational (clean VM per job)
- [ ] Android builds complete successfully in CI
- [ ] iOS builds complete successfully in CI
- [ ] macOS builds complete successfully in CI
- [ ] Windows builds complete successfully in CI (cross-compile)
- [ ] All tests pass in CI environment
- [ ] Fastlane iOS TestFlight deployment works
- [ ] Fastlane Android Play Store Beta deployment works
- [ ] Build artifacts stored and accessible
- [ ] CI pipeline completes in reasonable time (<30 min for full build)
- [ ] Documentation created for maintaining CI/CD system

## Security Considerations

**Secrets Management:**
- Store signing certificates in GitLab CI/CD variables (encrypted)
- Use Fastlane Match for iOS certificate management
- Android keystore in secure CI variables
- Never commit secrets to repository

**VM Isolation:**
- Each job runs in isolated VM clone
- VMs deleted after job completion
- No persistent state between jobs (except snapshots)

## Estimated Timeline

- **Phase 1-2** (Tart & Runner): 4-6 hours
- **Phase 3** (Build Environment): 6-8 hours
- **Phase 4** (Pipeline Configuration): 8-10 hours
- **Phase 5** (Fastlane Integration): 6-8 hours
- **Phase 6** (Optimization): 4-6 hours
- **Phase 7** (Testing & Documentation): 4-6 hours

**Total Estimate:** 32-44 hours (4-6 days of focused work)

## Related Tasks

- task-277: Integrate Firebase C++ SDK for Windows Desktop Build
- task-278: Unify iOS Firebase Binary Management with CocoaPods and Xcode Integration

## References

**Tart Documentation:**
- https://github.com/cirruslabs/tart
- https://tart.run/integrations/gitlab-ci/

**GitLab Runner:**
- https://docs.gitlab.com/runner/
- https://docs.gitlab.com/runner/executors/custom.html

**Fastlane:**
- https://docs.fastlane.tools/
- https://docs.fastlane.tools/actions/

**GameTwo Build System:**
- `backlog doc view doc-002` - Build System Architecture & Workflows
- `just help-build` - Build command reference

## Notes

- Consider using GitLab's CI/CD caching to speed up Godot engine compilation
- May need multiple runner VMs for parallel platform builds
- Windows cross-compilation from macOS may have limitations (consider dedicated Windows runner)
- Fastlane requires App Store Connect API keys (iOS) and Play Console API keys (Android)
- Budget for ~200GB storage per VM snapshot with full build environment
