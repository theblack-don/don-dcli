{ system, pkgs }:

{
  description = "VM Module";

  packages = [
    "qemu-ui-sdl"
    "qemu-device-display-virtio-vga-gl"
    "qemu-device-display-virtio-gpu-gl"
    "qemu-audio-pa"
  ];

  flatpak_packages = [
  ];

  nix_packages = [
  ];
}
