# Nix Modules Guide

## Overview

Nix modules provide a powerful alternative to YAML and Lua for creating package
configurations. While YAML modules are static and Lua modules use embedded Lua
scripts, Nix modules are evaluated by the real `nix` binary with access to
`nixpkgs`, enabling complex package expressions, attribute set manipulation,
and integration with existing Nix workflows.

**Use Nix modules when you need:**

- Access to `nixpkgs` for package filtering, version checks, or custom derivations
- Complex conditional logic based on system facts
- Integration with existing Nix flake or expression-based workflows
- Nix-based host configurations alongside module definitions

## Prerequisites

Nix modules require the external `nix` binary with the `nix-command`
experimental feature enabled. Flakes are required for `nix profile` installs
and flake-based Home Manager setups.

Install Nix through dcli after creating a config (`dcli init` or
`dcli init --nix`):

```bash
dcli nix install
```

Or install it manually:

```bash
# Arch Linux
sudo pacman -S --needed nix
sudo systemctl enable --now nix-daemon
sudo usermod -aG nix-users "$USER"   # log out/in afterwards

# Fedora
sudo dnf install nix nix-daemon libgit2
sudo systemctl enable --now nix-daemon

# Debian/Ubuntu
curl --proto '=https' --tlsv1.2 -sSf -L https://nixos.org/nix/install | sh -s -- --daemon
```

Then enable the experimental features and add a `nixpkgs` channel:

```bash
sudo mkdir -p /etc/nix
echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon

nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
nix-channel --update
```

For a single-user installation, put `experimental-features` in
`~/.config/nix/nix.conf` instead of `/etc/nix/nix.conf`.

If `nix` is not installed or the feature is disabled, `module.nix` cannot be
evaluated. dcli falls back to `module.lua` or `module.yaml` when the module
provides one.

> For a complete setup walkthrough, including standalone `nix profile` mode
> and Home Manager, see the
> [README Nix integration section](../README.md#nix-integration).

## Host Configuration (`host.nix`)

Nix host configs live at `~/.config/dcli/hosts/<hostname>.nix` (or
`~/.config/dcli/hosts/<hostname>/host.nix`). The top-level `config.nix` is a
pointer to the active host:

```nix
{ system, pkgs }:

{
  host = "myhost";
}
```

The full host file contains the package lists and the `nix` integration block:

```nix
{ system, pkgs }:

{
  host = "myhost";
  description = "Nix-configured desktop";

  enabled_modules = [ "base" "development" ];

  packages = [
    "firefox"
    "git"
  ];

  # Fedora/dnf: enable these COPR repositories before installing packages
  copr_repos = [ "theblackdon/dcli" ];

  flatpak_packages = [
    "com.spotify.Client"
  ];

  nix_packages = [
    "ripgrep"
    "fd"
    "bat"
  ];

  nix_gui_packages = [
    "goverlay"
  ];

  nix_wrapped_packages = [
    "ghostty"
  ];

  # Named flake inputs referenced as "<input>#<attr>" in nix_packages.
  nix_flakes = {
    helium = {
      url = "github:amaanq/helium-flake";
      follows = { nixpkgs = "nixpkgs"; };
    };
  };

  nix = {
    enabled = true;
    home_manager_enabled = false;
    nix_profile_enabled = true;
    flake_enabled = false;
    nixpkgs_channel = "nixpkgs-unstable";
    home_manager_channel = "release-25.05";
  };
}
```

The `nix` block selects how dcli integrates with Nix:

| Field | Default | Description |
|---|---|---|
| `enabled` | `false` | Enables Nix integration for update checks. Set to `true` when using Nix. |
| `home_manager_enabled` | `false` | Uses Home Manager and runs `home-manager switch` during `dcli sync`. |
| `nix_profile_enabled` | `false` | Installs packages with `nix profile` (standalone mode). Ignored when `home_manager_enabled = true`. |
| `flake_enabled` | `false` | Uses flake mode (`flake.nix` + `flake.lock`) for Home Manager instead of channels. |
| `nixpkgs_channel` | `nixpkgs-unstable` | Channel used for channel-mode Home Manager setup. |
| `home_manager_channel` | `release-25.05` | Home Manager channel used for channel-mode installation. |

For standalone package installation:

```nix
nix = {
  enabled = true;
  home_manager_enabled = false;
  nix_profile_enabled = true;
};
```

For Home Manager:

```nix
nix = {
  enabled = true;
  home_manager_enabled = true;
  nix_profile_enabled = false;
  flake_enabled = true;
};
```

Create the Nix config files with `dcli init --nix`; set up Home Manager with
`dcli init --nix-init`. Then validate and apply:

```bash
dcli validate
dcli sync --dry-run
dcli sync
```

## Quick Start

### Basic Nix Module

Create a file with `.nix` extension in your modules directory:

```nix
# ~/.config/dcli/modules/gaming.nix
{ pkgs, system }: {
  description = "Gaming packages";
  packages = [
    "steam"
    "lutris"
    "wine"
    "gamemode"
  ];
}
```

Enable and sync like any other module:

```bash
dcli module enable gaming
dcli sync
```

### Directory Module with module.nix

Directory modules can use `module.nix` as the manifest instead of
`module.lua` or `module.yaml`:

```
modules/gaming/
├── module.nix          # Manifest (takes precedence over module.lua/module.yaml)
├── packages.nix        # Optional: Nix-based package files
├── packages.yaml       # Optional: YAML-based package files
├── scripts/
│   └── setup.sh
└── dotfiles/
    └── ...
```

```nix
# modules/gaming/module.nix
{ pkgs, system }: {
  description = "Gaming packages with conditional NVIDIA drivers";

  packages =
    # Base gaming packages
    [
      "steam"
      "lutris"
      "wine"
      "gamemode"
    ]
    # Conditionally add NVIDIA drivers
    ++ pkgs.lib.optionals (system.arch == "x86_64") [
      "nvidia"
      "nvidia-utils"
    ];

  package_files = [ "packages-extra.nix" ];
  post_install_hook = "scripts/setup.sh";
}
```

## Module Structure

A Nix module is a function `{ pkgs, system }: { ... }` that returns an
attribute set. The available fields are:

```nix
{ pkgs, system }: {
  description = "My module description";

  packages = [
    "pkg1"
    "pkg2"
    "flatpak:com.spotify.Client"    # Flatpak with prefix syntax
  ];

  flatpak_packages = [
    "com.spotify.Client"             # Alternative flatpak field
    # Local bundle / flatpakref (no remote needed)
    { name = "org.videolan.VLC"; source = "/path/VLC.flatpak"; }
    # Specific remote and languages ("*" = all)
    { name = "org.gnome.Calculator"; remote = "flathub"; languages = [ "*" ]; }
  ];

  nix_packages = [
    "helix"                          # Packages installed via nix profile
  ];

  nix_gui_packages = [
    "goverlay"                       # GUI apps: installed via nix profile;
                                     # use the Nix graphics stack by default
  ];

  nix_wrapped_packages = [
    "ghostty"                        # GUI apps wrapped to use the host GPU
                                     # libraries (nixGL-style) when the Nix
                                     # stack cannot create a GL context
    # Per-entry override (works in either list):
    # { name = "some-app"; wrapper = true; }
  ];

  # Named flake inputs (see "Flake inputs" below)
  nix_flakes = {
    helium = {
      url = "github:amaanq/helium-flake";
      follows = { nixpkgs = "nixpkgs"; };
    };
  };

  deb_packages = [
    "package.deb"                    # Local .deb packages
  ];

  # Fedora/dnf: enable these COPR repositories before installing packages
  copr_repos = [ "owner/project" ];

  conflicts = [ "other-module" ];

  services = {
    enabled = [ "docker.service" ];
    disabled = [ "cups.service" ];
  };

  pre_install_hook = "scripts/pre-setup.sh";
  post_install_hook = "scripts/post-setup.sh";

  hook_behavior = "ask";
  pre_hook_behavior = "once";
  post_hook_behavior = "always";
  post_disable_hook = "scripts/cleanup.sh";
  post_disable_behavior = "ask";
  run_hooks_as_user = false;

  # Sharing metadata (for upload)
  author = "your-username";
  version = "1.0.0";
  category = "development";
  tags = [ "python" "tools" ];
  license = "MIT";
  upstream_url = "https://github.com/example/module";
}
```

## System Facts

Nix modules receive system facts via the `system` argument. It is an attribute
set, not the Nix system string:

```nix
{ system, pkgs }:

{
  packages =
    if system.hardware.has_nvidia then
      [ "nvidia" "nvidia-utils" ]
    else if system.hardware.is_laptop then
      [ "tlp" ]
    else
      [];
}
```

Common facts include:

| Fact | Description |
|---|---|
| `system.hostname` | Current hostname |
| `system.arch` | CPU architecture (e.g. `x86_64`) |
| `system.distro` | Distribution ID (e.g. `arch`, `fedora`) |
| `system.kernel_version` | Running kernel version |
| `system.hardware.cpu_vendor` | `intel`, `amd`, or `unknown` |
| `system.hardware.gpu_vendors` | List of detected GPU vendors |
| `system.hardware.has_nvidia` | NVIDIA GPU present |
| `system.hardware.has_amd_gpu` | AMD GPU present |
| `system.hardware.is_laptop` | Laptop chassis detected |
| `system.desktop.is_wayland` | Wayland session |
| `system.package.installed` | Installed package names |
| `system.service.enabled` | Enabled systemd services |

The `pkgs` argument is the default `nixpkgs` package set, giving you access
to all of nixpkgs for package filtering, version checks, and more.

## Package Entry Formats

```nix
{ pkgs, system }: {
  packages = [
    "firefox"                         # Simple native package
    "flatpak:com.spotify.Client"      # Flatpak with prefix
    "nix:helix"                       # Nix profile package

    # Structured package entries
    { name = "com.discordapp.Discord"; type = "flatpak"; }
    { name = "com.discordapp.Discord"; type = "flatpak"; source = "/path/Discord.flatpak"; }
    { name = "com.discordapp.Discord"; type = "flatpak"; remote = "my-remote"; languages = [ "*" ]; }
    { name = "steam"; type = null; }  # Native (default)
  ];
}
```

### Flake inputs

Declare named flake inputs with `nix_flakes`, then reference packages from them
as `"<input>#<attr>"`:

```nix
{ system, pkgs }:

{
  nix_flakes = {
    helium = {
      url = "github:amaanq/helium-flake";

      # Optional: pin a branch or commit. Do not set both.
      # ref = "main";
      # rev = "0123456789abcdef0123456789abcdef01234567";

      follows = {
        nixpkgs = "nixpkgs";
      };
    };
  };

  nix_packages = [
    "helium#default"
    # Explicit output paths are also accepted:
    # "helium#packages.x86_64-linux.default"
  ];
}
```

`nix_flakes` can be declared in a `.nix` host or module. Inputs declared in
enabled modules are merged with the host's inputs; conflicting definitions for
the same input name are an error.

Package reference forms:

| Reference | Meaning |
|---|---|
| `"helium#default"` | `packages.<system>.default` from the `helium` input |
| `"helium#helium"` | `packages.<system>.helium` |
| `"helium#packages.x86_64-linux.helium"` | explicit flake output path |
| `"helium"` | `packages.<system>.default`, when `helium` is a declared input |

How the declarations are applied depends on the install mode:

- **Home Manager flake mode** (`nix.home_manager_enabled = true` and
  `nix.flake_enabled = true`): dcli writes the inputs into
  `~/.config/dcli/home-manager/flake.nix`, renders `follows` as
  `inputs.helium.inputs.nixpkgs.follows = "nixpkgs";`, and generates
  `inputs.helium.packages.${system}.default` entries in `dcli-packages.nix`.
- **Standalone profile mode** (`nix.nix_profile_enabled = true`): `helium#default`
  becomes `github:amaanq/helium-flake#default`. Each `follows` entry becomes
  `--override-input <input> <target>`. If the target is another declared input,
  dcli uses that input's URL; otherwise the target is passed through as a flake
  reference.

Specific-commit pinning can also be written directly in the URL, for example
`url = "github:amaanq/helium-flake/0123456789abcdef0123456789abcdef01234567";`.
Using `rev` is preferred because dcli can keep it separate from the repository
URL.

GUI packages can come from a flake input too. Use the object form so `name`
remains the binary/launcher name:

```nix
nix_gui_packages = [
  {
    name = "helium";
    flake = "helium";
    package = "default";   # optional; defaults to "default"
    wrapper = false;
  }
];
```

Flake inputs require flakes to be enabled for Home Manager. If flakes are
disabled, declaring a flake-backed package is an error with instructions to
either enable `nix.flake_enabled` or use standalone profile mode.

> `dcli sync` manages a `# BEGIN dcli-flake-inputs` block in the Home Manager
> `flake.nix`. Entries are added or updated by name, but removing an input from
> `nix_flakes` does not delete it automatically. This avoids breaking other
> hosts that share the same Home Manager flake; remove the line manually (or use
> a shared imported config) if you no longer need it.

### Flake, path and store installables

Entries in `nix_packages` normally name nixpkgs attributes, which are
installed as `nix profile add nixpkgs#<attr>`. A full installable is passed to
`nix profile add` unchanged instead, so packages can come from any flake:

```nix
nix_packages = [
  "helix"                                                    # nixpkgs#helix
  "git+file:///home/me/src/kineticwe?ref=kineticwe-2.0#kinetic-we"  # local flake
  "github:owner/repo#package"                                # remote flake
  "/home/me/src/flake#package"                               # path flake
];
```

`nix_gui_packages` / `nix_wrapped_packages` still expect plain nixpkgs
attribute names: their entries double as desktop-entry and wrapper file names.

Anything containing `:`, `#` or `/` (or a bare `.`/`..`) is treated as an
installable; everything else keeps the `nixpkgs#` prefix. `~/` is expanded to
the home directory before the reference is handed to nix.

Prefer `git+file://` over `path:` for a local checkout: the git fetcher honours
`.gitignore` and includes uncommitted changes to tracked files, while `path:`
copies the entire tree, build directories included. Omit `?ref=` to build the
checkout as-is (local edits included); add `&shallow=1` when the clone is
shallow, otherwise nix refuses to fetch it.

`dcli update` (`nix profile upgrade --all`) re-evaluates these references, so a
rebuilt branch is picked up on the next update. `dcli sync --prune` matches
declared references against profile element names (a `...#kinetic-we` reference
matches the `kinetic-we` element), so flake installs are neither re-added on
every sync nor pruned as undeclared.

## Differences from Lua Modules

| Feature | Lua Modules | Nix Modules |
|---------|-------------|-------------|
| **Runtime** | Embedded Lua interpreter | External `nix` binary |
| **Package access** | dcli API helpers (`dcli.hardware.*`, etc.) | Full `nixpkgs` via `pkgs` argument |
| **Conditional logic** | Lua `if`/`else`, loops | Nix expressions, `pkgs.lib.optionals`, etc. |
| **System facts** | dcli-provided API | `system` facts attribute set (`system.hardware.*`, etc.) |
| **Performance** | Fast (in-process) | Slower (subprocess eval) |
| **Dependency** | None (vendored Lua) | Requires `nix` with `nix-command`; flakes for profile installs |

> **Note:** If `module.nix` exists alongside `module.lua` or `module.yaml` in a
> directory module, `module.nix` takes precedence (`module.nix` > `module.lua` > `module.yaml`).
