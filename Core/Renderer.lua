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

-- Tooltip handling for rows
local function AttachRowTooltip(row)
  row:SetScript("OnEnter", function(self)
    if not self.player then return end
    
    local title = self.player
    if self.guild then
      title = title .. " |cffaaaaaa(Guild)|r"
    end
    
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(title, 1,1,1)
    GameTooltip:AddLine("Left-click to whisper | Right-click for actions", .9,.9,.9)
    
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
  local cleanName = name:match("^([^-]+)") or name

  local menu = {
    { text = name, isTitle = true, notCheckable = true },
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

    -- Create columns (match original exactly)
    b.col1 = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")   -- time/rank
    b.col1:SetPoint("LEFT", 6, 0)
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
    b.SetBarColor = function(self, _) self.bar:SetStatusBarColor(0.00, 0.65, 1.00) end
    b:SetBarColor()
    b.bar:Hide()

    -- Click handlers
    b:SetScript("OnClick", function(self, button)
      if button == "LeftButton" then
        if self.player and self.player ~= "" then
          ChatFrame_OpenChat("/w "..self.player.." ", SELECTED_DOCK_FRAME)
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
                r.col2:Show(); r.col1:Show(); r.col3:Show(); r.col4:Show()

                -- Name without redundant profession icon (already in header)
                r.col2:ClearAllPoints(); r.col2:SetPoint("LEFT", 6, 0); r.col2:SetWidth(wName)
                r.col2:SetText(CB.classColorWrap(m.name or "?", m.classFile))

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
                r:SetBarColor()
                r.bar.text:SetText((lvl and lvl > 0) and (lvl.."/300") or "—")

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

                r.col1:Show(); r.col2:Show(); r.col3:Show(); r.col4:Show()
                r.col1:SetWidth(wTime); r.col2:SetWidth(wName); r.col3:SetWidth(wChan); r.col4:SetWidth(wMsg)
                r.col1:ClearAllPoints(); r.col1:SetPoint("LEFT", 6, 0)
                r.col2:ClearAllPoints(); r.col2:SetPoint("LEFT", r.col1, "RIGHT", 8, 0)
                r.col3:ClearAllPoints(); r.col3:SetPoint("LEFT", r.col2, "RIGHT", 8, 0)
                r.col4:ClearAllPoints(); r.col4:SetPoint("LEFT", r.col3, "RIGHT", 8, 0)

                r.col1:SetText(CB.agoStr(e.time))
                -- Remove redundant profession icon since entries are already grouped by profession
                r.col2:SetText(e.player or "?")
                r.col3:SetText(e.channel or "")
                -- Parse any remaining icon markup in the message
                local message = e.message or ""
                if CB.ParseIconMarkup then
                  message = CB.ParseIconMarkup(message)
                end
                r.col4:SetText(message)
                r.player = e.player; r.entry = e; r.guild = false

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

-- Initialize pools when UI is created
UI.InitializePools()

-- Export the render function
CB.render = UI.render
UI.render = UI.render -- Also keep it in UI namespace
