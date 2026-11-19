{ system, pkgs }:

let
  # scx-loader is not in nixos-26.05; pin nixos-unstable for the module + package.
  nixpkgsUnstable = "github:NixOS/nixpkgs/177d0540942fb205af6993b1d5fa0b57799e09f8";
in
{
  host = "nixnix";
  description = "NixOS workstation";

  # Sequential runs the kineticwe-dev hook as the user, not via sudo.
  module_processing = "sequential";

  enabled_modules = [
    "kineticwe-dev"
    "flatpak"
    "nixnix-dots"
    "umbriel"
  ];

  # User apps via nix profile; dcli sync converges the profile to this list.
  nix_packages = [
    "helix"
    "nemo"
    "ghostty"
    "kitty"
    "mpvpaper"
    "fastfetch"
    "matugen"
    "zed-editor"
    "btop"
    "gh"
    "eza"
    "htop"
    "nil"
    "nixd"
    "zoxide"
    "mpv"
    "nix-output-monitor"
    "tuios"
    "herdr-desktop"
    "xdg-desktop-portal-gtk"
    "opencode"
    "chromium"
    # Temporary pin: nixpkgs-unstable still marks qutebrowser insecure.
    "github:NixOS/nixpkgs/4bc82a230ef72f82a7c62ed32435e570b26bc76f#qutebrowser"
    "helium#default"
    # Wrapper adds Qt Multimedia to quickshell; see ~/Projects/kwepaperpicker/nix/.
    "path:/home/don/Projects/kwepaperpicker/nix#quickshell"
    # Upstream flake instead of nixpkgs.
    "vm-curator#default"
    "lgl-papercutter#default"
    "lgl-emoji-picker#default"
    "lgl-scheduler-manager#default"
    "lgl-text-editor#default"
    "ffmpeg"
  ];

  # System packages (environment.systemPackages).
  nixos = {
    system_packages = [
      "git"
      "curl"
      "wget"
      "skopeo"
      "wl-clipboard"
      "wireguard-tools"
      "smartmontools"
      "wtype"
      "playerctl"
      # Needed for Global Menu Plugin
      "(python3.withPackages (ps: [ ps.dbus-python ps.pygobject3 ]))"
      "telegram-desktop"
      "nemo-fileroller"
      "kdePackages.ark"
      "gnome-keyring"
      "seahorse"
      # QEMU/KVM stack for vm-curator
      "qemu"
      "swtpm"          # TPM 2.0 emulation (Windows 11)
      "virt-viewer"    # SPICE-app display backend
      "passt"          # user-mode networking backend
      "dnsmasq"        # DHCP for managed virtual
      "hunspellDicts.en_US"   # English dictionary for GTK/libspelling/Qt apps
      "hunspell"              # CLI for verification
      "adwaita-icon-theme"    # fallback for GTK symbolic icons (Punktfunk etc.)
      "gsettings-desktop-schemas"  # org.gnome.desktop.interface for GTK4
    ];

    config = ''
      { pkgs, ... }:
      let
        unstable = builtins.getFlake "${nixpkgsUnstable}";
        unstablePkgs = unstable.legacyPackages.''${pkgs.system};
      in
      {
        imports = [
          (unstable.outPath + "/nixos/modules/services/scheduling/scx-loader.nix")
        ];

        # Fish as the login shell.
        programs.fish.enable = true;
        users.users.don.shell = pkgs.fish;

        # input: veadotube; ydotool: fifine deck; kvm: QEMU/vm-curator.
        users.users.don.extraGroups = [ "input" "ydotool" "kvm" ];

        # AppImage support (fifine Control Deck).
        programs.appimage.enable = true;
        programs.appimage.binfmt = true;
        # Qt6 xcb fallback needs libxcb-cursor inside the FHS.
        programs.appimage.package = pkgs.appimage-run.override {
          extraPkgs = pkgs: [ pkgs.xcb-util-cursor ];
        };

        # ydotoold system daemon for the deck's hotkey buttons.
        programs.ydotool.enable = true;

        # fifine deck udev rules; 70 so uaccess applies before systemd seat rules.
        services.udev.packages = [
          (pkgs.writeTextDir "etc/udev/rules.d/70-fifine-deck.rules"
            "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"3142\", MODE=\"0660\", GROUP=\"users\", TAG+=\"uaccess\"\nKERNEL==\"hidraw*\", ATTRS{idVendor}==\"3142\", MODE=\"0660\", GROUP=\"users\", TAG+=\"uaccess\"\n")
        ];
        # Controller configs
        hardware.steam-hardware.enable = true;

        # AMD-V needs firmware support; load kvm-amd explicitly (installer omitted it).
        boot.kernelModules = [ "kvm-amd" ];

        # Desktop
        services.flatpak.enable = true;

        # D-Bus dconf service: GTK4 reads icon/theme settings through GSettings.
        programs.dconf.enable = true;

        # Register Adwaita Sans/Mono with fontconfig (systemPackages alone is not scanned).
        fonts.packages = [ pkgs.adwaita-fonts ];

        # Punktfunk streaming host (Punktfunk + GameStream/Moonlight clients).
        # Disabled: not in use, and the host build stalls every update. Uncomment to re-enable.
        # services.punktfunk.host = {
        #   enable = true;
        #   users = [ "don" ];
        #   gamestream = true;
        #   openFirewall = true;
        #   desktopSession = true;   # KDE/KineticWE desktop login
        #   settings = { RUST_LOG = "info"; };
        # };

        # Native Punktfunk client (replaces the Flatpak).
        services.punktfunk.client = {
          enable = true;
          openFirewall = true;
        };

        # Fonts and GTK file pickers.
        fonts.fontconfig.enable = true;

        # Gnome Keyring
        services.gnome.gnome-keyring.enable = true; 

        # Podman 
        virtualisation.podman = {
          enable = true;
          defaultNetwork.settings.dns_enabled = true;
        };

        # Firmware updates and networking essentials
        services.fwupd.enable = true;
        networking.networkmanager.enable = true;

        # TuneD provides the PPD-compatible power profile interface.
        services.power-profiles-daemon.enable = false;
        services.upower.enable = true;
        services.tuned = {
          enable = true;
          ppdSupport = true;   # default, but explicit
        };

        # Scheduler services (scx-loader from nixpkgs-unstable).
        services.scx-loader = {
          enable = true;
          package = unstablePkgs.scx-loader;
          schedsPackages = [ unstablePkgs.scx.full ];
          config.default_sched = "scx_bpfland";
        };

        # Garbage collection.
        nix.settings.auto-optimise-store = true;
        nix.settings.substituters = [ "https://nix.unom.io" ];
        nix.settings.trusted-public-keys = [ "punktfunk-cache-1:yhOJmHxzg6tzXpxSFzlYn6Pc6r0jHprsWqt8MZC654o=" ];
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
    allow_unfree = true;         # permits unfree packages (e.g. discord)
    home_manager_enabled = false;
    flake_enabled = false;
  };

  # Host-wide flake inputs (kineticwe-dev supplies its own).
  nix_flakes = {
    vm-curator = {
      url = "github:mroboff/vm-curator";
    };
    helium = {
      url = "github:amaanq/helium-flake";
    };
    punktfunk = {
      url = "git+file:///home/don/Projects/punktfunk";
      ref = "feat/host-kineticwe";
      nixos_module = true;
    };
    lgl-papercutter = {
      url = "github:linuxgamerlife/lgl-papercutter";
    };
    lgl-emoji-picker = {
      url = "github:linuxgamerlife/lgl-emoji-picker";
    };
    lgl-scheduler-manager = {
      url = "github:linuxgamerlife/lgl-scheduler-manager";
    };
    lgl-text-editor = {
      url = "github:linuxgamerlife/lgl-text-editor";
    };

  };

  config_backups = {
    enabled = false;
    max_backups = 5;
  };

  # timeshift/snapper are not used here.
  system_backups = {
    enabled = false;
    backup_on_sync = false;
    backup_on_update = false;
    max_backups = 5;
  };
}
