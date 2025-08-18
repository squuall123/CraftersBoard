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
  ["Unknown"] = "Interface\\Icons\\INV_Misc_Eye_01"
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

  -- Create modern frameless window
  local f = CreateFrame("Frame", "CraftersBoardFrame", UIParent)
  f:SetSize(840, 420)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:Hide()
  
  -- Modern dark glass-morphism background
  SetBackdropCompat(f, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  })
  SetBackdropColorCompat(f, 0.05, 0.08, 0.12, 0.95)  -- Deep dark blue with high transparency
  SetBackdropBorderColorCompat(f, 0.2, 0.4, 0.8, 0.8)  -- Subtle blue glow border

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

  -- Modern title bar
  local titleBar = CreateFrame("Frame", nil, f)
  titleBar:SetHeight(32)
  titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  
  -- Title bar background with gradient effect
  SetBackdropCompat(titleBar, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16
  })
  SetBackdropColorCompat(titleBar, 0.1, 0.15, 0.25, 0.9)
  
  -- Modern title text
  f.title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("LEFT", titleBar, "LEFT", 16, 0)
  f.title:SetText("CraftersBoard — Workers")
  f.title:SetTextColor(0.9, 0.9, 1.0, 1.0)  -- Slight blue tint
  
  -- Modern close button
  local closeBtn = CreateFrame("Button", nil, titleBar)
  closeBtn:SetSize(20, 20)
  closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)
  closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
  closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
  closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
  closeBtn:SetScript("OnClick", function() f:Hide() end)
  
  -- Separator line under title
  local separator = titleBar:CreateTexture(nil, "OVERLAY")
  separator:SetHeight(1)
  separator:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 8, 0)
  separator:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", -8, 0)
  separator:SetColorTexture(0.3, 0.5, 0.9, 0.6)

  -- Modern tab container
  local tabContainer = CreateFrame("Frame", nil, f)
  tabContainer:SetHeight(32)
  tabContainer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, -4)
  tabContainer:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -8, -4)
  
  -- Create modern flat tabs (Classic-compatible without TabButtonTemplate)
  local tab1 = CreateFrame("Button", f:GetName().."Tab1", tabContainer)
  tab1:SetID(1)
  tab1:SetSize(150, 28)
  tab1:SetPoint("LEFT", tabContainer, "LEFT", 0, 0)
  tab1:EnableMouse(true)
  tab1:RegisterForClicks("LeftButtonUp")
  
  local tab2 = CreateFrame("Button", f:GetName().."Tab2", tabContainer)
  tab2:SetID(2)
  tab2:SetSize(170, 28)
  tab2:SetPoint("LEFT", tab1, "RIGHT", 4, 0)
  tab2:EnableMouse(true)
  tab2:RegisterForClicks("LeftButtonUp")

  local tab3 = CreateFrame("Button", f:GetName().."Tab3", tabContainer)
  tab3:SetID(3)
  tab3:SetSize(180, 28)
  tab3:SetPoint("LEFT", tab2, "RIGHT", 4, 0)
  tab3:EnableMouse(true)
  tab3:RegisterForClicks("LeftButtonUp")
  
  -- Add text to tabs manually (more reliable than TabButtonTemplate)
  tab1.text = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tab1.text:SetPoint("CENTER", tab1, "CENTER", 0, 0)
  tab1.text:SetText("|TInterface\\Icons\\Trade_BlackSmithing:16:16:0:0|t Workers")
  
  tab2.text = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tab2.text:SetPoint("CENTER", tab2, "CENTER", 0, 0)
  tab2.text:SetText("|TInterface\\Icons\\INV_Misc_Eye_01:16:16:0:0|t Looking For")
  
  tab3.text = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tab3.text:SetPoint("CENTER", tab3, "CENTER", 0, 0)
  tab3.text:SetText("|TInterface\\Icons\\INV_Misc_GroupLooking:16:16:0:0|t Guild Workers")
  
  -- Style tabs with modern appearance
  for _, tab in ipairs({tab1, tab2, tab3}) do
    -- Modern tab styling
    SetBackdropCompat(tab, {
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      tile = true,
      tileSize = 16,
      insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    SetBackdropColorCompat(tab, 0.08, 0.12, 0.2, 0.8)
    
    -- Set up hover effects
    tab:SetScript("OnEnter", function(self)
      if self ~= UI.activeTab then
        SetBackdropColorCompat(self, 0.12, 0.18, 0.3, 0.9)
      end
    end)
    
    tab:SetScript("OnLeave", function(self)
      if self ~= UI.activeTab then
        SetBackdropColorCompat(self, 0.08, 0.12, 0.2, 0.8)
      end
    end)
    
    -- Ensure text is properly styled
    if tab.text then
      tab.text:SetTextColor(0.8, 0.8, 0.9, 1.0)
      tab.text:SetJustifyH("CENTER")
      tab.text:SetJustifyV("MIDDLE")
      tab.text:SetWordWrap(false)
    end
    
    -- Ensure tab is clickable
    tab:SetFrameLevel(tabContainer:GetFrameLevel() + 1)
  end
  
  -- Store reference to tabs for active state management
  UI.tab1 = tab1
  UI.tab2 = tab2
  UI.tab3 = tab3

  -- Note: Removed PanelTemplates_SetNumTabs since we're not using TabButtonTemplate

  -- Modern search area
  local searchArea = CreateFrame("Frame", nil, f)
  searchArea:SetHeight(32)
  searchArea:SetPoint("TOPLEFT", tabContainer, "BOTTOMLEFT", 0, -8)
  searchArea:SetPoint("TOPRIGHT", tabContainer, "BOTTOMRIGHT", 0, -8)
  
  -- Search area background
  SetBackdropCompat(searchArea, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    tile = true,
    tileSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  SetBackdropColorCompat(searchArea, 0.03, 0.05, 0.08, 0.7)
  
  -- Create modern search box (repositioned for better layout)
  local search = CreateFrame("EditBox", nil, searchArea, "InputBoxTemplate")
  search:SetSize(360, 24)
  search:SetPoint("LEFT", searchArea, "LEFT", 12, 0)
  search:SetAutoFocus(false)
  
  -- Modern dark styling for search box
  SetBackdropCompat(search, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 6, right = 6, top = 6, bottom = 6 }
  })
  SetBackdropColorCompat(search, 0.08, 0.12, 0.18, 0.95)
  SetBackdropBorderColorCompat(search, 0.2, 0.4, 0.8, 0.6)
  
  -- Search placeholder text
  local searchPlaceholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  searchPlaceholder:SetPoint("LEFT", search, "LEFT", 8, 0)
  searchPlaceholder:SetText("Search players, professions, or messages...")
  searchPlaceholder:SetTextColor(0.5, 0.5, 0.6, 1.0)
  
  -- Modern button styling function
  local function styleModernButton(btn, width)
    btn:SetSize(width or 80, 24)
    SetBackdropCompat(btn, {
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 12,
      insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    SetBackdropColorCompat(btn, 0.1, 0.2, 0.4, 0.9)
    SetBackdropBorderColorCompat(btn, 0.3, 0.5, 0.9, 0.8)
    
    local btnText = btn:GetFontString()
    if btnText then
      btnText:SetTextColor(0.9, 0.9, 1.0, 1.0)
    end
  end
  
  -- Search functionality
  search:SetScript("OnEnterPressed", function(self) 
    CRAFTERSBOARD_DB.filters.search = CB.trim(self:GetText():lower() or "")
    UI.Force()
    self:ClearFocus() 
  end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  search:SetScript("OnEditFocusGained", function(self)
    if self:GetText() == "" then
      searchPlaceholder:Hide()
    end
  end)
  search:SetScript("OnEditFocusLost", function(self)
    if self:GetText() == "" then
      searchPlaceholder:Show()
    end
  end)
  search:SetScript("OnTextChanged", function(self)
    if self:GetText() == "" then
      searchPlaceholder:Show()
    else
      searchPlaceholder:Hide()
    end
    CRAFTERSBOARD_DB.filters.search = CB.trim(self:GetText():lower() or "")
    if UI.Force then UI.Force() end
  end)
  search:SetText(CRAFTERSBOARD_DB.filters.search or "")
  if search:GetText() ~= "" then
    searchPlaceholder:Hide()
  end
  
  -- Store search reference
  UI.search = search
  
  -- Modern content area with scroll frame
  local scroll = CreateFrame("ScrollFrame", f:GetName().."Scroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", searchArea, "BOTTOMLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 12)
  scroll:SetFrameStrata("DIALOG")
  
  -- Modern dark background for scroll area with inner shadow effect
  SetBackdropCompat(scroll, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  })
  SetBackdropColorCompat(scroll, 0.02, 0.03, 0.06, 0.9)  -- Very dark content area
  SetBackdropBorderColorCompat(scroll, 0.15, 0.25, 0.4, 0.7)  -- Subtle inner border
  
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
  
  -- Guild scan button (repositioned after removing refresh button)
  local btnGuildScan = CreateFrame("Button", nil, searchArea, "UIPanelButtonTemplate")
  btnGuildScan:SetPoint("LEFT", search, "RIGHT", 12, 0)
  btnGuildScan:SetText("Scan Guild")
  btnGuildScan:SetScript("OnClick", function()
    if not IsInGuild or not IsInGuild() then
      print("|cff00ff88CraftersBoard|r You are not in a guild.")
      return
    end
    if GuildRoster then GuildRoster() end
    if CB.rebuildGuildWorkers then 
      CB.rebuildGuildWorkers() 
      local members = CRAFTERSBOARD_DB.guildScan.members or {}
      CB.DebugPrint("Guild scan complete. Found " .. #members .. " members with professions.")
    end
    if UI.Force then UI.Force() end
  end)
  btnGuildScan:Hide()
  styleModernButton(btnGuildScan, 100)
  
  local lblScan = searchArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  lblScan:SetPoint("LEFT", btnGuildScan, "RIGHT", 8, 0)
  lblScan:SetText("Last scan: —")
  lblScan:SetTextColor(0.7, 0.7, 0.8, 1.0)
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

  -- Tab switching function with modern styling
  local function setActiveTab(id)
    UI.activeKind = (id == 1) and "PROVIDER" or (id == 2 and "REQUESTER" or "GUILD")
    f.selectedTab = id
    CRAFTERSBOARD_DB.lastTab = id
    
    -- Update tab appearance
    local tabs = {UI.tab1, UI.tab2, UI.tab3}
    for i, tab in ipairs(tabs) do
      if i == id then
        -- Active tab styling
        SetBackdropColorCompat(tab, 0.15, 0.25, 0.45, 1.0)
        if tab.text then
          tab.text:SetTextColor(1.0, 1.0, 1.0, 1.0)
        end
        UI.activeTab = tab
      else
        -- Inactive tab styling
        SetBackdropColorCompat(tab, 0.08, 0.12, 0.2, 0.8)
        if tab.text then
          tab.text:SetTextColor(0.8, 0.8, 0.9, 1.0)
        end
      end
    end
    
    -- Note: Removed PanelTemplates_SetTab since we're using custom tabs
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
  UI.tab1:SetScript("OnClick", function() 
    CB.DebugPrint("Tab 1 clicked - Workers")
    setActiveTab(1) 
  end)
  UI.tab2:SetScript("OnClick", function() 
    CB.DebugPrint("Tab 2 clicked - Looking For")
    setActiveTab(2) 
  end)
  UI.tab3:SetScript("OnClick", function() 
    CB.DebugPrint("Tab 3 clicked - Guild Workers")
    setActiveTab(3) 
  end)

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
