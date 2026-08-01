package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")

local FakeSampler = {}
function FakeSampler.new()
  return setmetatable({ starts = {}, updates = 0, writes = 0 }, { __index = FakeSampler })
end
function FakeSampler:loadBank(path, style)
  self.synth, self.path, self.style = true, path, style
  return true
end
function FakeSampler:listPresets()
  return {
    { bank = 0, program = 0, name = "Acoustic Grand Piano" },
    { bank = 128, program = 0, name = "Standard Drum Kit" },
  }
end
function FakeSampler:setChannelPrograms(programs) self.channelPrograms = programs end
function FakeSampler:start(_, song)
  self.song = song
  self.starts[#self.starts + 1] = song
  return true
end
function FakeSampler:stop() self.song = nil end
function FakeSampler:setVolume(value) self.volume = value end
function FakeSampler:update() self.updates = self.updates + 1 end
function FakeSampler:destroy() self.destroyed = true end

_G.ENHANCED_MUSIC_TEST_SAMPLER = FakeSampler
_G.ENHANCED_MUSIC_TEST_SOUNDFONTS = {
  generaluser = "/banks/GeneralUser-GS.sf2",
  musescore = "/banks/MuseScore_General.sf3",
  fluidr3 = "/banks/FluidR3Mono_GM.sf3",
  rare = "/banks/MuseScore_General.sf3",
}

local data = T.fixtures.fresh()
data.audio = { songs = {
  Music_PalletTown = { address = 0x4000, bank = 2, engine = 1 },
  Music_WildBattle = { address = 0x4010, bank = 8, engine = 2 },
  Music_OtherMod = { file = "other.ogg" },
} }

local run = T.sdk.loadMod("mods/ENHANCED_MUSIC", { data = data })
T.eq(#run.errors, 0, "real-time mod loads cleanly")
local sampler = run.loader.exports.enhanced_music.sampler
T.eq(sampler.style, "generaluser", "default SoundFont loads in memory")
T.eq(sampler.path, "/banks/GeneralUser-GS.sf2", "default bank uses its local path")
T.eq(run.loader.exports.enhanced_music.writesMusicFiles, false,
  "runtime explicitly exposes that it writes no music files")
T.eq(run.loader.exports.enhanced_music.backend, "fluidsynth_ffi",
  "runtime exposes the restored FluidSynth backend")
T.eq(run.loader.exports.enhanced_music.requiresNativeLibrary, true,
  "runtime explicitly exposes its FluidSynth shared-library dependency")
T.eq(#run.loader.exports.enhanced_music.instrumentChoices, 3,
  "all active SoundFont presets are exposed to the settings menu")

local function select(song)
  return run.loader.hooks:call("music.select", function(chosen) return chosen end,
    song, { reason = "map" })
end
T.eq(select("Music_PalletTown"), "Music_PalletTown",
  "the engine keeps the original ROM label")
T.eq(sampler.song, "Music_PalletTown", "ROM song starts in the live sampler")
T.eq(run.loader.hooks:call("music.volume", function(v) return v end, 0.7, {}), 0,
  "vanilla chip audio is muted while live sampling succeeds")

T.eq(select("Music_OtherMod"), "Music_OtherMod", "file-backed songs pass through")
T.eq(sampler.song, nil, "unsupported music stops the sampler")
T.eq(run.loader.hooks:call("music.volume", function(v) return v end, 0.7, {}), 0.7,
  "other mods' file-backed music remains audible")

select("Music_WildBattle")
run.loader.modOptions.enhanced_music = { channel_1 = "preset:0:0" }
run.loader.events:emit("mod.options_changed",
  { mod = "enhanced_music", key = "soundfont", value = "rare" })
T.eq(sampler.style, "rare", "menu selection swaps the live bank")
T.eq(sampler.song, "Music_WildBattle", "current ROM song restarts on the new bank")

run.loader.events:emit("mod.options_changed",
  { mod = "enhanced_music", key = "channel_1", value = "preset:0:0" })
T.eq(sampler.channelPrograms[1].name, "Acoustic Grand Piano",
  "channel setting selects a preset from the active SoundFont")
T.eq(sampler.song, "Music_WildBattle",
  "changing a channel instrument restarts the current song")

local game = { save = { options = { musicVol = 4 } } }
run.loader.hooks:call("input.step", function() end, game, 1 / 60)
T.eq(sampler.updates, 1, "sampler queue is serviced each game step")
T.check(math.abs(sampler.volume - 0.8 * 4 / 7) < 0.000001,
  "live music follows the game's music volume")

run.loader.events:emit("music.stopped", { song = "Music_WildBattle" })
T.eq(sampler.song, nil, "engine music stop also stops live playback")

run.release()
_G.ENHANCED_MUSIC_TEST_SAMPLER = nil
_G.ENHANCED_MUSIC_TEST_SOUNDFONTS = nil
_G.ENHANCED_MUSIC_RUNTIME = nil
T.finish("enhanced music real-time")
