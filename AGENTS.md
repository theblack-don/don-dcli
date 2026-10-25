# Agent Instructions — dcli configuration

Personal dcli configuration for host `fednix` (Nix-based). This directory is
user-owned, hand-maintained configuration — treat it accordingly.

## Hard rules

1. **Never run build scripts or dcli commands without explicit permission.**
   - No build/install scripts or toolchain invocations: `build.sh`,
     `install.sh`, `cargo`, `make`, etc.
   - No `dcli` subcommands — including `sync`, `update`, `install`, `remove`,
     `nix`, `validate`, and `status`.
   - Ask for permission first and wait for the user to approve the exact
     command. The user prefers to run `dcli sync` and dry-runs themselves.
   - Read-only shell inspection (`ls`, `cat`, `grep`, `nix eval`, `nvidia-smi`,
     reading logs) is fine unless it would mutate state.

2. **Always present a plan before implementing changes.**
   - List the files that will be touched and the steps involved.
   - Call out risks (driver updates, nix profile changes, generated files).
   - Wait for approval before editing or generating anything.

## Context

- `config.nix` — pointer config: `host = system.hostname`, which resolves to
  `hosts/<hostname>.nix`. The machine hostname must match the host file name.
- `hosts/fednix.nix` — full host configuration (packages, services, nix).
- `modules/` — Nix modules (`base.nix`, `example.nix`).
- `state/` — dcli state and `yaml-backup-*` (old YAML configs; do not edit or
  delete).
- Nix package lists:
  - `nix_packages` — CLI packages, installed via `nix profile`.
  - `nix_gui_packages` — GUI packages using the nix graphics stack.
  - `nix_wrapped_packages` — GUI packages wrapped with host GPU libraries
    (nixGL-style), needed for some apps on non-NixOS/NVIDIA systems.
  - `{ name = "..."; wrapper = true|false; }` overrides the list default per
    entry.
- dcli generates `~/.local/bin/<app>` wrappers and
  `~/.local/share/applications/*.desktop` overrides — never hand-edit these;
  they are regenerated on sync.
- dcli source lives in `~/Projects/dcli` (separate repo; its own rules apply).
