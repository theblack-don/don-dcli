# don-dcli

My personal [dcli](https://github.com/theblackdon/dcli) config. The primary
machine is `nixnix`, a NixOS workstation using dcli's NixOS integration (Nix
profile apps, no Home Manager). The older Fedora and PikaOS hosts are kept here
for the other machines.

| Hostname | Machine | Config |
|---|---|---|
| `nixnix` | NixOS workstation, primary | `hosts/nixnix.nix` |
| `fednix` | Fedora desktop (AMD) | `hosts/fednix.nix` |
| `fednixgaming` | Fedora gaming desktop (NVIDIA) | `hosts/fednixgaming.nix` |
| `piknix` | PikaOS (Debian/apt) on second NVMe | `hosts/piknix.nix` |

`config.nix` picks `hosts/<hostname>.nix` automatically, so the machine's
hostname must match the file name.

## nixnix (NixOS)

`hosts/nixnix.nix` is the main config. `nixos_enabled = true`, so `dcli sync`
converges the user profile and then finishes with `nixos-rebuild switch`. Home
Manager and dcli's flake mode are off.

- `module_processing = "sequential"` so the `kineticwe-dev` hook runs as the
  user, not via sudo.
- Enabled modules: `kineticwe-dev`, `flatpak`, `nixnix-dots`.
- User apps come from `nix_packages` and are installed with `nix profile`.
- dcli generates `nixos/dcli-system.nix` and `nixos/dcli-inputs.nix`. They are
  imported from `/etc/nixos/configuration.nix`:

  ```nix
  imports = [ /home/don/.config/dcli/nixos/dcli-system.nix ];
  ```

  Do not hand-edit the generated files. Host-level NixOS settings belong in the
  `nixos.config` block in `hosts/nixnix.nix`.

### Dotfiles

`modules/nixnix-dots/module.nix` uses explicit `dotfiles` mappings, not
`dotfiles_sync`. It symlinks static config into `~/.config` only; runtime state,
logs, databases, tokens and stream keys stay in the live directories and out of
git.

Managed: fastfetch, fish, ghostty, kitty, qutebrowser static config, Nemo
bookmarks, Firebot static config, OBS profiles/themes, noctalia, noctalia-kwe,
kineticwe static files, zed, tuios, veadotube, and fifine-control-deck.

If an app replaces a managed file symlink, restore it with
`dcli sync --force-dotfiles`. Nemo preferences live in dconf and are not managed.

`dcli sync --dry-run` skips dotfile sync, so it is not a useful preview for
dotfile changes.

## New NixOS machine

Short version of `~/Projects/dcli/docs/NIXOS-MIGRATION.md`; read the runbook for
the full install.

1. Install NixOS. Keep the existing `/home` mounted but do not format it.
2. Enable flakes in `/etc/nixos/configuration.nix`:

   ```nix
   nix.settings.experimental-features = [ "nix-command" "flakes" ];
   ```

3. Set the hostname and clone this repo:

   ```bash
   sudo hostnamectl set-hostname nixnix
   git clone https://github.com/theblack-don/don-dcli.git ~/.config/dcli
   ```

4. Install `dcli`. If `~/Projects/dcli` is not present, clone
   `https://gitlab.com/theblackdon/dcli` there first, then build it as shown in
   the runbook and run `dcli init --nixos`.
5. Add the generated import to `/etc/nixos/configuration.nix`:

   ```nix
   imports = [ /home/don/.config/dcli/nixos/dcli-system.nix ];
   ```

6. Validate and sync, then reboot once for greeter/session changes:

   ```bash
   cd ~/.config/dcli
   dcli validate
   dcli sync
   ```

## Daily use

```bash
$EDITOR hosts/$(hostname).nix    # or modules/*/module.nix

dcli validate
dcli sync --no-system            # apply profile/dotfiles, skip nixos-rebuild
dcli sync                        # full sync, ends with nixos-rebuild switch

git add -A && git commit -m "..." && git push
```

On another machine: `git pull && dcli sync`.

## Other hosts

`fednix` and `fednixgaming` are Fedora desktops (dnf/COPR), and `piknix` is
PikaOS with apt on a second NVMe. They are kept for the older machines and are
not the primary setup.

## Notes

- Never hand-edit `state/`, `nixos/dcli-system.nix`, or `nixos/dcli-inputs.nix`.
- dcli owns `~/.local/bin/*` wrappers and
  `~/.local/share/applications/*.desktop` overrides. Change the Nix files
  instead; the generated files are replaced on every sync.
- `nixnix` is AMD. NVIDIA driver protection is only enabled on `fednixgaming`.
- `config_backups` is disabled on `nixnix` so ignored dotfile state and secrets
  are not pulled into a config archive.
