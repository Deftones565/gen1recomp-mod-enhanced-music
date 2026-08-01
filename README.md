# Enhanced Music 2.4 — automatic SoundFont discovery

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

Use FluidSynth's official [Get FluidSynth](https://www.fluidsynth.org/wiki/Download/)
page for current downloads and platform instructions. Prefer a released
package from the operating system's package manager.

### Linux

Install FluidSynth system-wide with the package manager. It places the shared
library in that distribution's normal library directory, which the mod checks
automatically:

```bash
# Ubuntu or Debian
sudo apt-get install fluidsynth

# Arch Linux
sudo pacman -S fluidsynth

# Fedora
sudo dnf install fluidsynth

# openSUSE
sudo zypper install fluidsynth
```

SteamOS uses an Arch base, but its system partition is managed differently and
system changes may not survive an OS update. A user-local Steam Deck setup can
instead place the SteamOS-compatible library and its dependencies in `lib`
beside the AppImage, then launch with that directory in `LD_LIBRARY_PATH`.

### Windows

Install the 64-bit build so it matches the 64-bit game. The official page lists
Chocolatey:

```powershell
choco install fluidsynth
```

Restart the launcher after installation so it receives the updated `PATH`.
The folder containing `libfluidsynth-3.dll` must be in `PATH`, or the DLL may
be placed in the application's `lib` folder. For a custom location, set
`POKEPORT_FLUIDSYNTH_LIBRARY` to the complete DLL path.

### macOS

The official page lists Homebrew, MacPorts, and Fink. Install with one of:

```bash
brew install fluidsynth
sudo port install fluidsynth
fink install fluidsynth
```

Homebrew's Intel and Apple Silicon prefixes and the standard MacPorts location
are detected automatically. A custom installation can use the full-path
override described below.

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

Drop any `.sf2` or `.sf3` bank into the game's user `soundfonts` folder and
restart the game. The mod discovers it automatically, adds it to the F10 mod
menu, and the default **AUTO** selection prefers it over the included named
presets. Its menu name is the SoundFont filename with only the `.sf2` or `.sf3`
extension removed; capitalization and punctuation are preserved. An unpacked
mod's own `soundfonts` folder is scanned as well.

The user folder is inside LÖVE's per-user save directory. Its exact parent
varies by operating system; `love.filesystem.getSaveDirectory()` determines it
at runtime, so the mod contains no machine-specific path. Existing explicit
SoundFont environment variables remain available for unusual installations.

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
