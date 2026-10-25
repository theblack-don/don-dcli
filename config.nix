{ system, pkgs }:

{
  # Resolve the host file from the machine's hostname: hosts/<hostname>.nix.
  # Keep the hostname and the host file name in sync (fednix, fednix-lap, ...).
  host = system.hostname;
}
