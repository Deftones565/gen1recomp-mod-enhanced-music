#!/usr/bin/env bash
# Optional Steam Deck launcher for a user-local FluidSynth installation.
# Copy this file beside gen1recomp-x86_64.AppImage, soundfonts/, and lib/.

set -euo pipefail

launcher_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
appimage="${GEN1RECOMP_APPIMAGE:-$launcher_dir/gen1recomp-x86_64.AppImage}"
soundfont_dir="$launcher_dir/soundfonts"
library_dir="${POKEPORT_FLUIDSYNTH_DIR:-$launcher_dir/lib}"

if [[ ! -x "$appimage" ]]; then
  printf 'Enhanced Music launcher: AppImage is missing or not executable:\n  %s\n' \
    "$appimage" >&2
  printf 'Place this script beside the AppImage and run: chmod +x %q\n' \
    "$appimage" >&2
  exit 1
fi

shopt -s nullglob
soundfonts=(
  "$soundfont_dir"/*.sf2 "$soundfont_dir"/*.sf3
  "$soundfont_dir"/*.SF2 "$soundfont_dir"/*.SF3
)
shopt -u nullglob
if (( ${#soundfonts[@]} == 0 )); then
  printf 'Enhanced Music launcher: no .sf2 or .sf3 banks found in:\n  %s\n' \
    "$soundfont_dir" >&2
  exit 1
fi

# The lib folder is optional. When present, exposing it before launch lets the
# dynamic loader resolve both FluidSynth and its neighboring dependencies.
if [[ -d "$library_dir" ]]; then
  export POKEPORT_FLUIDSYNTH_DIR="$library_dir"
  export LD_LIBRARY_PATH="$library_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

cd -- "$launcher_dir"
exec "$appimage" "$@"
