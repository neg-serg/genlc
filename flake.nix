{
  description = "genlc — Genelec SAM loudspeaker control over the GLM USB adapter";

  # Minimal on purpose: the host flake consumes `packages.<system>.default` and
  # makes this input follow its nixpkgs pin, so the binary is built against the
  # same nixpkgs as the system that runs it.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: rec {
        default = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        genlc = default;
      });

      # The CLI surface, not the hardware: `--version` has to agree with the
      # manifest (clap prints CARGO_PKG_VERSION) and the subcommands that need
      # no adapter have to stay listed. Nothing here opens the GLM adapter, so
      # the check runs on a build machine without a monitor bus.
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          version = (pkgs.lib.importTOML ./Cargo.toml).package.version;
        in
        {
          cli =
            pkgs.runCommand "genlc-cli-check"
              {
                nativeBuildInputs = [ pkgs.gnugrep ];
              }
              ''
                test "$(${self.packages.${system}.default}/bin/genlc --version)" = "genlc ${version}"

                help="$(${self.packages.${system}.default}/bin/genlc --help)"
                for command in daemon status volume mute unmute probe apply lease discover wakeup shutdown decode poll diagnose; do
                  grep -F "  $command" <<< "$help" > /dev/null
                done

                touch "$out"
              '';
        }
      );

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            cargo
            rustc
            clippy
            rustfmt
            rust-analyzer
            pkg-config
            udev
            libusb1
            hidapi
          ];
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
