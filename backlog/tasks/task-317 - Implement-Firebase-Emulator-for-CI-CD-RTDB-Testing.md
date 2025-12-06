---
id: task-317
title: Implement Firebase Emulator for CI/CD RTDB Testing
status: To Do
assignee: []
created_date: '2025-11-27 16:41'
updated_date: '2025-12-05 09:23'
labels:
  - infrastructure
  - testing
  - firebase
  - ci-cd
dependencies: []
priority: medium
---

## Assessment (2025-12-06)

**Value: HIGH** - Critical for reliable CI/CD testing.

**Recommendation: KEEP - HIGH PRIORITY** - Rate limiting issues cause test flakiness and slow down development. Firebase Emulator would enable fast, reliable testing without hitting production quotas. This is infrastructure that pays for itself quickly.

**Effort**: Medium (emulator setup, environment detection)
**Impact**: High (eliminates rate limiting issues, 2-5x faster tests, reliable CI/CD)

---

## Description

Set up Firebase Emulator infrastructure for CI/CD pipeline to eliminate test flakiness caused by Firebase RTDB rate limiting when running full test suites.

## Problem Statement

Current investigation of `rtdb.advanced.transaction` test reveals:
- Test passes reliably in isolation (1.6s execution time)
- Same test times out in full test suites (76s timeout)
- Root cause: Firebase RTDB rate limiting after running 11+ Firebase tests sequentially
- Network-dependent tests are inherently flaky in CI/CD environments

## Solution

Implement Firebase Emulator for automated testing using **100% external configuration** (no game code changes):
- **Deterministic**: No network dependencies or external service state
- **Fast**: Local execution eliminates network latency (2-5x faster)
- **Reliable**: No rate limiting or quota constraints
- **Cost-effective**: No Firebase billing for CI/CD test runs
- **Parallel-safe**: Multiple test suites can run simultaneously
- **Zero Code Impact**: Uses environment variables only - game code unchanged

## Technical Approach

Firebase C++ SDK automatically detects `FIREBASE_DATABASE_EMULATOR_HOST` environment variable during initialization. Implementation is purely external through:
1. Justfile recipes that set environment variables
2. CI/CD pipeline configuration
3. Firebase emulator setup (firebase.json)

No changes required in:
- GDScript game code
- C++ Firebase module
- Debug configurations
- Test code

## Benefits

1. Eliminates test flakiness from Firebase rate limiting
2. 2-5x faster test execution (no network round trips)
3. Enables parallel test execution in CI/CD
4. Reduces Firebase costs (no production quota consumption)
5. Improves developer experience with reliable local testing
6. Maintains production validation through targeted smoke tests
7. Easy rollback (remove environment variable = back to production)

## Hybrid Strategy

**Use Emulator** (90% of tests):
- Unit tests, integration tests, CI/CD automation
- Comprehensive test suites (solves task-317 problem)

**Keep Live Firebase** (10% of tests):
- Smoke tests for production validation
- Security rules testing
- End-to-end authentication flows

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Firebase Emulator runs in CI/CD pipeline for RTDB tests with automatic lifecycle management
- [ ] #2 Firebase C++ SDK automatically connects to emulator via FIREBASE_DATABASE_EMULATOR_HOST environment variable
- [ ] #3 All RTDB tests execute successfully against emulator without timeouts or rate limiting
- [ ] #4 Justfile recipes provide emulator commands (start/stop/status/test) with zero game code changes
- [ ] #5 Live Firebase tests remain as smoke tests for production validation (10% of test suite)
- [ ] #6 Test execution time improves 2-5x compared to live Firebase testing
- [ ] #7 CI/CD pipeline documentation includes emulator setup and justfile integration
- [ ] #8 Verification script validates emulator setup and confirms automatic SDK detection
<!-- AC:END -->

## Implementation Plan

1. Research Firebase Emulator Suite setup and configuration requirements
2. Add Firebase Emulator to CI/CD pipeline (Dockerfile or pipeline config)
3. Implement environment detection in FirebaseBackend to switch between live/emulator
4. Configure emulator connection settings (host, port, project ID)
5. Migrate RTDB tests to use emulator mode when CI environment detected
6. Maintain small subset of live Firebase tests as smoke tests
7. Update CI/CD documentation with emulator setup instructions
8. Validate test reliability improvements and execution time gains

## Implementation Notes

# Implementation Research Complete (2025-12-05)

## Summary
Firebase C++ SDK supports emulator connection via environment variable `FIREBASE_DATABASE_EMULATOR_HOST` - **NO game code changes required**. Implementation is 100% external through justfile recipes and CI/CD configuration.

## Prerequisites
- **Node.js** v16.0+ (for Firebase CLI)
- **Java JDK** v11+ (for emulator runtime)
- **Firebase CLI** v8.14.0+ (`npm install -g firebase-tools`)

## Key Technical Discovery
Firebase C++ SDK automatically detects `FIREBASE_DATABASE_EMULATOR_HOST` environment variable during initialization in `firebase::database::Database::GetInstance()`. No code changes needed in:
- ❌ GDScript (no emulator detection)
- ❌ C++ module (SDK handles automatically)
- ❌ Debug configs (same configs for both modes)
- ❌ Test code (transparent to tests)

## Platform-Specific Configuration
- **Desktop**: `FIREBASE_DATABASE_EMULATOR_HOST="localhost:9000"`
- **Android Emulator**: `FIREBASE_DATABASE_EMULATOR_HOST="10.0.2.2:9000"` (special IP for host)
- **Android Physical Device**: `FIREBASE_DATABASE_EMULATOR_HOST="<HOST_IP>:9000"`

## Implementation Phases

### Phase 1: Firebase Emulator Setup (30 min)
```bash
# Install and initialize
npm install -g firebase-tools
cd /Users/mattiasmyhrman/repos/gametwo
firebase init emulators  # Select Database only, port 9000
```

**Create `firebase.json` (project root)**:
```json
{
  "emulators": {
    "database": {
      "host": "127.0.0.1",
      "port": 9000
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  }
}
```

**Create `.firebaserc` (project root)**:
```json
{
  "projects": {
    "default": "your-project-id"
  }
}
```

### Phase 2: Justfile Integration (2-3 hours)

**Create `justfiles/justfile-firebase-emulator.justfile`**:

```makefile
# Firebase Emulator integration - 100% external, no game code changes

# Check if emulator running
_emulator-running:
    #!/usr/bin/env bash
    if lsof -i:9000 > /dev/null 2>&1; then
        echo "✅ Firebase Emulator running on port 9000"
    else
        echo "❌ Firebase Emulator not running"
        exit 1
    fi

# Start emulator in background
emulator-start:
    #!/usr/bin/env bash
    if lsof -i:9000 > /dev/null 2>&1; then
        echo "✅ Firebase Emulator already running"
    else
        echo "🚀 Starting Firebase Emulator..."
        firebase emulators:start --only database > logs/firebase-emulator.log 2>&1 &
        echo $! > logs/firebase-emulator.pid
        sleep 5
        echo "✅ Firebase Emulator started (PID: $(cat logs/firebase-emulator.pid))"
        echo "🌐 Emulator UI: http://localhost:4000"
    fi

# Stop emulator
emulator-stop:
    #!/usr/bin/env bash
    if [ -f logs/firebase-emulator.pid ]; then
        PID=$(cat logs/firebase-emulator.pid)
        if kill -0 $PID 2>/dev/null; then
            echo "🛑 Stopping Firebase Emulator (PID: $PID)..."
            kill $PID
            rm logs/firebase-emulator.pid
            echo "✅ Firebase Emulator stopped"
        fi
    else
        pkill -f "firebase emulators:start" || echo "No emulator process found"
    fi

# Show emulator status
emulator-status:
    #!/usr/bin/env bash
    if lsof -i:9000 > /dev/null 2>&1; then
        echo "✅ Firebase Emulator: RUNNING"
        echo "🌐 Database: localhost:9000"
        echo "🌐 UI: http://localhost:4000"
    else
        echo "❌ Firebase Emulator: NOT RUNNING"
    fi

# Desktop testing with emulator (auto start/stop)
test-desktop-emulator CONFIG:
    #!/usr/bin/env bash
    echo "🧪 Running desktop test with Firebase Emulator: {{CONFIG}}"
    firebase emulators:exec --only database \
        "export FIREBASE_DATABASE_EMULATOR_HOST='localhost:9000' && \
         just test-desktop-target {{CONFIG}}"

# Android testing with emulator (auto start/stop)
test-android-emulator CONFIG:
    #!/usr/bin/env bash
    echo "🧪 Running Android test with Firebase Emulator: {{CONFIG}}"
    firebase emulators:exec --only database \
        "export FIREBASE_DATABASE_EMULATOR_HOST='10.0.2.2:9000' && \
         just test-android-target {{CONFIG}}"

# Android physical device testing
test-android-emulator-device CONFIG HOST_IP:
    #!/usr/bin/env bash
    echo "🧪 Running Android device test: {{CONFIG}}"
    firebase emulators:exec --only database \
        "export FIREBASE_DATABASE_EMULATOR_HOST='{{HOST_IP}}:9000' && \
         just test-android-target {{CONFIG}}"

# Run comprehensive test suite with emulator
test-all-emulator:
    #!/usr/bin/env bash
    echo "🧪 Running comprehensive test suite with Firebase Emulator..."
    firebase emulators:exec --only database \
        "export FIREBASE_DATABASE_EMULATOR_HOST='localhost:9000' && \
         just test-desktop test-all && \
         export FIREBASE_DATABASE_EMULATOR_HOST='10.0.2.2:9000' && \
         just test-android test-all"

# Test Firebase configs with emulator
test-firebase-emulator:
    #!/usr/bin/env bash
    echo "🧪 Testing all Firebase configs with emulator..."
    firebase emulators:exec --only database \
        "export FIREBASE_DATABASE_EMULATOR_HOST='localhost:9000' && \
         just test-desktop-target firebase-cpp-layer && \
         just test-desktop-target firebase-backend-layer && \
         just test-desktop-target firebase-rtdb-layer && \
         export FIREBASE_DATABASE_EMULATOR_HOST='10.0.2.2:9000' && \
         just test-android-target firebase-cpp-layer && \
         just test-android-target firebase-backend-layer && \
         just test-android-target firebase-rtdb-layer"

# Validate emulator setup
emulator-validate:
    #!/usr/bin/env bash
    echo "🔍 Validating Firebase Emulator setup..."
    
    # Check Firebase CLI
    if ! command -v firebase &> /dev/null; then
        echo "❌ Firebase CLI not installed"
        echo "Install: npm install -g firebase-tools"
        exit 1
    fi
    echo "✅ Firebase CLI: $(firebase --version)"
    
    # Check Node.js version
    NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VERSION" -lt 16 ]; then
        echo "❌ Node.js v16+ required (current: $(node --version))"
        exit 1
    fi
    echo "✅ Node.js: $(node --version)"
    
    # Check Java version
    if ! command -v java &> /dev/null; then
        echo "❌ Java JDK not installed"
        exit 1
    fi
    echo "✅ Java: $(java -version 2>&1 | head -n 1)"
    
    # Check firebase.json
    if [ ! -f firebase.json ]; then
        echo "❌ firebase.json not found"
        echo "Run: firebase init emulators"
        exit 1
    fi
    echo "✅ firebase.json exists"
    
    echo ""
    echo "✅ All prerequisites met!"
```

**Add to main `justfile`**:
```makefile
import? 'justfiles/justfile-firebase-emulator.justfile'
```

### Phase 3: CI/CD Integration (1-2 hours)

**Update `.gitlab-ci.yml`**:
```yaml
stages:
  - validate
  - build
  - test
  - test-emulator  # New stage
  - deploy

variables:
  GIT_SUBMODULE_STRATEGY: recursive

test-emulator:
  stage: test-emulator
  image: node:18
  cache:
    paths:
      - ~/.cache/firebase/emulators/  # Cache emulator JARs
  before_script:
    - npm install -g firebase-tools
    - apt-get update && apt-get install -y default-jdk
    - firebase --version && java -version
  script:
    # Run all Firebase tests with emulator
    - firebase emulators:exec --only database "just test-all-emulator"
    - firebase emulators:exec --only database "just test-firebase-emulator"
  artifacts:
    paths:
      - logs/
    when: always
  only:
    - merge_requests
    - master
```

### Phase 4: Verification (1 hour)

**Create `scripts/verify-emulator.sh`**:
```bash
#!/usr/bin/env bash
set -e

echo "🔍 Firebase Emulator Verification"
echo "=================================="

# 1. Validate prerequisites
echo "Step 1: Validating prerequisites..."
just emulator-validate

# 2. Start emulator
echo "Step 2: Starting emulator..."
just emulator-start
sleep 3

# 3. Check status
echo "Step 3: Checking status..."
just emulator-status

# 4. Test single config
echo "Step 4: Testing config with emulator..."
export FIREBASE_DATABASE_EMULATOR_HOST="localhost:9000"
just test-desktop-target firebase-cpp-layer

# 5. Verify logs
echo "Step 5: Checking logs..."
TEST_ID=$(just logs-latest desktop)
just logs-search "$TEST_ID" "9000" || echo "⚠️ Emulator connection may be internal"

# 6. Stop emulator
echo "Step 6: Stopping emulator..."
just emulator-stop

echo "✅ Verification complete!"
```

## Expected Benefits

| Metric | Before (Live) | After (Emulator) | Improvement |
|--------|---------------|------------------|-------------|
| **Reliability** | Timeouts in suites | No timeouts | 100% reliable |
| **Speed** | Network + rate limit | Local execution | 2-5x faster |
| **Parallel** | Sequential only | Unlimited | Parallel-safe |
| **Cost** | Firebase quota | Zero | Free |
| **CI/CD** | Network failures | Deterministic | Zero flakiness |

**Specific Test Case: `rtdb.advanced.transaction`**
- Current: Passes individually (1.6s), timeouts in suite (76s)
- Expected: Consistent 0.5-1s in all scenarios

## Usage Examples

**Developer Workflow**:
```bash
# Manual emulator control
just emulator-start
export FIREBASE_DATABASE_EMULATOR_HOST="localhost:9000"
just test-desktop-target firebase-cpp-layer
just emulator-stop

# Automatic lifecycle (recommended)
just test-desktop-emulator firebase-cpp-layer
just test-android-emulator firebase-backend-layer
just test-all-emulator
```

**CI/CD Workflow**:
```bash
# Automatic emulator lifecycle
firebase emulators:exec --only database "just test-all"
```

## Hybrid Strategy (Recommended)

**Use Emulator** (90% of tests):
- Unit tests for RTDB operations
- Integration tests
- CI/CD automated testing
- Comprehensive test suites (task-317 problem)

**Keep Live Firebase** (10% of tests):
- Smoke tests for production validation
- Security rules testing
- End-to-end auth flows
- Performance monitoring

## Critical Notes

1. **Zero Game Code Changes**: All configuration is external via environment variables
2. **Platform Transparent**: Desktop/Android/iOS work identically
3. **SDK Automatic Detection**: Firebase C++ SDK checks environment variable during `Database::GetInstance()`
4. **No Android Special Code**: Android IP (10.0.2.2) set in justfile only
5. **Easy Rollback**: Remove environment variable = back to production

## Environment Variable Flow

```
Justfile (sets env var)
    ↓
Operating System (environment)
    ↓
Godot Engine (inherits env)
    ↓
Firebase C++ SDK (auto-detects)
    ↓
Emulator (if var set) OR Production (if not set)
```

## References

- [Firebase Emulator Suite Docs](https://firebase.google.com/docs/emulator-suite)
- [RTDB Emulator Connection](https://firebase.google.com/docs/emulator-suite/connect_rtdb)
- [Firebase C++ SDK GitHub](https://github.com/firebase/firebase-cpp-sdk)
- [Install & Configure](https://firebase.google.com/docs/emulator-suite/install_and_configure)

## Implementation Checklist

- [ ] Install Node.js v16+ and Java JDK 11+
- [ ] Install Firebase CLI: `npm install -g firebase-tools`
- [ ] Initialize emulator: `firebase init emulators`
- [ ] Create `justfiles/justfile-firebase-emulator.justfile`
- [ ] Add import to main justfile
- [ ] Create verification script: `scripts/verify-emulator.sh`
- [ ] Run verification: `./scripts/verify-emulator.sh`
- [ ] Update `.gitlab-ci.yml` with emulator stage
- [ ] Test rate limit scenario (task-317 original problem)
- [ ] Document in CLAUDE.md files
- [ ] Create smoke test suite for live Firebase (10%)
