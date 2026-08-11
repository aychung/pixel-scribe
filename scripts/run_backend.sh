#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

"$script_dir/build_frontend.sh"

cd "$repo_root/pixel_scribe_backend"
exec gleam run "$@"
