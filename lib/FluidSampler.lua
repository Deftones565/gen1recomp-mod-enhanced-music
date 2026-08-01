-- Real-time ROM-song -> SoundFont sampler. Nothing in this module writes a
-- file: FluidSynth reads the user's bank and renders directly into LÖVE
-- QueueableSource buffers held in memory.

local FluidSampler = {}
FluidSampler.__index = FluidSampler

local RATE = 44100
local FRAMES = 2048
local BUFFERS = 8
local EPSILON = 1 / RATE / 2

local PALETTES = {
  orchestral = {
    town = { 73, 24, 32 }, travel = { 68, 48, 33 },
    battle = { 60, 48, 34 }, dark = { 52, 19, 43 },
    gentle = { 11, 73, 32 },
  },
  rare = {
    town = { 105, 71, 32 }, travel = { 22, 110, 58 },
    battle = { 61, 45, 58 }, dark = { 79, 19, 43 },
    gentle = { 12, 70, 32 },
  },
}

local function category(name)
  if name:find("Battle") or name:find("Defeated") or name:find("Gym")
      or name:find("Evil") or name:find("Final") then return "battle" end
  if name:find("Lavender") or name:find("Tower") or name:find("Dungeon")
      or name:find("Mansion") or name:find("Silph") then return "dark" end
  if name:find("Route") or name:find("Bike") or name:find("Surf")
      or name:find("Safari") then return "travel" end
  if name:find("PkmnHealed") or name:find("Pokecenter")
      or name:find("Jiggly") then return "gentle" end
  return "town"
end

local function midiPitch(event, hardware)
  local frequency = 131072 / (2048 - math.min(event.register, 2047))
  if hardware == 3 then frequency = frequency * 0.5 end
  local exact = 69 + 12 * math.log(frequency / 440) / math.log(2)
  local note = math.max(0, math.min(127, math.floor(exact + 0.5)))
  return note, exact - note
end

local function drumPitch(event)
  local parameter = event.noiseParameter
  if not parameter and event.drum and event.drum[1] then
    parameter = event.drum[1].parameter
  end
  local bit = require("bit")
  local shift = bit.rshift(parameter or 0x54, 4)
  if shift <= 3 then return 42 end
  if shift <= 7 then return 38 end
  return 36
end

local function getenv(name)
  local testing = rawget(_G, "ENHANCED_MUSIC_TEST_ENV")
  if testing then return testing[name] end
  return os.getenv(name)
end

local function platformName()
  local testing = rawget(_G, "ENHANCED_MUSIC_TEST_OS")
  if testing then return testing end
  return jit and jit.os or "Unknown"
end

local function addCandidate(candidates, seen, value)
  if type(value) ~= "string" or value == "" or seen[value] then return end
  seen[value] = true
  candidates[#candidates + 1] = value
end

local function join(root, leaf)
  if type(root) ~= "string" or root == "" then return nil end
  return root:gsub("[/\\]+$", "") .. "/" .. leaf
end

local function dirname(path)
  if type(path) ~= "string" then return nil end
  return path:match("^(.*)[/\\][^/\\]+$")
end

local function localLibraryRoots()
  local testing = rawget(_G, "ENHANCED_MUSIC_TEST_LIBRARY_ROOTS")
  if testing then return testing end

  local roots, seen = {}, {}
  local function addLibRoot(base)
    addCandidate(roots, seen, join(base, "lib"))
  end

  -- Support application layouts that keep optional native dependencies in a
  -- lib directory instead of installing them into the global loader path.
  addCandidate(roots, seen, getenv("POKEPORT_FLUIDSYNTH_DIR"))
  addLibRoot(dirname(getenv("APPIMAGE")))

  if love and love.filesystem then
    if love.filesystem.getSourceBaseDirectory then
      local ok, base = pcall(love.filesystem.getSourceBaseDirectory)
      if ok then addLibRoot(base) end
    end
    if love.filesystem.getWorkingDirectory then
      local ok, base = pcall(love.filesystem.getWorkingDirectory)
      if ok then addLibRoot(base) end
    end
  end

  local arguments = rawget(_G, "arg")
  if type(arguments) == "table" then addLibRoot(dirname(arguments[0])) end
  return roots
end

local function addLibrariesInRoots(candidates, seen, roots, names, pattern)
  for _, root in ipairs(roots) do
    for _, name in ipairs(names) do
      if name:match(pattern) then
        addCandidate(candidates, seen, join(root, name))
      end
    end
  end
end

local function libraryCandidates()
  local candidates, seen = {}, {}

  -- This is the reliable escape hatch for package-manager layouts that are
  -- not part of the platform's normal dynamic-library search path.
  addCandidate(candidates, seen, getenv("POKEPORT_FLUIDSYNTH_LIBRARY"))

  local platform = platformName()
  if platform == "Windows" then
    local names = {
      "libfluidsynth-3.dll", "libfluidsynth-3",
      "libfluidsynth.dll", "fluidsynth.dll", "fluidsynth",
    }
    for _, name in ipairs(names) do addCandidate(candidates, seen, name) end
    addLibrariesInRoots(candidates, seen, localLibraryRoots(), names, "%.dll$")

    -- PATH is already searched by LoadLibrary, but package managers commonly
    -- keep their DLLs in a private prefix until the user adds it to PATH.
    local roots, rootSeen = {}, {}
    addCandidate(roots, rootSeen, join(getenv("ProgramFiles"), "FluidSynth/bin"))
    addCandidate(roots, rootSeen, join(getenv("ProgramFiles(x86)"), "FluidSynth/bin"))
    addCandidate(roots, rootSeen, join(getenv("VCPKG_ROOT"), "installed/x64-windows/bin"))
    addCandidate(roots, rootSeen, join(getenv("MSYSTEM_PREFIX"), "bin"))
    for _, root in ipairs(roots) do
      for _, name in ipairs(names) do
        if name:match("%.dll$") then
          addCandidate(candidates, seen, join(root, name))
        end
      end
    end
  elseif platform == "OSX" then
    local names = {
      "libfluidsynth.3.dylib", "libfluidsynth.dylib", "fluidsynth",
    }
    for _, name in ipairs(names) do addCandidate(candidates, seen, name) end
    addLibrariesInRoots(candidates, seen, localLibraryRoots(), names, "%.dylib$")
    for _, root in ipairs({ "/opt/homebrew/lib", "/usr/local/lib", "/opt/local/lib" }) do
      for _, name in ipairs(names) do
        if name:match("%.dylib$") then
          addCandidate(candidates, seen, join(root, name))
        end
      end
    end
  else
    local names = { "libfluidsynth.so.3", "libfluidsynth.so", "fluidsynth" }
    for _, name in ipairs(names) do addCandidate(candidates, seen, name) end
    addLibrariesInRoots(candidates, seen, localLibraryRoots(), names, "%.so")
    local roots, rootSeen = {}, {}
    addCandidate(roots, rootSeen, join(getenv("HOME"), ".local/lib"))
    for _, root in ipairs({ "/usr/local/lib", "/usr/lib64", "/usr/lib",
        "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu" }) do
      addCandidate(roots, rootSeen, root)
    end
    for _, root in ipairs(roots) do
      for _, name in ipairs(names) do
        if name:match("%.so") then addCandidate(candidates, seen, join(root, name)) end
      end
    end
  end
  return candidates
end

local function loadFluid()
  local ok, ffi = pcall(require, "ffi")
  if not ok then return nil, nil, "LuaJIT FFI is unavailable" end
  pcall(ffi.cdef, [[
    typedef struct _fluid_settings_t fluid_settings_t;
    typedef struct _fluid_synth_t fluid_synth_t;
    fluid_settings_t *new_fluid_settings(void);
    void delete_fluid_settings(fluid_settings_t *settings);
    int fluid_settings_setnum(fluid_settings_t *, const char *, double);
    int fluid_settings_setint(fluid_settings_t *, const char *, int);
    fluid_synth_t *new_fluid_synth(fluid_settings_t *settings);
    void delete_fluid_synth(fluid_synth_t *synth);
    int fluid_synth_sfload(fluid_synth_t *, const char *, int);
    int fluid_synth_program_select(fluid_synth_t *, int, int, int, int);
    int fluid_synth_noteon(fluid_synth_t *, int, int, int);
    int fluid_synth_noteoff(fluid_synth_t *, int, int);
    int fluid_synth_pitch_bend(fluid_synth_t *, int, int);
    int fluid_synth_pitch_wheel_sens(fluid_synth_t *, int, int);
    int fluid_synth_cc(fluid_synth_t *, int, int, int);
    int fluid_synth_all_notes_off(fluid_synth_t *, int);
    int fluid_synth_all_sounds_off(fluid_synth_t *, int);
    int fluid_synth_write_s16(fluid_synth_t *, int,
      void *, int, int, void *, int, int);
  ]])
  local candidates = libraryCandidates()
  local lastError
  for _, name in ipairs(candidates) do
    local loaded, lib = pcall(ffi.load, name)
    if loaded then return ffi, lib, nil, name end
    lastError = lib
  end
  local message = "FluidSynth was not found for " .. platformName()
    .. ". Install its native library and make it available through the system "
    .. "library path, or set POKEPORT_FLUIDSYNTH_LIBRARY to its full path."
  if lastError then message = message .. " Last loader error: " .. tostring(lastError) end
  return ffi, nil, message
end

local function newSource()
  return love.audio.newQueueableSource(RATE, 16, 2, BUFFERS)
end

function FluidSampler.new(log)
  local ffi, lib, err, libraryPath = loadFluid()
  local self = setmetatable({
    ffi = ffi, lib = lib, log = log, error = err,
    libraryPath = libraryPath,
    source = nil, synth = nil, settings = nil, sfid = nil,
    engine = nil, states = {}, pool = {}, poolIndex = 1,
    data = nil, song = nil, style = nil, path = nil, volume = 0.8,
  }, FluidSampler)
  return self
end

function FluidSampler:isAvailable()
  return self.lib ~= nil and love and love.audio and love.sound
end

function FluidSampler:destroySynth()
  self:stop()
  if self.synth then
    self.lib.delete_fluid_synth(self.synth)
    self.synth = nil
  end
  if self.settings then
    self.lib.delete_fluid_settings(self.settings)
    self.settings = nil
  end
  self.sfid = nil
end

function FluidSampler:loadBank(path, style)
  if not self:isAvailable() then return false, self.error or "audio unavailable" end
  local lib = self.lib
  local settings = lib.new_fluid_settings()
  if settings == nil then return false, "could not create FluidSynth settings" end
  lib.fluid_settings_setnum(settings, "synth.sample-rate", RATE)
  lib.fluid_settings_setnum(settings, "synth.gain", 0.65)
  lib.fluid_settings_setint(settings, "synth.polyphony", 64)
  lib.fluid_settings_setint(settings, "synth.chorus.active", 1)
  lib.fluid_settings_setint(settings, "synth.reverb.active", 1)
  local synth = lib.new_fluid_synth(settings)
  if synth == nil then
    lib.delete_fluid_settings(settings)
    return false, "could not create FluidSynth"
  end
  local sfid = lib.fluid_synth_sfload(synth, path, 1)
  if sfid < 0 then
    lib.delete_fluid_synth(synth)
    lib.delete_fluid_settings(settings)
    return false, "FluidSynth could not load " .. tostring(path)
  end
  -- Only retire the playing bank after its replacement loaded completely.
  -- A missing/corrupt menu choice therefore leaves the current music alive.
  local oldSynth, oldSettings = self.synth, self.settings
  self:stop()
  if oldSynth then lib.delete_fluid_synth(oldSynth) end
  if oldSettings then lib.delete_fluid_settings(oldSettings) end
  self.settings, self.synth, self.sfid = settings, synth, sfid
  self.path, self.style = path, style
  return true
end

function FluidSampler:allOff()
  if not self.synth then return end
  for channel = 0, 15 do
    self.lib.fluid_synth_all_notes_off(self.synth, channel)
    self.lib.fluid_synth_all_sounds_off(self.synth, channel)
  end
end

function FluidSampler:stop()
  if self.source then pcall(self.source.stop, self.source) end
  self:allOff()
  self.source, self.engine, self.states = nil, nil, {}
  self.pool, self.poolIndex = {}, 1
  self.song = nil
end

function FluidSampler:setVolume(value)
  self.volume = math.max(0, math.min(1, tonumber(value) or 0.8))
  if self.source then pcall(self.source.setVolume, self.source, self.volume) end
end

function FluidSampler:programSong(song)
  local palette = PALETTES[self.style == "rare" and "rare" or "orchestral"]
  local programs = palette[category(song)]
  for channel = 0, 2 do
    self.lib.fluid_synth_program_select(self.synth, channel,
      self.sfid, 0, programs[channel + 1])
    self.lib.fluid_synth_pitch_wheel_sens(self.synth, channel, 2)
    self.lib.fluid_synth_cc(self.synth, channel, 10, channel == 0 and 48 or 80)
  end
  self.lib.fluid_synth_pitch_wheel_sens(self.synth, 9, 2)
end

function FluidSampler:noteOff(state)
  if state.note ~= nil then
    self.lib.fluid_synth_noteoff(self.synth, state.midiChannel, state.note)
    state.note = nil
  end
end

function FluidSampler:advance(state)
  self:noteOff(state)
  local event = state.channel:nextEvent()
  if not event then state.done = true; state.remaining = math.huge; return end
  state.remaining = math.max(tonumber(event.duration) or 0, EPSILON)
  if event.silence then return end
  local hardware = state.channel.hardware
  local note, bend
  if hardware == 4 then
    note, bend = drumPitch(event), 0
  elseif event.register then
    note, bend = midiPitch(event, hardware)
  end
  if not note then return end
  local velocity = hardware == 4 and 68
    or math.max(25, math.min(110, math.floor((event.volume or 10) / 15 * 105)))
  self.lib.fluid_synth_pitch_bend(self.synth, state.midiChannel,
    math.max(0, math.min(16383, math.floor(8192 + bend * 4096 + 0.5))))
  self.lib.fluid_synth_noteon(self.synth, state.midiChannel, note, velocity)
  state.note = note
end

function FluidSampler:start(data, song, decoder)
  if not self.synth then return false, "no SoundFont is loaded" end
  local def = data and data.audio and data.audio.songs and data.audio.songs[song]
  if type(def) ~= "table" or type(def.engine) ~= "number" then
    return false, "song is not a ROM chip program"
  end
  self:stop()
  self.data, self.song = data, song
  self:programSong(song)
  local ok, engine = pcall(decoder.newEngine, data, def, { allowLoops = true })
  if not ok then self.song = nil; return false, tostring(engine) end
  self.engine, self.states = engine, {}
  for _, channel in ipairs(engine.channels) do
    self.states[#self.states + 1] = {
      channel = channel,
      midiChannel = channel.hardware == 4 and 9 or channel.hardware - 1,
      remaining = 0,
    }
  end
  self.source = newSource()
  self.source:setVolume(self.volume)
  for index = 1, BUFFERS do
    self.pool[index] = love.sound.newSoundData(FRAMES, RATE, 16, 2)
  end
  self.poolIndex = 1
  self:update()
  return true
end

function FluidSampler:render(buffer)
  local pointer = self.ffi.cast("int16_t *", buffer:getPointer())
  local offset = 0
  while offset < FRAMES do
    local nearest = math.huge
    for _, state in ipairs(self.states) do
      local guard = 0
      while not state.done and state.remaining <= EPSILON and guard < 32 do
        guard = guard + 1
        self:advance(state)
      end
      if state.remaining < nearest then nearest = state.remaining end
    end
    local frames = FRAMES - offset
    if nearest < math.huge then
      frames = math.min(frames, math.max(1, math.floor(nearest * RATE + 0.5)))
    end
    self.lib.fluid_synth_write_s16(self.synth, frames,
      pointer, offset * 2, 2, pointer, offset * 2 + 1, 2)
    local elapsed = frames / RATE
    for _, state in ipairs(self.states) do
      if not state.done then state.remaining = state.remaining - elapsed end
    end
    offset = offset + frames
  end
end

function FluidSampler:update()
  if not (self.source and self.engine) then return end
  local free = self.source:getFreeBufferCount()
  while free > 0 do
    local buffer = self.pool[self.poolIndex]
    self:render(buffer)
    self.source:queue(buffer)
    self.poolIndex = self.poolIndex % #self.pool + 1
    free = free - 1
  end
  if not self.source:isPlaying() then self.source:play() end
end

function FluidSampler:destroy()
  self:destroySynth()
end

return FluidSampler
