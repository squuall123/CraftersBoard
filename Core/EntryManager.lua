-- CraftersBoard - Entry Management
-- Version: 1.0.0
-- Handles adding, updating, and managing crafting entries

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

-- Entry management functions
local function normalizeMessage(msg)
  return (msg or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function extractItemLinks(s)
  local links = {}
  if not s then return links end
  for link in s:gmatch("|c%x+|H.-|h%[.-%]|h|r") do
    table.insert(links, link)
  end
  return links
end

-- Main entry add/refresh function
function CB.addOrRefreshEntry(player, msg, kind, profs, channel)
  if CB.IsPlayerMuted and CB.IsPlayerMuted(player) then return nil end
  if CB.IsMessageMuted and CB.IsMessageMuted(msg) then return nil end

  local nm   = normalizeMessage(msg)
  local tnow = CB.now()
  local links = extractItemLinks(msg)

  -- Remove older duplicates from the same player with identical normalized message
  local previous
  for i = #CRAFTERSBOARD_DB.entries, 1, -1 do
    local e = CRAFTERSBOARD_DB.entries[i]
    if e and e.player == player and e.norm == nm then
      previous = previous or e
      table.remove(CRAFTERSBOARD_DB.entries, i)
    end
  end

  local entry = {
    player  = player,
    message = msg,
    norm    = nm,
    kind    = kind or (previous and previous.kind) or "UNKNOWN",
    profs   = profs or (previous and previous.profs) or {},
    channel = channel or (previous and previous.channel) or "",
    links   = links,
    time    = tnow,
  }

  -- Insert at the beginning (most recent first)
  table.insert(CRAFTERSBOARD_DB.entries, 1, entry)

  -- Enforce max entries limit
  local maxEntries = CRAFTERSBOARD_DB.maxEntries or 300
  while #CRAFTERSBOARD_DB.entries > maxEntries do
    table.remove(CRAFTERSBOARD_DB.entries)
  end

  return entry
end

-- Data grouping functions
function CB.GroupEntriesByProfession(kind, query)
  local grouped = {}
  
  -- Initialize profession groups
  for _, prof in ipairs(CB.PROF_ORDER or {"Other"}) do 
    grouped[prof] = {} 
  end
  
  local q = (query or ""):lower()
  
  -- Process entries from newest to oldest so newer entries appear first in groups
  for i = #CRAFTERSBOARD_DB.entries, 1, -1 do
    local e = CRAFTERSBOARD_DB.entries[i]
    if e and e.kind == kind then
      local shouldInclude = true
      
      -- Apply search filter
      if shouldInclude and q ~= "" then
        local searchText = ((e.player or "") .. " " .. (e.message or "") .. " " .. 
                           table.concat(e.profs or {}, " ")):lower()
        if not searchText:find(q, 1, true) then
          shouldInclude = false
        end
      end
      
      -- Skip muted entries
      if shouldInclude and CB.IsPlayerMuted and CB.IsPlayerMuted(e.player) then 
        shouldInclude = false 
      end
      if shouldInclude and CB.IsMessageMuted and CB.IsMessageMuted(e.message) then 
        shouldInclude = false 
      end
      
      -- Strict render-time filter (affects both Workers & Looking For)
      if shouldInclude and CRAFTERSBOARD_DB.filters.strict then
        local m = e.message or ""
        local groupish = CB.IsGroupOrBoosting and CB.IsGroupOrBoosting(m) or false
        local instanceish = CB.ContainsAny and CB.ContainsAny(m:lower(), CB.RAID_DUNGEON_TERMS) or false
        local crafting = CB.LooksCraftingRelated and CB.LooksCraftingRelated(m, e.profs) or false
        
        -- Drop if it mentions instances/raids and is not clearly crafting related
        if instanceish and not crafting then
          shouldInclude = false
        end
        
        -- Drop if it's groupish and either not crafting or mentions instances
        if shouldInclude and groupish and (not crafting or instanceish) then
          shouldInclude = false
        end
      end
      
      -- Group by primary profession or "Other"
      if shouldInclude then
        local prof = (e.profs and e.profs[1]) or "Other"
        if grouped[prof] then
          table.insert(grouped[prof], 1, e)  -- Insert at beginning for newest-first order
        else
          if not grouped["Other"] then grouped["Other"] = {} end
          table.insert(grouped["Other"], 1, e)  -- Insert at beginning for newest-first order
        end
      end
    end
  end
  
  return grouped
end

function CB.GroupGuildByProfession(query)
  local grouped = {}
  
  -- Initialize profession groups
  for _, prof in ipairs(CB.PROF_ORDER or {"Other"}) do 
    grouped[prof] = {} 
  end
  
  local q = (query or ""):lower()
  local members = CRAFTERSBOARD_DB.guildScan.members or {}
  
  for _, member in ipairs(members) do
    if member and member.profs then
      local shouldInclude = true
      
      -- Apply search filter
      if shouldInclude and q ~= "" then
        local searchText = ((member.name or "") .. " " .. (member.note or "") .. " " .. 
                           (member.officerNote or "") .. " " .. table.concat(member.profs, " ")):lower()
        if not searchText:find(q, 1, true) then
          shouldInclude = false
        end
      end
      
      -- Group by each profession the member has
      if shouldInclude then
        for prof, level in pairs(member.profs) do
          if prof and level and level > 0 then
            if grouped[prof] then
              table.insert(grouped[prof], member)
            end
          end
        end
      end
    end
  end
  
  return grouped
end

-- Collapse state management
function CB.IsCollapsed(kind, prof)
  local collapsed = CRAFTERSBOARD_DB.collapsed or {}
  local kindCollapsed = collapsed[kind] or {}
  return kindCollapsed[prof] == true
end

function CB.SetCollapsed(kind, prof, val)
  CRAFTERSBOARD_DB.collapsed = CRAFTERSBOARD_DB.collapsed or {}
  CRAFTERSBOARD_DB.collapsed[kind] = CRAFTERSBOARD_DB.collapsed[kind] or {}
  CRAFTERSBOARD_DB.collapsed[kind][prof] = val and true or nil
end

-- Export functions
CB.normalizeMessage = normalizeMessage
CB.extractItemLinks = extractItemLinks
