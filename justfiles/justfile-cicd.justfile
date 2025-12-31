# CI/CD related commands for Godot 4 Projects

# Generate GitLab CI configuration
generate-gitlab-ci:
    @echo "Generating GitLab CI configuration..."
    echo 'stages:' > .gitlab-ci.yml
    echo '  - validate' >> .gitlab-ci.yml
    echo '  - build' >> .gitlab-ci.yml
    echo '  - test' >> .gitlab-ci.yml
    echo '  - deploy' >> .gitlab-ci.yml
    echo '' >> .gitlab-ci.yml
    echo 'variables:' >> .gitlab-ci.yml
    echo '  GIT_SUBMODULE_STRATEGY: recursive' >> .gitlab-ci.yml
    echo '' >> .gitlab-ci.yml
    echo 'validate:' >> .gitlab-ci.yml
    echo '  stage: validate' >> .gitlab-ci.yml
    echo '  script:' >> .gitlab-ci.yml
    echo '    - just validate-env' >> .gitlab-ci.yml
    echo '' >> .gitlab-ci.yml
    echo 'build:' >> .gitlab-ci.yml
    echo '  stage: build' >> .gitlab-ci.yml
    echo '  script:' >> .gitlab-ci.yml
    echo '    - just install-deps' >> .gitlab-ci.yml
    echo '    - just build-editor' >> .gitlab-ci.yml
    echo '    - just build-templates' >> .gitlab-ci.yml
    echo '    - just export-all-android' >> .gitlab-ci.yml
    echo '    - just export-pck-ios' >> .gitlab-ci.yml
    echo '  artifacts:' >> .gitlab-ci.yml
    echo '    paths:' >> .gitlab-ci.yml
    echo '      - editor/' >> .gitlab-ci.yml
    echo '      - export/' >> .gitlab-ci.yml
    echo '      - templates/' >> .gitlab-ci.yml
    echo '' >> .gitlab-ci.yml
    echo 'test:' >> .gitlab-ci.yml
    echo '  stage: test' >> .gitlab-ci.yml
    echo '  script:' >> .gitlab-ci.yml
    echo '    - just lint' >> .gitlab-ci.yml
    echo '' >> .gitlab-ci.yml
    echo 'deploy:' >> .gitlab-ci.yml
    echo '  stage: deploy' >> .gitlab-ci.yml
    echo '  only:' >> .gitlab-ci.yml
    echo '    - master' >> .gitlab-ci.yml
    echo '  script:' >> .gitlab-ci.yml
    echo '    - just update-version' >> .gitlab-ci.yml
    echo '    - just deploy-ios' >> .gitlab-ci.yml
    echo '    - just deploy-android' >> .gitlab-ci.yml
    @echo "GitLab CI configuration generated successfully."

# Install pre-commit hook
install-hooks:
    @echo "Installing pre-commit hook..."
    mkdir -p .git/hooks
    echo '#!/bin/sh' > .git/hooks/pre-commit
    echo 'just generate-gitlab-ci' >> .git/hooks/pre-commit
    echo 'git add .gitlab-ci.yml' >> .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    @echo "Pre-commit hook installed successfully."

# CI/CD process
ci-cd: validate-env
    @echo "Running CI/CD process..."
    just generate-gitlab-ci
    just full-process

# Ship to App Store (production release)
# Includes debug symbol upload to Sentry for crash symbolication
ship-ios: export-pck-ios
    @echo "🚀 Shipping to App Store..."
    cd export/ios && fastlane beta
    @echo "📤 Uploading debug symbols to Sentry..."
    just sentry-upload-symbols-ios
    @echo "✅ Ship complete with crash symbols uploaded!"

# Ship to Play Store
# Workflow: bump version → export AAB → upload → upload debug symbols
# Usage: just ship-android [track] [draft]
#   track: internal (default), alpha, beta, production
#   draft: yes (for first upload to track), no (default)
# Includes debug symbol upload to Sentry for crash symbolication
ship-android track="internal" draft="no":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Shipping to Play Store ({{track}} track)..."

    # Step 1: Bump version code
    echo "📈 Bumping version code..."
    cd export/android && fastlane bump_version

    # Step 2: Export AAB
    echo "📦 Exporting AAB..."
    cd ../.. && just export-android-aab

    # Step 3: Upload to Play Store
    echo "☁️  Uploading to Play Store..."
    if [ "{{draft}}" = "yes" ]; then
        cd export/android && fastlane {{track}} draft:true
    else
        cd export/android && fastlane {{track}}
    fi

    # Step 4: Upload debug symbols to Sentry
    echo "📤 Uploading debug symbols to Sentry..."
    cd ../.. && just sentry-upload-symbols-android

    echo "✅ Ship complete with crash symbols uploaded!"

# Aliases
ship-android-internal draft="no":
    just ship-android internal {{draft}}

ship-android-production draft="no":
    just ship-android production {{draft}}

# Internal: Shared pipeline steps for export → test → ship
# Used by both pipeline-ship and pipeline-rebuild-ship
_pipeline-export-test-ship track draft:
    #!/usr/bin/env bash
    set -euo pipefail

    # Export all platforms
    echo "2️⃣ Exporting all platforms..."
    if ! just export-all; then
        echo "❌ Export failed - aborting ship"
        exit 1
    fi
    echo "✅ Exports completed"
    echo ""

    # Run tests
    echo "3️⃣ Running cross-platform tests..."
    if ! just log-run test; then
        echo "❌ Tests failed - aborting ship"
        exit 1
    fi
    echo "✅ Tests passed"
    echo ""

    # Ship to Play Store
    echo "4️⃣ Shipping to Play Store ({{track}})..."
    just ship-android {{track}} {{draft}}

# Pipeline: build → export → test → ship
# Standard release workflow - builds if needed, only ships if all tests pass
# Usage: just pipeline-ship [track] [draft]
#   track: internal (default), production
#   draft: yes (first upload), no (default)
pipeline-ship track="internal" draft="no":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🚀 Running pipeline-ship: build → export → test → ship"
    echo "⏱️  This takes 20-45 minutes"
    echo ""

    # Step 1: Build (incremental, not forced)
    echo "1️⃣ Building (incremental)..."
    if ! just build; then
        echo "❌ Build failed - aborting ship"
        exit 1
    fi
    echo "✅ Build completed"
    echo ""

    # Steps 2-4: Export, test, ship (shared)
    just _pipeline-export-test-ship {{track}} {{draft}}

    echo ""
    echo "🎉 Pipeline-ship completed!"

# Pipeline: rebuild → export → test → ship
# Full rebuild before shipping - use after C++ or template changes
# Usage: just pipeline-rebuild-ship [track] [draft]
pipeline-rebuild-ship track="internal" draft="no":
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔄 Running pipeline-rebuild-ship: rebuild → export → test → ship"
    echo "⏱️  This may take 45-90 minutes"
    echo ""

    # Step 1: Rebuild
    echo "1️⃣ Rebuilding all components..."
    if ! just rebuild; then
        echo "❌ Rebuild failed - aborting ship"
        exit 1
    fi
    echo "✅ Rebuild completed"
    echo ""

    # Steps 2-4: Export, test, ship (shared)
    just _pipeline-export-test-ship {{track}} {{draft}}

    echo ""
    echo "🎉 Pipeline-rebuild-ship completed!"
