{ system, pkgs }:

{
  host = "fednix";

  # native package manager (preserved from the old config.yaml pointer)
  package_manager = "dnf";

  # process modules in declared order. Sequential mode honors
  # run_hooks_as_user, which the kineticwe-dev hook needs: parallel mode runs
  # module hooks through sudo (root), breaking per-user nix profile installs.
  module_processing = "sequential";

  # COPR repositories enabled before native packages
  copr_repos = [
    "theblackdon/dcli"                    # dcli
    "theblackdon/kwee"                    # kineticwe (kineticwe-dev module)
    "bieszczaders/kernel-cachyos-addons"  # scx-scheds/scx-tools (lgl deps)
    "imput/helium"                        # helium-bin
    "lemmy/favorites"                     # fluxer-canary
  ];

  # packages managed by native package manager (dnf)
  packages = [
    "kitty"
    "helium-bin"
    "nemo"
    "gwenview"
    "mpv"
    "ark"
    "chromium"
    "quickshell"
    "mangohud"
    "power-profiles-daemon"
    "tailscale"
    "fluxer-canary"
  ];

  # flatpak packages (installed via flatpak)
  flatpak_packages = [
    "com.discordapp.Discord"
    "org.telegram.desktop"
    "com.obsproject.Studio"
    "com.moonlight_stream.Moonlight"
  ];

  # flatpak installation scope: "user" (default) or "system"
  # (flathub remote on this machine is configured system-wide)
  flatpak_scope = "system";

  # nix packages (installed via nix profile — standalone, no home-manager)
  nix_packages = [
    "helix"
    "mpvpaper"
    "fastfetch"
    "matugen"
    "btop"
    "htop"
    "nil"
    "nixd"
    "zoxide"
    "nix-output-monitor"
  ];

  # GUI nix packages (nix graphics stack)
  nix_gui_packages = [
    "goverlay"
    "nwg-look"
  ];

  # GUI nix packages wrapped with host GPU libraries (nixGL-style)
  nix_wrapped_packages = [
    "ghostty"
    "protonplus"
  ];

  enabled_modules = [
    "dotfiles"
    "vm-stuff"
    "bootc"
    "lgl"
    # "kineticwe-dev"  # disabled: nix runtime + NVIDIA proprietary EGL does not
    #                   # work on Fedora (undefined symbols in libnvidia-eglcore);
    #                   # use ./build-rpm-dev.sh --kwin-only for the live session.
  ];

  # Conditional packages based on system facts
  # packages = if system.hardware.has_nvidia then [ "nvidia-driver" ] else [];

  # Backup configuration
  config_backups = {
    enabled = false;
    max_backups = 5;
  };

  # System backup configuration (timeshift/snapper)
  system_backups = {
    enabled = false;
    backup_on_sync = false;
    backup_on_update = false;
    tool = "timeshift";
    snapper_config = "root";
    max_backups = 5;
  };

  # Nix configuration
  nix = {
    enabled = true;
    nix_profile_enabled = true;
    home_manager_enabled = false;
    flake_enabled = false;
  };

  # NVIDIA driver protection (Fedora/dnf only)
  # Checks kernel/driver sync before updating, builds missing kernel modules
  # after the update, and notifies when the compilation finishes.
  nvidia = {
    enabled = true;
    driver = "auto";        # auto | akmod | kmod | dkms | proprietary
    check_updates = true;   # report newer driver versions before updating
    notify = true;          # desktop notification when a module build finishes
  };
}
