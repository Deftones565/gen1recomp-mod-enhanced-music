package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")

local presets = {
  { bank = 128, program = 0, name = "Standard Drum Kit" },
  { bank = 0, program = 73, name = "Flute" },
  { bank = 0, program = 0, name = "Acoustic Grand Piano" },
}
local position = 0
local selected = {}
local lib = {
  fluid_synth_get_sfont_by_id = function(_, id)
    return id == 7 and {} or nil
  end,
  fluid_sfont_iteration_start = function() position = 0 end,
  fluid_sfont_iteration_next = function()
    position = position + 1
    return presets[position]
  end,
  fluid_preset_get_name = function(preset) return preset.name end,
  fluid_preset_get_banknum = function(preset) return preset.bank end,
  fluid_preset_get_num = function(preset) return preset.program end,
  fluid_synth_program_select = function(_, channel, sfid, bank, program)
    selected[channel] = { sfid = sfid, bank = bank, program = program }
    return 0
  end,
  fluid_synth_pitch_wheel_sens = function() return 0 end,
  fluid_synth_cc = function() return 0 end,
}

local Sampler = dofile("mods/ENHANCED_MUSIC/lib/FluidSampler.lua")
local sampler = setmetatable({
  ffi = { string = function(value) return value end },
  lib = lib,
  synth = {},
  sfid = 7,
  style = "orchestral",
  channelPrograms = {},
}, { __index = Sampler })

local found = sampler:listPresets()
T.eq(#found, 3, "enumerates every preset in the loaded SoundFont")
T.eq(found[1].name, "Acoustic Grand Piano", "sorts presets by bank and program")
T.eq(found[2].program, 73, "preserves the MIDI program number")
T.eq(found[3].bank, 128, "preserves percussion bank numbers")
sampler:setPresetCatalog(found)

sampler:setChannelPrograms({
  [1] = { bank = 0, program = 73 },
  [4] = { bank = 128, program = 0 },
})
sampler:programSong("Music_Routes1")
T.eq(selected[0].program, 73, "custom preset replaces channel 1 mapping")
T.eq(selected[1].bank, 0, "AUTO keeps the normal channel 2 mapping")
T.eq(selected[9].bank, 128, "custom drum preset maps to MIDI channel 10")
T.eq(selected[9].program, 0, "drum kit program is preserved")

local goldenEye = {
  { bank = 0, program = 0, name = "Guitar (Clean)" },
  { bank = 0, program = 1, name = "Drum Kit (Far)" },
  { bank = 0, program = 20, name = "Flute" },
  { bank = 0, program = 51, name = "Bass (Pop)" },
  { bank = 0, program = 58, name = "Drum Kit (Close)" },
  { bank = 0, program = 61, name = "French Horn" },
  { bank = 0, program = 63, name = "Strings Section" },
}
sampler:setPresetCatalog(goldenEye)
T.check(not sampler.generalMidi, "custom game SoundFont is not mistaken for GM")
local town = sampler:autoPrograms("Music_PalletTown")
T.eq(town[1].program, 20, "custom bank AUTO finds its flute lead")
T.eq(town[2].program, 0, "custom bank AUTO finds its clean guitar harmony")
T.eq(town[3].program, 51, "custom bank AUTO finds its bass")
T.eq(town[4].program, 58, "custom bank AUTO finds its preferred drum kit")
local battle = sampler:autoPrograms("Music_WildBattle")
T.eq(battle[1].program, 61, "battle AUTO finds brass in a custom bank")
T.eq(battle[2].program, 63, "battle AUTO finds strings in a custom bank")

local gm = {}
for _, program in ipairs({ 0, 19, 24, 32, 43, 48, 60, 68, 73 }) do
  gm[#gm + 1] = { bank = 0, program = program, name = "GM " .. program }
end
gm[#gm + 1] = { bank = 128, program = 0, name = "Standard Drum Kit" }
sampler:setPresetCatalog(gm)
T.check(sampler.generalMidi, "standard melodic coverage and bank 128 detect GM")
local gmTown = sampler:autoPrograms("Music_PalletTown")
T.eq(gmTown[1].program, 73, "GM AUTO keeps the exact lead program")
T.eq(gmTown[4].bank, 128, "GM AUTO keeps the standard percussion bank")

T.finish("enhanced music instrument presets")
