-- CraftersBoard - Database Management
-- Handles saved variables and defaults

local CB = CraftersBoard

-- Default configuration
CB.DEFAULTS = {
  filters = {
    showProviders = true,
    showRequesters = true,
    search = "",
    channelHints = {"general","trade","commerce","lookingforgroup","services"},
    strict = true, -- drop LFG/boost/raid messages unless clearly crafting related
    noiseCustom = { raids = {}, groups = {}, roles = {}, boosts = {} }, -- user-managed extra noise
  },
  debug = false, -- Enable debug output
  entries = {},
  maxEntries = 300,
  minimap = { show = true, angle = 200 },
  collapsed = { PROVIDER = {}, REQUESTER = {}, GUILD = {} },
  guildScan = { lastScan = 0, members = {} },
  window = { w = 840, h = 420, point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
  muted = { players = {}, phrases = {} },
  lastTab = 1,
}

-- Initialize database with defaults
function CB.InitDatabase()
  if type(CRAFTERSBOARD_DB) ~= "table" then CRAFTERSBOARD_DB = {} end
  
  for k,v in pairs(CB.DEFAULTS) do
    if CRAFTERSBOARD_DB[k] == nil then
      CRAFTERSBOARD_DB[k] = (type(v) == "table") and CB.deepcopy(v) or v
    end
  end
  
  -- Ensure sub-tables exist
  CRAFTERSBOARD_DB.entries   = CRAFTERSBOARD_DB.entries   or {}
  CRAFTERSBOARD_DB.minimap   = CRAFTERSBOARD_DB.minimap   or CB.deepcopy(CB.DEFAULTS.minimap)
  CRAFTERSBOARD_DB.collapsed = CRAFTERSBOARD_DB.collapsed or CB.deepcopy(CB.DEFAULTS.collapsed)
  CRAFTERSBOARD_DB.guildScan = CRAFTERSBOARD_DB.guildScan or CB.deepcopy(CB.DEFAULTS.guildScan)
  CRAFTERSBOARD_DB.window    = CRAFTERSBOARD_DB.window    or CB.deepcopy(CB.DEFAULTS.window)
  CRAFTERSBOARD_DB.muted     = CRAFTERSBOARD_DB.muted     or CB.deepcopy(CB.DEFAULTS.muted)
  CRAFTERSBOARD_DB.lastTab   = CRAFTERSBOARD_DB.lastTab   or CB.DEFAULTS.lastTab
  CRAFTERSBOARD_DB.filters   = CRAFTERSBOARD_DB.filters   or CB.deepcopy(CB.DEFAULTS.filters)
  CRAFTERSBOARD_DB.debug     = (CRAFTERSBOARD_DB.debug ~= nil) and CRAFTERSBOARD_DB.debug or CB.DEFAULTS.debug
  
  local f = CRAFTERSBOARD_DB.filters
  f.noiseCustom = f.noiseCustom or { raids = {}, groups = {}, roles = {}, boosts = {} }
  f.channelHints = f.channelHints or CB.deepcopy(CB.DEFAULTS.filters.channelHints)
  f.showProviders = (f.showProviders ~= nil) and f.showProviders or CB.DEFAULTS.filters.showProviders
  f.showRequesters = (f.showRequesters ~= nil) and f.showRequesters or CB.DEFAULTS.filters.showRequesters
  f.strict = (f.strict ~= nil) and f.strict or CB.DEFAULTS.filters.strict
  f.search = f.search or CB.DEFAULTS.filters.search
end

-- Prune old entries
function CB.ParseDuration(s)
  s = CB.trim(s or "")
  if s == "" then return 60*60, "60m" end
  local n, u = s:match("^(%d+)%s*([smhdSMHD]?)$")
  n = tonumber(n or "0") or 0
  if n <= 0 then return 60*60, "60m" end
  u = (u or ""):lower()
  local secs, label
  if u == "s" then secs, label = n, (n.."s")
  elseif u == "h" then secs, label = n*60*60, (n.."h")
  elseif u == "d" then secs, label = n*24*60*60, (n.."d")
  else secs, label = n*60, (n.."m") end
  return secs, label
end

function CB.PruneEntries(olderThanSeconds)
  local cutoff = CB.now() - (olderThanSeconds or 60*60)
  local removed = 0
  for i = #CRAFTERSBOARD_DB.entries, 1, -1 do
    local e = CRAFTERSBOARD_DB.entries[i]
    if e and (e.time or 0) < cutoff then
      table.remove(CRAFTERSBOARD_DB.entries, i)
      removed = removed + 1
    end
  end
  return removed
end

-- Money display utilities
CB.GOLD_TEX   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
CB.SILVER_TEX = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
CB.COPPER_TEX = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

function CB.MoneyTextureString(c)
  if not c or c <= 0 then return "—" end
  if GetCoinTextureString then return GetCoinTextureString(c) end
  local g = floor(c/10000); local s = floor((c%10000)/100); local cp = c % 100
  local parts = {}
  if g > 0 then table.insert(parts, g..CB.GOLD_TEX) end
  if s > 0 or g > 0 then table.insert(parts, s..CB.SILVER_TEX) end
  table.insert(parts, cp..CB.COPPER_TEX)
  return table.concat(parts, " ")
end

-- Export alias for compatibility
CB.initDB = CB.InitDatabase

-- Debug function
function CB.DebugPrint(...)
  if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
    print("|cff00ff88[CB Debug]|r", ...)
  end
end