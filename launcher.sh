#!/usr/bin/env bash
# Steam Deck launcher for Gen1Recomp and Enhanced Music.
# Place this file beside the AppImage, soundfonts/, and optional lib/ folder.

set -euo pipefail

launcher_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
appimage="$launcher_dir/gen1recomp-x86_64.AppImage"
soundfont_dir="$launcher_dir/soundfonts"
library_dir="$launcher_dir/lib"

if [[ ! -x "$appimage" ]]; then
  printf 'Gen1Recomp: AppImage is missing or not executable:\n  %s\n' \
    "$appimage" >&2
  printf 'Run: chmod +x %q\n' "$appimage" >&2
  exit 1
fi

shopt -s nullglob
soundfonts=(
  "$soundfont_dir"/*.sf2 "$soundfont_dir"/*.sf3
  "$soundfont_dir"/*.SF2 "$soundfont_dir"/*.SF3
)
shopt -u nullglob
if (( ${#soundfonts[@]} == 0 )); then
  printf 'Gen1Recomp: no .sf2 or .sf3 SoundFonts found in:\n  %s\n' \
    "$soundfont_dir" >&2
  exit 1
fi

# Enhanced Music finds the main library itself. This additionally lets the
# SteamOS native loader resolve dependencies stored beside libfluidsynth.
if [[ -d "$library_dir" ]]; then
  export POKEPORT_FLUIDSYNTH_DIR="$library_dir"
  export LD_LIBRARY_PATH="$library_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

cd -- "$launcher_dir"
exec "$appimage" "$@"
