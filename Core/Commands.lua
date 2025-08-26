-- CraftersBoard - Slash Commands
-- Version: 1.0.0

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

-- UI reference
local UI = CB.UI

-- Helper function to parse duration
function CB.parseDuration(s)
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

-- Helper function to prune entries
function CB.pruneEntries(olderThanSeconds)
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

-- Main slash command handler
local function handleSlashCommand(msg)
  msg = CB.trim(msg or "")
  
  if msg == "" or msg == "toggle" then
    if CB.ToggleWindow then
      CB.ToggleWindow()
    elseif UI.frame then
      if UI.frame:IsShown() then 
        UI.frame:Hide() 
      else 
        UI.frame:Show()
        if UI.Force then UI.Force() elseif UI.render then UI.render() end
      end
    end
    return
  end

  local cmd, rest = msg:match("^(%S+)%s*(.*)$")
  cmd = (cmd or ""):lower()
  rest = rest or ""

  if cmd == "search" then
    CRAFTERSBOARD_DB.filters.search = rest:lower()
    if UI.search then UI.search:SetText(rest) end
    if UI.Force then UI.Force() elseif UI.render then UI.render() end

  elseif cmd == "clear" then
    CRAFTERSBOARD_DB.entries = {}
    print("|cff00ff88CraftersBoard|r cleared entries.")
    if UI.Force then UI.Force() elseif UI.render then UI.render() end

  elseif cmd == "providers" then
    CRAFTERSBOARD_DB.filters.showProviders = (rest:lower()=="on")
    if UI.Force then UI.Force() elseif UI.render then UI.render() end

  elseif cmd == "requesters" then
    CRAFTERSBOARD_DB.filters.showRequesters = (rest:lower()=="on")
    if UI.Force then UI.Force() elseif UI.render then UI.render() end

  elseif cmd == "channels" then
    local hints = {}
    for token in rest:gmatch("[^,]+") do 
      table.insert(hints, CB.trim(token:lower())) 
    end
    CRAFTERSBOARD_DB.filters.channelHints = hints
    print("|cff00ff88CraftersBoard|r Channel hints set to:", table.concat(hints, ", "))

  elseif cmd == "workers" or cmd == "prov" or cmd == "providers" or cmd == "tab1" then
    if UI.setActiveTab then UI.setActiveTab(1) end

  elseif cmd == "looking" or cmd == "req" or cmd == "requesters" or cmd == "tab2" then
    if UI.setActiveTab then UI.setActiveTab(2) end

  elseif cmd == "guild" or cmd == "tab3" then
    if UI.setActiveTab then UI.setActiveTab(3) end

  elseif cmd == "gscan" or cmd == "guildscan" then
    if not IsInGuild or not IsInGuild() then 
      print("|cff00ff88CraftersBoard|r You are not in a guild.") 
      return 
    end
    if GuildRoster then GuildRoster() end
    if CB.rebuildGuildWorkers then CB.rebuildGuildWorkers() end
    print("|cff00ff88CraftersBoard|r Guild scan complete. Found "..(#(CRAFTERSBOARD_DB.guildScan.members or {})).." workers.")
    if UI and UI.Force then UI.Force() end

  elseif cmd == "prune" or cmd == "cleanup" or cmd == "cleanold" then
    local secs, label = CB.parseDuration(rest)
    local removed = CB.pruneEntries(secs)
    print(string.format("|cff00ff88CraftersBoard|r pruned %d entr%s older than %s.",
      removed, removed == 1 and "y" or "ies", label))
    if UI and UI.Force then UI.Force() elseif UI and UI.render then UI.render() end

  elseif cmd == "mmb" then
    local sub, val = rest:match("^(%S+)%s*(.*)$")
    sub = (sub or ""):lower()
    if sub == "on" or sub == "show" then
      CRAFTERSBOARD_DB.minimap.show = true
      if CB.UpdateMinimapButton then CB.UpdateMinimapButton() end
      if CB.MMB and CB.MMB.button then 
        CB.MMB.button:Show()
        if CB.MMB_UpdatePosition then CB.MMB_UpdatePosition() end
      end
    elseif sub == "off" or sub == "hide" then
      CRAFTERSBOARD_DB.minimap.show = false
      if CB.UpdateMinimapButton then CB.UpdateMinimapButton() end
      if CB.MMB and CB.MMB.button then CB.MMB.button:Hide() end
    elseif sub == "angle" then
      local ang = tonumber(val)
      if ang then 
        CRAFTERSBOARD_DB.minimap.angle = (ang % 360)
        if CB.MMB_UpdatePosition then CB.MMB_UpdatePosition() end
      else 
        print("|cff00ff88CraftersBoard|r Usage: /cb mmb angle <0-359>") 
      end
    elseif sub == "reset" then
      CRAFTERSBOARD_DB.minimap.show = true
      CRAFTERSBOARD_DB.minimap.angle = 200
      if CB.MMB and CB.MMB.button then 
        CB.MMB.button:Show()
        if CB.MMB_UpdatePosition then CB.MMB_UpdatePosition() end
      end
    else
      print("|cff00ff88CraftersBoard|r mmb commands: on|off|show|hide  •  angle <0-359>  •  reset")
    end

  elseif cmd == "mute" then
    local sub, val = rest:match("^(%S+)%s*(.*)$")
    sub = (sub or ""):lower()
    if sub == "player" and val ~= "" then
      if CB.MutePlayer then CB.MutePlayer(val) end
      print("|cff00ff88CraftersBoard|r muted player:", val)
      if UI and UI.Force then UI.Force() end
    elseif sub == "phrase" and val ~= "" then
      if CB.AddMutePhrase then CB.AddMutePhrase(val) end
      print("|cff00ff88CraftersBoard|r muted phrase:", val)
      if UI and UI.Force then UI.Force() end
    else
      print("|cff00ff88CraftersBoard|r Usage: /cb mute player <name>  |  /cb mute phrase <text>")
    end

  elseif cmd == "unmute" then
    local sub, val = rest:match("^(%S+)%s*(.*)$")
    sub = (sub or ""):lower()
    if sub == "player" and val ~= "" then
      if CB.UnmutePlayer then CB.UnmutePlayer(val) end
      print("|cff00ff88CraftersBoard|r unmuted player:", val)
      if UI and UI.Force then UI.Force() end
    elseif sub == "phrase" and val ~= "" then
      if CB.RemoveMutePhrase then CB.RemoveMutePhrase(val) end
      print("|cff00ff88CraftersBoard|r removed muted phrase:", val)
      if UI and UI.Force then UI.Force() end
    else
      print("|cff00ff88CraftersBoard|r Usage: /cb unmute player <name>  |  /cb unmute phrase <text>")
    end

  elseif cmd == "strict" then
    local on = rest:lower()
    if on == "on" or on == "1" or on == "true" then
      CRAFTERSBOARD_DB.filters.strict = true
      print("|cff00ff88CraftersBoard|r strict filtering: ON")
    elseif on == "off" or on == "0" or on == "false" then
      CRAFTERSBOARD_DB.filters.strict = false
      print("|cff00ff88CraftersBoard|r strict filtering: OFF")
    else
      print("|cff00ff88CraftersBoard|r strict is "..(CRAFTERSBOARD_DB.filters.strict and "ON" or "OFF")..". Use: /cb strict on|off")
    end
    if UI and UI.Force then UI.Force() end

  elseif cmd == "noise" then
    local sub, cat, rest2 = rest:match("^(%S+)%s*(%S*)%s*(.*)$")
    sub = (sub or ""):lower()
    cat = (cat or ""):lower()
    local nc = CRAFTERSBOARD_DB.filters.noiseCustom or { raids={},groups={},roles={},boosts={} }
    local map = { raids = "raids", groups = "groups", roles = "roles", boosts = "boosts" }
    local key = map[cat]
    if sub == "add" and key then
      nc[key] = nc[key] or {}
      for tok in (rest2 or ""):gmatch("[^,]+") do 
        table.insert(nc[key], CB.trim(tok)) 
      end
      print("|cff00ff88CraftersBoard|r added to "..key..": "..(rest2 or ""))
    elseif sub == "clear" and key then
      nc[key] = {}
      print("|cff00ff88CraftersBoard|r cleared "..key.." custom terms.")
    elseif sub == "list" then
      local function join(t) 
        local s={}
        for _,v in ipairs(t or {}) do s[#s+1]=v end
        return #s>0 and table.concat(s,", ") or "—" 
      end
      print("|cff00ff88CraftersBoard|r custom noise terms:")
      print("  raids:  "..join(nc.raids))
      print("  groups: "..join(nc.groups))
      print("  roles:  "..join(nc.roles))
      print("  boosts: "..join(nc.boosts))
      print("Usage: /cb noise add <raids|groups|roles|boosts> term1,term2  |  /cb noise clear <cat>")
    else
      print("|cff00ff88CraftersBoard|r noise usage:")
      print("  /cb noise add <raids|groups|roles|boosts> term1,term2")
      print("  /cb noise list")
      print("  /cb noise clear <raids|groups|roles|boosts>")
    end

  elseif cmd == "mutes" then
    local sub = rest:lower()
    if sub == "clear" then
      CRAFTERSBOARD_DB.muted = { players = {}, phrases = {} }
      print("|cff00ff88CraftersBoard|r cleared all mutes.")
      if UI and UI.Force then UI.Force() end
    else
      local players = {}
      if CRAFTERSBOARD_DB.muted and CRAFTERSBOARD_DB.muted.players then
        for n,_ in pairs(CRAFTERSBOARD_DB.muted.players) do table.insert(players, n) end
        table.sort(players)
      end
      local phrases = {}
      if CRAFTERSBOARD_DB.muted and CRAFTERSBOARD_DB.muted.phrases then
        for p,_ in pairs(CRAFTERSBOARD_DB.muted.phrases) do table.insert(phrases, p) end
        table.sort(phrases)
      end
      print("|cff00ff88CraftersBoard|r Muted players: "..(#players > 0 and table.concat(players, ", ") or "—"))
      print("|cff00ff88CraftersBoard|r Muted phrases: "..(#phrases > 0 and table.concat(phrases, " | ") or "—"))
      print("|cff00ff88CraftersBoard|r (/cb mutes clear  to wipe)")
    end

  elseif cmd == "options" or cmd == "settings" or cmd == "config" then
    if CB.OpenOptionsPanel then CB.OpenOptionsPanel() end

  elseif cmd == "testicons" or cmd == "icontest" then
    if CB.TestIconParsing then 
      CB.TestIconParsing() 
    else
      print("|cff00ff88CraftersBoard|r Icon parsing test function not available.")
    end
    
  elseif cmd == "testdict" then
    if CB.DataDictionary and CB.DataDictionary.CompressProfessionData then
      print("|cff00ff88CraftersBoard|r Testing dictionary compression system...")
      print("  Using external Data/Vanilla.lua mappings")
      
      -- Test compression with sample data
      local sampleSnapshot = {
        name = "Test Player",
        rank = 300,
        maxRank = 300,
        timestamp = time(),
        recipes = {
          {name = "Flask of the Titans", type = "optimal", category = "Alchemy"},
          {name = "Mooncloth", type = "optimal", category = "Tailoring"}
        }
      }
      
      local compressed = CB.DataDictionary.CompressProfessionData(sampleSnapshot)
      local decompressed = CB.DataDictionary.DecompressProfessionData(compressed)
      local ratio = CB.DataDictionary.CalculateCompressionRatio(sampleSnapshot, compressed)
      
      print("  Original data: " .. (sampleSnapshot and "Valid" or "Invalid"))
      print("  Compressed: " .. (compressed and "Success" or "Failed"))
      print("  Decompressed: " .. (decompressed and "Success" or "Failed"))
      print("  Compression ratio: " .. string.format("%.1f", ratio) .. "%")
    else
      print("|cff00ff88CraftersBoard|r DataDictionary module not available.")
    end
  
  elseif cmd == "professionfilter" or cmd == "filtertest" then
    -- Test profession filtering functionality  
    local professionName = rest or "Alchemy"
    if CB.DataDictionary then
      local DD = CB.DataDictionary
      
      -- Get profession ID from name
      local professionId = DD.GetProfessionId(professionName)
      if not professionId then
        CB.Print("Profession not found: " .. tostring(professionName))
        CB.Print("Available professions:")
        local professions = DD.GetAvailableProfessions()
        for _, prof in ipairs(professions) do
          CB.Print("  - " .. prof.name .. " (ID: " .. prof.id .. ", Recipes: " .. prof.recipeCount .. ")")
        end
        return
      end
      
      CB.Print("Testing profession filter for: " .. DD.GetProfessionName(professionId) .. " (ID: " .. professionId .. ")")
      
      -- Get recipes for this profession
      local recipes = DD.GetRecipesByProfession(professionId)
      local count = 0
      local sampleRecipes = {}
      
      for spellId, recipeName in pairs(recipes) do
        count = count + 1
        if count <= 5 then  -- Show first 5 as samples
          table.insert(sampleRecipes, recipeName .. " (ID: " .. spellId .. ")")
        end
      end
      
      CB.Print("Found " .. count .. " recipes for " .. DD.GetProfessionName(professionId))
      if #sampleRecipes > 0 then
        CB.Print("Sample recipes:")
        for _, recipe in ipairs(sampleRecipes) do
          CB.Print("  - " .. recipe)
        end
        if count > 5 then
          CB.Print("  ... and " .. (count - 5) .. " more")
        end
      end
    else
      CB.Print("DataDictionary module not available.")
    end
    if CB.DataDictionary and CB.DataDictionary.CompressProfessionData then
      print("|cff00ff88CraftersBoard|r Testing dictionary compression system...")
      print("  Using external Data/Vanilla.lua mappings")
      
      -- Show dictionary stats
      local spellCount = 0
      if CB.DataDictionary.SPELL_TO_RECIPE then
        for _ in pairs(CB.DataDictionary.SPELL_TO_RECIPE) do
          spellCount = spellCount + 1
        end
      end
      print("  Loaded " .. spellCount .. " spell ID mappings")
      
      -- Create sample profession data
      local sampleData = {
        name = "Alchemy",
        rank = 300,
        maxRank = 300,
        timestamp = time(),
        recipes = {
          {
            name = "Flask of the Titans",
            type = "craft",
            category = "Alchemy", 
            reagents = {
              {name = "Gromsblood", required = 30, available = 25},
              {name = "Stonescale Oil", required = 10, available = 15},
              {name = "Black Lotus", required = 2, available = 1}
            }
          },
          {
            name = "Major Healing Potion",
            type = "craft", 
            category = "Alchemy",
            reagents = {
              {name = "Mountain Silversage", required = 2, available = 10},
              {name = "Crystal Vial", required = 1, available = 20}
            }
          },
          {
            name = "Transmute: Arcanite",
            type = "craft",
            category = "Alchemy",
            reagents = {
              {name = "Arcane Crystal", required = 1, available = 0},
              {name = "Thorium Bar", required = 1, available = 5}
            }
          }
        },
        categories = {}
      }
      
      -- Test compression
      local compressed = CB.DataDictionary.CompressProfessionData(sampleData)
      if compressed then
        print("✓ Dictionary compression successful")
        print("  Original recipes: " .. #sampleData.recipes)
        print("  Compressed recipes: " .. #compressed.rc)
        
        -- Show spell ID usage
        local idsUsed = 0
        local namesUsed = 0
        for _, recipe in ipairs(compressed.rc) do
          if recipe.id then
            idsUsed = idsUsed + 1
          else
            namesUsed = namesUsed + 1
          end
        end
        print("  Recipes using spell IDs: " .. idsUsed)
        print("  Recipes using names (fallback): " .. namesUsed)
        
        -- Test decompression
        local decompressed = CB.DataDictionary.DecompressProfessionData(compressed)
        if decompressed then
          print("✓ Dictionary decompression successful")
          print("  Decompressed recipes: " .. #decompressed.recipes)
          print("  Recipe names match: " .. (decompressed.recipes[1].name == sampleData.recipes[1].name and "✓" or "✗"))
          
          -- Calculate size reduction
          local ratio = CB.DataDictionary.CalculateCompressionRatio(sampleData, compressed)
          print("  Compression efficiency: " .. string.format("%.1f", ratio) .. "%")
          print("✓ External dictionary data working correctly!")
        else
          print("✗ Dictionary decompression failed")
        end
      else
        print("✗ Dictionary compression failed")
      end
    else
      print("|cff00ff88CraftersBoard|r DataDictionary module not available.")
    end
    
  elseif cmd == "dictinfo" then
    -- Show dictionary information and statistics
    if CB.DataDictionary then
      print("|cff00ff88CraftersBoard|r Dictionary Information:")
      
      -- Use the new profession statistics function
      local stats = CB.DataDictionary.GetProfessionStatistics()
      
      print("  Data source: " .. stats.dataSource)
      print("  Total recipes: " .. stats.totalRecipes)
      print("  Recipes by profession:")
      
      -- Sort professions by ID for consistent display
      local sortedProfessions = {}
      for professionId, profData in pairs(stats.professions) do
        table.insert(sortedProfessions, {
          id = professionId,
          name = profData.name,
          count = profData.recipeCount
        })
      end
      
      table.sort(sortedProfessions, function(a, b) return a.id < b.id end)
      
      for _, prof in ipairs(sortedProfessions) do
        print("    " .. prof.name .. " (ID: " .. prof.id .. "): " .. prof.count .. " recipes")
      end
      
      -- Show spell ID usage efficiency
      local spellCount = 0
      if CB.DataDictionary.SPELL_TO_RECIPE then
        for _ in pairs(CB.DataDictionary.SPELL_TO_RECIPE) do
          spellCount = spellCount + 1
        end
      end
      
      print("  Dictionary entries: " .. spellCount .. " spell IDs mapped")
      
      -- Show sample profession filtering
      if CB.DataDictionary.RECIPES_BY_PROFESSION then
        print("  Available professions for filtering:")
        local professions = CB.DataDictionary.GetAvailableProfessions()
        for i, prof in ipairs(professions) do
          if i <= 3 then  -- Show first 3 as examples
            print("    - " .. prof.name .. " (" .. prof.recipeCount .. " recipes)")
          end
        end
        if #professions > 3 then
          print("    ... and " .. (#professions - 3) .. " more")
        end
      end
      
      -- Show categories and types
      local categoryCount = 0
      if CB.DataDictionary.CATEGORY_TO_ID then
        for _ in pairs(CB.DataDictionary.CATEGORY_TO_ID) do
          categoryCount = categoryCount + 1
        end
      end
      
      local typeCount = 0
      if CB.DataDictionary.TYPE_TO_ID then
        for _ in pairs(CB.DataDictionary.TYPE_TO_ID) do
          typeCount = typeCount + 1
        end
      end
      
      print("  Categories defined: " .. categoryCount)
      print("  Types defined: " .. typeCount)
      
      -- Show data source
      if CraftersBoard_VanillaData then
        print("  Data source: External Data/Vanilla.lua ✓")
      else
        print("  Data source: External data not loaded ✗")
      end
      
    else
      print("|cff00ff88CraftersBoard|r DataDictionary module not available.")
    end
    
  -- ProfessionLinks commands integration
  elseif cmd == "link" or cmd == "post" or cmd == "trade" or cmd == "group" or cmd == "party" or cmd == "raid" or cmd == "scan" or 
         cmd == "info" or cmd == "snapshots" or cmd == "cache" or 
         cmd == "cleanup" or cmd == "stats" or cmd == "viewer" or cmd == "ui" or
         cmd == "test" or cmd == "clear" then
    -- Route to ProfessionLinks module
    if CB.ProfessionLinks and CB.ProfessionLinks.HandleSlashCommand then
      CB.ProfessionLinks.HandleSlashCommand(msg)
    else
      print("|cff00ff88CraftersBoard|r ProfessionLinks module not loaded.")
    end

  else
    print("|cff00ff88CraftersBoard|r commands:")
    print("  /cb toggle                  - show/hide")
    print("  /cb workers | /cb looking | /cb guild")
    print("  /cb search <text>           - filter by text, name, or profession")
    print("  /cb strict on|off           - drop LFG/boost/raid ads unless clearly crafting")
    print("  /cb channels a,b,c          - match trade channels")
    print("  /cb noise list              - view custom noise terms")
    print("  /cb noise add <cat> a,b     - add custom terms (raids|groups|roles|boosts)")
    print("  /cb noise clear <cat>       - clear a category of custom terms")
    print("  /cb gscan                   - scan guild notes now")
    print("  /cb prune <age>             - remove entries older than age (e.g. 30m, 2h, 1d)")
    print("  /cb clear                   - clear stored chat entries")
    print("  /cb mute player <name>      - hide this player in CraftersBoard")
    print("  /cb mute phrase <text>      - hide messages containing text")
    print("  /cb unmute player|phrase …  - remove a mute")
    print("  /cb mmb on|off|angle|reset  - minimap button controls")
    print("  /cb testicons               - test WoW icon markup parsing")
    print("  /cb options                 - open settings")
    print("")
    print("|cff00ff88CraftersBoard|r ProfessionLinks commands:")
    print("  /cb link                    - generate profession link")
    print("  /cb post                    - post profession link to say")
    print("  /cb trade                   - post profession link to trade")
    print("  /cb group                   - post profession link to group chat")
    print("  /cb scan                    - scan current profession")
    print("  /cb test scenario basic     - run profession link tests")
    print("  /cb testdict                - test dictionary compression system")
    print("  /cb professionfilter <name> - test profession filtering (e.g., Alchemy)")
    print("  /cb dictinfo                - show dictionary statistics")
  end
end

-- Register slash commands
SLASH_CraftersBoard1 = "/CraftersBoard"
SLASH_CraftersBoard2 = "/cb"
SlashCmdList["CraftersBoard"] = handleSlashCommand

-- Export function
CB.handleSlashCommand = handleSlashCommand
