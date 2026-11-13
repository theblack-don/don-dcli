{ system, pkgs }:

{
  # Host file is hosts/<system.hostname>.nix; keep the filename in sync.
  host = system.hostname;
}
