const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { childPath, isUmbriel, logPath, qdbusPath, runtimeDir } = require('./desktop-integration');

const OPACITY = 0.65;
// Time to alt-tab / click another window after hitting Test Effects
const DELAY_MS = 3000;
// Derive paths from this script's location so they survive home/config moves
// (e.g. /var/home -> /home) instead of hardcoding an absolute path.
const DEBUG_FILE = logPath('set-window-opacity-debug.log');
const KWIN_SCRIPT = path.join(__dirname, 'kwin-set-opacity.js');
const QDBUS_PATH = qdbusPath();

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
        PATH: childPath(),
        DBUS_SESSION_BUS_ADDRESS:
            process.env.DBUS_SESSION_BUS_ADDRESS || `unix:path=${runtimeDir()}/bus`,
        XDG_RUNTIME_DIR: runtimeDir(),
        DISPLAY: process.env.DISPLAY || ':0',
        WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-0'
    };
}

function qdbus(args, opts = {}) {
    const env = dbusEnv();
    const cmd = `"${QDBUS_PATH}" ${args}`;
    logDebug(`qdbus: ${cmd}`);
    return execSync(cmd, {
        env,
        encoding: 'utf8',
        stdio: opts.ignore ? 'ignore' : ['ignore', 'pipe', 'pipe']
    });
}

function writeKwinScript(opacity) {
    const script = `
const win = workspace.activeWindow || workspace.activeClient;
if (win) {
    win.opacity = ${opacity};
    try {
        callDBus(
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications",
            "Notify",
            "firebot-opacity",
            0,
            "",
            "Window Opacity",
            "Set to ${Math.round(opacity * 100)}%: " + (win.caption || win.resourceClass || "window"),
            [],
            {},
            3000
        );
    } catch (e) {}
}
`.trim();

    fs.writeFileSync(KWIN_SCRIPT, script, 'utf8');
    logDebug(`Wrote kwin script: ${KWIN_SCRIPT}`);
}

function setActiveWindowOpacity(opacity) {
    writeKwinScript(opacity);

    // Unique name each run so KWin always loads fresh script contents
    const pluginName = `firebot-set-window-opacity-${Date.now()}`;

    const id = String(
        qdbus(
            `org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "${KWIN_SCRIPT}" "${pluginName}"`
        )
    ).trim();
    logDebug(`loadScript id=${id} name=${pluginName}`);

    if (!id || Number.isNaN(Number(id))) {
        throw new Error(`KWin loadScript failed, got: ${id}`);
    }

    try {
        qdbus(`org.kde.KWin /Scripting org.kde.kwin.Scripting.start`, { ignore: true });
    } catch (e) {
        logDebug(`start: ${e.message}`);
    }

    qdbus(
        `org.kde.KWin /Scripting/Script${id} org.kde.kwin.Script.run`,
        { ignore: true }
    );
    logDebug('Script.run called');

    // Give KWin a moment to apply before unloading
    execSync('sleep 0.3', { env: dbusEnv() });

    try {
        qdbus(
            `org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "${pluginName}"`,
            { ignore: true }
        );
    } catch (e) {
        logDebug(`cleanup unload: ${e.message}`);
    }
}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

exports.getScriptManifest = function () {
    return {
        name: 'Set Window Opacity',
        description: 'Sets the current (non-Firebot) window opacity to 65% via KWin',
        version: '1.1.0',
        author: 'don',
        website: '',
        startupOnly: false,
        firebotVersion: '5'
    };
};

exports.run = async function (runRequest) {
    logDebug('=== NEW SET WINDOW OPACITY RUN ===');
    logDebug(`cwd=${process.cwd()}`);
    logDebug(`DBUS=${process.env.DBUS_SESSION_BUS_ADDRESS || '(unset)'}`);

    const username = getUsername(runRequest);
    logDebug(`username: ${username}, opacity: ${OPACITY}, delayMs: ${DELAY_MS}`);

    try {
        if (isUmbriel()) {
            logDebug('Umbriel session detected; window opacity requires KineticWE/KWin');
            return {
                success: false,
                errorMessage: 'You are not in KineticWE, so window opacity will not work.'
            };
        }

        if (DELAY_MS > 0) {
            logDebug(`Waiting ${DELAY_MS}ms — focus the target window now`);
            await sleep(DELAY_MS);
        }

        setActiveWindowOpacity(OPACITY);
        logDebug('Success!');
        return {
            success: true,
            errorMessage: `Window set to ${Math.round(OPACITY * 100)}% opacity by ${username}!`
        };
    } catch (error) {
        logDebug(`Failed: ${error.message}`);
        if (error.stderr) logDebug(`stderr: ${error.stderr}`);
        if (error.stdout) logDebug(`stdout: ${error.stdout}`);
        return {
            success: false,
            errorMessage: `Failed to set window opacity: ${error.message}`
        };
    }
};
