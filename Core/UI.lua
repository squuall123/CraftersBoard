-- CraftersBoard - UI Components
-- Version: 1.0.0

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

-- UI namespace
CB.UI = CB.UI or {}
local UI = CB.UI

-- Forward declarations
local createUI, SetupResizeHandles, SaveWindowGeometry, RestoreWindowGeometry

-- Utility tables
local tinsert = table.insert

-- Classic compatibility functions for backdrop
local function SetBackdropCompat(frame, backdrop)
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

local function SetBackdropColorCompat(frame, r, g, b, a)
  if frame.SetBackdropColor then
    frame:SetBackdropColor(r, g, b, a)
  elseif frame._backdrop then
    frame._backdrop:SetVertexColor(r, g, b, a or 1)
  end
end

local function SetBackdropBorderColorCompat(frame, r, g, b, a)
  if frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(r, g, b, a)
  end
  -- Note: Border color not easily implemented in manual fallback
end

-- Coin textures for tooltip prices
local GOLD_TEX   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_TEX = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_TEX = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- Profession icon paths for Classic WoW
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
  ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
  ["Unknown"] = "Interface\\Icons\\INV_Misc_QuestionMark"
}

-- Function to get profession icon texture string
function CB.getProfessionIcon(profession, size)
  size = size or 16
  local iconPath = PROFESSION_ICONS[profession]
  if iconPath then
    return "|T" .. iconPath .. ":" .. size .. ":" .. size .. ":0:0|t"
  end
  return ""
end

function CB.moneyTextureString(c)
  if not c or c <= 0 then return "—" end
  if GetCoinTextureString then return GetCoinTextureString(c) end
  local g = math.floor(c/10000); local s = math.floor((c%10000)/100); local cp = c % 100
  local parts = {}
  if g > 0 then table.insert(parts, g..GOLD_TEX) end
  if s > 0 or g > 0 then table.insert(parts, s..SILVER_TEX) end
  table.insert(parts, cp..COPPER_TEX)
  return table.concat(parts, " ")
end

-- Window geometry management
function SaveWindowGeometry(frame)
  local point, _, relPoint, x, y = frame:GetPoint()
  CRAFTERSBOARD_DB.window = {
    w = frame:GetWidth(),
    h = frame:GetHeight(),
    point = point or "CENTER",
    relPoint = relPoint or "CENTER",
    x = x or 0,
    y = y or 0
  }
end

function RestoreWindowGeometry(frame)
  local w = CRAFTERSBOARD_DB.window or {}
  frame:SetSize(w.w or 840, w.h or 420)
  frame:ClearAllPoints()
  frame:SetPoint(w.point or "CENTER", UIParent, w.relPoint or "CENTER", w.x or 0, w.y or 0)
end

-- Resize handle setup
function SetupResizeHandles(frame)
  frame:SetResizable(true)
  
  -- WoW Classic compatibility: try different resize methods
  if frame.SetResizeBounds then
    -- Modern method (WoW Classic Era and later)
    frame:SetResizeBounds(400, 300, 1200, 800)
  elseif frame.SetMinResize and frame.SetMaxResize then
    -- Retail method (if available)
    frame:SetMinResize(400, 300)
    frame:SetMaxResize(1200, 800)
  else
    -- Fallback: no resize limits (very old versions)
    -- Frame is still resizable, just no bounds checking
  end

  local rb = CreateFrame("Button", nil, frame)
  rb:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
  rb:SetSize(16, 16)
  rb:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  rb:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  rb:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  rb:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      frame:StartSizing("BOTTOMRIGHT")
      frame:SetFrameStrata("DIALOG")
      frame:SetFrameLevel(math.max(UIParent:GetFrameLevel() + 100, frame:GetFrameLevel()))
      frame:Raise()
    end
  end)
  rb:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      frame:StopMovingOrSizing()
      SaveWindowGeometry(frame)
      if UI.Force then UI.Force() end
    end
  end)
end

-- Main UI creation function
function createUI()
  if UI.frame then return end

  local f = CreateFrame("Frame", "CraftersBoardFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(840, 420)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:Hide()
  
  -- Modern dark transparent background
  SetBackdropCompat(f, {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  SetBackdropColorCompat(f, 0.1, 0.1, 0.15, 0.9)  -- Dark blue-gray with transparency
  SetBackdropBorderColorCompat(f, 0.4, 0.4, 0.5, 1.0)  -- Subtle border

  if UISpecialFrames then tinsert(UISpecialFrames, f:GetName()) end

  f:SetToplevel(true)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(math.max(UIParent:GetFrameLevel() + 100, f:GetFrameLevel()))
  
  local function bringToFront(self)
    self:SetFrameStrata("DIALOG")
    self:SetFrameLevel(math.max(UIParent:GetFrameLevel() + 100, self:GetFrameLevel()))
    self:Raise()
  end
  
  f:SetScript("OnDragStart", function(self) bringToFront(self); self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SaveWindowGeometry(self) end)
  f:SetScript("OnMouseDown", function(self) bringToFront(self) end)

  SetupResizeHandles(f)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 6, 0)
  f.title:SetText("CraftersBoard — Workers")

  -- Create tabs with profession icons
  local tabTemplate = "CharacterFrameTabButtonTemplate"
  local tab1 = CreateFrame("Button", f:GetName().."Tab1", f, tabTemplate)
  tab1:SetID(1); tab1:SetText("⚒ Workers")
  tab1:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, -8)

  local tab2 = CreateFrame("Button", f:GetName().."Tab2", f, tabTemplate)
  tab2:SetID(2); tab2:SetText("🔍 Looking For")
  tab2:SetPoint("LEFT", tab1, "RIGHT", -16, 0)

  local tab3 = CreateFrame("Button", f:GetName().."Tab3", f, tabTemplate)
  tab3:SetID(3); tab3:SetText("🏛 Guild Workers")
  tab3:SetPoint("LEFT", tab2, "RIGHT", -16, 0)

  if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, 3) end

  -- Create scroll frame and content (match original positioning exactly)
  local scroll = CreateFrame("ScrollFrame", f:GetName().."Scroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -96)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 12)
  scroll:SetFrameStrata("DIALOG")
  
  -- Modern dark background for scroll area
  SetBackdropCompat(scroll, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  SetBackdropColorCompat(scroll, 0.05, 0.05, 0.1, 0.8)  -- Very dark background for content area
  
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  content:SetFrameStrata("DIALOG")
  scroll:SetScrollChild(content)
  
  -- Enable clipping if available (Classic compatibility)
  if content.SetClipsChildren then
    content:SetClipsChildren(true)
  end
  
  UI.scroll = scroll
  UI.content = content

  -- Create search box (match original positioning)
  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetSize(300, 24)
  search:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -64)
  search:SetAutoFocus(false)
  
  -- Modern dark styling for search box
  SetBackdropCompat(search, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  SetBackdropColorCompat(search, 0.1, 0.1, 0.15, 0.9)
  SetBackdropBorderColorCompat(search, 0.5, 0.5, 0.6, 1.0)
  search:SetScript("OnEnterPressed", function(self) 
    CRAFTERSBOARD_DB.filters.search = CB.trim(self:GetText():lower() or "")
    UI.Force()
    self:ClearFocus() 
  end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  search:SetScript("OnTextChanged", function(self)
    -- Optional: Update search in real-time (more responsive than original)
    CRAFTERSBOARD_DB.filters.search = CB.trim(self:GetText():lower() or "")
    if UI.Force then UI.Force() end
  end)
  search:SetText(CRAFTERSBOARD_DB.filters.search or "")
  UI.search = search

  -- Search label
  local lblSearch = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lblSearch:SetPoint("BOTTOMLEFT", search, "TOPLEFT", 4, 4)
  lblSearch:SetText("Search (text, name, or profession):")

  -- Refresh button
  local btnRefresh = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btnRefresh:SetSize(80, 22)
  btnRefresh:SetPoint("LEFT", search, "RIGHT", 10, 0)
  btnRefresh:SetText("Refresh")
  btnRefresh:SetScript("OnClick", function() UI.Force() end)
  UI.btnRefresh = btnRefresh

  -- Create guild scan button and label (for Guild Workers tab)
  local btnGuildScan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btnGuildScan:SetSize(110, 22)
  btnGuildScan:SetPoint("LEFT", btnRefresh, "RIGHT", 10, 0)
  btnGuildScan:SetText("Scan Guild")
  btnGuildScan:SetScript("OnClick", function()
    if not IsInGuild or not IsInGuild() then
      print("|cff00ff88CraftersBoard|r You are not in a guild.")
      return
    end
    if GuildRoster then GuildRoster() end
    if CB.rebuildGuildWorkers then 
      CB.rebuildGuildWorkers() 
      -- Debug: show guild scan results
      local members = CRAFTERSBOARD_DB.guildScan.members or {}
      CB.DebugPrint("Guild scan complete. Found " .. #members .. " members with professions.")
    end
    if UI.Force then UI.Force() end
  end)
  btnGuildScan:Hide()
  
  local lblScan = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lblScan:SetPoint("LEFT", btnGuildScan, "RIGHT", 8, 0)
  lblScan:SetText("Last scan: —")
  lblScan:Hide()
  
  UI.btnGuildScan = btnGuildScan
  UI.lblScan = lblScan

  -- Force refresh function
  function UI.Force()
    if not UI.content or not UI.scroll then 
      return 
    end
    
    -- Update content frame size to match scroll frame
    local scrollWidth = UI.scroll:GetWidth()
    local scrollHeight = UI.scroll:GetHeight()
    
    if scrollWidth and scrollWidth > 0 then
      UI.content:SetWidth(scrollWidth)
    end
    
    -- Render the UI content
    if UI.render then 
      UI.render() 
    end
    
    -- Update scroll child after rendering
    if UI.scroll.UpdateScrollChildRect then 
      UI.scroll:UpdateScrollChildRect()
    end
  end

  -- Tab switching function
  local function setActiveTab(id)
    UI.activeKind = (id == 1) and "PROVIDER" or (id == 2 and "REQUESTER" or "GUILD")
    f.selectedTab = id
    CRAFTERSBOARD_DB.lastTab = id
    if PanelTemplates_SetTab then PanelTemplates_SetTab(f, id) end
    f.title:SetText("CraftersBoard — "..
      (UI.activeKind == "PROVIDER" and "Workers" or UI.activeKind == "REQUESTER" and "Looking For" or "Guild Workers"))
    CRAFTERSBOARD_DB.filters.showProviders  = (UI.activeKind == "PROVIDER")
    CRAFTERSBOARD_DB.filters.showRequesters = (UI.activeKind == "REQUESTER")
    if UI.scroll and UI.scroll.SetVerticalScroll then UI.scroll:SetVerticalScroll(0) end
    if UI.btnGuildScan then
      if UI.activeKind == "GUILD" then UI.btnGuildScan:Show(); UI.lblScan:Show()
      else UI.btnGuildScan:Hide(); UI.lblScan:Hide() end
    end
    UI.Force()
  end
  
  UI.setActiveTab = setActiveTab
  tab1:SetScript("OnClick", function() setActiveTab(1) end)
  tab2:SetScript("OnClick", function() setActiveTab(2) end)
  tab3:SetScript("OnClick", function() setActiveTab(3) end)

  UI.frame = f
  
  -- Restore window geometry
  RestoreWindowGeometry(f)
  
  -- Initialize active tab
  local initialTab = 1
  if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.lastTab then
    initialTab = CRAFTERSBOARD_DB.lastTab
  end
  setActiveTab(initialTab)
end

-- Toggle main window
function CB.ToggleWindow()
  if not UI.frame then createUI() end
  if UI.frame:IsShown() then
    UI.frame:Hide()
  else
    UI.frame:Show()
    UI.frame:Raise()
  end
end

-- Show main window
function CB.ShowWindow()
  if not UI.frame then createUI() end
  UI.frame:Show()
  UI.frame:Raise()
end

-- Hide main window
function CB.HideWindow()
  if UI.frame then UI.frame:Hide() end
end

-- Export the createUI function for initialization
CB.createUI = createUI
