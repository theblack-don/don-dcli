{ pkgs, system }:

{
  description = "dcli-managed static dotfiles for nixnix";

  # Explicit mappings only. Runtime state and secrets stay in the live
  # ~/.config directories and are never linked into this module.
  dotfiles = [
    # Whole-directory configs that are static in normal use.
    { source = "dotfiles/fastfetch"; target = "~/.config/fastfetch"; }
    { source = "dotfiles/ghostty"; target = "~/.config/ghostty"; }
    { source = "dotfiles/zed"; target = "~/.config/zed"; }
    { source = "dotfiles/tuios"; target = "~/.config/tuios"; }
    { source = "dotfiles/veadotube"; target = "~/.config/veadotube"; }
    { source = "dotfiles/noctalia"; target = "~/.config/noctalia"; }
    { source = "dotfiles/noctalia-kwe"; target = "~/.config/noctalia-kwe"; }
    { source = "dotfiles/fifine-control-deck"; target = "~/.config/fifine-control-deck"; }

    # fish: static files only; fish_variables and generated conf.d stay live.
    { source = "dotfiles/fish/config.fish"; target = "~/.config/fish/config.fish"; }
    { source = "dotfiles/fish/conf.d/user.fish"; target = "~/.config/fish/conf.d/user.fish"; }
    { source = "dotfiles/fish/conf.d/nix.fish"; target = "~/.config/fish/conf.d/nix.fish"; }
    { source = "dotfiles/fish/conf.d/rustup.fish"; target = "~/.config/fish/conf.d/rustup.fish"; }
    { source = "dotfiles/fish/functions"; target = "~/.config/fish/functions"; }
    { source = "dotfiles/fish/completions"; target = "~/.config/fish/completions"; }

    # kitty: generated current/cosmic theme files stay live.
    { source = "dotfiles/kitty/kitty.conf"; target = "~/.config/kitty/kitty.conf"; }
    { source = "dotfiles/kitty/dank-tabs.conf"; target = "~/.config/kitty/dank-tabs.conf"; }
    { source = "dotfiles/kitty/dank-theme.conf"; target = "~/.config/kitty/dank-theme.conf"; }
    { source = "dotfiles/kitty/scripts"; target = "~/.config/kitty/scripts"; }
    { source = "dotfiles/kitty/sessions"; target = "~/.config/kitty/sessions"; }
    { source = "dotfiles/kitty/themes"; target = "~/.config/kitty/themes"; }

    # qutebrowser: static config only. autoconfig.yml, quickmarks, bookmarks,
    # qsettings and generated noctalia colors stay live.
    { source = "dotfiles/qutebrowser/config.py"; target = "~/.config/qutebrowser/config.py"; }
    { source = "dotfiles/qutebrowser/userscripts/qute-bitwarden"; target = "~/.config/qutebrowser/userscripts/qute-bitwarden"; }

    # Nemo bookmarks only; preferences live in dconf.
    { source = "dotfiles/gtk-3.0/bookmarks"; target = "~/.config/gtk-3.0/bookmarks"; }

    # Firebot: static config only. auth-twitch.json, integrations.json,
    # db/, logs/, backups/, clips/ and caches stay live.
    { source = "dotfiles/Firebot/v5/global-settings.json"; target = "~/.config/Firebot/v5/global-settings.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/settings.json"; target = "~/.config/Firebot/v5/profiles/Main/settings.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/channel-rewards.json"; target = "~/.config/Firebot/v5/profiles/Main/channel-rewards.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/custom-quick-actions.json"; target = "~/.config/Firebot/v5/profiles/Main/custom-quick-actions.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/games.json"; target = "~/.config/Firebot/v5/profiles/Main/games.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/hotkeys.json"; target = "~/.config/Firebot/v5/profiles/Main/hotkeys.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/notifications.json"; target = "~/.config/Firebot/v5/profiles/Main/notifications.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/overlay-widgets.json"; target = "~/.config/Firebot/v5/profiles/Main/overlay-widgets.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/power-ups.json"; target = "~/.config/Firebot/v5/profiles/Main/power-ups.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/ranks.json"; target = "~/.config/Firebot/v5/profiles/Main/ranks.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/scheduled-tasks.json"; target = "~/.config/Firebot/v5/profiles/Main/scheduled-tasks.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/sort-tags.json"; target = "~/.config/Firebot/v5/profiles/Main/sort-tags.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/startup-scripts-config.json"; target = "~/.config/Firebot/v5/profiles/Main/startup-scripts-config.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/timers.json"; target = "~/.config/Firebot/v5/profiles/Main/timers.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/variable-macros.json"; target = "~/.config/Firebot/v5/profiles/Main/variable-macros.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/webhooks.json"; target = "~/.config/Firebot/v5/profiles/Main/webhooks.json"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/chat"; target = "~/.config/Firebot/v5/profiles/Main/chat"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/counters"; target = "~/.config/Firebot/v5/profiles/Main/counters"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/currency"; target = "~/.config/Firebot/v5/profiles/Main/currency"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/effects"; target = "~/.config/Firebot/v5/profiles/Main/effects"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/events"; target = "~/.config/Firebot/v5/profiles/Main/events"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/roles"; target = "~/.config/Firebot/v5/profiles/Main/roles"; }
    { source = "dotfiles/Firebot/v5/profiles/Main/scripts"; target = "~/.config/Firebot/v5/profiles/Main/scripts"; }

    # OBS: static profile files only. service.json, scenes, plugin_config,
    # logs and profiler data stay live.
    { source = "dotfiles/obs-studio/user.ini"; target = "~/.config/obs-studio/user.ini"; }
    { source = "dotfiles/obs-studio/themes"; target = "~/.config/obs-studio/themes"; }
    { source = "dotfiles/obs-studio/basic/profiles/169/basic.ini"; target = "~/.config/obs-studio/basic/profiles/169/basic.ini"; }
    { source = "dotfiles/obs-studio/basic/profiles/169/streamEncoder.json"; target = "~/.config/obs-studio/basic/profiles/169/streamEncoder.json"; }
    { source = "dotfiles/obs-studio/basic/profiles/219/basic.ini"; target = "~/.config/obs-studio/basic/profiles/219/basic.ini"; }
    { source = "dotfiles/obs-studio/basic/profiles/219/streamEncoder.json"; target = "~/.config/obs-studio/basic/profiles/219/streamEncoder.json"; }
    { source = "dotfiles/obs-studio/basic/profiles/219/recordEncoder.json"; target = "~/.config/obs-studio/basic/profiles/219/recordEncoder.json"; }

    # Kineticwe: static settings only. kineticwe.kwe and the generated
    # keybind files are runtime state, like KDE state files, sessions and
    # output/EDID config.
    { source = "dotfiles/kineticwe/appearance.kwe"; target = "~/.config/kineticwe/appearance.kwe"; }
    { source = "dotfiles/kineticwe/decoration.colors"; target = "~/.config/kineticwe/decoration.colors"; }
    { source = "dotfiles/kineticwe/kinetic-settings.kwe"; target = "~/.config/kineticwe/kinetic-settings.kwe"; }
    { source = "dotfiles/kineticwe/rules.kwe"; target = "~/.config/kineticwe/rules.kwe"; }
    { source = "dotfiles/kineticwe/lsfg-vk/conf.toml"; target = "~/.config/kineticwe/lsfg-vk/conf.toml"; }
  ];
}
