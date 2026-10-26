# Personal dotfiles

Source of truth for the dotfiles managed by the `dotfiles` dcli module.

## Layout

- `dotfiles/` (repo root) — the actual files.
- `modules/dotfiles/module.nix` — explicit source → target mappings.
- dcli symlinks each target into place on `dcli sync`; it does not copy.
- The first sync backs up any existing target as
  `<name>.backup.<timestamp>` next to the original.

Explicit mappings are used instead of `dotfiles_sync` because the source of
truth is the top-level `dotfiles/` directory, not a module-local
`modules/dotfiles/dotfiles/` directory. Explicit mappings also cover targets
outside `~/.config` and keep OBS/Firebot caches and logs out of the repo.

## What is managed

| Source | Target |
|---|---|
| `dotfiles/kitty` | `~/.config/kitty` |
| `dotfiles/fish` | `~/.config/fish` |
| `dotfiles/fastfetch` | `~/.config/fastfetch` |
| `dotfiles/ghostty` | `~/.config/ghostty` |
| `dotfiles/nemo/bookmark-metadata` | `~/.config/nemo/bookmark-metadata` |
| `dotfiles/nemo-terminal` | `~/.config/nemo-terminal` |
| `dotfiles/noctalia-kwe` | `~/.config/noctalia-kwe` |
| `dotfiles/kineticwe` | `~/.config/kineticwe` |
| `dotfiles/bin/firebot-command` | `~/.local/bin/firebot-command` |
| `dotfiles/bin/veado-set` | `~/.local/bin/veado-set` |
| `dotfiles/fifine-control-deck/config.json` | `~/.config/fifine-control-deck/config.json` |
| `dotfiles/bin/noctalia-colors-to-obs.sh` | `~/bin/noctalia-colors-to-obs.sh` |
| `dotfiles/bin/noctalia-wallpaper-to-obs.sh` | `~/bin/noctalia-wallpaper-to-obs.sh` |
| `dotfiles/bin/obs-wallpaper-watcher.sh` | `~/bin/obs-wallpaper-watcher.sh` |
| `dotfiles/bin/noctalia-konsole-reload.sh` | `~/bin/noctalia-konsole-reload.sh` |
| `dotfiles/bin/noctalia-qutebrowser-reload.sh` | `~/bin/noctalia-qutebrowser-reload.sh` |
| `dotfiles/systemd/user/obs-wallpaper-sync.service` | `~/.config/systemd/user/obs-wallpaper-sync.service` |
| `dotfiles/nemo/bookmarks` | `~/.config/gtk-3.0/bookmarks` |
| `dotfiles/nemo-python/extensions/nemo_terminal_theme.py` | `~/.local/share/nemo-python/extensions/nemo_terminal_theme.py` |
| `dotfiles/obs-studio/global.ini` | `~/.var/app/com.obsproject.Studio/config/obs-studio/global.ini` |
| `dotfiles/obs-studio/user.ini` | `~/.config/obs-studio/user.ini` |
| `dotfiles/obs-studio/basic` | `~/.config/obs-studio/basic` |
| `dotfiles/obs-studio/plugin_config/aitum-multistream` | `~/.var/app/com.obsproject.Studio/config/obs-studio/plugin_config/aitum-multistream` |
| `dotfiles/obs-studio/plugin_config/obs-websocket` | `~/.var/app/com.obsproject.Studio/config/obs-studio/plugin_config/obs-websocket` |
| `dotfiles/obs-studio/plugin_config/vertical-canvas` | `~/.var/app/com.obsproject.Studio/config/obs-studio/plugin_config/vertical-canvas` |
| `dotfiles/Firebot/v5/profiles/Main` | `~/.config/Firebot/v5/profiles/Main` |
| `dotfiles/Firebot/v5/global-settings.json` | `~/.config/Firebot/v5/global-settings.json` |
| `dotfiles/Firebot/v5/overlay.html` | `~/.config/Firebot/v5/overlay.html` |
| `dotfiles/Firebot/v5/overlay-resources` | `~/.config/Firebot/v5/overlay-resources` |

## Stream deck scripts

`firebot-command` and `veado-set` are the two helpers used by the fifine
Control Deck buttons (and by `Meta+Shift+F` for Firebot). dcli symlinks them
into `~/.local/bin`, so a new machine gets them on `dcli sync`; there is no
separate install step. Both need Python 3, and `firebot-command` optionally
uses `notify-send` for errors.

`firebot-command` talks to Firebot's local REST API on `127.0.0.1:7472`, so
Firebot must be running. `veado-set` discovers the veadotube mini server from
`~/.veadotube/instances/*`.

The deck config is live application state: if the deck app rewrites
`config.json` via a temp-file rename, it replaces the dcli symlink. Copy the
new file back into `dotfiles/fifine-control-deck/config.json` and rerun
`dcli sync --force-dotfiles`.

## Noctalia/OBS helpers

`noctalia-colors-to-obs.sh`, `noctalia-wallpaper-to-obs.sh`, and
`obs-wallpaper-watcher.sh` keep the OBS background image in sync with Noctalia
themes and wallpapers. `noctalia-konsole-reload.sh` and
`noctalia-qutebrowser-reload.sh` refresh those apps after a palette change.
The first two are wired from `dotfiles/noctalia-kwe/config.toml` as template
post-hooks.

Runtime dependencies: ImageMagick (`magick`), Python 3 with `websockets` for
the OBS websocket reload, and `inotify-tools` (`inotifywait`) for the watcher.
dcli only symlinks the service; enable it per machine:

```bash
systemctl --user daemon-reload
systemctl --user enable --now obs-wallpaper-sync.service
```

`dotfiles/nemo/dconf.ini` is a reference export of the Nemo dconf settings.
It is not applied automatically. Restore it manually with:

```bash
dconf load /org/nemo/ < dotfiles/nemo/dconf.ini
```

## Secrets

These files are copied locally so the symlinked apps keep working, but
`dotfiles/.gitignore` prevents a normal `git add` from committing them:

- `obs-studio/basic/profiles/*/service.json` — OBS stream keys
- `obs-studio/plugin_config/aitum-multistream/config.json` — Aitum stream keys
- `obs-studio/plugin_config/obs-websocket/config.json` — OBS websocket password
- `Firebot/v5/profiles/Main/auth-twitch.json` — Twitch OAuth tokens
- `Firebot/v5/profiles/Main/integrations.json` — OBS websocket password

After cloning to a new machine, re-enter/re-auth these. Do not use
`git add -f` on them.

OBS scenes intentionally include overlay widget URLs/tokens because this is a
private repo and they are required for the alerts to work.

## OBS Studio (Flatpak)

OBS is the Flatpak build. Its `global.ini` sets
`[Locations] Configuration=/home/don/.config`, so `user.ini` and `basic/` live
in `~/.config/obs-studio`, while `global.ini` and `plugin_config/` live in
`~/.var/app/com.obsproject.Studio/config/obs-studio`.

OBS may replace the `global.ini` or `user.ini` symlink when it rewrites the
file. If that happens, rerun `dcli sync --force-dotfiles`; the copy in
`dotfiles/obs-studio` is the backup. After closing OBS, refresh the host
`user.ini` copy before syncing if OBS changed it:

```bash
cp ~/.config/obs-studio/user.ini dotfiles/obs-studio/user.ini
```

OBS 33 removed the `gs_image_file_init` symbol. Advanced Masks is
intentionally not installed: the current Flathub build (1.5.4) still uses the
removed symbol. Upstream 1.6.1 exists, but it is not packaged as a Flatpak
extension yet. The other installed OBS Flatpak plugin extensions are
ABI-compatible with OBS 33.

The OBS plugin extensions are installed system-wide because dcli's Flatpak
tracking only lists apps, not extensions:

```bash
flatpak install --system -y flathub \
  com.obsproject.Studio.Plugin.HtmlSource \
  com.obsproject.Studio.Plugin.OBSVkCapture \
  com.obsproject.Studio.Plugin.Gstreamer \
  com.obsproject.Studio.Plugin.GStreamerVaapi \
  com.obsproject.Studio.Plugin.OBSPWVideo \
  com.obsproject.Studio.Plugin.WebSocket
```

## BlackDon

`dotfiles/BlackDon/` is a snapshot for version control, not a dcli target.
Symlinking it would move the 16 GB of videos out of `~/BlackDon` and break
OBS's recording path. Videos are ignored; empty directories are kept with
`.gitkeep` files. To restore the snapshot:

```bash
rsync -a --exclude='.gitkeep' dotfiles/BlackDon/ ~/BlackDon/
```

## First sync

Close OBS, Firebot, the fifine Control Deck app, and terminals before running
`dcli sync`. Then:

```bash
dcli validate
dcli sync --dry-run
dcli sync
```

Fish completions and `fish_variables` are intentionally not managed; they are
generated by the shell and packages. Kitty/Firebot/OBS backups and caches are
excluded as well.
