##
# Package: genlc
# Purpose: Genelec SAM loudspeaker control over the GLM USB adapter — volume,
#   mute, lease/probe, monitor discovery and the adapter daemon.
#
# The crate talks to the adapter through `hidapi`, which nixpkgs builds on its
#   hidraw/udev backend: the binary needs `libudev` at runtime and never links
#   `libusb`. nixpkgs puts the build inputs on the rpath, so the CLI works from a
#   session that does not export LD_LIBRARY_PATH; no wrapper is needed. The udev
#   rule that grants hidraw access is host configuration, not package content.
#
# Version comes from the crate manifest: clap reports CARGO_PKG_VERSION from it
#   and this derivation reads the same file, so the binary and the store path
#   cannot drift (they did once: 0.1.0 in the binary, 0.2.0 in the attr).
{
  lib,
  rustPlatform,
  pkg-config,
  udev,
  hidapi,
}:

rustPlatform.buildRustPackage {
  pname = "genlc";
  version = (lib.importTOML ./Cargo.toml).package.version;

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    udev
    hidapi
  ];

  meta = {
    description = "Genelec SAM loudspeaker control over the GLM USB adapter";
    homepage = "https://github.com/neg-serg/genlc";
    license = lib.licenses.mit;
    mainProgram = "genlc";
    platforms = lib.platforms.linux;
  };
}
