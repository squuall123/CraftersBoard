-- CraftersBoard - Event Handling
-- Version: 1.0.0

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

-- Create event handler frame
local eventFrame = CreateFrame("Frame")
CB.eventFrame = eventFrame

-- UI reference
local UI = CB.UI

-- Register all events
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
eventFrame:RegisterEvent("CHAT_MSG_YELL")
eventFrame:RegisterEvent("CHAT_MSG_SAY")
eventFrame:RegisterEvent("CHAT_MSG_GUILD")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")

-- Helper function to check if channel is allowed
local function isChannelAllowed(event, ...)
  if event ~= "CHAT_MSG_CHANNEL" then return true end
  
  local channelName = select(4, ...) or select(9, ...)
  if not channelName then return false end
  
  channelName = channelName:lower()
  local hints = CRAFTERSBOARD_DB.filters.channelHints or {"general","trade","commerce","lookingforgroup","services"}
  
  -- DEBUG: Log channel filtering
  CB.Debug("Channel filtering - channel:" .. channelName .. " hints:" .. table.concat(hints, ","))
  
  for _, hint in ipairs(hints) do
    if channelName:find(hint:lower(), 1, true) then
      CB.Debug("Channel allowed - matched hint:" .. hint)
      return true
    end
  end
  
  CB.Debug("Channel not allowed - no matching hints")
  return false
end

-- Helper function to try hooking Auctionator
local function TryHookAuctionator()
  if not Auctionator then return end
  
  -- Hook Auctionator tooltip functions if available
  if Auctionator.Tooltip and Auctionator.Tooltip.AddPriceToTooltip then
    -- Already hooked or available
    CB.auctionatorAvailable = true
  end
end

-- Helper to compute last seen timestamp for guild members
local function computeLastSeenTS(index, online)
  if online then return CB.now() end
  if not GetGuildRosterLastOnline then return nil end
  local y,m,d,h = GetGuildRosterLastOnline(index)
  if not y and not m and not d and not h then return nil end
  y,m,d,h = y or 0, m or 0, d or 0, h or 0
  local days = y*365 + m*30 + d
  local secs = days*86400 + h*3600
  return CB.now() - secs
end

-- Helper function to rebuild guild workers
local function rebuildGuildWorkers()
  local data = { lastScan = CB.now(), members = {} }
  if not IsInGuild or not IsInGuild() then
    CRAFTERSBOARD_DB.guildScan = data
    return
  end
  
  if GuildRoster then GuildRoster() end
  local numMembers = GetNumGuildMembers and GetNumGuildMembers() or 0
  
  for i = 1, numMembers do
    local name, rank, rankIndex, level, class, zone, note, officerNote, online, status, classFileName = GetGuildRosterInfo(i)
    if name then
      name = name or "?"
      local combined = CB.trim((note or "").." "..(officerNote or ""))
      local profLevels = CB.ParseProfLevelsFromText and CB.ParseProfLevelsFromText(combined) or {}
      
      -- Check if member has any profession levels
      local hasAny = false
      for _ in pairs(profLevels) do hasAny = true; break end
      
      if hasAny then
        table.insert(data.members, {
          index = i,
          name = name,
          rank = rank,
          level = level or 0,
          class = class,
          classFile = classFileName,
          online = online,
          zone = zone,
          note = note,
          officerNote = officerNote,
          profs = profLevels,
          lastSeen = computeLastSeenTS(i, online),
        })
      end
    end
  end
  
  CRAFTERSBOARD_DB.guildScan = data
end

-- Main event handler
eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == ADDON_NAME then
      -- Initialize database first
      if CB.InitDatabase then 
        CB.InitDatabase() 
        -- DEBUG: Show channel hints after DB init
        local hints = CRAFTERSBOARD_DB.filters.channelHints or {}
        CB.Debug("After DB init, channel hints:" .. table.concat(hints, ","))
      end
      
      -- Initialize all systems
      if CB.createUI then CB.createUI() end
      if CB.createOptionsPanel then 
        CB.createOptionsPanel()
        if CB.EnsureOptionsCategory then CB.EnsureOptionsCategory() end
      end
      if CB.createMinimapButton then CB.createMinimapButton() end
      
      -- Initialize ProfessionLinks module
      if CB.ProfessionLinks and CB.ProfessionLinks.Initialize then
        CB.ProfessionLinks.Initialize()
      end
      
      TryHookAuctionator()
      
      print("|cff00ff88CraftersBoard|r loaded. Type |cffffff00/cb|r to toggle.")
    elseif name == "Auctionator" then
      TryHookAuctionator()
    end
  elseif event == "PLAYER_LOGOUT" then
    -- Save profession cache and stop auto-save timer
    if CB.ProfessionLinks then
      if CB.ProfessionLinks.SaveCache then
        CB.ProfessionLinks.SaveCache()
      end
      if CB.ProfessionLinks.StopAutoSave then
        CB.ProfessionLinks.StopAutoSave()
      end
    end
    if UI and UI.frame and UI.frame:IsShown() and UI.Force then UI.Force() end
    return
    
  elseif event == "PLAYER_LOGIN" then
    TryHookAuctionator()
    return
    
  elseif event == "GUILD_ROSTER_UPDATE" then
    rebuildGuildWorkers()
    if UI and UI.frame and UI.frame:IsShown() and UI.activeKind == "GUILD" and UI.Force then
      UI.Force()
    end
    return
  end

  -- Chat events
  local msg, player = ...
  local channelName
  
  -- Parse and clean icon markup from the message
  if msg and CB.ParseIconMarkup then
    local originalMsg = msg
    msg = CB.ParseIconMarkup(msg)
    if originalMsg ~= msg then
      CB.Debug("Icon markup parsed - before:" .. originalMsg:sub(1,50) .. " after:" .. msg:sub(1,50))
    end
  end
  
  -- Handle different chat event types
  if event == "CHAT_MSG_CHANNEL" then
    channelName = select(4, ...) or select(9, ...)
    CB.Debug("Channel name:" .. (channelName or "nil"))
    if not isChannelAllowed(event, ...) then
      CB.Debug("Channel not allowed")
      return 
    end
  else
    -- Handle other chat events (SAY, YELL, GUILD)
    channelName = (event == "CHAT_MSG_SAY" and "SAY") or (event == "CHAT_MSG_YELL" and "YELL") or (event == "CHAT_MSG_GUILD" and "GUILD") or ""
    CB.Debug("Non-channel event " .. event .. " mapped to channel:" .. (channelName or "nil"))
  end

  CB.Debug("Chat event " .. event .. " from " .. tostring(player or "?") .. " msg:" .. (msg or ""):sub(1,50))

  -- Quick pre-filter & classification
  CB.Debug("Function checks - ExtractProfessions:" .. (CB.ExtractProfessions and "exists" or "missing"))
  CB.Debug("Function checks - LooksCraftingRelated:" .. (CB.LooksCraftingRelated and "exists" or "missing"))
  CB.Debug("Function checks - ClassifyIntent:" .. (CB.ClassifyIntent and "exists" or "missing"))
  
  local profs = CB.ExtractProfessions and CB.ExtractProfessions(msg) or {}
  local crafting = CB.LooksCraftingRelated and CB.LooksCraftingRelated(msg, profs) or false
  local intent = CB.ClassifyIntent and CB.ClassifyIntent(msg) or "UNKNOWN"

  -- DEBUG: Log parsing results
  CB.Debug("Professions found:" .. (#profs > 0 and table.concat(profs, ",") or "none"))
  CB.Debug("Crafting related:" .. tostring(crafting) .. " Intent:" .. (intent or "nil"))

  -- Strict mode filtering
  if CRAFTERSBOARD_DB.filters.strict then
    local m = (msg or ""):lower()
    local groupish = CB.IsGroupOrBoosting and CB.IsGroupOrBoosting(msg) or false
    local instanceish = CB.ContainsAny and CB.ContainsAny(m, CB.RAID_DUNGEON_TERMS) or false
    local crafting = CB.LooksCraftingRelated and CB.LooksCraftingRelated(msg, profs) or false
    
    CB.Debug("Strict mode analysis - groupish:" .. tostring(groupish) .. " instanceish:" .. tostring(instanceish) .. " crafting:" .. tostring(crafting))
    
    -- Drop if it mentions instances/raids and is not clearly crafting related
    if instanceish and not crafting then
      CB.Debug("Dropped by strict mode - mentions instances/raids without clear crafting context")
      return
    end
    
    -- Drop if it's groupish and either not crafting or mentions instances
    if groupish then
      if not crafting or instanceish then
        CB.Debug("Dropped by strict mode - groupish and either not crafting or mentions instances")
        return
      end
    end
  end

  -- Filter out messages with no clear intent or professions
  if intent == "UNKNOWN" and #profs == 0 then
    CB.Debug("Skipped - no intent and no professions")
    return
  end

  -- Add entry
  CB.Debug("Adding entry for " .. (player or "unknown"))
  if CB.addOrRefreshEntry then
    local entry = CB.addOrRefreshEntry(player, msg, intent, profs, channelName)
    CB.Debug("Entry added:" .. (entry and "success" or "failed"))
  else
    CB.Debug("addOrRefreshEntry function not found!")
  end

  -- Refresh UI if visible
  if UI and UI.frame and UI.frame:IsShown() and UI.Force then
    UI.Force()
  end
end)

-- Export functions
CB.rebuildGuildWorkers = rebuildGuildWorkers
CB.TryHookAuctionator = TryHookAuctionator
