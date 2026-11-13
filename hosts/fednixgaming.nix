{ system, pkgs }:

{
  host = "fednixgaming";
  description = "Fedora gaming desktop (NVIDIA)";

  # Native package manager (dnf).
  package_manager = "dnf";

  # Parallel hooks run via sudo; sequential honors run_hooks_as_user.
  module_processing = "parallel";

  # COPR repositories (enabled before native packages).
  copr_repos = [
    "theblackdon/dcli"                    # dcli
    "theblackdon/kwee"                    # kineticwe
    "bieszczaders/kernel-cachyos-addons"  # scx-scheds/scx-tools
    "imput/helium"                        # helium-bin
  ];

  # Packages managed by dnf.
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
    "sunshine"
  ];

  # Flatpak packages.
  flatpak_packages = [
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
    "htop"
    "nil"
    "nixd"
    "zoxide"
    "nix-output-monitor"
  ];

  # GUI nix packages (nix graphics stack).
  nix_gui_packages = [
    "goverlay"
    "nwg-look"
  ];

  # GUI packages wrapped with host GPU libs (nixGL-style).
  nix_wrapped_packages = [
    "ghostty"
    "protonplus"
  ];

  enabled_modules = [
    # "kineticwe-dev"  # disabled on Fedora (NVIDIA EGL breaks); use build-rpm-dev.sh --kwin-only.
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

  # NVIDIA driver protection (Fedora/dnf only): checks sync and rebuilds modules.
  nvidia = {
    enabled = true;
    driver = "auto";        # auto | akmod | kmod | dkms | proprietary
    check_updates = true;   # report newer driver versions before updating
    notify = true;          # desktop notification when a module build finishes
  };
}
