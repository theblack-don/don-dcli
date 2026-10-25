{ system, pkgs }:

{
  description = "Bootc Module";

  packages = [
    "bootc"
    "podman"
    "skopeo"
    "dcli-bootc"
    "rclone"
  ];

  flatpak_packages = [
  ];

  nix_packages = [
  ];
}
