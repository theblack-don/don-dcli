#!/usr/bin/env bash
# kineticwe-dev — install the KineticWE dev branch from its Nix flake.
#
# Run by `dcli sync` as the invoking user (module post-install hook).
#
# Modes (KWE_INSTALL_MODE, or the first word of $XDG_STATE_HOME/kineticwe/mode):
#   auto    (default) `profile` on NixOS, `local` everywhere else.
#   local   `nix build` the flake into stable out-links under
#           ~/.local/state/kineticwe/nix and drop shims in ~/.local/bin so the
#           existing start-kineticwe launcher (INSTALL_PREFIX=$HOME/.local),
#           its portals, config setup and systemd shell unit keep working.
#   profile `nix profile add`/`upgrade` the flake outputs in a dedicated
#           kinetic profile (KWE_KINETIC_PROFILE), so `dcli update` does not
#           rebuild them through the default profile. On NixOS the generated
#           system module registers that profile's launcher as a session.
#   dev     fast incremental CMake/Meson builds into
#           ~/.local/state/kineticwe/dev (see dev-build.sh) and a separate
#           KineticWE Dev session. The dedicated profile is left alone; the
#           old default-profile kinetic elements are removed.
#
# Environment:
#   KWE_REPO          checkout to build        (default $HOME/Projects/kineticwe)
#   KWE_REF           build a clean git ref instead of the checkout (optional)
#   KWE_INSTALL_MODE  auto | local | profile | dev   (default auto)
#   KWE_KINETIC_PROFILE  profile for kinetic-we/noctalia/session
#                        (default $XDG_STATE_HOME/kineticwe/profile)
#   KWE_DEV_ROOT      dev install prefix       (default $XDG_STATE_HOME/kineticwe/dev)
#   KWE_DEV_FORCE     set to 1 to rebuild both dev components
#   KWE_BIN_DIR       shim directory           (default $HOME/.local/bin)
#   KWE_GREETER       set to 0 to skip the one-time Noctalia greeter setup
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
    echo "kineticwe-dev: refusing to run as root — nix profiles are per-user." >&2
    echo "kineticwe-dev: set run_hooks_as_user = true on the module." >&2
    exit 1
fi

# `sudo -u` may leave HOME pointing at the caller; nix resolves ~/.nix-profile
# from HOME, so derive it from the account we actually run as.
HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
export HOME
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IS_NIXOS=0
if [[ -e /etc/NIXOS ]] || command -v nixos-rebuild &>/dev/null; then
    IS_NIXOS=1
fi

REPO="${KWE_REPO:-$HOME/Projects/kineticwe}"
REF="${KWE_REF:-}"
BIN_DIR="${KWE_BIN_DIR:-$HOME/.local/bin}"
STATE_DIR="$XDG_STATE_HOME/kineticwe/nix"
KWE_STATE_DIR="$XDG_STATE_HOME/kineticwe"
KINETIC_PROFILE="${KWE_KINETIC_PROFILE:-$KWE_STATE_DIR/profile}"
DEV_ROOT="${KWE_DEV_ROOT:-$KWE_STATE_DIR/dev}"

# KWE_INSTALL_MODE wins; the state file records the mode picked earlier.
MODE="${KWE_INSTALL_MODE:-}"
if [[ -z "$MODE" ]] && [[ -f "$KWE_STATE_DIR/mode" ]]; then
    read -r MODE _ < "$KWE_STATE_DIR/mode" || true
fi
MODE="${MODE:-auto}"
# Strip a CR from CRLF mode files (read keeps it as part of the word).
MODE="${MODE%$'\r'}"
if [[ "$MODE" == "auto" ]]; then
    if (( IS_NIXOS )); then MODE="profile"; else MODE="local"; fi
fi

log() { printf 'kineticwe-dev: %s\n' "$*"; }

[[ -f "$REPO/flake.nix" ]] || {
    echo "kineticwe-dev: no flake.nix in $REPO (set KWE_REPO)" >&2
    exit 1
}

# Build the checkout itself (HEAD + uncommitted changes to tracked files).
# `?ref=` is deliberately NOT used by default: it pins a clean revision and
# silently drops local edits. Flake source queries:
#   shallow=1  required for shallow clones ("shallow repositories are only
#              allowed when `shallow = true;` is specified")
#   ref=<ref>  optional, builds that committed revision only (KWE_REF)
QUERY=()
if [[ -n "$REF" ]]; then
    QUERY+=("ref=${REF}")
fi
if [[ "$(git -C "$REPO" rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]]; then
    QUERY+=("shallow=1")
fi
FLAKE="git+file://${REPO}"
if ((${#QUERY[@]})); then
    FLAKE="${FLAKE}?$(IFS='&'; printf '%s' "${QUERY[*]}")"
fi

SYSTEM="$(nix eval --raw --impure --expr builtins.currentSystem 2>/dev/null || true)"
[[ -n "$SYSTEM" ]] || SYSTEM="$(uname -m)-linux"

# Current store path of one flake output; fails when the attr is broken.
flake_out_path() {
    nix eval --raw "$FLAKE#packages.$SYSTEM.$1.outPath" 2>/dev/null
}

# Keep a real file (e.g. a build-rpm-dev.sh install) as a one-time backup
# instead of silently clobbering it. A symlink (earlier nix-profile install)
# is simply replaced.
backup_unmanaged() {
    local dst="$1"
    if [[ -L "$dst" ]]; then
        rm -f "$dst"
        return 0
    fi
    if [[ -e "$dst" ]] && ! grep -q "managed by kineticwe-dev" "$dst" 2>/dev/null; then
        mv -f "$dst" "$dst.pre-nix"
        log "backed up $dst -> $dst.pre-nix"
    fi
}

# A shim resolves the out-link at exec time, so a rebuild only needs a new
# `nix build` (no re-install).
#
# The Nix build must not inherit the host launcher's Qt/KF6 library and plugin
# paths (~/.local/lib64 holds a host-built libkineticwe.so.6), but it *does*
# need the host GPU drivers: nixpkgs' libglvnd looks in /run/opengl-driver,
# which only exists on NixOS. dcli already curates exactly those graphics
# sonames (libEGL/libGL/libgbm/libnvidia-*) in nix-gui-libs for its wrapped GUI
# packages, so reuse that directory instead of the whole host library path.
write_shim() {
    local pkg="$1" bin="$2" name="$3" dst="$BIN_DIR/$3"
    backup_unmanaged "$dst"
    mkdir -p "$BIN_DIR"
    {
        printf '%s\n' '#!/usr/bin/env bash'
        printf '%s\n' '# Generated by kineticwe-dev (dcli module) — managed by kineticwe-dev.'
        printf '%s\n' '# Resolves the current out-link so a rebuild needs no re-install.'
        if (( IS_NIXOS )); then
            printf '%s\n' '# NixOS: nixpkgs libglvnd finds drivers in /run/opengl-driver.'
            printf '%s\n' 'unset LD_LIBRARY_PATH'
            printf '%s\n' 'unset __EGL_VENDOR_LIBRARY_DIRS LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH'
        else
            printf '%s\n' 'gl_libs="$HOME/.local/share/dcli/nix-gui-libs"'
            printf '%s\n' 'if [ -d "$gl_libs" ]; then'
            printf '%s\n' '    export LD_LIBRARY_PATH="$gl_libs"'
            printf '%s\n' 'else'
            printf '%s\n' '    unset LD_LIBRARY_PATH'
            printf '%s\n' 'fi'
            printf '%s\n' 'export __EGL_VENDOR_LIBRARY_DIRS="${__EGL_VENDOR_LIBRARY_DIRS:-/usr/share/glvnd/egl_vendor.d}"'
            printf '%s\n' 'export LIBGL_DRIVERS_PATH="${LIBGL_DRIVERS_PATH:-/usr/lib64/dri}"'
            printf '%s\n' 'export GBM_BACKENDS_PATH="${GBM_BACKENDS_PATH:-/usr/lib64/gbm}"'
        fi
        printf '%s\n' 'unset QT_PLUGIN_PATH QML_IMPORT_PATH QML2_IMPORT_PATH'
        printf '%s\n' 'unset KWE_QT_PLUGIN_PATH KWE_QML_IMPORT_PATH'
        printf 'exec "%s/%s/bin/%s" "$@"\n' "$STATE_DIR" "$pkg" "$bin"
    } > "$dst"
    chmod +x "$dst"
}

install_local() {
    mkdir -p "$STATE_DIR"
    for pkg in kinetic-we noctalia; do
        log "building $FLAKE#$pkg"
        nix build --out-link "$STATE_DIR/$pkg" "$FLAKE#$pkg"
    done
    write_shim kinetic-we kinetic-we kinetic-we
    write_shim noctalia noctalia-kwe noctalia-kwe
    log "installed: $BIN_DIR/{kinetic-we,noctalia-kwe} -> $STATE_DIR"
    log "shell only:  systemctl --user restart kineticwe-shell (or Meta+Alt+R)"
    log "compositor:  log out and back in (or run a nested session)"
}

# Profile mode uses the binaries in ~/.nix-profile. A local-mode shim left
# over from a previous setup (or another host sharing $HOME) points at an
# out-link that may have been garbage-collected, and ~/.local/bin comes before
# the profile on PATH, so it would shadow the working binary.
remove_local_shims() {
    local name dst
    for name in kinetic-we kinetic-we.shim noctalia-kwe; do
        dst="$BIN_DIR/$name"
        if [[ -f "$dst" ]] && grep -q "managed by kineticwe-dev" "$dst" 2>/dev/null; then
            rm -f "$dst"
            log "removed local-mode shim $dst"
        fi
    done
}

# JSON view of a profile; an empty/absent profile reads as no elements.
profile_list_json() {
    local profile="${1:-}"
    if [[ -n "$profile" ]]; then
        nix profile list --json --profile "$profile" 2>/dev/null || echo '{}'
    else
        nix profile list --json 2>/dev/null || echo '{}'
    fi
}

# Text-format companion to the JSON presence check: print the store paths of
# one element from `nix profile list`, one path per line. Nix bolds the name
# with ANSI escapes and puts all paths on one line, so strip both before the
# awk element match. Empty profile = the default profile.
profile_store_paths() {
    local profile="$1" want="$2"
    local -a cmd=(profile list)
    if [[ -n "$profile" ]]; then
        cmd+=(--profile "$profile")
    fi
    NO_COLOR=1 nix "${cmd[@]}" 2>/dev/null |
        sed 's/\x1b\[[0-9;]*m//g' |
        awk -v want="$want" '
            /^Name:/ {
                name = $0
                sub(/^Name:[ \t]*/, "", name)
                inblock = (name == want)
                next
            }
            inblock && /^Store paths:/ {
                sub(/^Store paths:[ \t]*/, "")
                n = split($0, paths, /[ \t]+/)
                for (i = 1; i <= n; i++)
                    if (paths[i] != "") print paths[i]
                next
            }
        '
}

# The default profile is what `dcli update` upgrades, so kinetic-we/noctalia/
# session must live elsewhere. xdg-desktop-portal-kwe stays there and dcli owns
# it; upgrade it here only when the flake output changed.
ensure_default_portal() {
    local element="xdg-desktop-portal-kwe" out installed_paths
    if ! grep -q "\"$element\":" <<<"$(profile_list_json)"; then
        log "$element not in the default profile; skipping portal upgrade"
        return 0
    fi
    installed_paths="$(profile_store_paths "" "$element")"
    out="$(flake_out_path "$element")" || out=""
    if [[ -n "$out" ]] && [[ -n "$installed_paths" ]] &&
        grep -Fxq "$out" <<<"$installed_paths"; then
        log "$element unchanged"
    else
        log "nix profile upgrade $element"
        nix profile upgrade "$element"
    fi
}

# One-time migration: an old install put these in the default profile.
remove_default_kinetic_elements() {
    local installed element
    installed="$(profile_list_json)"
    for element in kinetic-we noctalia session; do
        grep -q "\"$element\":" <<<"$installed" || continue
        log "removing $element from the default profile (managed in $KINETIC_PROFILE)"
        if ! nix profile remove "$element"; then
            log "warning: could not remove $element from the default profile"
        fi
    done
}

install_profile() {
    local updated=0 element out installed_paths
    local -a missing=() present=() changed=() unchanged=()
    remove_local_shims
    mkdir -p "$KWE_STATE_DIR" "$(dirname "$KINETIC_PROFILE")"
    installed="$(profile_list_json "$KINETIC_PROFILE")"
    for element in kinetic-we noctalia session; do
        if grep -q "\"$element\":" <<<"$installed"; then
            present+=("$element")
        else
            missing+=("$FLAKE#$element")
        fi
    done
    if ((${#missing[@]})); then
        log "nix profile add --profile $KINETIC_PROFILE ${missing[*]}"
        nix profile add --profile "$KINETIC_PROFILE" "${missing[@]}"
        updated=1
    fi
    for element in "${present[@]}"; do
        installed_paths="$(profile_store_paths "$KINETIC_PROFILE" "$element")"
        out="$(flake_out_path "$element")" || out=""
        if [[ -z "$out" ]] || [[ -z "$installed_paths" ]] ||
            ! grep -Fxq "$out" <<<"$installed_paths"; then
            changed+=("$element")
        else
            unchanged+=("$element")
        fi
    done
    if ((${#changed[@]})); then
        log "changed: ${changed[*]}"
        if ((${#unchanged[@]})); then
            log "unchanged: ${unchanged[*]}"
        fi
        log "nix profile upgrade --profile $KINETIC_PROFILE ${changed[*]}"
        nix profile upgrade --profile "$KINETIC_PROFILE" "${changed[@]}"
        updated=1
    elif ((${#present[@]})); then
        log "unchanged: ${unchanged[*]}"
        if ((${#missing[@]} == 0)); then
            log "all components up to date ($FLAKE)"
        fi
    fi
    log "kinetic profile: $KINETIC_PROFILE"
    touch "$KWE_STATE_DIR/profile-enabled"
    remove_default_kinetic_elements
    ensure_default_portal
    if ((updated)); then
        log "profile updated; log out and back in to use it"
    fi
}

# Dev mode: incremental builds in $DEV_ROOT plus a separate "KineticWE Dev"
# session. The dedicated kinetic profile is left alone; the default profile
# keeps only the portal so `dcli update` does not rebuild the dev branch.
install_dev() {
    local -a args=(all)
    if [[ "${KWE_DEV_FORCE:-0}" == "1" ]]; then
        args=(--force all)
    fi
    KWE_DEV_ROOT="$DEV_ROOT" "$SCRIPT_DIR/dev-build.sh" "${args[@]}"
    mkdir -p "$KWE_STATE_DIR"
    touch "$KWE_STATE_DIR/dev-enabled"

    remove_default_kinetic_elements
    ensure_default_portal

    log "dev session ready: log out and pick \"KineticWE Dev\""
    log "shell only:  systemctl --user restart kineticwe-shell"
    log "compositor:  log out and back in"
}

case "$MODE" in
    local) install_local ;;
    profile) install_profile ;;
    dev) install_dev ;;
    *)
        echo "kineticwe-dev: unknown KWE_INSTALL_MODE=$MODE (expected auto|local|profile|dev)" >&2
        exit 2
        ;;
esac

# NixOS one-time activation. The markers are read by the generated NixOS
# module (module.nix -> nixos.config): `dcli sync` regenerates the module after
# hooks run, then runs nixos-rebuild switch.
enable_nixos_activation() {
    (( IS_NIXOS )) || return 0
    mkdir -p "$KWE_STATE_DIR"

    if [[ "${KWE_GREETER:-1}" == "0" ]]; then
        log "greeter setup skipped (KWE_GREETER=0)"
        return 0
    fi
    if [[ -f "$KWE_STATE_DIR/greeter-enabled" ]]; then
        log "noctalia greeter already enabled"
        return 0
    fi

    touch "$KWE_STATE_DIR/greeter-enabled"
    log "noctalia greeter enabled (one-time setup; greetd will be configured)"
    echo
    log "Done! Reboot to use the Noctalia greeter."
}

enable_nixos_activation
