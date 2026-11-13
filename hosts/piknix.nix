{ system, pkgs }:

{
  host = "piknix";
  description = "PikaOS (Debian/apt) on the second NVMe partition";

  # Native package manager (apt).
  package_manager = "apt";

  # Sequential processing keeps hooks out of sudo (per-user nix profiles).
  module_processing = "sequential";

  # Packages managed by apt; re-add helium/fluxer via flatpak/nix if wanted.
  packages = [
    "kitty"
    "nemo"
    "gwenview"
    "mpv"
    "ark"
    "chromium"
    "quickshell"
    "mangohud"
    "power-profiles-daemon"
    "tailscale"
  ];

  # Flatpak packages.
  flatpak_packages = [
    "com.obsproject.Studio"
  ];

  # Flatpak scope: "user" (default) or "system"; flathub is system-wide here.
  flatpak_scope = "system";

  # Nix profile packages (no home-manager).
  nix_packages = [
    "helix"
    "mpvpaper"
    "fastfetch"
    "matugen"
    "btop"
    "eza"
    "htop"
    "nil"
    "nixd"
    "zoxide"
    "nix-output-monitor"
    "tuios"
  ];

  # GUI nix packages (nix graphics stack).
  nix_gui_packages = [
  ];

  # GUI packages wrapped with host GPU libs (nixGL-style).
  nix_wrapped_packages = [
  ];

  enabled_modules = [
    # "dotfiles"
  ];

  # packages = if system.hardware.has_nvidia then [ "nvidia-driver" ] else [];

  # Backup configuration.
  config_backups = {
    enabled = false;
    max_backups = 5;
  };

  # System backup configuration (timeshift/snapper).
  system_backups = {
    enabled = false;
    backup_on_sync = false;
    backup_on_update = false;
    tool = "timeshift";
    snapper_config = "root";
    max_backups = 5;
  };

  # Nix configuration.
  nix = {
    enabled = true;
    nix_profile_enabled = true;
    home_manager_enabled = false;
    flake_enabled = false;
  };

  # NVIDIA driver protection is Fedora/dnf only; dcli is a no-op on apt.
}
