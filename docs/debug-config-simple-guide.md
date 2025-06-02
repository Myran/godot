# GameTwo Debug Configuration - Simple CI/CD Guide

## Overview
Simple, focused debug configuration system for GameTwo with CI/CD readiness.

**Philosophy: Simplicity First**
- Clear command names
- Minimal complexity
- Reliable validation
- Fast feedback

## Quick Commands

### Daily Development
```bash
just config-list                        # See available configs
just config-restart-android testing     # Apply config + restart (5 sec)
just config-clear-android               # Reset to default
```

### Validation (CI/CD Ready)
```bash
just test-config-android CONFIG         # Test single config (restarts app)
just test-all-android                   # Test all configs (CI ready)
just config-status-android              # System health check
```

### Testing
```bash
just test-config-android CONFIG         # Reliable functional test (with restart)
just test-config-android CONFIG 30 true # Fast test (no restart)
just config-status-android              # Check device state
```

## Available Configurations

| Config | Actions | Purpose |
|--------|---------|---------|
| `system-testing` | 4 | Platform validation |
| `database-testing` | 5 | RTDB operations |
| `gameplay-testing` | 3 | Core mechanics |
| `performance-testing` | 3 | Load testing |
| `minimal-testing` | 1 | Baseline |
| `no-actions` | 0 | Clean state |

## CI/CD Integration

### Pre-commit Hook
```bash
just test-all-android || exit 1
```

### GitHub Actions Example
```yaml
- name: Validate Debug Configs
  run: just test-all-android
```

### GitLab CI Example
```yaml
validate_configs:
  script:
    - just test-all-android
```

## Simple Workflow Patterns

### Development Loop
1. `just config-list` - See options
2. `just config-restart-android testing` - Apply config
3. Test functionality
4. `just config-clear-android` - Reset

### CI Pipeline
1. `just test-all-android` - Test all configurations
2. `just test-config-android system-testing` - Test key config
3. Continue with build if all pass

### Debugging Issues
1. `just config-status-android` - Check system health
2. `just test-config-android CONFIG` - Test specific config
3. `just test-monitor-android CONFIG` - Monitor logs

## Testing Behavior

**Default (Reliable):**
- `just test-config-android minimal-testing` 
- **Restarts app** to ensure config is loaded
- Shows: "🔄 Restarting app to ensure config is loaded..."

**Fast Iteration:**
- `just test-config-android minimal-testing 30 true`
- **No restart** - tests current app state
- Shows: "⚡ Starting test without restart..."

## Configuration File Format

Simple JSON structure:
```json
{
  "actions": [
    "Action Name 1", 
    "Action Name 2"
  ]
}
```

**Rules:**
- Must have `actions` array
- Action names must be non-empty strings
- Duplicates are allowed but warned about
- Empty arrays are valid for baseline testing

## Error Handling

All commands return proper exit codes:
- `0` = Success
- `1` = Failure

Error messages are clear and actionable:
```bash
❌ Not found: project/debug_configs/missing.json
❌ Invalid JSON
❌ Missing actions array
```

## Best Practices

### Development
- Use `config-restart-android` for quick iteration
- Always `config-clear-android` when done testing
- Check `config-list` to see what's available

### CI/CD
- Use `test-all-android` for comprehensive validation
- Use default restart behavior for reliable results
- Set appropriate timeouts (30-60 seconds typical)

### Maintenance
- Keep configs simple and focused
- Use descriptive action names
- Test configs before committing changes

## Command Reference

### Configuration Management
| Command | Purpose |
|---------|---------|
| `config-list` | List available configurations |
| `config-push-android <config>` | Push config (no restart) |
| `config-restart-android <config>` | Push config + restart app |
| `config-status-android` | Check current config status |
| `config-clear-android` | Clear external config |
| `config-setup` | Create sample configurations |

### Testing Commands
| Command | Behavior | Use Case |
|---------|----------|----------|
| `test-config-android <config>` | **Restarts app** + tests | Reliable testing |
| `test-config-android <config> 30 true` | **No restart** + tests | Fast iteration |
| `test-monitor-android <config>` | Monitor logs | Analysis |
| `test-quick-android <config>` | Push + restart + test | Development |
| `test-all-android` | Test all configs | CI/CD |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Config not found | Run `just config-list` |
| Test timeouts | Use restart behavior: `just test-config-android CONFIG` |
| Device issues | Run `just config-status-android` |
| CI failures | Run `just test-all-android` locally |
| Inconsistent results | Ensure using restart behavior (default) |

## Advanced Usage

For complex scenarios, see the full documentation:
- `just help-debug` - Complete debug workflow
- `just help-android` - Android development guide
- `project/docs/debug_system.md` - Technical details
- `docs/automated-test-integration.md` - Testing system details

---

**Remember: Keep it simple. The debug system is designed for clarity and reliability, not complexity.**
