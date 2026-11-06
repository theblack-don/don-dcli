const fs = require('fs');
const { runNoctalia } = require('./desktop-integration');

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
            runNoctalia('plugin', 'theblackdon/theme-switcher:wallpaper-ipc', 'all', 'random');

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
