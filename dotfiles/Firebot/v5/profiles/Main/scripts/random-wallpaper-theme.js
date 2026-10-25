const { execSync } = require('child_process');
const fs = require('fs');

// Noctalia's IPC socket name differs per build/install:
//   system build (/usr/bin)              -> noctalia-<display>.sock
//   older local dev build (~/.local/bin) -> noctalia-kwe-<display>.sock
// Pick the binary whose socket is actually live so this keeps working
// regardless of which install is currently running.
function resolveNoctaliaPath() {
    const runtimeDir = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;
    const display = process.env.WAYLAND_DISPLAY || 'wayland-0';
    const candidates = [
        { bin: '/usr/bin/noctalia-kwe', sock: `${runtimeDir}/noctalia-${display}.sock` },
        { bin: '/home/don/.local/bin/noctalia-kwe', sock: `${runtimeDir}/noctalia-kwe-${display}.sock` },
    ];
    const live = candidates.find((c) => fs.existsSync(c.sock) && fs.existsSync(c.bin));
    const anyBin = candidates.find((c) => fs.existsSync(c.bin));
    return (live || anyBin || candidates[0]).bin;
}

const NOCTALIA_PATH = resolveNoctaliaPath();
const DEBUG_FILE = '/home/don/.config/Firebot/v5/logs/random-wallpaper-theme-debug.log';

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

exports.run = function (runRequest) {
    return new Promise((resolve) => {
        try {
            logDebug('=== NEW RANDOM THEME WALLPAPER RUN ===');
        } catch (e) {}

        const username = getUsername(runRequest);

        // Dispatch a "random" event to the theme-switcher plugin's always-running
        // wallpaper-ipc service (a plugin *panel* such as :wallpapers is only
        // reachable over IPC while it is open, which is why this used to fail with
        // "matched plugin entry is not ready").
        try {
            execSync(`"${NOCTALIA_PATH}" msg plugin theblackdon/theme-switcher:wallpaper-ipc all random`, {
                env: {
                    ...process.env,
                    PATH: '/usr/bin:' + (process.env.PATH || '')
                }
            });

            logDebug('Success!');
            resolve({
                success: true,
                errorMessage: `Random theme wallpaper chosen by ${username}!`
            });
        } catch (error) {
            logDebug(`Failed to set wallpaper: ${error.message}`);
            resolve({
                success: false,
                errorMessage: `Failed to set wallpaper: ${error.message}`
            });
        }
    });
};
