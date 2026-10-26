#!/usr/bin/env bash
set -euo pipefail

TARGET_FILE="$HOME/.local/state/noctalia/settings.toml"
SCRIPT="$HOME/bin/noctalia-wallpaper-to-obs.sh"

# Run once immediately on startup so OBS starts with the correct wallpaper
if [[ -x "$SCRIPT" ]]; then
    "$SCRIPT"
else
    echo "ERROR: wallpaper script not found or not executable: $SCRIPT" >&2
    exit 1
fi

# Watch the settings file for changes and re-run the sync script
while true; do
    if ! command -v inotifywait &>/dev/null; then
        echo "ERROR: inotifywait is not installed" >&2
        exit 1
    fi

    if [[ ! -f "$TARGET_FILE" ]]; then
        echo "WARNING: $TARGET_FILE does not exist, waiting..." >&2
        sleep 5
        continue
    fi

    # Wait for the file to be modified (attrib catches chmod, move_self catches renames)
    if inotifywait -q -e modify,attrib,move_self,close_write "$TARGET_FILE"; then
        sleep 0.2  # Small debounce so the file is fully written
        "$SCRIPT"
    fi
done
