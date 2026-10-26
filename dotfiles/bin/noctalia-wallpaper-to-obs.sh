#!/usr/bin/env bash
set -euo pipefail

SETTINGS_FILE="$HOME/.local/state/noctalia/settings.toml"
TARGET_DIR="$HOME/BlackDon/OBS Assets/CurrentWall"
TARGET_FILE="$TARGET_DIR/current-wallpaper.png"

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "Settings file not found: $SETTINGS_FILE" >&2
    exit 1
fi

wallpaper_path=$(grep -A 1 '^[[:space:]]*\[wallpaper\.last\]' "$SETTINGS_FILE" | grep '^[[:space:]]*path' | sed 's/^[[:space:]]*path = "\(.*\)"$/\1/')

if [[ -z "$wallpaper_path" ]]; then
    echo "Could not extract wallpaper path from settings" >&2
    exit 1
fi

if [[ ! -f "$wallpaper_path" ]]; then
    echo "Wallpaper file not found: $wallpaper_path" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

# Write to a temp file and atomically move it into place so OBS never
# reads a partially-written image (which breaks its file-change reload).
tmp_file="$TARGET_DIR/.current-wallpaper.tmp.png"
trap 'rm -f "$tmp_file"' EXIT
magick "$wallpaper_path" -resize 3440x1440^ -gravity center -extent 3440x1440 "$tmp_file"
mv -f "$tmp_file" "$TARGET_FILE"
trap - EXIT

# Force OBS to reload the image via obs-websocket so it updates even if
# OBS's own file-change detection misses or drops the change.
python3 - "$TARGET_FILE" <<'PY' || echo "WARNING: could not force OBS reload (OBS not running?)" >&2
import asyncio, json, sys
import websockets

async def main():
    async with websockets.connect("ws://127.0.0.1:4455", open_timeout=2, close_timeout=1) as ws:
        await ws.recv()  # Hello
        await ws.send(json.dumps({"op": 1, "d": {"rpcVersion": 1}}))
        await ws.recv()  # Identified
        await ws.send(json.dumps({
            "op": 6,
            "d": {
                "requestType": "SetInputSettings",
                "requestId": "reload-currentwall",
                "requestData": {
                    "inputName": "currentwall1",
                    "inputSettings": {"file": sys.argv[1]},
                },
            },
        }))
        resp = json.loads(await asyncio.wait_for(ws.recv(), 3))
        status = resp["d"]["requestStatus"]
        if not status.get("result"):
            raise RuntimeError(status.get("comment"))

asyncio.run(main())
PY

echo "Copied and resized wallpaper to OBS: $TARGET_FILE"
