#!/usr/bin/env bash
# Reload Konsole colorscheme after Noctalia updates it.
set -euo pipefail

COLORSCHEME_NAME="Noctalia"
PROFILE_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/konsole/Main.profile"

# 1. Ensure the Main.profile uses the Noctalia colorscheme so new windows pick it up.
if [ -f "$PROFILE_FILE" ]; then
    if ! grep -q "ColorScheme=$COLORSCHEME_NAME" "$PROFILE_FILE"; then
        sed -i "s/^ColorScheme=.*/ColorScheme=$COLORSCHEME_NAME/" "$PROFILE_FILE"
    fi
fi

# 2. Send OSC 50 to every running Konsole tab so they switch live.
for konsole_pid in $(pgrep -x konsole 2>/dev/null || true); do
    for pts in $(ls -l "/proc/$konsole_pid/fd" 2>/dev/null | grep -oP '/dev/pts/\d+' | sort -u || true); do
        if [ -w "$pts" ]; then
            printf '\033]50;ColorScheme=%s\a' "$COLORSCHEME_NAME" > "$pts" 2>/dev/null || true
        fi
    done
done
