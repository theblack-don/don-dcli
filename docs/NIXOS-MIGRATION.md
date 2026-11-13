# NixOS Migration Runbook: reuse the existing `/home`

This runbook moves the machine from the current pikaos/fedora dual-boot to a
single NixOS install **without touching the home partition**. The dcli config,
the KineticWE checkout, dotfiles and all user data ride along in `/home`.

Facts recorded from the current machine (verify before wiping anything!):

| What | Value |
|---|---|
| Home partition | `/dev/nvme0n1p5`, ext4, **UUID `77f92884-5ae7-4862-b631-4d52f5219575`** |
| Games partition (optional) | `/dev/nvme0n1p6`, ext4, UUID `934efd0f-ba2a-4eca-94bd-ff73642471e8` |
| EFI system partition | `/dev/nvme0n1p1`, vfat, UUID `32BE-AF3A` (600M) |
| Old roots to wipe | `nvme0n1p3` (btrfs, fedora), `nvme0n1p7` (btrfs, pikaos) |
| Old boot partition | `nvme0n1p4` (ext4, 2G) — reusable for NixOS `/boot` |
| User | `don`, uid **1000**, gid **1000**, group 27 (`sudo` → NixOS `wheel`) |
| Current hostname | `piknix`; the new host file is `hosts/nixnix.nix` |

> **Never format `nvme0n1p5`.** All commands below assume it is mounted at
> `/home` with its contents intact.

---

## 1. Before you start (still on piknix)

1. **Push the dcli config** — it is a git repo in `~/.config/dcli`:

   ```bash
   cd ~/.config/dcli
   dcli repo push
   ```

2. **Record an inventory** (optional, for reference):

   ```bash
   dpkg --get-selections > ~/pikaos-packages.txt
   flatpak list > ~/flatpak-packages.txt
   ```

3. **Note the UUIDs again** (they are also listed above):

   ```bash
   lsblk -o NAME,FSTYPE,UUID,MOUNTPOINTS
   ```

4. **Housekeeping** (saves space and avoids stale state on first boot):

   ```bash
   # Distrobox containers are not needed on NixOS
   distrobox rm kineticwe-build 2>/dev/null || true
   # Fedora leftovers from the old kineticwe-dev flow
   ls ~/.local/bin/*.pre-nix 2>/dev/null   # delete manually if present
   ```

5. **Keep the dcli config and the KineticWE checkout** in `/home` — they are
   the inputs for everything after the install.

## 2. Install NixOS (live USB)

1. Boot the NixOS installer. Use manual partitioning:
   - **EFI** `nvme0n1p1` → mount at `/boot` (NixOS uses systemd-boot; the old
     loaders are replaced). Formatting it is optional — keep it if you want to
     preserve other boot entries until cleanup.
   - **NixOS root** — pick one of the freed partitions (`nvme0n1p3` or `p7`) or
     `nvme0n1p4`; format it (ext4 or btrfs).
   - **Home** `nvme0n1p5` → mount at `/home`, **no format**.
   - **Games** `nvme0n1p6` → mount at `/mnt/games` (optional), no format.
2. Let the installer generate `configuration.nix` + `hardware-configuration.nix`.
3. Before the first rebuild, edit `/etc/nixos/configuration.nix` and add:

   ```nix
   networking.hostName = "nixnix";

   users.users.don = {
     uid = 1000;                 # MUST match the home partition ownership
     isNormalUser = true;
     extraGroups = [ "wheel" "networkmanager" ];
   };

   # The installer writes fileSystems."/home" if it was mounted during
   # install. Verify it exists and uses the by-UUID path:
   fileSystems."/home" = {
     device = "/dev/disk/by-uuid/77f92884-5ae7-4862-b631-4d52f5219575";
     fsType = "ext4";
   };

   # Optional games partition
   fileSystems."/mnt/games" = {
     device = "/dev/disk/by-uuid/934efd0f-ba2a-4eca-94bd-ff73642471e8";
     fsType = "ext4";
   };

   # Match the previous zram swap setup
   zramSwap.enable = true;

   # Required: flake installs and builtins.getFlake in the generated module.
   nix.settings.experimental-features = [ "nix-command" "flakes" ];

   # Leave this commented until dcli has generated the file (step 4):
   # imports = [ /home/don/.config/dcli/nixos/dcli-system.nix ];
   ```

4. Also check `system.stateVersion` matches the release you installed, and set
   `services.xserver`/desktop options as desired. Finish the install, reboot.

## 3. First boot on NixOS

1. Verify ownership (if this prints a different uid, fix `configuration.nix`
   before continuing):

   ```bash
   id don                 # uid=1000
   stat -c '%u:%g' ~      # 1000:1000
   ```

2. Activate the base configuration once. This enables the `nix-command` /
   `flakes` features that dcli needs to evaluate `config.nix`:

   ```bash
   sudo nixos-rebuild switch
   ```

3. Build dcli from the existing checkout (Nix provides the Rust toolchain):

   ```bash
   cd ~/Projects/dcli
   nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#pkg-config nixpkgs#gcc nixpkgs#binutils -c \
     cargo build --release
   mkdir -p ~/.local/bin
   install -m755 target/release/dcli ~/.local/bin/dcli
   export PATH="$HOME/.local/bin:$PATH"
   ```

   (Or build it from a Nix derivation / package it as a flake output later.)

4. Generate the NixOS integration (adopt mode — existing host files such as
   `hosts/piknix.nix` are untouched):

   ```bash
   dcli init --nixos
   ```

5. Add the printed line to `/etc/nixos/configuration.nix`:

   ```nix
   imports = [ /home/don/.config/dcli/nixos/dcli-system.nix ];
   ```

6. Apply and sync:

   ```bash
   dcli sync                    # profile apps + kineticwe-dev hook + switch
   ```

   The first sync installs the profile packages, builds KineticWE, and enables
   the Noctalia greeter (one-time; set `KWE_GREETER=0` to skip). Finish with:

   ```
   Done! Reboot to use the Noctalia greeter.
   ```

7. Reboot. The greeter offers the `KineticWE` session.
## 4. Verify the two sides

```bash
dcli status                              # config + sync status
dcli build status                        # NixOS integration, pins, drift
nix profile list                         # user apps (declarative side)
nixos-rebuild list-generations           # system generations
```

Typical day-to-day:

```bash
dcli install foo                 # nix profile add, tracked hint printed
# declare "foo" in ~/.config/dcli/hosts/nixnix.nix → nix_packages
dcli sync                        # converge profile + hooks + nixos-rebuild switch

cd ~/Projects/kineticwe && edit code
dcli sync                        # incremental rebuild via ccache → log out/in
```

## 5. Cleanup after the migration is verified

- Delete stale global dcli state from the old machine (state is per-host now):

  ```bash
  ls ~/.config/dcli/state/          # legacy *.yaml + hosts/nixnix/...
  rm -f ~/.config/dcli/state/installed.yaml \
        ~/.config/dcli/state/hooks-executed.yaml \
        ~/.config/dcli/state/modules-state.yaml \
        ~/.config/dcli/state/dotfiles-state.yaml
  ```

- Remove the old nix profile symlinks (their store paths lived on the wiped
  partitions; `dcli sync` recreates the profile):

  ```bash
  rm -rf ~/.nix-profile ~/.local/state/nix/profiles
  dcli sync
  ```

- Old Fedora/pikaos binaries and containers:

  ```bash
  rm -rf ~/.local/share/distrobox ~/.local/share/containers/storage 2>/dev/null
  rm -f ~/.local/bin/*.pre-nix
  ```

- Old boot entries (after confirming NixOS boots):

  ```bash
  efibootmgr                         # list
  sudo efibootmgr -b <NUM> -B        # delete stale entries
  ```

- Remove `hosts/piknix.nix` / `hosts/fednix*.nix` from the dcli config if those
  machines are gone (keep them if the config repo is shared).

## 6. Notes and gotchas

- **`/home` permissions**: keep `/home/don` traversable by root (mode 755).
  If you use mode 700, `nixos-rebuild` cannot read
  `~/.config/dcli/nixos/dcli-system.nix`; move the generated files into
  `/etc/nixos/dcli/` instead (and adjust the imports path).
- **Flakes must stay enabled** (`nix-command flakes` in `/etc/nix/nix.conf`
  or `nix.settings.experimental-features`), because the generated module uses
  `builtins.getFlake` for `nixos_module` inputs.
- **The dcli config repo is the source of truth** — `dcli sync` regenerates
  `dcli-system.nix`; do not hand-edit it.
- **No Home Manager anywhere.** User packages are `nix profile`; everything
  system-level is the generated NixOS module.
- If the first `dcli sync` fails during `nixos-rebuild switch`, the generated
  files are already on disk: inspect with `dcli build status`, fix the raw
  `nixos.config` block, and rerun `dcli build switch`.
