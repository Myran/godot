---
id: task-002
title: Add Battle replays to test
status: To Do
assignee: []
created_date: '2025-08-07 09:05'
labels: []
dependencies: []
---

## Description

Add a system which allows us to add replays to the regression test suite, enabling both selective replay inclusion and comprehensive test coverage while maintaining the validity that is paramount to company survival.

## 🎯 Executive Summary

After comprehensive analysis by specialized QA engineering subagents, **three distinct approaches** have been evaluated for integrating battle replays into GameTwo's existing regression test infrastructure:

1. **Directory Structure Approach** - Dedicated folder hierarchy for organized replay management
2. **Test List Integration Approach** - Enhanced metadata system within existing test-lists 
3. **Standalone Command Approach** - Independent replay testing system with optional integration

**STRATEGIC RECOMMENDATION**: **Hybrid Implementation** combining Test List Integration (Phase 1) with Standalone Commands (Phase 2) for optimal balance of immediate value and long-term scalability.

## 📋 Current System Analysis

### Existing Infrastructure
- **Test Lists**: JSON configs in `/test-lists/` using `@*-all` wildcard expansion
- **Generated Replays**: 25+ replay configs in `/debug_configs/archive/generated-replays/`  
- **Commands**: `just test-android test-all` runs all regression suites automatically
- **Replay Generation**: `just replay-generate SESSION_ID CONFIG_NAME` creates semantic replay tests

### Current Replay Structure
```json
{
  "description": "Generated replay from semantic session",
  "session_id": "session_20250801_154631_d73cf30f", 
  "semantic_action_count": 21,
  "actions": ["system.debug.hide_menu", {"action": "game.draft.move_card_to_lineup_player"}],
  "checksum_config": {
    "state_type": "player_actions",
    "initial_seed": 42,
    "expected_checksums": [...]
  }
}
```

## 🏗️ Approach 1: Directory Structure Approach

**🎯 CONCEPT**: Create dedicated folder hierarchy for replay organization

### Directory Structure Proposal
```
replay-tests/
├── regression/           # Production regression tests  
│   ├── battle/          # Battle system replays
│   ├── draft/           # Draft system replays
│   ├── ui/              # UI interaction replays
│   └── integration/     # Cross-system integration replays
├── experimental/        # Ad-hoc testing replays
├── archive/            # Deprecated/outdated replays  
└── templates/          # Replay config templates
```

### Integration Mechanism
```json
{
  "name": "All Regression Tests",
  "configs": [
    "@*-all",              // Existing system tests
    "@replay-*-all"        // All replay test suites
  ]
}
```

### New Commands
```bash
just replay-test TARGET                    # Run any replay test
just replay-regression-test CATEGORY       # Run regression replays by category
just replay-promote EXPERIMENTAL_CONFIG    # Promote experimental to regression
just replay-archive OLD_CONFIG             # Archive outdated replays
```

### ✅ Advantages
- **Clear Separation**: Regression vs experimental vs archived replays
- **Scalable Organization**: Category-based folders prevent config sprawl
- **Preserved Compatibility**: Existing system continues working unchanged
- **Professional Workflow**: Clear promotion path experimental → regression → archive

### ❌ Disadvantages  
- **Configuration Complexity**: Multiple config resolution paths
- **Migration Effort**: Need to move existing generated replays
- **Learning Curve**: New directory conventions to learn
- **Command Proliferation**: Additional replay-specific commands

### 📊 Implementation Assessment
- **Complexity**: 🟡 Medium (7-9 weeks)
- **Risk**: 🟢 Low (preserves existing system)
- **Maintenance**: 🟡 Medium (multiple config paths)

## 🔗 Approach 2: Test List Integration Approach

**🎯 CONCEPT**: Enhance existing test-lists with replay metadata and classification

### Enhanced Test-List Schema
```json
{
  "name": "Battle Regression Testing",
  "description": "Battle system with replay validation", 
  "version": "2.0",
  "metadata": {
    "test_type": "regression",
    "includes_replays": true,
    "replay_categories": ["functional", "regression"],
    "priority": "high"
  },
  "configs": [
    "battle-logic-only",
    "battle-animated", 
    "@replay-battle-all"
  ],
  "replay_configs": {
    "enabled": true,
    "categories": ["regression", "smoke"],
    "auto_discovery": true,
    "validation_mode": "checksum_strict"
  }
}
```

### Replay Classification System
**Four-Tier Classification Hierarchy:**
1. **Source-Based**: `generated-replay`, `manual-replay`, `migrated-replay`, `synthetic-replay`
2. **Purpose-Based**: `regression`, `smoke`, `performance`, `integration`, `experimental`  
3. **Stability**: `stable`, `unstable`, `experimental`, `deprecated`
4. **Execution Context**: `automated`, `manual`, `nightly`, `on-demand`

### Enhanced Command Interface
```bash
# Existing commands work unchanged
just test-android test-all                    # All test suites  
just test-android battle-all                  # Battle system tests

# New replay-aware commands
just test-android battle-all --replay-only    # Only replay configs
just test-android test-all --exclude-replays  # Traditional configs only
just test-android regression --tags stable    # Tag-filtered execution
just test-android comprehensive --replay-categories regression,smoke
```

### Migration Strategy
**Phase 1**: Non-breaking schema extension (existing test-lists unchanged)
**Phase 2**: Auto-discovery integration with `/debug_configs/archive/generated-replays/`  
**Phase 3**: Enhanced command interface with filtering
**Phase 4**: Advanced features (weights, conditional inclusion)

### ✅ Advantages
- **Zero Disruption**: Existing workflows continue unchanged
- **Progressive Enhancement**: Teams adopt at their own pace
- **Rich Metadata**: Advanced filtering and CI/CD optimization
- **Leveraged Infrastructure**: Builds on existing `@` symbol expansion

### ❌ Disadvantages
- **Schema Complexity**: Enhanced metadata increases cognitive load
- **Filter Complexity**: Boolean logic with metadata expressions  
- **Migration Overhead**: Converting existing test-lists
- **Performance Impact**: Metadata processing overhead

### 📊 Implementation Assessment  
- **Complexity**: 🟡 Medium (8-10 weeks)
- **Risk**: 🟢 Low (backwards compatible)
- **Maintenance**: 🟢 Low (builds on existing patterns)

## ⚡ Approach 3: Standalone Command Approach

**🎯 CONCEPT**: Independent replay testing system with specialized commands

### Command Architecture
```bash
# Core replay commands
just replay-run CONFIG                     # Single replay execution
just replay-batch SUITE_FILE              # Batch replay execution  
just replay-suite-create NAME CONFIGS     # Create replay test suite
just replay-suite-run SUITE_NAME          # Execute replay suite

# Suite management  
just replay-suite-list                    # List available suites
just replay-suite-validate SUITE          # Validate suite configuration
just replay-suite-stats SUITE             # Execution statistics

# Advanced operations
just replay-parallel SUITE1 SUITE2        # Parallel suite execution
just replay-marathon CONFIG_PATTERN       # Long-running endurance testing
just replay-bisect SUITE FAILURE_POINT    # Binary search for failures
```

### Replay Suite Configuration
```json
{
  "name": "Battle Regression Suite",
  "version": "1.0", 
  "description": "Core battle system replay validation",
  "metadata": {
    "maintainer": "qa-team",
    "priority": "critical",
    "estimated_duration": "45m"
  },
  "execution": {
    "parallel": true,
    "max_concurrent": 4,
    "timeout_per_replay": "180s",  
    "retry_failed": true
  },
  "replays": [
    {
      "config": "merge-25",
      "weight": 2,
      "required": true,
      "platforms": ["android", "desktop"]
    },
    {
      "config": "draft-complex-scenario", 
      "weight": 3,
      "required": false,
      "condition": "nightly"
    }
  ]
}
```

### Workflow Integration
```bash
# Independent replay testing
just replay-suite-run battle-regression    # Dedicated replay testing

# Optional integration with main suite
just test-android test-all && just replay-suite-run critical-replays
just replay-parallel-with-main battle-regression system-all
```

### Advanced Features
- **True Parallelism**: Run replay suites concurrently with main regression
- **Resource Management**: Intelligent device/resource allocation
- **Failure Analysis**: Cross-replay correlation and bisection tools
- **Performance Optimization**: Replay-specific execution optimizations

### ✅ Advantages  
- **Independence**: Replay changes don't affect main test system
- **Specialized Features**: Purpose-built tools for replay testing
- **Parallel Execution**: True concurrent execution with main suite
- **Evolution Freedom**: Independent development and release cycles

### ❌ Disadvantages
- **Duplicate Infrastructure**: Separate command system to maintain  
- **Knowledge Splitting**: Need expertise in both systems
- **Integration Complexity**: Coordinating with main test suite
- **Resource Contention**: Managing concurrent system access

### 📊 Implementation Assessment
- **Complexity**: 🟠 High (9-11 weeks) 
- **Risk**: 🟡 Medium (new system complexity)
- **Maintenance**: 🟠 High (dual system maintenance)

## 📊 Comparative Analysis Matrix

| Criteria | Directory Structure | Test List Integration | Standalone Commands | 
|----------|--------------------|--------------------|-------------------|
| **Implementation Time** | 7-9 weeks | 8-10 weeks | 9-11 weeks |
| **Breaking Changes** | None | None | None |  
| **Learning Curve** | Medium | Low | High |
| **Maintenance Overhead** | Medium | Low | High |
| **Scalability** | High | High | Very High |
| **Integration Complexity** | Low | Very Low | Medium |
| **Feature Richness** | Medium | High | Very High |
| **Risk Level** | Low | Low | Medium |
| **Long-term Flexibility** | Medium | High | Very High |

## 🎯 Strategic Recommendations

### RECOMMENDED APPROACH: **Hybrid Implementation**

**Phase 1 (Weeks 1-4): Test List Integration Foundation**
- Implement enhanced test-list schema with replay metadata  
- Create auto-discovery for existing generated replays
- Add basic filtering to existing commands (`--replay-only`, `--exclude-replays`)
- Migrate 3-5 critical test-lists to enhanced schema

**Phase 2 (Weeks 5-8): Standalone Command Layer**  
- Implement core replay commands (`replay-run`, `replay-batch`, `replay-suite-create`)
- Create replay-specific test suites for specialized testing
- Add parallel execution capabilities
- Develop advanced replay analysis tools

**Phase 3 (Weeks 9-12): Advanced Integration**
- Cross-system coordination and resource management
- Advanced filtering and metadata-driven execution
- Performance optimization and caching
- Comprehensive documentation and team training

### Why Hybrid Approach?

**Immediate Value (Phase 1)**:  
- Zero disruption to existing workflows
- Quick replay integration with familiar patterns  
- Builds on existing, well-tested infrastructure

**Advanced Capabilities (Phase 2)**:
- Specialized replay testing features
- True parallel execution with main regression
- Independent evolution of replay-specific needs

**Long-term Scalability (Phase 3)**:
- Best of both worlds - integration + independence
- Flexible system that adapts to changing needs
- Professional-grade replay testing capabilities

## 🚨 Risk Assessment & Mitigation

### HIGH PRIORITY RISKS
1. **Test Validity Compromise**: Replay integration affects core regression reliability
   - **Mitigation**: Phased rollout with extensive validation at each stage
   - **Monitoring**: Automated test reliability metrics and alerting

2. **Performance Degradation**: Additional replay processing slows existing workflows  
   - **Mitigation**: Lazy loading and caching of replay metadata
   - **Monitoring**: Execution time tracking and performance benchmarks

3. **Team Productivity Impact**: Complex new system disrupts development flow
   - **Mitigation**: Backwards compatibility and optional adoption
   - **Training**: Comprehensive documentation and hands-on training sessions

### MEDIUM PRIORITY RISKS  
1. **Configuration Sprawl**: Too many replay configs become unmaintainable
   - **Mitigation**: Automated archival and cleanup processes
   - **Governance**: Clear replay lifecycle and promotion criteria

2. **Resource Contention**: Parallel execution overwhelms test infrastructure
   - **Mitigation**: Intelligent resource management and queueing
   - **Scaling**: Cloud-based test execution for peak loads

## 📈 Success Metrics

### Phase 1 Success Criteria  
- ✅ Zero breaking changes to existing test workflows
- ✅ 3+ test-lists successfully enhanced with replay metadata  
- ✅ Auto-discovery identifies all 25+ existing generated replays
- ✅ Filtering commands work correctly (`--replay-only`, `--exclude-replays`)

### Phase 2 Success Criteria
- ✅ Standalone replay commands handle 100+ replay configs efficiently  
- ✅ Parallel execution reduces total test time by 30%+
- ✅ Replay-specific test suites provide specialized validation
- ✅ Cross-platform replay execution (Android + Desktop) working

### Phase 3 Success Criteria  
- ✅ Hybrid system provides seamless user experience
- ✅ Advanced features (weights, conditions, analytics) operational
- ✅ Team adoption >80% within 4 weeks of training
- ✅ System reliability metrics meet or exceed baseline

## 🛠️ Implementation Roadmap

### Week 1-2: Foundation Setup
- [ ] Create enhanced test-list schema specification
- [ ] Implement auto-discovery for `/debug_configs/archive/generated-replays/`  
- [ ] Create prototype enhanced test-list with replay integration
- [ ] Validate backwards compatibility with existing commands

### Week 3-4: Integration Testing
- [ ] Migrate 3 critical test-lists to enhanced schema
- [ ] Implement basic filtering commands (`--replay-only`, `--exclude-replays`)
- [ ] Cross-platform testing (Android + Desktop)
- [ ] Performance benchmarking and optimization

### Week 5-6: Standalone Commands  
- [ ] Implement core replay commands (`replay-run`, `replay-batch`)
- [ ] Create replay suite configuration system
- [ ] Add parallel execution capabilities  
- [ ] Develop replay analysis and reporting tools

### Week 7-8: Advanced Features
- [ ] Cross-system coordination and resource management
- [ ] Advanced filtering with metadata expressions
- [ ] Performance optimization and intelligent caching
- [ ] Automated maintenance workflows (archival, cleanup)

### Week 9-10: Production Readiness
- [ ] CI/CD pipeline integration and optimization
- [ ] Monitoring, alerting, and reliability metrics
- [ ] Comprehensive documentation and training materials
- [ ] Team training and adoption support

### Week 11-12: Validation & Rollout
- [ ] Full regression testing across all platforms
- [ ] Performance validation and capacity planning  
- [ ] Production deployment with gradual rollout
- [ ] Success metrics tracking and optimization

## 🎓 Team Training Requirements

### QA Team Training (8 hours)
- **Enhanced Test-Lists**: Metadata schema and replay classification
- **Filtering Commands**: Advanced filtering and tag-based execution
- **Replay Lifecycle**: Creation, validation, promotion, and archival
- **Troubleshooting**: Common issues and debugging workflows

### Development Team Training (4 hours)  
- **Replay Generation**: Converting gameplay sessions to test configs
- **Integration Testing**: Using replays for feature validation
- **Performance Impact**: Understanding replay execution overhead
- **Best Practices**: Replay creation and maintenance guidelines

### DevOps Team Training (6 hours)
- **CI/CD Integration**: Automated replay execution in pipelines  
- **Resource Management**: Parallel execution and infrastructure scaling
- **Monitoring**: Performance metrics and reliability tracking
- **Maintenance**: Automated cleanup and archival processes

## 💡 Long-term Vision

### 6-Month Goals
- **Comprehensive Coverage**: 200+ high-quality replay tests across all game systems
- **Automated Pipeline**: Full CI/CD integration with intelligent replay selection  
- **Advanced Analytics**: Cross-replay correlation analysis and failure prediction
- **Team Mastery**: >90% team comfort with hybrid replay testing system

### 12-Month Goals  
- **AI-Powered Generation**: Automated replay creation from bug reports
- **Cross-Platform Parity**: Identical replay behavior across all target platforms
- **Performance Optimization**: Sub-minute execution for critical replay suites
- **Industry Leadership**: Open-source contributions to replay testing community

This comprehensive analysis provides GameTwo with the strategic foundation needed to make informed decisions about replay integration that will ensure the **validity of tests paramount to company survival** while delivering significant improvements to development productivity and product quality.

---

## 🎯 FINAL DECISION: Simplified Folder Expansion Approach

After analyzing three complex approaches, we identified a **much simpler and more elegant solution** that leverages GameTwo's existing infrastructure:

### ✅ CHOSEN APPROACH: Folder Expansion with `/foldername/` Syntax

**Core Concept**: Extend existing test-list expansion to support folder-based references:

```json
{
  "name": "Battle Testing with Replays",
  "configs": [
    "battle-logic-only",                    // Traditional config
    "battle-animated",                      // Traditional config  
    "/generated-replays/",                  // All replays in folder
    "/generated-replays/merge-*",           // Wildcard within folder
    "/experimental/firebase-*",             // Subfolder with pattern
    "@battle-all"                          // Existing @ expansion
  ]
}
```

### 🚀 Implementation Plan (Simplified - 1 Day!)

**Phase 1: Core Implementation (4 hours)**
- Enhance `_expand_at_references` function to recognize `/folder/` patterns
- Add folder expansion logic with wildcard support within folders
- Integrate with existing config resolution system

**Phase 2: Testing & Validation (2 hours)**  
- Test folder expansion with existing replay configs in `/debug_configs/archive/generated-replays/`
- Validate backwards compatibility with all existing test-lists
- Cross-platform testing (Android + Desktop)

**Phase 3: Documentation & Rollout (2 hours)**
- Update CLAUDE.md with folder expansion syntax
- Create example test-lists demonstrating folder patterns
- Team demonstration and adoption

### 🎯 Why This Approach Wins

**✅ Simplicity**: Single day implementation vs 8-12 week complex approaches
**✅ Zero Disruption**: Existing workflows unchanged, purely additive
**✅ Natural Syntax**: `/folder/pattern` feels intuitive and familiar
**✅ Auto-Discovery**: New replays automatically included based on folder placement
**✅ Powerful**: Mix `/folder/`, `@symbols`, and direct configs in same test-list
**✅ Scalable**: Grows naturally with replay volume

### 📋 Immediate Usage Examples

**Current Generated Replays (25+ configs) become instantly usable:**
```bash
# Test all generated replays
just test-android "/generated-replays/"

# Test specific replay patterns  
just test-android "/generated-replays/merge-*"     # merge-20 through merge-25
just test-android "/generated-replays/draft-1*"    # draft-10 through draft-14

# Mix with existing patterns
just test-android battle-all "/generated-replays/merge-*" @firebase-all
```

**Enhanced Test-Lists:**
```json
{
  "name": "Daily Regression with Key Replays",
  "configs": [
    "@*-all",                              // All existing regression
    "/generated-replays/merge-*",          // Critical merge scenarios
    "/generated-replays/locked-*",         // Edge case validation  
    "!/generated-replays/draft-07"         // Exclude flaky replay
  ]
}
```

### 🏆 Success Criteria (24 hours)

- [ ] **Folder expansion working**: `/generated-replays/` discovers all 25+ replay configs
- [ ] **Wildcard support**: `/generated-replays/merge-*` finds merge-20 through merge-25
- [ ] **Mixed patterns**: Test-lists can combine `/folder/`, `@symbols`, and direct configs
- [ ] **Zero breaking changes**: All existing test-lists continue working unchanged
- [ ] **Cross-platform**: Folder expansion works on Android and Desktop
- [ ] **Auto-discovery**: New replays added to folders are automatically included

### 📈 Immediate Business Value

**Day 1**: Can include replay tests in regression suites with zero learning curve
**Week 1**: Teams organically adopt folder patterns for replay organization  
**Month 1**: Comprehensive replay coverage without complex infrastructure overhead

This elegant solution delivers 80% of the value of complex approaches in 1% of the implementation time, perfectly aligning with GameTwo's need for **test validity that's paramount to company survival** while maintaining development velocity.
