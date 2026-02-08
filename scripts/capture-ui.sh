#!/bin/bash
# capture-ui.sh — Build, launch, and screenshot the Vox synth UI
# Used by AI agents during UI development for visual feedback.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DERIVED_DATA="$PROJECT_DIR/build"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/Vox.app"

# Defaults
OUTPUT="/tmp/vox-ui.png"
DELAY=5
SEND_MIDI=true
KEEP_APP=false
DO_BUILD=true

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build, launch, and screenshot the Vox synth UI.

Options:
  --output PATH     Screenshot output path (default: /tmp/vox-ui.png)
  --delay SECONDS   Wait time after launch before capture (default: 5)
  --no-midi         Skip sending MIDI test notes
  --keep            Don't kill the app after capture
  --no-build        Skip the xcodebuild step
  -h, --help        Show this help

Examples:
  ./scripts/capture-ui.sh                          # Full pipeline
  ./scripts/capture-ui.sh --no-build --delay 2     # Quick re-capture
  ./scripts/capture-ui.sh --keep --output ui.png   # Leave app running
EOF
    exit 0
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)   OUTPUT="$2"; shift 2 ;;
        --delay)    DELAY="$2"; shift 2 ;;
        --no-midi)  SEND_MIDI=false; shift ;;
        --keep)     KEEP_APP=true; shift ;;
        --no-build) DO_BUILD=false; shift ;;
        -h|--help)  usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Step 1: Build
if $DO_BUILD; then
    echo "▸ Building Vox..."
    cd "$PROJECT_DIR"
    xcodebuild -project Vox.xcodeproj -scheme Vox -configuration Debug \
        -derivedDataPath "$DERIVED_DATA" \
        build 2>&1 | grep -E "error:|warning:|BUILD|^\*\*" || true
    
    if [[ ! -d "$APP_PATH" ]]; then
        echo "✗ Build failed — app not found at $APP_PATH"
        exit 1
    fi
    echo "✓ Build succeeded"
fi

# Step 2: Kill any existing Vox instance
pkill -x Vox 2>/dev/null && sleep 1 || true

# Step 3: Launch the app
echo "▸ Launching Vox..."
open "$APP_PATH"

# Step 4: Bring to foreground via AppleScript
sleep 1
osascript -e 'tell application "Vox" to activate' 2>/dev/null || true

# Step 5: Wait for AU to load
echo "▸ Waiting ${DELAY}s for AU to load..."
sleep "$DELAY"

# Step 6: Send MIDI notes (optional)
if $SEND_MIDI; then
    echo "▸ Sending MIDI test notes..."
    "$SCRIPT_DIR/send-test-midi.sh" 2>/dev/null || echo "  (MIDI send skipped — see scripts/send-test-midi.sh)"
fi

# Step 7: Find window ID
echo "▸ Finding Vox window..."
WINDOW_ID=$(swift -e '
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let owner = w["kCGWindowOwnerName"] as? String ?? ""
    let wid = w["kCGWindowNumber"] as? Int ?? 0
    let layer = w["kCGWindowLayer"] as? Int ?? -1
    if owner == "Vox" && layer == 0 && wid > 0 {
        print(wid)
        break
    }
}
' 2>/dev/null)

if [[ -z "$WINDOW_ID" ]]; then
    echo "✗ Could not find Vox window. Is the app running?"
    echo "  Falling back to full-screen capture..."
    /usr/sbin/screencapture -x "$OUTPUT"
else
    echo "  Window ID: $WINDOW_ID"
    # Step 8: Capture just the Vox window
    /usr/sbin/screencapture -l "$WINDOW_ID" -o -x "$OUTPUT"
fi

echo "✓ Screenshot saved: $OUTPUT"

# Step 9: Optionally kill the app
if ! $KEEP_APP; then
    pkill -x Vox 2>/dev/null || true
    echo "▸ Vox terminated"
fi

echo "$OUTPUT"
