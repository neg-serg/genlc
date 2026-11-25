# genlc

Genelec SAM monitor control over the GLM USB adapter — volume, mute, leases, monitor discovery and
the daemon that keeps the adapter owned. Rust rewrite of the [Python
genlc](https://github.com/markbergsma/genlc) that this repository used to carry; the Python tree
stays in the git history, not on `master`.

The adapter is a USB HID device (`VID 0x1781`, `PID 0x0E39`) that speaks Genelec's GNet protocol:
`[address:1] [command:1] [data:N] [CRC16/GSM:2] [0x7E]`, PPP-stuffed inside 64-byte HID reports.
The protocol was reverse engineered for this host and implemented against the public
[qlm protocol notes](https://github.com/cmicali/qlm/blob/main/docs/protocol.md); frames that would
write into a monitor's DSP without a lease or a plan are refused before they leave the process.

## Requirements

- A GLM network adapter plugged into the host and at least one SAM monitor (or subwoofer) on the
  GLM network.
- `libudev` at runtime (hidapi's hidraw backend); the Nix package puts it on the binary's
  rpath, so no `LD_LIBRARY_PATH` is needed.
- Read access to the adapter's `hidraw` node — the host's udev rule, not this package. Without it
  every command fails with `GLM USB adapter not found (VID:0x1781 PID:0x0E39)`.
- A running `genlc daemon` for `status`, `lease --now` and `mute toggle`; `volume` and `mute` fall
  back to the adapter when no daemon answers.

## Commands

| Command | What it does |
| --- | --- |
| `genlc daemon [SOCKET]` | Own the adapter: keep GLM's ~0.57 s lease/poll cycle, apply volume and mute, serve the control socket (default `$XDG_RUNTIME_DIR/genlc.sock`) |
| `genlc status [--json]` | Print the daemon's state (adapter, cycles, volume, leases, telemetry); exits 1 when no daemon answers |
| `genlc volume -30` | Set an absolute level (`-40`, `-40dB` or `40%`); writes the state file and routes through the daemon |
| `genlc volume --by -1` | Step relative to the current level, clamped to the `-95 .. -20 dB` working range |
| `genlc volume --show` | Print the state file's value (`-40` for a fresh session) |
| `genlc volume --watch` | Print each new state-file value as it changes (150 ms poll; what the bar's Genelec plugin reads) |
| `genlc mute [on\|off\|toggle]` | Mute all / unmute all / flip; `toggle` needs the daemon, since only it knows the current bit |
| `genlc unmute` | Same as `genlc mute off` |
| `genlc probe` | One probe: the hardware id of a monitor that holds no lease |
| `genlc lease [--take] [--now]` | Report unleased monitors, lease them with `--take`, or ask the daemon for a probe cycle with `--now` |
| `genlc apply PLAN [--commit --take] [--first]` | Print a plan's frames (dry run, no adapter); `--commit --take` leases and sends, refusing sessions this run did not lease |
| `genlc discover` / `wakeup` / `shutdown` | Discover devices on the GLM network / wake all monitors / shut them down |
| `genlc poll --addr 0xFF` | Poll the adapter's own device status |
| `genlc decode [--stats] [--sequences]` | Decode a USB capture from stdin (one HID report per line, `tshark -r cap.pcap -T fields -e usb.capdata`); no adapter needed |
| `genlc diagnose` | hidraw nodes and modes, udev rules, adapter open, discovery — the old shell script, without the interpreter |

`-m/--monitors` and `--debug` are accepted but carry no behaviour yet.

## Daemon and state

GLM's model is a host that never stops talking: it probes for unleased monitors and polls the leased
ones about twice a second, and a monitor drops its lease ~2.5 s after it last answered. A one-shot
CLI cannot hold that state, so `genlc daemon` keeps the cycle and serves it over a Unix socket, one
command per line (`status`, `volume -30.5`, `mute on`, `lease`, `apply PATH`, `quit`), one reply
line each. The daemon survives an adapter re-enumeration: the HID handle is dropped, reopened on a
one-second retry, and the leases that belonged to the old handle are cleared.

The volume target lives in `$XDG_RUNTIME_DIR/genlc-volume` (per-session, 0700) and is written only
after the frame actually reached the bus — the bar and the daemon both read it back. The daemon's
predecessor wrote the file while the write to a dead handle failed, which is exactly the mismatch
these two channels now avoid.

A user unit is enough on a single-user host:

```ini
[Service]
ExecStart = %h/.nix-profile/bin/genlc daemon
Restart = on-failure
```

## Build

```sh
nix build .#default          # the package (libudev on the rpath, no LD_LIBRARY_PATH needed)
nix flake check -L           # CLI surface check: --version against the manifest, subcommand list
cargo build --release        # needs pkg-config, libudev and hidapi headers
```

As a flake input for a NixOS host:

```nix
inputs.genlc = {
  url = "github:neg-serg/genlc";
  inputs.nixpkgs.follows = "nixpkgs";
};
# then: inputs.genlc.packages.${system}.default
```

## License

MIT. The protocol facts were reconstructed from public notes for this hardware; no GLM binary or
decompiled asset is shipped or copied.
