#!/bin/bash
# DirXplore Native Setup Script
# This script creates the Xcode project and adds all source files

set -e

PROJECT_NAME="DirXplore"
PROJECT_DIR=$(dirname "$0")
cd "$PROJECT_DIR"

echo "Creating Xcode project for $PROJECT_NAME..."

# Remove existing project if any
rm -rf "$PROJECT_NAME.xcodeproj"

# Create project using swift package generate-xcodeproj (or use xcodegen)
if command -v xcodegen &> /dev/null; then
    echo "Using XcodeGen..."
    cat > project.yml << EOF
name: $PROJECT_NAME
options:
  bundleIdPrefix: com.dirxplore
  deploymentTarget:
    iOS: "18.0"
settings:
  SWIFT_VERSION: "6.0"
  SWIFT_STRICT_CONCURRENCY: "complete"
targets:
  $PROJECT_NAME:
    type: application
    platform: iOS
    sources:
      - path: .
        excludes:
          - "setup.sh"
          - "project.yml"
          - "Package.swift"
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.dirxplore.app
      INFOPLIST_FILE: Resources/Info.plist
      CODE_SIGN_STYLE: Manual
      DEVELOPMENT_TEAM: ""
    entitlements:
      path: Resources/App.entitlements
    dependencies:
      - framework: Yams
        url: https://github.com/jpsim/Yams
        version: "5.0.0"
    preBuildScripts:
      - name: "SwiftGen"
        script: ""
  WidgetExtension:
    type: app-extension
    platform: iOS
    sources:
      - WidgetExtension
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.dirxplore.app.WidgetExtension
      INFOPLIST_FILE: WidgetExtension/Info.plist
    dependencies:
      - target: $PROJECT_NAME
EOF
    xcodegen generate
elif command -v xcrun &> /dev/null; then
    echo "XcodeGen not found. Creating project manually..."
    echo "Please open Xcode and create a new iOS App project named '$PROJECT_NAME'"
    echo "with SwiftUI interface, Swift 6, and iOS 18.0 deployment target."
    echo ""
    echo "Then add all files from the 'DirXploreNative' directory."
else
    echo "Please install XcodeGen or manually create the project in Xcode."
fi

echo ""
echo "Setup complete! Open $PROJECT_NAME.xcodeproj in Xcode."
