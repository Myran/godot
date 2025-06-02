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
just config-list                    # See available configs
just restart-with-config testing    # Apply config + restart (5 sec)
just config-clear                   # Reset to default
```

### Validation (CI/CD Ready)
```bash
just validate-config CONFIG         # Check single config
just validate-all-configs          # Check all configs (CI ready)
just check-config-status           # System health
```

### Testing
```bash
just test-config CONFIG            # Quick functional test
just config-status-android         # Check device state
```

## Available Configurations

| Config | Actions | Purpose |
|--------|---------|---------|
| `system-testing` | 3 | Platform validation |
| `database-testing` | 3 | RTDB operations |
| `gameplay-testing` | 3 | Core mechanics |
| `performance-testing` | 3 | Load testing |
| `minimal-testing` | 1 | Baseline |
| `no-actions` | 0 | Clean state |

## CI/CD Integration

### Pre-commit Hook
```bash
just validate-all-configs || exit 1
```

### GitHub Actions Example
```yaml
- name: Validate Debug Configs
  run: just validate-all-configs
```

### GitLab CI Example
```yaml
validate_configs:
  script:
    - just validate-all-configs
```

## Simple Workflow Patterns

### Development Loop
1. `just config-list` - See options
2. `just restart-with-config testing` - Apply config
3. Test functionality
4. `just config-clear` - Reset

### CI Pipeline
1. `just validate-all-configs` - Validate integrity
2. `just test-config system-testing` - Test key config
3. Continue with build if all pass

### Debugging Issues
1. `just check-config-status` - Check system health
2. `just validate-config CONFIG` - Check specific config
3. `just config-status-android` - Check device state

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
- Use `restart-with-config` for quick iteration
- Always `config-clear` when done testing
- Check `config-list` to see what's available

### CI/CD
- Run `validate-all-configs` in pre-commit hooks
- Test critical configs in CI pipeline
- Use simple commands for reliable automation

### Maintenance
- Keep configs simple and focused
- Use descriptive action names
- Validate before committing changes

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Config not found | Run `just config-list` |
| Invalid JSON | Run `just validate-config CONFIG` |
| Device issues | Run `just config-status-android` |
| CI failures | Run `just validate-all-configs` |

## Advanced Usage

For complex scenarios, see the full documentation:
- `just help-debug` - Complete debug workflow
- `just help-android` - Android development guide
- `project/docs/debug_system.md` - Technical details

---

**Remember: Keep it simple. The debug system is designed for clarity and reliability, not complexity.**
