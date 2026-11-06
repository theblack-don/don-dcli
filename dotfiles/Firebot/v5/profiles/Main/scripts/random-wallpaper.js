const fs = require('fs');
const os = require('os');
const path = require('path');
const { runNoctalia } = require('./desktop-integration');

const WALLPAPER_DIR = path.join(os.homedir(), 'Pictures', 'Wallpapers');
const DEBUG_FILE = path.join(__dirname, '..', '..', '..', 'logs', 'random-wallpaper-debug.log');

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
            logDebug('=== NEW RANDOM WALLPAPER RUN ===');
        } catch (e) {}

        const username = getUsername(runRequest);

        let files;
        try {
            files = fs.readdirSync(WALLPAPER_DIR);
        } catch (err) {
            logDebug(`Failed to read directory: ${err.message}`);
            resolve({
                success: false,
                errorMessage: `Could not read wallpaper directory: ${err.message}`
            });
            return;
        }

        // Filter to only files with numeric names (e.g., "5.png", "42.jpg")
        const numericFiles = files.filter(file => {
            const baseName = path.parse(file).name;
            return /^\d+$/.test(baseName);
        });

        logDebug(`Found ${numericFiles.length} numeric wallpapers`);

        if (numericFiles.length === 0) {
            resolve({
                success: false,
                errorMessage: 'No numeric wallpapers found in the directory.'
            });
            return;
        }

        // Pick a random wallpaper
        const randomIndex = Math.floor(Math.random() * numericFiles.length);
        const wallpaper = numericFiles[randomIndex];
        const number = path.parse(wallpaper).name;

        logDebug(`Selected random wallpaper: ${wallpaper} (number: ${number})`);

        const wallpaperPath = path.join(WALLPAPER_DIR, wallpaper);

        try {
            runNoctalia('wallpaper-set', wallpaperPath);

            logDebug('Success!');
            resolve({
                success: true,
                errorMessage: `Random wallpaper #${number} chosen by ${username}!`
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
