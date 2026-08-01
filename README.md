# Enhanced Music 2.3 — cross-platform FluidSynth discovery

Enhanced Music reads the active song's note commands from the player's
imported Pokémon Red, Blue, or Yellow ROM and performs them through a
SoundFont in real time. It does not contain Pokémon music and never generates
MIDI, OGG, WAV, or other music files.

The mod keeps all synthesized audio in memory. If FluidSynth or the selected
bank is unavailable, the original ROM chip music remains audible instead of
leaving the game silent. Cries and sound effects are not replaced.

## Platform support

| Platform | Status | FluidSynth discovery |
| --- | --- | --- |
| Linux | Supported | System loader, application `lib`, standard library directories, or an override |
| SteamOS | Supported | Application `lib`, launcher environment, or a system/user installation |
| Windows 64-bit | Supported | Windows loader/`PATH`, application `lib`, common package prefixes, or an override |
| macOS Intel | Supported | System loader, application `lib`, Homebrew/MacPorts, or an override |
| macOS Apple Silicon | Supported | System loader, application `lib`, Homebrew/MacPorts, or an override |
| Android | Not generally supported | Android requires native libraries to be packaged in the APK for each ABI |

Android does not normally allow one application to load a native library from
another application, Termux, or shared storage. Consequently, a separately
installed FluidSynth cannot provide dependable Android support. FluidSynth
would need to be included in the Android APK, which this mod deliberately does
not do. Rooted or specially configured devices are outside the supported setup.

## FluidSynth setup

The real-time backend requires a user-installed FluidSynth shared library. The
mod does not distribute or install FluidSynth binaries. It searches the normal
library path for the current platform, followed by common package-manager
locations:

- Windows: `libfluidsynth-3.dll`, `libfluidsynth.dll`, or `fluidsynth.dll`;
- Linux: `libfluidsynth.so.3` or `libfluidsynth.so`;
- macOS: `libfluidsynth.3.dylib` or `libfluidsynth.dylib`.

On Windows, install the 64-bit library and add its `bin` directory to `PATH`.
The library architecture must match the 64-bit game.
Linux package-manager installations normally need no extra configuration.
Homebrew and MacPorts locations are recognized on macOS.

Application layouts with a `lib` folder are also recognized automatically.
The mod checks `lib` beside the application/source directory, beside an
AppImage, and beneath the launch working directory. Set
`POKEPORT_FLUIDSYNTH_DIR` when the library is in a different directory.

Example portable layouts:

```text
gen1recomp/
├── gen1recomp.exe
└── lib/
    └── libfluidsynth-3.dll
```

```text
gen1recomp/
├── gen1recomp-x86_64.AppImage
└── lib/
    └── libfluidsynth.so.3
```

The paths are derived from the running application. No machine-specific game
directory is embedded in the mod.

For a custom installation, set `POKEPORT_FLUIDSYNTH_LIBRARY` to the complete
path of the shared library. This is only a path override; the mod never copies
or writes the library. A missing or incompatible library leaves the original
ROM chip music active and reports a useful warning.

## SoundFont setup

The prepared Steam Deck bundle places the supported SoundFonts in a
`soundfonts` folder beside the AppImage. For a separate installation, use one
of these locations:

- `soundfonts/` beside the AppImage;
- `~/.local/share/pokemon-love2d/soundfonts/`; or
- a path supplied through the environment variables listed below.

Recognized files:

- `GeneralUser-GS.sf2`
- `MuseScore_General.sf3` (an SF2 file with the same base name also works)
- `FluidR3Mono_GM.sf3` (or `FluidR3_GM.sf2`)

Optional explicit paths:

- `POKEPORT_SOUNDFONT_GENERALUSER`
- `POKEPORT_SOUNDFONT_MUSESCORE`
- `POKEPORT_SOUNDFONT_FLUIDR3`
- `POKEPORT_SOUNDFONT_RARE`

Choose a bank from the F10 mod manager. The active song switches immediately:

- **GeneralUser GS** — warm and compact; the default.
- **MuseScore General** — fuller modern ensemble samples.
- **FluidR3Mono** — the classic MuseScore 2 / Linux GM bank.
- **Rare-inspired** — a playful General MIDI arrangement using banjo,
  clarinet, marimba, fiddle, pizzicato strings, organ, and low brass.

Rare-inspired changes instrument assignments only. It does not use samples
ripped from Banjo-Kazooie or any other Rare game.

The mod uses the game's existing read-only ROM song decoder and public music,
volume, and fixed-step hooks. It does not modify any engine source file.

SoundFont sources and license notices are included with distributed banks:

- GeneralUser GS: https://github.com/mrbumpy409/GeneralUser-GS
- MuseScore General: https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/
- FluidR3Mono: https://musescore.org/en/node/248741
