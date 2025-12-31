---
id: task-339
title: Implement automated App Store and Google Play deployment with Fastlane
status: Consider
assignee: []
created_date: '2025-12-14 00:35'
updated_date: '2025-12-29 00:07'
labels:
  - ci-cd
  - deployment
  - fastlane
  - app-store
  - google-play
  - ios
  - android
  - automation
dependencies:
  - task-336
priority: medium
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement automated deployment pipeline to iOS App Store and Google Play Store using Fastlane, integrated with GitHub Actions CI/CD.

**Scope:**
- **iOS**: App Store Connect upload, TestFlight distribution, App Store release
- **Android**: Google Play Console upload, internal/beta/production tracks

**Integration:**
- Triggered via GitHub Actions workflows (task-336 - UTM VM runner)
- Uses existing `just` export recipes for building artifacts
- Fastlane handles signing, metadata, screenshots, and store uploads

**Key workflows:**
1. **TestFlight/Internal Testing**: Push to branch triggers beta deployment
2. **Production Release**: Tag/release triggers store submission
3. **Metadata Management**: App descriptions, screenshots, changelogs in repo

**Security:**
- App Store Connect API keys stored as GitHub secrets
- Google Play service account credentials as GitHub secrets
- Code signing certificates/profiles managed via Fastlane Match or manual
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Install and configure Fastlane on Mac Mini runner
- [ ] #2 Configure iOS code signing with Fastlane Match or manual provisioning
- [ ] #3 Configure Android signing keystore management
- [ ] #4 Create Fastlane lane for TestFlight upload (iOS beta)
- [ ] #5 Create Fastlane lane for Google Play internal track upload (Android beta)
- [ ] #6 Create Fastlane lane for App Store production submission
- [ ] #7 Create Fastlane lane for Google Play production release
- [ ] #8 Integrate Fastlane lanes with existing just export recipes
- [ ] #9 Create GitHub Actions workflow for beta deployment (TestFlight + Play internal)
- [ ] #10 Create GitHub Actions workflow for production release (App Store + Play production)
- [ ] #11 Store signing credentials and API keys securely in GitHub secrets
- [ ] #12 Implement version/build number auto-increment
- [ ] #13 Configure metadata management (descriptions, changelogs) in repository
- [ ] #14 Document deployment procedures and rollback steps
<!-- AC:END -->
