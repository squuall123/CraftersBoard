-- CraftersBoard - Profession Links Module
-- Enables custom profession linking for Classic WoW Anniversary

-- Debug print only if enabled
if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
    print("CraftersBoard: ProfessionLinks.lua loading...")
end

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    print("ERROR: CraftersBoard namespace not found! Make sure Init.lua loads first.")
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

-- Debug print only if enabled
if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
    print("CraftersBoard: ProfessionLinks.lua - CB namespace found")
end

-- Create ProfessionLinks namespace
CB.ProfessionLinks = CB.ProfessionLinks or {}
local PL = CB.ProfessionLinks

-- Debug print only if enabled
if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
    print("CraftersBoard: ProfessionLinks.lua - PL namespace created")
end

-- Simple debug function to avoid undefined Debug errors during loading
local function simplePrint(msg)
    if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
        print("|cffffff00CraftersBoard|r |cff00ff00[ProfLinks]|r " .. tostring(msg))
    end
end

-- Forward declaration of functions that might be called during initialization
PL.InitializeCache = PL.InitializeCache or function()
    simplePrint("Warning: InitializeCache called but not yet fully defined")
end

PL.StartAutoSave = PL.StartAutoSave or function()
    simplePrint("Warning: StartAutoSave called but not yet fully defined")
end

-- Add compatibility functions for UI styling (shared with main UI)
if not CB.UI then CB.UI = {} end

-- Classic compatibility functions for backdrop (if not already defined)
if not CB.UI.SetBackdropCompat then
    function CB.UI.SetBackdropCompat(frame, backdrop)
        if frame.SetBackdrop then
            frame:SetBackdrop(backdrop)
        else
            -- Classic fallback: create a manual backdrop texture
            if not frame._backdrop then
                frame._backdrop = frame:CreateTexture(nil, "BACKGROUND")
                frame._backdrop:SetAllPoints()
            end
            if backdrop and backdrop.bgFile then
                frame._backdrop:SetTexture(backdrop.bgFile)
                frame._backdrop:SetTexCoord(0, 1, 0, 1)
            end
        end
    end
end

if not CB.UI.SetBackdropColorCompat then
    function CB.UI.SetBackdropColorCompat(frame, r, g, b, a)
        if frame.SetBackdropColor then
            frame:SetBackdropColor(r, g, b, a)
        elseif frame._backdrop then
            frame._backdrop:SetVertexColor(r, g, b, a or 1)
        end
    end
end

if not CB.UI.SetBackdropBorderColorCompat then
    function CB.UI.SetBackdropBorderColorCompat(frame, r, g, b, a)
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(r, g, b, a)
        end
        -- Note: Border color not easily implemented in manual fallback
    end
end

local ADDON_MESSAGE_PREFIX = "CBPROF"
local PROTOCOL_VERSION = 1
local LINK_FORMAT = "|Hcraftersboard:%s:%d:%d:%d|h[%s's %s (%d)]|h"

local MAX_ADDON_MESSAGE_SIZE = 200
local MAX_CHUNKS_PER_REQUEST = 100
local CHUNK_SEND_DELAY = 0.05
local COMPRESSION_ENABLED = true
local CHUNK_TIMEOUT = 30
local OPTIMIZE_NETWORK_DATA = true
local ENHANCED_PROTOCOL_VERSION = 2

local PROFESSION_IDS = {}
local PROFESSION_NAMES = {}

local function CreateOptimizedProfessionData(professionId, skillLevel, knownRecipes)
    if not OPTIMIZE_NETWORK_DATA or not CraftersBoard.CreateOptimizedRecipeData then
        return {
            professionId = professionId,
            currentSkill = skillLevel,  -- Fixed: was skillLevel, now currentSkill
            knownRecipes = knownRecipes, -- Fixed: was recipes, now knownRecipes
            timestamp = time()
        }
    end
    
    -- Use enhanced database optimization
    return CraftersBoard.CreateOptimizedRecipeData(professionId, skillLevel, knownRecipes)
end

local function ReconstructProfessionDisplay(optimizedData)
    if not OPTIMIZE_NETWORK_DATA or not CraftersBoard.ReconstructRecipeDisplay then
        -- Fallback to original display
        return optimizedData
    end
    
    -- Use enhanced database for reconstruction
    return CraftersBoard.ReconstructRecipeDisplay(optimizedData)
end

local function GetRecipeDisplayName(professionId, spellId)
    if CraftersBoard.GetRecipeData then
        local recipe = CraftersBoard.GetRecipeData(professionId, spellId)
        if recipe and recipe.name then
            return recipe.name
        end
    end
    
    -- Fallback to spell name
    local spellName = GetSpellInfo(spellId)
    return spellName or ("Recipe " .. spellId)
end

local function GetRecipesByCategory(professionId)
    if CraftersBoard.GetCategoriesForProfession then
        local categories = CraftersBoard.GetCategoriesForProfession(professionId)
        local categorizedRecipes = {}
        
        for _, category in ipairs(categories) do
            categorizedRecipes[category] = CraftersBoard.GetRecipesByCategory(professionId, category)
        end
        
        return categorizedRecipes
    end
    
    return {}
end

-- Map recipe names to spell IDs for Classic Era compatibility
local function GetSpellIdFromRecipeName(recipeName)
    if not recipeName then return nil end
    
    -- Use enhanced database to find spell ID by recipe name
    if CraftersBoard.EnhancedRecipeData then
        for professionId, recipes in pairs(CraftersBoard.EnhancedRecipeData) do
            for spellId, recipeData in pairs(recipes) do
                if recipeData.name == recipeName then
                    return spellId
                end
            end
        end
    end
    
    -- Fallback to basic name mapping for critical recipes
    local nameToSpellId = {
        -- Alchemy Examples
        ["Flask of the Titans"] = 17635,
        ["Major Healing Potion"] = 17556,
        ["Transmute: Arcanite"] = 17187,
        
        -- Blacksmithing Examples  
        ["Arcanite Reaper"] = 16994,
        ["Thunderfury Bindings"] = 16969,
        
        -- Engineering Examples
        ["Goblin Sapper Charge"] = 12754,
        ["Gnomish Cloaking Device"] = 12587,
        
        -- More mappings can be added here as needed
    }
    
    return nameToSpellId[recipeName]
end

-- Look up spell ID using Recipe_Master database by matching item names
function PL.GetSpellIdFromRecipeMasterData(recipeName)
    if not recipeName then return nil end
    
    -- Use Recipe_Master database: check all professions and items
    -- Access via global CraftersBoard namespace
    local cbAddon = CraftersBoard
    if cbAddon and cbAddon.VanillaAccurateData then
        for professionId, professionData in pairs(cbAddon.VanillaAccurateData) do
            for keyId, recipe in pairs(professionData) do
                -- Method 1: Check if recipe has spellId and itemId, match by item name
                if recipe.spellId and recipe.itemId then
                    -- Get the actual item name from WoW API
                    local itemName = GetItemInfo(recipe.itemId)
                    if itemName and itemName == recipeName then
                        -- CB.Debug("GetSpellIdFromRecipeMasterData: Found item match - " .. recipeName .. " → spellId " .. recipe.spellId .. " (itemId " .. recipe.itemId .. ")")
                        return recipe.spellId
                    end
                end
                
                -- Method 2: For recipes without itemId (like enchantments), check if spell name matches
                if not recipe.itemId and type(keyId) == "number" then
                    -- The key might be a spell ID, check if spell name matches recipe name
                    local spellName = GetSpellInfo and GetSpellInfo(keyId)
                    if spellName and spellName == recipeName then
                        -- CB.Debug("GetSpellIdFromRecipeMasterData: Found spell match - " .. recipeName .. " → spellId " .. keyId)
                        return keyId
                    end
                end
            end
        end
    end
    
    -- Fallback: Check the legacy compatibility layer
    if CraftersBoard_VanillaData and CraftersBoard_VanillaData.SPELL_TO_RECIPE then
        for spellId, itemName in pairs(CraftersBoard_VanillaData.SPELL_TO_RECIPE) do
            if itemName == recipeName then
                -- CB.Debug("GetSpellIdFromRecipeMasterData: Found in legacy layer - " .. recipeName .. " → spellId " .. spellId)
                return spellId
            end
        end
    end
    
    -- Only print debug for missing recipes if debug is enabled
    -- CB.Debug("GetSpellIdFromRecipeMasterData: No match found for '" .. recipeName .. "'")
    return nil
end

-- Look up spell ID by item ID directly (Recipe_Master preferred method)
function PL.GetSpellIdFromItemId(itemId)
    if not itemId then return nil end
    
    -- Use Recipe_Master database: direct item ID lookup
    local cbAddon = CraftersBoard
    if cbAddon and cbAddon.VanillaAccurateData then
        for professionId, professionData in pairs(cbAddon.VanillaAccurateData) do
            local recipe = professionData[itemId]
            if recipe then
                -- Check if recipe has a spellId field
                if recipe.spellId then
                    -- CB.Debug("GetSpellIdFromItemId: Direct match - itemId " .. itemId .. " → spellId " .. recipe.spellId .. " (profession " .. professionId .. ")")
                    return recipe.spellId
                -- For recipes without spellId (like enchantments), the key might be the spell ID
                elseif not recipe.itemId and type(itemId) == "number" then
                    -- CB.Debug("GetSpellIdFromItemId: Key-as-spellId match - using key " .. itemId .. " as spell ID (profession " .. professionId .. ")")
                    return itemId
                end
            end
        end
    end
    
    -- Only print debug for missing items if debug is enabled
    -- CB.Debug("GetSpellIdFromItemId: No recipe found for itemId " .. itemId)
    return nil
end

-- New function: Look up spell ID by spell ID key (for non-item recipes like enchantments)
function PL.GetSpellIdBySpellKey(spellId)
    if not spellId then return nil end
    
    -- Use Recipe_Master database: check if spell ID exists as a key
    local cbAddon = CraftersBoard
    if cbAddon and cbAddon.VanillaAccurateData then
        for professionId, professionData in pairs(cbAddon.VanillaAccurateData) do
            local recipe = professionData[spellId]
            if recipe then
                -- If this is a non-item recipe (no itemId), the key is likely the spell ID
                if not recipe.itemId then
                    -- CB.Debug("GetSpellIdBySpellKey: Found non-item recipe - spellId " .. spellId .. " (profession " .. professionId .. ")")
                    return spellId
                end
            end
        end
    end
    
    return nil
end

-- Add the function to the PL namespace for use in ScanRecipe
PL.GetSpellIdFromRecipeName = GetSpellIdFromRecipeName

-- Refresh the profession viewer display (called when item names get loaded)
function PL.RefreshProfessionViewer()
    if professionViewerFrame and professionViewerFrame:IsShown() then
        CB.Debug("Refreshing profession viewer display after item names loaded")
        
        -- If we have stored profession data, refresh the display
        if professionViewerFrame.currentProfessionData then
            professionViewerFrame:DisplayProfessionData(professionViewerFrame.currentProfessionData)
        end
    end
end

-- Optimized Data Serialization Functions

-- Serialize optimized profession data (profession ID + skill level + recipe IDs)
function PL.SerializeOptimizedData(optimizedData)
    if not optimizedData then return nil end
    
    -- Create compact format: professionId:skillLevel:spellId1,spellId2,spellId3...
    local parts = {
        tostring(optimizedData.professionId or 0),
        tostring(optimizedData.currentSkill or 0),
        table.concat(optimizedData.knownRecipes or {}, ","),
        tostring(optimizedData.timestamp or time())
    }
    
    return table.concat(parts, ":")
end

-- Deserialize optimized profession data
function PL.DeserializeOptimizedData(serializedData)
    CB.Debug("=== DESERIALIZEOPTIMIZEDDATA DEBUG ===")
    CB.Debug("Input data: " .. tostring(serializedData))
    
    if not serializedData or serializedData == "" then 
        CB.Debug("DeserializeOptimizedData: Empty or nil data")
        return false, nil 
    end
    
    -- Split by ':' but preserve empty parts
    local parts = {}
    local remaining = serializedData
    while true do
        local colonPos = string.find(remaining, ":")
        if colonPos then
            table.insert(parts, string.sub(remaining, 1, colonPos - 1))
            remaining = string.sub(remaining, colonPos + 1)
        else
            table.insert(parts, remaining)
            break
        end
    end
    
    CB.Debug("Found " .. #parts .. " colon-separated parts (preserving empty parts):")
    for i, part in ipairs(parts) do
        CB.Debug("  Part " .. i .. ": '" .. tostring(part) .. "'")
    end
    
    if #parts < 4 then
        CB.Debug("Invalid optimized data format - not enough parts (need 4, got " .. #parts .. ")")
        return false, nil
    end
    
    local professionId = tonumber(parts[1])
    local currentSkill = tonumber(parts[2])
    local recipeIdString = parts[3] or ""
    local timestamp = tonumber(parts[4])
    
    CB.Debug("Parsed values:")
    CB.Debug("  professionId: " .. tostring(professionId))
    CB.Debug("  currentSkill: " .. tostring(currentSkill))
    CB.Debug("  recipeIdString: '" .. tostring(recipeIdString) .. "'")
    CB.Debug("  timestamp: " .. tostring(timestamp))
    
    if not professionId or not currentSkill or not timestamp then
        CB.Debug("Invalid optimized data format - invalid numbers")
        CB.Debug("  professionId valid: " .. tostring(professionId ~= nil))
        CB.Debug("  currentSkill valid: " .. tostring(currentSkill ~= nil))
        CB.Debug("  timestamp valid: " .. tostring(timestamp ~= nil))
        return false, nil
    end
    
    -- Parse recipe IDs
    local knownRecipes = {}
    if recipeIdString ~= "" then
        for recipeId in string.gmatch(recipeIdString, "([^,]+)") do
            local id = tonumber(recipeId)
            if id then
                table.insert(knownRecipes, id)
            end
        end
    end
    
    local optimizedData = {
        professionId = professionId,
        currentSkill = currentSkill,
        knownRecipes = knownRecipes,
        timestamp = timestamp
    }
    
    CB.Debug("Successfully created optimizedData structure:")
    CB.Debug("  professionId: " .. tostring(optimizedData.professionId))
    CB.Debug("  currentSkill: " .. tostring(optimizedData.currentSkill))
    CB.Debug("  knownRecipes count: " .. tostring(#optimizedData.knownRecipes))
    CB.Debug("  timestamp: " .. tostring(optimizedData.timestamp))
    
    -- Debug function may not be available yet during early loading
    CB.Debug("Deserialized optimized data: profession " .. professionId .. ", skill " .. currentSkill .. ", " .. #knownRecipes .. " recipes")
    return true, optimizedData
end

-- Initialize profession mappings safely
local function InitializeProfessionMappings()
    CB.Debug("=== INITIALIZING PROFESSION MAPPINGS ===")
    
    local professionSpells = {
        {spell = 2259, id = 171, name = "Alchemy"},         -- Alchemy (Apprentice Alchemy)
        {spell = 2018, id = 164, name = "Blacksmithing"},   -- Blacksmithing (Apprentice Blacksmithing)
        {spell = 7411, id = 333, name = "Enchanting"},      -- Enchanting (Apprentice Enchanting) 
        {spell = 4036, id = 202, name = "Engineering"},     -- Engineering (Apprentice Engineering)
        {spell = 3273, id = 129, name = "First Aid"},       -- First Aid (Apprentice First Aid - corrected spell)
        {spell = 2550, id = 185, name = "Cooking"},         -- Cooking (Apprentice Cooking)
        {spell = 2575, id = 186, name = "Mining"},          -- Mining (Apprentice Mining - corrected ID)
        {spell = 8613, id = 393, name = "Skinning"},        -- Skinning (Apprentice Skinning - corrected ID)
        {spell = 2108, id = 165, name = "Leatherworking"},  -- Leatherworking (Apprentice Leatherworking - corrected spell)
        {spell = 3908, id = 197, name = "Tailoring"},       -- Tailoring (Apprentice Tailoring - corrected spell)
        {spell = 2366, id = 182, name = "Herbalism"},       -- Herbalism (Apprentice Herbalism - corrected ID)
        {spell = 7620, id = 356, name = "Fishing"},         -- Fishing (Apprentice Fishing)
    }
    
    CB.Debug("Processing " .. #professionSpells .. " profession mappings...")
    
    for _, prof in ipairs(professionSpells) do
        local spellName = GetSpellInfo(prof.spell)
        if spellName then
            -- Use spell name from game
            PROFESSION_IDS[spellName] = prof.id
            PROFESSION_NAMES[prof.id] = spellName
            CB.Debug("  Mapped profession " .. prof.id .. " (" .. prof.name .. ") to spell name: " .. spellName)
        else
            -- Fallback to hardcoded name for missing spells
            PROFESSION_IDS[prof.name] = prof.id
            PROFESSION_NAMES[prof.id] = prof.name
            CB.Debug("  Using fallback name for profession " .. prof.id .. ": " .. prof.name .. " (spell " .. prof.spell .. " not found)")
        end
    end
    
    local count = 0
    for _ in pairs(PROFESSION_NAMES) do count = count + 1 end
    CB.Debug("=== PROFESSION MAPPING COMPLETE: " .. count .. " professions initialized ===")
    
    -- Show all mappings for verification
    CB.Debug("Final PROFESSION_NAMES mappings:")
    for id, name in pairs(PROFESSION_NAMES) do
        CB.Debug("  [" .. id .. "] = " .. name)
    end
end

-- Module state
local isInitialized = false
local cachedProfessions = {} -- Cache for other players' professions
local pendingRequests = {}   -- Track outgoing requests
local pendingViewRequests = {} -- Track requests triggered by clicking profession links
local professionSnapshots = {} -- Our own profession data

-- Network optimization state
local playerCapabilities = {} -- Track which players support optimized protocol
local transferStats = {} -- Monitor transfer performance
local activeTransfers = {} -- Track ongoing optimized transfers

-- Profession scanning state
local scanInProgress = false
local lastScanTime = 0
local SCAN_COOLDOWN = 5 -- Minimum seconds between scans

-- Loading UI state
local loadingSpinners = {} -- Track active loading spinners

-- Recipe data structure
--[[
professionSnapshots[professionName] = {
    name = "Alchemy",
    rank = 300,
    maxRank = 300,
    timestamp = 1724010000,
    recipes = {
        [1] = {
            name = "Minor Healing Potion",
            type = "optimal", -- "trivial", "easy", "medium", "optimal"
            available = 5, -- number available to craft
            reagents = { ... }, -- required materials
            difficulty = { min = 1, max = 25, current = 1 }
        }
    },
    categories = {
        ["Potions"] = { 1, 2, 3 }, -- indices of recipes in this category
        ["Elixirs"] = { 4, 5, 6 }
    }
}
--]]


-- Compatibility function for sending addon messages (Classic Era compatible)
local function SendAddonMessageCompat(prefix, message, distribution, target)
    -- Try modern API first, then fall back to Classic Era API
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(prefix, message, distribution, target)
    elseif SendAddonMessage then
        return SendAddonMessage(prefix, message, distribution, target)
    else
        CB.Debug("No addon message API available")
        return false
    end
end

-- Debug command to test profession mappings
function PL.TestMappings()
    CB.Debug("=== TESTING PROFESSION MAPPINGS ===")
    
    CB.Debug("PROFESSION_NAMES contents:")
    local count = 0
    for id, name in pairs(PROFESSION_NAMES) do
        count = count + 1
        CB.Debug("  [" .. id .. "] = " .. name)
    end
    
    if count == 0 then
        CB.Debug("WARNING: PROFESSION_NAMES is empty!")
        CB.Debug("Calling InitializeProfessionMappings()...")
        InitializeProfessionMappings()
    else
        CB.Debug("Found " .. count .. " profession mappings")
    end
    
    CB.Debug("PROFESSION_IDS contents:")
    local idCount = 0
    for name, id in pairs(PROFESSION_IDS) do
        idCount = idCount + 1
        CB.Debug("  [" .. name .. "] = " .. id)
    end
    CB.Debug("Found " .. idCount .. " profession ID mappings")
end

-- Add debug command to slash commands
SLASH_TESTMAPPINGS1 = "/testmappings"
SlashCmdList.TESTMAPPINGS = function()
    PL.TestMappings()
end

-- Add debug command to test request/response mechanism
SLASH_TESTREQUEST1 = "/testrequest"
SlashCmdList.TESTREQUEST = function()
    local playerName = UnitName("player")
    local reqId = math.random(100000, 999999)
    
    print("|cffffff00CraftersBoard|r Testing request/response mechanism...")
    print("Sending test request with reqId: " .. reqId)
    
    -- Store a test pending request
    pendingRequests[reqId] = {
        target = playerName,
        profId = 186, -- Mining
        timestamp = time(),
        professionName = "Mining"
    }
    
    -- Send a test request to ourselves
    local message = "REQ:186:0:" .. reqId
    local success = SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "WHISPER", playerName)
    
    if success then
        print("✓ Test request sent successfully")
        -- Set up a shorter timeout for testing
        C_Timer.After(5, function()
            if pendingRequests[reqId] then
                print("✗ Test request timed out - no response received")
                pendingRequests[reqId] = nil
            else
                print("✓ Test request completed successfully")
            end
        end)
    else
        print("✗ Failed to send test request")
    end
end

-- Initialize profession mappings now that Debug is available
InitializeProfessionMappings()

-- Utility function to get player identifier
local function GetPlayerIdentifier(playerName)
    local name = playerName or UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Unknown"
    return name .. "-" .. realm
end

-- Utility function to normalize player names for consistent comparison
local function NormalizePlayerName(playerName)
    if not playerName then return nil end
    
    -- If it already contains realm, extract just the character name
    local charName = playerName:match("([^-]+)")
    return charName or playerName
end

-- Utility function to check if two player names refer to the same player
local function IsSamePlayer(playerName1, playerName2)
    local norm1 = NormalizePlayerName(playerName1)
    local norm2 = NormalizePlayerName(playerName2)
    return norm1 and norm2 and norm1 == norm2
end

-- Fallback: Get spell ID from recipe name using static mapping
-- This is a temporary workaround for Classic Era where GetTradeSkillRecipeLink might not work
function PL.GetSpellIdFromRecipeName(recipeName)
    if not recipeName then return nil end
    
    -- We can reverse-lookup from our static database
    if CraftersBoard_VanillaData and CraftersBoard_VanillaData.SPELL_TO_RECIPE then
        for spellId, recipeDbName in pairs(CraftersBoard_VanillaData.SPELL_TO_RECIPE) do
            if recipeDbName == recipeName then
                return spellId
            end
        end
    end
    
    -- CB.Debug("GetSpellIdFromRecipeName: No spell ID found for recipe '" .. recipeName .. "'")
    return nil
end

-- Initialize the module
function PL.Initialize()
    -- Debug print only if enabled
    if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
        print("CraftersBoard: PL.Initialize() called")
    end
    if isInitialized then 
        if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
            print("CraftersBoard: Already initialized, returning")
        end
        return 
    end
    
    -- Debug print only if enabled
    if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
        print("CraftersBoard: Starting PL initialization...")
    end
    CB.Debug("Initializing Profession Links module...")
    
    -- Register addon message prefix (Classic Era compatible)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)
        CB.Debug("Registered addon message prefix: " .. ADDON_MESSAGE_PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)
        CB.Debug("Registered addon message prefix (Classic Era): " .. ADDON_MESSAGE_PREFIX)
    else
        CB.Debug("Warning: Could not register addon message prefix (no API available)")
    end
    
    -- Initialize cache system (if function exists)
    if PL.InitializeCache then
        PL.InitializeCache()
    else
        CB.Debug("Warning: PL.InitializeCache not yet defined")
    end
    
    -- Start auto-save timer (if function exists)
    if PL.StartAutoSave then
        PL.StartAutoSave()
    else
        CB.Debug("Warning: PL.StartAutoSave not yet defined")
    end
    
    -- Hook SetItemRef for custom link handling
    PL.HookLinkHandler()
    
    -- Set up chat message filters
    PL.SetupChatFilters()
    
    -- Register event handlers for automatic profession scanning
    PL.RegisterEvents()
    
    -- Start automatic profession scanning
    PL.StartAutomaticScanning()
    
    -- Announce our capabilities to other players with a delay
    C_Timer.After(2, function()
        -- Delay to ensure other players are loaded
        local capabilities = {
            version = CB.VERSION or "1.0.0",
            supportsSpellIDs = true,
            staticDBVersion = (CB.VanillaData and CB.VanillaData.VERSION) or "1.0.0"
        }
        
        -- Simple JSON-like serialization for capability data
        local serialized = string.format('{"version":"%s","supportsSpellIDs":%s,"staticDBVersion":"%s"}',
            capabilities.version,
            tostring(capabilities.supportsSpellIDs),
            capabilities.staticDBVersion
        )
        local message = string.format("CAPABILITIES:%s", serialized)
        
        -- Announce to all channels
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "GUILD")
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "RAID")
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "PARTY")
        
        CB.Debug("Announced capabilities: optimized protocol supported")
    end)
    
    isInitialized = true
    CB.Debug("Profession Links module initialized successfully")
    
    -- Add a simple test command
    SLASH_CBPTEST1 = "/cbptest"
    SlashCmdList["CBPTEST"] = function(msg)
        if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
            print("CraftersBoard: ProfessionLinks is working! Debug enabled.")
            print("CraftersBoard: isInitialized = " .. tostring(isInitialized))
            print("CraftersBoard: CB.isInitialized = " .. tostring(CB.isInitialized))
            if msg and msg ~= "" then
                print("CraftersBoard: Test message: " .. msg)
            end
        else
            print("CraftersBoard: ProfessionLinks is working! Use '/cb debug on' to enable debug mode.")
        end
        
        -- Test database access
        if CraftersBoard_VanillaData and CraftersBoard_VanillaData.SPELL_TO_RECIPE then
            local count = 0
            local samples = {}
            for spellId, recipeName in pairs(CraftersBoard_VanillaData.SPELL_TO_RECIPE) do
                count = count + 1
                if count <= 5 then
                    table.insert(samples, spellId .. "=" .. recipeName)
                end
            end
            if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                print("Database loaded: " .. count .. " recipes")
                print("Samples: " .. table.concat(samples, ", "))
            end
        else
            if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                print("ERROR: Database not loaded!")
            end
        end
    end
    
    -- Add database inspection command
    SLASH_CBPDB1 = "/cbpdb"
    SlashCmdList["CBPDB"] = function(msg)
        if not msg or msg == "" then
            if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                print("Usage: /cbpdb <spellID> - Look up a specific spell ID")
            end
            return
        end
        
        local spellID = tonumber(msg)
        if not spellID then
            if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                print("Invalid spell ID: " .. msg)
            end
            return
        end
        
        if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
            print("Looking up spell ID: " .. spellID)
        end
        local recipe = PL.ResolveRecipeFromSpellID(spellID)
        if recipe then
            if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                print("Found: " .. recipe.name .. " (source: " .. recipe.source .. ")")
            end
        else
            if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                print("Not found in database")
            end
        end
    end
    
    -- Debug print only if enabled
    if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
        print("CraftersBoard: ProfessionLinks initialization complete, /cbptest command registered")
    end
end

-- Hook the link handler for custom profession links
function PL.HookLinkHandler()
    local oldSetItemRef = SetItemRef
    
    SetItemRef = function(link, text, button, chatFrame)
        if PL.HandleCustomLink(link, text, button, chatFrame) then
            return -- We handled it
        end
        
        -- Pass to original handler
        oldSetItemRef(link, text, button, chatFrame)
    end
    
    -- Also hook tooltip handling to prevent errors with other addons
    local oldSetHyperlink = ItemRefTooltip.SetHyperlink
    ItemRefTooltip.SetHyperlink = function(self, link, ...)
        -- Check if it's our custom link type
        if link and (link:match("^cbprof:") or link:match("^craftersboard:") or link:match("^craftersProfession:")) then
            -- Handle our custom profession link tooltip
            PL.ShowProfessionLinkTooltip(self, link)
            return
        end
        
        -- Pass to original handler
        return oldSetHyperlink(self, link, ...)
    end
    
    CB.Debug("Hooked SetItemRef and tooltip handlers for custom link handling")
end

-- Set up chat message filters to handle profession links in chat
function PL.SetupChatFilters()
    local function ChatMessageFilter(chatFrame, event, msg, ...)
        if not msg then return false end
        
        -- Debug output to see if filter is being called
        if string.find(msg, "%[%[.+%]%]") then
            CB.Debug("ChatFilter found double bracket pattern in: " .. msg)
        end
        
        -- Look for our profession link text pattern and convert to hyperlinks
        local newMsg = msg
        local changed = false
        
        -- Pattern to match: [[PlayerName's ProfessionName]]
        for playerName, professionName in string.gmatch(msg, "%[%[([^']+)'s ([^%]]+)%]%]") do
            CB.Debug("Found profession link pattern: " .. playerName .. "'s " .. professionName)
            
            -- Check if this looks like a profession name
            local profId = PROFESSION_IDS[professionName]
            if profId then
                CB.Debug("Converting to hyperlink: " .. professionName)
                
                -- Convert to hyperlink
                local linkData = string.format("%s:%s", playerName, professionName)
                local linkText = string.format("[%s's %s]", playerName, professionName)
                local hyperlink = string.format("|HcraftersProfession:%s|h%s|h", linkData, linkText)
                
                -- Replace the double-bracket text with the hyperlink
                local escapedPlayerName = playerName:gsub("([%-%.])", "%%%1")
                local escapedProfessionName = professionName:gsub("([%-%.])", "%%%1")
                local pattern = "%[%[" .. escapedPlayerName .. "'s " .. escapedProfessionName .. "%]%]"
                newMsg = newMsg:gsub(pattern, hyperlink)
                changed = true
                
                CB.Debug("New message: " .. newMsg)
            else
                CB.Debug("Not a recognized profession: " .. professionName)
            end
        end
        
        -- If we made changes, return the modified message
        if changed then
            CB.Debug("Returning modified message")
            return false, newMsg, ...
        end
        
        return false -- Don't filter the message
    end
    
    -- Add the filter to all relevant chat message types
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", ChatMessageFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", ChatMessageFilter)
    
    CB.Debug("Set up chat message filters for profession links")
end

-- Handle custom profession links
function PL.HandleCustomLink(link, text, button, chatFrame)
    CB.Debug("HandleCustomLink called with link: " .. tostring(link))
    
    -- Handle new profession link format: |HcraftersProfession:PlayerName:ProfessionName|h
    if link:match("^craftersProfession:") then
        -- Check if shift is held and chat input is active (using WoW's standard modifier check)
        if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
            local chatEditBox = ChatEdit_GetActiveWindow()
            if chatEditBox and chatEditBox:IsVisible() then
                -- Extract player and profession name from the link data
                local playerName, professionName = link:match("^craftersProfession:([^:]+):(.+)")
                if playerName and professionName then
                    -- Use double brackets like Questie to distinguish from regular text
                    local linkText = string.format("[[%s's %s]]", playerName, professionName)
                    ChatEdit_InsertLink(linkText)
                end
                return true
            end
        end
        
        -- Normal click - show profession data
        PL.HandleProfessionLink(link)
        return true
    end
    
    -- Handle legacy format
    local linkType, owner, profId, version, timestamp = link:match("^(%w+):([^:]+):(%d+):(%d+):(%d+)")
    
    -- Handle both old and new link formats
    if not linkType then
        -- Try alternative patterns for longer prefix names
        linkType, owner, profId, version, timestamp = link:match("^([^:]+):([^:]+):(%d+):(%d+):(%d+)")
    end
    
    CB.Debug("HandleCustomLink legacy format:")
    CB.Debug("  linkType: " .. tostring(linkType))
    CB.Debug("  owner: " .. tostring(owner))
    CB.Debug("  profId: " .. tostring(profId))
    CB.Debug("  version: " .. tostring(version))
    CB.Debug("  timestamp: " .. tostring(timestamp))
    
    if linkType == "cbprof" or linkType == "craftersboard" then
        -- Check for shift+click behavior (using WoW's standard modifier check)
        if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
            local chatEditBox = ChatEdit_GetActiveWindow()
            if chatEditBox and chatEditBox:IsVisible() then
                -- For legacy links, use the display text or create a simple format
                local linkText = text or "[Profession Link]"
                ChatEdit_InsertLink(linkText)
                return true
            end
        end
        
        CB.Debug("Handling legacy profession link: " .. link)
        
        -- Extract player and server
        local player, server = owner:match("([^-]+)-(.+)")
        if not player or not server then
            print("|cffffff00CraftersBoard|r Invalid profession link format")
            return true
        end
        
        -- Convert strings to numbers
        profId = tonumber(profId)
        version = tonumber(version)
        timestamp = tonumber(timestamp)
        
        CB.Debug("Converted values:")
        CB.Debug("  profId (number): " .. tostring(profId))
        CB.Debug("  profession name from ID: " .. tostring(PROFESSION_NAMES[profId]))
        CB.Debug("  player: " .. tostring(player))
        CB.Debug("  server: " .. tostring(server))
        
        -- Show profession viewer
        PL.ShowProfessionViewer(player, server, profId, timestamp)
        return true
    end
    
    return false -- Not our link type
end

-- Register event handlers
function PL.RegisterEvents()
    local frame = CreateFrame("Frame")
    
    -- Handle addon messages
    frame:RegisterEvent("CHAT_MSG_ADDON")
    
    -- Handle login and reload events for auto-scanning
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ADDON_LOADED")
    
    -- Handle trade skill window events for scanning
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("TRADE_SKILL_UPDATE")
    frame:RegisterEvent("TRADE_SKILL_CLOSE")
    
    -- Handle crafting window events (Classic Era)
    frame:RegisterEvent("CRAFT_SHOW")
    frame:RegisterEvent("CRAFT_UPDATE")
    frame:RegisterEvent("CRAFT_CLOSE")
    
    -- Handle profession learning/unlearning
    frame:RegisterEvent("SKILL_LINES_CHANGED")
    frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            PL.OnAddonMessage(...)
        elseif event == "PLAYER_ENTERING_WORLD" then
            PL.OnPlayerEnteringWorld()
        elseif event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == "CraftersBoard" then
                PL.OnAddonLoaded()
            end
        elseif event == "TRADE_SKILL_SHOW" then
            PL.OnTradeSkillShow()
        elseif event == "TRADE_SKILL_UPDATE" then
            PL.OnTradeSkillUpdate()
        elseif event == "TRADE_SKILL_CLOSE" then
            PL.OnTradeSkillClose()
        elseif event == "CRAFT_SHOW" then
            PL.OnCraftShow()
        elseif event == "CRAFT_UPDATE" then
            PL.OnCraftUpdate()
        elseif event == "CRAFT_CLOSE" then
            PL.OnCraftClose()
        elseif event == "SKILL_LINES_CHANGED" then
            PL.OnSkillLinesChanged()
        elseif event == "LEARNED_SPELL_IN_TAB" then
            PL.OnLearnedSpell(...)
        end
    end)
    
    CB.Debug("Registered event handlers for auto-scanning")
end

-- Handle incoming addon messages
function PL.OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_MESSAGE_PREFIX then return end
    
    -- Ignore messages from ourselves unless we're in debug network mode
    if sender == UnitName("player") then
        -- Check if this is a debug network mode test (look for debug network mode flag)
        -- For now, we'll allow self-messages for testing purposes
        CB.Debug("Received self-message - processing for debug/testing purposes")
    end
    
    CB.Debug("Received addon message from " .. sender .. ": " .. string.sub(message, 1, 50) .. (string.len(message) > 50 and "..." or ""))
    
    local msgType, data = message:match("^([^:]+):(.+)")
    
    if not msgType or not data then
        CB.Debug("Invalid message format: " .. tostring(message))
        return
    end
    
    CB.Debug("Message type: " .. msgType .. ", data length: " .. string.len(data))
    
    if msgType == "REQ" then
        PL.HandleProfessionRequest(data, sender)
    elseif msgType == "OPTIMIZED_REQUEST" then
        PL.HandleOptimizedRequest(data, sender)
    elseif msgType == "DATA" then
        PL.HandleProfessionData(data, sender)
    elseif msgType == "OPTIMIZED_DATA" then
        PL.HandleOptimizedData(data, sender)
    elseif msgType == "CAPABILITIES" then
        PL.HandleCapabilities(data, sender)
    else
        CB.Debug("Unknown message type: " .. tostring(msgType))
    end
end

-- Handle profession data requests
function PL.HandleProfessionRequest(data, sender)
    CB.Debug("===== HANDLING PROFESSION REQUEST =====")
    CB.Debug("Handling profession request from " .. sender)
    CB.Debug("Request data: " .. tostring(data))
    
    local profId, sinceTs, reqId = data:match("^(%d+):(%d+):(%w+)")
    if not profId or not reqId then
        CB.Debug("Invalid request format - profId: " .. tostring(profId) .. ", reqId: " .. tostring(reqId))
        return
    end
    
    profId = tonumber(profId)
    sinceTs = tonumber(sinceTs)
    
    CB.Debug("Parsed request - profId: " .. profId .. ", sinceTs: " .. sinceTs .. ", reqId: " .. reqId)
    
    -- Find the requested profession
    local professionName = PROFESSION_NAMES[profId]
    if not professionName then
        CB.Debug("Unknown profession ID: " .. profId)
        CB.Debug("Available profession IDs:")
        for id, name in pairs(PROFESSION_NAMES) do
            CB.Debug("  [" .. id .. "] = " .. name)
        end
        local response = string.format("DATA:%s:1/1:ERROR_UNKNOWN_PROFESSION", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    CB.Debug("Requested profession: " .. professionName)
    
    -- Get profession snapshot
    local snapshot = professionSnapshots[professionName]
    if not snapshot then
        CB.Debug("No snapshot available for " .. professionName)
        CB.Debug("Available snapshots:")
        for name, snap in pairs(professionSnapshots) do
            CB.Debug("  " .. name .. " (" .. #(snap.recipes or {}) .. " recipes)")
        end
        local response = string.format("DATA:%s:1/1:ERROR_NO_DATA", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    CB.Debug("Found snapshot with " .. #(snapshot.recipes or {}) .. " recipes")
    
    -- Check if data is fresh enough
    if sinceTs > 0 and snapshot.timestamp <= sinceTs then
        CB.Debug("Data not newer than requested timestamp")
        local response = string.format("DATA:%s:1/1:ERROR_NOT_NEWER", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    -- Try optimized protocol first if enhanced database is available
    if OPTIMIZE_NETWORK_DATA and snapshot.optimizedData and snapshot.professionId then
        CB.Debug("Using optimized protocol with enhanced database")
        
        -- Debug: Check structure of snapshot.optimizedData
        CB.Debug("=== SNAPSHOT.OPTIMIZEDDATA STRUCTURE ===")
        for key, value in pairs(snapshot.optimizedData) do
            CB.Debug("  " .. key .. ": " .. tostring(value))
        end
        CB.Debug("=== END STRUCTURE ===")
        
        local optimizedPayload = PL.SerializeOptimizedData(snapshot.optimizedData)
        if optimizedPayload then
            local compressedData = PL.SimpleCompress(optimizedPayload)
            if compressedData and #compressedData < (MAX_ADDON_MESSAGE_SIZE * 3) then -- Allow up to 3 chunks for optimized data
                CB.Debug("Sending optimized data (" .. #compressedData .. " bytes compressed)")
                local response = string.format("OPTIMIZED_DATA:%s:%s", reqId, compressedData)
                SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
                return
            else
                CB.Debug("Optimized data still too large, falling back to legacy protocol")
            end
        else
            CB.Debug("Failed to serialize optimized data, falling back to legacy protocol")
        end
    end
    
    -- Legacy protocol: serialize and compress the full data
    CB.Debug("===== USING LEGACY PROTOCOL =====")
    CB.Debug("Using legacy protocol for request from " .. sender)
    
    local serializedData = PL.SerializeProfessionData(snapshot)
    if not serializedData then
        CB.Debug("CRITICAL ERROR: Failed to serialize profession data for " .. professionName)
        local response = string.format("DATA:%s:1/1:ERROR_SERIALIZATION", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    CB.Debug("Serialized data size: " .. #serializedData .. " bytes")
    
    -- Check data size and create fallback if needed
    local chunks = PL.CreateChunks(serializedData, MAX_ADDON_MESSAGE_SIZE - 50)
    if #chunks > MAX_CHUNKS_PER_REQUEST then
        CB.Debug("Data too large (" .. #chunks .. " chunks), creating fallback with basic info")
        
        -- Create minimal snapshot with just profession info
        local minimalSnapshot = {
            name = snapshot.name,
            rank = snapshot.rank,
            maxRank = snapshot.maxRank,
            timestamp = snapshot.timestamp,
            recipes = {}
        }
        
        -- Include only recipe names (no reagents)
        for i, recipe in ipairs(snapshot.recipes) do
            table.insert(minimalSnapshot.recipes, {
                name = recipe.name,
                type = recipe.type,
                category = recipe.category or "Other",
                reagents = {} -- No reagent details to save space
            })
        end
        
        -- Try to serialize the minimal version
        serializedData = PL.SerializeProfessionData(minimalSnapshot)
        if not serializedData then
            CB.Debug("Failed to serialize even minimal data")
            local response = string.format("DATA:%s:1/1:ERROR_SERIALIZATION", reqId)
            SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
            return
        end
        
        -- Check if minimal version is still too large
        chunks = PL.CreateChunks(serializedData, MAX_ADDON_MESSAGE_SIZE - 50)
        if #chunks > MAX_CHUNKS_PER_REQUEST then
            CB.Debug("Even minimal data is too large")
            local response = string.format("DATA:%s:1/1:ERROR_DATA_TOO_LARGE", reqId)
            SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
            return
        end
        
        CB.Debug("Using minimal data fallback (" .. #chunks .. " chunks)")
    end
    
    -- Send chunked data
    CB.Debug("Sending profession data for " .. professionName .. " to " .. sender)
    if not PL.SendChunkedData(sender, reqId, serializedData) then
        CB.Debug("Failed to send chunked data")
        local response = string.format("DATA:%s:1/1:ERROR_SEND_FAILED", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
    end
end

-- Handle optimized profession data requests (spell ID protocol)
function PL.HandleOptimizedRequest(data, sender)
    CB.Debug("Handling optimized profession request from " .. sender)
    
    local reqId, profId, showInViewer = data:match("^(%w+):(%d+):(%d+)")
    if not reqId or not profId then
        CB.Debug("Invalid optimized request format")
        return
    end
    
    profId = tonumber(profId)
    showInViewer = (showInViewer == "1")
    
    local professionName = PROFESSION_NAMES[profId]
    if not professionName then
        CB.Debug("Unknown profession ID: " .. tostring(profId))
        local response = string.format("OPTIMIZED_DATA:%s:ERROR_UNKNOWN_PROFESSION", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    -- Get profession data
    local professionData = PL.GetProfessionSnapshot(professionName)
    if not professionData or not professionData.recipes or #professionData.recipes == 0 then
        CB.Debug("No profession data available for " .. professionName)
        CB.Debug("Available snapshots: " .. table.concat(PL.GetSnapshotNames(), ", "))
        local response = string.format("OPTIMIZED_DATA:%s:ERROR_NO_DATA", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    -- Send optimized data using the local function
    PL.SendOptimizedRecipeData(sender, reqId, professionData)
end

-- Handle profession data responses
function PL.HandleProfessionData(data, sender)
    CB.Debug("===== HANDLING PROFESSION DATA =====")
    CB.Debug("Handling profession data from " .. sender)
    CB.Debug("Data received: " .. string.sub(data, 1, 100) .. (#data > 100 and "..." or ""))
    
    local reqId, chunk, encodedData = data:match("^(%w+):([^:]+):(.+)")
    if not reqId then
        CB.Debug("CRITICAL ERROR: Invalid data format - could not parse reqId:chunk:data")
        CB.Debug("Full data: " .. tostring(data))
        return
    end
    
    CB.Debug("Parsed data - reqId: " .. reqId .. ", chunk: " .. chunk .. ", encodedData length: " .. #encodedData)
    
    -- Check for error responses
    if encodedData:match("^ERROR_") then
        local errorType = encodedData:match("^ERROR_(.+)")
        local errorMessage
        
        if errorType == "UNKNOWN_PROFESSION" then
            errorMessage = "Unknown profession requested"
        elseif errorType == "NO_DATA" then
            errorMessage = "No profession data available"
        elseif errorType == "NOT_NEWER" then
            errorMessage = "No newer data available"
        elseif errorType == "SERIALIZATION" then
            errorMessage = "Failed to prepare profession data"
        elseif errorType == "SEND_FAILED" then
            errorMessage = "Failed to send profession data"
        elseif errorType == "DATA_TOO_LARGE" then
            errorMessage = "Profession data too large to transmit"
        else
            errorMessage = "Unknown error: " .. errorType
        end
        
        -- Show error in viewer if request is pending
        local pendingRequest = pendingRequests[reqId]
        if pendingRequest then
            local professionName = PROFESSION_NAMES[pendingRequest.profId] or "Unknown"
            
            -- Check if this was a view request (from clicking a profession link)
            local viewRequest = pendingViewRequests[reqId]
            if viewRequest then
                print("|cffffff00CraftersBoard|r Could not get " .. viewRequest.playerName .. "'s " .. viewRequest.professionName .. " data: " .. errorMessage)
                pendingViewRequests[reqId] = nil
            else
                PL.ShowViewerError(sender, professionName, errorMessage)
            end
        end
        
        print("|cffffff00CraftersBoard|r " .. sender .. ": " .. errorMessage)
        
        -- Clean up pending request
        pendingRequests[reqId] = nil
        return
    end
    
    -- Handle chunked data
    PL.ReceiveChunk(sender, reqId, chunk, encodedData)
end

-- Handle optimized profession data (spell IDs)
function PL.HandleOptimizedData(data, sender)
    CB.Debug("Handling optimized data from " .. sender)
    CB.Debug("Raw data: " .. tostring(data))
    
    -- Parse reqId:compressedData format
    local reqId, compressedData = data:match("^([^:]+):(.+)")
    if not reqId or not compressedData then
        CB.Debug("Invalid optimized data format - expected reqId:compressedData")
        return
    end
    
    CB.Debug("Extracted reqId: " .. reqId)
    CB.Debug("Compressed data length: " .. #compressedData)
    
    local decompressed = PL.SimpleDecompress(compressedData)
    if not decompressed then
        CB.Debug("Failed to decompress optimized data")
        print("|cffffff00CraftersBoard|r |cffff0000ERROR:|r Failed to decompress data from " .. sender)
        return
    end
    
    CB.Debug("Decompressed data length: " .. #decompressed)
    CB.Debug("Decompressed data preview: " .. string.sub(decompressed, 1, 100) .. "...")
    CB.Debug("Full decompressed data: " .. tostring(decompressed))
    
    -- Check what format the data is in
    if string.find(decompressed, "|") then
        CB.Debug("Data contains '|' - appears to be request format")
    elseif string.find(decompressed, ":") then
        CB.Debug("Data contains ':' - appears to be optimized format")
    else
        CB.Debug("Data format unclear - no ':' or '|' separators found")
    end
    
    -- Count parts for debugging
    local colonParts = {}
    for part in string.gmatch(decompressed, "([^:]+)") do
        table.insert(colonParts, part)
    end
    CB.Debug("Decompressed data has " .. #colonParts .. " colon-separated parts:")
    for i, part in ipairs(colonParts) do
        CB.Debug("  Part " .. i .. ": " .. tostring(part))
    end
    
    -- Simple JSON-like deserialization for optimized data
    local success, optimizedData = PL.DeserializeOptimizedData(decompressed)
    if not success or not optimizedData then
        CB.Debug("Failed to deserialize optimized data")
        print("|cffffff00CraftersBoard|r |cffff0000ERROR:|r Failed to deserialize data from " .. sender)
        return
    end
    
    CB.Debug("Deserialized data contains " .. (#(optimizedData.knownRecipes or {})) .. " recipe IDs")
    CB.Debug("Profession ID: " .. tostring(optimizedData.professionId or "nil"))
    CB.Debug("Current Skill: " .. tostring(optimizedData.currentSkill or "nil"))
    
    -- Get profession name from ID
    local professionName = PROFESSION_NAMES[optimizedData.professionId] or "Unknown"
    CB.Debug("Profession Name: " .. professionName)
    
    -- Convert to profession snapshot using the local function
    local resolvedRecipes = {}
    local missingSpells = {}
    
    -- Check if static database is available
    if not CraftersBoard_VanillaData then
        CB.Debug("WARNING: CraftersBoard_VanillaData not loaded!")
        print("|cffffff00CraftersBoard|r |cffff0000ERROR:|r Recipe database not loaded")
    else
        CB.Debug("Recipe database loaded with " .. (CraftersBoard_VanillaData.SPELL_TO_RECIPE and 
              table.getn(CraftersBoard_VanillaData.SPELL_TO_RECIPE) or 0) .. " recipes")
    end
    
    -- Resolve recipe IDs to recipe names (knownRecipes contains recipe IDs, not spell IDs)
    for i, recipeID in pairs(optimizedData.knownRecipes or {}) do
        CB.Debug("Processing recipe ID: " .. tostring(recipeID))
        -- Note: knownRecipes should contain recipe spell IDs for lookup
        local recipe = PL.ResolveRecipeFromSpellID(recipeID)
        if recipe and recipe.name then
            CB.Debug("✓ Resolved: " .. recipe.name .. " (source: " .. recipe.source .. ")")
            -- Create a recipe structure compatible with existing display code
            table.insert(resolvedRecipes, {
                name = recipe.name,
                spellID = recipe.spellID,
                type = "unknown", -- We don't have difficulty info from spell IDs
                available = 0,
                reagents = {},
                difficulty = { min = 1, max = 1, current = 1 },
                source = recipe.source
            })
        else
            CB.Debug("✗ Failed to resolve spell ID: " .. tostring(spellID) .. " (recipe=" .. tostring(recipe) .. ")")
            table.insert(missingSpells, spellID)
        end
    end
    
    -- Debug summary
    CB.Debug("Resolution summary:")
    CB.Debug("  Total recipe IDs: " .. #(optimizedData.knownRecipes or {}))
    CB.Debug("  Successfully resolved: " .. #resolvedRecipes)
    CB.Debug("  Failed to resolve: " .. #missingSpells)
    
    -- Show first few resolved recipes for verification
    for i = 1, math.min(3, #resolvedRecipes) do
        local r = resolvedRecipes[i]
        -- CB.Debug("  Recipe " .. i .. ": " .. (r.name or "nil") .. " (ID: " .. tostring(r.spellID) .. ")")
    end
    
    -- Show first few missing spell IDs
    for i = 1, math.min(3, #missingSpells) do
        -- CB.Debug("  Missing: " .. tostring(missingSpells[i]))
    end
    
    -- Use profession name from ID lookup
    if not professionName or professionName == "" then
        CB.Debug("ERROR: Could not resolve profession name from ID: " .. tostring(optimizedData.professionId))
        professionName = "Unknown"
    end
    
    CB.Debug("Creating snapshot with profession name: " .. professionName)
    
    -- Create profession snapshot with resolved recipes
    local snapshot = {
        name = professionName,
        rank = optimizedData.currentSkill or 0,  -- Fixed: was optimizedData.rank
        maxRank = 300, -- Default max skill for Classic professions
        timestamp = optimizedData.timestamp or time(),
        recipes = resolvedRecipes,
        categories = {}, -- Not available in optimized format
        optimized = true,
        missingSpells = missingSpells
    }
    
    CB.Debug("Created snapshot - name: " .. tostring(snapshot.name) .. ", rank: " .. tostring(snapshot.rank) .. ", recipes: " .. #(snapshot.recipes or {}))
    
    -- Log transfer stats
    table.insert(transferStats, {
        type = "optimized_receive",
        resolvedCount = #resolvedRecipes,
        missingCount = #missingSpells,
        totalSpells = #(optimizedData.knownRecipes or {}),  -- Fixed: was optimizedData.spellIds
        timestamp = time(),
        sender = sender
    })
    
    CB.Debug(string.format("Optimized data received: %d/%d recipes resolved (%d missing)", 
          #resolvedRecipes, #(optimizedData.knownRecipes or {}), #missingSpells))  -- Fixed: was optimizedData.spellIds
    
    if not snapshot then
        CB.Debug("Failed to process optimized recipe data")
        return
    end
    
    -- CRITICAL FIX: Cache the received optimized data just like regular data
    local normalizedSender = NormalizePlayerName(sender)
    PL.CacheProfessionData(normalizedSender, snapshot.name, snapshot)
    CB.Debug("Cached optimized profession data for normalized name: " .. normalizedSender)
    
    -- Check if this was a request triggered by clicking a profession link
    local reqId = optimizedData.reqId
    local viewRequest = reqId and pendingViewRequests[reqId] or nil
    if viewRequest then
        -- Remove loading spinner and show the viewer
        if professionViewerFrame then
            PL.HideLoadingSpinner(professionViewerFrame)
        end
        
        CB.Debug("Opening profession viewer for " .. viewRequest.playerName .. "'s " .. viewRequest.professionName .. " (optimized)")
        PL.ShowProfessionData(normalizedSender, snapshot.name, snapshot)
        
        -- Clean up the view request
        if reqId then
            pendingViewRequests[reqId] = nil
        end
    else
        -- Regular request - show in profession viewer
        if professionViewerFrame then
            PL.HideLoadingSpinner(professionViewerFrame)
        end
        PL.ShowProfessionData(normalizedSender, snapshot.name, snapshot)
    end
    
    -- Clean up pending request (only if reqId is not nil)
    if reqId then
        pendingRequests[reqId] = nil
    end
    
    CB.Debug("Successfully processed optimized " .. snapshot.name .. " data from " .. sender)
end

-- Handle capability announcements
function PL.HandleCapabilities(data, sender)
    CB.Debug("Handling capabilities from " .. sender)
    
    -- Simple JSON-like deserialization for capability data
    local capabilities = PL.DeserializeCapabilities(data)
    if not capabilities then
        CB.Debug("Failed to deserialize capabilities")
        return
    end
    
    -- Call the local function for handling capabilities
    playerCapabilities[sender] = {
        version = capabilities.version or "unknown",
        supportsSpellIDs = capabilities.supportsSpellIDs == true,
        staticDBVersion = capabilities.staticDBVersion or "unknown",
        lastSeen = time()
    }
    
    CB.Debug(string.format("Player %s capabilities: optimized=%s, version=%s", 
          sender, tostring(capabilities.supportsSpellIDs), capabilities.version or "unknown"))
end

-- Generate a profession link for the current player
-- Modern profession link generation without deprecated APIs
function PL.GenerateModernProfessionLink(targetProfession)
    local professionName = targetProfession
    
    -- If no profession specified, try to find one from cached snapshots
    if not professionName then
        -- Look for any cached profession data
        for profession, snapshot in pairs(professionSnapshots) do
            if snapshot and snapshot.recipes and #snapshot.recipes > 0 then
                professionName = profession
                CB.Debug("Auto-detected profession: " .. profession)
                break
            end
        end
    end
    
    if not professionName or professionName == "" then
        print("|cffffff00CraftersBoard|r No profession specified and no cached profession data found.")
        print("|cffffff00CraftersBoard|r Usage: /cb link <profession name> (e.g., /cb link Alchemy)")
        print("|cffffff00CraftersBoard|r Available professions: " .. table.concat(PL.GetAvailableProfessions(), ", "))
        return nil
    end
    
    -- Validate profession name
    local profId = PROFESSION_IDS[professionName]
    if not profId then
        print("|cffffff00CraftersBoard|r Unknown profession: " .. professionName)
        print("|cffffff00CraftersBoard|r Available professions: " .. table.concat(PL.GetAvailableProfessions(), ", "))
        return nil
    end
    
    CB.Debug("Profession validation in GenerateModernProfessionLink:")
    CB.Debug("  professionName: " .. tostring(professionName))
    CB.Debug("  profId: " .. tostring(profId))
    CB.Debug("  PROFESSION_NAMES[profId]: " .. tostring(PROFESSION_NAMES[profId]))
    
    -- Debug: Show current PROFESSION_IDS and PROFESSION_NAMES mappings
    CB.Debug("Current PROFESSION_IDS mappings:")
    for name, id in pairs(PROFESSION_IDS) do
        CB.Debug("  [" .. tostring(name) .. "] = " .. tostring(id))
    end
    CB.Debug("Current PROFESSION_NAMES mappings:")
    for id, name in pairs(PROFESSION_NAMES) do
        CB.Debug("  [" .. tostring(id) .. "] = " .. tostring(name))
    end
    
    -- Check if we have data for this profession
    local snapshot = professionSnapshots[professionName]
    if not snapshot then
        print("|cffffff00CraftersBoard|r No data available for " .. professionName)
        print("|cffffff00CraftersBoard|r Try opening the " .. professionName .. " window and run '/cb scan' first")
        return nil
    end
    
    local timestamp = time()
    local owner = GetPlayerIdentifier()
    local playerName = UnitName("player") or "Unknown"
    
    CB.Debug("Modern link generation parameters:")
    CB.Debug("  owner: " .. tostring(owner))
    CB.Debug("  profId: " .. tostring(profId))
    CB.Debug("  timestamp: " .. tostring(timestamp))
    CB.Debug("  playerName: " .. tostring(playerName))
    CB.Debug("  professionName: " .. tostring(professionName))
    CB.Debug("  rank: " .. tostring(snapshot.rank or 0))
    
    local link = string.format(LINK_FORMAT, owner, profId, PROTOCOL_VERSION, timestamp, 
                              playerName, professionName, snapshot.rank or 0)
    
    CB.Debug("Generated modern profession link: " .. link)
    return link
end

-- Get list of available professions (those with cached data)
function PL.GetAvailableProfessions()
    local available = {}
    for profession, snapshot in pairs(professionSnapshots) do
        if snapshot and snapshot.recipes and #snapshot.recipes > 0 then
            table.insert(available, profession)
        end
    end
    
    -- If no cached data, return all known profession names
    if #available == 0 then
        for profession, _ in pairs(PROFESSION_IDS) do
            table.insert(available, profession)
        end
    end
    
    table.sort(available)
    return available
end

function PL.GenerateProfessionLink(professionName)
    if not professionName then
        -- Try to get current profession from trade skill window (Classic Era compatibility)
        if GetTradeSkillLine then
            professionName = GetTradeSkillLine()
        end
    end
    
    if not professionName or professionName == "" then
        print("|cffffff00CraftersBoard|r No profession window open. Please open a profession first.")
        return nil
    end
    
    local profId = PROFESSION_IDS[professionName]
    if not profId then
        print("|cffffff00CraftersBoard|r Unknown profession: " .. professionName)
        return nil
    end
    
    -- Try to get data from snapshot first
    local snapshot = professionSnapshots[professionName]
    local rank, maxRank
    
    if snapshot then
        rank = snapshot.rank
        maxRank = snapshot.maxRank
        CB.Debug("Using cached profession data for " .. professionName)
    else
        -- Fall back to current trade skill window - Classic Era API compatibility
        if GetTradeSkillLine then
            local skillName
            skillName, rank, maxRank = GetTradeSkillLine()
        else
            rank = 0
            maxRank = 300
        end
        CB.Debug("Using live profession data for " .. professionName)
        
        -- Trigger a scan if window is open
        if GetTradeSkillLine and GetTradeSkillLine() == professionName then
            PL.ScanCurrentProfession()
        end
    end
    
    local timestamp = time()
    local owner = GetPlayerIdentifier()
    local playerName = UnitName("player") or "Unknown"
    
    CB.Debug("Link generation parameters:")
    CB.Debug("  owner: " .. tostring(owner))
    CB.Debug("  profId: " .. tostring(profId))
    CB.Debug("  timestamp: " .. tostring(timestamp))
    CB.Debug("  playerName: " .. tostring(playerName))
    CB.Debug("  professionName: " .. tostring(professionName))
    CB.Debug("  rank: " .. tostring(rank or 0))
    
    local link = string.format(LINK_FORMAT, owner, profId, PROTOCOL_VERSION, timestamp, 
                              playerName, professionName, rank or 0)
    
    CB.Debug("Generated profession link: " .. link)
    CB.Debug("Link format validation:")
    CB.Debug("  Contains |H: " .. tostring(string.find(link, "|H") ~= nil))
    CB.Debug("  Contains |h: " .. tostring(string.find(link, "|h") ~= nil))
    CB.Debug("  Link length: " .. string.len(link))
    
    return link
end

-- Show profession viewer window
function PL.ShowProfessionViewer(player, server, profId, timestamp)
    local professionName = PROFESSION_NAMES[profId] or "Unknown"
    
    CB.Debug("ShowProfessionViewer called with:")
    CB.Debug("  player: " .. tostring(player))
    CB.Debug("  server: " .. tostring(server))
    CB.Debug("  profId: " .. tostring(profId))
    CB.Debug("  timestamp: " .. tostring(timestamp))
    CB.Debug("  resolved professionName: " .. tostring(professionName))
    
    -- Debug: Check if PROFESSION_NAMES is properly populated
    local nameCount = 0
    for id, name in pairs(PROFESSION_NAMES) do
        nameCount = nameCount + 1
        CB.Debug("  PROFESSION_NAMES[" .. id .. "] = " .. name)
    end
    CB.Debug("  Total profession names loaded: " .. nameCount)
    
    CB.Debug("Opening profession viewer for " .. player .. "'s " .. professionName)
    
    -- Create/show the profession viewer first
    local frame = PL.CreateProfessionViewer()
    frame:Show()
    
    -- Check if we have cached data first
    local cachedData = PL.GetCachedProfessionData(player, professionName)
    if cachedData then
        CB.Debug("Found cached data for " .. player .. "'s " .. professionName)
        CB.Debug("  Cached data type: " .. type(cachedData))
        CB.Debug("  Cached recipes: " .. (cachedData.recipes and #cachedData.recipes or "nil"))
        CB.Debug("  Cached name: " .. tostring(cachedData.name))
        
        -- Validate that cached data is actually useful
        if cachedData.recipes and #cachedData.recipes > 0 and cachedData.name then
            CB.Debug("Using valid cached data for " .. player .. "'s " .. professionName)
            PL.ShowProfessionData(player, professionName, cachedData)
            return
        else
            CB.Debug("Cached data is invalid/empty, requesting fresh data")
            -- Don't return here - fall through to request new data
        end
    else
        CB.Debug("No cached data found for " .. player .. "'s " .. professionName)
    end
    
    -- Show loading state with spinner
    PL.ShowViewerLoading(player, professionName)
    
    -- Request the data with loading spinner enabled
    PL.RequestProfessionData(player, profId, true)
end

-- Request profession data from another player
function PL.RequestProfessionData(targetPlayer, profId, showInViewer)
    if not targetPlayer or targetPlayer == "" then
        CB.Debug("RequestProfessionData: Invalid target player")
        return nil
    end
    
    if not profId then
        CB.Debug("RequestProfessionData: Invalid profession ID")
        return nil
    end
    
    local reqId = tostring(math.random(100000, 999999))
    
    -- Choose protocol based on target player capabilities
    local supportsOptimized = PL.SupportsOptimizedProtocol(targetPlayer)
    CB.Debug("Capability check for " .. targetPlayer .. ": " .. tostring(supportsOptimized))
    
    -- Enhanced debugging for capability detection
    if not playerCapabilities[targetPlayer] then
        CB.Debug("No capabilities found for " .. targetPlayer .. " - they may not have CraftersBoard or haven't announced capabilities")
        CB.Debug("Will use legacy protocol as fallback")
    else
        CB.Debug("Found capabilities for " .. targetPlayer .. ":")
        CB.Debug("  version: " .. tostring(playerCapabilities[targetPlayer].version))
        CB.Debug("  supportsSpellIDs: " .. tostring(playerCapabilities[targetPlayer].supportsSpellIDs))
        CB.Debug("  lastSeen: " .. tostring(playerCapabilities[targetPlayer].lastSeen))
    end
    
    local message
    if supportsOptimized then
        message = string.format("OPTIMIZED_REQUEST:%s:%d:%s", reqId, profId, showInViewer and "1" or "0")
        CB.Debug("Using optimized protocol for " .. targetPlayer)
        CB.Debug("Message: " .. message)
    else
        message = string.format("REQ:%d:0:%s", profId, reqId)
        CB.Debug("Using legacy protocol for " .. targetPlayer)
        CB.Debug("Message: " .. message)
    end
    
    CB.Debug("RequestProfessionData: Requesting " .. tostring(PROFESSION_NAMES[profId] or "Unknown") .. " from " .. targetPlayer)
    
    -- ENHANCED DEBUGGING: Check all values being used
    CB.Debug("=== DETAILED REQUEST PARAMETERS ===")
    CB.Debug("  targetPlayer: " .. tostring(targetPlayer))
    CB.Debug("  profId: " .. tostring(profId))
    CB.Debug("  showInViewer: " .. tostring(showInViewer))
    CB.Debug("  reqId: " .. tostring(reqId))
    CB.Debug("  PROFESSION_NAMES[profId]: " .. tostring(PROFESSION_NAMES[profId] or "NIL"))
    CB.Debug("  Message to send: " .. tostring(message))
    
    -- Debug profession mappings
    CB.Debug("=== CURRENT PROFESSION MAPPINGS ===")
    local profCount = 0
    for id, name in pairs(PROFESSION_NAMES) do
        profCount = profCount + 1
        CB.Debug("  ID[" .. tostring(id) .. "] -> " .. tostring(name))
    end
    CB.Debug("  Total profession mappings: " .. profCount)
    
    if profCount == 0 then
        CB.Debug("CRITICAL ERROR: No profession mappings found! PROFESSION_NAMES is empty!")
    end
    
    -- Store pending request
    pendingRequests[reqId] = {
        target = targetPlayer,
        profId = profId,
        timestamp = time(),
        professionName = PROFESSION_NAMES[profId]
    }
    
    -- Show loading spinner if viewer should be opened
    if showInViewer and professionViewerFrame then
        local professionName = PROFESSION_NAMES[profId] or "Unknown"
        PL.ShowLoadingSpinner(professionViewerFrame, "Loading " .. professionName .. " data from " .. targetPlayer .. "...")
    end
    
    local success = SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "WHISPER", targetPlayer)
    if success then
        CB.Debug("✓ Successfully sent profession request to " .. targetPlayer .. " (reqId: " .. reqId .. ")")
        CB.Debug("  Message: " .. tostring(message))
        CB.Debug("  Channel: WHISPER")
        CB.Debug("  Target: " .. targetPlayer)
        
        local professionName = PROFESSION_NAMES[profId] or "profession"
        if PL.SupportsOptimizedProtocol(targetPlayer) then
            CB.Debug("Requesting " .. professionName .. " data from " .. targetPlayer .. "... (optimized)")
        else
            CB.Debug("Requesting " .. professionName .. " data from " .. targetPlayer .. "...")
        end
        
        -- Set up timeout for the request
        C_Timer.After(30, function()
            if pendingRequests[reqId] then
                CB.Debug("Request " .. reqId .. " timed out")
                CB.Debug("Request for " .. (PROFESSION_NAMES[profId] or "profession") .. " data from " .. targetPlayer .. " timed out")
                
                -- Enhanced timeout message with troubleshooting info
                local timeoutMessage = "Request timed out - no response from player"
                if not playerCapabilities[targetPlayer] then
                    timeoutMessage = "No response - player may not have CraftersBoard addon or is offline"
                else
                    timeoutMessage = "Request timed out - player's addon may be unresponsive"
                end
                
                -- Show error in viewer if this was a view request
                if pendingViewRequests[reqId] then
                    local professionName = PROFESSION_NAMES[profId] or "Unknown"
                    PL.ShowViewerError(targetPlayer, professionName, timeoutMessage)
                    pendingViewRequests[reqId] = nil
                end
                
                pendingRequests[reqId] = nil
                print("|cffffff00CraftersBoard|r " .. timeoutMessage .. ": " .. targetPlayer)
                
                -- Suggest troubleshooting steps
                if not playerCapabilities[targetPlayer] then
                    print("|cffffff00CraftersBoard|r Make sure " .. targetPlayer .. " has CraftersBoard addon installed and is online")
                end
            end
        end)
        
        return reqId
    else
        CB.Debug("Failed to send profession request to " .. targetPlayer)
        print("|cffffff00CraftersBoard|r Failed to send request to " .. targetPlayer)
        
        -- Clean up pending request
        pendingRequests[reqId] = nil
        
        -- Show error immediately if request failed to send
        if showInViewer then
            local professionName = PROFESSION_NAMES[profId] or "Unknown"
            PL.ShowViewerError(targetPlayer, professionName, "Failed to send request")
        end
        
        return nil
    end
end

-- Public API for generating and posting profession links
-- Slash command integration
function PL.HandleSlashCommand(args)
    local cmd, param = args:match("^(%w+)%s*(.*)")
    cmd = cmd and cmd:lower()
    
    if cmd == "link" then
        -- Updated to use modern profession detection
        local targetProfession = param ~= "" and param or nil
        local link = PL.GenerateModernProfessionLink(targetProfession)
        if link then
            print("|cffffff00CraftersBoard|r Profession link: " .. link)
            print("|cffffff00CraftersBoard|r Click link to view profession")
        else
            print("|cffffff00CraftersBoard|r Failed to generate profession link. Make sure you have profession data available.")
            print("|cffffff00CraftersBoard|r Try: /cb scan first, or specify profession: /cb link <profession name>")
        end
    elseif cmd == "scan" then
        if PL.ForceScanCurrent() then
            print("|cffffff00CraftersBoard|r Profession scan completed")
        end
    elseif cmd == "info" then
        local professionName
        if GetTradeSkillLine then
            professionName = GetTradeSkillLine()
        end
        if professionName then
            local snapshot = PL.GetProfessionSnapshot(professionName)
            if snapshot then
                print("|cffffff00CraftersBoard|r " .. professionName .. " (" .. snapshot.rank .. "/" .. snapshot.maxRank .. ")")
                print("  Recipes: " .. #snapshot.recipes)
                print("  Categories: " .. tostring(#snapshot.categories))
                print("  Last scanned: " .. date("%H:%M:%S", snapshot.timestamp))
            else
                print("|cffffff00CraftersBoard|r No scan data for " .. professionName .. ". Use '/cb scan' first.")
            end
        else
            print("|cffffff00CraftersBoard|r No profession window open")
        end
    elseif cmd == "snapshots" then
        print("|cffffff00CraftersBoard|r Profession snapshots:")
        for name, snapshot in pairs(professionSnapshots) do
            print("  " .. name .. " (" .. snapshot.rank .. "/" .. snapshot.maxRank .. ") - " .. #snapshot.recipes .. " recipes")
        end
    elseif cmd == "cache" then
        print("|cffffff00CraftersBoard|r Cached profession data:")
        for playerName, professions in pairs(cachedProfessions) do
            print("  " .. playerName .. ":")
            for profName, snapshot in pairs(professions) do
                print("    " .. profName .. " (" .. snapshot.rank .. "/" .. snapshot.maxRank .. ")")
            end
        end
    elseif cmd == "view" then
        -- Handle profession viewing command
        local playerName, professionName = param:match("^(%S+)%s+(.+)")
        if not playerName or not professionName then
            print("|cffffff00CraftersBoard|r Usage: /cb view <playername> <profession>")
            print("|cffffff00CraftersBoard|r Example: /cb view " .. UnitName("player") .. " Alchemy")
            return
        end
        
        -- Check if we have data for this player's profession
        local snapshot = nil
        if playerName == UnitName("player") then
            -- Viewing our own profession
            snapshot = professionSnapshots[professionName]
        else
            -- Viewing another player's profession (from cache)
            if cachedProfessions[playerName] and cachedProfessions[playerName][professionName] then
                snapshot = cachedProfessions[playerName][professionName]
            end
        end
        
        if snapshot then
            PL.ShowProfessionData(playerName, professionName, snapshot)
            print("|cffffff00CraftersBoard|r Opened profession viewer for " .. playerName .. "'s " .. professionName)
        else
            print("|cffffff00CraftersBoard|r No data available for " .. playerName .. "'s " .. professionName)
            if playerName == UnitName("player") then
                print("  Try opening the " .. professionName .. " window and run '/cb scan' first")
            else
                print("  That player hasn't shared their " .. professionName .. " data yet")
            end
        end
    elseif cmd == "test" then
        -- Route to test command handler
        local subCmd, testParam = param:match("^(%w+)%s*(.*)")
        if subCmd then
            PL.HandleTestCommand(subCmd, testParam)
        else
            PL.HandleTestCommand("", param)
        end
    elseif cmd == "clear" then
        if param == "cache" then
            PL.ClearCachedData()
            print("|cffffff00CraftersBoard|r Cleared all cached profession data")
        else
            print("|cffffff00CraftersBoard|r Use '/cb clear cache' to clear cached data")
        end
    elseif cmd == "cleanup" then
        PL.CleanupOldCache()
        print("|cffffff00CraftersBoard|r Cleaned up old cache entries")
    elseif cmd == "stats" then
        local stats = PL.GetCacheStatistics()
        print("|cffffff00CraftersBoard|r Cache statistics: " .. stats)
        local lastCleanup = CRAFTERSBOARD_DB.professionCache and CRAFTERSBOARD_DB.professionCache.lastCleanup
        if lastCleanup then
            print("Last cleanup: " .. date("%m/%d %H:%M", lastCleanup))
        end
    elseif cmd == "viewer" or cmd == "ui" then
        -- Show/hide the profession viewer
        if professionViewerFrame and professionViewerFrame:IsShown() then
            professionViewerFrame:Hide()
            print("|cffffff00CraftersBoard|r Profession viewer hidden")
        else
            if param ~= "" then
                -- Try to show specific player's data
                local playerName, professionName = param:match("^([^%s]+)%s*(.*)$")
                if playerName and cachedProfessions[playerName] then
                    local professions = cachedProfessions[playerName]
                    if professionName and professionName ~= "" then
                        local snapshot = professions[professionName]
                        if snapshot then
                            PL.ShowProfessionData(playerName, professionName, snapshot)
                        else
                            print("|cffffff00CraftersBoard|r No cached " .. professionName .. " data for " .. playerName)
                        end
                    else
                        -- Show first available profession
                        for name, snapshot in pairs(professions) do
                            PL.ShowProfessionData(playerName, name, snapshot)
                            break
                        end
                    end
                else
                    print("|cffffff00CraftersBoard|r No cached profession data for " .. (playerName or "unknown player"))
                end
            else
                -- Show own profession data by default
                local ownPlayerName = UnitName("player")
                local foundProfession = false
                
                -- First try to show from our own snapshots
                for profName, snapshot in pairs(professionSnapshots) do
                    PL.ShowProfessionData(ownPlayerName, profName, snapshot)
                    foundProfession = true
                    break
                end
                
                if not foundProfession then
                    -- No snapshots available, try to scan and show
                    print("|cffffff00CraftersBoard|r No profession data available. Scanning professions...")
                    PL.ScanAllPlayerProfessions()
                    
                    -- Wait a moment and try again
                    C_Timer.After(1, function()
                        local scannedProfession = false
                        for profName, snapshot in pairs(professionSnapshots) do
                            PL.ShowProfessionData(ownPlayerName, profName, snapshot)
                            scannedProfession = true
                            break
                        end
                        
                        if not scannedProfession then
                            print("|cffffff00CraftersBoard|r No professions found. Make sure you have learned professions.")
                            print("Use '/cb viewer PlayerName [ProfessionName]' to view other players' cached data")
                        end
                    end)
                end
            end
        end
    elseif cmd == "scanall" then
        print("|cffffff00CraftersBoard|r Scanning all professions...")
        PL.ScanAllPlayerProfessions()
    elseif cmd == "debug" then
        -- Enable/disable debug mode
        if param == "on" then
            if CRAFTERSBOARD_DB then
                CRAFTERSBOARD_DB.debug = true
                print("|cffffff00CraftersBoard|r Debug mode enabled")
            end
        elseif param == "off" then
            if CRAFTERSBOARD_DB then
                CRAFTERSBOARD_DB.debug = false
                print("|cffffff00CraftersBoard|r Debug mode disabled")
            end
        else
            local debugState = (CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug) and "enabled" or "disabled"
            print("|cffffff00CraftersBoard|r Debug mode is currently " .. debugState)
            print("Use '/cb debug on' or '/cb debug off' to change")
        end
    elseif cmd == "debugnet" then
        -- Enable/disable debug network mode (forces own profession links through network)
        if param == "on" then
            if CRAFTERSBOARD_DB then
                CRAFTERSBOARD_DB.debugNetworkMode = true
                print("|cffffff00CraftersBoard|r Debug network mode enabled")
                print("Your own profession links will now go through the network optimization system")
            end
        elseif param == "off" then
            if CRAFTERSBOARD_DB then
                CRAFTERSBOARD_DB.debugNetworkMode = false
                print("|cffffff00CraftersBoard|r Debug network mode disabled")
                print("Your own profession links will use local cache again")
            end
        else
            local debugNetState = (CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debugNetworkMode) and "enabled" or "disabled"
            print("|cffffff00CraftersBoard|r Debug network mode is currently " .. debugNetState)
            print("Use '/cb debugnet on' or '/cb debugnet off' to change")
            print("When enabled, your own profession links will go through network optimization for testing")
        end
    elseif cmd == "recipes" then
        -- Show detailed recipe information for current profession
        local currentProf = PL.GetCurrentProfession()
        if currentProf then
            local snapshot = professionSnapshots[currentProf]
            if snapshot then
                print("|cffffff00CraftersBoard|r === " .. currentProf .. " Recipes ===")
                print("Total recipes: " .. #snapshot.recipes)
                for i, recipe in ipairs(snapshot.recipes) do
                    local reagentCount = recipe.reagents and #recipe.reagents or 0
                    print("  " .. i .. ". " .. recipe.name .. " (" .. recipe.type .. ") - " .. reagentCount .. " reagents")
                    if reagentCount > 0 and i <= 5 then -- Show first 5 recipes with reagents
                        for j, reagent in ipairs(recipe.reagents) do
                            print("    - " .. reagent.name .. " (" .. reagent.required .. " needed, " .. reagent.available .. " have)")
                        end
                    end
                end
            else
                print("|cffffff00CraftersBoard|r No recipe data for " .. currentProf)
            end
        else
            print("|cffffff00CraftersBoard|r No profession window open")
        end
    elseif cmd == "testdata" then
        -- Test data serialization/deserialization
        local currentProf = PL.GetCurrentProfession()
        if currentProf then
            local snapshot = professionSnapshots[currentProf]
            if snapshot then
                print("|cffffff00CraftersBoard|r Testing data serialization for " .. currentProf)
                print("Original: " .. #snapshot.recipes .. " recipes")
                
                local serialized = PL.SerializeProfessionData(snapshot)
                if serialized then
                    print("Serialized: " .. string.len(serialized) .. " bytes")
                    
                    local deserialized = PL.DeserializeProfessionData(serialized)
                    if deserialized then
                        print("Deserialized: " .. #deserialized.recipes .. " recipes")
                        
                        -- Test chunking
                        local chunks = PL.CreateChunks(serialized, MAX_ADDON_MESSAGE_SIZE - 50)
                        print("Would send " .. #chunks .. " chunks (max allowed: " .. MAX_CHUNKS_PER_REQUEST .. ")")
                        
                        if #chunks <= MAX_CHUNKS_PER_REQUEST then
                            print("|cff00ff00Data transfer should work fine|r")
                        else
                            print("|cffff0000Data too large for transfer!|r")
                        end
                    else
                        print("|cffff0000Failed to deserialize data|r")
                    end
                else
                    print("|cffff0000Failed to serialize data|r")
                end
            else
                print("|cffffff00CraftersBoard|r No snapshot data for " .. currentProf)
            end
        else
            print("|cffffff00CraftersBoard|r No profession window open")
        end
    elseif cmd == "testcomm" then
        -- Test addon message communication
        print("|cffffff00CraftersBoard|r === Testing Addon Communication ===")
        
        -- Test 1: Check if prefix is registered
        print("1. Testing message prefix registration...")
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            print("   ✓ Modern API available (C_ChatInfo)")
        elseif RegisterAddonMessagePrefix then
            print("   ✓ Classic API available (RegisterAddonMessagePrefix)")
        else
            print("   ✗ No addon message prefix API available!")
        end
        
        -- Test 2: Check if SendAddonMessage works
        print("2. Testing message sending capability...")
        local testMessage = "TEST:ping"
        local success = SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, testMessage, "WHISPER", UnitName("player"))
        if success then
            print("   ✓ SendAddonMessage function working")
        else
            print("   ✗ SendAddonMessage function failed!")
        end
        
        -- Test 3: Show current snapshots
        print("3. Current profession snapshots:")
        local count = 0
        for profName, snapshot in pairs(professionSnapshots) do
            count = count + 1
            print("   " .. profName .. ": " .. #snapshot.recipes .. " recipes")
        end
        if count == 0 then
            print("   No profession data cached. Use '/cb scanall' first.")
        else
            print("   Total: " .. count .. " professions ready for sharing")
        end
        
        -- Test 4: Check pending requests
        print("4. Pending profession requests:")
        local pendingCount = 0
        for reqId, request in pairs(pendingRequests) do
            pendingCount = pendingCount + 1
            print("   " .. reqId .. ": " .. (request.professionName or "Unknown") .. " from " .. request.target)
        end
        if pendingCount == 0 then
            print("   No pending requests")
        end
        
        print("|cffffff00CraftersBoard|r Communication test complete.")
    elseif cmd == "snapshots" then
        local playerName = UnitName("player")
        print("|cffffff00CraftersBoard|r === Your Profession Snapshots ===")
        local count = 0
        for profName, snapshot in pairs(professionSnapshots) do
            count = count + 1
            print("  " .. profName .. ": " .. (snapshot.rank or 0) .. "/" .. (snapshot.maxRank or 0) .. 
                  " (" .. #snapshot.recipes .. " recipes, updated " .. date("%H:%M:%S", snapshot.timestamp or 0) .. ")")
        end
        if count == 0 then
            print("  No profession snapshots found. Use '/cb scanall' to scan your professions.")
        else
            print("Total: " .. count .. " profession snapshots")
        end
    else
        print("|cffffff00CraftersBoard|r Profession Links commands:")
        print("  /cb link - Generate profession link")
        print("  /cb scan - Force scan current profession")
        print("  /cb info - Show current profession info")
        print("  /cb snapshots - List all profession snapshots")
        print("  /cb cache - Show cached profession data from others")
        print("  /cb test - Test commands (use '/cb test' for list)")
        print("  /cb testcomm - Test addon communication system")
        print("  /cb clear cache - Clear cached profession data")
        print("  /cb cleanup - Clean up old cache entries")
        print("  /cb stats - Show cache statistics")
        print("  /cb viewer [player] [profession] - Show/hide profession viewer")
        print("  /cb scanall - Force scan all professions")
        print("  /cb debug [on|off] - Enable/disable debug mode")
        print("  /cb debugnet [on|off] - Force own profession links through network (for testing)")
        print("  /cb recipes - Show detailed recipe info for current profession")
        print("  /cb testdata - Test data serialization for current profession")
    end
end

-- Handle test commands for development/debugging
function PL.HandleTestCommand(subCmd, param)
    if subCmd == "scanopen" then
        -- Force scan current profession and open viewer
        PL.ScanCurrentProfession()
        C_Timer.After(0.5, function()
            -- Try to find current profession and show it
            local currentProf = PL.GetCurrentProfession()
            if currentProf then
                local snapshot = professionSnapshots[currentProf]
                if snapshot then
                    PL.ShowProfessionData(UnitName("player"), currentProf, snapshot)
                    print("|cffffff00CraftersBoard|r Opened viewer with current " .. currentProf .. " data")
                else
                    print("|cffffff00CraftersBoard|r No snapshot available for " .. currentProf)
                end
            else
                print("|cffffff00CraftersBoard|r No profession window open")
            end
        end)
    elseif subCmd == "db" then
        -- Test recipe database access
        print("|cffffff00CraftersBoard|r === Testing Recipe Database ===")
        
        if CraftersBoard_VanillaData then
            print("✓ Recipe database loaded")
            
            if CraftersBoard_VanillaData.SPELL_TO_RECIPE then
                local count = 0
                for _ in pairs(CraftersBoard_VanillaData.SPELL_TO_RECIPE) do 
                    count = count + 1 
                end
                print("✓ Contains " .. count .. " spell-to-recipe mappings")
                
                -- Test a few known spells
                local testSpells = {2259, 2018, 3464, 7411} -- Minor Healing Potion, Blacksmithing, Enchanting, etc
                for _, spellID in ipairs(testSpells) do
                    local recipe = PL.ResolveRecipeFromSpellID(spellID)
                    if recipe then
                        print("✓ Spell " .. spellID .. " → " .. recipe.name .. " (source: " .. recipe.source .. ")")
                    else
                        print("✗ Spell " .. spellID .. " → not found")
                    end
                end
            else
                print("✗ SPELL_TO_RECIPE table missing")
            end
        else
            print("✗ Recipe database not loaded (CraftersBoard_VanillaData is nil)")
        end
    elseif subCmd == "spells" then
        -- Test spell ID extraction from current profession snapshots
        print("|cffffff00CraftersBoard|r === Testing Spell ID Extraction ===")
        
        local totalSpells = 0
        for profName, snapshot in pairs(professionSnapshots) do
            print("Profession: " .. profName)
            print("  Recipes: " .. #(snapshot.recipes or {}))
            
            local spellIds = PL.ExtractSpellIDs(snapshot.recipes)
            print("  Spell IDs: " .. #spellIds)
            totalSpells = totalSpells + #spellIds
            
            -- Show first few spell IDs
            for i = 1, math.min(5, #spellIds) do
                local recipe = nil
                for _, r in pairs(snapshot.recipes) do
                    if r.spellID == spellIds[i] then
                        recipe = r
                        break
                    end
                end
                if recipe then
                    print("    " .. spellIds[i] .. " → " .. recipe.name)
                end
            end
        end
        
        print("Total spell IDs across all professions: " .. totalSpells)
    elseif subCmd == "rescan" then
        -- Force rescan of all professions to pick up spell IDs
        print("|cffffff00CraftersBoard|r === Force Rescanning All Professions ===")
        print("This will rescan all your profession windows to capture spell IDs.")
        print("Please open each profession window and they will be scanned automatically.")
        
        -- Clear existing snapshots to force fresh scan
        for profName, _ in pairs(professionSnapshots) do
            professionSnapshots[profName] = nil
            print("Cleared cached data for: " .. profName)
        end
        
        print("Open your profession windows now - they will be scanned automatically with spell ID capture.")
    elseif subCmd == "cache" then
        -- Show cache information
        local stats = PL.GetCacheStatistics()
        print("|cffffff00CraftersBoard|r " .. stats)
        
        print("Own snapshots:")
        for prof, snapshot in pairs(professionSnapshots) do
            print("  " .. prof .. ": " .. (snapshot.rank or 0) .. "/" .. (snapshot.maxRank or 0) .. 
                  " (" .. #snapshot.recipes .. " recipes)")
        end
        
        print("Cached players:")
        for player, profs in pairs(cachedProfessions) do
            print("  " .. player .. ":")
            for prof, snapshot in pairs(profs) do
                print("    " .. prof .. ": " .. (snapshot.rank or 0) .. "/" .. (snapshot.maxRank or 0))
            end
        end
    elseif subCmd == "ui" then
        -- Test UI creation
        PL.CreateProfessionViewer()
        print("|cffffff00CraftersBoard|r Created profession viewer UI")
    elseif subCmd == "scan" then
        -- Force scan current profession
        PL.ScanCurrentProfession()
        print("|cffffff00CraftersBoard|r Forced profession scan")
    else
        print("|cffffff00CraftersBoard|r Test commands:")
        print("  /cb test scanopen - Scan and open viewer")
        print("  /cb test cache - Show cache contents")
        print("  /cb test ui - Create viewer UI")
        print("  /cb test scan - Force profession scan")
        print("  /cb test db - Test recipe database")
        print("  /cb test spells - Test spell ID extraction")
        print("  /cb test rescan - Clear and rescan all professions (to capture spell IDs)")
    end
end

-- Get the currently open profession name
function PL.GetCurrentProfession()
    -- Check if any profession window is open
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        -- Get the profession name from the trade skill frame
        local profName = GetTradeSkillLine()
        if profName and profName ~= "" then
            return profName
        end
    end
    
    -- Check for crafting window (Classic Era)
    if CraftFrame and CraftFrame:IsShown() then
        local profName = GetCraftDisplaySkillLine()
        if profName and profName ~= "" then
            return profName
        end
    end
    
    -- Try to get from profession spellbook
    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    
    -- Check primary professions
    if prof1 then
        local name, _, _, _, _, _, skillLine = GetProfessionInfo(prof1)
        if name and skillLine then
            -- Check if this profession window might be open
            return name
        end
    end
    
    if prof2 then
        local name, _, _, _, _, _, skillLine = GetProfessionInfo(prof2)
        if name and skillLine then
            return name
        end
    end
    
    -- Check secondary professions
    if cooking then
        local name = GetProfessionInfo(cooking)
        if name then
            return name
        end
    end
    
    if fishing then
        local name = GetProfessionInfo(fishing)
        if name then
            return name
        end
    end
    
    return nil
end

-- Trade skill window event handlers
function PL.OnTradeSkillShow()
    CB.Debug("Trade skill window opened")
    -- Start scanning after a small delay to ensure window is fully loaded
    C_Timer.After(0.5, function()
        PL.ScanCurrentProfession()
        -- Add our link button to the profession frame
        PL.AddLinkButtonToProfessionFrame()
    end)
end

function PL.OnTradeSkillUpdate()
    -- Only scan if we're not already scanning and enough time has passed
    if not scanInProgress and (time() - lastScanTime) >= SCAN_COOLDOWN then
        CB.Debug("Trade skill window updated, triggering scan")
        C_Timer.After(0.2, function()
            PL.ScanCurrentProfession()
        end)
    end
end

function PL.OnTradeSkillClose()
    CB.Debug("Trade skill window closed")
    scanInProgress = false
    -- Remove the link button when window closes
    PL.RemoveLinkButtonFromProfessionFrame()
end

-- New event handlers for auto-scanning
function PL.OnPlayerEnteringWorld()
    CB.Debug("Player entering world - scheduling profession scan")
    -- Delay the scan to ensure all profession data is loaded
    C_Timer.After(3, function()
        PL.ScanAllPlayerProfessions()
    end)
end

function PL.OnAddonLoaded()
    CB.Debug("CraftersBoard addon loaded - scheduling profession scan")
    -- Delay the scan to ensure all systems are ready
    C_Timer.After(2, function()
        PL.ScanAllPlayerProfessions()
    end)
end

function PL.OnCraftShow()
    CB.Debug("Craft window opened")
    -- Start scanning after a small delay to ensure window is fully loaded
    C_Timer.After(0.5, function()
        PL.ScanCurrentProfession()
        -- Add our link button to the profession frame
        PL.AddLinkButtonToProfessionFrame()
    end)
end

-- Add a "Generate Link" button to the original WoW profession frame
function PL.AddLinkButtonToProfessionFrame()
    -- Check if button already exists
    if _G["CraftersBoardLinkButton"] then
        return -- Button already exists
    end
    
    local targetFrame = nil
    local buttonAnchor = nil
    
    -- Try TradeSkillFrame first (most professions)
    if TradeSkillFrame and TradeSkillFrame:IsVisible() then
        targetFrame = TradeSkillFrame
        -- Try to find a good anchor point near existing buttons
        if TradeSkillFrameCloseButton then
            buttonAnchor = TradeSkillFrameCloseButton
        elseif TradeSkillFrame.CloseButton then
            buttonAnchor = TradeSkillFrame.CloseButton
        end
        CB.Debug("Adding link button to TradeSkillFrame")
    
    -- Try CraftFrame (enchanting in Classic)
    elseif CraftFrame and CraftFrame:IsVisible() then
        targetFrame = CraftFrame
        if CraftFrameCloseButton then
            buttonAnchor = CraftFrameCloseButton
        elseif CraftFrame.CloseButton then
            buttonAnchor = CraftFrame.CloseButton
        end
        CB.Debug("Adding link button to CraftFrame")
    end
    
    if not targetFrame then
        CB.Debug("No suitable profession frame found for button placement")
        return
    end
    
    -- Create the button
    local button = CreateFrame("Button", "CraftersBoardLinkButton", targetFrame, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetText("Share Link")
    
    -- Position the button
    if buttonAnchor then
        -- Position near the close button
        button:SetPoint("TOPRIGHT", buttonAnchor, "TOPLEFT", -5, 0)
    else
        -- Fallback position
        button:SetPoint("TOPRIGHT", targetFrame, "TOPRIGHT", -130, -5)
    end
    
    -- Set up button click handler
    button:SetScript("OnClick", function()
        PL.GenerateAndShareProfessionLink()
    end)
    
    -- Set up tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("CraftersBoard", 1, 1, 1, 1, true)
        GameTooltip:AddLine("Smart profession link sharing", nil, nil, nil, true)
        GameTooltip:AddLine("Inserts safe format if chat is open", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Shows clickable dialog otherwise", 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    CB.Debug("Successfully added CraftersBoard link button to profession frame")
end

-- Generate and share profession link directly to the active chat channel
function PL.GenerateAndShareProfessionLink()
    -- Use the EXACT same workflow as the working scanopen viewer button
    -- First, I need to create a temporary viewer frame with the current data
    local professionName = nil
    local rank = 0
    
    if GetTradeSkillLine then
        local skillName, skillRank, skillMaxRank = GetTradeSkillLine()
        if skillName then
            professionName = skillName
            rank = skillRank or 0
        end
    end
    
    if not professionName or professionName == "" then
        print("|cffffff00CraftersBoard|r No profession window open. Please open a profession first.")
        return
    end
    
    local playerName = UnitName("player") or "Unknown"
    
    -- Print the link details to chat console for debugging
    print("|cffffff00CraftersBoard|r Generating profession link using scanopen workflow:")
    print("|cffffff00CraftersBoard|r Player: " .. playerName .. ", Profession: " .. professionName .. " (" .. rank .. ")")
    
    -- Generate the working link format (same as scanopen)
    local linkData = string.format("%s:%s", playerName, professionName)
    local linkText = string.format("[%s's %s]", playerName, professionName)
    local workingLink = string.format("|HcraftersProfession:%s|h%s|h", linkData, linkText)
    
    -- Print the generated link to chat console
    print("|cffffff00CraftersBoard|r Generated link:")
    print(workingLink)
    CB.Debug("Safe format: [[" .. playerName .. "'s " .. professionName .. "]]")
    
    -- Check if any chat input is open and paste the link there
    local chatEditBox = ChatEdit_GetActiveWindow()
    if chatEditBox and chatEditBox:IsVisible() then
        -- Chat input is open, insert the SAFE format (same as shift+click behavior)
        -- This is the format that doesn't cause escape code errors
        local safeFormat = string.format("[[%s's %s]]", playerName, professionName)
        ChatEdit_InsertLink(safeFormat)
        print("|cffffff00CraftersBoard|r ✓ Inserted safe profession link into active chat!")
        print("|cffffff00CraftersBoard|r Format: " .. safeFormat)
        return
    end
    
    -- No chat input is open, show the dialog as fallback
    print("|cffffff00CraftersBoard|r No active chat input - showing link dialog instead")
    
    -- Create a mock viewer frame with the required data (same as the working scanopen viewer)
    local mockFrame = {
        currentPlayerName = playerName,
        currentProfessionName = professionName
    }
    
    -- Use the EXACT same function that the working scanopen viewer uses
    PL.GenerateAndShowProfessionLink(mockFrame)
end

-- Remove the link button from the profession frame
function PL.RemoveLinkButtonFromProfessionFrame()
    local button = _G["CraftersBoardLinkButton"]
    if button then
        button:Hide()
        button:SetParent(nil)
        _G["CraftersBoardLinkButton"] = nil
        CB.Debug("Removed CraftersBoard link button from profession frame")
    end
end

function PL.OnCraftUpdate()
    CB.Debug("Craft window updated")
    if scanInProgress then return end
    
    -- Scan on updates (recipes learned, etc.)
    C_Timer.After(0.2, function()
        PL.ScanCurrentProfession()
    end)
end

function PL.OnCraftClose()
    CB.Debug("Craft window closed")
    scanInProgress = false
    -- Remove the link button when window closes
    PL.RemoveLinkButtonFromProfessionFrame()
end

function PL.OnSkillLinesChanged()
    CB.Debug("Skill lines changed - may have learned/unlearned profession")
    -- Scan all professions when skill lines change
    C_Timer.After(1, function()
        PL.ScanAllPlayerProfessions()
    end)
end

function PL.OnLearnedSpell(spellId)
    CB.Debug("Learned spell: " .. tostring(spellId))
    -- Check if it's a profession spell and scan accordingly
    C_Timer.After(0.5, function()
        PL.ScanAllPlayerProfessions()
    end)
end

-- Scan the currently open profession window
-- Legacy function - replaced by automatic scanning
function PL.ScanPlayerProfessions()
    print("|cffffff00CraftersBoard|r This function has been replaced by automatic scanning.")
    print("Use '/cb test scan' to force a scan of all professions.")
    return PL.ScanAllPlayerProfessions()
end

-- Scan all player professions automatically
function PL.ScanAllPlayerProfessions()
    CB.Debug("Starting automatic scan of all player professions...")
    
    local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions()
    local scannedCount = 0
    
    -- Scan primary professions
    if prof1 then
        local name = GetProfessionInfo(prof1)
        if name then
            PL.ScanProfessionByName(name)
            scannedCount = scannedCount + 1
        end
    end
    
    if prof2 then
        local name = GetProfessionInfo(prof2)
        if name then
            PL.ScanProfessionByName(name)
            scannedCount = scannedCount + 1
        end
    end
    
    -- Scan secondary professions
    if cooking then
        local name = GetProfessionInfo(cooking)
        if name then
            PL.ScanProfessionByName(name)
            scannedCount = scannedCount + 1
        end
    end
    
    if fishing then
        local name = GetProfessionInfo(fishing)
        if name then
            PL.ScanProfessionByName(name)
            scannedCount = scannedCount + 1
        end
    end
    
    if firstAid then
        local name = GetProfessionInfo(firstAid)
        if name then
            PL.ScanProfessionByName(name)
            scannedCount = scannedCount + 1
        end
    end
    
    CB.Debug("Automatic profession scan completed - scanned " .. scannedCount .. " professions")
    
    if scannedCount > 0 then
        print("|cffffff00CraftersBoard|r Auto-scanned " .. scannedCount .. " professions")
    end
end

-- Scan a specific profession by name (without opening the UI)
function PL.ScanProfessionByName(professionName)
    if not professionName then return false end
    
    CB.Debug("Scanning profession: " .. professionName)
    
    -- Create a basic snapshot for professions we can't fully scan without UI
    local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions()
    local professions = {prof1, prof2, archaeology, fishing, cooking, firstAid}
    
    for _, profIndex in ipairs(professions) do
        if profIndex then
            local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier, specializationIndex, specializationOffset = GetProfessionInfo(profIndex)
            
            if name == professionName then
                -- Create basic snapshot
                local snapshot = {
                    name = name,
                    icon = icon,
                    rank = skillLevel or 0,
                    maxRank = maxSkillLevel or 0,
                    timestamp = time(),
                    recipes = {}, -- Will be populated when profession UI is opened
                    categories = {},
                    playerName = UnitName("player"),
                    playerRealm = GetRealmName(),
                    version = "auto-scan"
                }
                
                -- Store the snapshot
                PL.CacheOwnSnapshot(professionName, snapshot)
                CB.Debug("Created basic snapshot for " .. professionName .. " (" .. snapshot.rank .. "/" .. snapshot.maxRank .. ")")
                return true
            end
        end
    end
    
    CB.Debug("Could not find profession: " .. professionName)
    return false
end

-- Get available cached profession data for player
function PL.GetPlayerProfessionData()
    local playerName = UnitName("player")
    local availableProfessions = {}
    
    CB.Debug("GetPlayerProfessionData checking for player: " .. playerName)
    CB.Debug("Available snapshots: " .. PL.GetTableSize(professionSnapshots))
    
    for profName, snapshot in pairs(professionSnapshots) do
        CB.Debug("  Found profession: " .. profName)
        table.insert(availableProfessions, {
            name = profName,
            data = snapshot
        })
    end
    
    return availableProfessions
end

-- List player's cached profession data
function PL.ListPlayerProfessions()
    local playerName = UnitName("player")
    print("|cffffff00CraftersBoard|r === Cached Profession Data for " .. playerName .. " ===")
    
    local professionsFound = 0
    for profName, snapshot in pairs(professionSnapshots) do
        professionsFound = professionsFound + 1
        print("  " .. profName .. ": " .. (snapshot.rank or 0) .. "/" .. (snapshot.maxRank or 0) .. 
              " (" .. #snapshot.recipes .. " recipes, updated " .. 
              date("%H:%M:%S", snapshot.timestamp) .. ")")
    end
    
    if professionsFound == 0 then
        print("  No profession data cached yet.")
        print("  Open a profession window and run '/cb test scan' to scan your professions.")
    else
        print("Total professions cached: " .. professionsFound)
    end
end

-- Automatic profession scanning system
function PL.StartAutomaticScanning()
    CB.Debug("Starting automatic profession scanning...")
    
    -- Try to scan professions immediately if possible
    C_Timer.After(2, function()
        PL.ScanAllAvailableProfessions()
    end)
    
    -- Set up periodic scanning
    if not PL.scanTimer then
        PL.scanTimer = C_Timer.NewTicker(60, function() -- Check every minute
            PL.ScanAllAvailableProfessions()
        end)
        CB.Debug("Started periodic profession scanning")
    end
end

-- Scan all available professions the player knows
function PL.ScanAllAvailableProfessions()
    CB.Debug("Scanning all available professions...")
    
    local scannedCount = 0
    local totalProfessions = 0
    
    -- Get list of known professions by checking spells
    local knownProfessions = PL.GetKnownProfessions()
    totalProfessions = #knownProfessions
    
    if totalProfessions == 0 then
        CB.Debug("No professions found to scan")
        return
    end
    
    CB.Debug("Found " .. totalProfessions .. " known professions to scan")
    
    -- For each known profession, try to open it and scan
    for _, profData in ipairs(knownProfessions) do
        if PL.TryScanProfession(profData.name, profData.spellId) then
            scannedCount = scannedCount + 1
        end
    end
    
    if scannedCount > 0 then
        print("|cffffff00CraftersBoard|r Auto-scanned " .. scannedCount .. "/" .. totalProfessions .. " professions")
        CB.Debug("Auto-scan completed: " .. scannedCount .. "/" .. totalProfessions .. " professions")
    end
end

-- Get list of professions the player knows
function PL.GetKnownProfessions()
    local knownProfs = {}
    
    -- Check each profession spell to see if player knows it
    local professionSpells = {
        {spell = 2259, name = "Alchemy"},
        {spell = 2018, name = "Blacksmithing"},  
        {spell = 7411, name = "Enchanting"},
        {spell = 4036, name = "Engineering"},
        {spell = 3908, name = "First Aid"},
        {spell = 2550, name = "Cooking"},
        {spell = 8613, name = "Leatherworking"},
        {spell = 7924, name = "Tailoring"},
    }
    
    for _, prof in ipairs(professionSpells) do
        if IsSpellKnown(prof.spell) then
            table.insert(knownProfs, {
                name = prof.name,
                spellId = prof.spell
            })
            CB.Debug("Player knows profession: " .. prof.name)
        end
    end
    
    return knownProfs
end

-- Try to scan a specific profession
function PL.TryScanProfession(professionName, spellId)
    -- Check if we already have recent data
    local existingSnapshot = professionSnapshots[professionName]
    if existingSnapshot and (time() - existingSnapshot.timestamp) < 300 then
        CB.Debug("Skipping " .. professionName .. " - already scanned recently")
        return false
    end
    
    CB.Debug("TryScanProfession: Attempting to scan " .. professionName .. " (spell " .. spellId .. ")")
    
    -- For Classic Era, we need to check if the profession window is already open
    -- and scan directly if it matches what we want
    if TradeSkillFrame and TradeSkillFrame:IsVisible() then
        local currentProf = GetTradeSkillLine and GetTradeSkillLine()
        CB.Debug("TryScanProfession: Trade skill window is open with: " .. tostring(currentProf))
        
        if currentProf == professionName then
            CB.Debug("TryScanProfession: Current profession matches target, scanning...")
            if PL.ScanCurrentProfession() then
                CB.Debug("Successfully scanned " .. professionName .. " from already open window")
                return true
            end
        end
    end
    
    -- Try to open the profession using spell casting (this might not work in all contexts)
    CB.Debug("TryScanProfession: Attempting to cast profession spell for " .. professionName)
    
    -- Use a more reliable method - check if player can cast the spell
    if IsSpellKnown(spellId) then
        -- Create a temporary scanning state
        PL.pendingScanProfession = professionName
        
        -- Try to cast the spell
        local spellName = GetSpellInfo(spellId)
        if spellName then
            CB.Debug("TryScanProfession: Casting spell: " .. spellName)
            CastSpell(spellName)
            
            -- Set up a timer to check if the window opened
            C_Timer.After(1, function()
                if TradeSkillFrame and TradeSkillFrame:IsVisible() then
                    local currentProf = GetTradeSkillLine and GetTradeSkillLine()
                    CB.Debug("TryScanProfession: After spell cast, window shows: " .. tostring(currentProf))
                    
                    if currentProf == PL.pendingScanProfession then
                        if PL.ScanCurrentProfession() then
                            CB.Debug("Successfully auto-scanned " .. professionName .. " after spell cast")
                            -- Close the profession window to avoid clutter
                            HideUIPanel(TradeSkillFrame)
                        end
                    end
                end
                PL.pendingScanProfession = nil
            end)
            
            return true
        else
            CB.Debug("TryScanProfession: Could not get spell name for ID " .. spellId)
        end
    else
        CB.Debug("TryScanProfession: Player does not know spell " .. spellId .. " for " .. professionName)
    end
    
    return false
end

function PL.ScanCurrentProfession()
    if scanInProgress then
        CB.Debug("Scan already in progress, skipping")
        return false
    end
    
    local professionName
    if GetTradeSkillLine then
        professionName = GetTradeSkillLine()
    end
    if not professionName or professionName == "" then
        CB.Debug("No profession window open")
        return false
    end
    
    scanInProgress = true
    lastScanTime = time()
    
    CB.Debug("Starting profession scan for: " .. professionName)
    
    -- Classic Era API compatibility
    local skillName, rank, maxRank
    if GetTradeSkillLine then
        skillName, rank, maxRank = GetTradeSkillLine()
    else
        -- Fallback if function doesn't exist
        rank = 0
        maxRank = 300
    end
    local numSkills = GetNumTradeSkills()
    
    CB.Debug("ScanCurrentProfession: Found " .. numSkills .. " trade skills to scan")
    
    local snapshot = {
        name = professionName,
        playerName = UnitName("player"),
        playerRealm = GetRealmName(),
        rank = rank or 0,
        maxRank = maxRank or 0,
        timestamp = time(),
        recipes = {},
        categories = {},
        version = "detailed-scan"
    }
    
    -- Scan all recipes with better validation
    local recipesScanned = 0
    local headersFound = 0
    
    for i = 1, numSkills do
        local recipe = PL.ScanRecipe(i)
        if recipe then
            table.insert(snapshot.recipes, recipe)
            recipesScanned = recipesScanned + 1
            
            -- Organize by category
            local category = recipe.category or "Other"
            if not snapshot.categories[category] then
                snapshot.categories[category] = {}
            end
            table.insert(snapshot.categories[category], #snapshot.recipes)
            
            CB.Debug("  Scanned recipe " .. i .. ": " .. recipe.name .. " (category: " .. category .. ", reagents: " .. #recipe.reagents .. ")")
        else
            -- Check if this was a header
            local name, type = GetTradeSkillInfo(i)
            if type == "header" then
                headersFound = headersFound + 1
                CB.Debug("  Found header " .. i .. ": " .. (name or "unnamed"))
            else
                CB.Debug("  Recipe " .. i .. " returned nil (not a header)")
            end
        end
    end
    
    -- Store the snapshot using new cache system
    PL.CacheOwnSnapshot(professionName, snapshot)
    
    -- Create optimized data for network transmission
    local professionId = PROFESSION_IDS[professionName] or 0
    local knownRecipeIds = {}
    
    for _, recipe in ipairs(snapshot.recipes) do
        if recipe.spellID and recipe.spellID > 0 then
            table.insert(knownRecipeIds, recipe.spellID)
        end
    end
    
    -- Store optimized data alongside the snapshot
    if professionId > 0 and #knownRecipeIds > 0 then
        local optimizedData = CreateOptimizedProfessionData(professionId, rank or 0, knownRecipeIds)
        
        -- Store both formats for backward compatibility and optimization
        snapshot.optimizedData = optimizedData
        snapshot.professionId = professionId
        
        CB.Debug(string.format("Created optimized data for %s: %d recipes (%d bytes → optimized)", 
              professionName, #knownRecipeIds, string.len(tostring(snapshot))))
        
        -- print("|cffffff00CraftersBoard|r Enhanced: " .. professionName .. " with " .. #knownRecipeIds .. " recipe IDs for optimized sharing")
    else
        CB.Debug("Warning: Could not create optimized data - missing profession ID or recipe spell IDs")
    end
    
    CB.Debug(string.format("Scan completed for %s (%d/%d): %d recipes, %d headers", 
          professionName, rank, maxRank, recipesScanned, headersFound))
    
    -- print("|cffffff00CraftersBoard|r Scanned " .. professionName .. ": " .. recipesScanned .. " recipes")
    
    scanInProgress = false
    return true
end

-- Scan individual recipe at index
function PL.ScanRecipe(index)
    -- Validate input
    if not index or index < 1 then
        return nil
    end
    
    local name, type, available, isExpanded, altVerb, numIndents = GetTradeSkillInfo(index)
    
    if not name or name == "" then
        CB.Debug("ScanRecipe: No name found for index " .. index)
        return nil
    end
    
    -- Skip headers (they have different type)
    if type == "header" then
        CB.Debug("ScanRecipe: Skipping header '" .. name .. "' at index " .. index)
        return nil
    end
    
    CB.Debug("ScanRecipe: Processing recipe '" .. name .. "' at index " .. index .. " (type: " .. tostring(type) .. ")")
    
    local recipe = {
        name = name,
        type = type, -- "trivial", "easy", "medium", "optimal"
        available = available or 0,
        numIndents = numIndents or 0,
        category = PL.GetRecipeCategory(index, numIndents),
        index = index -- Store original index for reference
    }
    
    -- Get difficulty information (Classic Era compatible)
    if GetTradeSkillDifficulty then
        local difficulty = GetTradeSkillDifficulty(index)
        if difficulty then
            recipe.difficulty = {
                color = difficulty,
                -- Map color to descriptive text
                text = PL.GetDifficultyText(difficulty)
            }
        end
    else
        -- Fallback for Classic Era - use the type field which already contains difficulty info
        recipe.difficulty = {
            color = type,
            text = type or "unknown"
        }
    end
    
    -- Get reagent information with better error handling
    local reagents = PL.GetRecipeReagents(index)
    recipe.reagents = reagents or {}
    
    -- Get additional recipe information
    if GetTradeSkillDescription then
        recipe.description = GetTradeSkillDescription(index)
    end
    
    -- Get tool requirement if any
    local toolTip = PL.GetRecipeToolTip(index)
    if toolTip and toolTip ~= "" then
        recipe.tool = toolTip
    end
    
    -- Get cooldown information if available
    if GetTradeSkillCooldown then
        local cooldown = GetTradeSkillCooldown(index)
        if cooldown and cooldown > 0 then
            recipe.cooldown = cooldown
        end
    end
    
    -- Try to get item link for the recipe result
    if GetTradeSkillItemLink then
        recipe.itemLink = GetTradeSkillItemLink(index)
    end
    
    -- CRITICAL: Get spell ID for network optimization
    -- Try multiple methods to get spell ID in Classic Era
    local spellId = nil
    
    -- Method 1: Try GetTradeSkillRecipeLink (for direct spell ID extraction)
    local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(index)
    if recipeLink then
        -- Extract spell ID from recipe link format: |cffffd000|Henchant:spellId|h[Recipe Name]|h|r
        spellId = recipeLink:match("|H.-:(%d+)|h")
        if spellId then
            CB.Debug("ScanRecipe: Found spell ID " .. spellId .. " via recipe link for '" .. name .. "'")
        else
            CB.Debug("ScanRecipe: Could not extract spell ID from recipe link: " .. recipeLink)
        end
    end
    
    -- Method 2: Try item link approach (Recipe_Master method)
    if not spellId and GetTradeSkillItemLink then
        local itemLink = GetTradeSkillItemLink(index)
        if itemLink then
            -- Extract item ID from link format: |cffffffff|Hitem:itemId:...|h[Item Name]|h|r
            local itemId = itemLink:match("|Hitem:(%d+):")
            if itemId then
                itemId = tonumber(itemId)
                CB.Debug("ScanRecipe: Found created item ID " .. itemId .. " for recipe '" .. name .. "'")
                
                -- Look up spell ID in Recipe_Master database by item ID
                spellId = PL.GetSpellIdFromItemId(itemId)
                if spellId then
                    CB.Debug("ScanRecipe: Found spell ID " .. spellId .. " via item ID lookup for '" .. name .. "'")
                else
                    CB.Debug("ScanRecipe: No spell ID found for item ID " .. itemId .. " in Recipe_Master database")
                end
            else
                CB.Debug("ScanRecipe: Could not extract item ID from item link: " .. itemLink)
            end
        else
            CB.Debug("ScanRecipe: No item link available - might be a non-item recipe (like enchantment)")
        end
    end
    
    -- Method 2.5: Try spell ID direct lookup for non-item recipes (like enchantments)
    if not spellId and recipeLink then
        -- Some recipes might have spell ID in the recipe link itself
        local potentialSpellId = recipeLink:match("|H.-:(%d+)|h")
        if potentialSpellId then
            potentialSpellId = tonumber(potentialSpellId)
            CB.Debug("ScanRecipe: Trying direct spell ID " .. potentialSpellId .. " from recipe link")
            
            -- Check if this spell ID exists in Recipe_Master as a key (for non-item recipes)
            local confirmedSpellId = PL.GetSpellIdBySpellKey(potentialSpellId)
            if confirmedSpellId then
                spellId = confirmedSpellId
                CB.Debug("ScanRecipe: Confirmed spell ID " .. spellId .. " via spell key lookup for '" .. name .. "'")
            end
        end
    end
    
    -- Method 3: Recipe name matching (fallback)
    if not spellId then
        CB.Debug("ScanRecipe: Trying Recipe_Master database lookup for '" .. name .. "'")
        
        -- Use Recipe_Master data to find spell ID by matching item names
        spellId = PL.GetSpellIdFromRecipeMasterData(name)
        if spellId then
            CB.Debug("ScanRecipe: Found spell ID " .. spellId .. " via Recipe_Master database for '" .. name .. "'")
        else
            CB.Debug("ScanRecipe: No spell ID found in Recipe_Master database for '" .. name .. "'")
            
            -- Fallback to legacy name mapping
            spellId = PL.GetSpellIdFromRecipeName(name)
            if spellId then
                CB.Debug("ScanRecipe: Found spell ID " .. spellId .. " via legacy name mapping for '" .. name .. "'")
            else
                CB.Debug("ScanRecipe: No spell ID found for '" .. name .. "' - will need manual mapping")
            end
        end
    end
    
    if spellId then
        recipe.spellID = tonumber(spellId)
    else
        CB.Debug("ScanRecipe: WARNING - No spell ID captured for '" .. name .. "' - network optimization will not work!")
    end
    
    CB.Debug("ScanRecipe: Successfully scanned '" .. name .. "' with " .. #recipe.reagents .. " reagents (category: " .. tostring(recipe.category) .. ")")
    
    return recipe
end

-- Get reagents for a recipe
function PL.GetRecipeReagents(index)
    local reagents = {}
    
    -- Check if the function exists and index is valid
    if not GetTradeSkillNumReagents or not index then
        CB.Debug("GetRecipeReagents: Missing API or invalid index")
        return reagents
    end
    
    local numReagents = GetTradeSkillNumReagents(index)
    if not numReagents or numReagents == 0 then
        CB.Debug("GetRecipeReagents: No reagents for index " .. index)
        return reagents
    end
    
    CB.Debug("GetRecipeReagents: Processing " .. numReagents .. " reagents for index " .. index)
    
    for i = 1, numReagents do
        local name, texture, count, playerCount = GetTradeSkillReagentInfo(index, i)
        if name and name ~= "" then
            local reagent = {
                name = name,
                texture = texture,
                required = count or 0,
                available = playerCount or 0
            }
            
            -- Try to get item link (may not exist in Classic Era)
            if GetTradeSkillReagentItemLink then
                local link = GetTradeSkillReagentItemLink(index, i)
                if link and link ~= "" then
                    reagent.link = link
                end
            end
            
            table.insert(reagents, reagent)
            CB.Debug("  Added reagent: " .. name .. " (" .. (count or 0) .. " needed, " .. (playerCount or 0) .. " available)")
        else
            CB.Debug("  Skipped empty reagent at slot " .. i)
        end
    end
    
    return reagents
end

-- Get tool requirement for recipe (if any)
function PL.GetRecipeToolTip(index)
    -- Get tool requirement using tooltip scanning (Classic Era compatible)
    if GetTradeSkillTools then
        return GetTradeSkillTools(index)
    end
    return nil
end

-- Determine recipe category based on indentation and position
function PL.GetRecipeCategory(index, numIndents)
    -- Find the last header above this recipe
    for i = index - 1, 1, -1 do
        local name, type, _, _, _, indents = GetTradeSkillInfo(i)
        if type == "header" and (indents or 0) <= (numIndents or 0) then
            return name
        end
    end
    return "Other"
end

-- Convert difficulty color to text
function PL.GetDifficultyText(color)
    if color == "trivial" then
        return "Trivial (Gray)"
    elseif color == "easy" then
        return "Easy (Green)"
    elseif color == "medium" then
        return "Medium (Yellow)"
    elseif color == "optimal" then
        return "Optimal (Orange)"
    else
        return "Unknown"
    end
end

-- Get profession snapshot
function PL.GetProfessionSnapshot(professionName)
    return professionSnapshots[professionName]
end

-- Get all profession snapshots
function PL.GetAllSnapshots()
    return professionSnapshots
end

-- Get list of profession snapshot names (for debugging)
function PL.GetSnapshotNames()
    local names = {}
    for name, _ in pairs(professionSnapshots) do
        table.insert(names, name)
    end
    return names
end

-- Force scan current profession (public API)
function PL.ForceScanCurrent()
    if GetTradeSkillLine and GetTradeSkillLine() then
        lastScanTime = 0 -- Reset cooldown
        return PL.ScanCurrentProfession()
    else
        print("|cffffff00CraftersBoard|r Please open a profession window first")
        return false
    end
end

-- Get profession summary for linking
function PL.GetProfessionSummary(professionName)
    local snapshot = professionSnapshots[professionName]
    if not snapshot then
        return nil
    end
    
    local summary = {
        name = snapshot.name,
        rank = snapshot.rank,
        maxRank = snapshot.maxRank,
        totalRecipes = #snapshot.recipes,
        categories = {},
        timestamp = snapshot.timestamp
    }
    
    -- Count recipes by category
    for category, indices in pairs(snapshot.categories) do
        summary.categories[category] = #indices
    end
    
    return summary
end

-- Initialize when CraftersBoard is ready
print("CraftersBoard: Checking if CB.isInitialized = " .. tostring(CB.isInitialized))
if CB.isInitialized then
    print("CraftersBoard: CB already initialized, calling PL.Initialize immediately")
    PL.Initialize()
else
    print("CraftersBoard: CB not yet initialized, waiting for ADDON_LOADED event")
    -- Wait for CraftersBoard to initialize
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        print("CraftersBoard: ADDON_LOADED event for " .. tostring(addonName) .. ", CB.isInitialized = " .. tostring(CB.isInitialized))
        if addonName == ADDON_NAME and CB.isInitialized then
            print("CraftersBoard: Conditions met, calling PL.Initialize")
            PL.Initialize()
            initFrame:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- Export module
CB.ProfessionLinks = PL

-- Data compression and chunking constants

-- Chunking state
local outgoingChunks = {} -- Data we're sending
local incomingChunks = {} -- Data we're receiving

-- Simple compression using string patterns (fallback if no compression lib)
function PL.SimpleCompress(data)
    if not data or data == "" then return data end
    
    -- Simple run-length encoding for repeated patterns
    local compressed = data
    
    -- Replace common patterns in profession data
    local patterns = {
        ["trivial"] = "T",
        ["easy"] = "E", 
        ["medium"] = "M",
        ["optimal"] = "O",
        ["available"] = "av",
        ["required"] = "req",
        ["category"] = "cat",
        ["reagents"] = "rg",
        ["recipes"] = "rc"
    }
    
    for full, short in pairs(patterns) do
        compressed = compressed:gsub(full, short)
    end
    
    return compressed
end

function PL.SimpleDecompress(data)
    if not data or data == "" then return data end
    
    -- Reverse the compression patterns
    local patterns = {
        ["T"] = "trivial",
        ["E"] = "easy",
        ["M"] = "medium", 
        ["O"] = "optimal",
        ["av"] = "available",
        ["req"] = "required",
        ["cat"] = "category",
        ["rg"] = "reagents",
        ["rc"] = "recipes"
    }
    
    local decompressed = data
    for short, full in pairs(patterns) do
        decompressed = decompressed:gsub(short, full)
    end
    
    return decompressed
end

-- Helper functions for network optimization serialization
function PL.DeserializeCapabilities(data)
    -- Simple JSON-like parser for capability data
    local version = data:match('"version":"([^"]+)"')
    local supportsSpellIDs = data:match('"supportsSpellIDs":(%a+)') == "true"
    local staticDBVersion = data:match('"staticDBVersion":"([^"]+)"')
    
    if version then
        return {
            version = version,
            supportsSpellIDs = supportsSpellIDs,
            staticDBVersion = staticDBVersion or "1.0.0"
        }
    end
    
    return nil
end

function PL.DeserializeOptimizedRequest(data)
    if not data or data == "" or data == "optimized_data_placeholder" then
        CB.Debug("DeserializeOptimizedRequest: Invalid or placeholder data")
        return false, nil
    end
    
    -- Format: reqId|profession|rank|maxRank|timestamp|spellId1,spellId2,spellId3...
    local parts = {}
    for part in string.gmatch(data, "([^|]+)") do
        table.insert(parts, part)
    end
    
    if #parts < 5 then
        CB.Debug("DeserializeOptimizedRequest: Invalid format, expected at least 5 parts, got " .. #parts)
        return false, nil
    end
    
    local reqId = parts[1] ~= "nil" and parts[1] or nil
    local profession = parts[2] or "Unknown"
    local rank = tonumber(parts[3]) or 0
    local maxRank = tonumber(parts[4]) or 0
    local timestamp = tonumber(parts[5]) or time()
    
    local spellIds = {}
    if parts[6] and parts[6] ~= "" then
        for spellIdStr in string.gmatch(parts[6], "([^,]+)") do
            local spellId = tonumber(spellIdStr)
            if spellId then
                table.insert(spellIds, spellId)
            end
        end
    end
    
    local result = {
        reqId = reqId,
        profession = profession,
        rank = rank,
        maxRank = maxRank,
        timestamp = timestamp,
        spellIds = spellIds
    }
    
    CB.Debug("DeserializeOptimizedRequest: Successfully deserialized " .. profession .. " with " .. #spellIds .. " spell IDs, reqId: " .. tostring(reqId))
    return true, result
end

function PL.SerializeOptimizedRequest(data)
    if not data then
        CB.Debug("SerializeOptimizedRequest: No data provided")
        return "optimized_data_placeholder"
    end
    
    local reqId = data.reqId or "nil"
    local profession = data.profession or "Unknown"
    local rank = data.rank or 0
    local maxRank = data.maxRank or 0
    local timestamp = data.timestamp or time()
    
    -- Convert spell IDs to comma-separated string
    local spellIdStr = ""
    if data.spellIds and #data.spellIds > 0 then
        local spellIdStrings = {}
        for i, spellId in ipairs(data.spellIds) do
            table.insert(spellIdStrings, tostring(spellId))
        end
        spellIdStr = table.concat(spellIdStrings, ",")
    end
    
    -- Format: reqId|profession|rank|maxRank|timestamp|spellId1,spellId2,spellId3...
    local result = tostring(reqId) .. "|" .. profession .. "|" .. rank .. "|" .. maxRank .. "|" .. timestamp .. "|" .. spellIdStr
    
    CB.Debug("SerializeOptimizedRequest: Serialized " .. profession .. " with " .. (#(data.spellIds or {})) .. " spell IDs, reqId: " .. tostring(reqId))
    return result
end

-- Serialize profession data to string (optimized for size)
function PL.SerializeProfessionData(snapshot)
    if not snapshot then return nil end
    
    CB.Debug("Serializing profession data: " .. tostring(snapshot.name))
    
    -- Use new dictionary-based compression for massive size reduction
    local compressedData
    if CB.DataDictionary and CB.DataDictionary.CompressProfessionData then
        compressedData = CB.DataDictionary.CompressProfessionData(snapshot)
        CB.Debug("Applied dictionary compression")
    else
        CB.Debug("DataDictionary not available, using fallback compression")
        -- Fallback to old method if dictionary isn't loaded
        compressedData = {
            n = snapshot.name,
            r = snapshot.rank,
            mr = snapshot.maxRank,
            t = snapshot.timestamp,
            rc = {}
        }
        
        for i, recipe in ipairs(snapshot.recipes) do
            local compactRecipe = {
                n = recipe.name,
                t = recipe.type,
                c = recipe.category
            }
            
            if recipe.reagents and #recipe.reagents > 0 then
                compactRecipe.rg = {}
                for j, reagent in ipairs(recipe.reagents) do
                    table.insert(compactRecipe.rg, {
                        n = reagent.name,
                        r = reagent.required,
                        a = reagent.available
                    })
                end
            end
            
            table.insert(compressedData.rc, compactRecipe)
        end
    end
    
    CB.Debug("Prepared " .. #compressedData.rc .. " recipes for serialization")
    
    -- Convert to string (simple table serialization)
    local serialized = PL.TableToString(compressedData)
    
    if not serialized then
        CB.Debug("Failed to serialize data to string")
        return nil
    end
    
    local originalSize = string.len(serialized)
    
    -- Apply standard compression on top of dictionary compression
    if COMPRESSION_ENABLED then
        local compressed = PL.SimpleCompress(serialized)
        if compressed and string.len(compressed) < originalSize then
            serialized = compressed
            CB.Debug("Applied secondary compression: " .. originalSize .. " -> " .. string.len(serialized) .. " bytes")
        else
            CB.Debug("Secondary compression failed or not beneficial, using dictionary-compressed data")
        end
    end
    
    CB.Debug("Final serialized profession data: " .. string.len(serialized) .. " bytes")
    return serialized
end

-- Deserialize profession data from string (using dictionary decompression)
function PL.DeserializeProfessionData(serializedData)
    if not serializedData or serializedData == "" then return nil end
    
    local data
    
    CB.Debug("Deserializing profession data: " .. string.len(serializedData) .. " bytes")
    
    -- Decompress standard compression first if needed
    if COMPRESSION_ENABLED then
        local decompressed = PL.SimpleDecompress(serializedData)
        if decompressed then
            serializedData = decompressed
            CB.Debug("Applied standard decompression")
        else
            CB.Debug("Standard decompression failed, trying uncompressed data")
        end
    end
    
    -- Parse string back to table
    data = PL.StringToTable(serializedData)
    if not data then
        CB.Debug("Failed to deserialize profession data")
        return nil
    end
    
    -- Use dictionary decompression if available
    if CB.DataDictionary and CB.DataDictionary.DecompressProfessionData then
        local snapshot = CB.DataDictionary.DecompressProfessionData(data)
        if snapshot then
            CB.Debug("Applied dictionary decompression successfully")
            return snapshot
        else
            CB.Debug("Dictionary decompression failed, using fallback")
        end
    end
    
    -- Fallback decompression method (for old data or if dictionary unavailable)
    CB.Debug("Using fallback decompression method")
    local snapshot = {
        name = data.n,
        rank = data.r,
        maxRank = data.mr,
        timestamp = data.t,
        recipes = {},
        categories = {}
    }
    
    -- Expand recipe data with essential fields only
    for i, compactRecipe in ipairs(data.rc or {}) do
        local recipe = {
            name = compactRecipe.n or compactRecipe.id, -- Handle both old and new formats
            type = compactRecipe.t,
            category = compactRecipe.c,
            reagents = {}
        }
        
        -- Expand reagents with essential data only
        if compactRecipe.rg then
            for j, reagent in ipairs(compactRecipe.rg) do
                table.insert(recipe.reagents, {
                    name = reagent.n,
                    required = reagent.r,
                    available = reagent.a
                })
            end
        end
        
        table.insert(snapshot.recipes, recipe)
        
        -- Rebuild categories
        local category = recipe.category or "Other"
        if not snapshot.categories[category] then
            snapshot.categories[category] = {}
        end
        table.insert(snapshot.categories[category], recipe)
    end
    
    CB.Debug("Fallback decompression completed: " .. #snapshot.recipes .. " recipes")
    return snapshot
end

-- Simple table to string serialization (basic implementation)
function PL.TableToString(tbl)
    if not tbl then return "nil" end
    if type(tbl) ~= "table" then return tostring(tbl) end
    
    local parts = {}
    table.insert(parts, "{")
    
    for k, v in pairs(tbl) do
        local keyStr = type(k) == "string" and string.format("[%q]", k) or string.format("[%s]", tostring(k))
        local valueStr
        
        if type(v) == "table" then
            valueStr = PL.TableToString(v)
        elseif type(v) == "string" then
            valueStr = string.format("%q", v)
        else
            valueStr = tostring(v)
        end
        
        table.insert(parts, keyStr .. "=" .. valueStr .. ",")
    end
    
    table.insert(parts, "}")
    return table.concat(parts)
end

-- Simple string to table deserialization
function PL.StringToTable(str)
    if not str or str == "nil" then return nil end
    
    CB.Debug("StringToTable: Attempting to parse " .. #str .. " byte string")
    CB.Debug("String preview: " .. string.sub(str, 1, 200) .. (#str > 200 and "..." or ""))
    
    -- Use loadstring to parse the table (be careful with security)
    local fn, err = loadstring("return " .. str)
    if not fn then
        CB.Debug("CRITICAL ERROR: Failed to parse table string: " .. (err or "unknown error"))
        CB.Debug("This might indicate a WoW loadstring restriction or malformed data")
        return nil
    end
    
    local ok, result = pcall(fn)
    if not ok then
        CB.Debug("CRITICAL ERROR: Failed to execute table string: " .. (result or "unknown error"))
        return nil
    end
    
    CB.Debug("StringToTable: Successfully parsed table")
    return result
end

-- Split data into chunks
function PL.CreateChunks(data, maxSize)
    if not data then return {} end
    
    local chunks = {}
    local dataLen = string.len(data)
    
    for i = 1, dataLen, maxSize do
        local chunk = string.sub(data, i, i + maxSize - 1)
        table.insert(chunks, chunk)
    end
    
    CB.Debug("Split " .. dataLen .. " bytes into " .. #chunks .. " chunks")
    return chunks
end

-- Send chunked data with throttling to prevent disconnection
function PL.SendChunkedData(targetPlayer, reqId, data)
    CB.Debug("===== SENDING CHUNKED DATA =====")
    CB.Debug("SendChunkedData called - target: " .. targetPlayer .. ", reqId: " .. reqId .. ", data size: " .. #data .. " bytes")
    
    local chunks = PL.CreateChunks(data, MAX_ADDON_MESSAGE_SIZE - 50) -- Leave room for headers
    
    if #chunks == 0 then
        CB.Debug("CRITICAL ERROR: No data to send - CreateChunks returned empty")
        return false
    end
    
    CB.Debug("Created " .. #chunks .. " chunks from " .. #data .. " bytes (max chunk size: " .. (MAX_ADDON_MESSAGE_SIZE - 50) .. ")")
    
    -- Check if we're sending too much data
    if #chunks > MAX_CHUNKS_PER_REQUEST then
        CB.Debug("Data too large: " .. #chunks .. " chunks (max: " .. MAX_CHUNKS_PER_REQUEST .. ")")
        local response = string.format("DATA:%s:1/1:ERROR_DATA_TOO_LARGE", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", targetPlayer)
        return false
    end
    
    -- Store outgoing chunks for potential resend
    outgoingChunks[reqId] = {
        target = targetPlayer,
        chunks = chunks,
        timestamp = time()
    }
    
    CB.Debug("Sending " .. #chunks .. " chunks to " .. targetPlayer .. " with throttling")
    
    -- Send chunks with delays to prevent flooding/disconnection
    for i, chunk in ipairs(chunks) do
        local message = string.format("DATA:%s:%d/%d:%s", reqId, i, #chunks, chunk)
        
        -- Use timer for delayed sending to prevent flooding
        C_Timer.After((i - 1) * CHUNK_SEND_DELAY, function()
            local success = SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "WHISPER", targetPlayer)
            if success then
                CB.Debug("Sent chunk " .. i .. "/" .. #chunks .. " to " .. targetPlayer)
            else
                CB.Debug("Failed to send chunk " .. i .. "/" .. #chunks .. " to " .. targetPlayer)
            end
        end)
    end
    
    return true
end

-- Receive and reassemble chunked data
function PL.ReceiveChunk(sender, reqId, chunkInfo, chunkData)
    local current, total = chunkInfo:match("(%d+)/(%d+)")
    current = tonumber(current)
    total = tonumber(total)
    
    if not current or not total then
        CB.Debug("Invalid chunk info: " .. chunkInfo)
        return false
    end
    
    -- Initialize receiving state if needed
    if not incomingChunks[reqId] then
        incomingChunks[reqId] = {
            sender = sender,
            chunks = {},
            total = total,
            received = 0,
            timestamp = time()
        }
    end
    
    local incoming = incomingChunks[reqId]
    
    -- Store the chunk
    if not incoming.chunks[current] then
        incoming.chunks[current] = chunkData
        incoming.received = incoming.received + 1
        CB.Debug("Received chunk " .. current .. "/" .. total .. " from " .. sender)
    end
    
    -- Check if we have all chunks
    if incoming.received >= incoming.total then
        CB.Debug("All chunks received, reassembling data")
        
        -- Reassemble data
        local parts = {}
        for i = 1, incoming.total do
            if incoming.chunks[i] then
                table.insert(parts, incoming.chunks[i])
            else
                CB.Debug("Missing chunk " .. i .. ", data incomplete")
                return false
            end
        end
        
        local fullData = table.concat(parts)
        
        -- Clean up
        incomingChunks[reqId] = nil
        
        -- Process the complete data
        PL.ProcessReceivedProfessionData(sender, reqId, fullData)
        return true
    end
    
    return false -- Still waiting for more chunks
end

-- Process complete profession data
function PL.ProcessReceivedProfessionData(sender, reqId, serializedData)
    CB.Debug("ProcessReceivedProfessionData called:")
    CB.Debug("  sender: " .. tostring(sender))
    CB.Debug("  reqId: " .. tostring(reqId))
    CB.Debug("  data size: " .. string.len(serializedData) .. " bytes")
    CB.Debug("Processing complete profession data from " .. sender .. " (size: " .. string.len(serializedData) .. " bytes)")
    
    local snapshot = PL.DeserializeProfessionData(serializedData)
    if not snapshot then
        CB.Debug("Failed to deserialize profession data")
        print("|cffffff00CraftersBoard|r Failed to decode profession data from " .. sender)
        PL.ShowViewerError(sender, "Unknown", "Failed to decode profession data")
        return
    end
    
    CB.Debug("Deserialized profession data:")
    CB.Debug("  name: " .. tostring(snapshot.name))
    CB.Debug("  recipes: " .. tostring(snapshot.recipes and "table" or "nil"))
    CB.Debug("  recipes count: " .. tostring(snapshot.recipes and #snapshot.recipes or "nil"))
    CB.Debug("  rank: " .. tostring(snapshot.rank))
    CB.Debug("  maxRank: " .. tostring(snapshot.maxRank))
    
    -- Validate essential data fields
    if not snapshot.name or snapshot.name == "" then
        CB.Debug("Invalid profession data: missing name")
        print("|cffffff00CraftersBoard|r Invalid profession data from " .. sender .. " - missing profession name")
        PL.ShowViewerError(sender, "Unknown", "Invalid profession data - missing name")
        return
    end
    
    if not snapshot.recipes then
        CB.Debug("Invalid profession data: missing recipes table")
        print("|cffffff00CraftersBoard|r Invalid profession data from " .. sender .. " - missing recipes")
        PL.ShowViewerError(sender, snapshot.name, "Invalid profession data - missing recipes")
        return
    end
    
    if #snapshot.recipes == 0 then
        CB.Debug("Warning: Received profession data with no recipes")
        print("|cffffff00CraftersBoard|r " .. sender .. "'s " .. snapshot.name .. " has no recipes")
    else
        print("|cffffff00CraftersBoard|r Received " .. sender .. "'s " .. snapshot.name .. " (" .. #snapshot.recipes .. " recipes)")
    end
    
    -- Cache the profession data using normalized player name (without realm)
    local normalizedSender = NormalizePlayerName(sender)
    PL.CacheProfessionData(normalizedSender, snapshot.name, snapshot)
    
    CB.Debug("Cached profession data for normalized name: " .. normalizedSender)
    
    -- Check if this was a request triggered by clicking a profession link
    local viewRequest = pendingViewRequests[reqId]
    if viewRequest then
        -- This was from clicking a profession link - show the viewer
        CB.Debug("Opening profession viewer for " .. viewRequest.playerName .. "'s " .. viewRequest.professionName)
        PL.ShowProfessionData(normalizedSender, snapshot.name, snapshot)
        
        -- Clean up the view request
        pendingViewRequests[reqId] = nil
    else
        -- This was a regular request - show in profession viewer as before
        PL.ShowProfessionData(normalizedSender, snapshot.name, snapshot)
    end
    
    -- Clean up pending request
    pendingRequests[reqId] = nil
    
    CB.Debug("Successfully processed and displayed " .. snapshot.name .. " data from " .. sender)
end

-- ================================
-- NETWORK OPTIMIZATION FUNCTIONS
-- ================================

-- Check if player supports optimized spell ID protocol
function PL.SupportsOptimizedProtocol(playerName)
    if not playerCapabilities[playerName] then
        return false
    end
    return playerCapabilities[playerName].supportsSpellIDs == true
end

-- Resolve spell ID to recipe name using static database
function PL.ResolveRecipeFromSpellID(spellID)
    CB.Debug("ResolveRecipeFromSpellID: Looking up spell ID " .. tostring(spellID))
    
    -- Check static database first (Data/Vanilla.lua)
    if CraftersBoard_VanillaData and CraftersBoard_VanillaData.SPELL_TO_RECIPE then
        CB.Debug("Static database available, checking spell " .. spellID)
        
        -- Debug: Show a few sample entries from the database
        local count = 0
        local samples = {}
        for sampleId, sampleName in pairs(CraftersBoard_VanillaData.SPELL_TO_RECIPE) do
            count = count + 1
            if count <= 3 then
                table.insert(samples, sampleId .. "=" .. sampleName)
            end
        end
        CB.Debug("Database has " .. count .. " entries. Samples: " .. table.concat(samples, ", "))
        
        -- Convert spellID to number if it's a string
        local lookupId = tonumber(spellID)
        if not lookupId then
            CB.Debug("ERROR: Invalid spell ID (not a number): " .. tostring(spellID))
            return nil
        end
        
        CB.Debug("Looking up numeric spell ID: " .. lookupId)
        
        if CraftersBoard_VanillaData.SPELL_TO_RECIPE[lookupId] then
            local recipeName = CraftersBoard_VanillaData.SPELL_TO_RECIPE[lookupId]
            CB.Debug("✓ Found in static database: " .. recipeName)
            return {
                name = recipeName,
                spellID = lookupId,
                source = "static"
            }
        else
            CB.Debug("✗ Spell " .. lookupId .. " not found in static database")
            
            -- Debug: Check if similar IDs exist nearby
            local found = false
            for testId = lookupId - 2, lookupId + 2 do
                if CraftersBoard_VanillaData.SPELL_TO_RECIPE[testId] then
                    CB.Debug("  Near miss: " .. testId .. " = " .. CraftersBoard_VanillaData.SPELL_TO_RECIPE[testId])
                    found = true
                end
            end
            if not found then
                CB.Debug("  No similar spell IDs found nearby")
            end
        end
    else
        CB.Debug("✗ Static database not available!")
    end
    
    -- Fallback to live API for missing recipes
    if GetSpellInfo then
        local spellName = GetSpellInfo(spellID)
        if spellName then
            CB.Debug("✓ Found via live API: " .. spellName)
            return {
                name = spellName,
                spellID = spellID,
                source = "live"
            }
        else
            CB.Debug("✗ Spell " .. spellID .. " not found via live API")
        end
    else
        CB.Debug("✗ GetSpellInfo not available")
    end
    
    CB.Debug("✗ Could not resolve spell ID " .. spellID)
    return nil
end

-- Extract spell IDs from recipe data
function PL.ExtractSpellIDs(recipes)
    local spellIds = {}
    CB.Debug("ExtractSpellIDs: Processing " .. #(recipes or {}) .. " recipes")
    
    for i, recipe in pairs(recipes or {}) do
        CB.Debug("Recipe " .. i .. ": " .. (recipe.name or "unnamed") .. " (spellID: " .. tostring(recipe.spellID) .. ", type: " .. type(recipe.spellID) .. ")")
        if recipe.spellID and type(recipe.spellID) == "number" then
            table.insert(spellIds, recipe.spellID)
        end
    end
    
    CB.Debug("ExtractSpellIDs: Found " .. #spellIds .. " valid spell IDs")
    return spellIds
end

-- Send optimized recipe data (spell IDs only)
function PL.SendOptimizedRecipeData(targetPlayer, reqId, professionData)
    local spellIds = PL.ExtractSpellIDs(professionData.recipes)
    
    if #spellIds == 0 then
        CB.Debug("No spell IDs found for optimized transfer")
        CB.Debug("Recipe count: " .. #(professionData.recipes or {}))
        -- Debug first few recipes to see their structure
        for i = 1, math.min(3, #(professionData.recipes or {})) do
            local recipe = professionData.recipes[i]
            CB.Debug("Recipe " .. i .. ": " .. (recipe.name or "unnamed") .. " (spellID: " .. tostring(recipe.spellID) .. ")")
        end
        return false
    end
    
    CB.Debug("Extracted " .. #spellIds .. " spell IDs for optimized transfer")
    
    -- Debug spell IDs being sent
    CB.Debug("Spell IDs to send: " .. table.concat(spellIds, ", "))
    
    local optimizedData = {
        reqId = reqId,
        profession = professionData.name,
        rank = professionData.rank,
        maxRank = professionData.maxRank,
        timestamp = professionData.timestamp,
        spellIds = spellIds,
        categories = professionData.categories or {},
        optimized = true -- Flag to indicate this is optimized data
    }
    
    local serialized = PL.SerializeOptimizedRequest(optimizedData)
    local compressed = PL.SimpleCompress(serialized)
    
    -- Log transfer stats (simplified for now)
    local originalSize = 50000 -- Assume average original size
    local optimizedSize = #compressed
    local savings = originalSize - optimizedSize
    local reduction = math.floor((savings / originalSize) * 100)
    
    table.insert(transferStats, {
        type = "optimized_send",
        originalSize = originalSize,
        optimizedSize = optimizedSize,
        reduction = reduction,
        timestamp = time(),
        target = targetPlayer
    })
    
    CB.Debug(string.format("Optimized transfer: %d bytes -> %d bytes (%.1f%% reduction)", 
          originalSize, optimizedSize, reduction))
    
    -- Send as single message (no chunking needed due to small size)
    local message = string.format("OPTIMIZED_DATA:%s", compressed)
    return SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "WHISPER", targetPlayer)
end

-- Send capability announcement
local function AnnounceCapabilities()
    local capabilities = {
        version = CB.VERSION or "1.0.0",
        supportsSpellIDs = true,
        staticDBVersion = (CB.VanillaData and CB.VanillaData.VERSION) or "1.0.0"
    }
    
    -- Simple JSON-like serialization for capability data
    local serialized = string.format('{"version":"%s","supportsSpellIDs":%s,"staticDBVersion":"%s"}',
        capabilities.version,
        tostring(capabilities.supportsSpellIDs),
        capabilities.staticDBVersion
    )
    local message = string.format("CAPABILITIES:%s", serialized)
    SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "GUILD")
    SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "RAID")
    SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "PARTY")
end

-- ================================
-- LOADING SPINNER FUNCTIONS
-- ================================

-- Create animated loading spinner
-- Loading Spinner System
local loadingSpinners = {}

function PL.CreateLoadingSpinner(parent, size)
    size = size or 32
    
    local spinner = CreateFrame("Frame", nil, parent)
    spinner:SetSize(size, size)
    spinner:SetFrameLevel(parent:GetFrameLevel() + 10)
    
    -- Create spinning texture
    local texture = spinner:CreateTexture(nil, "OVERLAY")
    texture:SetSize(size, size)
    texture:SetPoint("CENTER")
    texture:SetTexture("Interface\\AddOns\\CraftersBoard\\Textures\\star_filled.tga")
    texture:SetVertexColor(1, 1, 0, 0.8) -- Yellow glow
    
    -- Rotation animation
    local rotation = 0
    local animFrame = CreateFrame("Frame")
    animFrame:SetScript("OnUpdate", function(self, elapsed)
        if not spinner:IsVisible() then return end
        rotation = rotation + (elapsed * 360) -- Full rotation per second
        if rotation >= 360 then rotation = rotation - 360 end
        texture:SetRotation(math.rad(rotation))
    end)
    
    spinner.texture = texture
    spinner.animFrame = animFrame
    
    -- Cleanup function
    spinner.Stop = function()
        animFrame:SetScript("OnUpdate", nil)
        spinner:Hide()
    end
    
    return spinner
end

-- Show loading overlay on profession viewer
-- Show loading state for profession viewer
function PL.ShowViewerLoading(player, professionName)
    -- Create viewer if it doesn't exist
    if not professionViewerFrame then
        CB.Debug("ShowViewerLoading: Creating profession viewer frame")
        PL.CreateProfessionViewer()
    end
    
    if not professionViewerFrame then
        CB.Debug("ShowViewerLoading: Failed to create profession viewer frame")
        return
    end
    
    local message = "Loading " .. professionName .. " data from " .. player .. "..."
    CB.Debug("ShowViewerLoading: " .. message)
    
    -- Show the viewer frame first
    professionViewerFrame:Show()
    
    -- Use the existing loading spinner function
    PL.ShowLoadingSpinner(professionViewerFrame, message)
end

function PL.ShowLoadingSpinner(frame, message)
    if loadingSpinners[frame] then
        return loadingSpinners[frame] -- Already showing
    end
    
    -- Create overlay
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 5)
    overlay:EnableMouse(true) -- Block interaction
    
    -- Semi-transparent background
    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.7)
    
    -- Loading spinner
    local spinner = PL.CreateLoadingSpinner(overlay, 48)
    spinner:SetPoint("CENTER", overlay, "CENTER", 0, 20)
    
    -- Loading text
    local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", overlay, "CENTER", 0, -20)
    text:SetText(message or "Loading...")
    text:SetTextColor(1, 1, 1)
    
    overlay.spinner = spinner
    overlay.text = text
    
    -- Store reference
    loadingSpinners[frame] = overlay
    
    overlay:Show()
    spinner:Show()
    
    return overlay
end

-- Hide loading spinner
function PL.HideLoadingSpinner(frame)
    local overlay = loadingSpinners[frame]
    if overlay then
        if overlay.spinner then
            overlay.spinner:Stop()
        end
        overlay:Hide()
        overlay:SetParent(nil)
        loadingSpinners[frame] = nil
    end
end

-- UI Viewer for profession data
local professionViewerFrame = nil
local viewerScrollFrame = nil
local viewerContent = nil

-- Create the profession viewer window inspired by original WoW profession UI
function PL.CreateProfessionViewer()
    if professionViewerFrame then return professionViewerFrame end
    
    CB.Debug("Creating profession viewer inspired by original WoW profession UI...")
    
    -- Create main frame with original profession window proportions
    local frame = CreateFrame("Frame", "CraftersBoardProfessionViewer", UIParent)
    frame:SetSize(700, 500)  -- More compact like original tradeskill window
    frame:SetPoint("CENTER")
    frame:Hide()
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    
    -- Add to special frames for ESC key handling
    if UISpecialFrames then
        table.insert(UISpecialFrames, frame:GetName())
    end
    
    -- Apply CraftersBoard backdrop styling
    local theme = CB.getThemeColors()
    CB.UI.SetBackdropCompat(frame, {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    CB.UI.SetBackdropColorCompat(frame, theme.primary[1], theme.primary[2], theme.primary[3], 0.95)
    CB.UI.SetBackdropBorderColorCompat(frame, theme.border[1], theme.border[2], theme.border[3], 1.0)
    
    -- Simple title bar like original profession window
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    
    -- Title text
    frame.TitleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    -- Create profession icon for title bar
    if not frame.ProfessionIcon then
        frame.ProfessionIcon = titleBar:CreateTexture(nil, "ARTWORK")
        frame.ProfessionIcon:SetSize(20, 20)
        frame.ProfessionIcon:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    end
    
    -- Update title text position to make room for icon
    frame.TitleText:SetPoint("LEFT", frame.ProfessionIcon, "RIGHT", 8, 0)
    frame.TitleText:SetText("Profession Viewer")
    frame.TitleText:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
    
    -- Close button (standard WoW style)
    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Category Filter Dropdown (proper dropdown UI component)
    local dropdownFrame = CreateFrame("Frame", nil, titleBar, "UIDropDownMenuTemplate")
    dropdownFrame:SetPoint("RIGHT", frame.CloseButton, "LEFT", -10, 0)
    
    -- Apply theme styling to dropdown
    local theme = CB.getThemeColors()
    
    -- Store reference to filter elements
    frame.categoryFilter = {
        dropdown = dropdownFrame,
        currentCategory = "all"
    }
    
    -- Initialize dropdown
    UIDropDownMenu_SetWidth(dropdownFrame, 120)
    UIDropDownMenu_SetText(dropdownFrame, "All Categories")
    
    -- Dropdown initialization function
    local function InitializeDropdown(self, level)
        if not frame.currentProfessionData then return end
        
        local info = UIDropDownMenu_CreateInfo()
        
        -- Add "All Categories" option
        info.text = "All Categories"
        info.value = "all"
        info.func = function()
            PL.SetCategoryFilter(frame, "all", "All Categories")
        end
        info.checked = (frame.categoryFilter.currentCategory == "all")
        UIDropDownMenu_AddButton(info)
        
        -- Add category options
        if frame.currentProfessionData.categories then
            for categoryName, recipeIndices in pairs(frame.currentProfessionData.categories) do
                if recipeIndices and #recipeIndices > 0 then
                    info = UIDropDownMenu_CreateInfo()
                    info.text = categoryName .. " (" .. #recipeIndices .. ")"
                    info.value = categoryName
                    info.func = function()
                        PL.SetCategoryFilter(frame, categoryName, categoryName)
                    end
                    info.checked = (frame.categoryFilter.currentCategory == categoryName)
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end
    
    UIDropDownMenu_Initialize(dropdownFrame, InitializeDropdown)
    
    -- Single content area like original profession window (no tabs)
    -- Split into left panel (recipes) and right panel (recipe details) with card styling
    
    -- Create recipe list card container
    local leftCardContainer = CreateFrame("Frame", nil, frame)
    leftCardContainer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 12, -8)
    leftCardContainer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    leftCardContainer:SetWidth(360)  -- Increased width for card padding
    
    -- Apply card backdrop styling to left container
    CB.UI.SetBackdropCompat(leftCardContainer, {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    CB.UI.SetBackdropColorCompat(leftCardContainer, theme.secondary[1] * 0.3, theme.secondary[2] * 0.3, theme.secondary[3] * 0.3, 0.95)
    CB.UI.SetBackdropBorderColorCompat(leftCardContainer, theme.border[1], theme.border[2], theme.border[3], 0.8)
    
    -- Create recipe list header
    local leftCardHeader = leftCardContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    leftCardHeader:SetPoint("TOPLEFT", leftCardContainer, "TOPLEFT", 12, -12)
    leftCardHeader:SetText("Recipe List")
    leftCardHeader:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
    
    -- Create scroll frame inside the card container with proper padding
    local leftPanel = CreateFrame("ScrollFrame", nil, leftCardContainer)
    leftPanel:SetPoint("TOPLEFT", leftCardContainer, "TOPLEFT", 8, -35)
    leftPanel:SetPoint("BOTTOMRIGHT", leftCardContainer, "BOTTOMRIGHT", -8, 8)
    
    -- Create recipe details card container
    local rightCardContainer = CreateFrame("Frame", nil, frame)
    rightCardContainer:SetPoint("TOPLEFT", leftCardContainer, "TOPRIGHT", 8, 0)
    rightCardContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    
    -- Apply card backdrop styling to right container
    CB.UI.SetBackdropCompat(rightCardContainer, {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    CB.UI.SetBackdropColorCompat(rightCardContainer, theme.secondary[1] * 0.3, theme.secondary[2] * 0.3, theme.secondary[3] * 0.3, 0.95)
    CB.UI.SetBackdropBorderColorCompat(rightCardContainer, theme.border[1], theme.border[2], theme.border[3], 0.8)
    
    -- Create recipe details header
    local rightCardHeader = rightCardContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rightCardHeader:SetPoint("TOPLEFT", rightCardContainer, "TOPLEFT", 12, -12)
    rightCardHeader:SetText("Recipe Details")
    rightCardHeader:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
    
    -- Create details panel inside the card container with proper padding
    local rightPanel = CreateFrame("Frame", nil, rightCardContainer)
    rightPanel:SetPoint("TOPLEFT", rightCardContainer, "TOPLEFT", 8, -35)
    rightPanel:SetPoint("BOTTOMRIGHT", rightCardContainer, "BOTTOMRIGHT", -8, 8)
    
    -- Remove old separator line since we have card containers now
    
    -- Scroll child for left panel content with additional padding for card design
    local scrollChild = CreateFrame("Frame", nil, leftPanel)
    scrollChild:SetWidth(leftPanel:GetWidth() - 20)
    leftPanel:SetScrollChild(scrollChild)
    
    -- Scroll bar for left panel - positioned relative to card container
    local scrollBar = CreateFrame("Slider", nil, leftCardContainer)
    scrollBar:SetPoint("TOPRIGHT", leftCardContainer, "TOPRIGHT", -6, -40)
    scrollBar:SetPoint("BOTTOMRIGHT", leftCardContainer, "BOTTOMRIGHT", -6, 16)
    scrollBar:SetWidth(16)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValue(0)
    
    -- Scroll bar background with card-appropriate styling
    local scrollBg = scrollBar:CreateTexture(nil, "BACKGROUND")
    scrollBg:SetAllPoints()
    scrollBg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    scrollBg:SetVertexColor(theme.secondary[1] * 0.6, theme.secondary[2] * 0.6, theme.secondary[3] * 0.6, 0.8)
    
    scrollBar:SetScript("OnValueChanged", function(self, value)
        leftPanel:SetVerticalScroll(value)
    end)
    
    -- Mouse wheel scrolling for left panel
    leftPanel:EnableMouseWheel(true)
    leftPanel:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = current - (delta * 30)
        
        if newScroll < 0 then
            newScroll = 0
        elseif newScroll > maxScroll then
            newScroll = maxScroll
        end
        
        scrollBar:SetValue(newScroll)
    end)
    
    -- Update scroll range function
    local function UpdateScrollRange()
        local contentHeight = scrollChild:GetHeight()
        local frameHeight = leftPanel:GetHeight()
        local maxScroll = math.max(0, contentHeight - frameHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
    end
    
    scrollChild:SetScript("OnSizeChanged", UpdateScrollRange)
    leftPanel:SetScript("OnSizeChanged", UpdateScrollRange)
    
    
    -- Store references for content updates
    frame.contentFrame = leftPanel
    frame.scrollChild = scrollChild
    frame.rightPanel = rightPanel
    frame.UpdateScrollRange = UpdateScrollRange
    
    -- Create the unified profession display function
    frame.DisplayProfessionData = function(self, professionData)
        -- Store profession data for filtering
        self.currentProfessionData = professionData
        
        -- Reset filter to "all" when new data is loaded
        if self.categoryFilter then
            self.categoryFilter.currentCategory = "all"
            UIDropDownMenu_SetText(self.categoryFilter.dropdown, "All Categories")
        end
        
        -- Initialize right panel with placeholder
        if self.rightPanel then
            PL.DisplayRecipeDetails(self.rightPanel, nil, theme)
        end
        
        -- Get current filter (default to "all")
        local categoryFilter = self.categoryFilter and self.categoryFilter.currentCategory or "all"
        
        PL.CreateUnifiedProfessionDisplay(self.scrollChild, professionData, theme, categoryFilter)
        self.UpdateScrollRange()
    end
    
    professionViewerFrame = frame
    return frame
end

-- Helper function to get difficulty color from recipe data
local function GetRecipeDifficultyColor(difficulty)
    if not difficulty then return "grey" end
    
    if type(difficulty) == "table" then
        -- New format: table with color and text fields
        return difficulty.color or difficulty.text or "grey"
    else
        -- Old format: simple string
        return tostring(difficulty)
    end
end

-- Helper function to set text color based on difficulty
local function SetDifficultyTextColor(fontString, difficulty)
    local difficultyColor = GetRecipeDifficultyColor(difficulty)
    
    if difficultyColor == "orange" then
        fontString:SetTextColor(1, 0.5, 0)
    elseif difficultyColor == "yellow" then
        fontString:SetTextColor(1, 1, 0)
    elseif difficultyColor == "green" then
        fontString:SetTextColor(0, 1, 0)
    elseif difficultyColor == "trivial" or difficultyColor == "grey" or difficultyColor == "gray" then
        fontString:SetTextColor(0.5, 0.5, 0.5)
    else
        fontString:SetTextColor(0.5, 0.5, 0.5)
    end
end

-- Display detailed recipe information in the right panel with card-style sections
function PL.DisplayRecipeDetails(rightPanel, recipe, theme)
    -- Clear existing content in right panel with comprehensive approach
    CB.Debug("DisplayRecipeDetails: Clearing right panel")
    
    -- Initialize display elements tracking if not exists
    if not rightPanel.displayElements then
        rightPanel.displayElements = {}
    end
    
    -- Method 1: Hide and reparent all children
    local childCount = rightPanel:GetNumChildren()
    CB.Debug("Clearing " .. childCount .. " existing children from right panel")
    
    for i = 1, childCount do
        local child = select(i, rightPanel:GetChildren())
        if child then
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    -- Method 2: Clear tracked display elements
    if rightPanel.displayElements then
        CB.Debug("Clearing " .. #rightPanel.displayElements .. " tracked elements from right panel")
        for _, element in ipairs(rightPanel.displayElements) do
            if element then
                element:Hide()
                element:SetParent(nil)
            end
        end
    end
    rightPanel.displayElements = {}
    
    -- Method 3: Force a layout update
    rightPanel:SetHeight(rightPanel:GetHeight())
    
    CB.Debug("After clearing, right panel children count: " .. rightPanel:GetNumChildren())
    
    if not recipe then
        -- Show placeholder text when no recipe is selected
        local placeholderCard = CreateFrame("Frame", nil, rightPanel)
        placeholderCard:SetSize(rightPanel:GetWidth() - 40, 100)
        placeholderCard:SetPoint("CENTER", rightPanel, "CENTER", 0, 0)
        
        -- Apply card styling to placeholder
        CB.UI.SetBackdropCompat(placeholderCard, {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        CB.UI.SetBackdropColorCompat(placeholderCard, theme.secondary[1] * 0.2, theme.secondary[2] * 0.2, theme.secondary[3] * 0.2, 0.8)
        CB.UI.SetBackdropBorderColorCompat(placeholderCard, theme.border[1] * 0.4, theme.border[2] * 0.4, theme.border[3] * 0.4, 0.6)
        
        local placeholderText = placeholderCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        placeholderText:SetPoint("CENTER", placeholderCard, "CENTER", 0, 0)
        placeholderText:SetText("Select a recipe to view details")
        placeholderText:SetTextColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
        
        -- Track this element
        table.insert(rightPanel.displayElements, placeholderCard)
        return
    end
    
    local yOffset = -10
    
    -- Recipe Information Card
    local infoCard = CreateFrame("Frame", nil, rightPanel)
    infoCard:SetSize(rightPanel:GetWidth() - 20, 120)
    infoCard:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, yOffset)
    
    -- Apply card styling
    CB.UI.SetBackdropCompat(infoCard, {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    CB.UI.SetBackdropColorCompat(infoCard, theme.secondary[1] * 0.2, theme.secondary[2] * 0.2, theme.secondary[3] * 0.2, 0.8)
    CB.UI.SetBackdropBorderColorCompat(infoCard, theme.border[1] * 0.4, theme.border[2] * 0.4, theme.border[3] * 0.4, 0.6)
    
    table.insert(rightPanel.displayElements, infoCard)
    
    -- Recipe Name Header
    local nameHeader = infoCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nameHeader:SetPoint("TOPLEFT", infoCard, "TOPLEFT", 12, -12)
    nameHeader:SetText(recipe.name or "Unknown Recipe")
    nameHeader:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
    
    -- Recipe Level/Difficulty Info
    local infoOffset = -35
    if recipe.level and recipe.maxLevel then
        local levelText = infoCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelText:SetPoint("TOPLEFT", infoCard, "TOPLEFT", 12, infoOffset)
        levelText:SetText("Required Level: " .. recipe.level .. " - " .. recipe.maxLevel)
        levelText:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
        infoOffset = infoOffset - 20
    end
    
    -- Difficulty Color
    if recipe.difficulty then
        local difficultyText = infoCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        difficultyText:SetPoint("TOPLEFT", infoCard, "TOPLEFT", 12, infoOffset)
        
        -- Handle both string and table formats for difficulty
        local difficultyValue = recipe.difficulty
        local difficultyDisplay = ""
        
        if type(difficultyValue) == "table" then
            -- New format: table with color and text fields
            difficultyDisplay = difficultyValue.text or difficultyValue.color or "unknown"
        else
            -- Old format: simple string
            difficultyDisplay = tostring(difficultyValue)
        end
        
        difficultyText:SetText("Difficulty: " .. difficultyDisplay:upper())
        SetDifficultyTextColor(difficultyText, recipe.difficulty)
        infoOffset = infoOffset - 20
    end
    
    yOffset = yOffset - 140
    
    -- Materials Card
    if recipe.reagents and #recipe.reagents > 0 then
        local materialsCard = CreateFrame("Frame", nil, rightPanel)
        local cardHeight = 50 + (#recipe.reagents * 18)
        materialsCard:SetSize(rightPanel:GetWidth() - 20, cardHeight)
        materialsCard:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, yOffset)
        
        -- Apply card styling
        CB.UI.SetBackdropCompat(materialsCard, {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        CB.UI.SetBackdropColorCompat(materialsCard, theme.secondary[1] * 0.2, theme.secondary[2] * 0.2, theme.secondary[3] * 0.2, 0.8)
        CB.UI.SetBackdropBorderColorCompat(materialsCard, theme.border[1] * 0.4, theme.border[2] * 0.4, theme.border[3] * 0.4, 0.6)
        
        table.insert(rightPanel.displayElements, materialsCard)
        
        local materialsHeader = materialsCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        materialsHeader:SetPoint("TOPLEFT", materialsCard, "TOPLEFT", 12, -12)
        materialsHeader:SetText("Materials Required:")
        materialsHeader:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
        
        local materialOffset = -35
        for _, reagent in ipairs(recipe.reagents) do
            local materialText = materialsCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            materialText:SetPoint("TOPLEFT", materialsCard, "TOPLEFT", 20, materialOffset)
            materialText:SetText("• " .. (reagent.count or 1) .. "x " .. (reagent.name or "Unknown Material"))
            materialText:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
            materialOffset = materialOffset - 18
        end
        
        yOffset = yOffset - cardHeight - 15
    end
    
    -- Tools Card
    if recipe.tools and #recipe.tools > 0 then
        local toolsCard = CreateFrame("Frame", nil, rightPanel)
        local cardHeight = 50 + (#recipe.tools * 18)
        toolsCard:SetSize(rightPanel:GetWidth() - 20, cardHeight)
        toolsCard:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, yOffset)
        
        -- Apply card styling
        CB.UI.SetBackdropCompat(toolsCard, {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        CB.UI.SetBackdropColorCompat(toolsCard, theme.secondary[1] * 0.2, theme.secondary[2] * 0.2, theme.secondary[3] * 0.2, 0.8)
        CB.UI.SetBackdropBorderColorCompat(toolsCard, theme.border[1] * 0.4, theme.border[2] * 0.4, theme.border[3] * 0.4, 0.6)
        
        table.insert(rightPanel.displayElements, toolsCard)
        
        local toolsHeader = toolsCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        toolsHeader:SetPoint("TOPLEFT", toolsCard, "TOPLEFT", 12, -12)
        toolsHeader:SetText("Tools Required:")
        toolsHeader:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
        
        local toolOffset = -35
        for _, tool in ipairs(recipe.tools) do
            local toolText = toolsCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            toolText:SetPoint("TOPLEFT", toolsCard, "TOPLEFT", 20, toolOffset)
            toolText:SetText("• " .. (tool.name or "Unknown Tool"))
            toolText:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
            toolOffset = toolOffset - 18
        end
        
        yOffset = yOffset - cardHeight - 15
    end
    
    -- Description Card
    if recipe.description then
        local descCard = CreateFrame("Frame", nil, rightPanel)
        descCard:SetSize(rightPanel:GetWidth() - 20, 80)
        descCard:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, yOffset)
        
        -- Apply card styling
        CB.UI.SetBackdropCompat(descCard, {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        CB.UI.SetBackdropColorCompat(descCard, theme.secondary[1] * 0.2, theme.secondary[2] * 0.2, theme.secondary[3] * 0.2, 0.8)
        CB.UI.SetBackdropBorderColorCompat(descCard, theme.border[1] * 0.4, theme.border[2] * 0.4, theme.border[3] * 0.4, 0.6)
        
        table.insert(rightPanel.displayElements, descCard)
        
        local descHeader = descCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        descHeader:SetPoint("TOPLEFT", descCard, "TOPLEFT", 12, -12)
        descHeader:SetText("Description:")
        descHeader:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
        
        local descText = descCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descText:SetPoint("TOPLEFT", descCard, "TOPLEFT", 20, -35)
        descText:SetText(recipe.description)
        descText:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
        descText:SetWidth(descCard:GetWidth() - 40)
        
        yOffset = yOffset - 95
    end
    
    -- Pricing Information Card (placeholder for future)
    local pricingCard = CreateFrame("Frame", nil, rightPanel)
    pricingCard:SetSize(rightPanel:GetWidth() - 20, 70)
    pricingCard:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 10, yOffset)
    
    -- Apply card styling
    CB.UI.SetBackdropCompat(pricingCard, {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    CB.UI.SetBackdropColorCompat(pricingCard, theme.secondary[1] * 0.15, theme.secondary[2] * 0.15, theme.secondary[3] * 0.15, 0.6)
    CB.UI.SetBackdropBorderColorCompat(pricingCard, theme.border[1] * 0.3, theme.border[2] * 0.3, theme.border[3] * 0.3, 0.4)
    
    table.insert(rightPanel.displayElements, pricingCard)
    
    local pricingHeader = pricingCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pricingHeader:SetPoint("TOPLEFT", pricingCard, "TOPLEFT", 12, -12)
    pricingHeader:SetText("Pricing Information:")
    pricingHeader:SetTextColor(theme.accent[1] * 0.7, theme.accent[2] * 0.7, theme.accent[3] * 0.7)
    
    local pricingText = pricingCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pricingText:SetPoint("TOPLEFT", pricingCard, "TOPLEFT", 20, -35)
    pricingText:SetText("• Coming in future updates")
    -- pricingText:SetTextColor(theme.secondary[1] * 0.8, theme.secondary[2] * 0.8, theme.secondary[3] * 0.8)
end

-- Create unified profession display inspired by original WoW profession UI
function PL.CreateUnifiedProfessionDisplay(parent, professionData, theme, categoryFilter)
    CB.Debug("CreateUnifiedProfessionDisplay called with:")
    CB.Debug("  player: " .. tostring(professionData and professionData.player))
    CB.Debug("  profession: " .. tostring(professionData and professionData.profession))
    CB.Debug("  level: " .. tostring(professionData and professionData.level))
    CB.Debug("  recipes count: " .. tostring(professionData and professionData.recipes and #professionData.recipes or "nil"))
    CB.Debug("  category filter: " .. tostring(categoryFilter or "none"))
    
    -- Clear existing content with more thorough approach
    local childCount = parent:GetNumChildren()
    CB.Debug("Clearing " .. childCount .. " existing children")
    
    -- Method 1: Hide and reparent all children
    for i = 1, childCount do
        local child = select(i, parent:GetChildren())
        if child then
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    -- Method 2: Store references and clear them explicitly
    if parent.displayElements then
        for _, element in ipairs(parent.displayElements) do
            if element and element.Hide then
                element:Hide()
                element:SetParent(nil)
            end
        end
    end
    parent.displayElements = {}
    
    -- Method 3: Force a layout update
    parent:SetHeight(1)
    
    CB.Debug("After clearing, children count: " .. parent:GetNumChildren())
    
    if not professionData then
        local noDataText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        noDataText:SetPoint("CENTER", parent, "CENTER", 0, 0)
        noDataText:SetText("No profession data available")
        noDataText:SetTextColor(theme.text[1] * 0.7, theme.text[2] * 0.7, theme.text[3] * 0.7)
        parent:SetHeight(100)
        
        -- Track this element
        table.insert(parent.displayElements, noDataText)
        return
    end
    
    -- Additional null checks for common issues
    if not professionData.recipes then
        local noRecipesText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        noRecipesText:SetPoint("CENTER", parent, "CENTER", 0, 0)
        noRecipesText:SetText("No recipes found for " .. (professionData.profession or professionData.name or "this profession"))
        noRecipesText:SetTextColor(theme.text[1] * 0.7, theme.text[2] * 0.7, theme.text[3] * 0.7)
        parent:SetHeight(100)
        
        -- Track this element
        table.insert(parent.displayElements, noRecipesText)
        CB.Debug("No recipes array found in profession data")
        return
    end
    
    if #professionData.recipes == 0 then
        local emptyRecipesText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        emptyRecipesText:SetPoint("CENTER", parent, "CENTER", 0, 0)
        emptyRecipesText:SetText("No recipes available for " .. (professionData.profession or professionData.name or "this profession"))
        emptyRecipesText:SetTextColor(theme.text[1] * 0.7, theme.text[2] * 0.7, theme.text[3] * 0.7)
        parent:SetHeight(100)
        
        -- Track this element
        table.insert(parent.displayElements, emptyRecipesText)
        CB.Debug("Empty recipes array in profession data")
        return
    end
    
    local yOffset = -20
    local contentHeight = 0
    
    -- Skill level bar (like original profession window)
    if professionData.level then
        local skillLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        skillLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        skillLabel:SetText("Skill: " .. (professionData.level or "0") .. " / " .. (professionData.maxLevel or "300"))
        skillLabel:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
        
        local skillBar = CreateFrame("StatusBar", nil, parent)
        skillBar:SetSize(400, 16)
        skillBar:SetPoint("TOPLEFT", skillLabel, "BOTTOMLEFT", 0, -5)
        skillBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        skillBar:SetStatusBarColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        skillBar:SetMinMaxValues(0, professionData.maxLevel or 300)
        skillBar:SetValue(professionData.level or 0)
        
        local skillBg = skillBar:CreateTexture(nil, "BACKGROUND")
        skillBg:SetAllPoints()
        skillBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        skillBg:SetVertexColor(theme.secondary[1], theme.secondary[2], theme.secondary[3], 0.8)
        
        -- Track these elements
        table.insert(parent.displayElements, skillLabel)
        table.insert(parent.displayElements, skillBar)
        
        yOffset = yOffset - 50
        contentHeight = contentHeight + 50
    end
    
    -- Recipe list organized by categories
    if professionData.recipes and #professionData.recipes > 0 then
        -- Check if we have categories in the data structure
        local hasCategories = professionData.categories and next(professionData.categories)
        
        CB.Debug("Recipe organization:")
        CB.Debug("  Total recipes: " .. #professionData.recipes)
        CB.Debug("  Categories available: " .. tostring(hasCategories))
        if professionData.categories then
            CB.Debug("  Categories object type: " .. type(professionData.categories))
            for catName, indices in pairs(professionData.categories) do
                CB.Debug("    Category '" .. catName .. "': " .. (indices and #indices or "nil") .. " recipes")
            end
        end
        
        if hasCategories then
            CB.Debug("Found categories: " .. tostring(PL.GetTableSize(professionData.categories)))
            
            -- Display recipes by category (filtered if specified)
            for categoryName, recipeIndices in pairs(professionData.categories) do
                if recipeIndices and #recipeIndices > 0 then
                    -- Only show category if filter allows it
                    local showCategory = not categoryFilter or categoryFilter == "all" or categoryFilter == categoryName
                    
                    if showCategory then
                        -- Category header
                        local categoryHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                        categoryHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
                        categoryHeader:SetText(categoryName .. " (" .. #recipeIndices .. ")")
                        categoryHeader:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3])
                        
                        -- Track this element
                        table.insert(parent.displayElements, categoryHeader)
                        
                        yOffset = yOffset - 25
                        contentHeight = contentHeight + 25
                    
                    -- List recipes in this category
                    for _, recipeIndex in ipairs(recipeIndices) do
                        local recipe = professionData.recipes[recipeIndex]
                        if recipe and recipe.name then  -- Enhanced null checking
                            local recipeButton = CreateFrame("Button", nil, parent)
                            recipeButton:SetSize(400, 16)
                            recipeButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 40, yOffset)
                            
                            local recipeText = recipeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                            recipeText:SetPoint("LEFT", recipeButton, "LEFT", 0, 0)
                            recipeText:SetText("• " .. recipe.name)
                            
                            -- Color code by difficulty like original UI
                            SetDifficultyTextColor(recipeText, recipe.difficulty)
                            
                            -- Add hover effect for clickability
                            recipeButton:SetScript("OnEnter", function(self)
                                recipeText:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
                            end)
                            recipeButton:SetScript("OnLeave", function(self)
                                -- Restore original color
                                SetDifficultyTextColor(recipeText, recipe.difficulty)
                            end)
                            
                            -- Add click handler to show recipe details in right panel
                            recipeButton:SetScript("OnClick", function(self)
                                -- Get the main profession viewer frame
                                local mainFrame = parent
                                while mainFrame and not mainFrame.rightPanel do
                                    mainFrame = mainFrame:GetParent()
                                end
                                
                                if mainFrame and mainFrame.rightPanel then
                                    PL.DisplayRecipeDetails(mainFrame.rightPanel, recipe, theme)
                                    CB.Debug("Displaying details for recipe: " .. recipe.name)
                                else
                                    CB.Debug("Could not find right panel for recipe details")
                                end
                            end)
                            
                            -- Track this element
                            table.insert(parent.displayElements, recipeButton)
                            
                            yOffset = yOffset - 16
                            contentHeight = contentHeight + 16
                        elseif recipe then
                            CB.Debug("Skipping recipe with missing name: " .. tostring(recipeIndex))
                        else
                            CB.Debug("Skipping nil recipe at index: " .. tostring(recipeIndex))
                        end
                    end
                    
                    -- Add spacing between categories
                    yOffset = yOffset - 10
                    contentHeight = contentHeight + 10
                    end  -- Close the if showCategory block
                end
            end
        else
            CB.Debug("No categories found, listing all recipes")
            
            -- No categories, list all recipes in one section
            local recipeHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            recipeHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
            recipeHeader:SetText("Known Recipes (" .. #professionData.recipes .. ")")
            recipeHeader:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
            
            yOffset = yOffset - 25
            contentHeight = contentHeight + 25
            
            -- List all recipes
            for i, recipe in ipairs(professionData.recipes) do
                if recipe and recipe.name then  -- Enhanced null checking
                    local recipeButton = CreateFrame("Button", nil, parent)
                    recipeButton:SetSize(400, 16)
                    recipeButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 40, yOffset)
                    
                    local recipeText = recipeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    recipeText:SetPoint("LEFT", recipeButton, "LEFT", 0, 0)
                    recipeText:SetText("• " .. recipe.name)
                    
                    -- Color code by difficulty like original UI
                    SetDifficultyTextColor(recipeText, recipe.difficulty)
                    
                    -- Add hover effect for clickability
                    recipeButton:SetScript("OnEnter", function(self)
                        recipeText:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
                    end)
                    recipeButton:SetScript("OnLeave", function(self)
                        -- Restore original color
                        SetDifficultyTextColor(recipeText, recipe.difficulty)
                    end)
                    
                    -- Add click handler to show recipe details in right panel
                    recipeButton:SetScript("OnClick", function(self)
                        -- Get the main profession viewer frame
                        local mainFrame = parent
                        while mainFrame and not mainFrame.rightPanel do
                            mainFrame = mainFrame:GetParent()
                        end
                        
                        if mainFrame and mainFrame.rightPanel then
                            PL.DisplayRecipeDetails(mainFrame.rightPanel, recipe, theme)
                            CB.Debug("Displaying details for recipe: " .. recipe.name)
                        else
                            CB.Debug("Could not find right panel for recipe details")
                        end
                    end)
                    
                    -- Track this element
                    table.insert(parent.displayElements, recipeButton)
                    
                    yOffset = yOffset - 16
                    contentHeight = contentHeight + 16
                elseif recipe then
                    CB.Debug("Skipping recipe with missing name at index: " .. tostring(i))
                else
                    CB.Debug("Skipping nil recipe at index: " .. tostring(i))
                end
            end
        end
    else
        -- No recipes available
        local noRecipesText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        noRecipesText:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        noRecipesText:SetText("No recipes available")
        noRecipesText:SetTextColor(theme.text[1] * 0.7, theme.text[2] * 0.7, theme.text[3] * 0.7)
        
        yOffset = yOffset - 30
        contentHeight = contentHeight + 30
    end
    
    parent:SetHeight(math.max(contentHeight + 40, 300))
end

-- Set category filter and refresh display
function PL.SetCategoryFilter(frame, category, displayName)
    if not frame or not frame.categoryFilter then
        return
    end
    
    frame.categoryFilter.currentCategory = category
    
    -- Update dropdown text
    if displayName then
        UIDropDownMenu_SetText(frame.categoryFilter.dropdown, displayName)
    else
        UIDropDownMenu_SetText(frame.categoryFilter.dropdown, category == "all" and "All Categories" or category)
    end
    
    -- Refresh the profession display with filter
    local professionData = frame.currentProfessionData
    if professionData then
        local theme = CB.getThemeColors()
        PL.CreateUnifiedProfessionDisplay(frame.scrollChild, professionData, theme, category)
        frame.UpdateScrollRange()
    end
end
    
-- Switch viewer tab function - removed since we now use single unified view
-- This function remains for backward compatibility but does nothing
function PL.SwitchViewerTab(tabIndex)
    CB.Debug("SwitchViewerTab called but tab system has been replaced with unified view")
end

-- Generate and show profession link
function PL.GenerateAndShowProfessionLink(frame)
    if not frame then 
        CB.Debug("GenerateAndShowProfessionLink: No frame provided")
        return 
    end
    
    local playerName = frame.currentPlayerName or UnitName("player") or "Unknown"
    local professionName = frame.currentProfessionName or "Unknown"
    
    CB.Debug("GenerateAndShowProfessionLink: Creating link for " .. playerName .. "'s " .. professionName)
    
    -- Generate the proper link using the same format as GenerateProfessionLink
    local profId = PROFESSION_IDS[professionName]
    if not profId then
        CB.Debug("GenerateAndShowProfessionLink: Unknown profession ID for " .. professionName)
        print("|cffffff00CraftersBoard|r Unknown profession: " .. professionName)
        return
    end
    
    -- Get profession data for rank information
    local snapshot = professionSnapshots[professionName]
    local rank = 0
    if snapshot then
        rank = snapshot.rank or 0
    end
    
    local timestamp = time()
    local owner = GetPlayerIdentifier() -- Current player identifier
    
    -- Use the proper LINK_FORMAT that includes all required data
    local hyperlink = string.format(LINK_FORMAT, owner, profId, PROTOCOL_VERSION, timestamp, 
                                  playerName, professionName, rank)
    
    local theme = CB.getThemeColors()
    if not theme then
        CB.Debug("GenerateAndShowProfessionLink: No theme available, using defaults")
        theme = { primary = {0.1, 0.1, 0.1}, accent = {0.5, 0.5, 1}, text = {1, 1, 1} }
    end
    
    -- TODO Fix this!
    -- Create a container frame for the EditBox with backdrop support
    -- local container = CreateFrame("Frame", nil, frame)
    -- container:SetSize(410, 40)
    -- container:SetPoint("CENTER", frame, "CENTER", 0, 100)
    
    -- Apply backdrop styling to the container
    -- if CB.UI and CB.UI.SetBackdropCompat then
    --     CB.UI.SetBackdropCompat(container, {
    --         bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    --         edgeFile = "Interface\\Common\\Common-Input-Border",
    --         tile = true, tileSize = 8, edgeSize = 8,
    --         insets = { left = 3, right = 3, top = 3, bottom = 3 }
    --     })
    --     CB.UI.SetBackdropColorCompat(container, theme.primary[1], theme.primary[2], theme.primary[3], 1.0)
    --     CB.UI.SetBackdropBorderColorCompat(container, theme.accent[1], theme.accent[2], theme.accent[3], 1.0)
    -- else
    --     CB.Debug("GenerateAndShowProfessionLink: CB.UI backdrop functions not available")
    -- end
    
    -- -- Create the EditBox inside the container
    -- local editBox = CreateFrame("EditBox", nil, container)
    -- editBox:SetSize(394, 24)
    -- editBox:SetPoint("CENTER", container, "CENTER", 0, 0)
    -- editBox:SetAutoFocus(true)
    -- editBox:SetText(hyperlink)
    -- editBox:HighlightText()
    -- editBox:SetFontObject("GameFontNormal")
    -- editBox:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
    
    -- local linkLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- linkLabel:SetPoint("BOTTOM", container, "TOP", 0, 5)
    -- linkLabel:SetText("Profession Link (Ctrl+C to copy, Shift+Click to insert in chat):")
    -- linkLabel:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
    
    -- editBox:SetScript("OnEscapePressed", function(self)
    --     container:Hide()
    --     linkLabel:Hide()
    -- end)
    
    -- editBox:SetScript("OnEnterPressed", function(self)
    --     container:Hide()
    --     linkLabel:Hide()
    -- end)
    
    CB.Debug("GenerateAndShowProfessionLink: Link dialog created successfully")
end

-- Helper function to map profession specializations to base professions using spell IDs (Classic WoW)
-- Function to convert internal profession names to user-friendly display names
local function GetUserFriendlyProfessionName(internalName)
    if not internalName then return "Unknown Profession" end
    
    -- Handle known internal name mappings to proper specialization names
    local internalToDisplay = {
        -- Engineering specializations (internal names that WoW might use)
        ["easyengineering"] = "Goblin Engineering",
        ["easyngineering"] = "Goblin Engineering", 
        ["hardengineering"] = "Gnomish Engineering",  -- Potential internal name
        ["gnomishengineering"] = "Gnomish Engineering",
        ["goblinengineering"] = "Goblin Engineering",
        
        -- Leatherworking specializations
        ["dragonscaleleatherworking"] = "Dragonscale Leatherworking",
        ["elementalleatherworking"] = "Elemental Leatherworking",
        ["triballeatherworking"] = "Tribal Leatherworking",
        
        -- Blacksmithing specializations  
        ["weaponsmith"] = "Weaponsmith",
        ["armorsmith"] = "Armorsmith",
        ["masterswordsmith"] = "Master Swordsmith",
        ["masterhammersmith"] = "Master Hammersmith",
        ["masteraxesmith"] = "Master Axesmith",
        
        -- Base professions (in case of weird internal names)
        ["alchemy"] = "Alchemy",
        ["blacksmithing"] = "Blacksmithing",
        ["enchanting"] = "Enchanting", 
        ["engineering"] = "Engineering",
        ["leatherworking"] = "Leatherworking",
        ["tailoring"] = "Tailoring",
        ["mining"] = "Mining",
        ["herbalism"] = "Herbalism",
        ["skinning"] = "Skinning",
        ["fishing"] = "Fishing",
        ["cooking"] = "Cooking",
        ["firstaid"] = "First Aid",
        ["first aid"] = "First Aid"
    }
    
    -- Try exact match first (case-sensitive)
    local displayName = internalToDisplay[internalName]
    if displayName then
        return displayName
    end
    
    -- Try case-insensitive match
    local lowerName = internalName:lower()
    displayName = internalToDisplay[lowerName]
    if displayName then
        return displayName
    end
    
    -- Try pattern matching for complex internal names
    if lowerName:find("goblin") and lowerName:find("engineering") then
        return "Goblin Engineering"
    elseif lowerName:find("gnomish") and lowerName:find("engineering") then
        return "Gnomish Engineering"
    elseif lowerName:find("dragonscale") and lowerName:find("leatherworking") then
        return "Dragonscale Leatherworking"
    elseif lowerName:find("elemental") and lowerName:find("leatherworking") then
        return "Elemental Leatherworking"
    elseif lowerName:find("tribal") and lowerName:find("leatherworking") then
        return "Tribal Leatherworking"
    elseif lowerName:find("master") and lowerName:find("swordsmith") then
        return "Master Swordsmith"
    elseif lowerName:find("master") and lowerName:find("hammersmith") then
        return "Master Hammersmith"
    elseif lowerName:find("master") and lowerName:find("axesmith") then
        return "Master Axesmith"
    elseif lowerName:find("weaponsmith") then
        return "Weaponsmith"
    elseif lowerName:find("armorsmith") then
        return "Armorsmith"
    elseif lowerName:find("engineering") then
        return "Engineering"
    elseif lowerName:find("leatherworking") then
        return "Leatherworking"
    elseif lowerName:find("blacksmithing") then
        return "Blacksmithing"
    elseif lowerName:find("alchemy") then
        return "Alchemy"
    elseif lowerName:find("enchanting") then
        return "Enchanting"
    elseif lowerName:find("tailoring") then
        return "Tailoring"
    elseif lowerName:find("mining") then
        return "Mining"
    end
    
    -- If nothing matches, return the original name (capitalized)
    return internalName:sub(1,1):upper() .. internalName:sub(2):lower()
end

local function GetBaseProfessionBySpellId(spellId)
    if not spellId then return "Other" end
    
    -- Classic WoW profession specialization spell IDs
    local SPECIALIZATION_SPELL_IDS = {
        -- Blacksmithing specializations
        [9787] = "Blacksmithing",   -- Weaponsmith
        [9788] = "Blacksmithing",   -- Armorsmith
        [17039] = "Blacksmithing",  -- Master Swordsmith
        [17040] = "Blacksmithing",  -- Master Hammersmith
        [17041] = "Blacksmithing",  -- Master Axesmith
        
        -- Engineering specializations
        [20219] = "Engineering",    -- Gnomish Engineering
        [20222] = "Engineering",    -- Goblin Engineering
        
        -- Leatherworking specializations
        [10656] = "Leatherworking", -- Dragonscale Leatherworking
        [10658] = "Leatherworking", -- Elemental Leatherworking
        [10660] = "Leatherworking", -- Tribal Leatherworking
        
        -- Base profession spell IDs
        [2018] = "Blacksmithing",   -- Blacksmithing
        [4036] = "Engineering",     -- Engineering
        [2108] = "Leatherworking",  -- Leatherworking
        [7411] = "Enchanting",      -- Enchanting
        [2259] = "Alchemy",         -- Alchemy
        [3908] = "Tailoring",       -- Tailoring
        [2575] = "Mining",          -- Mining
        [2366] = "Herbalism",       -- Herbalism
        [8613] = "Skinning",        -- Skinning
        [7620] = "Fishing",         -- Fishing
        [2550] = "Cooking",         -- Cooking
        [3273] = "FirstAid",        -- First Aid
    }
    
    return SPECIALIZATION_SPELL_IDS[spellId] or "Other"
end

-- Helper function to map profession names to base professions using spell ID lookup
local function GetBaseProfession(professionName)
    if not professionName then 
        return "Other" 
    end
    
    -- First try to get spell ID from profession name
    local spellId = nil
    
    -- Check if we have profession data available to lookup spell ID
    if PROFESSION_IDS and PROFESSION_IDS[professionName] then
        -- We have a profession ID, now we need to find the corresponding spell ID
        -- This is more complex as we need to check the profession spells table
        local professionSpells = {
            {spell = 2018, id = 164, name = "Blacksmithing"},
            {spell = 7411, id = 333, name = "Enchanting"},
            {spell = 4036, id = 202, name = "Engineering"},
            {spell = 2259, id = 171, name = "Alchemy"},
            {spell = 3273, id = 129, name = "FirstAid"},
            {spell = 2550, id = 185, name = "Cooking"},
            {spell = 2575, id = 186, name = "Mining"},
            {spell = 8613, id = 393, name = "Skinning"},
            {spell = 2108, id = 165, name = "Leatherworking"},
            {spell = 3908, id = 197, name = "Tailoring"},
            {spell = 2366, id = 182, name = "Herbalism"},
            {spell = 7620, id = 356, name = "Fishing"},
        }
        
        local profId = PROFESSION_IDS[professionName]
        for _, prof in ipairs(professionSpells) do
            if prof.id == profId then
                spellId = prof.spell
                break
            end
        end
    end
    
    -- Try to find specialization spell IDs by name matching for common specializations
    if not spellId then
        local lowerName = professionName:lower()
        
        -- Handle specific corrupted/internal names
        if lowerName == "easyengineering" then
            spellId = 20222 -- Assume Goblin Engineering for easyengineering
        elseif lowerName:find("goblin") and lowerName:find("engineering") then
            spellId = 20222 -- Goblin Engineering
        elseif lowerName:find("gnomish") and lowerName:find("engineering") then
            spellId = 20219 -- Gnomish Engineering
        elseif lowerName:find("engineering") then
            spellId = 4036 -- Base Engineering
        elseif lowerName:find("dragonscale") and lowerName:find("leatherworking") then
            spellId = 10656 -- Dragonscale Leatherworking
        elseif lowerName:find("elemental") and lowerName:find("leatherworking") then
            spellId = 10658 -- Elemental Leatherworking
        elseif lowerName:find("tribal") and lowerName:find("leatherworking") then
            spellId = 10660 -- Tribal Leatherworking
        elseif lowerName:find("leatherworking") then
            spellId = 2108 -- Base Leatherworking
        elseif lowerName:find("weaponsmith") then
            spellId = 9787 -- Weaponsmith
        elseif lowerName:find("armorsmith") then
            spellId = 9788 -- Armorsmith
        elseif lowerName:find("master") and lowerName:find("swordsmith") then
            spellId = 17039 -- Master Swordsmith
        elseif lowerName:find("master") and lowerName:find("hammersmith") then
            spellId = 17040 -- Master Hammersmith
        elseif lowerName:find("master") and lowerName:find("axesmith") then
            spellId = 17041 -- Master Axesmith
        elseif lowerName:find("blacksmithing") then
            spellId = 2018 -- Base Blacksmithing
        end
    end
    
    if spellId then
        local result = GetBaseProfessionBySpellId(spellId)
        return result
    end
    
    -- Fallback to string matching for exact profession names
    local exactMatches = {
        ["Alchemy"] = "Alchemy",
        ["Blacksmithing"] = "Blacksmithing", 
        ["Enchanting"] = "Enchanting",
        ["Engineering"] = "Engineering",
        ["Leatherworking"] = "Leatherworking",
        ["Tailoring"] = "Tailoring",
        ["Mining"] = "Mining",
        ["Herbalism"] = "Herbalism",
        ["Skinning"] = "Skinning",
        ["Fishing"] = "Fishing",
        ["Cooking"] = "Cooking",
        ["FirstAid"] = "FirstAid",
        ["First Aid"] = "FirstAid",
        -- Handle known internal names for icon resolution (all map to base professions)
        ["easyengineering"] = "Engineering",  
        ["easyngineering"] = "Engineering",   
        ["hardengineering"] = "Engineering", 
        ["gnomishengineering"] = "Engineering",
        ["goblinengineering"] = "Engineering",
        ["dragonscaleleatherworking"] = "Leatherworking",
        ["elementalleatherworking"] = "Leatherworking", 
        ["triballeatherworking"] = "Leatherworking",
        ["weaponsmith"] = "Blacksmithing",
        ["armorsmith"] = "Blacksmithing",
        ["masterswordsmith"] = "Blacksmithing",
        ["masterhammersmith"] = "Blacksmithing",
        ["masteraxesmith"] = "Blacksmithing"
    }
    
    local result = exactMatches[professionName]
    if result then
        return result
    end
    
    -- Only show error for truly unknown profession names that couldn't be resolved
    if professionName ~= "Unknown" and professionName ~= "" then
        print("|cffffff00CraftersBoard|r |cffff0000[ERROR]|r Unknown profession name: '" .. tostring(professionName) .. "' - using 'Other' icon")
    end
    
    return "Other"
end

-- Helper function to get profession icon path
local function GetProfessionIconPath(professionName)
    local baseProfession = GetBaseProfession(professionName)
    
    local PROFESSION_ICONS = {
        ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
        ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
        ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
        ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
        ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
        ["Mining"] = "Interface\\Icons\\Trade_Mining",
        ["Herbalism"] = "Interface\\Icons\\Trade_Herbalism",
        ["Skinning"] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
        ["Fishing"] = "Interface\\Icons\\Trade_Fishing",
        ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
        ["FirstAid"] = "Interface\\Icons\\Spell_Holy_Heal",
        ["Other"] = "Interface\\Icons\\INV_Misc_QuestionMark"
    }
    
    return PROFESSION_ICONS[baseProfession] or PROFESSION_ICONS["Other"]
end
-- Show error in the profession viewer
function PL.ShowViewerError(playerName, professionName, errorMessage)
    CB.Debug("ShowViewerError: " .. playerName .. "'s " .. professionName .. " - " .. errorMessage)
    print("|cffffff00CraftersBoard|r Error viewing " .. playerName .. "'s " .. professionName .. ": " .. errorMessage)
    
    -- You could also show this in a UI frame if you have one
    -- For now, just print to chat
end

-- Show profession data function - this displays profession data using the unified view
function PL.ShowProfessionData(playerName, professionName, snapshot)
    -- FIXED: Simplified to only handle three-parameter format
    if not playerName or not professionName or not snapshot then
        CB.Debug("ShowProfessionData: Missing required parameters")
        CB.Debug("  playerName: " .. tostring(playerName))
        CB.Debug("  professionName: " .. tostring(professionName))
        CB.Debug("  snapshot: " .. tostring(snapshot and "present" or "nil"))
        return
    end
    
    CB.Debug("ShowProfessionData called with player: " .. playerName .. ", profession: " .. professionName)
    
    -- Create the profession data structure for the viewer
    local professionData = {
        player = playerName,
        profession = professionName,
        level = snapshot.rank or 0,
        maxLevel = snapshot.maxRank or 0,
        recipes = snapshot.recipes or {},
        categories = snapshot.categories or {},
        timestamp = snapshot.timestamp or time(),
        data = snapshot
    }
    
    CB.Debug("Created professionData with " .. #professionData.recipes .. " recipes")
    
    -- Only show message if there's an issue (no debug for normal operation)
    local baseProfession = GetBaseProfession(professionData.profession)
    local iconPath = GetProfessionIconPath(professionData.profession)
    
    -- Only report if there's a problem with icon resolution
    if iconPath == "Interface\\Icons\\INV_Misc_QuestionMark" and professionData.profession ~= "Unknown" then
        print("|cffffff00CraftersBoard|r |cffff0000[ERROR]|r Failed to resolve icon for profession: " .. tostring(professionData.profession))
    end
    
    local frame = PL.CreateProfessionViewer()
    if frame then
        -- Set profession icon in title bar using proper specialization handling
        if frame.ProfessionIcon then
            frame.ProfessionIcon:SetTexture(iconPath)
            CB.Debug("Set profession icon to: " .. iconPath .. " for profession: " .. professionData.profession)
        end

        frame:DisplayProfessionData(professionData)
        
        -- Display user-friendly profession name in title using comprehensive mapping
        local displayName = GetUserFriendlyProfessionName(professionData.profession)
        
        -- Show user-friendly name in title (e.g., "Goblin Engineering - PlayerName")
        local displayPlayerName = NormalizePlayerName(professionData.player) or professionData.player
        frame.TitleText:SetText((displayName or "Profession") .. " - " .. displayPlayerName)
        frame:Show()
        local displayPlayerName = NormalizePlayerName(professionData.player) or professionData.player
        CB.Debug("Displayed profession data for: " .. displayPlayerName .. " (" .. (displayName or "Unknown") .. ")")
    end
end

-- Filter recipes function - placeholder for backward compatibility
function PL.FilterRecipes(searchText)
    CB.Debug("FilterRecipes called with: " .. (searchText or ""))
end

-- Update overview panel with profession data
function PL.UpdateOverviewPanel(panel, playerName, snapshot)
    if not panel then return end
    
    -- Set profession icon using the same logic as the profession viewer
    local iconPath = GetProfessionIconPath(snapshot.name)
    panel.profIcon:SetTexture(iconPath)
    
    -- Update text fields
    panel.profName:SetText(snapshot.name or "Unknown Profession")
    local displayPlayerName = NormalizePlayerName(playerName) or playerName
    panel.playerName:SetText(displayPlayerName or "Unknown Player")
    panel.skillLevel:SetText(string.format("%d / %d", snapshot.rank or 0, snapshot.maxRank or 300))
    panel.recipeCount:SetText(string.format("Total Recipes: %d", #snapshot.recipes))
    panel.lastUpdated:SetText("Last Updated: " .. date("%m/%d %H:%M", snapshot.timestamp or 0))
    
    -- Update progress bar
    local currentRank = snapshot.rank or 0
    local maxRank = snapshot.maxRank or 300
    panel.progressBar:SetMinMaxValues(0, maxRank)
    panel.progressBar:SetValue(currentRank)
    
    -- Calculate progress percentage
    local percentage = maxRank > 0 and (currentRank / maxRank * 100) or 0
    panel.progressBar:SetStatusBarColor(
        percentage < 50 and 0.8 or 0.2,  -- Red to green based on progress
        percentage > 30 and 0.8 or 0.2,
        0.2,
        1
    )
    
    -- Count categories
    local categoryCount = 0
    if snapshot.categories then
        for _ in pairs(snapshot.categories) do
            categoryCount = categoryCount + 1
        end
    end
    panel.categoryCount:SetText("Categories: " .. categoryCount)
    
    -- Calculate difficulty breakdown
    local difficultyStats = {optimal = 0, medium = 0, easy = 0, trivial = 0}
    local totalRecipes = #snapshot.recipes
    
    for _, recipe in ipairs(snapshot.recipes) do
        local difficulty = recipe.type or recipe.difficulty
        if type(difficulty) == "table" then
            difficulty = difficulty.color or difficulty.text
        end
        
        if difficulty == "optimal" then
            difficultyStats.optimal = difficultyStats.optimal + 1
        elseif difficulty == "medium" then
            difficultyStats.medium = difficultyStats.medium + 1
        elseif difficulty == "easy" then
            difficultyStats.easy = difficultyStats.easy + 1
        elseif difficulty == "trivial" then
            difficultyStats.trivial = difficultyStats.trivial + 1
        end
    end
    
    -- Update difficulty bars
    for diffType, count in pairs(difficultyStats) do
        local diffBar = panel.difficultyBars[diffType]
        if diffBar then
            local percentage = totalRecipes > 0 and (count / totalRecipes * 100) or 0
            diffBar.label:SetText(diffBar.label:GetText():gsub(": %d+", ": " .. count))
            diffBar.bar:SetValue(percentage)
        end
    end
    
    CB.Debug("Updated overview panel for " .. (snapshot.name or "unknown"))
end

-- Update recipes panel with scrollable recipe list
function PL.UpdateRecipesPanel(panel, snapshot)
    if not panel or not panel.scrollContent then return end
    
    -- Clear existing recipe buttons
    local children = {panel.scrollContent:GetChildren()}
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Reset search
    if panel.searchBox then
        panel.searchBox:SetText("")
    end
    
    -- Create recipe entries organized by category
    local yOffset = -10
    local recipes = snapshot.recipes or {}
    local categories = snapshot.categories or {}
    
    CB.Debug("Building recipes panel with " .. #recipes .. " recipes in " .. PL.GetTableSize(categories) .. " categories")
    
    -- If we have categories, organize by them
    if PL.GetTableSize(categories) > 0 then
        for categoryName, recipeIndices in pairs(categories) do
            if #recipeIndices > 0 then
                -- Create category header
                local categoryHeader = CreateFrame("Frame", nil, panel.scrollContent)
                categoryHeader:SetSize(720, 30)
                categoryHeader:SetPoint("TOPLEFT", panel.scrollContent, "TOPLEFT", 10, yOffset)
                
                -- Category background
                local catBg = categoryHeader:CreateTexture(nil, "BACKGROUND")
                catBg:SetAllPoints()
                catBg:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                catBg:SetVertexColor(0.2, 0.2, 0.2, 0.5)
                
                -- Category text
                local catText = categoryHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                catText:SetPoint("LEFT", categoryHeader, "LEFT", 10, 0)
                catText:SetText(categoryName .. " (" .. #recipeIndices .. " recipes)")
                catText:SetTextColor(1, 0.82, 0) -- Blizzard gold
                
                yOffset = yOffset - 35
                
                -- Add recipes for this category (limit display for performance)
                local recipeCount = 0
                for _, recipeIndex in ipairs(recipeIndices) do
                    if recipeCount >= 20 then -- Reasonable limit
                        local moreText = panel.scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        moreText:SetPoint("TOPLEFT", panel.scrollContent, "TOPLEFT", 30, yOffset)
                        moreText:SetText("... and " .. (#recipeIndices - recipeCount) .. " more recipes")
                        moreText:SetTextColor(0.7, 0.7, 0.7)
                        yOffset = yOffset - 20
                        break
                    end
                    
                    local recipe = recipes[recipeIndex]
                    if recipe then
                        local recipeButton = PL.CreateModernRecipeButton(recipe, panel.scrollContent, 30, yOffset)
                        yOffset = yOffset - 25
                        recipeCount = recipeCount + 1
                    end
                end
                
                yOffset = yOffset - 10 -- Extra spacing between categories
            end
        end
    else
        -- No categories, show all recipes
        for i, recipe in ipairs(recipes) do
            if i > 50 then -- Performance limit
                local moreText = panel.scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                moreText:SetPoint("TOPLEFT", panel.scrollContent, "TOPLEFT", 10, yOffset)
                moreText:SetText("... and " .. (#recipes - i + 1) .. " more recipes")
                moreText:SetTextColor(0.7, 0.7, 0.7)
                break
            end
            
            local recipeButton = PL.CreateModernRecipeButton(recipe, panel.scrollContent, 10, yOffset)
            yOffset = yOffset - 25
        end
    end
    
    -- Update scroll content size
    local contentHeight = math.max(400, math.abs(yOffset) + 50)
    panel.scrollContent:SetSize(720, contentHeight)
    
    -- Update scroll frame
    if panel.scrollFrame.UpdateScrollChildRect then
        panel.scrollFrame:UpdateScrollChildRect()
    end
    
    CB.Debug("Updated recipes panel with content height: " .. contentHeight)
end

-- Update statistics panel with detailed analysis
function PL.UpdateStatisticsPanel(panel, snapshot)
    if not panel then return end
    
    -- For now, show basic statistics
    local statsText = "=== Profession Statistics ===\n\n"
    statsText = statsText .. "Profession: " .. (snapshot.name or "Unknown") .. "\n"
    statsText = statsText .. "Skill Level: " .. (snapshot.rank or 0) .. " / " .. (snapshot.maxRank or 300) .. "\n"
    statsText = statsText .. "Total Recipes: " .. #snapshot.recipes .. "\n\n"
    
    -- Category breakdown
    if snapshot.categories then
        statsText = statsText .. "=== Categories ===\n"
        for categoryName, recipeIndices in pairs(snapshot.categories) do
            statsText = statsText .. categoryName .. ": " .. #recipeIndices .. " recipes\n"
        end
        statsText = statsText .. "\n"
    end
    
    -- Difficulty analysis
    local diffStats = {optimal = 0, medium = 0, easy = 0, trivial = 0, unknown = 0}
    for _, recipe in ipairs(snapshot.recipes) do
        local difficulty = recipe.type or (recipe.difficulty and recipe.difficulty.color) or "unknown"
        if diffStats[difficulty] then
            diffStats[difficulty] = diffStats[difficulty] + 1
        else
            diffStats.unknown = diffStats.unknown + 1
        end
    end
    
    statsText = statsText .. "=== Recipe Difficulty ===\n"
    statsText = statsText .. "Optimal (Orange): " .. diffStats.optimal .. "\n"
    statsText = statsText .. "Medium (Yellow): " .. diffStats.medium .. "\n"
    statsText = statsText .. "Easy (Green): " .. diffStats.easy .. "\n"
    statsText = statsText .. "Trivial (Gray): " .. diffStats.trivial .. "\n"
    if diffStats.unknown > 0 then
        statsText = statsText .. "Unknown: " .. diffStats.unknown .. "\n"
    end
    
    -- Update timestamp
    statsText = statsText .. "\nLast Updated: " .. date("%Y-%m-%d %H:%M:%S", snapshot.timestamp or 0)
    
    panel.statsText:SetText(statsText)
    panel.statsText:SetJustifyH("LEFT")
    panel.statsText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -20)
    
    CB.Debug("Updated statistics panel")
end

-- Create a modern recipe button with card-like styling
function PL.CreateModernRecipeButton(recipe, parent, x, y)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(700, 28)  -- Increased height for card styling
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    
    -- Create card background with rounded appearance
    local cardBg = CreateFrame("Frame", nil, button)
    cardBg:SetAllPoints(button)
    cardBg:SetFrameLevel(button:GetFrameLevel())
    
    -- Apply card backdrop styling similar to main UI
    local theme = CB.getThemeColors()
    CB.UI.SetBackdropCompat(cardBg, {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    CB.UI.SetBackdropColorCompat(cardBg, theme.secondary[1] * 0.2, theme.secondary[2] * 0.2, theme.secondary[3] * 0.2, 0.7)
    CB.UI.SetBackdropBorderColorCompat(cardBg, theme.border[1] * 0.3, theme.border[2] * 0.3, theme.border[3] * 0.3, 0.4)
    
    -- Hover effect for card
    button:SetScript("OnEnter", function(self)
        CB.UI.SetBackdropColorCompat(cardBg, theme.highlight[1] * 0.3, theme.highlight[2] * 0.3, theme.highlight[3] * 0.3, 0.8)
        CB.UI.SetBackdropBorderColorCompat(cardBg, theme.border[1] * 0.6, theme.border[2] * 0.6, theme.border[3] * 0.6, 0.7)
        
        -- Show detailed tooltip
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(recipe.name or "Unknown Recipe", 1, 1, 1)
        
        if recipe.reagents and #recipe.reagents > 0 then
            GameTooltip:AddLine("Reagents:", 1, 0.82, 0)
            for _, reagent in ipairs(recipe.reagents) do
                local reagentText = (reagent.name or "Unknown") .. " (" .. (reagent.count or 0) .. ")"
                GameTooltip:AddLine("  " .. reagentText, 0.8, 0.8, 0.8)
            end
        end
        
        if recipe.tool then
            GameTooltip:AddLine("Requires: " .. recipe.tool, 1, 0.5, 0.5)
        end
        
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        CB.UI.SetBackdropColorCompat(cardBg, theme.secondary[1] * 0.2, theme.secondary[2] * 0.2, theme.secondary[3] * 0.2, 0.7)
        CB.UI.SetBackdropBorderColorCompat(cardBg, theme.border[1] * 0.3, theme.border[2] * 0.3, theme.border[3] * 0.3, 0.4)
        GameTooltip:Hide()
    end)
    
    -- Recipe icon with enhanced styling
    local recipeIcon = button:CreateTexture(nil, "ARTWORK")
    recipeIcon:SetSize(20, 20)  -- Slightly larger icon
    recipeIcon:SetPoint("LEFT", button, "LEFT", 8, 0)
    recipeIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_01") -- Default recipe icon
    
    -- Recipe name with enhanced font
    local recipeName = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recipeName:SetPoint("LEFT", recipeIcon, "RIGHT", 8, 0)
    recipeName:SetText(recipe.name or "Unknown Recipe")
    recipeName:SetJustifyH("LEFT")
    recipeName:SetWidth(400)
    
    -- Set color based on difficulty with enhanced visibility
    local difficulty = recipe.type or (recipe.difficulty and recipe.difficulty.color) or "unknown"
    if difficulty == "optimal" then
        recipeName:SetTextColor(1, 0.6, 0.1) -- Enhanced orange
    elseif difficulty == "medium" then
        recipeName:SetTextColor(1, 1, 0.2) -- Enhanced yellow
    elseif difficulty == "easy" then
        recipeName:SetTextColor(0.2, 1, 0.2) -- Enhanced green
    elseif difficulty == "trivial" then
        recipeName:SetTextColor(0.6, 0.6, 0.6) -- Enhanced gray
    else
        recipeName:SetTextColor(0.9, 0.9, 0.9) -- Enhanced white
    end
    
    -- Recipe info with card-appropriate styling
    local recipeInfo = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recipeInfo:SetPoint("RIGHT", button, "RIGHT", -12, 0)
    recipeInfo:SetJustifyH("RIGHT")
    
    local reagentCount = recipe.reagents and #recipe.reagents or 0
    local infoText = reagentCount > 0 and (reagentCount .. " reagents") or "No reagents"
    recipeInfo:SetText(infoText)
    recipeInfo:SetTextColor(0.7, 0.7, 0.7)
    
    return button
end

-- Helper function to get table size (for Classic Era compatibility)
function PL.GetTableSize(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Cache management and persistence functions
local CACHE_MAX_AGE = 7 * 24 * 60 * 60 -- 7 days in seconds
local CACHE_MAX_ENTRIES = 100 -- Maximum cached profession snapshots

-- Initialize cache from SavedVariables
function PL.InitializeCache()
    -- Initialize cache structure in saved variables if needed
    if not CRAFTERSBOARD_DB.professionCache then
        CRAFTERSBOARD_DB.professionCache = {
            players = {}, -- Other players' profession data
            ownSnapshots = {}, -- Our own profession snapshots
            lastCleanup = time()
        }
    end
    
    -- Load cached data
    cachedProfessions = CRAFTERSBOARD_DB.professionCache.players or {}
    professionSnapshots = CRAFTERSBOARD_DB.professionCache.ownSnapshots or {}
    
    CB.Debug("Loaded profession cache: " .. PL.GetCacheStatistics())
    
    -- Clean up old entries
    PL.CleanupOldCache()
end

-- Save cache to SavedVariables
function PL.SaveCache()
    if not CRAFTERSBOARD_DB.professionCache then
        CRAFTERSBOARD_DB.professionCache = {}
    end
    
    CRAFTERSBOARD_DB.professionCache.players = cachedProfessions
    CRAFTERSBOARD_DB.professionCache.ownSnapshots = professionSnapshots
    CRAFTERSBOARD_DB.professionCache.lastCleanup = time()
    
    CB.Debug("Saved profession cache to SavedVariables")
end

-- Clean up old cache entries
function PL.CleanupOldCache()
    local currentTime = time()
    local removed = 0
    
    -- Clean up other players' data
    for playerName, professions in pairs(cachedProfessions) do
        for profName, snapshot in pairs(professions) do
            if snapshot.timestamp and (currentTime - snapshot.timestamp) > CACHE_MAX_AGE then
                professions[profName] = nil
                removed = removed + 1
                CB.Debug("Removed expired cache entry: " .. playerName .. "'s " .. profName)
            end
        end
        
        -- Remove empty player entries
        if next(professions) == nil then
            cachedProfessions[playerName] = nil
        end
    end
    
    -- Clean up our own snapshots (less aggressive - only remove very old ones)
    local ownMaxAge = 30 * 24 * 60 * 60 -- 30 days for our own data
    for profName, snapshot in pairs(professionSnapshots) do
        if snapshot.timestamp and (currentTime - snapshot.timestamp) > ownMaxAge then
            professionSnapshots[profName] = nil
            removed = removed + 1
            CB.Debug("Removed expired own snapshot: " .. profName)
        end
    end
    
    if removed > 0 then
        CB.Debug("Cleaned up " .. removed .. " expired cache entries")
        PL.SaveCache()
    end
end

-- Get cache statistics
function PL.GetCacheStatistics()
    local playerCount = 0
    local professionCount = 0
    local ownCount = 0
    
    for playerName, professions in pairs(cachedProfessions) do
        playerCount = playerCount + 1
        for profName, _ in pairs(professions) do
            professionCount = professionCount + 1
        end
    end
    
    for profName, _ in pairs(professionSnapshots) do
        ownCount = ownCount + 1
    end
    
    return string.format("%d players, %d cached professions, %d own snapshots", 
                        playerCount, professionCount, ownCount)
end

-- Enhanced cache functions with persistence
function PL.CacheProfessionData(playerName, professionName, snapshot)
    if not snapshot then return end
    
    -- Store in memory
    cachedProfessions[playerName] = cachedProfessions[playerName] or {}
    cachedProfessions[playerName][professionName] = snapshot
    
    -- Save to disk
    PL.SaveCache()
    
    CB.Debug("Cached " .. professionName .. " data for " .. playerName)
end

-- Get cached profession data for a player
function PL.GetCachedProfessionData(playerName, professionName)
    if not playerName or not professionName then return nil end
    
    -- Try exact match first
    if cachedProfessions[playerName] and cachedProfessions[playerName][professionName] then
        local data = cachedProfessions[playerName][professionName]
        -- Validate data before returning
        if data and data.recipes and #data.recipes > 0 and data.name then
            return data
        else
            CB.Debug("Found invalid cached data for " .. playerName .. " " .. professionName .. ", removing it")
            cachedProfessions[playerName][professionName] = nil
        end
    end
    
    -- Try normalized player name (without realm)
    local normalizedPlayerName = NormalizePlayerName(playerName)
    if normalizedPlayerName and normalizedPlayerName ~= playerName then
        if cachedProfessions[normalizedPlayerName] and cachedProfessions[normalizedPlayerName][professionName] then
            local data = cachedProfessions[normalizedPlayerName][professionName]
            -- Validate data before returning
            if data and data.recipes and #data.recipes > 0 and data.name then
                CB.Debug("Found cached data using normalized name: " .. normalizedPlayerName)
                return data
            else
                CB.Debug("Found invalid cached data for " .. normalizedPlayerName .. " " .. professionName .. ", removing it")
                cachedProfessions[normalizedPlayerName][professionName] = nil
            end
        end
    end
    
    -- Try with realm added (in case we're looking up with just character name)
    local playerWithRealm = GetPlayerIdentifier(playerName)
    if playerWithRealm and playerWithRealm ~= playerName then
        if cachedProfessions[playerWithRealm] and cachedProfessions[playerWithRealm][professionName] then
            local data = cachedProfessions[playerWithRealm][professionName]
            -- Validate data before returning
            if data and data.recipes and #data.recipes > 0 and data.name then
                CB.Debug("Found cached data using realm name: " .. playerWithRealm)
                return data
            else
                CB.Debug("Found invalid cached data for " .. playerWithRealm .. " " .. professionName .. ", removing it")
                cachedProfessions[playerWithRealm][professionName] = nil
            end
        end
    end
    
    return nil
end

function PL.CacheOwnSnapshot(professionName, snapshot)
    if not snapshot then 
        CB.Debug("CacheOwnSnapshot called with nil snapshot for: " .. tostring(professionName))
        return 
    end
    
    CB.Debug("CacheOwnSnapshot storing data for: " .. professionName)
    CB.Debug("  snapshot.name: " .. tostring(snapshot.name))
    CB.Debug("  snapshot.rank: " .. tostring(snapshot.rank))
    CB.Debug("  snapshot.maxRank: " .. tostring(snapshot.maxRank))
    CB.Debug("  snapshot.recipes count: " .. tostring(#snapshot.recipes))
    if snapshot.categories then
        CB.Debug("  snapshot.categories count: " .. tostring(PL.GetTableSize(snapshot.categories)))
    end
    
    -- Store our own snapshot
    professionSnapshots[professionName] = snapshot
    
    -- Verify storage
    local stored = professionSnapshots[professionName]
    if stored then
        CB.Debug("  Verified storage - stored.name: " .. tostring(stored.name))
        CB.Debug("  Verified storage - stored.rank: " .. tostring(stored.rank))
    else
        CB.Debug("  ERROR: Failed to store snapshot!")
    end
    
    -- Save to disk
    PL.SaveCache()
    
    CB.Debug("Cached own " .. professionName .. " snapshot")
end

-- Auto-save functionality
local autoSaveTimer = nil

function PL.StartAutoSave()
    if autoSaveTimer then return end
    
    -- Save cache every 5 minutes
    autoSaveTimer = C_Timer.NewTicker(300, function()
        PL.SaveCache()
    end)
    
    CB.Debug("Started auto-save timer for profession cache")
end

function PL.StopAutoSave()
    if autoSaveTimer then
        autoSaveTimer:Cancel()
        autoSaveTimer = nil
        CB.Debug("Stopped auto-save timer")
    end
end

-- Old duplicate function removed

-- Show a profession link dialog
function PL.ShowProfessionLink(link, playerName, professionName)
    -- Create or reuse the link dialog
    local dialog = _G["CraftersBoardLinkDialog"]
    if not dialog then
        dialog = CreateFrame("Frame", "CraftersBoardLinkDialog", UIParent)
        dialog:SetSize(500, 200)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:Hide()
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        
        -- Background
        local bg = dialog:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.9)
        
        -- Border
        local border = dialog:CreateTexture(nil, "BORDER")
        border:SetAllPoints()
        border:SetColorTexture(0.3, 0.3, 0.3, 1)
        
        -- Title
        dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        dialog.title:SetPoint("TOP", dialog, "TOP", 0, -15)
        dialog.title:SetTextColor(1, 0.82, 0)
        
        -- Instructions
        dialog.instructions = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dialog.instructions:SetPoint("TOP", dialog.title, "BOTTOM", 0, -15)
        dialog.instructions:SetText("Click to view profession details:")
        dialog.instructions:SetTextColor(1, 1, 1)
        
        -- Link display (clickable)
        dialog.linkText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dialog.linkText:SetPoint("CENTER", dialog, "CENTER", 0, -10)
        dialog.linkText:SetTextColor(0, 1, 0.5)
        
        -- Make the link clickable with standard WoW behavior
        dialog.linkButton = CreateFrame("Button", nil, dialog)
        dialog.linkButton:SetAllPoints(dialog.linkText)
        dialog.linkButton:SetScript("OnClick", function(self, button)
            -- Standard click - handle the link normally (with built-in shift+click support)
            if dialog.currentLink then
                -- Extract just the link part for proper handling
                local linkData = dialog.currentLink:match("|H([^|]+)|h")
                local linkText = dialog.currentLink:match("|h(.+)|h")
                if linkData then
                    PL.HandleCustomLink(linkData, linkText, button)
                end
            end
        end)
        dialog.linkButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Click to view profession")
            GameTooltip:AddLine("Shift+click to insert in chat (when chat is active)", 1, 1, 1)
            GameTooltip:Show()
        end)
        dialog.linkButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 15)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function(self)
            dialog:Hide()
        end)
        
        -- ESC key handling
        table.insert(UISpecialFrames, "CraftersBoardLinkDialog")
    end
    
    -- Update the dialog content
    dialog.title:SetText("Profession Link Generated")
    -- Display the link with color formatting for visual appeal
    local displayText = link:gsub("(%[.+%])", "|cff00ff88%1|r")
    dialog.linkText:SetText(displayText)
    dialog.currentLink = link
    
    -- Show the dialog
    dialog:Show()
end

-- Copy text to clipboard (WoW doesn't have direct clipboard access, so we show it in an edit box)
function PL.CopyToClipboard(text)
    -- Create a temporary edit box for copying
    local copyFrame = _G["CraftersBoardCopyFrame"]
    if not copyFrame then
        copyFrame = CreateFrame("Frame", "CraftersBoardCopyFrame", UIParent)
        copyFrame:SetSize(400, 150)
        copyFrame:SetPoint("CENTER")
        copyFrame:SetFrameStrata("TOOLTIP")
        copyFrame:Hide()
        
        -- Background
        local bg = copyFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.9)
        
        -- Title
        copyFrame.title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        copyFrame.title:SetPoint("TOP", copyFrame, "TOP", 0, -15)
        copyFrame.title:SetText("Copy to Clipboard")
        copyFrame.title:SetTextColor(1, 0.82, 0)
        
        -- Instructions
        copyFrame.instructions = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        copyFrame.instructions:SetPoint("TOP", copyFrame.title, "BOTTOM", 0, -15)
        copyFrame.instructions:SetText("Select all text below and copy (Ctrl+C):")
        copyFrame.instructions:SetTextColor(1, 1, 1)
        
        -- Edit box
        copyFrame.editBox = CreateFrame("EditBox", nil, copyFrame)
        copyFrame.editBox:SetSize(350, 50)
        copyFrame.editBox:SetPoint("CENTER", copyFrame, "CENTER", 0, -10)
        copyFrame.editBox:SetFontObject("GameFontNormal")
        copyFrame.editBox:SetAutoFocus(true)
        copyFrame.editBox:SetScript("OnEscapePressed", function(self)
            copyFrame:Hide()
        end)
        
        -- Edit box background
        local editBg = copyFrame.editBox:CreateTexture(nil, "BACKGROUND")
        editBg:SetAllPoints()
        editBg:SetColorTexture(0.2, 0.2, 0.2, 1)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, copyFrame, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOM", copyFrame, "BOTTOM", 0, 15)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function(self)
            copyFrame:Hide()
        end)
        
        -- ESC key handling
        table.insert(UISpecialFrames, "CraftersBoardCopyFrame")
    end
    
    -- Set the text and show
    copyFrame.editBox:SetText(text)
    copyFrame.editBox:HighlightText()
    copyFrame:Show()
end

-- Handle profession link clicks
function PL.HandleProfessionLink(link)
    local playerName, professionName, profId
    
    -- Ensure profession mappings are initialized
    local mappingCount = 0
    for _ in pairs(PROFESSION_NAMES) do mappingCount = mappingCount + 1 end
    if mappingCount == 0 then
        CB.Debug("PROFESSION_NAMES is empty, reinitializing mappings...")
        InitializeProfessionMappings()
    end
    
    -- Parse the new link format: |Hcraftersboard:owner:profId:version:timestamp|h[Display Text]|h
    if link:match("|Hcraftersboard:") then
        local linkData = link:match("|Hcraftersboard:([^|]+)|h")
        if linkData then
            local owner, profIdStr, version, timestamp = linkData:match("^([^:]+):(%d+):(%d+):(%d+)$")
            if owner and profIdStr then
                playerName = owner
                profId = tonumber(profIdStr)
                professionName = PROFESSION_NAMES[profId]
                CB.Debug("Parsed new format link - Owner: " .. owner .. ", ProfID: " .. profIdStr .. " (as number: " .. tostring(profId) .. "), ProfName: " .. (professionName or "unknown"))
                
                -- ENHANCED DEBUGGING: Check all parsed values
                CB.Debug("=== LINK PARSING DETAILS ===")
                CB.Debug("  Raw linkData: " .. tostring(linkData))
                CB.Debug("  owner: " .. tostring(owner))
                CB.Debug("  profIdStr: " .. tostring(profIdStr))
                CB.Debug("  version: " .. tostring(version))
                CB.Debug("  timestamp: " .. tostring(timestamp))
                CB.Debug("  profId (number): " .. tostring(profId))
                CB.Debug("  PROFESSION_NAMES lookup result: " .. tostring(professionName))
                
                if not professionName then
                    CB.Debug("WARNING: ProfId " .. tostring(profId) .. " not found in PROFESSION_NAMES!")
                end
                
                -- Debug: Check what's in PROFESSION_NAMES
                CB.Debug("PROFESSION_NAMES contents:")
                for id, name in pairs(PROFESSION_NAMES) do
                    CB.Debug("  [" .. tostring(id) .. "] = " .. tostring(name))
                end
            end
        end
    end
    
    -- Fallback: Try old format for compatibility
    if not playerName or not professionName then
        if link:match("|HcraftersProfession:") then
            -- Parse the old link format: |HcraftersProfession:PlayerName:ProfessionName|h[Display Text]|h
            local linkData = link:match("|HcraftersProfession:([^|]+)|h")
            if linkData then
                playerName, professionName = linkData:match("^([^:]+):(.+)$")
                CB.Debug("Parsed old format link - Player: " .. (playerName or "nil") .. ", Profession: " .. (professionName or "nil"))
            end
        else
            -- Parse just the data part: craftersProfession:PlayerName:ProfessionName
            playerName, professionName = link:match("^craftersProfession:([^:]+):(.+)$")
            CB.Debug("Parsed data-only format - Player: " .. (playerName or "nil") .. ", Profession: " .. (professionName or "nil"))
        end
    end
    
    if not playerName or not professionName then
        CB.Debug("Could not parse profession link: " .. tostring(link))
        return
    end
    
    -- Normalize the player name for consistent cache lookup
    local normalizedPlayerName = NormalizePlayerName(playerName)
    CB.Debug("Profession link clicked: " .. playerName .. "'s " .. professionName .. " (normalized: " .. (normalizedPlayerName or "nil") .. ")")
    
    -- TEMPORARY DEBUG MODE: Force network testing for own profession links
    local debugNetworkMode = true  -- ENABLED: Test network flow with own links as if another player
    
    -- Try to show the profession data
    local snapshot = nil
    
    -- Check if it's our own profession (use normalized names for comparison)
    if IsSamePlayer(normalizedPlayerName, UnitName("player")) and not debugNetworkMode then
        snapshot = professionSnapshots[professionName]
        CB.Debug("Using local snapshot for own profession")
    else
        if debugNetworkMode and IsSamePlayer(normalizedPlayerName, UnitName("player")) then
            CB.Debug("DEBUG NETWORK MODE: Treating own profession as if from another player - will use network flow")
        end
        -- Check cached data for other players - use normalized name for cache lookup
        if cachedProfessions[normalizedPlayerName] and cachedProfessions[normalizedPlayerName][professionName] then
            snapshot = cachedProfessions[normalizedPlayerName][professionName]
            CB.Debug("Using cached data for " .. normalizedPlayerName .. " (normalized name)")
        elseif cachedProfessions[playerName] and cachedProfessions[playerName][professionName] then
            snapshot = cachedProfessions[playerName][professionName]
            CB.Debug("Using cached data for " .. playerName .. " (original name)")
        else
            CB.Debug("No cached data found for " .. normalizedPlayerName .. " or " .. playerName)
        end
    end
   
    if snapshot then
        -- Debug the snapshot structure
        CB.Debug("HandleProfessionLink: Found snapshot for " .. playerName .. "'s " .. professionName)
        CB.Debug("  Snapshot.recipes type: " .. type(snapshot.recipes))
        CB.Debug("  Snapshot.recipes count: " .. (snapshot.recipes and #snapshot.recipes or "nil"))
        CB.Debug("  Snapshot.categories type: " .. type(snapshot.categories or "nil"))
        CB.Debug("  Snapshot.categories available: " .. tostring(snapshot.categories and next(snapshot.categories) and true or false))
        
        -- FIXED: Use proper three-parameter calling convention
        PL.ShowProfessionData(playerName, professionName, snapshot)
        CB.Debug("Showing cached data for " .. playerName .. "'s " .. professionName)
    else
        -- No data available - check if we should request it
        local profId = PROFESSION_IDS[professionName]
        
        if profId then
            
            -- Check if we already have a pending request for this player/profession
            local alreadyRequesting = false
            for reqId, request in pairs(pendingRequests) do
                if (request.target == playerName or request.target == normalizedPlayerName) and request.professionName == professionName then
                    local requestAge = time() - request.timestamp
                    if requestAge < 30 then -- Still within timeout period
                        alreadyRequesting = true
                        CB.Debug("Request already pending for " .. playerName .. "'s " .. professionName)
                        CB.Debug("Already requesting " .. playerName .. "'s " .. professionName .. "...")
                        break
                    else
                        -- Old request, clean it up
                        pendingRequests[reqId] = nil
                        if pendingViewRequests[reqId] then
                            pendingViewRequests[reqId] = nil
                        end
                    end
                end
            end
            
            if not alreadyRequesting then
                CB.Debug("No data available for " .. playerName .. "'s " .. professionName)
                CB.Debug("Requesting fresh data...")
                
                -- Send automatic data request using normalized player name
                local reqId = PL.RequestProfessionData(normalizedPlayerName, profId)
                
                if reqId then
                    -- Store the request so we can show the data when it arrives
                    if not pendingViewRequests then
                        pendingViewRequests = {}
                    end
                    pendingViewRequests[reqId] = {
                        playerName = normalizedPlayerName,  -- Use normalized name for consistency
                        professionName = professionName,
                        timestamp = time()
                    }
                    CB.Debug("Marked request " .. reqId .. " as view request for normalized name: " .. normalizedPlayerName)
                end
            end
        else
            print("|cffffff00CraftersBoard|r No data available for " .. playerName .. "'s " .. professionName)
            print("|cffffff00CraftersBoard|r Requesting data or ensure the player has CraftersBoard addon...")
        end
    end
end


