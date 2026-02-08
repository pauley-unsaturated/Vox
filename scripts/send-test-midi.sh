#!/bin/bash
# send-test-midi.sh — Send test MIDI notes to the Vox app
# Uses sendmidi (brew install gbevin/tools/sendmidi)
set -euo pipefail

SENDMIDI="/opt/homebrew/bin/sendmidi"

if [[ ! -x "$SENDMIDI" ]]; then
    echo "✗ sendmidi not found. Install: brew install gbevin/tools/sendmidi"
    exit 1
fi

# Find a MIDI device that looks like Vox or use IAC
VOX_PORT=""
while IFS= read -r dev; do
    if [[ "$dev" == *Vox* ]] || [[ "$dev" == *vox* ]]; then
        VOX_PORT="$dev"
        break
    fi
done < <($SENDMIDI list 2>/dev/null)

# Fallback to IAC Driver if Vox port not found
if [[ -z "$VOX_PORT" ]]; then
    while IFS= read -r dev; do
        if [[ "$dev" == *IAC* ]]; then
            VOX_PORT="$dev"
            break
        fi
    done < <($SENDMIDI list 2>/dev/null)
fi

if [[ -z "$VOX_PORT" ]]; then
    echo "✗ No Vox or IAC MIDI port found."
    echo "  Available devices:"
    $SENDMIDI list
    echo ""
    echo "  Enable 'IAC Driver' in Audio MIDI Setup if needed."
    exit 1
fi

echo "▸ Sending MIDI to: $VOX_PORT"

# Send a C major chord: C3 E3 G3
$SENDMIDI dev "$VOX_PORT" on 60 100
$SENDMIDI dev "$VOX_PORT" on 64 80
$SENDMIDI dev "$VOX_PORT" on 67 90

# Hold for 2 seconds (so scopes/meters have data to display)
sleep 2

# Note offs
$SENDMIDI dev "$VOX_PORT" off 60 0
$SENDMIDI dev "$VOX_PORT" off 64 0
$SENDMIDI dev "$VOX_PORT" off 67 0

# Short pause for release tail
sleep 0.5

echo "✓ MIDI test pattern sent"
