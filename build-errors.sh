#!/bin/bash
# Build script that only outputs errors (keeps context small)
cd "$(dirname "$0")"
xcodebuild -project Vox.xcodeproj -scheme Vox -configuration Debug build 2>&1 | grep -E "error:|fatal error:|undefined|cannot find|no such module" | head -50
