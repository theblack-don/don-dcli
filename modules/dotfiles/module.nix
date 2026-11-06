{ pkgs, system }:

{
  description = "Personal dotfiles (kitty, fish, nemo, OBS, Firebot, Noctalia/KineticWE)";

  # The source of truth is the top-level dotfiles/ directory in this repo.
  # dcli only auto-syncs a module's own dotfiles/ directory, so every target
  # is listed explicitly. Sources are relative to this module directory.
  dotfiles = [
    # ~/.config applications
    { source = "../../dotfiles/kitty"; target = "~/.config/kitty"; }
    { source = "../../dotfiles/fish"; target = "~/.config/fish"; }
    { source = "../../dotfiles/fastfetch"; target = "~/.config/fastfetch"; }
    { source = "../../dotfiles/ghostty"; target = "~/.config/ghostty"; }
    { source = "../../dotfiles/nemo/bookmark-metadata"; target = "~/.config/nemo/bookmark-metadata"; }
    { source = "../../dotfiles/nemo-terminal"; target = "~/.config/nemo-terminal"; }
    { source = "../../dotfiles/noctalia-kwe"; target = "~/.config/noctalia-kwe"; }
    { source = "../../dotfiles/kineticwe"; target = "~/.config/kineticwe"; }

    # User scripts (fifine deck buttons + KineticWE keybinds)
    { source = "../../dotfiles/bin/firebot-command"; target = "~/.local/bin/firebot-command"; }
    { source = "../../dotfiles/bin/noctalia-msg"; target = "~/.local/bin/noctalia-msg"; }
    { source = "../../dotfiles/bin/veado-set"; target = "~/.local/bin/veado-set"; }

    # fifine Control Deck button/profile config
    { source = "../../dotfiles/fifine-control-deck/config.json"; target = "~/.config/fifine-control-deck/config.json"; }

    # Noctalia/OBS wallpaper + theme helpers (Noctalia post_hooks call these)
    { source = "../../dotfiles/bin/noctalia-colors-to-obs.sh"; target = "~/bin/noctalia-colors-to-obs.sh"; }
    { source = "../../dotfiles/bin/noctalia-wallpaper-to-obs.sh"; target = "~/bin/noctalia-wallpaper-to-obs.sh"; }
    { source = "../../dotfiles/bin/obs-wallpaper-watcher.sh"; target = "~/bin/obs-wallpaper-watcher.sh"; }
    { source = "../../dotfiles/bin/noctalia-konsole-reload.sh"; target = "~/bin/noctalia-konsole-reload.sh"; }
    { source = "../../dotfiles/bin/noctalia-qutebrowser-reload.sh"; target = "~/bin/noctalia-qutebrowser-reload.sh"; }
    { source = "../../dotfiles/systemd/user/obs-wallpaper-sync.service"; target = "~/.config/systemd/user/obs-wallpaper-sync.service"; }

    # Nemo bookmarks and terminal extension
    { source = "../../dotfiles/nemo/bookmarks"; target = "~/.config/gtk-3.0/bookmarks"; }
    { source = "../../dotfiles/nemo-python/extensions/nemo_terminal_theme.py"; target = "~/.local/share/nemo-python/extensions/nemo_terminal_theme.py"; }

    # OBS Studio (Flatpak). OBS writes global.ini/plugin_config under its
    # Flatpak config dir, but user.ini/basic under ~/.config because its
    # global.ini sets [Locations] Configuration=/home/don/.config.
    { source = "../../dotfiles/obs-studio/global.ini"; target = "~/.var/app/com.obsproject.Studio/config/obs-studio/global.ini"; }
    { source = "../../dotfiles/obs-studio/user.ini"; target = "~/.config/obs-studio/user.ini"; }
    { source = "../../dotfiles/obs-studio/basic"; target = "~/.config/obs-studio/basic"; }
    { source = "../../dotfiles/obs-studio/plugin_config/aitum-multistream"; target = "~/.var/app/com.obsproject.Studio/config/obs-studio/plugin_config/aitum-multistream"; }
    { source = "../../dotfiles/obs-studio/plugin_config/obs-websocket"; target = "~/.var/app/com.obsproject.Studio/config/obs-studio/plugin_config/obs-websocket"; }
    { source = "../../dotfiles/obs-studio/plugin_config/vertical-canvas"; target = "~/.var/app/com.obsproject.Studio/config/obs-studio/plugin_config/vertical-canvas"; }

    # Firebot v5
    { source = "../../dotfiles/Firebot/v5/profiles/Main"; target = "~/.config/Firebot/v5/profiles/Main"; }
    { source = "../../dotfiles/Firebot/v5/global-settings.json"; target = "~/.config/Firebot/v5/global-settings.json"; }
    { source = "../../dotfiles/Firebot/v5/overlay.html"; target = "~/.config/Firebot/v5/overlay.html"; }
    { source = "../../dotfiles/Firebot/v5/overlay-resources"; target = "~/.config/Firebot/v5/overlay-resources"; }
  ];
}
