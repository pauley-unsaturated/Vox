#!/bin/bash
# build.sh - Build the Vox synthesizer plugin

# Script configuration
PROJECT_NAME="Vox"
SCHEME_NAME="Vox"
BUILD_DIR="build"
CONFIGURATION="Debug"

# Check for Xcode command line tools
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Please install Xcode command line tools."
    exit 1
fi

# Create build directory if it doesn't exist
mkdir -p "$BUILD_DIR"

echo "Building $PROJECT_NAME ($CONFIGURATION)..."

# Create logs directory if it doesn't exist
mkdir -p "$BUILD_DIR/logs"

# Build the project and save output to log file
LOG_FILE="$BUILD_DIR/logs/build-$(date +%Y%m%d-%H%M%S).log"
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

if [[ $result -eq 0 ]]; then
    # Clean up any test bundles that may have been copied to app PlugIns folder
    APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION/Vox.app"
    if [[ -d "$APP_PATH/Contents/PlugIns" ]]; then
        find "$APP_PATH/Contents/PlugIns" -name "*.xctest" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    echo "✅ Build completed successfully!"
    echo "🎉 Vox synthesizer is ready to make some music!"
    
    # Show build summary from log
    echo "Build Summary:"
    echo "----------------------------------------"
    grep -E "(\*\* BUILD SUCCEEDED \*\*|Build target|Compile)" "$LOG_FILE" | tail -5
    echo "----------------------------------------"
else
    echo "❌ Build failed with exit code: $result"
    echo "Build Errors:"
    echo "----------------------------------------"
    grep -E "(error: |warning: |\*\* BUILD FAILED \*\*)" "$LOG_FILE" | tail -10
    echo "----------------------------------------"
    echo "Full log available at: $LOG_FILE"
    
    # Check for provisioning issues
    if grep -q "provisioning profile" "$LOG_FILE"; then
        echo ""
        echo "📱 SIGNING SETUP REQUIRED:"
        echo "   Open Vox.xcodeproj in Xcode and set up signing:"
        echo "   1. Select 'Vox' target → Signing & Capabilities"
        echo "   2. Enable 'Automatically manage signing'"
        echo "   3. Select your Team"
        echo "   4. Repeat for 'VoxExtension' and 'VoxCore' targets"
        echo "   5. Then run ./build.sh again"
    fi
fi

# Show the build products location
PRODUCTS_DIR=$(xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" -configuration "$CONFIGURATION" -showBuildSettings | grep -m 1 "BUILT_PRODUCTS_DIR" | awk '{ print $3 }')
echo "Build products available at: $PRODUCTS_DIR"

exit $result
