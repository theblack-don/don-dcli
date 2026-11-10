const fs = require('fs');
const os = require('os');
const path = require('path');
const { logPath, runNoctalia } = require('./desktop-integration');

const WALLPAPER_DIR = path.join(os.homedir(), 'Pictures', 'Wallpapers');
const DEBUG_FILE = logPath('wallpaper-debug.log');

// Palette generation scheme applied whenever a numbered wallpaper is chosen.
const WALLPAPER_SCHEME = 'm3-content';

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

    // Fallback: parse raw chat text
    const rawText = runRequest?.trigger?.metadata?.chatMessage?.rawText;
    if (typeof rawText === 'string' && rawText.trim()) {
        return rawText.trim().split(/\s+/);
    }

    return [];
}

function extractNumber(args) {
    // Args look like ["!wallpaper", "55"]. Skip the command trigger.
    const candidates = args.slice(1);

    for (const arg of candidates) {
        const str = String(arg).trim();
        // Match a bare number or a number with an extension (e.g., "55.png")
        const match = str.match(/^(\d+)(?:\.\w+)?$/);
        if (match) {
            return match[1];
        }
    }

    return null;
}

function getNumericWallpapers() {
    const files = fs.readdirSync(WALLPAPER_DIR);
    return files.filter(file => /^\d+\.\w+$/.test(file));
}

exports.run = function (runRequest) {
    return new Promise((resolve) => {
        try {
            logDebug('=== NEW RUN ===');
        } catch (e) {}

        const username = getUsername(runRequest);
        const args = extractArgs(runRequest);
        logDebug(`Args: ${JSON.stringify(args)}, username: ${username}`);

        let number = extractNumber(args);

        // If no number provided, fall back to a random wallpaper instead of erroring.
        if (!number) {
            try {
                const wallpapers = getNumericWallpapers();
                if (wallpapers.length > 0) {
                    const randomWallpaper = wallpapers[Math.floor(Math.random() * wallpapers.length)];
                    number = path.parse(randomWallpaper).name;
                    logDebug(`No number provided; chose random wallpaper #${number}`);
                }
            } catch (err) {
                logDebug(`Failed to pick random fallback: ${err.message}`);
            }
        }

        if (!number) {
            logDebug('No number found and no wallpapers available');
            resolve({
                success: false,
                errorMessage: 'Please use !wallpaper <number> (e.g., !wallpaper 55).'
            });
            return;
        }

        let wallpapers;
        try {
            wallpapers = getNumericWallpapers();
        } catch (err) {
            logDebug(`Failed to read directory: ${err.message}`);
            resolve({
                success: false,
                errorMessage: `Could not read wallpaper directory: ${err.message}`
            });
            return;
        }

        const wallpaper = wallpapers.find(file => {
            // Strip leading zeros on both sides so "12" matches "0012.png" (and vice versa).
            const fileNumber = path.parse(file).name.replace(/^0+/, '');
            const requestedNumber = String(number).replace(/^0+/, '');
            return fileNumber === requestedNumber;
        });

        if (!wallpaper) {
            logDebug(`Wallpaper not found: ${number}`);
            resolve({
                success: false,
                errorMessage: `Wallpaper #${number} not found.`
            });
            return;
        }

        const wallpaperPath = path.join(WALLPAPER_DIR, wallpaper);
        logDebug(`Setting wallpaper: ${wallpaperPath}`);

        try {
            // Force the M3 Content scheme first so the new wallpaper is derived with it.
            try {
                runNoctalia('color-scheme-set', 'wallpaper', WALLPAPER_SCHEME);
                logDebug(`Palette scheme set to ${WALLPAPER_SCHEME}`);
            } catch (schemeError) {
                logDebug(`Failed to set scheme ${WALLPAPER_SCHEME}: ${schemeError.message}`);
            }

            runNoctalia('wallpaper-set', wallpaperPath);

            logDebug('Success!');
            resolve({
                success: true,
                errorMessage: `Wallpaper changed to #${number} by ${username}!`
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
