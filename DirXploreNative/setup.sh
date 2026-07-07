#!/bin/bash
# DirXplore Native Setup Script
# Creates Xcode project with LibTorrent integration

set -e

PROJECT_NAME="DirXplore"
PROJECT_DIR=$(dirname "$0")
cd "$PROJECT_DIR"

echo "Creating Xcode project for $PROJECT_NAME with LibTorrent..."

# Remove existing project if any
rm -rf "$PROJECT_NAME.xcodeproj"

# Create project using XcodeGen
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
  CLANG_ENABLE_MODULES: "YES"
  CLANG_ENABLE_OBJC_WEAK: "YES"
  CLANG_CXX_LANGUAGE_STANDARD: "c++14"
  CLANG_CXX_LIBRARY: "libc++"
  HEADER_SEARCH_PATHS:
    - "\$(SRCROOT)/Thirdparty/libtorrent/include"
    - "\$(SRCROOT)/LibTorrent"
    - "\$(SRCROOT)/LibTorrent/Core"
    - "\$(SRCROOT)/LibTorrent/Core/Session"
    - "\$(SRCROOT)/LibTorrent/Core/TorrentHandle"
    - "\$(SRCROOT)/LibTorrent/Core/TorrentHandleSnapshot"
    - "\$(SRCROOT)/LibTorrent/Core/TorrentTracker"
    - "\$(SRCROOT)/LibTorrent/Core/TorrentFile"
    - "\$(SRCROOT)/LibTorrent/Core/TorrentFile/File"
    - "\$(SRCROOT)/LibTorrent/Core/TorrentFile/Magnet"
    - "\$(SRCROOT)/LibTorrent/Core/TorrentFile/Downloadable"
    - "\$(SRCROOT)/LibTorrent/Core/FileEntry"
    - "\$(SRCROOT)/LibTorrent/Core/SessionSettings"
    - "\$(SRCROOT)/LibTorrent/Utils"
  LIBRARY_SEARCH_PATHS:
    - "\$(SRCROOT)/libtorrent-build"
  SWIFT_OBJC_BRIDGING_HEADER: "\$(SRCROOT)/LibTorrent/Bridging-Header.h"
  OTHER_LDFLAGS:
    - "\$(inherited)"
    - "-lz"
    - "-liconv"
    - "-all_load"
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
          - "make.sh"
          - "Thirdparty"
          - "LibTorrent.xcodeproj"
      - path: LibTorrent
        includes:
          - "**/*.m"
          - "**/*.mm"
          - "**/*.swift"
          - "**/*.h"
        excludes:
          - "Bridging-Header.h"
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
      - sdk: CoreFoundation.framework
      - sdk: SystemConfiguration.framework
      - sdk: libiconv.tbd
    preBuildScripts:
      - name: "Build libtorrent C++ library"
        script: |
          if [ ! -d "\$SRCROOT/libtorrent-build" ]; then
            echo "Building C++ libtorrent library..."
            cd "\$SRCROOT"
            cmake ./Thirdparty/libtorrent \
              -B./libtorrent-build \
              -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_CXX_STANDARD=14 \
              -G Xcode \
              -DCMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET=15.0 \
              -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 \
              -DCMAKE_CXX_FLAGS="-DTORRENT_HAVE_MMAP=0 -DNDEBUG -DTORRENT_NO_DEPRECATE" \
              -DBUILD_SHARED_LIBS=OFF \
              -DCMAKE_XCODE_ATTRIBUTE_ARCHS="\$\(ARCHS_STANDARD\)"
          fi
  WidgetExtension:
    type: app-extension
    platform: iOS
    sources:
      - WidgetExtension
      - path: Models/DownloadActivityAttributes.swift
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.dirxplore.app.WidgetExtension
      INFOPLIST_FILE: WidgetExtension/Info.plist
    dependencies:
      - target: $PROJECT_NAME
EOF
    xcodegen generate

    # Add LibTorrent.xcodeproj reference after generation
    echo "Adding LibTorrent.xcodeproj to workspace..."
    if command -v xcrun &> /dev/null; then
        ruby -e '
            require "xcodeproj"
            project_path = "'$PROJECT_NAME'.xcodeproj"
            project = Xcodeproj::Project.open(project_path)
            libtorrent_ref = project.new_file("LibTorrent.xcodeproj")
            project.save
        ' 2>/dev/null || true
    fi

elif command -v xcrun &> /dev/null; then
    echo "XcodeGen not found. Please install XcodeGen: brew install xcodegen"
    echo ""
    echo "To manually set up in Xcode:"
    echo "1. Open Xcode and open/create the project"
    echo "2. Drag the 'LibTorrent' folder into the project"
    echo "3. Add all .m, .mm, .swift files from LibTorrent to the target"
    echo "4. Set bridging header to LibTorrent/Bridging-Header.h"
    echo "5. Add Thirdparty/libtorrent/include to Header Search Paths"
    echo "6. Link CoreFoundation, SystemConfiguration, libiconv"
    echo "7. Set C++ Standard Library to libc++"
    echo "8. Run make.sh to build C++ libtorrent before building"
else
    echo "Please install XcodeGen or Xcode command line tools."
fi

echo ""
echo "Setup complete! Open $PROJECT_NAME.xcodeproj in Xcode."
echo ""
echo "IMPORTANT: Before building, you must set up the C++ libtorrent dependency:"
echo "  1. Git submodule (recommended): git submodule update --init --recursive"
echo "  2. Or manually clone: git clone https://github.com/arvidn/libtorrent.git Thirdparty/libtorrent"
echo "  3. Then run: bash make.sh"
echo "This builds the C++ libtorrent static library via CMake + Xcode."
