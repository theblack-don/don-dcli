{ system, pkgs }:

{
  description = "Bootc Module";

  # COPR providing dcli-bootc
  copr_repos = [
    "theblackdon/dcli-bootc"
  ];

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
