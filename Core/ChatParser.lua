-- CraftersBoard - Chat Parser
-- Handles message classification and filtering

local CB = CraftersBoard

-- Noise filter terms
CB.RAID_DUNGEON_TERMS = {
  -- Raids
  "mc","molten core","molten","bwl","blackwing","blackwing lair","aq","aq20","aq40","temple of ahn'qiraj","ruins of ahn'qiraj",
  "zg","zul'gurub","zulgurub","ony","onyxia","onyxia's lair","naxx","naxxramas",
  -- Dungeons
  "rfc","ragefire chasm","wc","wailing caverns","sfk","shadowfang keep","bfd","blackfathom deeps",
  "stocks","stockade","stormwind stockade","gnomer","gnomeregan","rfk","razorfen kraul","sm","scarlet monastery",
  "smc","sm cath","cathedral","sml","sm lib","library","sm arm","armory","sm gy","graveyard",
  "razorfen","rfd","razorfen downs","uld","uldaman","zf","zulfarrak","mara","maraudon",
  "st","sunken temple","temple of atal'hakkar","brd","blackrock depths","lbrs","lower blackrock spire",
  "ubrs","upper blackrock spire","strat","stratholme","live strat","ud strat","scholo","scholomance",
  "dm","dire maul","dmn","dm north","dmw","dm west","dme","dm east","tribute",
  -- Additional common terms
  "dungeon","dungeons","raid","raids","instance","instances","boss","bosses","run","runs","clear","clears",
  "reserve","reserves","hr","sr","hard res","soft res","dkp","gdkp","loot council","roll","rolling",
  "need tank","need heal","need dps","tank lf","heal lf","dps lf"
}

CB.GROUP_TERMS = { 
  "lfg","lfm","lf %d", "lf%d", "looking for", "need", "need %d", "inv", "invite", "inviting",
  "group", "pug", "party", "hr", "hard res", "soft res", "gdkp", "dkp", "loot council",
  "forming", "starting", "recruiting", "taking", "spots", "spot", "full", "pst", "whisper",
  "link", "achievement", "gear check", "gearscore", "gs", "attune", "attuned", "key", "keyed"
}
CB.ROLE_TERMS  = { "tank","tanks","heal","heals","healer","healers","dps" }
CB.BOOST_TERMS = { "boost","carry","cleave","layer","selling run","sell run","powerlevel","plvl","rush" }

CB.CRAFTING_VERBS = {
  "craft","crafter","enchant","enchanter","ench","make","forge","smith","blacksmith",
  "tailor","tailoring","sew","transmute","xmute","smelt","engineer","cook",
  "leatherwork","leatherworker","lw","bs","alch","alchemy"
}

-- WoW raid target icon mappings
CB.RAID_TARGET_ICONS = {
  ["{rt1}"] = "[Star]",
  ["{rt2}"] = "[Circle]", 
  ["{rt3}"] = "[Diamond]",
  ["{rt4}"] = "[Triangle]",
  ["{rt5}"] = "[Moon]",
  ["{rt6}"] = "[Square]",
  ["{rt7}"] = "[Cross]",
  ["{rt8}"] = "[Skull]",
  ["{star}"] = "[Star]",
  ["{circle}"] = "[Circle]",
  ["{diamond}"] = "[Diamond]",
  ["{triangle}"] = "[Triangle]",
  ["{moon}"] = "[Moon]",
  ["{square}"] = "[Square]",
  ["{cross}"] = "[Cross]",
  ["{skull}"] = "[Skull]",
  ["{rt star}"] = "[Star]",
  ["{rt circle}"] = "[Circle]",
  ["{rt diamond}"] = "[Diamond]",
  ["{rt triangle}"] = "[Triangle]",
  ["{rt moon}"] = "[Moon]",
  ["{rt square}"] = "[Square]",
  ["{rt cross}"] = "[Cross]",
  ["{rt skull}"] = "[Skull]"
}

-- WoW raid target icon texture mappings (actual icons)
CB.RAID_TARGET_ICON_TEXTURES = {
  ["{rt1}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t",
  ["{rt2}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t",
  ["{rt3}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t",
  ["{rt4}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t",
  ["{rt5}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t",
  ["{rt6}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t",
  ["{rt7}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t",
  ["{rt8}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t",
  ["{star}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t",
  ["{circle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t",
  ["{diamond}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t",
  ["{triangle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t",
  ["{moon}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t",
  ["{square}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t",
  ["{cross}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t",
  ["{skull}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t",
  ["{rt star}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t",
  ["{rt circle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t",
  ["{rt diamond}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t",
  ["{rt triangle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t",
  ["{rt moon}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t",
  ["{rt square}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t",
  ["{rt cross}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t",
  ["{rt skull}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t"
}

-- Helper functions
function CB.ContainsAny(hay, needles)
  if not hay or hay == "" then return false end
  hay = " "..hay:lower().." "
  for _,n in ipairs(needles) do
    if n:find("%%d") then
      if hay:find(n) then return true end
    else
      if hay:find(" "..n.." ", 1, true) or hay:find(n, 1, true) then return true end
    end
  end
  return false
end

function CB.MergedTerms(base, extra)
  local out, seen = {}, {}
  local function addOne(s)
    s = CB.trim((s or ""):lower()); if s == "" or seen[s] then return end
    seen[s] = true; out[#out+1] = s
  end
  local function addList(list)
    if type(list) ~= "table" then return end
    for _,v in ipairs(list) do
      if type(v) == "string" and v:find(",") then
        for tok in v:gmatch("[^,]+") do addOne(tok) end
      else
        addOne(v)
      end
    end
  end
  addList(base); addList(extra)
  return out
end

-- Helper function for LFM/LFG pattern detection
local function hasLFMPattern(s)
  s = " "..(s or ""):lower().." "
  return s:find("%f[%a]lfm%f[%A]") or s:find("%f[%a]lfg%f[%A]") or s:find("%d+/%d+")
end

-- Message classification
function CB.LooksCraftingRelated(msg, profs)
  if profs and #profs > 0 then return true end
  local m = (msg or ""):lower()
  if CB.ContainsAny(m, CB.CRAFTING_VERBS) then return true end
  if m:find(" my mats ") or m:find(" have mats ") or m:find(" tip ") or m:find(" tips ") then return true end
  return false
end

function CB.IsGroupOrBoosting(msg)
  local m = (msg or ""):lower()
  local nc = CRAFTERSBOARD_DB.filters.noiseCustom or {}
  local RAID  = CB.MergedTerms(CB.RAID_DUNGEON_TERMS, nc.raids)
  local GROUP = CB.MergedTerms(CB.GROUP_TERMS,        nc.groups)
  local ROLE  = CB.MergedTerms(CB.ROLE_TERMS,         nc.roles)
  local BOOST = CB.MergedTerms(CB.BOOST_TERMS,        nc.boosts)

  if CB.ContainsAny(m, BOOST) then return true end
  local hasGroupish = CB.ContainsAny(m, GROUP) or hasLFMPattern(m)
  if not hasGroupish then return false end
  if CB.ContainsAny(m, ROLE) then return true end
  if CB.ContainsAny(m, RAID) then return true end
  return hasGroupish
end

function CB.ClassifyIntent(msg)
  local m = " "..(msg or ""):lower().." "
  if m:find("%f[%a]lfw%f[%A]") or m:find(" looking%s*for%s*work ") or m:find("%f[%a]wts%f[%A]") or m:find(" selling ") then
    return "PROVIDER"
  end
  if m:find("%f[%a]wtb%f[%A]") or m:find(" need ") or m:find(" need%s+an? ") or m:find("%f[%a]lf%f[%A]") or m:find(" looking%s*for ") then
    return "REQUESTER"
  end
  if (m:find(" craft ") or m:find(" make ") or m:find(" ench") or m:find(" enchant ")) then
    if m:find(" for me ") or m:find(" lf ") or m:find(" need ") then return "REQUESTER" end
    if m:find(" have mats ") or m:find(" my mats ") or m:find(" tips ") then return "PROVIDER" end
  end
  return "UNKNOWN"
end

function CB.NormalizeMessage(msg)
  local s = (msg or ""):lower(); s = s:gsub("%s+", " "); return CB.trim(s)
end

function CB.ParseIconMarkup(msg)
  if not msg or msg == "" then return msg end
  
  local cleaned = msg
  
  -- First, preserve all item links by storing them and replacing with placeholders
  local itemLinks = {}
  local linkCount = 0
  
  -- Match and preserve complete WoW item links: |cffxxxxxx|Hitem:....|h[Name]|h|r
  cleaned = cleaned:gsub("(\124c%x%x%x%x%x%x%x%x\124H[^\124]*\124h%[[^\]]*%]\124h\124r)", function(link)
    linkCount = linkCount + 1
    local placeholder = "<<ITEMLINK" .. linkCount .. ">>"
    itemLinks[placeholder] = link
    return placeholder
  end)
  
  -- Now safely process raid target icons (case insensitive) with actual textures
  local iconMappings = {
    ["{rt1}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t",
    ["{RT1}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t",
    ["{rt2}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t",
    ["{RT2}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t",
    ["{rt3}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t",
    ["{RT3}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t",
    ["{rt4}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t",
    ["{RT4}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t",
    ["{rt5}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t",
    ["{RT5}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t",
    ["{rt6}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t",
    ["{RT6}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t",
    ["{rt7}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t",
    ["{RT7}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t",
    ["{rt8}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t",
    ["{RT8}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t",
    ["{star}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t",
    ["{STAR}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t",
    ["{Star}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t",
    ["{circle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t",
    ["{CIRCLE}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t",
    ["{Circle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t",
    ["{diamond}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t",
    ["{DIAMOND}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t",
    ["{Diamond}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t",
    ["{triangle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t",
    ["{TRIANGLE}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t",
    ["{Triangle}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t",
    ["{moon}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t",
    ["{MOON}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t",
    ["{Moon}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t",
    ["{square}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t",
    ["{SQUARE}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t",
    ["{Square}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t",
    ["{cross}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t",
    ["{CROSS}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t",
    ["{Cross}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t",
    ["{skull}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t",
    ["{SKULL}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t",
    ["{Skull}"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t",
    -- Additional status icons
    ["{ready}"] = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0:0:0:0|t",
    ["{READY}"] = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0:0:0:0|t",
    ["{Ready}"] = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0:0:0:0|t",
    ["{assist}"] = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:0:0:0:0|t",
    ["{ASSIST}"] = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:0:0:0:0|t",
    ["{Assist}"] = "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:0:0:0:0|t"
  }
  
  -- Replace all known icon markup
  for pattern, replacement in pairs(iconMappings) do
    cleaned = cleaned:gsub(pattern:gsub("[{}()]", "%%%1"), replacement)
  end
  
  -- Handle any remaining {rt#} patterns
  cleaned = cleaned:gsub("{[Rr][Tt](%d+)}", function(num)
    local n = tonumber(num)
    if n == 1 then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0:0:0:0|t"
    elseif n == 2 then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0:0:0:0|t"
    elseif n == 3 then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0:0:0:0|t"
    elseif n == 4 then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0:0:0:0|t"
    elseif n == 5 then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0:0:0:0|t"
    elseif n == 6 then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0:0:0:0|t"
    elseif n == 7 then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0:0:0:0|t"
    elseif n == 8 then return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0:0:0:0|t"
    else return "[RT" .. num .. "]"
    end
  end)
  
  -- Clean up any remaining unknown {xxx} patterns
  cleaned = cleaned:gsub("{[^}]*}", "")
  
  -- Restore preserved item links
  for placeholder, link in pairs(itemLinks) do
    cleaned = cleaned:gsub(placeholder:gsub("[<>]", "%%%1"), link)
  end
  
  -- Normalize whitespace
  cleaned = cleaned:gsub("%s+", " ")
  
  return CB.trim(cleaned)
end

-- Test function for icon parsing (for development/debugging)
function CB.TestIconParsing()
  local testMessages = {
    "WTS enchants {rt1} great prices!",
    "LF smith {star} have mats {moon}",
    "Selling crafts {RT3} {RT5} PST",
    "{SKULL} Hardcore crafter {Diamond} all profs available",
    "Multiple {rt1} {rt2} {rt3} icons here",
    "Looking for work {Ready} {Assist}",
    "WTS |cff1eff00|Hitem:12345:0:0:0:0:0:0:0:60|h[Enchanted Item]|h|r {star} cheap!",
    "Have |cffffffff|Hitem:2589:0:0:0:0:0:0:0:0|h[Linen Cloth]|h|r and {moon} mats",
    "{rt star} and {rt moon} old format test", 
    "No icons in this message at all",
    "Mixed case {Star} {MOON} {rt4} test",
    "Item with icon |cff9d9d9d|Hitem:7073:0:0:0:0:0:0:0:0|h[Broken Fang]|h|r {diamond} 5g"
  }
  
  print("Testing WoW icon markup parsing (now with texture icons):")
  for i, msg in ipairs(testMessages) do
    local parsed = CB.ParseIconMarkup(msg)
    if msg ~= parsed then
      print("  " .. i .. ". BEFORE: " .. msg)
      print("       AFTER:  " .. parsed)
      -- Show if it contains texture markup
      if parsed:find("|T") then
        print("       NOTE:   Contains texture icons that will display as actual icons in-game")
      end
    else
      print("  " .. i .. ". (no change) " .. msg)
    end
    print("") -- Empty line for readability
  end
end

function CB.ExtractItemLinks(s)
  local out = {}
  for link in (s or ""):gmatch("(\124c%x+\124Hitem:%d+.-\124h\124r)") do 
    table.insert(out, link) 
  end
  return out
end

function CB.IsChannelAllowed(event, ...)
  if event ~= "CHAT_MSG_CHANNEL" then return true end
  local ch = select(4, ...) or select(9, ...) or ""; ch = (ch and ch:lower()) or ""
  local hints = CRAFTERSBOARD_DB.filters.channelHints or {}
  if #hints == 0 then return true end
  for _,needle in ipairs(hints) do 
    if needle ~= "" and ch:find(needle, 1, true) then return true end 
  end
  return false
end

-- Export functions to CB namespace
-- (Note: CB.ContainsAny etc. are already defined above as CB functions)
-- Just need to export the local functions that aren't already in CB namespace
