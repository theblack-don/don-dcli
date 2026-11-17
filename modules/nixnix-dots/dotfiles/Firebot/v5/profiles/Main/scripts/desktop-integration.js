const { execFileSync, spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const HOME = os.homedir();
const USER = os.userInfo().username;

// Nix keeps binaries outside the FHS locations older distro setups assume.
// Search these first so a stale pre-NixOS build (e.g. PikaOS binaries in
// ~/.local/kineticwe) never wins over the working Nix build.
const NIX_BIN_DIRS = [
    path.join(HOME, '.nix-profile', 'bin'),
    '/run/current-system/sw/bin',
    `/etc/profiles/per-user/${USER}/bin`,
    '/nix/var/nix/profiles/default/bin',
];

function runtimeDir() {
    return process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;
}

function childPath() {
    return [...NIX_BIN_DIRS, process.env.PATH || ''].filter(Boolean).join(':');
}

// Firebot's wrapper exports an old gcc libstdc++ that shadows newer Nix
// closures (noctalia/umbriel). Drop only those entries for child processes.
function childEnv() {
    const env = { ...process.env, PATH: childPath() };
    if (!env.LD_LIBRARY_PATH) return env;

    const entries = env.LD_LIBRARY_PATH
        .split(':')
        .filter((entry) => !/\/nix\/store\/[^/]+-gcc-[^/]+-lib\/lib\/?$/.test(entry));

    if (entries.length > 0) {
        env.LD_LIBRARY_PATH = entries.join(':');
    } else {
        delete env.LD_LIBRARY_PATH;
    }
    return env;
}

// Firebot keeps its live profile under ~/.config/Firebot. The scripts are
// symlinked in from the dotfiles repo, so __dirname resolves to the repo and
// relative ../../../logs paths no longer reach Firebot's log directory.
function firebotConfigDir() {
    const configHome = process.env.XDG_CONFIG_HOME || path.join(HOME, '.config');
    return path.join(configHome, 'Firebot', 'v5');
}

function logPath(name) {
    return path.join(firebotConfigDir(), 'logs', name);
}

function displayName() {
    return process.env.WAYLAND_DISPLAY || 'wayland-0';
}

// KineticWE reports XDG_CURRENT_DESKTOP=KDE for Plasma compatibility, while
// XDG_SESSION_DESKTOP identifies the actual session as KineticWE. Firebot's
// desktop launcher also forces XDG_CURRENT_DESKTOP=KDE. Combine all hints so
// either source can identify the compositor.
function sessionDesktop() {
    return [
        process.env.XDG_CURRENT_DESKTOP,
        process.env.XDG_SESSION_DESKTOP,
        process.env.DESKTOP_SESSION,
    ]
        .filter(Boolean)
        .join(':')
        .toLowerCase();
}

function socketPath(family) {
    return path.join(runtimeDir(), `${family}-${displayName()}.sock`);
}

function isExecutable(file) {
    try {
        fs.accessSync(file, fs.constants.X_OK);
        return true;
    } catch (e) {
        return false;
    }
}

function findInPath(name) {
    const dirs = [...NIX_BIN_DIRS, ...(process.env.PATH || '').split(':')];
    for (const dir of dirs) {
        if (!dir) continue;
        const candidate = path.join(dir, name);
        if (isExecutable(candidate)) return candidate;
    }
    return null;
}

// A file can be executable and still be a foreign-ABI binary (the usual
// PikaOS/Fedora leftover on NixOS). Probe it once and cache the result so
// resolution never selects something the kernel cannot run.
const runnableCache = new Map();

function canRun(bin) {
    if (!bin) return false;
    if (runnableCache.has(bin)) return runnableCache.get(bin);

    let ok = false;
    try {
        execFileSync(bin, ['--version'], {
            stdio: 'ignore',
            timeout: 3000,
            env: childEnv(),
        });
        ok = true;
    } catch (e) {
        ok = false;
    }

    runnableCache.set(bin, ok);
    return ok;
}

// Noctalia's IPC socket differs between upstream and the KineticWE fork:
//   upstream (noctalia)      -> noctalia-<display>.sock
//   KineticWE (noctalia-kwe) -> noctalia-kwe-<display>.sock
// Order candidates by the session's compositor, then let resolveNoctalia()
// prefer an actually live socket over an installed-but-idle binary.
function uniqueCandidates(candidates) {
    const seen = new Set();
    return candidates.filter((candidate) => {
        if (!candidate.bin || seen.has(candidate.bin)) return false;
        seen.add(candidate.bin);
        return true;
    });
}

function noctaliaCandidates() {
    const stable = uniqueCandidates([
        { family: 'noctalia', bin: findInPath('noctalia') },
        { family: 'noctalia', bin: path.join(HOME, '.nix-profile/bin/noctalia') },
        { family: 'noctalia', bin: '/run/current-system/sw/bin/noctalia' },
        { family: 'noctalia', bin: `/etc/profiles/per-user/${USER}/bin/noctalia` },
        { family: 'noctalia', bin: '/usr/local/bin/noctalia' },
        { family: 'noctalia', bin: '/usr/bin/noctalia' },
    ]);
    const kwe = uniqueCandidates([
        { family: 'noctalia-kwe', bin: findInPath('noctalia-kwe') },
        { family: 'noctalia-kwe', bin: path.join(HOME, '.nix-profile/bin/noctalia-kwe') },
        { family: 'noctalia-kwe', bin: '/run/current-system/sw/bin/noctalia-kwe' },
        { family: 'noctalia-kwe', bin: `/etc/profiles/per-user/${USER}/bin/noctalia-kwe` },
        // Legacy distro builds live here. Keep them last: on NixOS they are
        // usually still on disk but cannot run (no FHS dynamic loader).
        { family: 'noctalia-kwe', bin: path.join(HOME, '.local/bin/noctalia-kwe') },
        { family: 'noctalia-kwe', bin: '/usr/local/bin/noctalia-kwe' },
        { family: 'noctalia-kwe', bin: '/usr/bin/noctalia-kwe' },
        { family: 'noctalia-kwe', bin: path.join(HOME, '.local/kineticwe/bin/noctalia-kwe') },
        {
            family: 'noctalia-kwe',
            bin: path.join(HOME, '.local/state/kineticwe/nix/noctalia/bin/noctalia-kwe'),
        },
    ]);

    const desktop = sessionDesktop();
    let ordered;
    if (desktop.includes('kinetic')) {
        ordered = kwe.concat(stable);
    } else {
        ordered = stable.concat(kwe);
    }

    return ordered.map((candidate) => ({
        ...candidate,
        sock: socketPath(candidate.family),
    }));
}

function preferredNoctaliaFamily() {
    const desktop = sessionDesktop();
    if (desktop.includes('kinetic')) return 'noctalia-kwe';
    if (
        desktop.includes('umbriel') ||
        desktop.includes('kwin') ||
        desktop.includes('plasma') ||
        desktop.includes('kde')
    ) {
        return 'noctalia';
    }
    return null;
}

function resolveNoctalia() {
    const candidates = noctaliaCandidates();
    const executable = candidates.filter(
        (candidate) => isExecutable(candidate.bin) && canRun(candidate.bin)
    );
    const live = executable.filter((candidate) => fs.existsSync(candidate.sock));
    const preferredFamily = preferredNoctaliaFamily();

    // A live socket is the strongest signal: it identifies the shell that is
    // actually running, even if the session environment is stale or overridden.
    if (preferredFamily) {
        const preferredLive = live.find((candidate) => candidate.family === preferredFamily);
        if (preferredLive) return preferredLive;
    }
    if (live.length > 0) return live[0];

    // No live socket yet; fall back to an installed binary for the session.
    if (preferredFamily) {
        const preferred = executable.find((candidate) => candidate.family === preferredFamily);
        if (preferred) return preferred;
    }

    return executable[0] || candidates[0];
}

function runNoctalia(...args) {
    const target = resolveNoctalia();

    return execFileSync(target.bin, ['msg', ...args], {
        env: childEnv(),
        encoding: 'utf8',
    });
}

function restartNoctalia() {
    const target = resolveNoctalia();
    const pkill = findInPath('pkill') || 'pkill';
    // Match process names exactly so we never kill unrelated commands whose
    // cmdline merely contains "noctalia" (e.g. the OBS wallpaper watcher).
    for (const name of ['noctalia-kwe', 'noctalia']) {
        try {
            execFileSync(pkill, ['-x', name], { stdio: 'ignore' });
        } catch (e) {
            // pkill exits 1 when no process matches; that is expected.
        }
    }

    return new Promise((resolve, reject) => {
        setTimeout(() => {
            try {
                const child = spawn(target.bin, [], {
                    detached: true,
                    stdio: 'ignore',
                    env: childEnv(),
                });
                child.on('error', reject);
                child.unref();
                resolve(target);
            } catch (error) {
                reject(error);
            }
        }, 2000);
    });
}

function isUmbriel() {
    const desktop = sessionDesktop();
    if (desktop.includes('umbriel')) return true;
    if (
        desktop.includes('kinetic') ||
        desktop.includes('kwin') ||
        desktop.includes('plasma') ||
        desktop.includes('kde')
    ) {
        return false;
    }

    return fs.existsSync(path.join(runtimeDir(), `umbriel-${displayName()}.sock`));
}

function umbrielBinary() {
    return (
        findInPath('umbriel') ||
        ['/usr/bin/umbriel', '/usr/local/bin/umbriel'].find(isExecutable) ||
        'umbriel'
    );
}

function runUmbriel(...args) {
    return execFileSync(umbrielBinary(), ['msg', ...args], {
        env: childEnv(),
        encoding: 'utf8',
    });
}

const QDBUS_NAMES = ['qdbus-qt6', 'qdbus6', 'qdbus'];

// qdbus lives on PATH on NixOS; the old /usr/bin locations do not exist.
function qdbusPath() {
    for (const name of QDBUS_NAMES) {
        const found = findInPath(name);
        if (found) return found;
    }
    return 'qdbus';
}

module.exports = {
    childPath,
    displayName,
    firebotConfigDir,
    isUmbriel,
    logPath,
    qdbusPath,
    resolveNoctalia,
    restartNoctalia,
    runNoctalia,
    runUmbriel,
    runtimeDir,
    sessionDesktop,
};
