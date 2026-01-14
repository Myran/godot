---
name: justfile
description: GameTwo justfile recipe usage patterns. Auto-triggers when working in the gametwo codebase. Ensures correct recipe selection, proper argument syntax, and efficient debugging workflows. Use this knowledge when running just commands, building, testing, or analyzing logs.
---

# Justfile Recipe Patterns

## Critical Syntax Rules

### Wrapper recipes take recipe names, NOT `just` commands

```bash
# ❌ WRONG - redundant "just"
just log-run-silent just test
just log-run-silent just deploy-android

# ✅ CORRECT - pass recipe name directly
just log-run-silent test
just log-run-silent deploy-android
```

### Always use just recipes, never raw build commands

```bash
# ❌ WRONG - bypasses helper recipes
scons platform=android target=template_release arch=arm64
./gradlew assembleRelease
adb install app.apk

# ✅ CORRECT - recipes handle all setup, deps, post-steps
just build-android-templates
just deploy-android
just test-android-target CONFIG
```

## Platform Workflows

### Android iteration

```bash
just deploy-android              # Export → install → launch (30-60 sec)
just test-android-target CONFIG  # Automated testing with validation
```

### Windows iteration (requires git sync)

```bash
# Windows VM pulls from git - must commit+push first
git add . && git commit -m "message" && git push
just win-vm-sync                          # Sync to VM
just win-vm-template-debug                # Build on VM
just win-vm-templates-package             # Package back to Mac
just test-windows-physical-target CONFIG  # Test on physical machine
```

### Full cycle testing (rebuild → export → test)

```bash
just build-export-test-android CONFIG     # Full Android rebuild + test
just build-export-test-ios CONFIG         # Full iOS rebuild + test
just build-export-test-macos CONFIG       # Full macOS rebuild + test
just build-export-test-windows CONFIG     # Full Windows rebuild + test
just build-export-test-all CONFIG         # All platforms
```

## Log Analysis

### Progressive debugging (start efficient, drill down)

```bash
# 1. Quick error scan (98% token savings) - START HERE
just logs-errors TEST_ID

# 2. Text search (99% token savings)
just logs-search TEST_ID "firebase"

# 3. Wildcard pattern matching
just logs-pattern TEST_ID "firebase.*"
just logs-pattern TEST_ID "*.error"

# 4. Full platform logs (last resort)
just logs-android TEST_ID
just logs-editor TEST_ID
```

### Test logs vs device logs

```bash
# Test result logs - filtered to debug actions only
just logs-android TEST_ID           # Filtered test results
just logs-search TEST_ID "term"     # Search within test results

# Full device logs - sees startup, initialization, everything
just logs-android-device "term"     # Complete device logs
```

Use `logs-android-device` when:
- Missing initialization/startup logs
- Logs seem incomplete
- Need to see non-debug-action output

### Platform auto-detection

Commands auto-detect platform from TEST_ID prefix:
- `android_*` → Android logs
- `editor_*` → Editor logs
- `ios_*` → iOS logs
- `macos_*` → macOS logs
- `windows-physical_*` → Windows logs

```bash
# Platform detected automatically
just logs-errors android_20250114_123456
just logs-errors editor_20250114_123456
```

## Recipe Hierarchy Reference

Key aliases to know:

| Alias | Underlying Recipe |
|-------|-------------------|
| `deploy-android` | `export-install-android-launch-debug` |
| `development` | `deploy-android` + `ci-validate` + `test` |
| `cpp-dev` | `build-android-templates` + `install-android-template` + `deploy-android` |

## Mandatory Rules

1. **Before Android testing**: `just deploy-android` after ANY code changes
2. **Before commit**: `just ci-validate`
3. **Windows iteration**: Commit + push before `win-vm-sync`
4. **Debugging**: Start with `logs-errors`, not full logs
