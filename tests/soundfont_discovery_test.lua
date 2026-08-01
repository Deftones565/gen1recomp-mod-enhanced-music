package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")

local FakeSampler = {}
function FakeSampler.new()
  return setmetatable({}, { __index = FakeSampler })
end
function FakeSampler:loadBank(path, style)
  self.synth, self.path, self.style = true, path, style
  return true
end
function FakeSampler:stop() self.song = nil end
function FakeSampler:setVolume() end
function FakeSampler:update() end
function FakeSampler:destroy() end

_G.ENHANCED_MUSIC_TEST_SAMPLER = FakeSampler
_G.ENHANCED_MUSIC_TEST_SOUNDFONTS = {
  generaluser = "/banks/GeneralUser-GS.sf2",
}

local oldWorkingDirectory = love.filesystem.getWorkingDirectory
local oldRealDirectory = love.filesystem.getRealDirectory
local oldOpen = io.open
local oldCacheFs = package.loaded["src.import.CacheFs"]
love.filesystem.getWorkingDirectory = function() return "/game" end
love.filesystem.getRealDirectory = function() return nil end
io.open = function(path, mode)
  if path == "/game/soundfonts/Warm-Piano.sf2" then
    return { close = function() end }
  end
  return oldOpen(path, mode)
end
package.loaded["src.import.CacheFs"] = {
  withMounted = function(root)
    if root == "/game/soundfonts" then return { "Warm-Piano.sf2" } end
  end,
}

local data = T.fixtures.fresh()
data.audio = { songs = {} }
local run = T.sdk.loadMod("mods/ENHANCED_MUSIC", { data = data })
local exports = run.loader.exports.enhanced_music
T.eq(exports.sampler.path, "/game/soundfonts/Warm-Piano.sf2",
  "AUTO prefers a user-dropped SoundFont")
T.eq(exports.sampler.style, "orchestral",
  "custom SoundFonts use the standard instrument mapping")
T.eq(exports.soundfonts[1].filename, "Warm-Piano.sf2",
  "discovered SoundFont is exposed to the mod menu")
T.eq(exports.soundfontDisplayName("My_Custom-Bank.sf3"), "My_Custom-Bank",
  "automatic menu name comes directly from the filename")

run.release()
love.filesystem.getWorkingDirectory = oldWorkingDirectory
love.filesystem.getRealDirectory = oldRealDirectory
io.open = oldOpen
package.loaded["src.import.CacheFs"] = oldCacheFs
_G.ENHANCED_MUSIC_TEST_SAMPLER = nil
_G.ENHANCED_MUSIC_TEST_SOUNDFONTS = nil
_G.ENHANCED_MUSIC_RUNTIME = nil
T.finish("enhanced music SoundFont discovery")
