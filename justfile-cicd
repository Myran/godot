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
    echo '    - just build-android' >> .gitlab-ci.yml
    echo '    - just build-ios' >> .gitlab-ci.yml
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

# Deploy to App Store
deploy-ios: build-ios
    @echo "Deploying to App Store..."
    cd export/ios && fastlane beta

# Deploy to Play Store
deploy-android: build-android
    @echo "Deploying to Play Store..."
    cd export/android && fastlane internal
