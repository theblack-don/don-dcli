const { spawn, execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const USER = os.userInfo().username;

// Common places these binaries might live after a distro change.
// Nix paths come first since fastfetch is installed via Nix here.
const TERMINAL_CANDIDATES = [
    path.join(HOME, '.nix-profile/bin/kitty'),
    '/run/current-system/sw/bin/kitty',
    '/nix/var/nix/profiles/default/bin/kitty',
    '/usr/bin/kitty',
    '/usr/local/bin/kitty',
    '/bin/kitty',
    path.join(HOME, '.local/bin/kitty')
];
const FASTFETCH_CANDIDATES = [
    path.join(HOME, '.nix-profile/bin/fastfetch'),
    path.join(HOME, '.local/state/nix/profiles/home-manager/bin/fastfetch'),
    '/run/current-system/sw/bin/fastfetch',
    '/nix/var/nix/profiles/default/bin/fastfetch',
    `/etc/profiles/per-user/${USER}/bin/fastfetch`,
    '/usr/bin/fastfetch',
    '/usr/local/bin/fastfetch',
    '/bin/fastfetch',
    path.join(HOME, '.local/bin/fastfetch')
];
const EXTRA_PATH = [
    path.join(HOME, '.nix-profile/bin'),
    '/run/current-system/sw/bin',
    '/nix/var/nix/profiles/default/bin',
    `/etc/profiles/per-user/${USER}/bin`
];

const DEBUG_FILE = path.join(__dirname, '..', '..', '..', 'logs', 'spawn-fastfetch-debug.log');

function logDebug(msg) {
    try {
        const timestamp = new Date().toISOString();
        fs.appendFileSync(DEBUG_FILE, `[${timestamp}] ${msg}\n`);
    } catch (e) {
        // Silent fail
    }
}

function getUsername(runRequest) {
    const metadata = runRequest?.trigger?.metadata;
    if (metadata?.username) return metadata.username;
    if (metadata?.userCommand?.commandSender) return metadata.userCommand.commandSender;
    if (runRequest?.command?.commandSender) return runRequest.command.commandSender;
    if (runRequest?.user?.name) return runRequest.user.name;
    return 'unknown';
}

// Resolve a binary: try known paths, then fall back to `which`.
function resolveBinary(candidates, name) {
    for (const c of candidates) {
        try {
            fs.accessSync(c, fs.constants.X_OK);
            return c;
        } catch (e) {
            // not here
        }
    }
    try {
        const found = execSync(`command -v ${name}`, {
            env: {
                ...process.env,
                PATH: [...EXTRA_PATH, '/usr/bin', '/bin', '/usr/local/bin', process.env.PATH || ''].join(':')
            },
            stdio: ['ignore', 'pipe', 'ignore']
        }).toString().trim();
        return found || null;
    } catch (e) {
        return null;
    }
}

function env() {
    return {
        ...process.env,
        PATH: [...EXTRA_PATH, '/usr/bin', '/bin', '/usr/local/bin', process.env.PATH || ''].join(':'),
        DBUS_SESSION_BUS_ADDRESS:
            process.env.DBUS_SESSION_BUS_ADDRESS || 'unix:path=/run/user/1000/bus',
        XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR || '/run/user/1000',
        DISPLAY: process.env.DISPLAY || ':0',
        WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-0'
    };
}

exports.run = function (runRequest) {
    return new Promise((resolve) => {
        logDebug('=== NEW SPAWN FASTFETCH RUN ===');
        const username = getUsername(runRequest);

        const kitty = resolveBinary(TERMINAL_CANDIDATES, 'kitty');
        const fastfetch = resolveBinary(FASTFETCH_CANDIDATES, 'fastfetch');

        if (!kitty) {
            logDebug('Failed: kitty not found');
            resolve({
                success: false,
                errorMessage: 'kitty was not found on this system. Install kitty or add its path.'
            });
            return;
        }
        if (!fastfetch) {
            logDebug('Failed: fastfetch not found');
            resolve({
                success: false,
                errorMessage: 'fastfetch was not found on this system. Install fastfetch or add its path.'
            });
            return;
        }

        logDebug(`resolved kitty=${kitty} fastfetch=${fastfetch}`);

        let child;
        try {
            child = spawn(kitty, ['--hold', fastfetch], {
                env: env(),
                detached: true,
                stdio: 'ignore'
            });
        } catch (error) {
            logDebug(`Failed to spawn (sync): ${error.message}`);
            resolve({
                success: false,
                errorMessage: `Failed to spawn fastfetch: ${error.message}`
            });
            return;
        }

        // Catch async failures (e.g. missing/broken binary) that the try/catch above miss.
        child.on('error', (error) => {
            logDebug(`child error: ${error.message}`);
            resolve({
                success: false,
                errorMessage: `Failed to spawn fastfetch: ${error.message}`
            });
        });

        child.on('exit', (code, signal) => {
            logDebug(`terminal exited code=${code} signal=${signal}`);
        });

        child.unref();
        logDebug(`spawned ${path.basename(kitty)} pid=${child.pid}`);
        resolve({
            success: true,
            errorMessage: `Floating fastfetch opened by ${username}!`
        });
    });
};
