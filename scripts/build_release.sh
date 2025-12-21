#!/bin/bash

# 1. Extract base version from pubspec.yaml
BASE_VERSION=$(grep 'version:' pubspec.yaml | sed 's/version: //')
# Remove any existing build number (everything after +) if present in pubspec
CLEAN_VERSION=$(echo $BASE_VERSION | cut -d'+' -f1)

# 2. Generate timestamp (YYYYMMDDHHmm)
TIMESTAMP=$(date +"%Y%m%d%H%M")

# 3. Construct full version string for logging
FULL_VERSION="${CLEAN_VERSION}-${TIMESTAMP}"

echo "🚀 Starting Release Build..."
echo "📦 Base Version: $CLEAN_VERSION"
echo "⏰ Timestamp:    $TIMESTAMP"
echo "🏷️  Target Tag:   $FULL_VERSION"

# 4. Run Flutter Build
# Note: --build-name sets the version name (e.g. 1.0.0)
#       --build-number sets the build number (e.g. 202512211400)
# In standard Flutter/Dart, package_info_plus usually exposes this as version+buildNumber.
# But since we customized VersionHelper to print "$version-$buildNumber", 
# passing these flags correctly is key.

flutter build macos --release --build-name="$CLEAN_VERSION" --build-number="$TIMESTAMP"

echo "✅ Build Complete!"
echo "📂 Artifact: build/macos/Build/Products/Release/iot_devkit.app"
