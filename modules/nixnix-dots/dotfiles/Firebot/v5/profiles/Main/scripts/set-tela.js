const { execSync, exec } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { logPath, restartNoctalia } = require('./desktop-integration');

const HOME = os.homedir();
const ICONS_DIR = path.join(HOME, '.local', 'share', 'icons');
const DEBUG_FILE = logPath('tela-debug.log');

const CONFIG_FILES = {
    qt5ct: path.join(HOME, '.config', 'qt5ct', 'qt5ct.conf'),
    qt6ct: path.join(HOME, '.config', 'qt6ct', 'qt6ct.conf'),
    gtk3: path.join(HOME, '.config', 'gtk-3.0', 'settings.ini'),
    gtk4: path.join(HOME, '.config', 'gtk-4.0', 'settings.ini'),
    xsettingsd: path.join(HOME, '.config', 'xsettingsd', 'xsettingsd.conf')
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

function getAvailableTelaThemes() {
    try {
        const entries = fs.readdirSync(ICONS_DIR);
        return entries
            .filter(name => name.startsWith('Tela'))
            .sort();
    } catch (e) {
        logDebug('Failed to read icons dir: ' + e.message);
        return [];
    }
}

function normalizeInput(input) {
    if (!input) return null;
    const lower = input.toLowerCase().trim();

    // Direct match for exact theme names
    const available = getAvailableTelaThemes();

    // If they typed exactly the theme name
    const exact = available.find(a => a.toLowerCase() === lower);
    if (exact) return exact;

    // Parse color and variant
    const parts = lower.split(/\s+/);

    // Handle "tela" by itself
    if (parts.length === 1 && parts[0] === 'tela') {
        return 'Tela';
    }

    // Remove "tela" prefix if present
    if (parts[0] === 'tela') parts.shift();

    const color = parts[0];
    const variant = parts[1]; // dark, light, or undefined

    if (!color) return 'Tela';

    // Try explicit variant first
    if (variant) {
        const candidate = `Tela-${color}-${variant}`;
        if (available.includes(candidate)) return candidate;
    }

    // Default to dark variant if available
    const darkCandidate = `Tela-${color}-dark`;
    if (available.includes(darkCandidate)) return darkCandidate;

    // Try base color variant
    const baseCandidate = `Tela-${color}`;
    if (available.includes(baseCandidate)) return baseCandidate;

    // Try light variant as last resort
    const lightCandidate = `Tela-${color}-light`;
    if (available.includes(lightCandidate)) return lightCandidate;

    return null;
}

function updateConfigFile(filePath, newTheme, fileType) {
    try {
        let content = fs.readFileSync(filePath, 'utf8');

        if (fileType === 'qt') {
            content = content.replace(/^icon_theme=.*/m, `icon_theme=${newTheme}`);
        } else if (fileType === 'xsettingsd') {
            content = content.replace(/^Net\/IconThemeName .*/m, `Net/IconThemeName "${newTheme}"`);
        } else {
            content = content.replace(/^gtk-icon-theme-name=.*/m, `gtk-icon-theme-name=${newTheme}`);
        }

        fs.writeFileSync(filePath, content);
        logDebug(`Updated ${filePath} to ${newTheme}`);
        return true;
    } catch (e) {
        logDebug(`Failed to update ${filePath}: ${e.message}`);
        return false;
    }
}

exports.run = function (runRequest) {
    return new Promise((resolve) => {
        try {
            logDebug('=== NEW TELA RUN ===');
        } catch (e) {}

        const username = getUsername(runRequest);

        // Extract arguments from Firebot
        const args = extractArgs(runRequest);
        logDebug(`Args: ${JSON.stringify(args)}`);

        // Skip the command trigger and join the rest
        const rawInput = args.slice(1).join(' ').trim();
        logDebug(`Raw input: ${rawInput}`);

        const themeName = normalizeInput(rawInput);
        logDebug(`Resolved theme: ${themeName}`);

        if (!themeName) {
            const available = getAvailableTelaThemes();
            const colorList = [...new Set(available.map(t => {
                const match = t.match(/^Tela-([a-z]+)(?:-(dark|light))?$/);
                return match && match[1] !== 'dark' && match[1] !== 'light' ? match[1] : null;
            }).filter(Boolean))].sort();

            resolve({
                success: false,
                errorMessage: `Invalid color. Available colors: ${colorList.join(', ')}. Use !tela <color> [dark|light]`
            });
            return;
        }

        // Update all config files
        let updatedCount = 0;

        if (updateConfigFile(CONFIG_FILES.qt5ct, themeName, 'qt')) updatedCount++;
        if (updateConfigFile(CONFIG_FILES.qt6ct, themeName, 'qt')) updatedCount++;
        if (updateConfigFile(CONFIG_FILES.gtk3, themeName, 'gtk')) updatedCount++;
        if (updateConfigFile(CONFIG_FILES.gtk4, themeName, 'gtk')) updatedCount++;
        if (updateConfigFile(CONFIG_FILES.xsettingsd, themeName, 'xsettingsd')) updatedCount++;

        if (updatedCount === 0) {
            resolve({
                success: false,
                errorMessage: 'Failed to update any config files.'
            });
            return;
        }

        // Update KDE Plasma icon theme (kdeglobals) for Dolphin/Qt apps
        try {
            execSync(`kwriteconfig6 --file kdeglobals --group Icons --key Theme "${themeName}"`, { stdio: 'ignore' });
            logDebug('kdeglobals Icons/Theme updated');
        } catch (e) {
            logDebug('kwriteconfig6 kdeglobals failed: ' + e.message);
        }

        // Update gsettings to notify running GTK apps immediately
        try {
            execSync(`gsettings set org.gnome.desktop.interface icon-theme "${themeName}"`, { stdio: 'ignore' });
            logDebug('gsettings icon-theme updated');
        } catch (e) {
            logDebug('gsettings failed: ' + e.message);
        }

        // Restart xsettingsd so GTK apps pick up the new icon theme
        try {
            let hasXsettingsd = false;
            try {
                execSync('command -v xsettingsd', { stdio: 'ignore' });
                hasXsettingsd = true;
            } catch (e) {
                // Not installed (common on NixOS unless explicitly added).
            }

            if (!hasXsettingsd) {
                logDebug('xsettingsd not installed; skipping restart');
            } else {
                execSync('pkill -x xsettingsd || true', { stdio: 'ignore' });
                execSync('sleep 0.5', { stdio: 'ignore' });
                exec('xsettingsd', { stdio: 'ignore' }, (err) => {
                    if (err) {
                        logDebug('xsettingsd restart error: ' + err.message);
                    } else {
                        logDebug('xsettingsd restarted successfully');
                    }
                });
            }
        } catch (e) {
            logDebug('Failed to restart xsettingsd: ' + e.message);
        }

        // Reload whichever Noctalia shell is running (noctalia on Umbriel,
        // noctalia-kwe on KineticWE) so it picks up the new icon theme.
        // Crystal dock is no longer used, so it is intentionally not reloaded.
        try {
            restartNoctalia()
                .then(() => logDebug('noctalia reloaded successfully'))
                .catch((err) => logDebug('noctalia reload error: ' + err.message));
        } catch (e) {
            logDebug('Failed to reload noctalia: ' + e.message);
            // Don't fail the whole command if reload fails
        }

        resolve({
            success: true,
            errorMessage: `Icon theme changed to ${themeName} by ${username}!`
        });
    });
};
