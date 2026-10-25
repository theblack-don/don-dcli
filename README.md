# don-dcli

My personal [dcli](https://github.com/theblackdon/dcli) config for Fedora
machines. Nix profile mode, no Home Manager.

| Hostname | Machine | Config |
|---|---|---|
| `fednix` | desktop | `hosts/fednix.nix` |
| `fednix-lap` | laptop | `hosts/fednix-lap.nix` |

`config.nix` picks `hosts/<hostname>.nix` automatically, so the machine's
hostname must match the file name.

## New machine

Assumes a fresh Fedora install and that your GitLab SSH key is already set up.

### 1. dcli and basics

```bash
sudo dnf install git flatpak fzf xdg-utils
sudo dnf copr enable theblackdon/dcli
sudo dnf install dcli
```

### 2. Nix

```bash
sudo dnf install nix nix-daemon libgit2
sudo systemctl enable --now nix-daemon
echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
nix-channel --update
```

Log out and back in if `nix` is not on `PATH`.

### 3. Clone this config

```bash
git clone git@gitlab.com:theblackdon/don-dcli.git ~/.config/dcli
```

If `dcli init` already created that directory, move it aside first
(`mv ~/.config/dcli ~/.config/dcli.bak`).

### 4. Set the hostname

```bash
hostnamectl set-hostname fednix-lap
```

The hostname must match a file in `hosts/`. Otherwise add a new
`hosts/<hostname>.nix` and sync from there.

### 5. Check and apply

```bash
cd ~/.config/dcli
dcli validate
dcli sync --dry-run
dcli sync
```

Flatpaks are installed system-wide (`flatpak_scope = "system"`), so Flathub
must exist as a system remote.

## Daily use

```bash
$EDITOR hosts/$(hostname).nix    # or modules/*.nix

dcli validate
dcli sync --dry-run
dcli sync

git add -A && git commit -m "..." && git push
```

On another machine: `git pull && dcli sync`.

## Notes

- Never hand-edit `state/`; it is machine-local and gitignored.
- dcli owns `~/.local/bin/*` wrappers and
  `~/.local/share/applications/*.desktop` overrides. They are regenerated on
  every sync, so change the Nix files instead.
- Both hosts enable NVIDIA driver protection. After a kernel update, `dcli
  sync` checks driver/kernel sync and rebuilds the module; wait for the
  notification before rebooting.
- `kineticwe-dev` is disabled on the desktop: the nix runtime plus NVIDIA
  proprietary EGL breaks on Fedora. Not enabled on the laptop either.
