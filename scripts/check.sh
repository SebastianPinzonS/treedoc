#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for executable in elixir mix erl; do
  if ! command -v "$executable" >/dev/null 2>&1; then
    echo "Falta $executable. En Omarchy: omarchy pkg add elixir erlang-headless" >&2
    exit 1
  fi
done
elixir --version
mix format
mix compile --warnings-as-errors
mix test
if [[ $# -gt 0 ]]; then
  mix run scripts/compare_references.exs "$1"
fi
