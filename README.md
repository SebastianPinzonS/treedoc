# Tree Doc — operation-based

A distributed console editor written in Elixir. It uses causal operations,
`[{bit, seq, node}]` positions, vector clocks, deduplication, and history replay.
The replica registers as `Crdt.Replica`.

## Running the project

Elixir >= 1.18 and < 2.0 with a compatible OTP version. The core has no Hex dependencies.

```sh
./scripts/check.sh
iex --name equipo1@127.0.0.1 --cookie cpd2026 -S mix
```

In another terminal, from the same project:

```sh
iex --name equipo2@127.0.0.1 --cookie cpd2026 -S mix
```

On the first node:

```elixir
Node.connect(:"equipo2@127.0.0.1")
TreeDoc.insert(0, "H")
TreeDoc.insert(1, "i")
TreeDoc.text()
TreeDoc.delete(0)
TreeDoc.state() # Document, clock, pending operations, and history
TreeDoc.sync()  # Broadcasts history without waiting for acknowledgments
```

On different machines, replace the loopback address with their actual IP addresses.
`insert/2` accepts one grapheme; indices are zero-based. Each node saves its history
under `data/`, configurable through `TREEDOC_DATA_DIR`.

## Identity and persistence

Keep the node name and its data directory when restarting. Do not delete history
and reuse the same name in a cluster that still remembers its operations:
reused sequence numbers would be discarded as duplicates. Use a new node name
for a new replica with no history. Do not run two replicas with the same identity
or sharing the same history file.

Changes are persisted before being acknowledged or broadcast. The file is a binary
ETF snapshot of history, written with fsync and replaced using rename. It is not
a JSONL log and does not, by itself, guarantee recovery from every power failure
(the directory is not synchronized). A corrupt file prevents startup.

## Status

Direct compilation with `elixirc --warnings-as-errors` and 11 op-based tests passed.
Five additional firmware tests passed, covering discovery, host startup, and
target configuration. Real network tests and Raspberry Pi deployment remain pending.

There is no graphical interface, LaTeX integration, balancing, or compaction.
History and tombstones grow; saving and retransmitting the entire history is an
initial solution. The repository is local and has not been published to GitHub.

## Flashing a Raspberry Pi

The firmware targets **Raspberry Pi 4 Model B** (`rpi4`). Confirm your board model
before proceeding. The image has not yet been built or validated on hardware.

Install the [Nerves prerequisites](https://nerves.hexdocs.pm/installation.html),
including `fwup`, compatible Erlang/Elixir versions, and the bootstrap archive:

```bash
mix local.hex
mix local.rebar
mix archive.install hex nerves_bootstrap
```

From the repository root, prepare your local configuration:

```bash
cd firmware
cp -n .env.example .env
chmod 600 .env
```

Edit `.env` with your Wi-Fi credentials and the path to an existing **public** SSH key:

```bash
MIX_TARGET=rpi4
TREEDOC_WIFI_SSID='router-name'
TREEDOC_WIFI_PSK='router-password'
TREEDOC_SSH_KEYS="$HOME/.ssh/id_ed25519.pub"
```

Build the firmware:

```bash
./mix-env deps.get
./mix-env firmware
```

Insert the microSD into your computer and run:

```bash
./mix-env firmware.burn
```

Check the selected device before confirming: **flashing overwrites the card**.
Once complete, safely eject it, insert it into the Pi, and power the Pi on.

Find the Pi's IP address in your router and connect, replacing the example IP:

```bash
ssh -i ~/.ssh/id_ed25519 user@192.168.1.20
```

SSH opens an IEx console. Check the node and document:

```elixir
node()
Node.list()
TreeDoc.text()
```

Use the same `/24` network for all nodes, disable router client isolation, and
reserve the Pi's IP through DHCP. History is stored in `/data/tree_doc`.
See [firmware/README.md](firmware/README.md) for configuration details and limitations.
