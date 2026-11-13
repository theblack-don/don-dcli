const win = workspace.activeWindow || workspace.activeClient;
if (win) {
    win.opacity = 0.65;
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
            "Set to 65%: " + (win.caption || win.resourceClass || "window"),
            [],
            {},
            3000
        );
    } catch (e) {}
}