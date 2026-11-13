#!/usr/bin/env bash
# kineticwe-dev — incremental builds of the KineticWE checkout.
#
# Builds kinetic-we (CMake/Ninja) and noctalia-kwe (Meson/Ninja) from the
# checkout into $KWE_DEV_ROOT instead of `nix build`, each in its own
# persistent `nix develop` shell so their dependency sets cannot mix (e.g.
# sdbus-c++ 1.x for kinetic-we vs 2.x for noctalia). A component is rebuilt
# only when its flake drvPath changed, its build dir is missing, or --force
# was passed.
#
# Usage:
#   dev-build.sh [--force] [all|kinetic-we|noctalia]
#
# Environment:
#   KWE_REPO                checkout to build    (default $HOME/Projects/kineticwe)
#   KWE_DEV_ROOT            install prefix       (default $XDG_STATE_HOME/kineticwe/dev;
#                           module.nix hardcodes this default for the session entry)
#   KWE_DEV_KWIN_BUILD      CMake build dir      (default $KWE_REPO/build-devnix)
#   KWE_DEV_NOCTALIA_BUILD  Meson build dir      (default $KWE_REPO/build-devnix-noctalia)
#   KWE_DEV_FORCE           1 = rebuild every requested component
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
    echo "kineticwe-dev: refusing to run as root — the dev build is per-user." >&2
    exit 1
fi

# `sudo -u` may leave HOME pointing at the caller; keep the nix profile paths
# and the user cache under the account we actually run as.
HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
export HOME
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

REPO="${KWE_REPO:-$HOME/Projects/kineticwe}"
KWE_STATE_DIR="$XDG_STATE_HOME/kineticwe"
DEV_ROOT="${KWE_DEV_ROOT:-$KWE_STATE_DIR/dev}"
KWIN_BUILD="${KWE_DEV_KWIN_BUILD:-$REPO/build-devnix}"
NOCTALIA_BUILD="${KWE_DEV_NOCTALIA_BUILD:-$REPO/build-devnix-noctalia}"

log() { printf 'kineticwe-dev: %s\n' "$*"; }

# Absolute path: the phase re-exec below may not start in this directory.
SCRIPT_PATH="$0"
if [[ "$SCRIPT_PATH" != /* ]]; then
    SCRIPT_PATH="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)/$(basename "$SCRIPT_PATH")"
fi

[[ -f "$REPO/flake.nix" ]] || {
    echo "kineticwe-dev: no flake.nix in $REPO (set KWE_REPO)" >&2
    exit 1
}

# Build the checkout itself (HEAD + uncommitted changes to tracked files).
# `shallow=1` is required for shallow clones, same as install-kineticwe.sh.
FLAKE="git+file://${REPO}"
if [[ "$(git -C "$REPO" rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]]; then
    FLAKE="${FLAKE}?shallow=1"
fi

SYSTEM="$(nix eval --raw --impure --expr builtins.currentSystem)"

# --- shared helpers -------------------------------------------------------

drv_of() {
    nix eval --raw "$FLAKE#packages.$SYSTEM.$1.drvPath"
}

# Rebuild when forced, when the record/build dir is missing, or when the flake
# output changed since the last successful build.
needs_build() {
    local attr="$1" record="$2" build_dir="$3" drv
    if ((FORCE)); then
        log "$attr: forced rebuild"
        return 0
    fi
    if [[ ! -f "$record" ]]; then
        log "$attr: no recorded drvPath; rebuilding"
        return 0
    fi
    if [[ ! -f "$build_dir/build.ninja" ]]; then
        log "$attr: no build.ninja in $build_dir; rebuilding"
        return 0
    fi
    if ! drv="$(drv_of "$attr")"; then
        log "$attr: drvPath evaluation failed; rebuilding"
        return 0
    fi
    if [[ "$drv" != "$(cat "$record")" ]]; then
        log "$attr: flake output changed; rebuilding"
        return 0
    fi
    return 1
}

# NixOS drivers live in /run/opengl-driver; keep any rpath the build wrote.
add_driver_runpath() {
    local binary="$1" rpath
    [[ -f "$binary" ]] || return 0
    if ! command -v patchelf &>/dev/null; then
        log "patchelf not in PATH; leaving RUNPATH of $binary alone"
        return 0
    fi
    if ! rpath="$(patchelf --print-rpath "$binary" 2>/dev/null)"; then
        log "patchelf cannot read $binary; leaving RUNPATH alone"
        return 0
    fi
    case ":$rpath:" in
        *:/run/opengl-driver/lib:*) return 0 ;;
    esac
    if [[ -n "$rpath" ]]; then
        patchelf --set-rpath "/run/opengl-driver/lib:$rpath" "$binary"
    else
        patchelf --set-rpath "/run/opengl-driver/lib" "$binary"
    fi
}

# `nix develop --command` runs the phase in a child bash, so makeWrapper's
# setup-hook `wrapProgram` is not inherited. Write the same wrapper explicitly:
# prepend git to PATH and the gsettings schema dir to XDG_DATA_DIRS (keeping
# existing values) and preserve argv[0] via exec -a.
wrap_noctalia() {
    local bin="$1" hidden
    : "${KWE_GIT_BIN:?}" "${KWE_GSETTINGS_DIR:?}"
    [[ -f "$bin" ]] || return 0
    [[ "$(head -c 2 "$bin")" == "#!" ]] && return 0
    hidden="$(dirname "$bin")/.$(basename "$bin")-wrapped"
    mv -f "$bin" "$hidden"
    cat > "$bin" <<EOF
#!${BASH:-/run/current-system/sw/bin/bash}
export PATH="$KWE_GIT_BIN\${PATH:+:\$PATH}"
export XDG_DATA_DIRS="$KWE_GSETTINGS_DIR\${XDG_DATA_DIRS:+:\$XDG_DATA_DIRS}"
exec -a "\$0" "$hidden" "\$@"
EOF
    chmod +x "$bin"
}

build_kwin() {
    local drv
    # Fail before the build if the flake output itself is broken.
    drv="$(drv_of kinetic-we)"
    log "building kinetic-we (CMake/Ninja, $KWIN_BUILD)"
    mkdir -p "$DEV_ROOT" "$KWIN_BUILD"
    cmake -S "$REPO" -B "$KWIN_BUILD" -G Ninja \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DBUILD_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX="$DEV_ROOT" \
        -DCMAKE_C_COMPILER_LAUNCHER=ccache \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    cmake --build "$KWIN_BUILD"
    cmake --install "$KWIN_BUILD" --prefix "$DEV_ROOT"
    [[ -x "$DEV_ROOT/bin/kinetic-we" ]] || {
        echo "kineticwe-dev: kinetic-we missing from $DEV_ROOT/bin after install" >&2
        exit 1
    }
    add_driver_runpath "$DEV_ROOT/bin/kinetic-we"
    printf '%s\n' "$drv" > "$DEV_ROOT/.kwin-drv"
    log "kinetic-we installed: $DEV_ROOT/bin/kinetic-we"
}

build_noctalia() {
    local drv bin="$DEV_ROOT/bin/noctalia-kwe"
    drv="$(drv_of noctalia)"
    log "building noctalia-kwe (Meson/Ninja, $NOCTALIA_BUILD)"
    mkdir -p "$DEV_ROOT" "$NOCTALIA_BUILD"
    cat > "$NOCTALIA_BUILD/ccache.ini" <<'EOF'
[binaries]
c = ['ccache', 'gcc']
cpp = ['ccache', 'g++']
EOF
    if [[ -f "$NOCTALIA_BUILD/build.ninja" ]]; then
        meson setup --reconfigure "$NOCTALIA_BUILD" "$REPO/shell/noctalia" \
            --prefix "$DEV_ROOT" --buildtype=release -Dtests=disabled \
            --native-file "$NOCTALIA_BUILD/ccache.ini"
    else
        meson setup "$NOCTALIA_BUILD" "$REPO/shell/noctalia" \
            --prefix "$DEV_ROOT" --buildtype=release -Dtests=disabled \
            --native-file "$NOCTALIA_BUILD/ccache.ini"
    fi
    meson compile -C "$NOCTALIA_BUILD"
    meson install -C "$NOCTALIA_BUILD"
    [[ -e "$bin" ]] || {
        echo "kineticwe-dev: noctalia-kwe missing from $DEV_ROOT/bin after install" >&2
        exit 1
    }

    # RUNPATH before wrapping: wrap_noctalia replaces the ELF with a script.
    add_driver_runpath "$bin"
    wrap_noctalia "$bin"
    if [[ ! -e "$DEV_ROOT/bin/noctalia" ]]; then
        ln -s noctalia-kwe "$DEV_ROOT/bin/noctalia"
    fi
    printf '%s\n' "$drv" > "$DEV_ROOT/.noctalia-drv"
    log "noctalia-kwe installed: $bin"
}

# Session pieces are cheap: regenerate them on every run so script/template
# edits land without a rebuild.
refresh_session() {
    local bash_bin="${BASH:-/run/current-system/sw/bin/bash}"
    mkdir -p "$DEV_ROOT/bin" "$DEV_ROOT/lib/kineticwe" "$DEV_ROOT/share/kineticwe"
    # greetd starts the session with a minimal PATH and /bin/bash does not
    # exist on NixOS, so the generated launchers need an absolute bash shebang.
    sed -e "s|@INSTALL_PREFIX@|$DEV_ROOT|g" \
        -e "1s|^#!.*|#!$bash_bin|" \
        "$REPO/scripts/start-kineticwe.sh" > "$DEV_ROOT/bin/start-kineticwe"
    chmod +x "$DEV_ROOT/bin/start-kineticwe"
    install -Dm755 "$REPO/scripts/kineticwe-config-setup" \
        "$DEV_ROOT/lib/kineticwe/kineticwe-config-setup"
    install -Dm644 "$REPO/scripts/kineticwe-session.target" \
        "$DEV_ROOT/share/kineticwe/kineticwe-session.target"
    sed -e "s|@INSTALL_PREFIX@|$DEV_ROOT|g" \
        "$REPO/scripts/kineticwe-shell.service.in" \
        > "$DEV_ROOT/share/kineticwe/kineticwe-shell.service"

    # Bake the dependency plugin/QML dirs: the session has no nix develop env.
    {
        printf '%s\n' '# Generated by kineticwe-dev — environment for the KineticWE Dev session.'
        printf 'export QT_PLUGIN_PATH="%s"\n' \
            "$DEV_ROOT/lib/qt-6/plugins:$DEV_ROOT/lib/plugins${KWE_QT_PLUGIN_DIRS:+:$KWE_QT_PLUGIN_DIRS}"
        printf 'export QML_IMPORT_PATH="%s"\n' \
            "$DEV_ROOT/lib/qt-6/qml:$DEV_ROOT/lib/qml${KWE_QML_DIRS:+:$KWE_QML_DIRS}"
        printf '%s\n' 'export QML2_IMPORT_PATH="$QML_IMPORT_PATH"'
        printf 'export NIXPKGS_QT6_QML_IMPORT_PATH="%s"\n' "${KWE_QML_DIRS:-}"
        printf '%s\n' 'export TZDIR="${TZDIR:-/etc/zoneinfo}"'
        # greetd sessions get a minimal PATH and no XDG_DATA_DIRS, so make the
        # system profile visible for the spec's runtime packages/data.
        printf '%s\n' 'export XDG_DATA_DIRS="/run/current-system/sw/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"'
        printf '%s\n' 'export PATH="$PATH:/run/current-system/sw/bin:/run/wrappers/bin"'
        printf 'export PATH="%s:$PATH"\n' "${KWE_HELPER_PATH:-}"
    } > "$DEV_ROOT/share/kineticwe/dev-env.sh"
    chmod 644 "$DEV_ROOT/share/kineticwe/dev-env.sh"

    {
        printf '#!%s\n' "$bash_bin"
        printf '%s\n' '# Generated by kineticwe-dev — KineticWE Dev session launcher.'
        printf '. "%s/share/kineticwe/dev-env.sh"\n' "$DEV_ROOT"
        printf '%s\n' 'unset INSTALL_PREFIX KWE_SCOPED_ENV KWE_QT_PLUGIN_PATH KWE_QML_IMPORT_PATH'
        printf '%s\n' 'unset LD_LIBRARY_PATH'
        printf 'exec "%s/bin/start-kineticwe" "$@"\n' "$DEV_ROOT"
    } > "$DEV_ROOT/bin/start-kineticwe-dev"
    chmod +x "$DEV_ROOT/bin/start-kineticwe-dev"
}

# --- phase dispatch -------------------------------------------------------
# run_phase re-execs this script inside one component's shell; the phase only
# runs that component's build (and the cheap session refresh for kinetic-we).
if [[ -n "${KWE_DEV_PHASE:-}" ]]; then
    case "$KWE_DEV_PHASE" in
        kinetic-we)
            if [[ "${KWE_DEV_BUILD_KWIN:-0}" == "1" ]]; then build_kwin; else log "kinetic-we: unchanged"; fi
            refresh_session
            ;;
        noctalia)
            build_noctalia
            ;;
        *)
            echo "kineticwe-dev: unknown phase: $KWE_DEV_PHASE" >&2
            exit 2
            ;;
    esac
    exit 0
fi

# --- outer script ---------------------------------------------------------

FORCE="${KWE_DEV_FORCE:-0}"
want_kwin=0
want_noctalia=0
components=()
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        all) components+=("kinetic-we" "noctalia") ;;
        kinetic-we | noctalia) components+=("$arg") ;;
        *)
            echo "kineticwe-dev: unknown argument: $arg (expected --force, all, kinetic-we, noctalia)" >&2
            exit 2
            ;;
    esac
done
if ((${#components[@]} == 0)); then
    components=(kinetic-we noctalia)
fi
for component in "${components[@]}"; do
    case "$component" in
        kinetic-we) want_kwin=1 ;;
        noctalia) want_noctalia=1 ;;
    esac
done

# Each component gets a shell with only its own dependency set.
write_kwin_shell() {
    local file="$1"
    mkdir -p "$(dirname "$file")"
    cat > "$file" <<'NIXEOF'
{ flakeRef }:
let
  flake = builtins.getFlake flakeRef;
  system = builtins.currentSystem;
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
  lib = pkgs.lib;
  kwin = flake.packages.${system}.kinetic-we;

  # Same extra Qt/KDE data providers as flake session.nix. Referencing their
  # store paths here keeps them in the dev shell closure via string context.
  qtExtra = [
    pkgs.qt6Packages.qt6ct
    pkgs.kdePackages.plasma-workspace
    pkgs.kdePackages.qqc2-desktop-style
  ];

  # Colon-joined Qt dirs from the runtime outputs. chooseDevOutputs already
  # rewrote buildInputs to -dev outputs and marks them outputSpecified, so
  # getOutput "out" is a no-op; select `.out` explicitly.
  qtDirs = sub:
    lib.concatStringsSep ":" (
      map (p: (p.out or p) + "/lib/qt-6/" + sub)
        (kwin.buildInputs ++ qtExtra)
    );
in
pkgs.mkShell {
  name = "kineticwe-kinetic-we";

  nativeBuildInputs = kwin.nativeBuildInputs ++ [ pkgs.ccache pkgs.git pkgs.patchelf ];
  buildInputs = kwin.buildInputs;

  shellHook = ''
    export CCACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/ccache"
    export CCACHE_COMPRESS=1
    export CCACHE_SLOPPINESS=random_seed
    export CMAKE_GENERATOR=Ninja
    export CMAKE_C_COMPILER_LAUNCHER=ccache
    export CMAKE_CXX_COMPILER_LAUNCHER=ccache
    export KWE_QT_PLUGIN_DIRS="${qtDirs "plugins"}"
    export KWE_QML_DIRS="${qtDirs "qml"}"
    export KWE_HELPER_PATH="${pkgs.lib.makeBinPath [ pkgs.xwayland pkgs.psmisc pkgs.procps pkgs.dbus pkgs.python3 pkgs.kdePackages.kservice ]}"
    mkdir -p "$CCACHE_DIR"
  '';
}
NIXEOF
}

write_noctalia_shell() {
    local file="$1"
    mkdir -p "$(dirname "$file")"
    cat > "$file" <<'NIXEOF'
{ flakeRef }:
let
  flake = builtins.getFlake flakeRef;
  system = builtins.currentSystem;
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
  noctalia = pkgs.callPackage (flake.outPath + "/shell/noctalia/nix/package.nix") { };
in
pkgs.mkShell {
  name = "kineticwe-noctalia";

  nativeBuildInputs = noctalia.nativeBuildInputs ++ [ pkgs.ccache pkgs.git pkgs.patchelf ];
  buildInputs = noctalia.buildInputs;

  shellHook = ''
    export CCACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/ccache"
    export CCACHE_COMPRESS=1
    export CCACHE_SLOPPINESS=random_seed
    export KWE_GSETTINGS_DIR="${pkgs.glib.getSchemaDataDirPath pkgs.gsettings-desktop-schemas}"
    export KWE_GIT_BIN="${pkgs.git}/bin"
    mkdir -p "$CCACHE_DIR"
  '';
}
NIXEOF
}

run_phase() {
    local component="$1" phase="$2"
    local shell_file="$KWE_STATE_DIR/dev-shell-$component.nix"
    case "$component" in
        kinetic-we) write_kwin_shell "$shell_file" ;;
        noctalia) write_noctalia_shell "$shell_file" ;;
        *)
            echo "kineticwe-dev: unknown component: $component" >&2
            exit 2
            ;;
    esac
    nix develop --impure \
        --expr "import \"$shell_file\" { flakeRef = \"$FLAKE\"; }" \
        --command env KWE_DEV_PHASE="$phase" KWE_DEV_BUILD_KWIN="${KWE_DEV_BUILD_KWIN:-0}" bash "$SCRIPT_PATH"
}

kwin_build=0
if ((want_kwin)); then
    if needs_build kinetic-we "$DEV_ROOT/.kwin-drv" "$KWIN_BUILD"; then
        kwin_build=1
    fi
fi

noctalia_build=0
if ((want_noctalia)); then
    if needs_build noctalia "$DEV_ROOT/.noctalia-drv" "$NOCTALIA_BUILD"; then
        noctalia_build=1
    fi
fi

# Regenerate the session pieces when the compositor changed or a source
# script/template is newer than its generated copy.
session_refresh=0
if ((kwin_build)); then
    session_refresh=1
fi
if [[ ! -f "$DEV_ROOT/bin/start-kineticwe" ]] ||
    [[ ! -f "$DEV_ROOT/share/kineticwe/dev-env.sh" ]]; then
    session_refresh=1
fi
session_srcs=(
    "$REPO/scripts/start-kineticwe.sh"
    "$REPO/scripts/kineticwe-config-setup"
    "$REPO/scripts/kineticwe-session.target"
    "$REPO/scripts/kineticwe-shell.service.in"
)
session_dsts=(
    "$DEV_ROOT/bin/start-kineticwe"
    "$DEV_ROOT/lib/kineticwe/kineticwe-config-setup"
    "$DEV_ROOT/share/kineticwe/kineticwe-session.target"
    "$DEV_ROOT/share/kineticwe/kineticwe-shell.service"
)
for i in "${!session_srcs[@]}"; do
    if [[ ! -f "${session_dsts[i]}" ]] || [[ "${session_srcs[i]}" -nt "${session_dsts[i]}" ]]; then
        session_refresh=1
        break
    fi
done

if ((kwin_build || session_refresh)); then
    KWE_DEV_BUILD_KWIN="$kwin_build" run_phase kinetic-we kinetic-we
elif ((want_kwin)); then
    log "kinetic-we: unchanged"
fi

if ((noctalia_build)); then
    run_phase noctalia noctalia
elif ((want_noctalia)); then
    log "noctalia-kwe: unchanged"
fi

# The NixOS module adds the "KineticWE Dev" greeter entry when this marker
# exists, so a direct dev-build.sh run is enough after the next system switch.
mkdir -p "$KWE_STATE_DIR"
touch "$KWE_STATE_DIR/dev-enabled"

log "install prefix: $DEV_ROOT"
if ((kwin_build)); then
    log "kinetic-we rebuilt: log out and back in to restart the compositor"
fi
if ((noctalia_build)); then
    log "noctalia-kwe rebuilt: systemctl --user restart kineticwe-shell"
fi
if ((!kwin_build && !noctalia_build)); then
    if ((session_refresh)); then
        log "nothing rebuilt; session files refreshed in $DEV_ROOT"
    else
        log "nothing rebuilt; $DEV_ROOT is up to date"
    fi
fi
log "greeter: run 'dcli sync' once if \"KineticWE Dev\" is not listed"
