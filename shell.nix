{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  packages = with pkgs; [
    zig_0_12
    wlroots_0_17
    libGL
    libevdev
    libinput
    libxkbcommon
    pixman
    udev
    wayland-protocols
    xorg.libX11
    pkg-config
    wayland
    xwayland
    valgrind
    gdb
  ];
}
