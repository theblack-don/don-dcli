const fs = require('fs');
const { logPath, runNoctalia } = require('./desktop-integration');

const DEBUG_FILE = logPath('theme-debug.log');

// Theme key -> Noctalia theme name. Used by the arg-driven entry point (set-theme.js).
const THEMES = {
    'mocha-pink': 'Mocha Pink',
    'monochrome': 'Monochrome',
    'gruvbox': 'Gruvbox',
};

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

function extractArgs(runRequest) {
    // Firebot puts args in a few possible spots. Prefer the most specific ones.
    const sources = [
        runRequest?.command?.args,
        runRequest?.trigger?.metadata?.userCommand?.args,
        runRequest?.trigger?.metadata?.command?.args,
        runRequest?.args,
        runRequest?.userCommand?.args,
    ];

    for (const source of sources) {
        if (Array.isArray(source) && source.length > 0) {
            return source;
        }
    }

    const rawText = runRequest?.trigger?.metadata?.chatMessage?.rawText;
    if (typeof rawText === 'string' && rawText.trim()) {
        return rawText.trim().split(/\s+/);
    }

    return [];
}

function applyTheme(theme, runRequest) {
    return new Promise((resolve) => {
        const username = getUsername(runRequest);
        logDebug(`=== APPLY "${theme}" ===`);

        try {
            runNoctalia('plugin', 'theblackdon/theme-switcher:wallpaper-ipc', 'all', 'apply', theme);

            logDebug('Success!');
            resolve({
                success: true,
                errorMessage: `Theme changed to ${theme} by ${username}!`
            });
        } catch (error) {
            logDebug(`Failed: ${error.message}`);
            resolve({
                success: false,
                errorMessage: `Failed to change theme to ${theme}: ${error.message}`
            });
        }
    });
}

// The setting shown in the Firebot script UI. Fresh object each call so
// Firebot can safely mutate it when storing user values.
function buildParameters(defaultTheme) {
    return {
        themeName: {
            type: 'string',
            title: 'Theme Name',
            description: 'Noctalia theme to apply, exactly as named (e.g. `Mocha Pink`).',
            default: defaultTheme
        }
    };
}

function pick(value, fallback) {
    const str = value == null ? '' : String(value).trim();
    return str.length > 0 ? str : fallback;
}

// Builds a ready-to-export Firebot script for a fixed theme, while still
// letting the user override the theme in the script settings.
function createScript(defaultTheme, name) {
    return {
        getScriptManifest: () => ({
            name: name || `${defaultTheme} Theme`,
            description: `Applies the "${defaultTheme}" Noctalia theme.`,
            author: 'theblackdon',
            version: '1.0'
        }),
        getDefaultParameters: () => buildParameters(defaultTheme),
        run: (runRequest) => {
            const params = runRequest?.parameters ?? {};
            const theme = pick(params.themeName, defaultTheme);
            return applyTheme(theme, runRequest);
        }
    };
}

// Arg-driven entry point: settings win, otherwise look for a known theme key
// in the command args (e.g. `!theme gruvbox`).
exports.run = function (runRequest) {
    return new Promise((resolve) => {
        const params = runRequest?.parameters ?? {};
        if (pick(params.themeName, '')) {
            applyTheme(pick(params.themeName, ''), runRequest).then(resolve);
            return;
        }

        const args = extractArgs(runRequest);
        const key = args
            .map((a) => String(a).trim().toLowerCase().replace(/[\s_]+/g, '-'))
            .find((a) => THEMES[a]);

        const entry = key ? THEMES[key] : null;
        if (!entry) {
            logDebug(`Unknown theme. args=${JSON.stringify(args)}`);
            resolve({
                success: false,
                errorMessage: `Unknown theme. Available: ${Object.keys(THEMES).join(', ')}`
            });
            return;
        }

        applyTheme(entry, runRequest).then(resolve);
    });
};

exports.getScriptManifest = () => ({
    name: 'Set Theme',
    description: 'Applies a Noctalia theme.',
    author: 'theblackdon',
    version: '1.0'
});

exports.getDefaultParameters = () => buildParameters('Mocha Pink');
exports.createScript = createScript;
exports.THEMES = THEMES;
