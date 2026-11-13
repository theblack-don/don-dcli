{ system, pkgs }:

{
  description = "Example module module";

copr_repos = [
  "linuxgamerlife/lgl-toolkit"
  "linuxgamerlife/lgl-vm-curator"
];

packages = [
  "lgl-colour-picker"
  "lgl-dnf-helper"
  "lgl-emoji-picker"
  "lgl-papercutter"
  "vm-curator"
  "lgl-scheduler-manager"
  # Dependencies
  "scx-tools"
  "scx-scheds"
 ];
}
