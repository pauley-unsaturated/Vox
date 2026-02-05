#!/bin/bash
# build-release.sh - Build Vox for distribution (unsigned)

# Script configuration
PROJECT_NAME="Vox"
SCHEME_NAME="Vox"
BUILD_DIR="build"
CONFIGURATION="Release"
DIST_DIR="$BUILD_DIR/dist"

# Check for Xcode command line tools
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Please install Xcode command line tools."
    exit 1
fi

# Create build directory if it doesn't exist
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/logs"

echo "Building $PROJECT_NAME ($CONFIGURATION)..."

# Build the project and save output to log file
LOG_FILE="$BUILD_DIR/logs/build-release-$(date +%Y%m%d-%H%M%S).log"
echo "Build log will be saved to: $LOG_FILE"

# Run build and capture output to log file with progress dots
echo -n "Building"

# Start build in background and capture output
xcodebuild \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR" \
  build > "$LOG_FILE" 2>&1 &

# Get the background process ID
BUILD_PID=$!

# Show progress dots while building
while kill -0 $BUILD_PID 2>/dev/null; do
    echo -n "."
    sleep 2
done

# Wait for build to complete and get result
wait $BUILD_PID
result=$?

echo "" # New line after dots

if [[ $result -ne 0 ]]; then
    echo "❌ Build failed with exit code: $result"
    echo "Build Errors:"
    echo "----------------------------------------"
    grep -E "(error: |warning: |\*\* BUILD FAILED \*\*)" "$LOG_FILE" | tail -10
    echo "----------------------------------------"
    echo "Full log available at: $LOG_FILE"
    exit $result
fi

echo "✅ Build completed successfully!"

# Set up paths
APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/Vox.app"
APPEX_PATH="$APP_PATH/Contents/PlugIns/VoxExtension.appex"

# Clean up any test bundles
if [[ -d "$APP_PATH/Contents/PlugIns" ]]; then
    find "$APP_PATH/Contents/PlugIns" -name "*.xctest" -type d -exec rm -rf {} + 2>/dev/null || true
fi

echo ""
echo "Verifying code signature..."

# Remove extended attributes (quarantine flags, etc.)
xattr -cr "$APP_PATH"

# Verify the signature from Xcode build
codesign --verify --verbose "$APP_PATH" 2>&1
if [[ $? -ne 0 ]]; then
    echo "❌ Code signature verification failed!"
    exit 1
fi

# Show signing info
echo ""
codesign -dvv "$APP_PATH" 2>&1 | grep -E "Authority=|TeamIdentifier="

# Create distribution folder with zip
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo ""
echo "Creating distribution zip..."
cd "$BUILD_DIR/Build/Products/$CONFIGURATION"
zip -rq "../../../dist/Vox.zip" "Vox.app"
cd - > /dev/null

ZIP_PATH="$DIST_DIR/Vox.zip"
ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

echo ""
echo "========================================="
echo "🎉 Distribution build ready!"
echo "========================================="
echo ""
echo "Zip file: $ZIP_PATH ($ZIP_SIZE)"
echo ""
echo "Instructions for your buddy:"
echo "  1. Download and unzip Vox.zip"
echo "  2. Move Vox.app to /Applications"
echo "  3. Right-click → Open (approve security dialog)"
echo "  4. The AUv3 plugin will be available in DAWs"
echo ""

exit 0
