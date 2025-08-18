-- CraftersBoard - Core Initialization
-- Version: 1.0.0

local ADDON_NAME = ...

-- Create addon namespace
CraftersBoard = CraftersBoard or {}
local CB = CraftersBoard

-- Export addon name for other modules
CB.ADDON_NAME = ADDON_NAME

-- Core constants
CB.VERSION = "1.0.0"

-- Saved variables will be initialized here
CRAFTERSBOARD_DB = CRAFTERSBOARD_DB or {}

-- Math shortcuts
local max, floor, min = math.max, math.floor, math.min
local cos, sin, rad, deg = math.cos, math.sin, math.rad, math.deg

-- Utility functions
function CB.atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x == 0 then return (y > 0 and math.pi/2) or (y < 0 and -math.pi/2) or 0 end
  local a = math.atan(y/x)
  if x < 0 then a = a + (y >= 0 and math.pi or -math.pi) end
  return a
end

function CB.deepcopy(v)
  if type(v) ~= "table" then return v end
  local r = {}
  for k,val in pairs(v) do r[k] = CB.deepcopy(val) end
  return r
end

function CB.now()
  return (GetServerTime and GetServerTime()) or time()
end

function CB.trim(s)
  return (s or ""):gsub("^%s+",""):gsub("%s+$","")
end

function CB.agoStr(ts)
  local d = max(0, CB.now() - (ts or CB.now()))
  if d < 60 then return d.."s"
  elseif d < 3600 then return floor(d/60).."m"
  elseif d < 86400 then return floor(d/3600).."h"
  else
    local days = floor(d/86400)
    local rem  = d % 86400
    local h = floor(rem/3600)
    return string.format("%dd %dh", days, h)
  end
end

-- Print with addon prefix
function CB.Print(msg)
  print("|cff00ff88CraftersBoard|r " .. (msg or ""))
end

-- Legacy debug function for compatibility - redirects to DebugPrint  
function CB.Debug(msg)
  CB.DebugPrint(msg or "")
end
