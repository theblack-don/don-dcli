{ system, pkgs }:

let
  # On NixOS declare dev outputs as profile packages so sync converges them.
  isNixOS = system.distro == "nixos";
in


{
  description = "Flatpak applications";

  flatpak_packages = [
    "com.obsproject.Studio"
    "com.discordapp.Discord"
  ];
}
