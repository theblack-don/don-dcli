const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const QDBUS_PATH =
    ['/usr/bin/qdbus-qt6', '/usr/bin/qdbus6', '/usr/bin/qdbus'].find((p) => fs.existsSync(p)) ||
    'qdbus6';
const DEBUG_FILE = path.join(__dirname, '..', '..', '..', 'logs', 'toggle-fullscreen-debug.log');

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

function dbusEnv() {
    return {
        ...process.env,
        PATH: '/usr/bin:/bin:' + (process.env.PATH || ''),
        DBUS_SESSION_BUS_ADDRESS:
            process.env.DBUS_SESSION_BUS_ADDRESS || 'unix:path=/run/user/1000/bus',
        XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR || '/run/user/1000',
        DISPLAY: process.env.DISPLAY || ':0',
        WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-0'
    };
}

// KineticWE renamed its KGlobalAccel component from "kwin" to "kineticwe".
// Try both so the script works under KineticWE and stock KWin.
const SHORTCUT_COMPONENTS = ['/component/kineticwe', '/component/kwin'];

function invokeShortcut(name) {
    let lastError;
    for (const path of SHORTCUT_COMPONENTS) {
        try {
            execSync(
                `"${QDBUS_PATH}" org.kde.kglobalaccel "${path}" org.kde.kglobalaccel.Component.invokeShortcut "${name}"`,
                { env: dbusEnv() }
            );
            logDebug(`invoked: ${name} on ${path}`);
            return;
        } catch (error) {
            lastError = error;
        }
    }
    throw lastError || new Error(`No shortcut component found for "${name}"`);
}

exports.run = function (runRequest) {
    return new Promise((resolve) => {
        logDebug('=== NEW TOGGLE FULLSCREEN RUN ===');
        const username = getUsername(runRequest);

        try {
            invokeShortcut('Window Fullscreen');

            logDebug('Success!');
            resolve({
                success: true,
                errorMessage: `Fullscreen toggled by ${username}!`
            });
        } catch (error) {
            logDebug(`Failed: ${error.message}`);
            resolve({
                success: false,
                errorMessage: `Failed to toggle fullscreen: ${error.message}`
            });
        }
    });
};
