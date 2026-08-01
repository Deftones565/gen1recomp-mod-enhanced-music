# Enhanced Music 2.6.0 — bring your own SoundFont

Enhanced Music reads the active song's note commands from the player's
imported Pokémon Red, Blue, or Yellow ROM and performs them through a
SoundFont in real time. It does not contain Pokémon music and never generates
MIDI, OGG, WAV, or other music files.

The mod keeps all synthesized audio in memory. If FluidSynth or the selected
bank is unavailable, the original ROM chip music remains audible instead of
leaving the game silent. Cries and sound effects are not replaced.

## Installation

1. Download the Enhanced Music `.zip` from this repository's latest GitHub
   release.
2. Open gen1recomp's launcher, select the **MODS** tab, choose
   **Import mod .zip**, and select the downloaded ZIP.
3. Install FluidSynth and add a SoundFont using the sections below.
4. Make sure **Enhanced Music** is enabled, then launch or restart the game.

Import the release ZIP as-is; do not extract it manually. The launcher installs
the mod into its shared per-user `mods` directory. SoundFont files remain
user-supplied and are not included in the release.

## Platform support

| Platform | Status | FluidSynth discovery |
| --- | --- | --- |
| Linux | Supported | System loader, application `lib`, standard library directories, or an override |
| SteamOS | Supported | Application `lib` or a system/user installation |
| Windows 64-bit | Supported | Windows loader/`PATH`, application `lib`, common package prefixes, or an override |
| macOS Intel | Supported | System loader, application `lib`, Homebrew/MacPorts, or an override |
| macOS Apple Silicon | Supported | System loader, application `lib`, Homebrew/MacPorts, or an override |
| Android | Not generally supported | Android requires native libraries to be packaged in the APK for each ABI |

Android does not normally allow one application to load a native library from
another application, Termux, or shared storage. Consequently, a separately
installed FluidSynth cannot provide dependable Android support. FluidSynth
would need to be included in the Android APK, which this mod deliberately does
not do. Rooted or specially configured devices are outside the supported setup.

## Required packaged layout

A fused executable or AppImage must have a physical `soundfonts` directory
containing at least one `.sf2` or `.sf3` bank. FluidSynth cannot read a bank
that exists only inside the fused executable. The directory name is exactly
`soundfonts`; alternatives such as `sf` are not searched.

Use this layout for the prepared Linux and Steam Deck package:

```text
gen1recomp/
├── gen1recomp-x86_64.AppImage
├── soundfonts/                    # required
│   └── Your-SoundFont.sf2         # any .sf2 or .sf3 bank
├── lib/                           # optional
│   ├── libfluidsynth.so.3
│   └── FluidSynth dependencies
```

The `lib` directory is optional. Do not include it when FluidSynth is installed
normally and the operating system can already find it. It is useful on
restrictive or immutable systems such as SteamOS, where a user-local library
is preferable to changing the system partition. The mod finds the main
FluidSynth shared library in an adjacent `lib` directory automatically. No
launcher script or command-line argument is required.

A mod installed from a release ZIP is extracted to a real directory, so its
own extracted `soundfonts` folder also satisfies this requirement.

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
beside the AppImage. The mod discovers the shared library there automatically.

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

Download or supply any `.sf2` or `.sf3` bank, place it in a supported
`soundfonts` folder, and restart the game. The mod discovers every compatible
bank automatically and adds it to the F10 mod menu. The default **AUTO**
selection prefers an arbitrary user-named bank before the recognized suggested
presets. Arbitrary banks use the SoundFont filename as their menu name, with
only the `.sf2` or `.sf3` extension removed; capitalization and punctuation are
preserved. Recognized suggested filenames use the preset labels listed below.
The three downloads are suggestions, not requirements.

The user folder is inside LÖVE's per-user save directory. Its exact parent
varies by operating system; `love.filesystem.getSaveDirectory()` determines it
at runtime, so the mod contains no machine-specific path. Existing explicit
SoundFont environment variables remain available for unusual installations.

Use one of these locations:

- `soundfonts/` beside the executable or AppImage;
- LÖVE's per-user save directory—for example,
  `~/.local/share/pokemon-love2d/soundfonts/` on Linux; or
- a path supplied through the environment variables listed below.

### Suggested SoundFonts

- [Download GeneralUser GS](https://github.com/mrbumpy409/GeneralUser-GS/raw/refs/heads/main/GeneralUser-GS.sf2)
  — place the downloaded `GeneralUser-GS.sf2` file in `soundfonts/`.
- [MuseScore General SF3](https://ftp.osuosl.org/pub/musescore/soundfont/MuseScore_General/MuseScore_General.sf3)
  — a compact, full General MIDI bank.
- [FluidR3 GM archive](https://ftp.osuosl.org/pub/musescore/soundfont/fluid-soundfont.zip)
  — extract `FluidR3_GM.sf2` and place it in `soundfonts/`.

Other compatible `.sf2` and `.sf3` banks work without renaming. Suggested
filenames retain their tailored menu presets; every other bank appears under
its own filename and uses the standard orchestral instrument mapping.

Optional explicit paths:

- `POKEPORT_SOUNDFONT_GENERALUSER`
- `POKEPORT_SOUNDFONT_MUSESCORE`
- `POKEPORT_SOUNDFONT_FLUIDR3`
- `POKEPORT_SOUNDFONT_RARE`

Choose a bank from the F10 mod manager. Suggested presets switch immediately:

- **GeneralUser GS** — warm and compact; the first suggested fallback for
  **AUTO**.
- **MuseScore General** — fuller modern ensemble samples.
- **FluidR3** — the classic General MIDI bank; both `FluidR3_GM.sf2` and the
  older `FluidR3Mono_GM.sf3` filename are recognized.
- **Rare-inspired** — a playful General MIDI arrangement using banjo,
  clarinet, marimba, fiddle, pizzicato strings, organ, and low brass.

Rare-inspired changes instrument assignments only. It does not use samples
ripped from Banjo-Kazooie or any other Rare game.

### Per-channel instruments

After loading a SoundFont, the mod reads every preset exposed by that bank and
adds four selectors to its F10 settings:

- **CHANNEL 1** — Game Boy pulse channel 1;
- **CHANNEL 2** — Game Boy pulse channel 2;
- **CHANNEL 3** — Game Boy wave channel; and
- **DRUMS** — Game Boy noise channel.

Each choice shows the SoundFont bank number, program number, and a shortened
preset name. **AUTO** detects standard General MIDI banks and keeps their exact
song-aware orchestral or Rare-inspired program mapping. For a custom non-GM
bank, it matches that bank's own preset names to each song's melody, harmony,
bass, and percussion roles. This allows game-specific banks such as GoldenEye
007 to use their real flute, guitar, bass, brass, strings, and bank-0 drum kits
instead of unrelated GM program numbers.

Selecting a preset manually overrides **AUTO** for that channel and restarts
the current song immediately. Choices are saved with the other mod settings.
When switching SoundFonts, a saved bank/program is reused if the new bank
provides it; otherwise that channel falls back to **AUTO**.

The mod uses the game's existing read-only ROM song decoder plus its public
music, volume, and fixed-step hooks. It does not modify any engine source file.

No SoundFont files are distributed by this repository or its release ZIP.
Review and follow the license supplied by the SoundFont author before use or
redistribution.
