{
  description = "A hackable wayland compositor based on views";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    zig-overlay.url = "github:mitchellh/zig-overlay";
    zig-overlay.inputs.nixpkgs.follows = "nixpkgs";

    zls-overlay.url = "github:zigtools/zls";
    zls-overlay.inputs.nixpkgs.follows = "nixpkgs";

    wlroots-src = {
      type = "gitlab";
      host = "gitlab.freedesktop.org";
      owner = "wlroots";
      repo = "wlroots";
      ref = "refs/tags/0.17.0";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    wlroots-src,
    zig-overlay,
    zls-overlay,
  }: let
    version = self.shortRev or "dirty";
    supportedSystems = ["x86_64-linux"];
    xwaylandSupport = true;

    # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
    forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    # Nixpkgs instantiated for supported system types.
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [self.overlay];
      });
  in {
    overlay = final: prev:
      with final; rec {
        wlroots = prev.wlroots.overrideAttrs (old: {
          version = wlroots-src.shortRev or "dirty";
          src = wlroots-src;
          buildInputs =
            old.buildInputs
            ++ [
              hwdata
              libliftoff
              libdisplay-info
            ];
        });

        gaze = with final;
          final.callPackage ({inShell ? false}:
            stdenv.mkDerivation rec {
              name = "gaze-${version}";

              # In 'nix develop', we don't need a copy of the source tree in the Nix store.
              src =
                if inShell
                then null
                else ./.;

              buildInputs =
                [
                  zig-overlay.packages.${system}.master
                  wlroots
                  libGL
                  libevdev
                  libinput
                  libxkbcommon
                  pixman
                  udev
                  wayland-protocols
                ]
                ++ lib.optional xwaylandSupport xorg.libX11
                ++ (
                  if inShell
                  then [
                    zls-overlay.packages.${system}.default
                    valgrind
                    gdb
                  ]
                  else []
                );

              nativeBuildInputs = [
                pkg-config
                wayland
                xwayland
              ];

              target = "-Dcpu=baseline -Doptimize=ReleaseSafe";

              buildPhase = "zig build ${target}";

              doCheck = true;

              checkPhase = "zig build test ${target}";

              installPhase = ''
                mkdir -p $out
                # TODO: implement this :)
              '';
            }) {};
      };

    packages = forAllSystems (system: {
      inherit (nixpkgsFor.${system}) gaze;
    });
    defaultPackage = forAllSystems (system: self.packages.${system}.gaze);

    devShell = forAllSystems (system: self.packages.${system}.gaze.override {inShell = true;});

    nixosModules.gaze = {pkgs, ...}: {
      nixpkgs.overlays = [self.overlay];

      passthru.providedSessions = ["gaze"];
      # TODO: this
    };
  };
}
