const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const DEBUG_FILE = path.join(__dirname, '..', '..', '..', 'logs', 'switch-to-lgl-debug.log');
const KWIN_SCRIPT = path.join(__dirname, 'kwin-switch-lgl.js');
const QDBUS_PATH =
    ['/usr/bin/qdbus-qt6', '/usr/bin/qdbus6', '/usr/bin/qdbus'].find((p) => fs.existsSync(p)) ||
    'qdbus6';

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

function writeKwinScript(output, desktop) {
    const script = `
function findScreen(name) {
    for (let i = 0; i < workspace.screens.length; i++) {
        if (workspace.screens[i].name === name) return workspace.screens[i];
    }
    return null;
}
const screen = findScreen("${output}");
const target = workspace.desktops[${desktop - 1}];
if (screen && target) {
    try {
        workspace.setCurrentDesktopForScreen(screen, target);
    } catch (e) {
        workspace.setCurrentDesktopForScreen(target, screen);
    }
}
`.trim();

    fs.writeFileSync(KWIN_SCRIPT, script, 'utf8');
    logDebug(`Wrote kwin script: ${KWIN_SCRIPT}`);
}

exports.getScriptManifest = function () {
    return {
        name: 'Switch to LGL',
        description: 'Switches to a specific virtual desktop on a specific monitor output via KWin',
        version: '1.0.0',
        author: 'don',
        website: '',
        startupOnly: false,
        firebotVersion: '5'
    };
};

exports.getDefaultParameters = function () {
    return {
        output: {
            type: 'string',
            default: 'DP-1',
            description: 'Monitor output (KScreen name) whose desktop should change'
        },
        desktop: {
            type: 'number',
            default: 3,
            description: 'Virtual desktop number to switch to'
        }
    };
};

exports.run = async function (runRequest) {
    logDebug('=== NEW SWITCH TO LGL RUN ===');

    const params = runRequest.parameters || {};
    const output = params.output || 'DP-1';
    const desktop = Number(params.desktop) || 3;

    const username = getUsername(runRequest);
    logDebug(`username: ${username}, output: ${output}, desktop: ${desktop}`);

    try {
        writeKwinScript(output, desktop);

        // Unique name each run so KWin always loads fresh script contents
        const pluginName = `firebot-switch-lgl-${Date.now()}`;

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

        logDebug('Success!');
        return {
            success: true,
            errorMessage: `Switched to desktop ${desktop} on ${output} by ${username}!`
        };
    } catch (error) {
        logDebug(`Failed: ${error.message}`);
        if (error.stderr) logDebug(`stderr: ${error.stderr}`);
        if (error.stdout) logDebug(`stdout: ${error.stdout}`);
        return {
            success: false,
            errorMessage: `Failed to switch desktop: ${error.message}`
        };
    }
};