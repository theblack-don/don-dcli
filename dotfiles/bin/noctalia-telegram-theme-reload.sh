#!/usr/bin/env bash
# Reapply the rendered Noctalia palette to Telegram Desktop.
#
# Noctalia's template engine opens the output with truncation before writing.
# Telegram Desktop watches the applied theme file with QFileSystemWatcher, so it
# can observe the file while it is empty and skip the update. Rewriting the
# already rendered content without truncating gives the watcher a complete file
# to read.

set -euo pipefail

theme="${XDG_CONFIG_HOME:-$HOME/.config}/telegram-desktop/themes/noctalia.tdesktop-theme"
[[ -f "$theme" ]] || exit 0

python3 - "$theme" <<'PY'
import os
import sys

path = sys.argv[1]
with open(path, "rb") as f:
    data = f.read()

fd = os.open(path, os.O_WRONLY)  # no O_TRUNC on purpose
try:
    view = memoryview(data)
    while view:
        written = os.write(fd, view)
        view = view[written:]
    os.ftruncate(fd, len(data))
finally:
    os.close(fd)
PY
