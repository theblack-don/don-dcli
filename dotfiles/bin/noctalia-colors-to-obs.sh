#!/usr/bin/env bash
# Regenerate the OBS background image from the active Noctalia surface-variant color.
# Usage: noctalia-colors-to-obs.sh [RRGGBB]
set -euo pipefail

TARGET_DIR="$HOME/BlackDon/OBS Assets/CurrentWall"
TARGET_FILE="$TARGET_DIR/currentbackground.png"
COLOR_FILE="$HOME/.local/state/noctalia-obs/surface-variant.hex"
SIZE="3440x1440"

color="${1:-}"
if [[ -z "$color" && -f "$COLOR_FILE" ]]; then
    color=$(tr -d '[:space:]#' < "$COLOR_FILE")
fi
color="${color#\#}"

if [[ ! "$color" =~ ^[0-9a-fA-F]{6}$ ]]; then
    echo "Invalid or missing surface variant color (got: '$color')" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

# Write to a temp file and atomically move it into place so OBS never
# reads a partially-written image (which breaks its file-change reload).
tmp_file="$TARGET_DIR/.currentbackground.tmp.png"
trap 'rm -f "$tmp_file"' EXIT
magick -size "$SIZE" "xc:#$color" -depth 8 "$tmp_file"
mv -f "$tmp_file" "$TARGET_FILE"
trap - EXIT

# Force OBS to reload every image source that uses this file via
# obs-websocket so it updates even if OBS's own file-change detection
# misses or drops the change. Matches sources by file path, so renamed
# or duplicated sources keep working.
python3 - "$TARGET_FILE" <<'PY' || echo "WARNING: could not force OBS reload (OBS not running?)" >&2
import asyncio, json, sys
import websockets

target = sys.argv[1]

async def req(ws, request_type, request_data, counter):
    counter[0] += 1
    await ws.send(json.dumps({
        "op": 6,
        "d": {
            "requestType": request_type,
            "requestId": f"{request_type}-{counter[0]}",
            "requestData": request_data,
        },
    }))
    resp = json.loads(await asyncio.wait_for(ws.recv(), 3))
    status = resp["d"]["requestStatus"]
    if not status.get("result"):
        raise RuntimeError(status.get("comment"))
    return resp["d"].get("responseData", {})

async def main():
    counter = [0]
    async with websockets.connect("ws://127.0.0.1:4455", open_timeout=2, close_timeout=1) as ws:
        await ws.recv()  # Hello
        await ws.send(json.dumps({"op": 1, "d": {"rpcVersion": 1}}))
        await ws.recv()  # Identified

        data = await req(ws, "GetInputList", {}, counter)
        reloaded = []
        for inp in data.get("inputs", []):
            if inp.get("inputKind") != "image_source":
                continue
            name = inp["inputName"]
            try:
                settings = await req(ws, "GetInputSettings", {"inputName": name}, counter)
            except RuntimeError:
                continue
            if settings.get("inputSettings", {}).get("file") != target:
                continue
            await req(ws, "SetInputSettings",
                      {"inputName": name, "inputSettings": {"file": target}}, counter)
            reloaded.append(name)
        if reloaded:
            print("Reloaded OBS inputs: " + ", ".join(reloaded))

asyncio.run(main())
PY

echo "Updated OBS background: $TARGET_FILE (#$color)"
