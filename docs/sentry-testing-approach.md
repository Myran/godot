# Sentry SDK Testing Approach

## Overview

GameTwo uses a hybrid approach to Sentry SDK testing that validates both development-time integration and production-ready mobile deployment.

## Testing Strategy

### Desktop Testing (Editor Mode)
- **Purpose**: Validate Sentry integration during development
- **Method**: `just test-desktop-target` (runs in Godot editor)
- **What it tests**:
  - GDExtension loading and registration
  - SentrySDK singleton accessibility
  - Platform-specific code paths (macOS → SentryOptions)
  - API functionality in development environment
- **Limitations**: Does not test exported macOS application behavior

### Mobile Testing (Device Mode)
- **Purpose**: Validate Sentry integration in production-like environment
- **Method**: `just test-android-target` (runs on physical device)
- **What it tests**:
  - AAR plugin integration
  - Device-specific Sentry behavior
  - GDExtension functionality on mobile
  - Real-world error capture and reporting

## Test Lists

### `sentry-desktop`
- **Platform**: Desktop (macOS)
- **Mode**: Editor mode development testing
- **Focus**: Development workflow validation
- **Configs**: 4 test configurations
- **Duration**: 3-5 minutes

### `sentry-android`
- **Platform**: Android device
- **Mode**: Real device testing
- **Focus**: Production mobile validation
- **Configs**: 5 test configurations
- **Duration**: 3-6 minutes

### `sentry-core-validation`
- **Platform**: Desktop + Android
- **Mode**: Hybrid (editor + device)
- **Focus**: Quick essential functionality validation
- **Configs**: 3 test configurations
- **Duration**: 2-3 minutes

### `sentry-all`
- **Platform**: Desktop + Android
- **Mode**: Comprehensive testing
- **Focus**: Full Sentry integration validation
- **Configs**: 6 test configurations
- **Duration**: 5-10 minutes

## Key Validations

### What Desktop Tests Validate ✅
1. **GDExtension Loading**: Sentry GDExtension loads correctly in editor
2. **API Accessibility**: SentrySDK singleton is accessible and functional
3. **Platform Detection**: macOS correctly identified as native Sentry platform
4. **Code Path Validation**: Platform-specific SentryOptions API works
5. **Configuration**: Sentry project settings are properly parsed
6. **Development Workflow**: No crashes or errors during development

### What Mobile Tests Validate ✅
1. **AAR Integration**: Sentry AAR plugin loads on Android
2. **Device Compatibility**: Sentry works on physical Android devices
3. **Mobile API**: GDExtension integration with mobile-specific features
4. **Production Readiness**: Real-world error capture scenarios

## Production Testing Considerations

### Current Limitations
- No macOS export preset configured
- Desktop tests don't validate exported application behavior
- iOS testing requires physical device (Xcode deployment)

### Future Enhancements (Optional)
1. **Create macOS Export Preset**: For testing exported macOS applications
2. **Add iOS Device Testing**: Complete mobile validation
3. **Export Build Validation**: Test Sentry in actual production builds

## Usage Examples

```bash
# Quick development validation
just test-desktop-target sentry-core-validation

# Comprehensive testing (recommended for changes)
just test sentry-all

# Mobile-specific validation
just test-android-target sentry-android

# Individual platform testing
just test-desktop-target sentry-integration-test
just test-android-target sentry-android-integration-test
```

## Configuration Notes

- **Editor Mode**: `options/auto_init=false` allows manual testing
- **Mobile Mode**: Sentry automatically initializes via AAR
- **Platform Detection**: SentryOptions available on macOS/iOS, Dictionary on Android
- **Development**: Sentry captures errors during development (useful for debugging)

This approach provides comprehensive Sentry SDK validation while maintaining clear separation between development testing and production validation.