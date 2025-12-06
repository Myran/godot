---
id: task-283
title: Implement End-to-End Sentry Crash Reporting Validation Across All Platforms
status: To Do
assignee: []
created_date: '2025-11-16 17:48'
updated_date: '2025-11-16 17:48'
labels: []
dependencies: []
---

## Assessment (2025-12-06)

**Value: HIGH** - Production readiness validation.

**Recommendation: KEEP** - Sentry crash reporting is critical for production games. Validating it works across all platforms is essential before launch. Android already validated. Need to complete iOS and desktop platforms.

**Effort**: Medium (testing across platforms)
**Impact**: High (ensures crash visibility in production)

---

## Description

**Critical Validation**: Implement comprehensive end-to-end testing of Sentry crash reporting across all platforms to ensure proper crash capture, stack trace preservation, and reporting in both GDScript and native code contexts.

## Problem Statement

With Task-281 (Sentry .so library integration) and Task-282 (test framework batch processing) resolved, we now have a fully functional Sentry integration. However, we need **validation that crashes are actually being reported properly** to Sentry with correct:

- **Platform coverage**: GDScript + native crashes on iOS, Android, Windows, macOS
- **Stack trace preservation**: Native frames preserved in GDScript crashes and vice versa
- **Contextual data**: Device info, user data, and breadcrumbs included
- **Error categorization**: Proper grouping and alerting in Sentry dashboard

## Platform Strategy

### **Phase 1: Android Validation (Primary Platform)**
**Why Android First**:
- ✅ Sentry integration fully tested and working (Task-281/282)
- ✅ Debug APK deployment workflow established
- ✅ Fast build cycle (60 seconds vs 20+ minutes for iOS)
- ✅ Sentry MCP tools available for immediate validation
- ✅ Native (.so) and GDScript crash scenarios available

### **Phase 2-4: Additional Platforms**
- **iOS**: Native crash reporting validation
- **Desktop**: Windows/macOS native crash handling
- **Cross-Platform**: Consistency validation across all platforms

## Implementation Plan

### **Phase 1: Android Crash Validation (Immediate)**

#### **Step 1: Branch Creation & Setup**
```bash
git checkout -b feature/sentry-crash-validation
# Focus on Android platform first for rapid iteration
```

#### **Step 2: Crash Scenario Testing**
Use existing Sentry crash test configurations:
- **GDScript Crashes**: `sentry-crash-scenarios` (null dereference, assertion failures, etc.)
- **Native Integration**: `sentry-android-integration-test` (validate .so loading)
- **Bridge Testing**: `sentry-integration-bridges` (GDScript↔Native error propagation)

#### **Step 3: Sentry MCP Validation**
```bash
# After inducing crashes, validate in Sentry:
mcp__sentry__find_organizations
mcp__sentry__find_projects
mcp__sentry__search_issues --naturalLanguageQuery "crash scenarios android"
mcp__sentry__get_issue_details --organizationSlug --issueId
```

#### **Step 4: Stack Trace Analysis**
**Validation Criteria**:
- ✅ GDScript crashes show native frames when applicable
- ✅ Native crashes preserve GDScript context
- ✅ Device metadata included (Android version, device model)
- ✅ Breadcrumbs capture user actions leading to crash
- ✅ Proper error grouping in Sentry dashboard

### **Phase 2-4: Additional Platform Expansion**

#### **iOS Validation Requirements**:
- Native crash reporting (Objective-C/Swift exceptions)
- GDScript crash context preservation
- App Store release build considerations
- Symbolication setup for production builds

#### **Desktop Validation Requirements**:
- Windows minidump generation and upload
- macOS crash reporter integration
- Cross-platform consistency in error reporting

#### **Cross-Platform Requirements**:
- Unified error grouping strategy
- Platform-specific context preservation
- Consistent alerting and monitoring

## Success Criteria

### **Phase 1 Success (Android)**:
✅ **GDScript Crashes**: Properly reported with full stack traces
✅ **Native Crashes**: .so library failures captured and reported
✅ **Integration Bridges**: Cross-language error propagation working
✅ **Sentry Dashboard**: Issues properly grouped with actionable context
✅ **MCP Validation**: Sentry MCP tools can retrieve and analyze crash data

### **Full Platform Success**:
✅ **All Platforms**: iOS, Android, Windows, macOS crash reporting functional
✅ **Consistency**: Unified error handling and reporting approach
✅ **Production Ready**: Release build crash reporting validated

## Technical Requirements

### **Sentry Configuration Validation**:
- **DSN Configuration**: Proper project and environment setup
- **Release Tracking**: Automatic version and build number association
- **Environment Tagging**: Development vs production crash separation
- **User Context**: Device ID, user session data inclusion

### **Crash Scenario Coverage**:
- **GDScript Errors**: Null references, type errors, assertion failures
- **Native Crashes**: Memory violations, library load failures, system errors
- **Integration Points**: GDScript→Native and Native→GDScript error propagation
- **Edge Cases**: Out of memory, network failures, permission errors

### **Monitoring & Alerting**:
- **Real-time Validation**: Immediate crash reporting verification
- **Dashboard Setup**: Proper issue grouping and alerting rules
- **Trend Analysis**: Crash rate monitoring and regression detection

## Risk Assessment

### **High Risk Areas**:
- **Native Integration**: Platform-specific crash handling complexities
- **Symbolication**: Debug symbols management for production builds
- **Performance**: Crash reporting overhead impact on app performance

### **Mitigation Strategies**:
- **Phased Approach**: Start with Android (known working) before platform expansion
- **Incremental Testing**: Validate each crash scenario independently
- **Fallback Mechanisms**: Ensure crash reporting doesn't cause additional crashes

## Dependencies

### **Prerequisites**:
- ✅ Task-281: Sentry .so library integration complete
- ✅ Task-282: Test framework batch processing resolved
- ✅ Sentry MCP tools: Available for crash validation
- ✅ Android Debug Workflow: Fast build and deployment established

### **Platform Dependencies**:
- **iOS**: Xcode build pipeline, App Store provisioning
- **Windows**: Windows build environment, minidump tools
- **macOS**: macOS build pipeline, crash reporter integration

## Timeline & Phasing

### **Phase 1 (Android)**: 2-4 hours
- Branch creation and setup
- Crash scenario execution and validation
- Sentry MCP dashboard verification
- Stack trace analysis completion

### **Phase 2-4 (Additional Platforms)**: 1-2 days
- Platform-specific setup and configuration
- Cross-platform crash scenario testing
- Unified validation and consistency checks

## Validation Tools & Workflow

### **Primary Tools**:
- **Sentry MCP**: `mcp__sentry__find_issues`, `mcp__sentry__get_issue_details`
- **Test Framework**: `just test-android-target sentry-crash-scenarios`
- **Log Analysis**: `just logs-errors TEST_ID` for crash validation
- **Real-time Monitoring**: Live crash detection and verification

### **Expected Workflow**:
1. Execute crash scenarios via test framework
2. Monitor real-time crash generation and reporting
3. Validate in Sentry dashboard via MCP tools
4. Analyze stack traces and contextual data quality
5. Verify error grouping and alerting functionality
6. Document platform-specific findings and requirements
