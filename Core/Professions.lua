-- CraftersBoard - Profession System
-- Handles profession detection and classification

local CB = CraftersBoard

-- Profession keywords and mapping
CB.PROF_KEYWORDS = {
  Alchemy       = {"alchemy","alch","elixir","flask","transmute","xmute","pots","potion","arcanite","arcanite bar"},
  Blacksmithing = {"blacksmith","bs","smith","armorsmith","weaponsmith","enchanted thorium","mithril spurs","spurs"},
  Enchanting    = {"enchant","enchanter","crusader","fiery","spellpower","agility to","agi to","str to","int to","spirit to"},
  Engineering   = {"engineering","engineer","eng","reflector","scope","goblin","gnomish","sapper","jumper","rocket","bomb"},
  Leatherworking= {"leatherworking","leatherworker","lw","devilsaur","hide of the wild","black dragonscale","kits"},
  Tailoring     = {"tailoring","tailor","bag","mooncloth","robe","boots of the enchanter","spellfire","spellweave","netherweave","runecloth"},
  Cooking       = {"cooking","cook","chef","feast","dirge","smoked","stamina food","agi food","str food"},
  FirstAid      = {"first aid","bandage","anti-venom","antivenom"},
  Fishing       = {"fishing","angler","lure"},
  Herbalism     = {"herbalism","herbalist","herb"},
  Mining        = {"mining","miner","smelt","smelting"},
  Skinning      = {"skinning","skinner","skin"},
}

CB.PROF_ORDER = {
  "Alchemy","Blacksmithing","Enchanting","Engineering","Leatherworking",
  "Tailoring","Cooking","FirstAid","Fishing","Herbalism","Mining","Skinning","Unknown"
}

-- Build keyword to profession mapping
CB.KEYWORD2PROF = {}
for prof, words in pairs(CB.PROF_KEYWORDS) do 
  for _,w in ipairs(words) do 
    CB.KEYWORD2PROF[w] = prof 
  end 
end

-- Extract professions from message
function CB.ExtractProfessions(msg)
  local found = {}; local m = (msg or ""):lower()
  for kw, prof in pairs(CB.KEYWORD2PROF) do 
    if m:find(kw, 1, true) then 
      found[prof] = true 
    end 
  end
  local out = {}; 
  for p,_ in pairs(found) do 
    table.insert(out, p) 
  end
  table.sort(out); 
  return out
end

-- Parse profession levels from guild notes
function CB.NumberNearKeyword(s, kw)
  local l = s:lower()
  local e = CB.EscapePattern(kw:lower())
  local n = l:match(e.."%s*[:=-]?%s*([1-3]?%d?%d)") or l:match("([1-3]?%d?%d)%s*[:=-]?%s*"..e)
  if n then return tonumber(n) end
  if l:find(e..".-max") or l:find("max.-"..e) then return 300 end
  return nil
end

function CB.ParseProfLevelsFromText(text)
  local out = {}
  if not text or text == "" then return out end
  local lower = text:lower()
  local present = {}
  for kw, prof in pairs(CB.KEYWORD2PROF) do 
    if lower:find(kw, 1, true) then 
      present[prof] = true 
    end 
  end
  for prof,_ in pairs(present) do
    local best
    for _,kw in ipairs(CB.PROF_KEYWORDS[prof] or {}) do
      local n = CB.NumberNearKeyword(lower, kw)
      if n then 
        n = math.max(1, math.min(300, n)); 
        best = math.max(best or 0, n) 
      end
    end
    if best and best > 0 then out[prof] = best end
  end
  return out
end

-- Utility function
function CB.EscapePattern(s) 
  return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")) 
end
