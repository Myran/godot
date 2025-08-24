# task-095 - Create automated file size limit monitoring system

## Context

**Priority**: 🔥 HIGH  
**Status**: Open  
**Estimated Effort**: 2-3 days  
**Category**: Quality Assurance - Code Standards  

## Problem Statement

Despite successful resolution of all file size violations through recent refactoring, several files are approaching the 1000-line limit and need proactive monitoring to prevent future violations. Manual monitoring is insufficient for maintaining code quality standards.

**Current Situation**:
- `game_action_core.gd`: 1000 lines (exactly at limit)
- `debug_menu_controller.gd`: 983 lines  
- `firebase_backend.gd`: 968 lines
- `game.gd`: 946 lines

**Risk**: Without automated monitoring, files will gradually exceed limits, requiring expensive large-scale refactoring.

## Technical Goals

### Primary Objectives
1. **Automated Detection**: Real-time monitoring of file sizes approaching limits
2. **Proactive Alerts**: Early warning system before violations occur
3. **CI/CD Integration**: Prevent commits that violate size standards
4. **Trend Analysis**: Track file growth patterns over time

### Success Criteria
- [ ] Automated file size checking integrated into validation pipeline
- [ ] Warning alerts at 850+ lines, error alerts at 950+ lines
- [ ] CI/CD integration prevents oversized file commits
- [ ] Dashboard showing file size trends and risk indicators
- [ ] Zero file size violations maintained over time

## Implementation Approach

### Phase 1: Core Monitoring System
```bash
# Add to justfile validation pipeline
validate-file-sizes:
    #!/usr/bin/env bash
    echo "🔍 Checking file size compliance..."
    
    # Find all GDScript files
    find project/ -name "*.gd" -type f | while read file; do
        line_count=$(wc -l < "$file")
        
        if [ "$line_count" -ge 1000 ]; then
            echo "❌ VIOLATION: $file ($line_count lines) exceeds 1000 line limit"
            exit 1
        elif [ "$line_count" -ge 950 ]; then
            echo "🚨 ERROR: $file ($line_count lines) approaching limit (950+)"
            exit 1
        elif [ "$line_count" -ge 850 ]; then
            echo "⚠️  WARNING: $file ($line_count lines) approaching limit (850+)"
        fi
    done
    
    echo "✅ All files within size limits"
```

### Phase 2: Advanced Analytics
```bash
# File size trend analysis
analyze-file-sizes:
    #!/usr/bin/env bash
    echo "📊 File Size Analysis Report"
    echo "=========================="
    
    # Generate size report with risk categorization
    find project/ -name "*.gd" -type f -exec wc -l {} + | \
    sort -nr | head -20 | \
    awk '{
        if ($1 >= 950) print "🚨 CRITICAL: " $2 " (" $1 " lines)"
        else if ($1 >= 850) print "⚠️  WARNING: " $2 " (" $1 " lines)"  
        else if ($1 >= 750) print "📊 MONITOR: " $2 " (" $1 " lines)"
        else print "✅ OK: " $2 " (" $1 " lines)"
    }'
```

### Phase 3: CI/CD Integration
- Pre-commit hooks to block oversized files
- GitHub Actions integration for PR validation
- Automated reports in commit messages
- Trend tracking with historical data

## Dependencies

- **Depends on**: Existing validation pipeline (`just validate`)
- **Integrates with**: Git hooks, CI/CD workflow
- **Enhances**: Code quality standards, refactoring workflow
- **Supports**: Ongoing file size compliance efforts

## Implementation Details

### File Size Categories
```
✅ HEALTHY:    0-749 lines   (No action needed)
📊 MONITOR:    750-849 lines (Track growth)
⚠️  WARNING:   850-949 lines (Plan refactoring)
🚨 ERROR:      950-999 lines (Immediate action)
❌ VIOLATION:  1000+ lines   (Block commit)
```

### Integration Points
1. **Validation Pipeline**: Integrate with `just validate`
2. **Pre-commit Hooks**: Block violations before commit
3. **CI/CD**: Automated checking in GitHub Actions
4. **Reporting**: Generate trend reports and alerts

### Monitoring Dashboard
```bash
# Enhanced reporting with historical tracking
file-size-dashboard:
    echo "📈 GameTwo File Size Dashboard"
    echo "============================="
    echo ""
    echo "🎯 Current Status:"
    just validate-file-sizes --summary
    echo ""
    echo "📊 Top 10 Largest Files:"
    just analyze-file-sizes --top-10
    echo ""
    echo "📈 Growth Trends (Last 30 Days):"
    just analyze-file-growth --days 30
```

## Risk Mitigation

### Technical Risks
- **Performance Impact**: File scanning might slow validation
  - *Mitigation*: Efficient file scanning with caching
- **False Positives**: Generated files might trigger alerts
  - *Mitigation*: Configurable ignore patterns
- **Developer Friction**: Too many alerts might be ignored
  - *Mitigation*: Smart alerting with appropriate thresholds

### Operational Risks
- **Alert Fatigue**: Too frequent warnings
  - *Mitigation*: Graduated warning system with appropriate thresholds
- **Integration Complexity**: Multiple CI/CD systems
  - *Mitigation*: Simple, portable bash-based implementation

## Acceptance Criteria

### Must Have
- [ ] Automated file size validation integrated into `just validate`
- [ ] Pre-commit hooks prevent file size violations
- [ ] Clear categorization: HEALTHY/MONITOR/WARNING/ERROR/VIOLATION
- [ ] CI/CD integration blocks oversized file commits
- [ ] Zero performance impact on daily development workflow

### Should Have
- [ ] Historical trend tracking and analysis
- [ ] Dashboard with visual file size status
- [ ] Configurable thresholds and ignore patterns
- [ ] Integration with existing CLAUDE.md documentation

### Nice to Have
- [ ] GitHub Actions integration with PR comments
- [ ] Slack/email notifications for critical files
- [ ] Refactoring suggestions based on file analysis
- [ ] Integration with code complexity metrics

## Implementation Notes

**Configuration Management**:
```bash
# .filesizerc configuration
{
  "limits": {
    "warning": 850,
    "error": 950,
    "violation": 1000
  },
  "ignore_patterns": [
    "*/generated/*",
    "*/external/*",
    "*.generated.gd"
  ],
  "extensions": [".gd", ".cs", ".cpp", ".h"]
}
```

**Success Metrics**:
- Zero file size violations maintained over 6+ months
- Early warning system catches 100% of files before violation
- 95%+ developer satisfaction with monitoring system
- <100ms additional time added to validation pipeline

This proactive monitoring system builds upon the successful file size violation resolution and ensures long-term code quality compliance.