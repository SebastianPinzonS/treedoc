# Tree Doc firmware

Nerves firmware for **Raspberry Pi 4 Model B** (`rpi4`), created with
`mix nerves.new` and integrated with the Tree Doc CRDT in the parent directory.
Confirm your Pi model before flashing.

## Setup

Install the [Nerves prerequisites](https://nerves.hexdocs.pm/installation.html),
including `fwup` and `nerves_bootstrap`.

From this directory:

```bash
cp -n .env.example .env
chmod 600 .env
```

Edit `.env`:

```bash
MIX_TARGET=rpi4
TREEDOC_WIFI_SSID='router-name'
TREEDOC_WIFI_PSK='router-password'
TREEDOC_SSH_KEYS="$HOME/.ssh/id_ed25519.pub"
```

Use a **public** SSH key. `.env` is ignored by Git. `mix-env` loads it as a trusted
Bash file; Wi-Fi credentials are included in the compiled firmware.

## Build and flash

```bash
./mix-env deps.get
./mix-env firmware
./mix-env firmware.burn
```

Check the selected microSD before confirming: flashing overwrites it.

## Connect

Boot the Pi on the same `/24` network as the other Tree Doc nodes. Disable router
client isolation and reserve the Pi's IP through DHCP. Find its IP in the router, then:

```bash
ssh -i ~/.ssh/id_ed25519 user@192.168.1.20
```

In the IEx console:

```elixir
node()
Node.list()
TreeDoc.insert(0, "H")
TreeDoc.text()
TreeDoc.state().pending
```

The firmware starts Tree Doc after obtaining an IP, uses cookie `cpd2026`,
discovers peers through EPMD, and stores history in `/data/tree_doc`.
Keep the node's IP and history across restarts.

## Status

Unit tests pass. The firmware image has **not been built or tested on a Pi**.
Real network connectivity and recovery still need validation. Editing currently
supports one grapheme per insertion and one character per deletion.
