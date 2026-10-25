#!/usr/bin/python3
# -*- coding: UTF-8 -*-
"""Give the stock nemo-terminal extension Kitty/Ghostty-style colors.

This is a per-user add-on. Nemo loads the system nemo_terminal extension
first, then this file, which patches NemoTerminal.__init__ to apply a color
scheme after the VTE widget has been created.

Settings live in ~/.config/nemo-terminal/theme.conf:

    source = auto        # auto, kitty, ghostty, gtk, or custom
    file = ~/.config/kitty/themes/noctalia.conf   # for source = custom

The code is intentionally self-contained so it works with the distro package.
"""

import glob
import os


CONFIG_FILE = os.path.join(
    os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
    "nemo-terminal", "theme.conf")

DEFAULT_PALETTE = (
    "#2e3436", "#cc0000", "#4e9a06", "#c4a000",
    "#3465a4", "#75507b", "#06989a", "#d3d7cf",
    "#555753", "#ef2929", "#8ae234", "#fce94f",
    "#729fcf", "#ad7fa8", "#34e2e2", "#eeeeec",
)

THEME_COLOR_KEYS = {
    "foreground": "foreground",
    "background": "background",
    "cursor": "cursor",
    "cursor_color": "cursor",
    "cursor_text": "cursor_text",
    "cursor_text_color": "cursor_text",
    "selection_background": "selection_background",
    "selection_foreground": "selection_foreground",
}


def _xdg_config_home():
    return (os.environ.get("XDG_CONFIG_HOME") or
            os.path.expanduser("~/.config"))


def _read_local_settings():
    settings = {"source": "auto", "file": ""}
    try:
        with open(CONFIG_FILE, encoding="utf-8", errors="replace") as config:
            for raw_line in config:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                key = key.strip().lower()
                value = value.strip().strip("\"'")
                if key in settings:
                    settings[key] = value
    except OSError:
        pass
    return settings


def _kitty_config_file():
    directory = os.environ.get("KITTY_CONFIG_DIRECTORY")
    if directory:
        return os.path.join(os.path.expanduser(directory), "kitty.conf")
    return os.path.join(_xdg_config_home(), "kitty", "kitty.conf")


def _ghostty_config_file():
    directory = os.path.join(_xdg_config_home(), "ghostty")
    for name in ("config", "config.ghostty"):
        path = os.path.join(directory, name)
        if os.path.isfile(path):
            return path
    return os.path.join(directory, "config")


def _theme_key(key):
    key = key.strip().lower().replace("-", "_")
    return THEME_COLOR_KEYS.get(key, key)


def _resolve_theme_path(value, current_file):
    value = os.path.expandvars(os.path.expanduser(value.strip().strip("\"'")))
    if not value:
        return []

    if os.path.isabs(value):
        candidates = [value]
    else:
        candidates = [
            os.path.join(os.path.dirname(current_file), value),
            os.path.join(_xdg_config_home(), "kitty", value),
            os.path.join(_xdg_config_home(), "ghostty", value),
        ]

    for candidate in candidates:
        matches = sorted(glob.glob(candidate))
        if matches:
            return matches
    return []


def _ghostty_theme_files(name):
    name = os.path.expandvars(os.path.expanduser(name.strip()))
    if not name:
        return []
    if os.path.isabs(name) or os.sep in name:
        return [name] if os.path.isfile(name) else []

    directories = [os.path.join(_xdg_config_home(), "ghostty", "themes")]

    data_home = (os.environ.get("XDG_DATA_HOME") or
                 os.path.expanduser("~/.local/share"))
    directories.append(os.path.join(data_home, "ghostty", "themes"))

    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    for data_dir in data_dirs.split(":"):
        directories.append(os.path.join(data_dir, "ghostty", "themes"))

    paths = []
    for directory in directories:
        path = os.path.join(directory, name)
        if os.path.isfile(path) and path not in paths:
            paths.append(path)
    return paths


def _parse_theme_file(path, colors, seen):
    path = os.path.realpath(os.path.expanduser(path))
    if path in seen or not os.path.isfile(path):
        return False
    seen.add(path)

    try:
        with open(path, encoding="utf-8", errors="replace") as theme_file:
            lines = theme_file.readlines()
    except OSError:
        return False

    found = False
    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if "=" in line:
            key, value = line.split("=", 1)
        else:
            parts = line.split(None, 1)
            key = parts[0]
            value = parts[1] if len(parts) > 1 else ""
        key = _theme_key(key)
        value = value.strip()

        if key in ("include", "config_file"):
            for included in _resolve_theme_path(value, path):
                found = _parse_theme_file(included, colors, seen) or found
            continue

        if key == "theme":
            for theme_name in value.split(":"):
                for theme_path in _ghostty_theme_files(theme_name):
                    if _parse_theme_file(theme_path, colors, seen):
                        found = True
                        break
            continue

        if key == "palette":
            index, separator, color = value.partition("=")
            if separator and index.strip().isdigit():
                color_index = int(index.strip())
                if 0 <= color_index < 16:
                    colors["color%d" % color_index] = color.strip()
                    found = True
            continue

        if key.startswith("color") and key[5:].isdigit():
            color_index = int(key[5:])
            if 0 <= color_index < 16:
                colors["color%d" % color_index] = value
                found = True
        elif key in THEME_COLOR_KEYS.values():
            colors[key] = value
            found = True

    return found


def _load_colors(path):
    colors = {}
    if path:
        _parse_theme_file(path, colors, set())
    return colors


def _load_gtk_colors(Gtk):
    window = Gtk.Window()
    context = window.get_style_context()
    foreground = context.get_color(Gtk.StateFlags.NORMAL)
    background = context.get_background_color(Gtk.StateFlags.NORMAL)
    window.destroy()

    colors = {}
    if foreground.alpha > 0:
        colors["foreground"] = foreground.to_string()
    if background.alpha > 0:
        colors["background"] = background.to_string()
    return colors


def get_color_scheme(Gdk, Gtk, scheme, custom_file):
    if scheme == "kitty":
        return _load_colors(_kitty_config_file())
    if scheme == "ghostty":
        return _load_colors(_ghostty_config_file())
    if scheme == "gtk":
        return _load_gtk_colors(Gtk)
    if scheme == "custom":
        return _load_colors(os.path.expanduser(custom_file))

    colors = _load_colors(_kitty_config_file())
    if not colors:
        colors = _load_colors(_ghostty_config_file())
    if not colors:
        colors = _load_gtk_colors(Gtk)
    return colors


def _to_rgba(Gdk, value):
    if isinstance(value, Gdk.RGBA):
        return value
    if not value:
        return None
    value = value.strip()
    if value.lower() in ("none", "transparent"):
        return None
    if len(value) == 9 and value.startswith("#"):
        try:
            color = Gdk.RGBA()
            color.red = int(value[1:3], 16) / 255.0
            color.green = int(value[3:5], 16) / 255.0
            color.blue = int(value[5:7], 16) / 255.0
            color.alpha = int(value[7:9], 16) / 255.0
            return color
        except ValueError:
            return None
    color = Gdk.RGBA()
    return color if color.parse(value) else None


def apply_color_scheme(Gdk, Gtk, term, scheme, custom_file):
    colors = get_color_scheme(Gdk, Gtk, scheme, custom_file)
    if not colors:
        return

    foreground = _to_rgba(Gdk, colors.get("foreground"))
    background = _to_rgba(Gdk, colors.get("background"))
    palette = [_to_rgba(Gdk, colors.get("color%d" % index))
               for index in range(16)]
    if any(palette):
        palette = [color or _to_rgba(Gdk, DEFAULT_PALETTE[index])
                   for index, color in enumerate(palette)]
    else:
        palette = None

    term.set_colors(foreground, background, palette)

    cursor = _to_rgba(Gdk, colors.get("cursor"))
    if cursor is not None:
        term.set_color_cursor(cursor)

    cursor_text = _to_rgba(Gdk, colors.get("cursor_text"))
    if cursor_text is not None:
        term.set_color_cursor_foreground(cursor_text)

    selection_background = _to_rgba(Gdk, colors.get("selection_background"))
    if selection_background is not None:
        term.set_color_highlight(selection_background)

    selection_foreground = _to_rgba(Gdk, colors.get("selection_foreground"))
    if selection_foreground is not None:
        term.set_color_highlight_foreground(selection_foreground)


def _install():
    import nemo_terminal

    if getattr(nemo_terminal, "_nemo_terminal_theme_patched", False):
        return

    # If the system copy already has the built-in theming patch, do nothing.
    if hasattr(nemo_terminal, "apply_color_scheme"):
        return

    from gi.repository import Gdk, Gtk

    env_source = os.environ.get("NEMO_TERMINAL_THEME_SOURCE")
    env_file = os.environ.get("NEMO_TERMINAL_THEME_FILE")

    original_init = nemo_terminal.NemoTerminal.__init__

    def themed_init(self, *args, **kwargs):
        original_init(self, *args, **kwargs)
        try:
            local_settings = _read_local_settings()
            source = env_source or local_settings["source"]
            theme_file = env_file or local_settings["file"]
            apply_color_scheme(Gdk, Gtk, self.term, source, theme_file)
        except Exception as error:
            print("[Nemo Terminal Theme] Could not apply colors: %s" % error)

    nemo_terminal.NemoTerminal.__init__ = themed_init
    nemo_terminal._nemo_terminal_theme_patched = True

    if os.environ.get("NEMO_TERMINAL_THEME_DEBUG"):
        local_settings = _read_local_settings()
        print("[Nemo Terminal Theme] Using scheme '%s' from %s"
              % (env_source or local_settings["source"],
                 env_file or local_settings["file"] or "auto-detected config"))


try:
    _install()
except Exception as error:
    print("[Nemo Terminal Theme] Failed to initialize: %s" % error)
