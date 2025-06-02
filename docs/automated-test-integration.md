# Automated Test System Integration Guide

## Overview

The automated test system determines test success/failure by analyzing log patterns with unique test IDs. This provides reliable CI/CD integration while building on your existing debug infrastructure.

**Key Feature**: Tests automatically **restart the app by default** to ensure config changes are loaded, making tests reliable and deterministic.

## How It Works

### 1. Test ID Generation
```bash
just test-config-android system-testing
# Generates: test_20250602_143052_a1b2
```

### 2. Enhanced Config with Test ID
```json
{
  "actions": ["Print Debug Info", "Log System Info"],
  "test_metadata": {
    "test_id": "test_20250602_143052_a1b2",
    "config": "system-testing", 
    "timestamp": "20250602_143052"
  }
}
```

### 3. App Restart Behavior

**Default (Reliable):**
```bash
just test-config-android system-testing
# 🔄 Restarting app to ensure config is loaded...
# 🚀 Starting test with fresh app instance...
```

**Fast Iteration (No Restart):**
```bash
just test-config-android system-testing 30 true
# ⚡ Starting test without restart (using current app state)...
```

### 4. Expected Log Patterns

**Test Start:**
```
INFO [debug, test, start] DEBUG_TEST_START {"test_id": "test_20250602_143052_a1b2"}
```

**Action Success:**
```
INFO [debug, test, success] DEBUG_TEST_SUCCESS {
  "test_id": "test_20250602_143052_a1b2",
  "action": "Print Debug Info",
  "category": "Quick Actions",
  "duration_ms": 25
}
```

**Action Failure:**
```
ERROR [debug, test, failure] DEBUG_TEST_FAILURE {
  "test_id": "test_20250602_143052_a1b2",
  "action": "Missing Action",
  "category": "unknown", 
  "error": "Action not found in registry"
}
```

**Test Complete:**
```
INFO [debug, test, complete] DEBUG_TEST_COMPLETE {
  "test_id": "test_20250602_143052_a1b2",
  "total_actions": 2,
  "successful_actions": 2,
  "failed_actions": 0
}
```

## Implementation Steps

### 1. Enhance Debug Action Base Class

Add to `project/debug/actions/debug_action.gd`:
```gdscript
# Test tracking variables
static var current_test_id: String = ""
static var test_success_count: int = 0
static var test_failure_count: int = 0

# Test context methods
static func set_test_context(test_id: String) -> void:
    current_test_id = test_id
    test_success_count = 0
    test_failure_count = 0
    Log.info("DEBUG_TEST_START", {"test_id": test_id}, ["debug", "test", "start"])

# Enhanced execute with test tracking
func execute() -> void:
    # ... existing code ...
    
    if success and current_test_id != "":
        test_success_count += 1
        Log.info("DEBUG_TEST_SUCCESS", {
            "test_id": current_test_id,
            "action": action_name,
            "category": category
        }, ["debug", "test", "success"])
```

### 2. Enhanced Debug Startup Coordinator

Modify `project/addons/debug_startup/debug_startup_coordinator.gd`:
```gdscript
func execute_debug_actions():
    var config = load_debug_config()
    
    # Extract test metadata
    if config.has("test_metadata"):
        var test_id = config.test_metadata.get("test_id", "")
        if test_id != "":
            DebugAction.set_test_context(test_id)
    
    # Execute actions...
    # Emit completion signal when done
```

## CI/CD Integration

### Simple Pass/Fail Testing
```bash
# Returns exit code 0 for pass, 1 for fail (with restart)
just test-config-android system-testing 30

# Fast iteration without restart
just test-config-android system-testing 30 true

# Use in CI pipeline
if just test-config-android system-testing; then
    echo "✅ System tests passed"
else
    echo "❌ System tests failed" 
    exit 1
fi
```

### Test All Configurations
```bash
# Run all standard test configurations
just test-all-android

# Monitor specific test
just test-monitor-android system-testing 60

# Quick test with restart + monitoring
just test-quick-android performance-testing
```

### GitHub Actions Example
```yaml
- name: Run Automated Debug Tests
  run: |
    just test-config-android system-testing 45
    just test-config-android database-testing 30
    just test-all-android
```

### Results Structure
```json
{
  "test_id": "test_20250602_143052_a1b2",
  "config": "system-testing",
  "overall_result": "PASS",
  "successful_actions": 3,
  "failed_actions": 0,
  "test_complete": true
}
```

## Command Reference

### Primary Testing Commands

| Command | Behavior | Use Case |
|---------|----------|----------|
| `test-config-android <config>` | **Restarts app** + tests config | Reliable testing (default) |
| `test-config-android <config> 30 true` | **No restart** + tests current state | Fast iteration |
| `test-monitor-android <config>` | Monitor logs without changes | Log analysis |
| `test-quick-android <config>` | Push config + restart + quick test | Development workflow |
| `test-all-android` | Test all configs with restart | CI/CD validation |

### Configuration Management

| Command | Purpose |
|---------|---------|
| `config-push-android <config>` | Push config to device (no restart) |
| `config-restart-android <config>` | Push config + restart app |
| `config-status-android` | Check current config status |
| `config-list` | List available configurations |
| `config-clear-android` | Clear external config |

## Benefits

### For Development
- **Reliable results** - App restart ensures config is actually loaded
- **Fast iteration** - Optional no-restart mode for rapid testing
- **Instant feedback** - Know test results immediately  
- **Detailed logs** - Full test execution trace
- **Unique identification** - No confusion between test runs

### For CI/CD
- **Deterministic behavior** - Restart ensures consistent state
- **Reliable exit codes** - Proper automation integration
- **Structured results** - Parse test data programmatically
- **No device storage** - Uses existing log infrastructure

### For Debugging
- **Clear test boundaries** - Easy to isolate specific test runs
- **Rich metadata** - Test ID, timing, action details
- **Audit trail** - Complete log history
- **App state control** - Choose whether to restart or preserve state

## Troubleshooting

### Test Not Starting
- Check: App installed and running
- Check: ADB device connection
- Check: Config validation passes

### Actions Not Found
- Check: Debug action registry has all referenced actions
- Check: Action names match exactly (case-sensitive)

### Inconsistent Results
- **Issue**: Test results vary between runs
- **Solution**: Use default restart behavior (`test-config-android <config>`)
- **Explanation**: Without restart, app may be in different state

### Log Filtering Issues
- Check: Test ID appears in logs
- Check: LogCat not being filtered by system
- Check: App permissions for log output

## Migration Path

1. **Start simple** - Use on one config to test
2. **Choose behavior** - Default restart for reliability, opt-out for speed
3. **Enhance gradually** - Add test signals to key actions  
4. **Expand coverage** - Apply to all critical configs
5. **CI integration** - Add to build pipeline

## Best Practices

### Reliable Testing
- Use default restart behavior for CI/CD: `test-config-android <config>`
- Use `test-all-android` for comprehensive validation
- Monitor logs with `test-monitor-android <config> 60` for detailed analysis

### Fast Development
- Use no-restart mode for rapid iteration: `test-config-android <config> 30 true`
- Use `test-quick-android <config>` for push + restart + test workflow
- Check `config-status-android` to verify current state

### CI/CD Integration
- Always use restart behavior in automated environments
- Set appropriate timeouts for your configs (30-60 seconds typical)
- Use `test-all-android` for comprehensive pre-release validation

The system is designed to work with your existing debug actions while providing the automation and reliability you need for testing.
