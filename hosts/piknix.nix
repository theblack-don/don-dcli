{ system, pkgs }:

{
  host = "piknix";
  description = "PikaOS (Debian/apt) on the second NVMe partition";

  # native package manager
  package_manager = "apt";

  # module hooks through sudo (root), breaking per-user nix profile installs.
  module_processing = "sequential";

  # packages managed by native package manager (apt)
  # re-add them via flatpak/nix if wanted. quickshell may need the PikaOS repo.
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
    # "helium-bin"
    # "fluxer-canary"
  ];

  # flatpak packages (installed via flatpak)
  flatpak_packages = [
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
    "eza"
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

  enabled_modules = [
    # "dotfiles"
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

  # NVIDIA driver protection is Fedora/dnf only; dcli is a no-op on apt.
  # nvidia = {
  #   enabled = true;
  #   driver = "auto";        # auto | akmod | kmod | dkms | proprietary
  #   check_updates = true;   # report newer driver versions before updating
  #   notify = true;          # desktop notification when a module build finishes
  # };
}
