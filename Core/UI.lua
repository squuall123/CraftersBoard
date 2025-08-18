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
  ["FirstAid"] = "Interface\\Icons\\Spell_Holy_Heal",
  ["Other"] = "Interface\\Icons\\INV_Misc_QuestionMark"
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
  rb:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 5)  -- Positioned under the custom scroll bar
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
  f.title:SetText("CraftersBoard — Crafters")
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
  tab1.text:SetText("|TInterface\\Icons\\Trade_BlackSmithing:16:16:0:0|t Crafters")
  
  tab2.text = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tab2.text:SetPoint("CENTER", tab2, "CENTER", 0, 0)
  tab2.text:SetText("|TInterface\\Icons\\INV_Scroll_08:16:16:0:0|t Requests")
  
  tab3.text = tab3:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tab3.text:SetPoint("CENTER", tab3, "CENTER", 0, 0)
  tab3.text:SetText("|TInterface\\Icons\\INV_Misc_GroupLooking:16:16:0:0|t Guild Crafters")
  
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
  
  -- Create modern search box container
  local searchContainer = CreateFrame("Frame", nil, searchArea)
  searchContainer:SetSize(360, 24)
  searchContainer:SetPoint("LEFT", searchArea, "LEFT", 12, 0)
  
  -- Modern dark styling for search container
  SetBackdropCompat(searchContainer, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 6, right = 6, top = 6, bottom = 6 }
  })
  SetBackdropColorCompat(searchContainer, 0.08, 0.12, 0.18, 0.95)
  SetBackdropBorderColorCompat(searchContainer, 0.2, 0.4, 0.8, 0.6)
  
  -- Search scope icon (magnifying glass)
  local searchIcon = searchContainer:CreateTexture(nil, "OVERLAY")
  searchIcon:SetSize(16, 16)
  searchIcon:SetPoint("LEFT", searchContainer, "LEFT", 8, 0)
  searchIcon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
  searchIcon:SetVertexColor(0.6, 0.7, 0.8, 0.8)
  
  -- Create modern search box (repositioned for icons)
  local search = CreateFrame("EditBox", nil, searchContainer)
  search:SetSize(310, 16)  -- Reduced width to make room for icons
  search:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
  search:SetPoint("RIGHT", searchContainer, "RIGHT", -30, 0)  -- Leave space for clear button
  search:SetAutoFocus(false)
  search:SetFontObject("GameFontNormal")
  search:SetTextColor(0.9, 0.9, 1.0, 1.0)
  
  -- Clear button (X to delete text)
  local clearButton = CreateFrame("Button", nil, searchContainer)
  clearButton:SetSize(16, 16)
  clearButton:SetPoint("RIGHT", searchContainer, "RIGHT", -8, 0)
  
  -- Clear button texture
  local clearIcon = clearButton:CreateTexture(nil, "OVERLAY")
  clearIcon:SetAllPoints()
  clearIcon:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
  clearIcon:SetVertexColor(0.6, 0.6, 0.7, 0.8)
  
  -- Clear button hover effect
  clearButton:SetScript("OnEnter", function()
    clearIcon:SetVertexColor(1.0, 0.4, 0.4, 1.0)  -- Red on hover
  end)
  clearButton:SetScript("OnLeave", function()
    clearIcon:SetVertexColor(0.6, 0.6, 0.7, 0.8)
  end)
  
  -- Clear button functionality
  clearButton:SetScript("OnClick", function()
    search:SetText("")
    search:ClearFocus()
    CRAFTERSBOARD_DB.filters.search = ""
    if UI.Force then UI.Force() end
  end)
  
  -- Show/hide clear button based on text content
  local function updateClearButton()
    if search:GetText() and search:GetText() ~= "" then
      clearButton:Show()
    else
      clearButton:Hide()
    end
  end
  
  -- Search placeholder text (adjusted position for icon)
  local searchPlaceholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  searchPlaceholder:SetPoint("LEFT", search, "LEFT", 2, 0)
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
    updateClearButton()  -- Update clear button visibility
    CRAFTERSBOARD_DB.filters.search = CB.trim(self:GetText():lower() or "")
    if UI.Force then UI.Force() end
  end)
  search:SetText(CRAFTERSBOARD_DB.filters.search or "")
  if search:GetText() ~= "" then
    searchPlaceholder:Hide()
  end
  updateClearButton()  -- Initial clear button state
  
  -- Store search reference
  UI.search = search
  
  -- Modern content area with MinimalScrollBar (Anniversary Edition)
  local scrollContainer = CreateFrame("Frame", nil, f)
  scrollContainer:SetPoint("TOPLEFT", searchArea, "BOTTOMLEFT", 8, -8)
  scrollContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 25)  -- Extra space for resize handle under scroll bar
  
  -- Container background
  SetBackdropCompat(scrollContainer, {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  SetBackdropColorCompat(scrollContainer, 0.02, 0.03, 0.06, 0.9)
  SetBackdropBorderColorCompat(scrollContainer, 0.15, 0.25, 0.4, 0.7)
  
  -- Create scroll frame with fallback for Classic compatibility
  local scroll
  local useMinimalScrollBar = false
  
  -- Try MinimalScrollBar first (Anniversary Edition)
  if MinimalScrollBarTemplate or MinimalScrollBar then
    local success, result = pcall(function()
      scroll = CreateFrame("ScrollFrame", f:GetName().."Scroll", scrollContainer, "MinimalScrollBar")
      
      -- Test if CallbackRegistry is properly available
      if scroll.OnLoad then
        scroll:OnLoad()
      end
      
      -- Verify callback registry is working
      if scroll.callbackTables == nil then
        -- Try to initialize manually
        scroll.callbackTables = {}
        local CallbackType = { Closure = 1, Function = 2 }
        for callbackType, value in pairs(CallbackType) do
          scroll.callbackTables[value] = {}
        end
      end
      
      -- Test if the scroll bar actually works
      if scroll.SetScrollPercentage then
        scroll:SetScrollPercentage(0)  -- Test call
      end
      
      return true
    end)
    
    if success and result and scroll then
      useMinimalScrollBar = true
      CB.DebugPrint("Successfully initialized MinimalScrollBar for modern scroll appearance")
    else
      CB.DebugPrint("MinimalScrollBar failed (callback registry issue), falling back to styled UIPanelScrollFrameTemplate")
      if scroll then
        scroll:Hide()
        scroll = nil
      end
    end
  else
    CB.DebugPrint("MinimalScrollBar template not available, using styled UIPanelScrollFrameTemplate")
  end
  
  -- Fallback to standard scroll frame with custom minimal scroll bar styling
  if not useMinimalScrollBar then
    scroll = CreateFrame("ScrollFrame", f:GetName().."Scroll", scrollContainer, "UIPanelScrollFrameTemplate")
    
    -- Create a custom minimal scroll bar that looks like Anniversary Edition
    local scrollBar = scroll.ScrollBar or _G[scroll:GetName().."ScrollBar"]
    if scrollBar then
      CB.DebugPrint("Creating custom minimal scroll bar design")
      
      -- Hide the standard scroll bar completely
      scrollBar:Hide()
      
      -- Create our custom minimal scroll bar
      local customScrollBar = CreateFrame("Frame", nil, scrollContainer)
      customScrollBar:SetPoint("TOPRIGHT", scrollContainer, "TOPRIGHT", -4, -4)
      customScrollBar:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -4, 4)
      customScrollBar:SetWidth(12)
      
      -- Minimal track background (very subtle)
      local track = customScrollBar:CreateTexture(nil, "BACKGROUND")
      track:SetAllPoints()
      track:SetColorTexture(0.1, 0.1, 0.15, 0.3)  -- Very subtle dark track
      
      -- Create minimal thumb
      local thumb = CreateFrame("Button", nil, customScrollBar)
      thumb:SetWidth(8)
      thumb:SetPoint("TOP", customScrollBar, "TOP", 0, 0)
      
      -- Thumb texture (sleek minimal design)
      local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
      thumbTex:SetAllPoints()
      thumbTex:SetColorTexture(0.4, 0.5, 0.7, 0.8)  -- Modern blue-gray
      
      -- Thumb hover effect
      thumb:SetScript("OnEnter", function()
        thumbTex:SetColorTexture(0.5, 0.6, 0.8, 0.9)
      end)
      thumb:SetScript("OnLeave", function()
        thumbTex:SetColorTexture(0.4, 0.5, 0.7, 0.8)
      end)
      
      -- Scroll functionality
      local function updateThumb()
        local scrollRange = scroll:GetVerticalScrollRange()
        local scrollValue = scroll:GetVerticalScroll()
        local trackHeight = customScrollBar:GetHeight()
        
        if scrollRange > 0 then
          local thumbHeight = math.max(20, trackHeight * (trackHeight / (trackHeight + scrollRange)))
          local thumbPos = (scrollValue / scrollRange) * (trackHeight - thumbHeight)
          
          thumb:SetHeight(thumbHeight)
          thumb:ClearAllPoints()
          thumb:SetPoint("TOP", customScrollBar, "TOP", 0, -thumbPos)
          customScrollBar:Show()
        else
          customScrollBar:Hide()
        end
      end
      
      -- Dragging functionality
      local isDragging = false
      local startY, startScroll
      
      thumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
          isDragging = true
          startY = select(2, GetCursorPosition())
          startScroll = scroll:GetVerticalScroll()
          self:SetScript("OnUpdate", function()
            if isDragging then
              local currentY = select(2, GetCursorPosition())
              local deltaY = (startY - currentY) / self:GetEffectiveScale()
              local scrollRange = scroll:GetVerticalScrollRange()
              local trackHeight = customScrollBar:GetHeight()
              local thumbHeight = thumb:GetHeight()
              
              if scrollRange > 0 and trackHeight > thumbHeight then
                local scrollPercent = deltaY / (trackHeight - thumbHeight)
                local newScroll = math.max(0, math.min(scrollRange, startScroll + (scrollPercent * scrollRange)))
                scroll:SetVerticalScroll(newScroll)
                updateThumb()
              end
            end
          end)
        end
      end)
      
      thumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
          isDragging = false
          self:SetScript("OnUpdate", nil)
        end
      end)
      
      -- Track click to scroll
      customScrollBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
          local y = select(2, GetCursorPosition()) / self:GetEffectiveScale()
          local trackTop = self:GetTop()
          local thumbTop = thumb:GetTop()
          local thumbBottom = thumb:GetBottom()
          
          if y > thumbTop then
            -- Click above thumb - scroll up
            scroll:SetVerticalScroll(math.max(0, scroll:GetVerticalScroll() - 100))
          elseif y < thumbBottom then
            -- Click below thumb - scroll down
            scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() + 100))
          end
          updateThumb()
        end
      end)
      
      -- Mouse wheel support
      scroll:SetScript("OnMouseWheel", function(self, delta)
        local newScroll = self:GetVerticalScroll() - (delta * 40)
        newScroll = math.max(0, math.min(self:GetVerticalScrollRange(), newScroll))
        self:SetVerticalScroll(newScroll)
        updateThumb()
      end)
      
      -- Update thumb when content changes
      scroll:SetScript("OnScrollRangeChanged", updateThumb)
      scroll:SetScript("OnVerticalScroll", updateThumb)
      
      -- Store reference for updates
      scroll.customScrollBar = customScrollBar
      scroll.updateThumb = updateThumb
      
      CB.DebugPrint("Custom minimal scroll bar created successfully")
    else
      CB.DebugPrint("Warning: Could not find scroll bar to replace")
    end
  end
  
  -- Set positioning based on scroll bar type
  if useMinimalScrollBar then
    scroll:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -18, 6)  -- Space for minimal scroll bar
  else
    scroll:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -18, 6)  -- Space for custom minimal scroll bar
  end
  
  scroll:SetFrameStrata("DIALOG")
  
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
  
  -- Guild scan button (repositioned to the right side of search area)
  local btnGuildScan = CreateFrame("Button", nil, searchArea, "UIPanelButtonTemplate")
  btnGuildScan:SetPoint("RIGHT", searchArea, "RIGHT", -12, 0)
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
  lblScan:SetPoint("RIGHT", btnGuildScan, "LEFT", -8, 0)
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
    
    -- Update custom scroll bar if it exists
    if UI.scroll.updateThumb then
      C_Timer.After(0.05, function()
        if UI.scroll.updateThumb then
          UI.scroll.updateThumb()
        end
      end)
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
      (UI.activeKind == "PROVIDER" and "Crafters" or UI.activeKind == "REQUESTER" and "Requests" or "Guild Crafters"))
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
  
  -- Add credits text (bottom-left, opposite the resize handle)
  local credits = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  credits:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
  credits:SetText("CraftersBoard v1.0 by Squall#69")
  credits:SetTextColor(0.6, 0.7, 0.8, 0.8)  -- Subtle blue-gray color
  
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
