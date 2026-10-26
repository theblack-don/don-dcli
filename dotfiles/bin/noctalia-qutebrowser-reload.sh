#!/usr/bin/env bash
# Reload the qutebrowser config via its IPC socket so it picks up new Noctalia colors.
# Never launches qutebrowser: if no instance is listening, the socket connect fails and we exit.
set -u

IPC_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/qutebrowser"

for socket in "$IPC_DIR"/ipc-*; do
    [ -S "$socket" ] || continue
    if python3 - "$socket" <<'PY'
import json
import os
import socket
import sys

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
try:
    s.settimeout(2)
    s.connect(sys.argv[1])
except OSError:
    sys.exit(1)

try:
    s.sendall((json.dumps({
        "args": [":config-source"],
        "target_arg": "",
        "protocol_version": 1,
        "cwd": os.getcwd(),
    }) + "\n").encode("utf-8"))
finally:
    s.close()
PY
    then
        exit 0
    fi
done

exit 0