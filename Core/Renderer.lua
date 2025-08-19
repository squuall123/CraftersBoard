-- CraftersBoard - UI Renderer
-- Version: 1.0.0
-- Handles complex UI rendering, layouts, and display logic

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

local UI = CB.UI
local max, floor = math.max, math.floor

-- Class color wrapping for names
function CB.classColorWrap(name, classFile)
  if not classFile or classFile == "" then return name end
  local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if color then
    return string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
  end
  return name
end

-- Helper function to clean player names (remove realm suffix)
function CB.cleanPlayerName(name)
  if not name or name == "" then return name end
  -- Remove realm suffix (everything after the first hyphen)
  return name:match("^([^-]+)") or name
end

-- Helper function for debug printing
function CB.debugPrint(...)
  if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
    print("|cff00ff88CraftersBoard|r", ...)
  end
end

-- Helper function to get color for profession skill level
function CB.getProfessionLevelColor(level)
  if not level or level <= 0 then
    return 0.5, 0.5, 0.5 -- Gray for no skill
  elseif level <= 150 then
    return 1.0, 0.3, 0.3 -- Red for Apprentice/Journeyman (1-150)
  elseif level <= 225 then
    return 1.0, 0.8, 0.0 -- Yellow/Orange for Expert (151-225)
  elseif level <= 299 then
    return 0.2, 1.0, 0.2 -- Green for Artisan (226-299)
  else
    return 0.0, 0.8, 1.0 -- Blue for Master (300)
  end
end

-- Tooltip handling for rows
local function AttachRowTooltip(row)
  row:SetScript("OnEnter", function(self)
    if not self.player then return end
    
    local title = CB.cleanPlayerName(self.player)
    if self.guild then
      title = title .. " |cffaaaaaa(Guild)|r"
    end
    
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(title, 1,1,1)
    GameTooltip:AddLine("Left-click to whisper | Right-click for actions", .9,.9,.9)
    
    -- Show all profession levels for guild members
    if self.guild and self.player then
      local members = CRAFTERSBOARD_DB.guildScan.members or {}
      for _, member in ipairs(members) do
        if member.name == self.player and member.profs then
          GameTooltip:AddLine(" ", 1,1,1) -- Spacer
          GameTooltip:AddLine("Professions:", 0.8, 0.8, 1.0)
          for prof, level in pairs(member.profs) do
            if level and level > 0 then
              local r, g, b = CB.getProfessionLevelColor(level)
              GameTooltip:AddLine(string.format("  %s: %d/300", prof, level), r, g, b)
            end
          end
          break
        end
      end
    end
    
    if self.entry and CB.AppendTooltipPrices then 
      CB.AppendTooltipPrices(self.entry) 
    end
    
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Context menu handling
function UI.ShowRowMenu(row)
  local name = row.player or "?"
  local isMuted = CB.IsPlayerMuted and CB.IsPlayerMuted(name) or false
  local isGuild = row.guild == true
  local hasMsg  = not isGuild and row.entry and row.entry.message

  -- Clean player name (remove realm suffix for Classic compatibility)
  local cleanName = CB.cleanPlayerName(name)

  local menu = {
    { text = cleanName, isTitle = true, notCheckable = true },
    { text = "Whisper", notCheckable = true, func = function()
      ChatFrame_OpenChat("/w " .. cleanName .. " ", SELECTED_DOCK_FRAME)
    end },
    { text = "Invite", notCheckable = true, func = function()
      InviteUnit(cleanName)
    end },
    { text = "Add Friend", notCheckable = true, func = function()
      -- Classic-compatible friend adding
      if C_FriendList and C_FriendList.AddFriend then
        C_FriendList.AddFriend(cleanName)
      else
        -- Fallback for older Classic versions
        SendChatMessage("/friend " .. cleanName, "GUILD")
      end
    end },
    { text = "Who", notCheckable = true, func = function()
      -- Execute /who command directly
      SlashCmdList["WHO"](cleanName)
    end },
  }

  if hasMsg then
    table.insert(menu, { text = "Mute phrase", notCheckable = true, func = function()
      local msg = row.entry.message or ""
      local seed = msg:match("%S+") or ""
      StaticPopup_Show("CRAFTERSBOARD_MUTE_PHRASE", nil, nil, seed)
    end })
  end

  table.insert(menu, { text = isMuted and "Unmute player" or "Mute player", notCheckable = true, func = function()
    if isMuted then
      if CB.UnmutePlayer then CB.UnmutePlayer(name) end
      print("|cff00ff88CraftersBoard|r unmuted player:", name)
    else
      if CB.MutePlayer then CB.MutePlayer(name) end
      print("|cff00ff88CraftersBoard|r muted player:", name)
    end
    if UI and UI.Force then UI.Force() end
  end })

  -- Add separator before Request submenu
  table.insert(menu, { text = "", disabled = true, notCheckable = true })
  
  -- Add Request submenu with proper Classic dropdown implementation
  table.insert(menu, { 
    text = "Request", 
    notCheckable = true, 
    hasArrow = true,
    value = "REQUEST_SUBMENU"
  })

  -- Add separator before Cancel
  table.insert(menu, { text = "", disabled = true, notCheckable = true })
  table.insert(menu, { text = CANCEL, notCheckable = true })

  -- Create dropdown menu
  if not UI.menuFrame then
    UI.menuFrame = CreateFrame("Frame", "CraftersBoardContextMenu", UIParent, "UIDropDownMenuTemplate")
  end

  if type(EasyMenu) == "function" then
    EasyMenu(menu, UI.menuFrame, "cursor", 0, 0, "MENU", true)
  else
    if not UI.menuFrameInit then
      UIDropDownMenu_Initialize(UI.menuFrame, function(self, level)
        if level == 1 then
          for _, info in ipairs(UI.menuItems or {}) do
            local di = UIDropDownMenu_CreateInfo()
            for k, v in pairs(info) do di[k] = v end
            UIDropDownMenu_AddButton(di, level)
          end
        elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "REQUEST_SUBMENU" then
          -- Request submenu items
          local di = UIDropDownMenu_CreateInfo()
          di.text = "Ask for mats"
          di.notCheckable = true
          di.func = function()
            local template = CRAFTERSBOARD_DB.requestTemplates.askForMats or "Hi! Could you please tell me what materials you need for your crafting services? Thanks!"
            ChatFrame_OpenChat("/w " .. cleanName .. " " .. template, SELECTED_DOCK_FRAME)
          end
          UIDropDownMenu_AddButton(di, level)
          
          di = UIDropDownMenu_CreateInfo()
          di.text = "Ask for price"
          di.notCheckable = true
          di.func = function()
            local template = CRAFTERSBOARD_DB.requestTemplates.askForPrice or "Hello! Could you please let me know your pricing for crafting services? Thank you!"
            ChatFrame_OpenChat("/w " .. cleanName .. " " .. template, SELECTED_DOCK_FRAME)
          end
          UIDropDownMenu_AddButton(di, level)
        end
      end, "MENU")
      UI.menuFrameInit = true
    end
    UI.menuItems = menu
    ToggleDropDownMenu(1, nil, UI.menuFrame, "cursor", 0, 0)
  end
end

-- Pool management for UI elements
function UI.InitializePools()
  if not UI.pool then
    UI.pool = { headers = {}, rows = {}, hUsed = 0, rUsed = 0 }
  end
end

function UI.AcquireHeader(parent)
  UI.InitializePools() -- Ensure pools exist
  
  if not UI.content then
    return nil
  end
  
  UI.pool.hUsed = UI.pool.hUsed + 1
  local idx = UI.pool.hUsed
  local h = UI.pool.headers[idx]
  
  if not h then
    -- Always create with UI.content as parent for proper containment
    h = CreateFrame("Button", nil, UI.content)
    h:SetHeight(22)
    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetColorTexture(1,1,1,0.08)
    h.bg:SetAllPoints()
    
    h.toggle = CreateFrame("Button", nil, h)
    h.toggle:SetSize(16,16)
    h.toggle:SetPoint("LEFT", 4, 0)
    h.toggle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP")
    h.toggle:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-DOWN")
    
    h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.text:SetPoint("LEFT", h.toggle, "RIGHT", 4, 0)
    
    h.toggle:SetScript("OnClick", function(self)
      local collapsed = CB.IsCollapsed and CB.IsCollapsed(h.kind, h.prof) or false
      if CB.SetCollapsed then CB.SetCollapsed(h.kind, h.prof, not collapsed) end
      if UI.Force then UI.Force() end
    end)
    
    UI.pool.headers[idx] = h
  end
  
  -- Ensure it's always parented to content frame
  if h:GetParent() ~= UI.content then
    h:SetParent(UI.content)
  end
  
  h:Show()
  return h
end

function UI.AcquireRow(parent)
  UI.InitializePools() -- Ensure pools exist
  
  if not UI.content then
    return nil
  end
  
  UI.pool.rUsed = UI.pool.rUsed + 1
  local idx = UI.pool.rUsed
  local b = UI.pool.rows[idx]
  
  if not b then
    -- Always create with UI.content as parent for proper containment
    b = CreateFrame("Button", nil, UI.content)
    b:SetHeight(20)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")

    -- Create star button for favorites
    b.starButton = CreateFrame("Button", nil, b)
    b.starButton:SetSize(20, 20)  -- Increased size from 16x16 to 20x20
    b.starButton:SetPoint("LEFT", 6, 0)
    
    -- Try different texture approaches for star icon
    local function SetupStarDisplay()
      -- First try: Custom TGA textures
      b.starTexture = b.starButton:CreateTexture(nil, "OVERLAY")
      b.starTexture:SetAllPoints()
      
      -- Try to load the custom TGA texture
      local customTexturePath = "Interface\\AddOns\\CraftersBoard\\Textures\\star_empty"
      b.starTexture:SetTexture(customTexturePath)
      
      -- Better detection: Check if texture loaded by testing if it has dimensions
      -- In Classic, GetTexture() might not return the full path, so we use a different approach
      local textureWorked = false
      
      -- Method 1: Check if texture object is valid and has content
      local loadedTexture = b.starTexture:GetTexture()
      if loadedTexture and loadedTexture ~= "" then
        -- Try to set it again to make sure it's really loaded
        b.starTexture:SetTexture(customTexturePath)
        
        -- Additional test: try to set vertex color (this will fail if texture didn't load)
        local success = pcall(function()
          b.starTexture:SetVertexColor(1, 1, 1, 1)
        end)
        
        if success then
          textureWorked = true
        end
      end
      
      if textureWorked then
        -- Custom TGA textures are working
        b.starTextureMode = "custom"
        b.filledTexturePath = "Interface\\AddOns\\CraftersBoard\\Textures\\star_filled"
        b.emptyTexturePath = "Interface\\AddOns\\CraftersBoard\\Textures\\star_empty"
        CB.debugPrint("Using custom TGA star textures")
      else
        -- Second try: Better built-in WoW textures for stars
        -- Try a few different built-in textures that should work in Classic
        local builtinTextures = {
          "Interface\\Buttons\\UI-GroupLoot-Dice-Up",  -- Dice icon
          "Interface\\Common\\ReputationStar",          -- Reputation star (if exists)
          "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
          "Interface\\Buttons\\ButtonHilight-Square"
        }
        
        local foundBuiltin = false
        for _, texPath in ipairs(builtinTextures) do
          b.starTexture:SetTexture(texPath)
          if b.starTexture:GetTexture() then
            foundBuiltin = true
            b.starTextureMode = "builtin"
            if texPath:find("ZoomButton") then
              b.starTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop zoom button
            elseif texPath:find("Dice") then
              b.starTexture:SetTexCoord(0.0, 1.0, 0.0, 1.0) -- Use full dice
            end
            b.filledTexturePath = texPath
            b.emptyTexturePath = texPath
            CB.debugPrint("Using built-in texture: " .. texPath)
            break
          end
        end
        
        if not foundBuiltin then
          -- Final fallback: Text symbols
          b.starTexture:Hide()
          b.starText = b.starButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
          b.starText:SetPoint("CENTER")
          b.starText:SetText("★")
          b.starTextureMode = "text"
          CB.debugPrint("Using text symbols for stars")
        end
      end
    end
    
    SetupStarDisplay()
    
    -- Add highlight texture
    b.starButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    
    -- Star click handler
    b.starButton:SetScript("OnClick", function(self)
      local parentRow = self:GetParent()
      if parentRow.player then
        CB.togglePlayerFavorite(parentRow.player)
        -- Update star button immediately after toggle
        CB.updateStarButton(parentRow, false) -- false = not showing on hover after click
      end
    end)
    
    -- Star tooltip
    b.starButton:SetScript("OnEnter", function(self)
      local parentRow = self:GetParent()
      if not parentRow.player then return end
      
      -- Show star on hover if not a favorite
      local isFavorite = CB.isPlayerFavorite(parentRow.player)
      if not isFavorite then
        CB.updateStarButton(parentRow, true) -- true = showing on hover
      end
      
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local cleanName = CB.cleanPlayerName(parentRow.player)
      if isFavorite then
        GameTooltip:SetText("★ " .. cleanName .. " (Favorite)", 1, 0.8, 0)
        GameTooltip:AddLine("Click to remove from favorites", 0.8, 0.8, 0.8)
      else
        GameTooltip:SetText("☆ " .. cleanName, 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Click to add to favorites", 0.8, 0.8, 0.8)
      end
      GameTooltip:Show()
    end)
    
    b.starButton:SetScript("OnLeave", function(self)
      local parentRow = self:GetParent()
      if not parentRow.player then return end
      
      -- Hide star on leave if not a favorite
      local isFavorite = CB.isPlayerFavorite(parentRow.player)
      if not isFavorite then
        CB.updateStarButton(parentRow, false) -- false = not showing on hover
      end
      
      GameTooltip:Hide()
    end)

    -- Create columns (adjusted positioning to account for star)
    b.col1 = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")   -- time/rank
    b.col1:SetPoint("LEFT", b.starButton, "RIGHT", 4, 0)
    b.col2 = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") -- name
    b.col2:SetPoint("LEFT", b.col1, "RIGHT", 8, 0)
    b.col3 = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")   -- chan / char lvl
    b.col3:SetJustifyH("LEFT")
    b.col4 = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") -- msg / note
    b.col4:SetJustifyH("LEFT")

    -- Guild bar (blue) - match original exactly
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    b.bar:SetMinMaxValues(0, 300)
    b.bar:SetValue(0)
    b.bar:SetHeight(12)
    b.bar.bg = b.bar:CreateTexture(nil, "BACKGROUND")
    b.bar.bg:SetAllPoints(true)
    b.bar.bg:SetColorTexture(0.05, 0.20, 0.45, 0.35)
    b.bar.text = b.bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.bar.text:SetPoint("CENTER", b.bar, "CENTER", 0, 0)
    b.bar.text:SetTextColor(1, 1, 1)
    b.bar.text:SetShadowOffset(1, -1)
    b.SetBarColor = function(self, r, g, b) 
      -- Default blue color if no color specified
      r = r or 0.00
      g = g or 0.65
      b = b or 1.00
      self.bar:SetStatusBarColor(r, g, b) 
    end
    b:SetBarColor()
    b.bar:Hide()

    -- Click handlers
    b:SetScript("OnClick", function(self, button)
      if button == "LeftButton" then
        if self.player and self.player ~= "" then
          ChatFrame_OpenChat("/w "..CB.cleanPlayerName(self.player).." ", SELECTED_DOCK_FRAME)
        end
      else
        UI.ShowRowMenu(self)
      end
    end)

    AttachRowTooltip(b)
    UI.pool.rows[idx] = b
  end
  
  -- Ensure it's always parented to content frame
  if b:GetParent() ~= UI.content then
    b:SetParent(UI.content)
  end
  
  b:Show()
  return b
end

function UI.ReleaseAll()
  UI.InitializePools() -- Ensure pools exist
  for i = 1, #UI.pool.headers do 
    local h = UI.pool.headers[i]
    if h then h:Hide(); h:ClearAllPoints() end 
  end
  
  for i = 1, #UI.pool.rows do
    local r = UI.pool.rows[i]
    if r then
      r:Hide()
      r:ClearAllPoints()
      r.bar:Hide()
      if r.starButton then r.starButton:Hide() end
    end
  end
  
  UI.pool.hUsed, UI.pool.rUsed = 0, 0
end

-- Main rendering function
function UI.render()
  if not UI.frame or not UI.frame:IsShown() then return end
  if not UI.content or not UI.scroll then 
    return 
  end
  
  -- Initialize pools if needed
  UI.InitializePools()

  UI.ReleaseAll()

  -- Update guild scan info
  if UI.lblScan then
    local t = CRAFTERSBOARD_DB.guildScan.lastScan or 0
    UI.lblScan:SetText("Last scan: "..(t > 0 and (CB.agoStr(t).." ago") or "—"))
  end

  local totalW = UI.scroll:GetWidth()
  if not totalW or totalW <= 0 then 
    totalW = (UI.frame:GetWidth() or 840) - 38 
  end
  UI.content:SetWidth(totalW)

  local q = CRAFTERSBOARD_DB.filters.search or ""
  local y = -2  -- Use absolute Y positioning like the original

  if UI.activeKind == "GUILD" then
    -- Guild layout: Name | Rank | Prof Bar | Level/Online | Note
    local wName, wRank, wBar, wInfo = 160, 120, 160, 120
    local wNote = max(100, totalW - (wName + 8 + wRank + 8 + wBar + 8 + wInfo + 16))

    local grouped = CB.GroupGuildByProfession and CB.GroupGuildByProfession(q) or {}
    
    -- Debug: Log guild data
    local totalMembers = 0
    for prof, list in pairs(grouped) do
      if list and #list > 0 then
        totalMembers = totalMembers + #list
      end
    end
    
    for _, prof in ipairs(CB.PROF_ORDER or {"Other"}) do
      local list = grouped[prof]
      if list and #list > 0 then
        -- Sort list like the original
        table.sort(list, function(a,b)
          local la = (a.profs and a.profs[prof]) or -1
          local lb = (b.profs and b.profs[prof]) or -1
          if la ~= lb then return (la or -1) > (lb or -1) end
          return (a.name or "") < (b.name or "")
        end)

        -- Count online for header (like original)
        local onlineCount = 0
        for _, m in ipairs(list) do if m.online then onlineCount = onlineCount + 1 end end

        local h = UI.AcquireHeader(UI.content)
        if h then
          h:ClearAllPoints()
          h:SetPoint("TOPLEFT", 0, y); h:SetPoint("RIGHT", -4, 0)
          
          -- Add profession icon to header text
          local profIcon = CB.getProfessionIcon and CB.getProfessionIcon(prof, 16) or ""
          h.text:SetText(string.format("%s %s (%d/%d)", profIcon, prof, onlineCount, #list))
          h.prof = prof
          h.kind = "GUILD"

          local collapsed = CB.IsCollapsed and CB.IsCollapsed("GUILD", prof) or false
          h.toggle:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-UP" or "Interface\\Buttons\\UI-MinusButton-UP")
          h.toggle:SetPushedTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-DOWN" or "Interface\\Buttons\\UI-MinusButton-DOWN")

          y = y - h:GetHeight() - 2

          if not collapsed then
            for _, m in ipairs(list) do
              local r = UI.AcquireRow(UI.content)
              if r then
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, y); r:SetPoint("RIGHT", -4, 0)

                -- Setup guild layout
                r.bar:Show()
                if r.starButton then r.starButton:Show() end
                r.col2:Show(); r.col1:Show(); r.col3:Show(); r.col4:Show()

                -- Name without redundant profession icon (already in header)
                r.col2:ClearAllPoints(); r.col2:SetPoint("LEFT", 6, 0); r.col2:SetWidth(wName)
                r.col2:SetText(CB.classColorWrap(CB.cleanPlayerName(m.name) or "?", m.classFile))

                -- Update star button
                r.player = m.name
                CB.updateStarButton(r, false) -- false = not showing on hover initially

                -- Rank
                r.col1:ClearAllPoints(); r.col1:SetPoint("LEFT", r.col2, "RIGHT", 8, 0); r.col1:SetWidth(wRank)
                r.col1:SetText(m.rank or "—")

                -- Profession bar
                local lvl = (m.profs and m.profs[prof]) or 0
                r.bar:ClearAllPoints()
                r.bar:SetPoint("LEFT", r.col1, "RIGHT", 8, 0)
                r.bar:SetWidth(wBar)
                r.bar:SetMinMaxValues(0, 300)
                r.bar:SetValue(lvl or 0)
                
                -- Color-coded profession level text and bar
                if lvl and lvl > 0 then
                  local r_val, g_val, b_val = CB.getProfessionLevelColor(lvl)
                  r:SetBarColor(r_val, g_val, b_val)  -- Set bar color to match level
                  local colorCode = string.format("|cff%02x%02x%02x", r_val * 255, g_val * 255, b_val * 255)
                  r.bar.text:SetText(colorCode .. lvl .. "/300|r")
                else
                  r:SetBarColor()  -- Default blue color for no skill
                  r.bar.text:SetText("—")
                end

                -- Info
                r.col3:ClearAllPoints(); r.col3:SetPoint("LEFT", r.bar, "RIGHT", 8, 0); r.col3:SetWidth(wInfo)
                local charLvl = tonumber(m.level or 0) or 0
                if m.online then
                  r.col3:SetText(string.format("Lv%d • |cff80ff80Online|r", charLvl))
                else
                  local ls = m.lastSeen and (CB.agoStr(m.lastSeen).." ago") or "unknown"
                  r.col3:SetText(string.format("Lv%d • |cffaaaaaaOffline|r\n(last seen %s)", charLvl, ls))
                end

                -- Note
                r.col4:ClearAllPoints(); r.col4:SetPoint("LEFT", r.col3, "RIGHT", 8, 0); r.col4:SetWidth(wNote)
                local note = CB.trim((m.note or "").." "..(m.officerNote or ""))
                -- Parse any icon markup in guild notes
                if CB.ParseIconMarkup and note ~= "" then
                  note = CB.ParseIconMarkup(note)
                end
                r.col4:SetText(note ~= "" and note or "—")

                -- Meta data
                r.player = m.name; r.guild = true; r.note = m.note; r.officerNote = m.officerNote
                r.online = m.online; r.lastSeen = m.lastSeen; r.rank = m.rank

                y = y - r:GetHeight()
              end
            end
            y = y - 6  -- Add space after section
          end
        end
      end
    end
  else
    -- Workers / Looking For: Time | Name | Channel | Message
    local wTime, wName, wChan = 50, 130, 90
    local wMsg = max(100, totalW - (wTime + 8 + wName + 8 + wChan + 16))

    local wantKind = UI.activeKind or "PROVIDER"
    local grouped = CB.GroupEntriesByProfession and CB.GroupEntriesByProfession(wantKind, q) or {}

    for _, prof in ipairs(CB.PROF_ORDER or {"Other"}) do
      local list = grouped[prof]
      if list and #list > 0 then
        local h = UI.AcquireHeader(UI.content)
        if h then
          h:ClearAllPoints()
          h:SetPoint("TOPLEFT", 0, y); h:SetPoint("RIGHT", -4, 0)
          
          -- Add profession icon to header text
          local profIcon = CB.getProfessionIcon and CB.getProfessionIcon(prof, 16) or ""
          h.text:SetText(string.format("%s %s (%d)", profIcon, prof, #list))
          h.prof = prof
          h.kind = wantKind

          local collapsed = CB.IsCollapsed and CB.IsCollapsed(wantKind, prof) or false
          h.toggle:SetNormalTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-UP" or "Interface\\Buttons\\UI-MinusButton-UP")
          h.toggle:SetPushedTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-DOWN" or "Interface\\Buttons\\UI-MinusButton-DOWN")

          y = y - h:GetHeight() - 2

          if not collapsed then
            for _, e in ipairs(list) do
              local r = UI.AcquireRow(UI.content)
              if r then
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, y); r:SetPoint("RIGHT", -4, 0)

                r.bar:Hide()
                if r.starButton then r.starButton:Show() end

                r.col1:Show(); r.col2:Show(); r.col3:Show(); r.col4:Show()
                r.col1:SetWidth(wTime); r.col2:SetWidth(wName); r.col3:SetWidth(wChan); r.col4:SetWidth(wMsg)
                r.col1:ClearAllPoints(); r.col1:SetPoint("LEFT", r.starButton, "RIGHT", 4, 0)
                r.col2:ClearAllPoints(); r.col2:SetPoint("LEFT", r.col1, "RIGHT", 8, 0)
                r.col3:ClearAllPoints(); r.col3:SetPoint("LEFT", r.col2, "RIGHT", 8, 0)
                r.col4:ClearAllPoints(); r.col4:SetPoint("LEFT", r.col3, "RIGHT", 8, 0)

                r.col1:SetText(CB.agoStr(e.time))
                -- Remove redundant profession icon since entries are already grouped by profession
                r.col2:SetText(CB.cleanPlayerName(e.player) or "?")
                r.col3:SetText(e.channel or "")
                -- Parse any remaining icon markup in the message
                local message = e.message or ""
                if CB.ParseIconMarkup then
                  message = CB.ParseIconMarkup(message)
                end
                r.col4:SetText(message)
                r.player = e.player; r.entry = e; r.guild = false

                -- Update star button
                CB.updateStarButton(r, false) -- false = not showing on hover initially

                y = y - r:GetHeight()
              end
            end
            y = y - 6  -- Add space after section
          end
        end
      end
    end
  end

  -- Set content height based on total content (use the original formula)
  UI.content:SetHeight(-y + 8)
  if UI.scroll and UI.scroll.UpdateScrollChildRect then 
    UI.scroll:UpdateScrollChildRect() 
  end
end

-- Favorite system functions
function CB.isPlayerFavorite(playerName)
  if not playerName then return false end
  local cleanName = CB.cleanPlayerName(playerName)
  return CRAFTERSBOARD_DB.favorites and CRAFTERSBOARD_DB.favorites[cleanName] == true
end

function CB.togglePlayerFavorite(playerName)
  if not playerName then return end
  local cleanName = CB.cleanPlayerName(playerName)
  
  -- Initialize favorites if needed
  if not CRAFTERSBOARD_DB.favorites then
    CRAFTERSBOARD_DB.favorites = {}
  end
  
  -- Toggle favorite status
  if CRAFTERSBOARD_DB.favorites[cleanName] then
    CRAFTERSBOARD_DB.favorites[cleanName] = nil
    CB.debugPrint("Removed " .. cleanName .. " from favorites")
  else
    CRAFTERSBOARD_DB.favorites[cleanName] = true
    CB.debugPrint("Added " .. cleanName .. " to favorites")
  end
  
  -- Refresh UI if visible
  if UI and UI.frame and UI.frame:IsShown() and UI.Force then
    UI.Force()
  end
end

function CB.updateStarButton(row, showOnHover)
  if not row or not row.starButton or not row.player then return end
  
  local isFavorite = CB.isPlayerFavorite(row.player)
  showOnHover = showOnHover or false
  
  -- Visibility logic: show filled star for favorites, show empty star only on hover for non-favorites
  local shouldShow = isFavorite or showOnHover
  
  if not shouldShow then
    -- Hide all star elements
    if row.starTexture then row.starTexture:Hide() end
    if row.starText then row.starText:Hide() end
    return
  end
  
  if row.starTextureMode == "custom" and row.starTexture then
    -- Use custom TGA textures
    if isFavorite then
      row.starTexture:SetTexture(row.filledTexturePath)
      row.starTexture:SetVertexColor(1.0, 1.0, 1.0, 1.0) -- No tinting, texture has color
      row.starTexture:Show()
    else
      row.starTexture:SetTexture(row.emptyTexturePath)
      row.starTexture:SetVertexColor(1.0, 1.0, 1.0, 1.0) -- No tinting, texture has color
      row.starTexture:Show()
    end
  elseif row.starTextureMode == "builtin" and row.starTexture then
    -- Use built-in WoW textures with color tinting
    if isFavorite then
      row.starTexture:SetVertexColor(1.0, 0.8, 0.0, 1.0) -- Gold tint
      row.starTexture:SetDesaturated(false)
      row.starTexture:Show()
    else
      row.starTexture:SetVertexColor(0.5, 0.5, 0.5, 0.7) -- Gray tint
      row.starTexture:SetDesaturated(true)
      row.starTexture:Show()
    end
  elseif row.starTextureMode == "text" and row.starText then
    -- Use text symbols
    if row.starTexture then row.starTexture:Hide() end -- Hide texture if using text
    if isFavorite then
      row.starText:SetText("★") -- Filled star
      row.starText:SetTextColor(1.0, 0.8, 0.0, 1.0) -- Gold color
    else
      row.starText:SetText("☆") -- Empty star
      row.starText:SetTextColor(0.5, 0.5, 0.5, 1.0) -- Gray color
    end
    row.starText:Show()
  end
end

-- Initialize pools when UI is created
UI.InitializePools()

-- Export the render function
CB.render = UI.render
UI.render = UI.render -- Also keep it in UI namespace
