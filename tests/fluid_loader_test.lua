package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")

local oldFFI = package.loaded.ffi

local function probe(platform, environment, succeedsAt, libraryRoots)
  local attempted = {}
  package.loaded.ffi = {
    cdef = function() end,
    load = function(name)
      attempted[#attempted + 1] = name
      if name == succeedsAt then return { loadedFrom = name } end
      error("cannot load " .. name)
    end,
  }
  _G.ENHANCED_MUSIC_TEST_OS = platform
  _G.ENHANCED_MUSIC_TEST_ENV = environment or {}
  _G.ENHANCED_MUSIC_TEST_LIBRARY_ROOTS = libraryRoots or {}
  local Sampler = dofile("mods/ENHANCED_MUSIC/lib/FluidSampler.lua")
  return Sampler.new(), attempted
end

local override = "C:/Custom FluidSynth/libfluidsynth-3.dll"
local sampler, attempted = probe("Windows", {
  POKEPORT_FLUIDSYNTH_LIBRARY = override,
}, override)
T.eq(sampler.libraryPath, override, "explicit library override loads")
T.eq(attempted[1], override, "explicit override is tried first")

sampler, attempted = probe("Windows", {}, "libfluidsynth-3.dll")
T.eq(sampler.libraryPath, "libfluidsynth-3.dll",
  "Windows discovers the installed FluidSynth DLL by name")

sampler, attempted = probe("Windows", {},
  "lib/libfluidsynth-3.dll", { "lib" })
T.eq(sampler.libraryPath, "lib/libfluidsynth-3.dll",
  "Windows discovers FluidSynth in the application lib folder")

sampler, attempted = probe("OSX", {}, "/opt/homebrew/lib/libfluidsynth.3.dylib")
T.eq(sampler.libraryPath, "/opt/homebrew/lib/libfluidsynth.3.dylib",
  "macOS discovers an Apple Silicon Homebrew installation")

sampler, attempted = probe("Linux", {}, "libfluidsynth.so.3")
T.eq(sampler.libraryPath, "libfluidsynth.so.3",
  "Linux discovers the installed FluidSynth SONAME")

sampler, attempted = probe("Linux", {}, "lib/libfluidsynth.so.3", { "lib" })
T.eq(sampler.libraryPath, "lib/libfluidsynth.so.3",
  "Linux discovers FluidSynth in the application lib folder")

sampler = probe("Windows", {}, nil)
T.check(not sampler.lib and sampler.error:find("POKEPORT_FLUIDSYNTH_LIBRARY", 1, true),
  "failure explains the explicit cross-platform override")

package.loaded.ffi = oldFFI
_G.ENHANCED_MUSIC_TEST_OS = nil
_G.ENHANCED_MUSIC_TEST_ENV = nil
_G.ENHANCED_MUSIC_TEST_LIBRARY_ROOTS = nil
T.finish("enhanced music FluidSynth discovery")
