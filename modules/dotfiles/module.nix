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

    # Nemo bookmarks and terminal extension
    { source = "../../dotfiles/nemo/bookmarks"; target = "~/.config/gtk-3.0/bookmarks"; }
    { source = "../../dotfiles/nemo-python/extensions/nemo_terminal_theme.py"; target = "~/.local/share/nemo-python/extensions/nemo_terminal_theme.py"; }

    # OBS Studio
    { source = "../../dotfiles/obs-studio/global.ini"; target = "~/.config/obs-studio/global.ini"; }
    { source = "../../dotfiles/obs-studio/user.ini"; target = "~/.config/obs-studio/user.ini"; }
    { source = "../../dotfiles/obs-studio/basic"; target = "~/.config/obs-studio/basic"; }
    { source = "../../dotfiles/obs-studio/plugin_config/aitum-multistream"; target = "~/.config/obs-studio/plugin_config/aitum-multistream"; }
    { source = "../../dotfiles/obs-studio/plugin_config/obs-websocket"; target = "~/.config/obs-studio/plugin_config/obs-websocket"; }
    { source = "../../dotfiles/obs-studio/plugin_config/vertical-canvas/config.json"; target = "~/.config/obs-studio/plugin_config/vertical-canvas/config.json"; }

    # Firebot v5
    { source = "../../dotfiles/Firebot/v5/profiles/Main"; target = "~/.config/Firebot/v5/profiles/Main"; }
    { source = "../../dotfiles/Firebot/v5/global-settings.json"; target = "~/.config/Firebot/v5/global-settings.json"; }
    { source = "../../dotfiles/Firebot/v5/overlay.html"; target = "~/.config/Firebot/v5/overlay.html"; }
    { source = "../../dotfiles/Firebot/v5/overlay-resources"; target = "~/.config/Firebot/v5/overlay-resources"; }
  ];
}
