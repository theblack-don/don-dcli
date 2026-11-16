{ system, pkgs }:

{
  description = "Umbriel Wayland compositor";

  nix_flakes.umbriel = {
    # Cachix branch: latest commit CI has prebuilt x86_64/aarch64 binaries for.
    url = "github:noctalia-dev/umbriel";
    ref = "cachix";
    nixos_module = true;
  };

  nixos = {
    config = ''
      { ... }:
      {
        programs.umbriel.enable = true;

        nix.settings = {
          extra-substituters = [ "https://umbriel.cachix.org" ];
          extra-trusted-public-keys = [
            "umbriel.cachix.org-1:JfNq/2yg2S6D6z4Z2dVSZrZlDPQTKtexB6GAVLD98nw="
          ];
        };
      }
    '';
  };
}
