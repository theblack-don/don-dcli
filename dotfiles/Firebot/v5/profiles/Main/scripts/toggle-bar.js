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
const DEBUG_FILE = '/var/home/don/.config/Firebot/v5/logs/toggle-bar-debug.log';

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
        logDebug('=== NEW TOGGLE BAR RUN ===');
        const username = getUsername(runRequest);

        try {
            execSync(`"${NOCTALIA_PATH}" msg bar-toggle`, {
                env: {
                    ...process.env,
                    PATH: '/usr/bin:' + (process.env.PATH || '')
                }
            });

            logDebug('Success!');
            resolve({
                success: true,
                errorMessage: `Bar toggled by ${username}!`
            });
        } catch (error) {
            logDebug(`Failed: ${error.message}`);
            resolve({
                success: false,
                errorMessage: `Failed to toggle bar: ${error.message}`
            });
        }
    });
};
