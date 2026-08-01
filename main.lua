local STYLES = {
  generaluser = {
    label = "GENERALUSER",
    files = { "GeneralUser-GS.sf2", "GeneralUser_GS.sf2" },
    env = "POKEPORT_SOUNDFONT_GENERALUSER",
  },
  musescore = {
    label = "MUSESCORE",
    files = { "MuseScore_General.sf3", "MuseScore_General.sf2" },
    env = "POKEPORT_SOUNDFONT_MUSESCORE",
  },
  fluidr3 = {
    label = "FLUID R3",
    files = { "FluidR3Mono_GM.sf3", "FluidR3_GM.sf2" },
    env = "POKEPORT_SOUNDFONT_FLUIDR3",
  },
  rare = {
    label = "RARE-INSPIRED",
    files = { "MuseScore_General.sf3", "MuseScore_General.sf2",
      "GeneralUser-GS.sf2" },
    env = "POKEPORT_SOUNDFONT_RARE",
  },
}

local function dirname(path)
  return type(path) == "string" and path:match("^(.*)[/\\][^/\\]+$") or nil
end

local function exists(path)
  if type(path) ~= "string" or path == "" then return false end
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

local function addRoot(roots, seen, root)
  if type(root) ~= "string" or root == "" or seen[root] then return end
  seen[root], roots[#roots + 1] = true, root:gsub("[/\\]+$", "")
end

local function soundfontRoots(mod)
  local roots, seen = {}, {}
  if love and love.filesystem then
    if love.filesystem.getSaveDirectory then
      addRoot(roots, seen, love.filesystem.getSaveDirectory() .. "/soundfonts")
    end
    if love.filesystem.getWorkingDirectory then
      local cwd = love.filesystem.getWorkingDirectory()
      addRoot(roots, seen, cwd .. "/soundfonts")
      addRoot(roots, seen, cwd)
    end
    if love.filesystem.getRealDirectory then
      for _, spec in pairs(STYLES) do
        for _, filename in ipairs(spec.files) do
          local logical = mod.path .. "/soundfonts/" .. filename
          local real = love.filesystem.getRealDirectory(logical)
          if real then
            addRoot(roots, seen, real .. "/" .. mod.path .. "/soundfonts")
          end
        end
      end
    end
  end
  local appDir = dirname(os.getenv("APPIMAGE"))
  if appDir then addRoot(roots, seen, appDir .. "/soundfonts") end
  addRoot(roots, seen, "/usr/share/soundfonts")
  addRoot(roots, seen, "/usr/share/sounds/sf2")
  -- Developer convenience only; packaged users use an adjacent or save-dir
  -- soundfonts folder. No path here is ever written by the mod.
  addRoot(roots, seen, "/tmp")
  return roots
end

local function findSoundfont(mod, style)
  local testing = rawget(_G, "ENHANCED_MUSIC_TEST_SOUNDFONTS")
  if testing and testing[style] then return testing[style] end
  local spec = STYLES[style]
  if not spec then return nil end
  local explicit = os.getenv(spec.env)
  if exists(explicit) then return explicit end
  for _, root in ipairs(soundfontRoots(mod)) do
    for _, filename in ipairs(spec.files) do
      local path = root .. "/" .. filename
      if exists(path) then return path end
    end
  end
  return nil
end

local function displayName(filename)
  return filename:gsub("%.[Ss][Ff][23]$", "")
end

local function discoverSoundfonts(mod)
  local testing = rawget(_G, "ENHANCED_MUSIC_TEST_DISCOVERED")
  if testing then return testing end
  local found, paths = {}, {}
  if not (love and love.filesystem and love.filesystem.getDirectoryItems
      and love.filesystem.getRealDirectory) then return found end

  local function scan(logicalRoot)
    local ok, items = pcall(love.filesystem.getDirectoryItems, logicalRoot)
    if not ok or type(items) ~= "table" then return end
    table.sort(items, function(a, b) return a:lower() < b:lower() end)
    for _, filename in ipairs(items) do
      if filename:lower():match("%.sf[23]$") then
        local logical = logicalRoot .. "/" .. filename
        local real = love.filesystem.getRealDirectory(logical)
        local path = real and (real:gsub("[/\\]+$", "") .. "/" .. logical)
        -- A bank inside a packed .g1mod has no native filesystem path for
        -- FluidSynth. Adjacent copies are found separately by findSoundfont.
        if path and exists(path) and not paths[path] then
          paths[path] = true
          found[#found + 1] = {
            key = "file:" .. filename:lower(), filename = filename,
            label = displayName(filename), path = path,
          }
        end
      end
    end
  end

  -- `soundfonts` is LÖVE's per-user save folder. The mod path also supports
  -- developers and players who install the mod as an unpacked directory.
  scan("soundfonts")
  scan(mod.path .. "/soundfonts")
  return found
end

local function loadSamplerClass(mod)
  local testing = rawget(_G, "ENHANCED_MUSIC_TEST_SAMPLER")
  if testing then return testing end
  local source = mod:read("lib/FluidSampler.lua")
  if not source then return nil, "lib/FluidSampler.lua is missing" end
  local chunk, err = load(source, "@" .. mod.path .. "/lib/FluidSampler.lua")
  if not chunk then return nil, err end
  local ok, class = pcall(chunk)
  if not ok then return nil, class end
  return class
end

return function(mod)
  local discovered = discoverSoundfonts(mod)
  local customBanks, customOrder, choices = {}, {}, { { "AUTO", "auto" } }
  local knownNames = {}
  for _, spec in pairs(STYLES) do
    for _, filename in ipairs(spec.files) do knownNames[filename:lower()] = true end
  end
  for _, style in ipairs({ "generaluser", "musescore", "fluidr3", "rare" }) do
    if findSoundfont(mod, style) then
      choices[#choices + 1] = { STYLES[style].label, style }
    end
  end
  for _, bank in ipairs(discovered) do
    if not knownNames[bank.filename:lower()] and not customBanks[bank.key] then
      customBanks[bank.key] = bank
      customOrder[#customOrder + 1] = bank.key
      choices[#choices + 1] = { bank.label, bank.key }
    end
  end

  mod.options:define({
    {
      key = "soundfont", type = "choice", label = "SOUNDFONT",
      choices = choices,
      default = "auto",
      help = "AUTO detects .sf2/.sf3 files dropped into the soundfonts folder.",
    },
  })

  local previous = rawget(_G, "ENHANCED_MUSIC_RUNTIME")
  if previous and previous.destroy then pcall(previous.destroy, previous) end

  local Sampler, classErr = loadSamplerClass(mod)
  if not Sampler then
    mod.log:error("Real-time sampler could not load: %s", tostring(classErr))
    return
  end
  local sampler = Sampler.new(mod.log)
  _G.ENHANCED_MUSIC_RUNTIME = sampler

  -- Engine 0.1.x's optional music.volume context reads a legacy global named
  -- `state` before consulting any hook. Vanilla never enters that branch.
  -- Supplying an empty compatibility view here lets this mod use the public
  -- volume hook without patching Music.lua; the hook below ignores the view.
  if rawget(_G, "state") == nil then _G.state = {} end

  local data, game, capturing = nil, nil, false
  local selected = mod.options:get("soundfont") or "auto"
  if selected ~= "auto" and not STYLES[selected] and not customBanks[selected] then
    selected = "auto"
  elseif STYLES[selected] and not findSoundfont(mod, selected) then
    selected = "auto"
  end

  local decoder
  local decoderOk, decoderValue = pcall(require, "src.core.ChipSynth")
  if decoderOk then decoder = decoderValue end

  local function resolveSelection(selection)
    local custom = customBanks[selection]
    if custom then return custom.path, "orchestral", custom.label end
    if selection == "auto" then
      -- A bank deliberately dropped by the user wins over bundled presets.
      local first = customOrder[1]
      if first then
        custom = customBanks[first]
        return custom.path, "orchestral", custom.label
      end
      for _, fallback in ipairs({ "generaluser", "musescore", "fluidr3" }) do
        local path = findSoundfont(mod, fallback)
        if path then return path, fallback, STYLES[fallback].label end
      end
      return nil, "orchestral", "AUTO"
    end
    local spec = STYLES[selection]
    if not spec then return nil, "orchestral", tostring(selection) end
    return findSoundfont(mod, selection), selection, spec.label
  end

  local function configure(selection, restartSong)
    local path, style, label = resolveSelection(selection)
    if not path then
      mod.log:warn("%s SoundFont not found. Drop an .sf2 or .sf3 file into the soundfonts folder.",
        label)
      return false
    end
    local ok, err = sampler:loadBank(path, style)
    if not ok then
      mod.log:warn("Could not activate %s: %s", label, tostring(err))
      return false
    end
    selected = selection
    mod.log:info("Live SoundFont set to %s (%s)", label, path)
    if restartSong and data and decoder then
      local started, startErr = sampler:start(data, restartSong, decoder)
      capturing = started == true
      if not started then mod.log:warn("Live song restart failed: %s", tostring(startErr)) end
    end
    return true
  end

  mod.events:on("mods.loaded", function(payload)
    data = payload and payload.data or data
    if not decoder then
      mod.log:warn("ROM song decoder unavailable; original chip music will be used")
      return
    end
    configure(selected)
  end)

  mod.events:on("game.ready", function(payload)
    game = payload and payload.game or game
  end)

  -- Capture the ROM label before the engine begins playback. If real-time
  -- synthesis starts successfully, music.volume mutes only that vanilla
  -- source; otherwise next() receives the untouched label and stays audible.
  mod.hooks:wrap("music.select", function(next, song, ctx)
    local def = data and data.audio and data.audio.songs and data.audio.songs[song]
    local supported = type(def) == "table" and type(def.engine) == "number"
    if supported and sampler.synth and decoder then
      if sampler.song ~= song then
        local ok, err = sampler:start(data, song, decoder)
        capturing = ok == true
        if not ok then mod.log:warn("Live synthesis failed for %s: %s", song, tostring(err)) end
      else
        capturing = true
      end
    else
      if sampler.song then sampler:stop() end
      capturing = false
    end
    return next(song, ctx)
  end, 100)

  mod.hooks:wrap("music.volume", function(next, volume, ctx)
    local value = next(volume, ctx)
    if capturing then return 0 end
    return value
  end, 100)

  mod.hooks:wrap("input.step", function(next, activeGame, dt)
    game = activeGame or game
    local options = game and game.save and game.save.options or {}
    local level = tonumber(options.musicVol)
    if level == nil then level = 7 end
    sampler:setVolume(0.8 * math.max(0, math.min(7, level)) / 7)
    sampler:update(dt)
    return next(activeGame, dt)
  end, 100)

  mod.events:on("music.stopped", function()
    sampler:stop()
    capturing = false
  end)

  mod.events:on("mod.options_changed", function(payload)
    if not (payload and payload.mod == mod.id and payload.key == "soundfont") then
      return
    end
    local style = payload.value
    if (style ~= "auto" and not STYLES[style] and not customBanks[style])
        or style == selected then return end
    local song = sampler.song
    configure(style, song)
  end)

  mod.exports.styles = STYLES
  mod.exports.soundfonts = discovered
  mod.exports.soundfontDisplayName = displayName
  mod.exports.runtime = true
  mod.exports.backend = "fluidsynth_ffi"
  mod.exports.requiresNativeLibrary = true
  mod.exports.writesMusicFiles = false
  mod.exports.sampler = sampler
end
