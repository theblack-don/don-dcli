function findScreen(name) {
    for (let i = 0; i < workspace.screens.length; i++) {
        if (workspace.screens[i].name === name) return workspace.screens[i];
    }
    return null;
}
const screen = findScreen("DP-1");
const target = workspace.desktops[2];
if (screen && target) {
    try {
        workspace.setCurrentDesktopForScreen(screen, target);
    } catch (e) {
        workspace.setCurrentDesktopForScreen(target, screen);
    }
}