-- CraftersBoard - Profession Links Module
-- Version: 1.0.0
-- Enables custom profession linking for Classic WoW Anniversary

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

-- Create ProfessionLinks namespace
CB.ProfessionLinks = CB.ProfessionLinks or {}
local PL = CB.ProfessionLinks

-- Constants
local ADDON_MESSAGE_PREFIX = "CBPROF"
local PROTOCOL_VERSION = 1
-- Use a more compatible link format for Classic Era
local LINK_FORMAT = "|Hcraftersboard:%s:%d:%d:%d|h[%s's %s (%d)]|h"

-- Data transmission constants
local MAX_ADDON_MESSAGE_SIZE = 200 -- Conservative size for Classic Era
local MAX_CHUNKS_PER_REQUEST = 100 -- Increased limit for larger profession data
local CHUNK_SEND_DELAY = 0.05 -- Reduced delay for faster transmission
local COMPRESSION_ENABLED = true -- Re-enabled to reduce data size
local CHUNK_TIMEOUT = 30 -- Seconds to wait for chunks

-- Profession ID mapping (using spell IDs for consistency)
local PROFESSION_IDS = {}
local PROFESSION_NAMES = {}

-- Initialize profession mappings safely
local function InitializeProfessionMappings()
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
    
    for _, prof in ipairs(professionSpells) do
        local spellName = GetSpellInfo(prof.spell)
        if spellName then
            -- Use spell name from game
            PROFESSION_IDS[spellName] = prof.id
            PROFESSION_NAMES[prof.id] = spellName
        else
            -- Fallback to hardcoded name for missing spells
            PROFESSION_IDS[prof.name] = prof.id
            PROFESSION_NAMES[prof.id] = prof.name
            -- Debug will be available when this is called later
            if Debug then
                Debug("Using fallback name for profession: " .. prof.name .. " (spell " .. prof.spell .. " not found)")
            end
        end
    end
    
    local count = 0
    for _ in pairs(PROFESSION_NAMES) do count = count + 1 end
    if Debug then
        Debug("Initialized " .. count .. " profession mappings")
    end
end

-- Module state
local isInitialized = false
local cachedProfessions = {} -- Cache for other players' professions
local pendingRequests = {}   -- Track outgoing requests
local pendingViewRequests = {} -- Track requests triggered by clicking profession links
local professionSnapshots = {} -- Our own profession data

-- Profession scanning state
local scanInProgress = false
local lastScanTime = 0
local SCAN_COOLDOWN = 5 -- Minimum seconds between scans

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

-- Debug function
local function Debug(msg)
    if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
        print("|cffffff00CraftersBoard|r |cff00ff00[ProfLinks]|r " .. tostring(msg))
    end
end

-- Compatibility function for sending addon messages (Classic Era compatible)
local function SendAddonMessageCompat(prefix, message, distribution, target)
    -- Try modern API first, then fall back to Classic Era API
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(prefix, message, distribution, target)
    elseif SendAddonMessage then
        return SendAddonMessage(prefix, message, distribution, target)
    else
        Debug("No addon message API available")
        return false
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

-- Initialize the module
function PL.Initialize()
    if isInitialized then return end
    
    Debug("Initializing Profession Links module...")
    
    -- Register addon message prefix (Classic Era compatible)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)
        Debug("Registered addon message prefix: " .. ADDON_MESSAGE_PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX)
        Debug("Registered addon message prefix (Classic Era): " .. ADDON_MESSAGE_PREFIX)
    else
        Debug("Warning: Could not register addon message prefix (no API available)")
    end
    
    -- Initialize cache system
    PL.InitializeCache()
    
    -- Start auto-save timer
    PL.StartAutoSave()
    
    -- Hook SetItemRef for custom link handling
    PL.HookLinkHandler()
    
    -- Set up chat message filters
    PL.SetupChatFilters()
    
    -- Register event handlers for automatic profession scanning
    PL.RegisterEvents()
    
    -- Start automatic profession scanning
    PL.StartAutomaticScanning()
    
    isInitialized = true
    Debug("Profession Links module initialized successfully")
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
    
    Debug("Hooked SetItemRef and tooltip handlers for custom link handling")
end

-- Set up chat message filters to handle profession links in chat
function PL.SetupChatFilters()
    local function ChatMessageFilter(chatFrame, event, msg, ...)
        if not msg then return false end
        
        -- Debug output to see if filter is being called
        if string.find(msg, "%[%[.+%]%]") then
            Debug("ChatFilter found double bracket pattern in: " .. msg)
        end
        
        -- Look for our profession link text pattern and convert to hyperlinks
        local newMsg = msg
        local changed = false
        
        -- Pattern to match: [[PlayerName's ProfessionName]]
        for playerName, professionName in string.gmatch(msg, "%[%[([^']+)'s ([^%]]+)%]%]") do
            Debug("Found profession link pattern: " .. playerName .. "'s " .. professionName)
            
            -- Check if this looks like a profession name
            local profId = PROFESSION_IDS[professionName]
            if profId then
                Debug("Converting to hyperlink: " .. professionName)
                
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
                
                Debug("New message: " .. newMsg)
            else
                Debug("Not a recognized profession: " .. professionName)
            end
        end
        
        -- If we made changes, return the modified message
        if changed then
            Debug("Returning modified message")
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
    
    Debug("Set up chat message filters for profession links")
end

-- Handle custom profession links
function PL.HandleCustomLink(link, text, button, chatFrame)
    Debug("HandleCustomLink called with link: " .. tostring(link))
    
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
    
    Debug("HandleCustomLink legacy format:")
    Debug("  linkType: " .. tostring(linkType))
    
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
        
        Debug("Handling legacy profession link: " .. link)
        
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
    
    Debug("Registered event handlers for auto-scanning")
end

-- Handle incoming addon messages
function PL.OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_MESSAGE_PREFIX then return end
    
    -- Ignore messages from ourselves
    if sender == UnitName("player") then
        return
    end
    
    Debug("Received addon message from " .. sender .. ": " .. string.sub(message, 1, 50) .. (string.len(message) > 50 and "..." or ""))
    
    local msgType, data = message:match("^([^:]+):(.+)")
    
    if not msgType or not data then
        Debug("Invalid message format: " .. tostring(message))
        return
    end
    
    Debug("Message type: " .. msgType .. ", data length: " .. string.len(data))
    
    if msgType == "REQ" then
        PL.HandleProfessionRequest(data, sender)
    elseif msgType == "DATA" then
        PL.HandleProfessionData(data, sender)
    else
        Debug("Unknown message type: " .. tostring(msgType))
    end
end

-- Handle profession data requests
function PL.HandleProfessionRequest(data, sender)
    Debug("Handling profession request from " .. sender)
    
    local profId, sinceTs, reqId = data:match("^(%d+):(%d+):(%w+)")
    if not profId or not reqId then
        Debug("Invalid request format")
        return
    end
    
    profId = tonumber(profId)
    sinceTs = tonumber(sinceTs)
    
    -- Find the requested profession
    local professionName = PROFESSION_NAMES[profId]
    if not professionName then
        Debug("Unknown profession ID: " .. profId)
        local response = string.format("DATA:%s:1/1:ERROR_UNKNOWN_PROFESSION", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    -- Get profession snapshot
    local snapshot = professionSnapshots[professionName]
    if not snapshot then
        Debug("No snapshot available for " .. professionName)
        local response = string.format("DATA:%s:1/1:ERROR_NO_DATA", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    -- Check if data is fresh enough
    if sinceTs > 0 and snapshot.timestamp <= sinceTs then
        Debug("Data not newer than requested timestamp")
        local response = string.format("DATA:%s:1/1:ERROR_NOT_NEWER", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    -- Serialize and compress the data
    local serializedData = PL.SerializeProfessionData(snapshot)
    if not serializedData then
        Debug("Failed to serialize profession data")
        local response = string.format("DATA:%s:1/1:ERROR_SERIALIZATION", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
        return
    end
    
    -- Check data size and create fallback if needed
    local chunks = PL.CreateChunks(serializedData, MAX_ADDON_MESSAGE_SIZE - 50)
    if #chunks > MAX_CHUNKS_PER_REQUEST then
        Debug("Data too large (" .. #chunks .. " chunks), creating fallback with basic info")
        
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
            Debug("Failed to serialize even minimal data")
            local response = string.format("DATA:%s:1/1:ERROR_SERIALIZATION", reqId)
            SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
            return
        end
        
        -- Check if minimal version is still too large
        chunks = PL.CreateChunks(serializedData, MAX_ADDON_MESSAGE_SIZE - 50)
        if #chunks > MAX_CHUNKS_PER_REQUEST then
            Debug("Even minimal data is too large")
            local response = string.format("DATA:%s:1/1:ERROR_DATA_TOO_LARGE", reqId)
            SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
            return
        end
        
        Debug("Using minimal data fallback (" .. #chunks .. " chunks)")
    end
    
    -- Send chunked data
    Debug("Sending profession data for " .. professionName .. " to " .. sender)
    if not PL.SendChunkedData(sender, reqId, serializedData) then
        Debug("Failed to send chunked data")
        local response = string.format("DATA:%s:1/1:ERROR_SEND_FAILED", reqId)
        SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, response, "WHISPER", sender)
    end
end

-- Handle profession data responses
function PL.HandleProfessionData(data, sender)
    Debug("Handling profession data from " .. sender)
    
    local reqId, chunk, encodedData = data:match("^(%w+):([^:]+):(.+)")
    if not reqId then
        Debug("Invalid data format")
        return
    end
    
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

-- Generate a profession link for the current player
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
        Debug("Using cached profession data for " .. professionName)
    else
        -- Fall back to current trade skill window - Classic Era API compatibility
        if GetTradeSkillLine then
            local skillName
            skillName, rank, maxRank = GetTradeSkillLine()
        else
            rank = 0
            maxRank = 300
        end
        Debug("Using live profession data for " .. professionName)
        
        -- Trigger a scan if window is open
        if GetTradeSkillLine and GetTradeSkillLine() == professionName then
            PL.ScanCurrentProfession()
        end
    end
    
    local timestamp = time()
    local owner = GetPlayerIdentifier()
    local playerName = UnitName("player") or "Unknown"
    
    Debug("Link generation parameters:")
    Debug("  owner: " .. tostring(owner))
    Debug("  profId: " .. tostring(profId))
    Debug("  timestamp: " .. tostring(timestamp))
    Debug("  playerName: " .. tostring(playerName))
    Debug("  professionName: " .. tostring(professionName))
    Debug("  rank: " .. tostring(rank or 0))
    
    local link = string.format(LINK_FORMAT, owner, profId, PROTOCOL_VERSION, timestamp, 
                              playerName, professionName, rank or 0)
    
    Debug("Generated profession link: " .. link)
    Debug("Link format validation:")
    Debug("  Contains |H: " .. tostring(string.find(link, "|H") ~= nil))
    Debug("  Contains |h: " .. tostring(string.find(link, "|h") ~= nil))
    Debug("  Link length: " .. string.len(link))
    
    return link
end

-- Show profession viewer window
function PL.ShowProfessionViewer(player, server, profId, timestamp)
    local professionName = PROFESSION_NAMES[profId] or "Unknown"
    
    Debug("Opening profession viewer for " .. player .. "'s " .. professionName)
    
    -- Check if we have cached data first
    local cachedData = PL.GetCachedProfessionData(player, professionName)
    if cachedData then
        Debug("Using cached data for " .. player .. "'s " .. professionName)
        PL.ShowProfessionData(player, professionName, cachedData)
        return
    end
    
    -- Show loading state
    PL.ShowViewerLoading(player, professionName)
    
    -- Request the data
    PL.RequestProfessionData(player, profId)
end

-- Request profession data from another player
function PL.RequestProfessionData(targetPlayer, profId)
    if not targetPlayer or targetPlayer == "" then
        Debug("RequestProfessionData: Invalid target player")
        return nil
    end
    
    if not profId then
        Debug("RequestProfessionData: Invalid profession ID")
        return nil
    end
    
    local reqId = tostring(math.random(100000, 999999))
    local message = string.format("REQ:%d:0:%s", profId, reqId)
    
    Debug("RequestProfessionData: Requesting " .. tostring(PROFESSION_NAMES[profId] or "Unknown") .. " from " .. targetPlayer)
    
    -- Store pending request
    pendingRequests[reqId] = {
        target = targetPlayer,
        profId = profId,
        timestamp = time(),
        professionName = PROFESSION_NAMES[profId]
    }
    
    local success = SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "WHISPER", targetPlayer)
    if success then
        Debug("Sent profession request to " .. targetPlayer .. " (reqId: " .. reqId .. ")")
        print("|cffffff00CraftersBoard|r Requesting " .. (PROFESSION_NAMES[profId] or "profession") .. " data from " .. targetPlayer .. "...")
    else
        Debug("Failed to send profession request")
        pendingRequests[reqId] = nil
        print("|cffffff00CraftersBoard|r Failed to send request to " .. targetPlayer)
        return nil
    end
    
    -- Set up timeout for the request
    C_Timer.After(30, function()
        if pendingRequests[reqId] then
            Debug("Request " .. reqId .. " timed out")
            print("|cffffff00CraftersBoard|r Request for " .. (PROFESSION_NAMES[profId] or "profession") .. " data from " .. targetPlayer .. " timed out")
            pendingRequests[reqId] = nil
            
            -- Also clean up view request if it exists
            if pendingViewRequests[reqId] then
                pendingViewRequests[reqId] = nil
            end
        end
    end)
    
    return reqId
end

-- Public API for generating and posting profession links
-- Slash command integration
function PL.HandleSlashCommand(args)
    local cmd, param = args:match("^(%w+)%s*(.*)")
    cmd = cmd and cmd:lower()
    
    if cmd == "link" then
        local link = PL.GenerateProfessionLink(param ~= "" and param or nil)
        if link then
            print("|cffffff00CraftersBoard|r Profession link: " .. link)
            print("|cffffff00CraftersBoard|r Click link to view profession")
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
    Debug("Trade skill window opened")
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
        Debug("Trade skill window updated, triggering scan")
        C_Timer.After(0.2, function()
            PL.ScanCurrentProfession()
        end)
    end
end

function PL.OnTradeSkillClose()
    Debug("Trade skill window closed")
    scanInProgress = false
    -- Remove the link button when window closes
    PL.RemoveLinkButtonFromProfessionFrame()
end

-- New event handlers for auto-scanning
function PL.OnPlayerEnteringWorld()
    Debug("Player entering world - scheduling profession scan")
    -- Delay the scan to ensure all profession data is loaded
    C_Timer.After(3, function()
        PL.ScanAllPlayerProfessions()
    end)
end

function PL.OnAddonLoaded()
    Debug("CraftersBoard addon loaded - scheduling profession scan")
    -- Delay the scan to ensure all systems are ready
    C_Timer.After(2, function()
        PL.ScanAllPlayerProfessions()
    end)
end

function PL.OnCraftShow()
    Debug("Craft window opened")
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
        Debug("Adding link button to TradeSkillFrame")
    
    -- Try CraftFrame (enchanting in Classic)
    elseif CraftFrame and CraftFrame:IsVisible() then
        targetFrame = CraftFrame
        if CraftFrameCloseButton then
            buttonAnchor = CraftFrameCloseButton
        elseif CraftFrame.CloseButton then
            buttonAnchor = CraftFrame.CloseButton
        end
        Debug("Adding link button to CraftFrame")
    end
    
    if not targetFrame then
        Debug("No suitable profession frame found for button placement")
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
    
    Debug("Successfully added CraftersBoard link button to profession frame")
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
    print("|cffffff00CraftersBoard|r Safe format: [[" .. playerName .. "'s " .. professionName .. "]]")
    
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
        Debug("Removed CraftersBoard link button from profession frame")
    end
end

function PL.OnCraftUpdate()
    Debug("Craft window updated")
    if scanInProgress then return end
    
    -- Scan on updates (recipes learned, etc.)
    C_Timer.After(0.2, function()
        PL.ScanCurrentProfession()
    end)
end

function PL.OnCraftClose()
    Debug("Craft window closed")
    scanInProgress = false
    -- Remove the link button when window closes
    PL.RemoveLinkButtonFromProfessionFrame()
end

function PL.OnSkillLinesChanged()
    Debug("Skill lines changed - may have learned/unlearned profession")
    -- Scan all professions when skill lines change
    C_Timer.After(1, function()
        PL.ScanAllPlayerProfessions()
    end)
end

function PL.OnLearnedSpell(spellId)
    Debug("Learned spell: " .. tostring(spellId))
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
    Debug("Starting automatic scan of all player professions...")
    
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
    
    Debug("Automatic profession scan completed - scanned " .. scannedCount .. " professions")
    
    if scannedCount > 0 then
        print("|cffffff00CraftersBoard|r Auto-scanned " .. scannedCount .. " professions")
    end
end

-- Scan a specific profession by name (without opening the UI)
function PL.ScanProfessionByName(professionName)
    if not professionName then return false end
    
    Debug("Scanning profession: " .. professionName)
    
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
                Debug("Created basic snapshot for " .. professionName .. " (" .. snapshot.rank .. "/" .. snapshot.maxRank .. ")")
                return true
            end
        end
    end
    
    Debug("Could not find profession: " .. professionName)
    return false
end

-- Get available cached profession data for player
function PL.GetPlayerProfessionData()
    local playerName = UnitName("player")
    local availableProfessions = {}
    
    Debug("GetPlayerProfessionData checking for player: " .. playerName)
    Debug("Available snapshots: " .. PL.GetTableSize(professionSnapshots))
    
    for profName, snapshot in pairs(professionSnapshots) do
        Debug("  Found profession: " .. profName)
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
    Debug("Starting automatic profession scanning...")
    
    -- Try to scan professions immediately if possible
    C_Timer.After(2, function()
        PL.ScanAllAvailableProfessions()
    end)
    
    -- Set up periodic scanning
    if not PL.scanTimer then
        PL.scanTimer = C_Timer.NewTicker(60, function() -- Check every minute
            PL.ScanAllAvailableProfessions()
        end)
        Debug("Started periodic profession scanning")
    end
end

-- Scan all available professions the player knows
function PL.ScanAllAvailableProfessions()
    Debug("Scanning all available professions...")
    
    local scannedCount = 0
    local totalProfessions = 0
    
    -- Get list of known professions by checking spells
    local knownProfessions = PL.GetKnownProfessions()
    totalProfessions = #knownProfessions
    
    if totalProfessions == 0 then
        Debug("No professions found to scan")
        return
    end
    
    Debug("Found " .. totalProfessions .. " known professions to scan")
    
    -- For each known profession, try to open it and scan
    for _, profData in ipairs(knownProfessions) do
        if PL.TryScanProfession(profData.name, profData.spellId) then
            scannedCount = scannedCount + 1
        end
    end
    
    if scannedCount > 0 then
        print("|cffffff00CraftersBoard|r Auto-scanned " .. scannedCount .. "/" .. totalProfessions .. " professions")
        Debug("Auto-scan completed: " .. scannedCount .. "/" .. totalProfessions .. " professions")
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
            Debug("Player knows profession: " .. prof.name)
        end
    end
    
    return knownProfs
end

-- Try to scan a specific profession
function PL.TryScanProfession(professionName, spellId)
    -- Check if we already have recent data
    local existingSnapshot = professionSnapshots[professionName]
    if existingSnapshot and (time() - existingSnapshot.timestamp) < 300 then
        Debug("Skipping " .. professionName .. " - already scanned recently")
        return false
    end
    
    Debug("TryScanProfession: Attempting to scan " .. professionName .. " (spell " .. spellId .. ")")
    
    -- For Classic Era, we need to check if the profession window is already open
    -- and scan directly if it matches what we want
    if TradeSkillFrame and TradeSkillFrame:IsVisible() then
        local currentProf = GetTradeSkillLine and GetTradeSkillLine()
        Debug("TryScanProfession: Trade skill window is open with: " .. tostring(currentProf))
        
        if currentProf == professionName then
            Debug("TryScanProfession: Current profession matches target, scanning...")
            if PL.ScanCurrentProfession() then
                Debug("Successfully scanned " .. professionName .. " from already open window")
                return true
            end
        end
    end
    
    -- Try to open the profession using spell casting (this might not work in all contexts)
    Debug("TryScanProfession: Attempting to cast profession spell for " .. professionName)
    
    -- Use a more reliable method - check if player can cast the spell
    if IsSpellKnown(spellId) then
        -- Create a temporary scanning state
        PL.pendingScanProfession = professionName
        
        -- Try to cast the spell
        local spellName = GetSpellInfo(spellId)
        if spellName then
            Debug("TryScanProfession: Casting spell: " .. spellName)
            CastSpell(spellName)
            
            -- Set up a timer to check if the window opened
            C_Timer.After(1, function()
                if TradeSkillFrame and TradeSkillFrame:IsVisible() then
                    local currentProf = GetTradeSkillLine and GetTradeSkillLine()
                    Debug("TryScanProfession: After spell cast, window shows: " .. tostring(currentProf))
                    
                    if currentProf == PL.pendingScanProfession then
                        if PL.ScanCurrentProfession() then
                            Debug("Successfully auto-scanned " .. professionName .. " after spell cast")
                            -- Close the profession window to avoid clutter
                            HideUIPanel(TradeSkillFrame)
                        end
                    end
                end
                PL.pendingScanProfession = nil
            end)
            
            return true
        else
            Debug("TryScanProfession: Could not get spell name for ID " .. spellId)
        end
    else
        Debug("TryScanProfession: Player does not know spell " .. spellId .. " for " .. professionName)
    end
    
    return false
end

function PL.ScanCurrentProfession()
    if scanInProgress then
        Debug("Scan already in progress, skipping")
        return false
    end
    
    local professionName
    if GetTradeSkillLine then
        professionName = GetTradeSkillLine()
    end
    if not professionName or professionName == "" then
        Debug("No profession window open")
        return false
    end
    
    scanInProgress = true
    lastScanTime = time()
    
    Debug("Starting profession scan for: " .. professionName)
    
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
    
    Debug("ScanCurrentProfession: Found " .. numSkills .. " trade skills to scan")
    
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
            
            Debug("  Scanned recipe " .. i .. ": " .. recipe.name .. " (category: " .. category .. ", reagents: " .. #recipe.reagents .. ")")
        else
            -- Check if this was a header
            local name, type = GetTradeSkillInfo(i)
            if type == "header" then
                headersFound = headersFound + 1
                Debug("  Found header " .. i .. ": " .. (name or "unnamed"))
            else
                Debug("  Recipe " .. i .. " returned nil (not a header)")
            end
        end
    end
    
    -- Store the snapshot using new cache system
    PL.CacheOwnSnapshot(professionName, snapshot)
    
    Debug(string.format("Scan completed for %s (%d/%d): %d recipes, %d headers", 
          professionName, rank, maxRank, recipesScanned, headersFound))
    
    print("|cffffff00CraftersBoard|r Scanned " .. professionName .. ": " .. recipesScanned .. " recipes")
    
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
        Debug("ScanRecipe: No name found for index " .. index)
        return nil
    end
    
    -- Skip headers (they have different type)
    if type == "header" then
        Debug("ScanRecipe: Skipping header '" .. name .. "' at index " .. index)
        return nil
    end
    
    Debug("ScanRecipe: Processing recipe '" .. name .. "' at index " .. index .. " (type: " .. tostring(type) .. ")")
    
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
    
    Debug("ScanRecipe: Successfully scanned '" .. name .. "' with " .. #recipe.reagents .. " reagents (category: " .. tostring(recipe.category) .. ")")
    
    return recipe
end

-- Get reagents for a recipe
function PL.GetRecipeReagents(index)
    local reagents = {}
    
    -- Check if the function exists and index is valid
    if not GetTradeSkillNumReagents or not index then
        Debug("GetRecipeReagents: Missing API or invalid index")
        return reagents
    end
    
    local numReagents = GetTradeSkillNumReagents(index)
    if not numReagents or numReagents == 0 then
        Debug("GetRecipeReagents: No reagents for index " .. index)
        return reagents
    end
    
    Debug("GetRecipeReagents: Processing " .. numReagents .. " reagents for index " .. index)
    
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
            Debug("  Added reagent: " .. name .. " (" .. (count or 0) .. " needed, " .. (playerCount or 0) .. " available)")
        else
            Debug("  Skipped empty reagent at slot " .. i)
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
if CB.isInitialized then
    PL.Initialize()
else
    -- Wait for CraftersBoard to initialize
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == ADDON_NAME and CB.isInitialized then
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
local function SimpleCompress(data)
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

local function SimpleDecompress(data)
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

-- Serialize profession data to string (optimized for size)
function PL.SerializeProfessionData(snapshot)
    if not snapshot then return nil end
    
    Debug("Serializing profession data: " .. tostring(snapshot.name))
    
    -- Use new dictionary-based compression for massive size reduction
    local compressedData
    if CB.DataDictionary and CB.DataDictionary.CompressProfessionData then
        compressedData = CB.DataDictionary.CompressProfessionData(snapshot)
        Debug("Applied dictionary compression")
    else
        Debug("DataDictionary not available, using fallback compression")
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
    
    Debug("Prepared " .. #compressedData.rc .. " recipes for serialization")
    
    -- Convert to string (simple table serialization)
    local serialized = PL.TableToString(compressedData)
    
    if not serialized then
        Debug("Failed to serialize data to string")
        return nil
    end
    
    local originalSize = string.len(serialized)
    
    -- Apply standard compression on top of dictionary compression
    if COMPRESSION_ENABLED then
        local compressed = SimpleCompress(serialized)
        if compressed and string.len(compressed) < originalSize then
            serialized = compressed
            Debug("Applied secondary compression: " .. originalSize .. " -> " .. string.len(serialized) .. " bytes")
        else
            Debug("Secondary compression failed or not beneficial, using dictionary-compressed data")
        end
    end
    
    Debug("Final serialized profession data: " .. string.len(serialized) .. " bytes")
    return serialized
end

-- Deserialize profession data from string (using dictionary decompression)
function PL.DeserializeProfessionData(serializedData)
    if not serializedData or serializedData == "" then return nil end
    
    local data
    
    Debug("Deserializing profession data: " .. string.len(serializedData) .. " bytes")
    
    -- Decompress standard compression first if needed
    if COMPRESSION_ENABLED then
        local decompressed = SimpleDecompress(serializedData)
        if decompressed then
            serializedData = decompressed
            Debug("Applied standard decompression")
        else
            Debug("Standard decompression failed, trying uncompressed data")
        end
    end
    
    -- Parse string back to table
    data = PL.StringToTable(serializedData)
    if not data then
        Debug("Failed to deserialize profession data")
        return nil
    end
    
    -- Use dictionary decompression if available
    if CB.DataDictionary and CB.DataDictionary.DecompressProfessionData then
        local snapshot = CB.DataDictionary.DecompressProfessionData(data)
        if snapshot then
            Debug("Applied dictionary decompression successfully")
            return snapshot
        else
            Debug("Dictionary decompression failed, using fallback")
        end
    end
    
    -- Fallback decompression method (for old data or if dictionary unavailable)
    Debug("Using fallback decompression method")
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
    
    Debug("Fallback decompression completed: " .. #snapshot.recipes .. " recipes")
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
    
    -- Use loadstring to parse the table (be careful with security)
    local fn, err = loadstring("return " .. str)
    if not fn then
        Debug("Failed to parse table string: " .. (err or "unknown error"))
        return nil
    end
    
    local ok, result = pcall(fn)
    if not ok then
        Debug("Failed to execute table string: " .. (result or "unknown error"))
        return nil
    end
    
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
    
    Debug("Split " .. dataLen .. " bytes into " .. #chunks .. " chunks")
    return chunks
end

-- Send chunked data with throttling to prevent disconnection
function PL.SendChunkedData(targetPlayer, reqId, data)
    local chunks = PL.CreateChunks(data, MAX_ADDON_MESSAGE_SIZE - 50) -- Leave room for headers
    
    if #chunks == 0 then
        Debug("No data to send")
        return false
    end
    
    -- Check if we're sending too much data
    if #chunks > MAX_CHUNKS_PER_REQUEST then
        Debug("Data too large: " .. #chunks .. " chunks (max: " .. MAX_CHUNKS_PER_REQUEST .. ")")
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
    
    Debug("Sending " .. #chunks .. " chunks to " .. targetPlayer .. " with throttling")
    
    -- Send chunks with delays to prevent flooding/disconnection
    for i, chunk in ipairs(chunks) do
        local message = string.format("DATA:%s:%d/%d:%s", reqId, i, #chunks, chunk)
        
        -- Use timer for delayed sending to prevent flooding
        C_Timer.After((i - 1) * CHUNK_SEND_DELAY, function()
            local success = SendAddonMessageCompat(ADDON_MESSAGE_PREFIX, message, "WHISPER", targetPlayer)
            if success then
                Debug("Sent chunk " .. i .. "/" .. #chunks .. " to " .. targetPlayer)
            else
                Debug("Failed to send chunk " .. i .. "/" .. #chunks .. " to " .. targetPlayer)
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
        Debug("Invalid chunk info: " .. chunkInfo)
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
        Debug("Received chunk " .. current .. "/" .. total .. " from " .. sender)
    end
    
    -- Check if we have all chunks
    if incoming.received >= incoming.total then
        Debug("All chunks received, reassembling data")
        
        -- Reassemble data
        local parts = {}
        for i = 1, incoming.total do
            if incoming.chunks[i] then
                table.insert(parts, incoming.chunks[i])
            else
                Debug("Missing chunk " .. i .. ", data incomplete")
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
    Debug("Processing complete profession data from " .. sender .. " (size: " .. string.len(serializedData) .. " bytes)")
    
    local snapshot = PL.DeserializeProfessionData(serializedData)
    if not snapshot then
        Debug("Failed to deserialize profession data")
        print("|cffffff00CraftersBoard|r Failed to decode profession data from " .. sender)
        PL.ShowViewerError(sender, "Unknown", "Failed to decode profession data")
        return
    end
    
    Debug("Deserialized profession data: " .. snapshot.name .. " with " .. #snapshot.recipes .. " recipes")
    
    -- Validate the data
    if not snapshot.name or snapshot.name == "" then
        Debug("Invalid profession data: missing name")
        print("|cffffff00CraftersBoard|r Invalid profession data from " .. sender)
        return
    end
    
    if #snapshot.recipes == 0 then
        Debug("Warning: Received profession data with no recipes")
        print("|cffffff00CraftersBoard|r " .. sender .. "'s " .. snapshot.name .. " has no recipes")
    else
        print("|cffffff00CraftersBoard|r Received " .. sender .. "'s " .. snapshot.name .. " (" .. #snapshot.recipes .. " recipes)")
    end
    
    -- Cache the profession data using new system
    PL.CacheProfessionData(sender, snapshot.name, snapshot)
    
    -- Check if this was a request triggered by clicking a profession link
    local viewRequest = pendingViewRequests[reqId]
    if viewRequest then
        -- This was from clicking a profession link - show the viewer
        print("|cffffff00CraftersBoard|r Opening profession viewer for " .. viewRequest.playerName .. "'s " .. viewRequest.professionName)
        PL.ShowProfessionData(sender, snapshot.name, snapshot)
        
        -- Clean up the view request
        pendingViewRequests[reqId] = nil
    else
        -- This was a regular request - show in profession viewer as before
        PL.ShowProfessionData(sender, snapshot.name, snapshot)
    end
    
    -- Clean up pending request
    pendingRequests[reqId] = nil
    
    Debug("Successfully processed and displayed " .. snapshot.name .. " data from " .. sender)
end

-- UI Viewer for profession data
local professionViewerFrame = nil
local viewerScrollFrame = nil
local viewerContent = nil

-- Create the profession viewer window with modern Blizzard-style UI
function PL.CreateProfessionViewer()
    if professionViewerFrame then return professionViewerFrame end
    
    Debug("Creating modern profession viewer with authentic Blizzard styling...")
    
    -- Create main frame using authentic Blizzard window styling
    local frame = CreateFrame("Frame", "CraftersBoardProfessionViewer", UIParent)
    frame:SetSize(850, 560) -- Larger, more modern size
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
    
    -- Create transparent frame background
    local bgTexture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bgTexture:SetAllPoints()
    bgTexture:SetColorTexture(0, 0, 0, 0.85) -- Semi-transparent black background
    
    -- Create simple border instead of textured one
    local borderTexture = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    borderTexture:SetAllPoints()
    borderTexture:SetColorTexture(0.2, 0.2, 0.2, 0.9) -- Dark gray border
    
    -- Remove decorative borders for cleaner look
    -- Top border decoration (commented out)
    -- local topBorder = frame:CreateTexture(nil, "ARTWORK", nil, -6)
    -- topBorder:SetSize(850, 64)
    -- topBorder:SetPoint("TOP", frame, "TOP", 0, 32)
    -- topBorder:SetTexture("Interface\\FrameGeneral\\UI-Frame-TopFrame")
    
    -- Remove all decorative borders for clean transparent look
    -- (All border decorations commented out)
    
    -- Create elegant title with proper styling
    frame.TitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.TitleText:SetPoint("TOP", frame, "TOP", 0, -20)
    frame.TitleText:SetText("Profession Viewer")
    frame.TitleText:SetTextColor(1, 0.82, 0) -- Blizzard gold
    frame.TitleText:SetShadowOffset(1, -1)
    frame.TitleText:SetShadowColor(0, 0, 0, 1)
    
    -- Create modern close button with hover effects
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    closeBtn:SetScript("OnClick", function(self)
        frame:Hide()
    end)
    closeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Close")
        GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Create "Generate Link" button
    local linkBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    linkBtn:SetSize(100, 22)
    linkBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -10, -1)
    linkBtn:SetText("Generate Link")
    linkBtn:SetScript("OnClick", function(self)
        PL.GenerateAndShowProfessionLink(frame)
    end)
    linkBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Generate a shareable profession link")
        GameTooltip:AddLine("Click the generated link to view profession", 1, 1, 1)
        GameTooltip:AddLine("Shift+click to insert in chat (when chat is active)", 1, 1, 1)
        GameTooltip:Show()
    end)
    linkBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    frame.linkBtn = linkBtn
    
    -- Create tabbed interface for better organization
    local tabContainer = CreateFrame("Frame", nil, frame)
    tabContainer:SetSize(820, 40)
    tabContainer:SetPoint("TOP", frame, "TOP", 0, -60)
    
    -- Transparent tab background
    local tabBg = tabContainer:CreateTexture(nil, "BACKGROUND")
    tabBg:SetAllPoints()
    tabBg:SetColorTexture(0.1, 0.1, 0.1, 0.6) -- Semi-transparent dark background
    
    -- Create tabs
    local tabs = {}
    local tabNames = {"Overview", "Recipes", "Statistics"}
    for i, tabName in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, tabContainer)
        tab:SetSize(120, 32)
        tab:SetPoint("LEFT", tabContainer, "LEFT", (i-1) * 125 + 20, 0)
        
        -- Tab textures
        tab:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTab")
        tab:SetHighlightTexture("Interface\\ChatFrame\\ChatFrameTab")
        tab:SetPushedTexture("Interface\\ChatFrame\\ChatFrameTab")
        
        -- Tab text
        local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tabText:SetPoint("CENTER", tab, "CENTER", 0, 0)
        tabText:SetText(tabName)
        tab.text = tabText
        
        tab.tabIndex = i
        tab:SetScript("OnClick", function(self)
            PL.SwitchViewerTab(self.tabIndex)
        end)
        
        tabs[i] = tab
    end
    frame.tabs = tabs
    frame.activeTab = 1
    
    -- Create main content area with modern styling
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -105)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25, 25)
    
    -- Transparent content background
    local contentBg = contentFrame:CreateTexture(nil, "BACKGROUND")
    contentBg:SetAllPoints()
    contentBg:SetColorTexture(0.05, 0.05, 0.05, 0.7) -- Very subtle transparent background
    
    -- Simple content border
    local contentBorder = contentFrame:CreateTexture(nil, "BORDER")
    contentBorder:SetAllPoints()
    contentBorder:SetColorTexture(0.3, 0.3, 0.3, 0.8) -- Simple gray border
    
    frame.contentFrame = contentFrame
    
    -- Create overview panel (default active)
    local overviewPanel = PL.CreateOverviewPanel(contentFrame)
    frame.overviewPanel = overviewPanel
    
    -- Create recipes panel
    local recipesPanel = PL.CreateRecipesPanel(contentFrame)
    frame.recipesPanel = recipesPanel
    
    -- Create statistics panel
    local statsPanel = PL.CreateStatisticsPanel(contentFrame)
    frame.statsPanel = statsPanel
    
    -- Initially show overview
    overviewPanel:Show()
    recipesPanel:Hide()
    statsPanel:Hide()
    
    -- Loading indicator with animation
    local loadingText = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    loadingText:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
    loadingText:SetText("Loading profession data...")
    loadingText:SetTextColor(1, 0.82, 0)
    loadingText:Hide()
    frame.loadingText = loadingText
    
    -- Create loading animation
    local loadingDots = ""
    local loadingFrame = CreateFrame("Frame")
    loadingFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.5 then
            self.elapsed = 0
            loadingDots = loadingDots .. "."
            if string.len(loadingDots) > 3 then
                loadingDots = ""
            end
            if frame.loadingText and frame.loadingText:IsVisible() then
                frame.loadingText:SetText("Loading profession data" .. loadingDots)
            end
        end
    end)
    frame.loadingFrame = loadingFrame
    
    -- Store references
    professionViewerFrame = frame
    viewerScrollFrame = recipesPanel.scrollFrame -- For backward compatibility
    viewerContent = recipesPanel.scrollContent -- For backward compatibility
    
    Debug("Created modern profession viewer with:")
    Debug("  Size: " .. frame:GetWidth() .. "x" .. frame:GetHeight())
    Debug("  Tabbed interface with 3 panels")
    Debug("  Transparent backgrounds for clean look")
    Debug("  Animated loading indicators")
    Debug("  Modern close button with tooltips")
    
    return frame
end

-- Create overview panel with profession summary
function PL.CreateOverviewPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    
    -- Transparent panel background
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0) -- Fully transparent background
    
    -- Large profession icon
    local profIcon = panel:CreateTexture(nil, "ARTWORK")
    profIcon:SetSize(128, 128)
    profIcon:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -20)
    profIcon:SetTexture("Interface\\Icons\\Trade_Alchemy") -- Default
    panel.profIcon = profIcon
    
    -- Icon border decoration
    local iconBorder = panel:CreateTexture(nil, "BORDER")
    iconBorder:SetSize(140, 140)
    iconBorder:SetPoint("CENTER", profIcon, "CENTER", 0, 0)
    iconBorder:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
    iconBorder:SetTexCoord(0, 0.5625, 0, 0.5625)
    iconBorder:SetVertexColor(1, 0.82, 0, 1)
    
    -- Profession name
    local profName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    profName:SetPoint("TOPLEFT", profIcon, "TOPRIGHT", 20, -10)
    profName:SetText("Unknown Profession")
    profName:SetTextColor(1, 0.82, 0) -- Blizzard gold
    panel.profName = profName
    
    -- Player name
    local playerName = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    playerName:SetPoint("TOPLEFT", profName, "BOTTOMLEFT", 0, -10)
    playerName:SetText("Player Name")
    playerName:SetTextColor(0.8, 0.8, 1) -- Light blue
    panel.playerName = playerName
    
    -- Skill level with progress bar
    local skillText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skillText:SetPoint("TOPLEFT", playerName, "BOTTOMLEFT", 0, -15)
    skillText:SetText("Skill Level:")
    skillText:SetTextColor(1, 1, 1)
    
    local skillLevel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    skillLevel:SetPoint("LEFT", skillText, "RIGHT", 10, 0)
    skillLevel:SetText("0 / 300")
    panel.skillLevel = skillLevel
    
    -- Progress bar
    local progressBar = CreateFrame("StatusBar", nil, panel)
    progressBar:SetSize(300, 20)
    progressBar:SetPoint("TOPLEFT", skillText, "BOTTOMLEFT", 0, -10)
    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBar:SetStatusBarColor(0.2, 0.8, 0.2, 1) -- Green
    progressBar:SetMinMaxValues(0, 300)
    progressBar:SetValue(0)
    
    -- Progress bar background
    local progressBg = progressBar:CreateTexture(nil, "BACKGROUND")
    progressBg:SetAllPoints()
    progressBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBg:SetVertexColor(0.3, 0.3, 0.3, 0.8)
    
    -- Progress bar border
    local progressBorder = CreateFrame("Frame", nil, panel)
    progressBorder:SetPoint("TOPLEFT", progressBar, "TOPLEFT", -2, 2)
    progressBorder:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", 2, -2)
    local borderTex = progressBorder:CreateTexture(nil, "OVERLAY")
    borderTex:SetAllPoints()
    borderTex:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    borderTex:SetVertexColor(0.6, 0.6, 0.6, 1)
    
    panel.progressBar = progressBar
    
    -- Statistics section
    local statsHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statsHeader:SetPoint("TOPLEFT", progressBar, "BOTTOMLEFT", 0, -30)
    statsHeader:SetText("Statistics")
    statsHeader:SetTextColor(1, 0.82, 0)
    
    -- Recipe count
    local recipeCount = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recipeCount:SetPoint("TOPLEFT", statsHeader, "BOTTOMLEFT", 0, -10)
    recipeCount:SetText("Total Recipes: 0")
    panel.recipeCount = recipeCount
    
    -- Categories count
    local categoryCount = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryCount:SetPoint("TOPLEFT", recipeCount, "BOTTOMLEFT", 0, -5)
    categoryCount:SetText("Categories: 0")
    panel.categoryCount = categoryCount
    
    -- Last updated
    local lastUpdated = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lastUpdated:SetPoint("TOPLEFT", categoryCount, "BOTTOMLEFT", 0, -5)
    lastUpdated:SetText("Last Updated: Never")
    lastUpdated:SetTextColor(0.7, 0.7, 0.7)
    panel.lastUpdated = lastUpdated
    
    -- Recipe difficulty breakdown
    local difficultyHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    difficultyHeader:SetPoint("TOPLEFT", lastUpdated, "BOTTOMLEFT", 0, -30)
    difficultyHeader:SetText("Recipe Difficulty")
    difficultyHeader:SetTextColor(1, 0.82, 0)
    
    -- Difficulty bars
    local difficulties = {
        {name = "Optimal (Orange)", color = {1, 0.5, 0}},
        {name = "Medium (Yellow)", color = {1, 1, 0}},
        {name = "Easy (Green)", color = {0, 1, 0}},
        {name = "Trivial (Gray)", color = {0.5, 0.5, 0.5}}
    }
    
    panel.difficultyBars = {}
    for i, diff in ipairs(difficulties) do
        local yOffset = -15 - (i-1) * 25
        
        -- Difficulty label
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", difficultyHeader, "BOTTOMLEFT", 0, yOffset)
        label:SetText(diff.name .. ": 0")
        label:SetTextColor(diff.color[1], diff.color[2], diff.color[3])
        
        -- Difficulty bar
        local bar = CreateFrame("StatusBar", nil, panel)
        bar:SetSize(200, 12)
        bar:SetPoint("LEFT", label, "RIGHT", 20, 0)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(diff.color[1], diff.color[2], diff.color[3], 0.8)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(0)
        
        -- Bar background
        local barBg = bar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints()
        barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barBg:SetVertexColor(0.2, 0.2, 0.2, 0.8)
        
        panel.difficultyBars[diff.name:lower():match("(%w+)")] = {label = label, bar = bar}
    end
    
    return panel
end

-- Create recipes panel with scrollable list
function PL.CreateRecipesPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    
    -- Transparent panel background
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0) -- Fully transparent background
    
    -- Search/filter section
    local filterFrame = CreateFrame("Frame", nil, panel)
    filterFrame:SetSize(780, 40)
    filterFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    
    -- Search box
    local searchBox = CreateFrame("EditBox", nil, filterFrame)
    searchBox:SetSize(200, 32)
    searchBox:SetPoint("LEFT", filterFrame, "LEFT", 0, 0)
    searchBox:SetFontObject("GameFontNormal")
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    
    -- Search box background
    local searchBg = searchBox:CreateTexture(nil, "BACKGROUND")
    searchBg:SetAllPoints()
    searchBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    searchBg:SetVertexColor(0, 0, 0, 0.8)
    
    -- Search box border
    local searchBorder = searchBox:CreateTexture(nil, "BORDER")
    searchBorder:SetAllPoints()
    searchBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    searchBorder:SetVertexColor(0.6, 0.6, 0.6, 1)
    
    searchBox:SetScript("OnTextChanged", function(self)
        PL.FilterRecipes(self:GetText())
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        PL.FilterRecipes("")
    end)
    
    panel.searchBox = searchBox
    
    -- Search label
    local searchLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("BOTTOM", searchBox, "TOP", 0, 5)
    searchLabel:SetText("Search Recipes:")
    searchLabel:SetTextColor(1, 1, 1)
    
    -- Category filter dropdown placeholder
    local categoryLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    categoryLabel:SetPoint("LEFT", searchBox, "RIGHT", 30, 0)
    categoryLabel:SetText("Filter by Category: All")
    categoryLabel:SetTextColor(1, 1, 1)
    panel.categoryLabel = categoryLabel
    
    -- Create scroll frame for recipes
    local scrollFrame = CreateFrame("ScrollFrame", "ProfessionViewerRecipesScrollFrame", panel)
    scrollFrame:SetPoint("TOPLEFT", filterFrame, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -25, 10)
    
    -- Create scroll bar
    local scrollBar = CreateFrame("Slider", "ProfessionViewerRecipesScrollBar", panel)
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 5, -16)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 5, 16)
    scrollBar:SetWidth(16)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    
    -- Scroll bar background
    local scrollBg = scrollBar:CreateTexture(nil, "BACKGROUND")
    scrollBg:SetAllPoints()
    scrollBg:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    
    -- Configure scroll bar
    scrollBar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    
    scrollFrame.ScrollBar = scrollBar
    
    -- Create scroll content
    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(750, 1)
    scrollFrame:SetScrollChild(scrollContent)
    
    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = current - (delta * 30)
        
        if newScroll < 0 then
            newScroll = 0
        elseif newScroll > maxScroll then
            newScroll = maxScroll
        end
        
        self:SetVerticalScroll(newScroll)
        scrollBar:SetValue(newScroll)
    end)
    
    -- Update scroll bar when content changes
    scrollFrame.UpdateScrollChildRect = function(self)
        local range = self:GetVerticalScrollRange()
        scrollBar:SetMinMaxValues(0, range)
        scrollBar:SetValue(self:GetVerticalScroll())
    end
    
    panel.scrollFrame = scrollFrame
    panel.scrollContent = scrollContent
    
    return panel
end

-- Create statistics panel with detailed analysis
function PL.CreateStatisticsPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    
    -- Transparent panel background
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0) -- Fully transparent background
    
    -- Statistics content will be populated dynamically
    local statsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statsText:SetPoint("CENTER", panel, "CENTER", 0, 0)
    statsText:SetText("Detailed statistics coming soon...")
    statsText:SetTextColor(1, 0.82, 0)
    panel.statsText = statsText
    
    return panel
end

-- Switch between viewer tabs
function PL.SwitchViewerTab(tabIndex)
    local frame = professionViewerFrame
    if not frame or not frame.tabs then return end
    
    -- Update tab appearance
    for i, tab in ipairs(frame.tabs) do
        if i == tabIndex then
            tab.text:SetTextColor(1, 0.82, 0) -- Active tab (gold)
            tab:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTab")
        else
            tab.text:SetTextColor(0.7, 0.7, 0.7) -- Inactive tab (gray)
            tab:SetNormalTexture("Interface\\ChatFrame\\ChatFrameTabInactive")
        end
    end
    
    -- Show/hide panels
    if frame.overviewPanel then frame.overviewPanel:SetShown(tabIndex == 1) end
    if frame.recipesPanel then frame.recipesPanel:SetShown(tabIndex == 2) end
    if frame.statsPanel then frame.statsPanel:SetShown(tabIndex == 3) end
    
    frame.activeTab = tabIndex
    
    Debug("Switched to tab " .. tabIndex)
end

-- Filter recipes in the recipes panel
function PL.FilterRecipes(searchText)
    -- Implementation will be added when populating recipe data
    Debug("Filtering recipes with: " .. (searchText or ""))
end

-- Show profession viewer with data using modern tabbed interface
function PL.ShowProfessionData(playerName, professionName, snapshot)
    local frame = PL.CreateProfessionViewer()
    
    -- Store current data for link generation
    frame.currentPlayerName = playerName
    frame.currentProfessionName = professionName
    frame.currentSnapshot = snapshot
    
    -- Safety check: ensure viewer components were created
    if not frame.overviewPanel or not frame.recipesPanel then
        Debug("ERROR: Viewer panels not properly initialized")
        return
    end
    
    Debug("ShowProfessionData called with modern UI:")
    Debug("  playerName: " .. tostring(playerName))
    Debug("  professionName: " .. tostring(professionName))
    Debug("  snapshot exists: " .. tostring(snapshot ~= nil))
    if snapshot then
        Debug("  snapshot.name: " .. tostring(snapshot.name))
        Debug("  snapshot.rank: " .. tostring(snapshot.rank))
        Debug("  snapshot.maxRank: " .. tostring(snapshot.maxRank))
        Debug("  snapshot.recipes count: " .. tostring(#snapshot.recipes))
    end
    
    -- Update main window title
    frame.TitleText:SetText(playerName .. "'s " .. professionName)
    
    if not snapshot then
        -- Show error state
        frame.loadingText:SetText("No profession data available")
        frame.loadingText:SetTextColor(1, 0.5, 0.5)
        frame.loadingText:Show()
        frame:Show()
        return
    end
    
    -- Hide loading text
    frame.loadingText:Hide()
    
    -- Update overview panel
    PL.UpdateOverviewPanel(frame.overviewPanel, playerName, snapshot)
    
    -- Update recipes panel
    PL.UpdateRecipesPanel(frame.recipesPanel, snapshot)
    
    -- Update statistics panel
    PL.UpdateStatisticsPanel(frame.statsPanel, snapshot)
    
    -- Show the frame and ensure overview tab is active
    PL.SwitchViewerTab(1)
    frame:Show()
    
    Debug("Profession viewer updated with modern tabbed interface")
end

-- Update overview panel with profession data
function PL.UpdateOverviewPanel(panel, playerName, snapshot)
    if not panel then return end
    
    -- Set profession icon
    local professionIcons = {
        ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
        ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
        ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
        ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
        ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
        ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
        ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
    }
    
    local iconPath = professionIcons[snapshot.name] or "Interface\\Icons\\INV_Misc_QuestionMark"
    panel.profIcon:SetTexture(iconPath)
    
    -- Update text fields
    panel.profName:SetText(snapshot.name or "Unknown Profession")
    panel.playerName:SetText(playerName or "Unknown Player")
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
    
    Debug("Updated overview panel for " .. (snapshot.name or "unknown"))
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
    
    Debug("Building recipes panel with " .. #recipes .. " recipes in " .. PL.GetTableSize(categories) .. " categories")
    
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
    
    Debug("Updated recipes panel with content height: " .. contentHeight)
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
    
    Debug("Updated statistics panel")
end

-- Create a modern recipe button with authentic Blizzard styling
function PL.CreateModernRecipeButton(recipe, parent, x, y)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(700, 22)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    
    -- Button background with hover effect
    button:SetNormalTexture("Interface\\Buttons\\UI-Listbox-Highlight")
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button:SetPushedTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    
    -- Recipe icon (if we had one)
    local recipeIcon = button:CreateTexture(nil, "ARTWORK")
    recipeIcon:SetSize(16, 16)
    recipeIcon:SetPoint("LEFT", button, "LEFT", 5, 0)
    recipeIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_01") -- Default recipe icon
    
    -- Recipe name
    local recipeName = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recipeName:SetPoint("LEFT", recipeIcon, "RIGHT", 5, 0)
    recipeName:SetText(recipe.name or "Unknown Recipe")
    recipeName:SetJustifyH("LEFT")
    recipeName:SetWidth(400)
    
    -- Set color based on difficulty
    local difficulty = recipe.type or (recipe.difficulty and recipe.difficulty.color) or "unknown"
    if difficulty == "optimal" then
        recipeName:SetTextColor(1, 0.5, 0) -- Orange
    elseif difficulty == "medium" then
        recipeName:SetTextColor(1, 1, 0) -- Yellow
    elseif difficulty == "easy" then
        recipeName:SetTextColor(0, 1, 0) -- Green
    elseif difficulty == "trivial" then
        recipeName:SetTextColor(0.5, 0.5, 0.5) -- Gray
    else
        recipeName:SetTextColor(1, 1, 1) -- White
    end
    
    -- Recipe info (reagents, etc.)
    local recipeInfo = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    recipeInfo:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    recipeInfo:SetJustifyH("RIGHT")
    
    local reagentCount = recipe.reagents and #recipe.reagents or 0
    local infoText = reagentCount > 0 and (reagentCount .. " reagents") or "No reagents"
    recipeInfo:SetText(infoText)
    recipeInfo:SetTextColor(0.7, 0.7, 0.7)
    
    -- Tooltip on hover
    button:SetScript("OnEnter", function(self)
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
        GameTooltip:Hide()
    end)
    
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
    
    Debug("Loaded profession cache: " .. PL.GetCacheStatistics())
    
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
    
    Debug("Saved profession cache to SavedVariables")
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
                Debug("Removed expired cache entry: " .. playerName .. "'s " .. profName)
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
            Debug("Removed expired own snapshot: " .. profName)
        end
    end
    
    if removed > 0 then
        Debug("Cleaned up " .. removed .. " expired cache entries")
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
    
    Debug("Cached " .. professionName .. " data for " .. playerName)
end

-- Get cached profession data for a player
function PL.GetCachedProfessionData(playerName, professionName)
    if not playerName or not professionName then return nil end
    
    if cachedProfessions[playerName] and cachedProfessions[playerName][professionName] then
        return cachedProfessions[playerName][professionName]
    end
    
    return nil
end

function PL.CacheOwnSnapshot(professionName, snapshot)
    if not snapshot then 
        Debug("CacheOwnSnapshot called with nil snapshot for: " .. tostring(professionName))
        return 
    end
    
    Debug("CacheOwnSnapshot storing data for: " .. professionName)
    Debug("  snapshot.name: " .. tostring(snapshot.name))
    Debug("  snapshot.rank: " .. tostring(snapshot.rank))
    Debug("  snapshot.maxRank: " .. tostring(snapshot.maxRank))
    Debug("  snapshot.recipes count: " .. tostring(#snapshot.recipes))
    if snapshot.categories then
        Debug("  snapshot.categories count: " .. tostring(PL.GetTableSize(snapshot.categories)))
    end
    
    -- Store our own snapshot
    professionSnapshots[professionName] = snapshot
    
    -- Verify storage
    local stored = professionSnapshots[professionName]
    if stored then
        Debug("  Verified storage - stored.name: " .. tostring(stored.name))
        Debug("  Verified storage - stored.rank: " .. tostring(stored.rank))
    else
        Debug("  ERROR: Failed to store snapshot!")
    end
    
    -- Save to disk
    PL.SaveCache()
    
    Debug("Cached own " .. professionName .. " snapshot")
end

-- Auto-save functionality
local autoSaveTimer = nil

function PL.StartAutoSave()
    if autoSaveTimer then return end
    
    -- Save cache every 5 minutes
    autoSaveTimer = C_Timer.NewTicker(300, function()
        PL.SaveCache()
    end)
    
    Debug("Started auto-save timer for profession cache")
end

function PL.StopAutoSave()
    if autoSaveTimer then
        autoSaveTimer:Cancel()
        autoSaveTimer = nil
        Debug("Stopped auto-save timer")
    end
end

-- Generate and display profession link in the viewer
function PL.GenerateAndShowProfessionLink(viewerFrame)
    if not viewerFrame or not viewerFrame.currentPlayerName or not viewerFrame.currentProfessionName then
        print("|cffffff00CraftersBoard|r No profession data currently displayed")
        return
    end
    
    local playerName = viewerFrame.currentPlayerName
    local professionName = viewerFrame.currentProfessionName
    
    -- Generate the custom profession link
    local linkData = string.format("%s:%s", playerName, professionName)
    local linkText = string.format("[%s's %s]", playerName, professionName)
    local fullLink = string.format("|HcraftersProfession:%s|h%s|h", linkData, linkText)
    
    -- Show the link in a clickable frame
    PL.ShowProfessionLink(fullLink, playerName, professionName)
    
    print("|cffffff00CraftersBoard|r Generated profession link for " .. playerName .. "'s " .. professionName)
end

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
    local playerName, professionName
    
    -- Check if it's the full hyperlink format or just the data part
    if link:match("|HcraftersProfession:") then
        -- Parse the full link format: |HcraftersProfession:PlayerName:ProfessionName|h[Display Text]|h
        local linkData = link:match("|HcraftersProfession:([^|]+)|h")
        if linkData then
            playerName, professionName = linkData:match("^([^:]+):(.+)$")
        end
    else
        -- Parse just the data part: craftersProfession:PlayerName:ProfessionName
        playerName, professionName = link:match("^craftersProfession:([^:]+):(.+)$")
    end
    
    if not playerName or not professionName then
        Debug("Could not parse profession link: " .. tostring(link))
        return
    end
    
    Debug("Profession link clicked: " .. playerName .. "'s " .. professionName)
    
    -- Try to show the profession data
    local snapshot = nil
    
    -- Check if it's our own profession
    if playerName == UnitName("player") then
        snapshot = professionSnapshots[professionName]
    else
        -- Check cached data for other players
        if cachedProfessions[playerName] and cachedProfessions[playerName][professionName] then
            snapshot = cachedProfessions[playerName][professionName]
        end
    end
    
    if snapshot then
        PL.ShowProfessionData(playerName, professionName, snapshot)
        Debug("Showing cached data for " .. playerName .. "'s " .. professionName)
    else
        -- No data available - check if we should request it
        local profId = PROFESSION_IDS[professionName]
        if profId and playerName ~= UnitName("player") then
            
            -- Check if we already have a pending request for this player/profession
            local alreadyRequesting = false
            for reqId, request in pairs(pendingRequests) do
                if request.target == playerName and request.professionName == professionName then
                    local requestAge = time() - request.timestamp
                    if requestAge < 30 then -- Still within timeout period
                        alreadyRequesting = true
                        Debug("Request already pending for " .. playerName .. "'s " .. professionName)
                        print("|cffffff00CraftersBoard|r Already requesting " .. playerName .. "'s " .. professionName .. "...")
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
                print("|cffffff00CraftersBoard|r No data available for " .. playerName .. "'s " .. professionName)
                print("|cffffff00CraftersBoard|r Requesting fresh data...")
                
                -- Send automatic data request
                local reqId = PL.RequestProfessionData(playerName, profId)
                
                if reqId then
                    -- Store the request so we can show the data when it arrives
                    if not pendingViewRequests then
                        pendingViewRequests = {}
                    end
                    pendingViewRequests[reqId] = {
                        playerName = playerName,
                        professionName = professionName,
                        timestamp = time()
                    }
                    Debug("Marked request " .. reqId .. " as view request")
                end
            end
        else
            print("|cffffff00CraftersBoard|r No data available for " .. playerName .. "'s " .. professionName)
            if playerName == UnitName("player") then
                print("|cffffff00CraftersBoard|r Try opening your " .. professionName .. " window to scan the profession.")
            else
                print("|cffffff00CraftersBoard|r Ensure they have the CraftersBoard addon and try again.")
            end
        end
    end
end

