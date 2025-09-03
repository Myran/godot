# Command Integration in Test Lists - Feature Guide

## 🚀 Overview

GameTwo's test system now supports executing `just` commands directly from test lists with intelligent platform filtering and context inheritance. This feature seamlessly integrates command-based testing with existing config-based workflows, providing enhanced validation capabilities while maintaining full backward compatibility.

### Key Benefits

- **🎯 Platform Intelligence**: Commands automatically run only on compatible platforms
- **🔄 Context Inheritance**: Commands receive TEST_ID and session data for integrated logging
- **⚡ Zero Maintenance**: Existing test lists continue working unchanged
- **🛡️ Error Isolation**: Command failures don't break test list execution
- **📈 Enhanced Coverage**: Combine config testing with custom command validation

## 🎯 When to Use This Feature

### Perfect Use Cases

1. **Save/Load Cycle Validation**: Test gamestate consistency after config execution
2. **Cross-Platform Workflows**: Same test list, platform-specific command execution
3. **Extended Validation**: Add custom verification steps to standard config tests
4. **Integration Testing**: Combine multiple testing approaches in unified workflow

### Example Scenarios

- **Gamestate Testing**: Run config to create save → Execute save/load cycle command
- **Performance Validation**: Run standard tests → Execute performance analysis commands
- **Cross-Platform Parity**: Desktop and Android tests with platform-specific validation
- **Regression Testing**: Standard configs + specialized regression commands

## 📋 JSON Format Reference

### Basic Structure

```json
{
  "name": "Test List Name",
  "description": "Test description",
  "configs": [
    "existing-config-name"
  ],
  "commands": [
    {
      "command": "just-command-name",
      "platforms": ["desktop", "android"],
      "description": "What this command does"
    }
  ]
}
```

### Field Specifications

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `commands` | Optional | Array | Array of command objects |
| `command` | Required | String | Exact just command name (without 'just') |
| `platforms` | Required | Array | Target platforms: `["desktop"]`, `["android"]`, or `["desktop", "android"]` |
| `description` | Required | String | Human-readable command description |

## 🔄 Execution Flow

### Step-by-Step Process

1. **Config Execution**: All `configs` array items execute first (existing behavior)
2. **Command Discovery**: System checks for optional `commands` array
3. **Platform Filtering**: Commands filtered by current execution platform
4. **Context Preparation**: TEST_ID and session data prepared for commands
5. **Command Execution**: Compatible commands execute with full context inheritance
6. **Result Integration**: Command results integrated with existing error analysis

### Platform Filtering Logic

```bash
# Desktop execution
just test-desktop-target my-test-list
# → Runs commands with "desktop" in platforms array
# → Skips commands with only "android" in platforms array

# Android execution  
just test-android-target my-test-list
# → Runs commands with "android" in platforms array
# → Skips commands with only "desktop" in platforms array
```

## 💻 Practical Examples

### Example 1: Basic Save/Load Cycle Testing

**File**: `tests/test-lists/gamestate-validation.json`

```json
{
  "name": "Gamestate Save/Load Validation",
  "description": "Test config execution followed by save/load cycle validation",
  "configs": [
    "gamestate-save-load-test"
  ],
  "commands": [
    {
      "command": "test-save-load-cycle-desktop",
      "platforms": ["desktop"],
      "description": "Validate save/load consistency on desktop"
    },
    {
      "command": "test-save-load-cycle-android",
      "platforms": ["android"],
      "description": "Validate save/load consistency on Android"
    }
  ]
}
```

**Usage**:
```bash
# Desktop testing - runs config + desktop save/load command
just test-desktop-target gamestate-validation

# Android testing - runs config + Android save/load command  
just test-android-target gamestate-validation
```

**Expected Output**:
- Desktop: Executes config, then runs `test-save-load-cycle-desktop`
- Android: Executes config, then runs `test-save-load-cycle-android`

### Example 2: Cross-Platform Performance Testing

**File**: `tests/test-lists/performance-validation.json`

```json
{
  "name": "Cross-Platform Performance Validation",
  "description": "Standard testing with platform-specific performance analysis",
  "configs": [
    "production-ready",
    "firebase-cpp-layer"
  ],
  "commands": [
    {
      "command": "analyze-performance-desktop",
      "platforms": ["desktop"],
      "description": "Desktop performance analysis with detailed metrics"
    },
    {
      "command": "analyze-performance-mobile",
      "platforms": ["android"],
      "description": "Mobile-specific performance validation"
    },
    {
      "command": "memory-profile-analysis",
      "platforms": ["desktop", "android"],
      "description": "Cross-platform memory usage validation"
    }
  ]
}
```

**Usage**:
```bash
# Desktop: Runs 2 configs + desktop performance + memory analysis
just test-desktop-target performance-validation

# Android: Runs 2 configs + mobile performance + memory analysis  
just test-android-target performance-validation
```

### Example 3: Complex Multi-Stage Testing

**File**: `tests/test-lists/comprehensive-regression.json`

```json
{
  "name": "Comprehensive Regression Testing",
  "description": "Full regression with specialized validation commands",
  "configs": [
    "@system-all",
    "@firebase-all",
    "production-ready"
  ],
  "commands": [
    {
      "command": "validate-database-integrity",
      "platforms": ["desktop", "android"],
      "description": "Verify database consistency after system tests"
    },
    {
      "command": "check-memory-leaks-desktop",
      "platforms": ["desktop"],
      "description": "Desktop-specific memory leak detection"
    },
    {
      "command": "validate-network-resilience",
      "platforms": ["android"],
      "description": "Android network connectivity validation"
    },
    {
      "command": "performance-regression-check",
      "platforms": ["desktop", "android"],
      "description": "Ensure no performance degradation"
    }
  ]
}
```

**Expected Results**:
- Desktop: 3 config groups + 3 commands (database, memory leaks, performance)
- Android: 3 config groups + 3 commands (database, network, performance)

## 🛠️ Command Requirements

### Command Compatibility

Commands used in test lists must:

1. **Exist in just system**: Listed in `just --list` output
2. **Handle TEST_ID**: Accept `TEST_ID` environment variable (recommended)
3. **Work in automated context**: Function without user interaction
4. **Fail gracefully**: Handle errors without breaking test list execution

### Environment Variables Available to Commands

| Variable | Description | Example |
|----------|-------------|---------|
| `TEST_ID` | Unique test execution identifier | `testlist-my-test_desktop_1756924010` |
| `CURRENT_PLATFORM` | Execution platform | `desktop` or `android` |
| `TEST_SESSION` | Session timestamp | `1756924010` |

### Creating Compatible Commands

```bash
# Example command that uses TEST_ID context
my-custom-validation:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="${TEST_ID:-default-test-id}"
    echo "🧪 Custom validation with context: $TEST_ID"
    
    # Your validation logic here
    # Command can access all inherited context
```

## 🔍 Debugging and Validation

### Testing Command Integration

1. **Validate JSON Format**:
   ```bash
   jq '.' tests/test-lists/your-test-list.json
   ```

2. **Test Command Discovery**:
   ```bash
   just --list | grep your-command-name
   ```

3. **Demo Integration**:
   ```bash
   just test-command-integration
   ```

4. **Full Integration Test**:
   ```bash
   just test-desktop-target your-test-list
   ```

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Command not found | "Command not found: my-command" | Verify command exists in `just --list` |
| Platform mismatch | Commands not executing | Check `platforms` array matches execution platform |
| JSON syntax error | Test list fails to parse | Validate JSON with `jq` command |
| Context inheritance | Commands missing TEST_ID | Ensure command accepts environment variables |

## 📊 Monitoring and Analytics

### Success Indicators

- **Command Execution**: Commands run on appropriate platforms
- **Context Inheritance**: TEST_ID properly passed to commands
- **Error Handling**: Command failures logged but don't break test list
- **Platform Filtering**: Correct commands execute per platform

### Log Analysis

Commands integrate with existing log analysis:
```bash
# Analyze command execution in test results
just logs-errors TEST_ID

# Search for command-specific patterns
just logs-pattern TEST_ID "command.*execution"

# Full text search in command output
just logs-text TEST_ID "your-search-term"
```

## 🚀 Best Practices

### Design Principles

1. **Explicit Platform Declaration**: Always specify `platforms` array clearly
2. **Descriptive Names**: Use clear, descriptive command names and descriptions
3. **Idempotent Commands**: Commands should be safe to run multiple times
4. **Graceful Failure**: Handle errors without breaking the broader test execution
5. **Context Awareness**: Utilize TEST_ID and session data when available

### JSON Organization

```json
{
  "name": "Clear, descriptive test list name",
  "description": "Explain what this test list validates",
  "configs": [
    "// Order configs logically - dependencies first",
    "basic-setup-config",
    "main-functionality-config"
  ],
  "commands": [
    {
      "// Group related commands together",
      "command": "validate-setup-results",
      "platforms": ["desktop", "android"],
      "description": "Cross-platform validation of setup"
    },
    {
      "// Platform-specific commands after cross-platform",
      "command": "desktop-specific-validation",
      "platforms": ["desktop"],
      "description": "Desktop-only deep validation"
    }
  ]
}
```

### Command Development

1. **Start Simple**: Begin with basic commands, add complexity gradually
2. **Test Standalone**: Ensure commands work independently before integration
3. **Document Context**: Clearly document what context commands expect
4. **Handle Edge Cases**: Commands should handle missing context gracefully
5. **Integrate Logging**: Use existing GameTwo logging patterns

## 🎯 Migration Guide

### For Existing Test Lists

**No changes required** - existing test lists continue working unchanged.

### Adding Commands to Existing Lists

1. **Identify Enhancement Opportunities**: Look for manual validation steps
2. **Create Compatible Commands**: Develop commands following requirements above
3. **Add Commands Array**: Extend existing JSON with optional `commands` section
4. **Test Incrementally**: Add one command at a time, validate behavior
5. **Document Changes**: Update test list descriptions to reflect new capabilities

### Example Migration

**Before** (existing):
```json
{
  "name": "Firebase Testing",
  "description": "Test Firebase functionality",
  "configs": [
    "firebase-cpp-layer",
    "firebase-network-connectivity"
  ]
}
```

**After** (enhanced):
```json
{
  "name": "Firebase Testing with Save/Load Validation",
  "description": "Test Firebase functionality plus save/load consistency",
  "configs": [
    "firebase-cpp-layer",
    "firebase-network-connectivity"
  ],
  "commands": [
    {
      "command": "test-save-load-cycle-desktop",
      "platforms": ["desktop"],
      "description": "Validate save/load with Firebase data"
    },
    {
      "command": "test-save-load-cycle-android",
      "platforms": ["android"],
      "description": "Validate save/load with Firebase data on Android"
    }
  ]
}
```

## 📚 Additional Resources

### Help Commands
- `just help-command-integration` - Complete interactive guide
- `just help-debug` - Testing workflows and debugging
- `just help-at-symbols` - Advanced pattern systems

### Example Files
- `tests/test-lists/command-integration-test.json` - Working reference implementation
- `backlog/research/tdd-command-integration-final-status.md` - Technical implementation details

### Related Documentation
- [CLAUDE.md](../../CLAUDE.md) - Quick reference and daily workflow integration
- [CLAUDE-ADVANCED.md](../../CLAUDE-ADVANCED.md) - Advanced testing patterns and workflows

---

## 🎉 Ready to Use

This feature is **production-ready** and available immediately. Start with the examples above, then customize for your specific testing needs. The feature provides a powerful platform for enhanced testing while maintaining the simplicity and reliability of the existing GameTwo test infrastructure.

**Questions or need help?** Use `just help-command-integration` for interactive guidance!