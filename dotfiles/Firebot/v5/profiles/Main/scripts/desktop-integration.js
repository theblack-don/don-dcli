const { execFileSync, exec } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const HOME = os.homedir();

function runtimeDir() {
    return process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;
}

function displayName() {
    return process.env.WAYLAND_DISPLAY || 'wayland-0';
}

function sessionDesktop() {
    return String(
        process.env.XDG_CURRENT_DESKTOP ||
        process.env.XDG_SESSION_DESKTOP ||
        process.env.DESKTOP_SESSION ||
        ''
    ).toLowerCase();
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

// Noctalia's IPC socket differs between upstream and the KineticWE fork:
//   upstream (/usr/bin/noctalia)      -> noctalia-<display>.sock
//   KineticWE (/usr/bin/noctalia-kwe) -> noctalia-kwe-<display>.sock
// Prefer the binaries belonging to the running session, then fall back to
// whichever socket is actually live.
function noctaliaCandidates() {
    const stable = [
        { family: 'noctalia', bin: '/usr/bin/noctalia' },
        { family: 'noctalia', bin: '/usr/local/bin/noctalia' },
        { family: 'noctalia', bin: path.join(HOME, '.nix-profile/bin/noctalia') },
    ];
    const kwe = [
        { family: 'noctalia-kwe', bin: path.join(HOME, '.local/bin/noctalia-kwe') },
        { family: 'noctalia-kwe', bin: '/usr/bin/noctalia-kwe' },
        { family: 'noctalia-kwe', bin: path.join(HOME, '.nix-profile/bin/noctalia-kwe') },
        {
            family: 'noctalia-kwe',
            bin: path.join(HOME, '.local/state/kineticwe/nix/noctalia/bin/noctalia-kwe'),
        },
    ];

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
    const executable = candidates.filter((candidate) => isExecutable(candidate.bin));
    const live = executable.find((candidate) => fs.existsSync(candidate.sock));
    const preferredFamily = preferredNoctaliaFamily();

    if (preferredFamily) {
        const preferred = executable.filter((candidate) => candidate.family === preferredFamily);
        const preferredLive = preferred.find((candidate) => fs.existsSync(candidate.sock));

        if (preferredLive) return preferredLive;
        if (preferred.length > 0) return preferred[0];
    }

    return live || executable[0] || candidates[0];
}

function quote(value) {
    return `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function runNoctalia(...args) {
    const target = resolveNoctalia();

    return execFileSync(target.bin, ['msg', ...args], {
        env: {
            ...process.env,
            PATH: '/usr/bin:/usr/local/bin:' + (process.env.PATH || ''),
        },
        encoding: 'utf8',
    });
}

function restartNoctalia() {
    const target = resolveNoctalia();
    // Match process names exactly so we never kill unrelated commands whose
    // cmdline merely contains "noctalia" (e.g. the OBS wallpaper watcher).
    const command = [
        'pkill -x noctalia-kwe || true',
        'pkill -x noctalia || true',
        'sleep 2',
        `setsid ${quote(target.bin)} >/dev/null 2>&1 </dev/null &`,
    ].join('; ');

    return new Promise((resolve, reject) => {
        exec(command, { shell: '/bin/bash', stdio: 'ignore' }, (error) => {
            if (error) {
                reject(error);
            } else {
                resolve(target);
            }
        });
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
    return ['/usr/bin/umbriel', '/usr/local/bin/umbriel'].find(isExecutable) || 'umbriel';
}

function runUmbriel(...args) {
    return execFileSync(umbrielBinary(), ['msg', ...args], {
        env: {
            ...process.env,
            PATH: '/usr/bin:/usr/local/bin:' + (process.env.PATH || ''),
        },
        encoding: 'utf8',
    });
}

module.exports = {
    displayName,
    isUmbriel,
    resolveNoctalia,
    restartNoctalia,
    runNoctalia,
    runUmbriel,
    runtimeDir,
    sessionDesktop,
};
