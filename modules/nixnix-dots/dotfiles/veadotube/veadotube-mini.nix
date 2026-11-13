{ pkgs ? import <nixpkgs> { } }:

pkgs.buildFHSEnv {
  name = "veadotube-mini";

  targetPkgs = pkgs: with pkgs; [
    sdl3
    icu
    openssl
    file
    which
    harfbuzz
    stdenv.cc.cc.lib
    libxkbcommon
    libGL
    wayland
    fontconfig
    freetype
    dbus
    libpulseaudio
  ];

  runScript = "/home/don/Documents/veadotube-mini";
}
