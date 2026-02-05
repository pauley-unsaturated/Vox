#!/bin/bash
# test.sh - Run the tests for the Vox synthesizer plugin

# Script configuration
PROJECT_NAME="Vox"
TEST_SCHEME_NAME="Vox"
BUILD_DIR="build"
CONFIGURATION="Debug"

# Check for Xcode command line tools
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Please install Xcode command line tools."
    exit 1
fi

echo "Running tests for $PROJECT_NAME..."

# Create logs directory if it doesn't exist
mkdir -p "$BUILD_DIR/logs"

# Run the tests and save output to log file
LOG_FILE="$BUILD_DIR/logs/test-$(date +%Y%m%d-%H%M%S).log"
echo "Test log will be saved to: $LOG_FILE"

# Run tests and capture output to log file with progress dots
echo -n "Running tests"

# Start tests in background and capture output
xcodebuild \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$TEST_SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR" \
  test > "$LOG_FILE" 2>&1 &

# Get the background process ID
TEST_PID=$!

# Show progress dots while testing
while kill -0 $TEST_PID 2>/dev/null; do
    echo -n "."
    sleep 2
done

# Wait for tests to complete and get result
wait $TEST_PID
result=$?

echo "" # New line after dots

if [[ $result -eq 0 ]]; then
    echo "✅ Tests completed successfully!"
    echo "🎵 All systems go! Your synthesizer is rock solid! 🎵"
    
    # Show test summary from log (new Swift test output format)
    echo ""
    echo "Test Summary:"
    echo "----------------------------------------"
    # Look for the new format: "Test run with N tests in M suites passed"
    grep -E "Test run with.*tests in.*suites" "$LOG_FILE"
    echo ""
    # Show suite breakdown
    grep -E "^✔ Suite.*passed" "$LOG_FILE"
    echo "----------------------------------------"
else
    echo "❌ Tests failed with exit code: $result"
    echo ""
    echo "Failed Tests:"
    echo "----------------------------------------"
    # Look for failed suites and individual test failures
    grep -E "(^✘|failed|FAIL|\*\* TEST FAILED \*\*)" "$LOG_FILE" | head -20
    echo "----------------------------------------"
    echo ""
    echo "Full log available at: $LOG_FILE"
fi

exit $result
