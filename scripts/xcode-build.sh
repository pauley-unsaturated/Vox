#!/bin/bash
# xcode-build.sh — Serialized Xcode MCP build with lock
# Usage: ./scripts/xcode-build.sh [build|test|test-some "target/id"]
set -euo pipefail

LOCKFILE="/tmp/vox-xcode-build.lock"
TAB="windowtab1"
ACTION="${1:-build}"
shift || true

acquire_lock() {
    local waited=0
    while ! (set -o noclobber; echo $$ > "$LOCKFILE") 2>/dev/null; do
        local holder=$(cat "$LOCKFILE" 2>/dev/null || echo "unknown")
        if [ $waited -eq 0 ]; then
            echo "⏳ Build queue: waiting (held by pid $holder)..." >&2
        fi
        sleep 3
        waited=$((waited + 3))
        # Steal lock if holder is dead
        if ! kill -0 "$holder" 2>/dev/null; then
            echo "🔓 Stale lock from dead pid $holder, stealing" >&2
            rm -f "$LOCKFILE"
        fi
        if [ $waited -gt 300 ]; then
            echo "❌ Timed out waiting for build lock after 5min" >&2
            exit 1
        fi
    done
    trap 'rm -f "$LOCKFILE"' EXIT
    echo "🔒 Build lock acquired (pid $$)" >&2
}

acquire_lock

case "$ACTION" in
    build)
        echo "🔨 Building..." >&2
        mcporter call xcode.BuildProject tabIdentifier="$TAB" 2>&1
        ;;
    test)
        echo "🧪 Running all tests..." >&2
        mcporter call xcode.RunAllTests tabIdentifier="$TAB" 2>&1
        ;;
    test-some)
        echo "🧪 Running specific tests..." >&2
        mcporter call xcode.RunSomeTests tabIdentifier="$TAB" tests="$*" 2>&1
        ;;
    log)
        mcporter call xcode.GetBuildLog tabIdentifier="$TAB" 2>&1
        ;;
    *)
        echo "Unknown action: $ACTION" >&2
        exit 1
        ;;
esac
