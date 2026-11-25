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
TreeDoc.insert(0, "Hi")
TreeDoc.insert(2, " world!")
TreeDoc.text()
TreeDoc.delete(0)
TreeDoc.state() # Document, clock, pending operations, and history
TreeDoc.sync()  # Broadcasts history without waiting for acknowledgments
```

On different machines, replace the loopback address with their actual IP addresses.
`insert/2` accepts non-empty UTF-8 text, including multiple characters and newlines;
indices are zero-based and count graphemes. `delete/1` removes one grapheme.
Each insertion is saved locally as a batch before acknowledgment or broadcast,
with one causal operation per grapheme for replication. Empty or invalid text
returns `{:error, :invalid_character}`. Each node saves its history
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

There is a local web editor; LaTeX integration, balancing, and compaction are not implemented.
History and tombstones grow; saving and retransmitting the entire history is an
initial solution. The repository is local and has not been published to GitHub.

## Web editor

Start the project with `iex --name laptop@<your-ip> --cookie cpd2026 -S mix`, then:

```elixir
TreeDoc.Web.start() # http://localhost:4000
```

The Document tab edits this node's shared document. State, Nodes, and Raw inspect
the replica and its history. Connected peers supporting the same read calls can
be inspected through the selector; other implementations may not expose these views.
Editing and replication still use the existing persisted insert/delete operations.

On the Pi, after its replica starts, use `TreeDoc.Web.start(ip: {0, 0, 0, 0})`
and visit `http://<pi-ip>:4000`. This editor has no authentication; bind it to a
trusted network only. Starting the web server is optional and does not change discovery.

The client polls every 400 ms and sends PosIDs instead of shifting text indices.
`POST /edit` accepts `{del, after, ins, seq}`, where `seq` is the local author's
sequence from `GET /state`. Remote authors may advance independently. If another
local client has edited, or a previous POST committed but its reply was lost,
the server returns 409 instead of repeating the insertion. The page preserves
the draft and pauses: copy any pending text before choosing **Discard draft and
load server text**. Rejected edits also preserve the draft. Pending typing that
overlaps a remote change follows the supplied client's server-wins rebase policy.
The initial document loads before typing is enabled.

Validation:

```sh
mix test --warnings-as-errors
node --test test/web_client_test.cjs
```

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
