{ system, pkgs }:

{
  description = "Example module module";

  packages = [
    # Add your packages here
  ];

  flatpak_packages = [
    # "com.example.App"
  ];

  nix_packages = [
    # "ripgrep"
    # "fd"
    # "bat"
  ];

  # Conditional packages based on system facts
  # packages = if system.hardware.is_laptop then [ "tlp" ] else [];

  conflicts = [];

  # services = {
  #   enabled = [ "example.service" ];
  #   disabled = [];
  #   scope = "system";
  # };
}