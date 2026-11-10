const fs = require('fs');
const { logPath, runNoctalia } = require('./desktop-integration');

const DEBUG_FILE = logPath('toggle-bar-debug.log');

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
            runNoctalia('bar-toggle');

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
