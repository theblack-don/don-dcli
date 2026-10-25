// Veadotube State Switcher
// Sets a veadotube mini state, waits, then sets another. Defaults:
//   Hulk Don  -> (5 minutes) ->  Normal
//
// Uses veado-set, which talks to veadotube's built-in WebSocket control API
// (the same server its web remote uses). No ydotool, kdotool, window focus or
// root required — and it works no matter which window is focused.
//
//   veado-set ~/.local/bin/veado-set   (installed alongside this script)
//
// The old version of this script pressed <Delete>, waited 5 minutes, then
// pressed <Insert>. Delete is bound to "Hulk Don", but Insert was bound to no
// state, so the second half did nothing. State names are used here instead.

const { execFile } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const os = require('os');
const path = require('path');

const execFileAsync = promisify(execFile);

const DEBUG_FILE = '/var/home/don/.config/Firebot/v5/logs/veadotube-state-debug.log';
const VEADO_SET = path.join(os.homedir(), '.local/bin', 'veado-set');

function logDebug(msg) {
    try {
        fs.appendFileSync(DEBUG_FILE, `[${new Date().toISOString()}] ${msg}\n`);
    } catch (e) {}
}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

function getUsername(runRequest) {
    const metadata = runRequest?.trigger?.metadata;
    if (metadata?.username) return metadata.username;
    if (metadata?.userCommand?.commandSender) return metadata.userCommand.commandSender;
    if (runRequest?.command?.commandSender) return runRequest.command.commandSender;
    if (runRequest?.user?.name) return runRequest.user.name;
    return 'unknown';
}

async function setState(state) {
    if (!state) throw new Error('no state name given');
    const { stderr } = await execFileAsync(VEADO_SET, [state], { timeout: 15000 });
    if (stderr) logDebug(`veado-set ${state}: ${stderr.trim()}`);
    logDebug(`set -> ${state}`);
}

exports.getScriptManifest = function () {
    return {
        name: 'Veadotube State Switcher',
        description: 'Sets one veadotube state, waits, then sets another (default Hulk Don -> 5 min -> Normal).',
        version: '2.0.0',
        author: 'don',
        website: '',
        startupOnly: false,
        firebotVersion: '5'
    };
};

exports.getDefaultParameters = function () {
    return Promise.resolve({
        startState: {
            type: 'string',
            description: 'State to switch to first',
            secondaryDescription: 'Default "Hulk Don"',
            default: 'Hulk Don'
        },
        endState: {
            type: 'string',
            description: 'State to switch to after the wait',
            secondaryDescription: 'Default "Normal"',
            default: 'Normal'
        },
        waitMinutes: {
            type: 'number',
            description: 'Minutes to wait before switching to the end state',
            secondaryDescription: 'Default 5',
            default: 5
        }
    });
};

exports.run = async function (runRequest) {
    const username = getUsername(runRequest);
    const params = runRequest?.parameters ?? {};
    const startState = String(params.startState ?? 'Hulk Don').trim();
    const endState = String(params.endState ?? 'Normal').trim();
    const waitMinutes = Math.min(120, Math.max(0, Number(params.waitMinutes ?? 5) || 0));
    const waitMs = waitMinutes * 60 * 1000;

    logDebug('=== NEW VEADOTUBE SET STATE RUN ===');
    logDebug(`username: ${username}, start="${startState}", end="${endState}", wait=${waitMinutes}m`);

    try {
        await setState(startState);
        await sleep(waitMs);
        await setState(endState);
        return { success: true, errorMessage: `${startState} -> ${endState} (triggered by ${username})` };
    } catch (error) {
        const detail = (error.stderr || error.message || '').toString().trim();
        logDebug(`Failed: ${detail}`);
        return { success: false, errorMessage: `Veadotube state switch failed: ${detail}` };
    }
};
