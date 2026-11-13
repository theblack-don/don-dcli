const { execSync } = require('child_process');
const fs = require('fs');
const { childPath, isUmbriel, logPath, qdbusPath, runtimeDir } = require('./desktop-integration');

const QDBUS_PATH = qdbusPath();
const DEBUG_FILE = logPath('kwin-zoom-debug.log');

function logDebug(msg) {
    try {
        const timestamp = new Date().toISOString();
        fs.appendFileSync(DEBUG_FILE, `[${timestamp}] ${msg}\n`);
    } catch (e) {}
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
        PATH: childPath(),
        DBUS_SESSION_BUS_ADDRESS:
            process.env.DBUS_SESSION_BUS_ADDRESS || `unix:path=${runtimeDir()}/bus`,
        XDG_RUNTIME_DIR: runtimeDir(),
        DISPLAY: process.env.DISPLAY || ':0',
        WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-0'
    };
}

// KineticWE renamed its KGlobalAccel component from "kwin" to "kineticwe".
// Try both so the script works under KineticWE and stock KWin.
const SHORTCUT_COMPONENTS = ['kineticwe', 'kwin'];
let shortcutComponent = null;

function invokeShortcut(name) {
    const candidates = shortcutComponent
        ? [shortcutComponent]
        : SHORTCUT_COMPONENTS.map((c) => `/component/${c}`);

    let lastError;
    for (const path of candidates) {
        try {
            execSync(
                `"${QDBUS_PATH}" org.kde.kglobalaccel "${path}" org.kde.kglobalaccel.Component.invokeShortcut "${name}"`,
                { env: dbusEnv() }
            );
            shortcutComponent = path;
            logDebug(`invoked: ${name} on ${path}`);
            return;
        } catch (error) {
            lastError = error;
        }
    }
    throw lastError || new Error(`No shortcut component found for "${name}"`);
}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.getScriptManifest = function () {
    return {
        name: 'KWin Zoom Effect',
        description: 'Zooms in, out, in, then resets to actual size when triggered',
        version: '1.0.0',
        author: 'don',
        website: '',
        startupOnly: false,
        firebotVersion: '5'
    };
};

exports.getDefaultParameters = function () {
    return new Promise((resolve) => {
        resolve({
            zoomDelay: {
                type: 'number',
                description: 'Delay between zoom steps (milliseconds)',
                secondaryDescription: 'Default 400 — raise it if zoom steps feel cut short',
                default: 400
            }
        });
    });
};

exports.run = async function (runRequest) {
    logDebug('=== NEW KWIN ZOOM RUN ===');
    const username = getUsername(runRequest);
    const delayMs = Math.min(5000, Math.max(50, Number(runRequest?.parameters?.zoomDelay) || 400));
    logDebug(`username: ${username}, delayMs: ${delayMs}`);

    if (isUmbriel()) {
        logDebug('Umbriel session detected; zoom requires KineticWE/KWin');
        return {
            success: false,
            errorMessage: 'You are not in KineticWE, so zoom will not work.'
        };
    }

    try {
        for (let i = 0; i < 5; i++) {
            invokeShortcut('view_zoom_in');
            await sleep(delayMs);
            invokeShortcut('view_zoom_out');
            await sleep(delayMs);
        }
        await sleep(delayMs);
        invokeShortcut('view_actual_size');
        await sleep(300);
        invokeShortcut('view_actual_size');
        logDebug('Success!');
        return {
            success: true,
            errorMessage: `Zoom effect triggered by ${username}!`
        };
    } catch (error) {
        logDebug(`Failed: ${error.message}`);
        if (error.stderr) logDebug(`stderr: ${error.stderr}`);
        return {
            success: false,
            errorMessage: `Failed to run zoom effect: ${error.message}`
        };
    }
};
