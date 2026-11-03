{ system, pkgs }:

{
  host = "piktop";
  description = "PikaOS laptop (NVIDIA)";

  # native package manager
  package_manager = "apt";

  # keep sequential so module hooks run as the user (per-user nix profile)
  module_processing = "sequential";

  # packages managed by dnf
  packages = [
    "kitty"
    "nemo"
    "nemo-fileroller"
    "gwenview"
    "mpv"
    "ark"
    "chromium"
    "nwg-look"
    "ghostty"
    "power-profiles-daemon"
  ];

  # flatpak packages (installed via flatpak)
  flatpak_packages = [
  ];

  # flatpak installation scope: "user" (default) or "system"
  flatpak_scope = "system";

  # nix packages (installed via nix profile — standalone, no home-manager)
  nix_packages = [
    "helix"
    "fastfetch"
    "btop"
    "htop"
    "nil"
    "nixd"
    "zoxide"
    "nix-output-monitor"
  ];

  # GUI nix packages (nix graphics stack)
  nix_gui_packages = [
  ];

  # GUI nix packages wrapped with host GPU libraries (nixGL-style)
  nix_wrapped_packages = [
  ];

  # start empty; enable as the laptop gets set up
  enabled_modules = [
    # "dotfiles"
    # "vm-stuff"
    # "bootc"
    # "lgl"
  ];

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

  # # NVIDIA driver protection (Fedora/dnf only)
  # nvidia = {
  #   enabled = true;
  #   driver = "auto";        # auto | akmod | kmod | dkms | proprietary
  #   check_updates = true;   # report newer driver versions before updating
  #   notify = true;          # desktop notification when a module build finishes
  # };
}
