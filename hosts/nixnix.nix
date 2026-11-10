{ system, pkgs }:

{
  host = "nixnix";
  description = "NixOS workstation (replaces piknix/fednix), shared /home partition";

  # Sequential module processing runs the kineticwe-dev hook as the invoking
  # user (parallel mode runs hooks through sudo, which breaks per-user nix
  # profiles).
  module_processing = "sequential";

  enabled_modules = [
    "kineticwe-dev"
    "flatpak"
  ];

  # User applications: installed with `nix profile add`.
  # `nix profile add nixpkgs#foo` also works imperatively; declaring it here
  # makes `dcli sync` converge the profile back to this list.
  nix_packages = [
    "helix"
    "nemo"
    "ghostty"
    "kitty"
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
    "xdg-desktop-portal-gtk"
    "opencode"
    "chromium"
    "equibop"
    "helium#default"
    # Core CLI only.
    "hermes#minimal"
    # nixpkgs' quickshell is built without Qt Multimedia; this wrapper adds
    # it, matched to the same nixpkgs. See ~/Projects/kwepaperpicker/nix/.
    "path:/home/don/Projects/kwepaperpicker/nix#quickshell"
    # Built from the upstream flake instead of nixpkgs.
    "vm-curator#default"
    "ffmpeg"
  ];

  # System-side packages (environment.systemPackages via dcli-system.nix).
  nixos = {
    system_packages = [
      "git"
      "curl"
      "wget"
      "wl-clipboard"
      "wireguard-tools"
      "smartmontools"
      "wtype"
      "playerctl"
      "telegram-desktop"
      "nemo-fileroller"
      "kdePackages.ark"
      # QEMU/KVM stack for vm-curator (user TUI installed via nix profile).
      "qemu"
      "swtpm"          # TPM 2.0 emulation (Windows 11)
      "virt-viewer"    # SPICE-app display backend
      "passt"          # user-mode networking backend
      "dnsmasq"        # DHCP for managed virtual networks
    ];

    config = ''
      { pkgs, ... }: {
        # Fish as the login shell.
        programs.fish.enable = true;
        users.users.don.shell = pkgs.fish;

        # Direct /dev/input access for veadotube mini's raw-input hotkeys
        # (its pkexec helper cannot work inside the FHS sandbox).
        # ydotool group lets the fifine deck's hotkey buttons use ydotoold.
        # kvm group gives access to /dev/kvm for QEMU/vm-curator.
        users.users.don.extraGroups = [ "input" "ydotool" "kvm" ];

        # AppImage support for the fifine Control Deck (and other AppImages).
        programs.appimage.enable = true;
        programs.appimage.binfmt = true;
        # Qt6's xcb fallback needs libxcb-cursor inside the FHS.
        programs.appimage.package = pkgs.appimage-run.override {
          extraPkgs = pkgs: [ pkgs.xcb-util-cursor ];
        };

        # ydotoold system daemon for the deck's hotkey buttons.
        programs.ydotool.enable = true;

        # fifine Control Deck USB permissions (VID 3142). Numbered 70 so the
        # uaccess tag is set before systemd's 73-seat-late.rules.
        # Use services.udev.packages instead of environment.etc: /etc/udev/rules.d
        # is a symlink to the read-only udev-rules store path, so writing a
        # child file through environment.etc fails at build time.
        services.udev.packages = [
          (pkgs.writeTextDir "etc/udev/rules.d/70-fifine-deck.rules"
            "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"3142\", MODE=\"0660\", GROUP=\"users\", TAG+=\"uaccess\"\nKERNEL==\"hidraw*\", ATTRS{idVendor}==\"3142\", MODE=\"0660\", GROUP=\"users\", TAG+=\"uaccess\"\n")
        ];
        # Controller configs
        hardware.steam-hardware.enable = true;

        # AMD-V (SVM) must be enabled in firmware; load KVM explicitly because
        # the installer generated no module entry while it was disabled.
        boot.kernelModules = [ "kvm-amd" ];

        # Desktop
        services.flatpak.enable = true;

        # Fonts and GTK file pickers from the old host setups.
        fonts.fontconfig.enable = true;

        # Firmware updates and networking essentials
        services.fwupd.enable = true;
        networking.networkmanager.enable = true;

        # Garbage
        nix.settings.auto-optimise-store = true;
        nix.gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
        };
      }
    '';
  };

  nix = {
    enabled = true;
    nixos_enabled = true;        # dcli sync ends with nixos-rebuild switch
    nix_profile_enabled = true;  # user apps via nix profile
    home_manager_enabled = false;
    flake_enabled = false;
  };

  # Flake inputs used by the NixOS system module live in the kineticwe-dev
  # module (noctalia-greeter). Add host-wide ones here.
  nix_flakes = {
    vm-curator = {
      url = "github:mroboff/vm-curator";
    };
    helium = {
      url = "github:amaanq/helium-flake";
    };
    hermes = {
      url = "github:NousResearch/hermes-agent";
    };
  };

  config_backups = {
    enabled = true;
    max_backups = 5;
  };

  # timeshift/snapper are not used on this host.
  system_backups = {
    enabled = false;
    backup_on_sync = false;
    backup_on_update = false;
    max_backups = 5;
  };
}
