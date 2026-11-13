{ pkgs, system }:

let
  # NixOS only: the kineticwe flake input and the portal package dcli owns.
  isNixOS = system.distro == "nixos";
in

{
  description = "KineticWE dev branch (compositor + Noctalia shell) from its Nix flake (profile or incremental dev mode)";

  # Rebuilt by the hook on every sync (post_hook_behavior = "always").
  post_install_hook = "scripts/install-kineticwe.sh";
  post_hook_behavior = "always";

  # Per-user profile and ~/.local; never run this hook through sudo.
  run_hooks_as_user = true;

  # NixOS setup (ignored elsewhere): Noctalia greeter pinned to the RPM spec rev.
  nix_flakes = {
    noctalia-greeter = {
      url = "gitlab:theblackdon/noctalia-greeter-kwe";
      rev = "b3e3bc0268fc5aaf346a250faac70570d15e3bef";
      nixos_module = true;
    };
  } // (if isNixOS then {
    # Dev branch only; shallow=1 lets nix profile add it first. The dev hook
    # still builds the checkout's dirty tree for incremental work.
    kineticwe = {
      url = "git+file:///home/don/Projects/kineticwe?ref=kineticwe-2.0&shallow=1";
    };
  } else { });

  # dcli owns the portal in the default profile; the hook owns the dedicated
  # kinetic profile (kinetic-we/noctalia/session), so `dcli update` never
  # rebuilds the kinetic outputs through the default profile.
  nix_packages = if isNixOS then [
    "kineticwe#xdg-desktop-portal-kwe"
  ] else [ ];

  nixos = {
    # Runtime deps from lgl-kineticwe-copr/kineticwe.spec (Requires plus the
    # qt5ct/qt6ct Recommends). systemd is the init; kineticwe-noctalia and
    # xdg-desktop-portal-kwe come from the dev prefix/profile, not nixpkgs.
    system_packages = [
      "kdePackages.milou"
      "kdePackages.breeze-icons"
      "kdePackages.spectacle"
      "kdePackages.qqc2-desktop-style"
      "adw-gtk3"
      "hwdata"
      "xwayland"
      "xdg-desktop-portal"
      "xdg-user-dirs"
      "python3"
      "procps"
      "psmisc"
      "bashInteractive"
      "qt6.qttools"
      "qt6Packages.qt6ct"
      "libsForQt5.qt5ct"
    ];

    config = ''
      { pkgs, lib, ... }:
      let
        # Markers from install-kineticwe.sh; update the path if the user changes.
        kweState = "/home/don/.local/state/kineticwe";
        greeterEnabled = builtins.pathExists (kweState + "/greeter-enabled");
        profileEnabled = builtins.pathExists (kweState + "/profile-enabled");
        devEnabled = builtins.pathExists (kweState + "/dev-enabled");
      in
      {
        # Shared ccache for incremental KineticWE builds.
        programs.ccache.enable = true;
        nix.settings.extra-sandbox-paths = [ "/var/cache/ccache" ];

        # KDE portal backend; KineticWE's kwe backend comes from the profile.
        xdg.portal = {
          enable = true;
          extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
          config.common.default = [ "kde" ];
        };

        # Unset NIX_XDG_DESKTOP_PORTAL_DIR so the profile's kwe.portal is found.
        systemd.user.services.xdg-desktop-portal = {
          # Keep the packaged unit; only add the env override.
          overrideStrategy = "asDropin";
          serviceConfig.UnsetEnvironment = [ "NIX_XDG_DESKTOP_PORTAL_DIR" ];
        };

        # Wayland session launcher comes from the dedicated kinetic profile, so
        # the hook keeps it updated outside `dcli update`'s default profile.
        environment.pathsToLink = [ "/share/wayland-sessions" ];
        # One definition: a second `environment.systemPackages` in the same
        # attrset is a duplicate-attribute parse error.
        environment.systemPackages =
          lib.optionals profileEnabled [
            (pkgs.writeTextDir "share/wayland-sessions/kineticwe.desktop" '''
              [Desktop Entry]
              Name=KineticWE
              Comment=KineticWE dev build from the local checkout
              Exec=/home/don/.local/state/kineticwe/profile/bin/start-kineticwe
              Type=Application
              DesktopNames=KDE
            ''')
          ]
          # Dev mode (KWE_INSTALL_MODE=dev): incremental build under
          # ~/.local/state/kineticwe/dev, exposed as a separate session.
          ++ lib.optionals devEnabled [
            (pkgs.writeTextDir "share/wayland-sessions/kineticwe-dev.desktop" '''
              [Desktop Entry]
              Name=KineticWE Dev
              Comment=Incremental KineticWE build from the local checkout
              Exec=/home/don/.local/state/kineticwe/dev/bin/start-kineticwe-dev
              Type=Application
              DesktopNames=KineticWE
            ''')
          ];

        # Greetd/Noctalia greeter: enabled once by the hook, reboot afterwards.
        services.displayManager.noctalia-greeter = lib.mkIf greeterEnabled {
          enable = true;
        };
        services.greetd.settings.default_session.user =
          lib.mkIf greeterEnabled "greeter";
        users.groups.greeter = lib.mkIf greeterEnabled { };
        users.users.greeter = lib.mkIf greeterEnabled {
          isSystemUser = true;
          group = "greeter";
          home = "/var/lib/noctalia-greeter";
          extraGroups = [ "video" "input" ];
        };
      }
    '';
  };
}
