{ pkgs, system }:

{
  description = "KineticWE dev branch (compositor + Noctalia shell) from its Nix flake";

  # Nothing comes from nixpkgs: the checkout is built by the hook below, which
  # re-runs on every `dcli sync` (post_hook_behavior = "always"), so a sync
  # means "rebuild and install the dev branch".
  post_install_hook = "scripts/install-kineticwe.sh";
  post_hook_behavior = "always";

  # nix profile and ~/.local are per-user; never run this hook through sudo.
  run_hooks_as_user = true;
}
