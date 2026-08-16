#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
frontend_dir="$repo_root/pixel_scribe_frontend"
backend_dir="$repo_root/pixel_scribe_backend"
artifact_dir="$frontend_dir/dist"
public_dir="$backend_dir/priv/public"

die() {
  printf 'build_frontend: %s\n' "$1" >&2
  exit 1
}

require_directory() {
  local path=$1

  if [ ! -d "$path" ] || [ -L "$path" ]; then
    die "expected a real directory at $path"
  fi
}

require_file() {
  local path=$1

  if [ ! -f "$path" ] || [ -L "$path" ]; then
    die "expected a generated regular file at $path"
  fi
}

clean_directory() {
  local path=$1

  require_directory "$path"
  find "$path" -mindepth 1 -delete
}

require_directory "$frontend_dir"
require_directory "$backend_dir"
if [ -e "$backend_dir/priv" ] || [ -L "$backend_dir/priv" ]; then
  require_directory "$backend_dir/priv"
else
  mkdir "$backend_dir/priv"
fi
require_file "$frontend_dir/gleam.toml"
require_file "$frontend_dir/manifest.toml"

if [ -e "$artifact_dir" ] || [ -L "$artifact_dir" ]; then
  require_directory "$artifact_dir"
else
  mkdir "$artifact_dir"
fi

printf 'Building frontend into %s\n' "$artifact_dir"
clean_directory "$artifact_dir"
(cd "$frontend_dir" && gleam run -m lustre/dev build)

# Lustre's build contract includes the generated entry files and copied assets.
require_file "$artifact_dir/index.html"
require_file "$artifact_dir/pixel_scribe_frontend.js"
require_file "$artifact_dir/styles.css"

while IFS= read -r -d '' artifact; do
  case "$(basename "$artifact")" in
    index.html|pixel_scribe_frontend.js|styles.css|pixel-art) ;;
    *) die "unexpected frontend artifact: $artifact" ;;
  esac
done < <(find "$artifact_dir" -mindepth 1 -maxdepth 1 -print0)

if [ -n "$(find "$artifact_dir" -type l -print -quit)" ]; then
  die "frontend output contains a symlink: $artifact_dir"
fi

if [ -e "$public_dir" ] || [ -L "$public_dir" ]; then
  require_directory "$public_dir"
else
  mkdir "$public_dir"
fi

clean_directory "$public_dir"
cp -a "$artifact_dir/." "$public_dir/"

printf 'Published frontend artifacts from %s to %s\n' "$artifact_dir" "$public_dir"
