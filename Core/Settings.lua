-- CraftersBoard - Settings Panel

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

-- UI namespace (shared with UI.lua)
CB.UI = CB.UI or {}
local UI = CB.UI

-- Forward declarations
local createOptionsPanel, OpenOptionsPanel, EnsureOptionsCategory

-- Helper functions for creating UI controls (now defined within createOptionsPanel for scroll support)
-- These are placeholders - actual functions are defined in createOptionsPanel

-- Refresh function for options panel
function UI.RefreshOptionsPanel()
  if not UI.optionControls then return end
  
  for name, ctrl in pairs(UI.optionControls) do
    if ctrl.checkbox then
      ctrl.checkbox:SetChecked(ctrl.getter() and true or false)
    elseif ctrl.editbox then
      ctrl.editbox:SetText(ctrl.getter() or "")
    elseif ctrl.dropdown and ctrl.refresh then
      ctrl.refresh()
    end
  end
end

-- Main options panel creation
function createOptionsPanel()
  if UI.optionsPanel then return end

  -- Create panel exactly like Blizzard interface options
  local panel = CreateFrame("Frame", "CraftersBoardOptionsPanel")
  panel.name = "CraftersBoard"
  panel:Hide()
  
  -- No custom background - let Blizzard handle it
  
  -- Add panel event handlers
  panel:SetScript("OnShow", function(self)
    if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
    -- Update content size when shown
    if UI.UpdateSettingsContentSize then
      C_Timer.After(0.1, UI.UpdateSettingsContentSize)
    end
  end)
  
  UI.optionsPanel = panel

  -- Use modern Legion-era scroll frame (WoW Classic has Legion 7.3.5 engine)
  local scrollFrame = CreateFrame("ScrollFrame", "CraftersBoardSettingsScrollFrame", panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 4)
  
  -- The UIPanelScrollFrameTemplate automatically creates the scroll bar
  -- Just make sure it's positioned correctly
  local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName().."ScrollBar"]
  if scrollBar then
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 6, -16)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 6, 16)
  end
  
  -- Create scrollable content frame with proper modern layout
  local scrollContent = CreateFrame("Frame", nil, scrollFrame)
  scrollContent:SetSize(1, 1) -- Will be resized later
  scrollFrame:SetScrollChild(scrollContent)
  
  -- Modern scrolling behavior
  scrollFrame:EnableMouseWheel(true)
  scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local newValue = self:GetVerticalScroll() - (delta * 20)
    if newValue < 0 then
      newValue = 0
    elseif newValue > self:GetVerticalScrollRange() then
      newValue = self:GetVerticalScrollRange()
    end
    self:SetVerticalScroll(newValue)
  end)
  
  -- Store references
  UI.settingsScrollFrame = scrollFrame
  UI.settingsScrollContent = scrollContent
  UI.settingsPanel = panel
  
  -- Auto-resize content based on actual content height
  local function UpdateContentSize()
    local maxY = 0
    local children = { scrollContent:GetChildren() }
    for _, child in ipairs(children) do
      if child:IsShown() then
        local bottom = child:GetBottom()
        if bottom and bottom < maxY then
          maxY = bottom
        end
      end
    end
    -- Add padding and convert to positive height
    local contentHeight = math.max(600, math.abs(maxY) + 100)
    local contentWidth = scrollFrame:GetWidth() - 20
    scrollContent:SetSize(contentWidth, contentHeight)
  end
  
  -- Store the update function for external use
  UI.UpdateSettingsContentSize = UpdateContentSize
  
  -- Update content size after all controls are created
  C_Timer.After(0.2, function()
    UpdateContentSize()
    -- Additional delay to ensure all UI elements are positioned
    C_Timer.After(0.1, UpdateContentSize)
  end)

  -- Helper functions exactly like Blizzard interface options
  local function ScrollTitle(text, x, y)
    local t = scrollContent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", x, y)
    t:SetText(text)
    t:SetJustifyH("LEFT")
    return t
  end

  local function ScrollSubText(text, x, y)
    local t = scrollContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", x, y)
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    t:SetText(text)
    t:SetWordWrap(true)
    t:SetWidth(500)
    return t
  end

  -- Standard separator
  local function ScrollSeparator(x, y, width)
    local spacer = CreateFrame("Frame", nil, scrollContent)
    spacer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", x, y)
    spacer:SetSize(width or 500, 16)
    return spacer
  end

  local function ScrollCheck(name, label, tooltip, getter, setter, x, y)
    -- Use SettingsCheckBoxTemplate for modern Legion UI - fallback to older template if not available
    local template = "SettingsCheckBoxTemplate"
    local cb = CreateFrame("CheckButton", name, scrollContent, template)
    
    -- Fallback if modern template doesn't exist
    if not cb then
      cb = CreateFrame("CheckButton", name, scrollContent, "OptionsBaseCheckButtonTemplate")
    end
    
    cb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", x, y)
    
    -- Set label using Legion's modern system
    if cb.Text then
      cb.Text:SetText(label)
    else
      -- Fallback for older templates
      local txt = _G[name.."Text"]
      if txt then 
        txt:SetText(label)
      else
        txt = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        txt:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        txt:SetText(label)
        cb.Text = txt
      end
    end
    
    -- Modern tooltip support with improved styling
    cb:SetScript("OnEnter", function(self)
      if not tooltip or tooltip == "" then return end
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:SetText(label, 1, 1, 1, 1, true)
      GameTooltip:AddLine(tooltip, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() 
      GameTooltip:Hide()
    end)
    
    cb:SetScript("OnShow", function(self) 
      self:SetChecked(getter() and true or false) 
    end)
    cb:SetScript("OnClick", function(self)
      local v = self:GetChecked() and true or false
      setter(v)
      if UI and UI.Force then UI.Force() end
    end)
    
    -- Store reference for refreshing
    if not UI.optionControls then UI.optionControls = {} end
    UI.optionControls[name] = { checkbox = cb, getter = getter }
    
    return cb
  end

  local function ScrollEdit(name, width, x, y, label, tooltip, get, set)
    local lbl = scrollContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", x, y)
    lbl:SetText(label)

    -- Use standard InputBoxTemplate for clean, traditional styling
    local eb = CreateFrame("EditBox", name, scrollContent, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetSize(width, 22)
    eb:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
    
    -- Modern tooltip support with improved styling
    eb:SetScript("OnEnter", function(self)
      if not tooltip or tooltip == "" then return end
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:SetText(label, 1, 1, 1, 1, true)
      GameTooltip:AddLine(tooltip, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    eb:SetScript("OnLeave", function() 
      GameTooltip:Hide()
    end)
    
    eb:SetScript("OnShow", function(self) 
      self:SetText(get() or "") 
    end)
    eb:SetScript("OnTextChanged", function(self) 
      -- Auto-apply for simple text fields
      if label == "Channel hints (comma-separated)" then
        set(self:GetText() or "")
      end
    end)
    eb:SetScript("OnEnterPressed", function(self)
      set(self:GetText() or "")
      self:ClearFocus()
      print("|cffffff00CraftersBoard|r saved: " .. label)
      if UI and UI.Force then UI.Force() end
    end)
    eb:SetScript("OnEscapePressed", function(self) 
      self:SetText(get() or "")
      self:ClearFocus()
    end)
    eb:SetCursorPosition(0)

    local btn = CreateFrame("Button", name.."Apply", scrollContent, "UIPanelButtonTemplate")
    btn:SetSize(60, 22)
    btn:SetPoint("LEFT", eb, "RIGHT", 4, 0)
    btn:SetText("Apply")
    btn:SetScript("OnClick", function()
      set(eb:GetText() or "")
      print("|cffffff00CraftersBoard|r saved: " .. label)
      if UI and UI.Force then UI.Force() end
    end)

    -- Store reference for refreshing
    if not UI.optionControls then UI.optionControls = {} end
    UI.optionControls[name] = { editbox = eb, getter = get }

    return eb, btn, lbl
  end

  local function ScrollDropdown(name, x, y, label, tooltip, options, getter, setter)
    local lbl = scrollContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", x, y)
    lbl:SetText(label)

    local dropdown = CreateFrame("Frame", name, scrollContent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -15, -4)
    
    -- Modern tooltip support with improved styling
    if tooltip and tooltip ~= "" then
      dropdown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(label, 1, 1, 1, 1, true)
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
      end)
      dropdown:SetScript("OnLeave", function() 
        GameTooltip:Hide() 
      end)
    end

    -- Initialize dropdown
    UIDropDownMenu_SetWidth(dropdown, 200)
    UIDropDownMenu_Initialize(dropdown, function(self, level)
      for _, option in ipairs(options) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = option.text
        info.value = option.value
        info.func = function()
          setter(option.value)
          UIDropDownMenu_SetSelectedValue(dropdown, option.value)
          print("|cffffff00CraftersBoard|r changed " .. label .. " to: " .. option.text)
          if UI and UI.Force then UI.Force() end
        end
        info.checked = (getter() == option.value)
        UIDropDownMenu_AddButton(info, level)
      end
    end)
    
    -- Set initial value
    UIDropDownMenu_SetSelectedValue(dropdown, getter())
    UIDropDownMenu_SetText(dropdown, "")
    for _, option in ipairs(options) do
      if option.value == getter() then
        UIDropDownMenu_SetText(dropdown, option.text)
        break
      end
    end

    -- Store reference for refreshing
    if not UI.optionControls then UI.optionControls = {} end
    UI.optionControls[name] = { 
      dropdown = dropdown, 
      getter = getter,
      options = options,
      refresh = function()
        local currentValue = getter()
        UIDropDownMenu_SetSelectedValue(dropdown, currentValue)
        for _, option in ipairs(options) do
          if option.value == currentValue then
            UIDropDownMenu_SetText(dropdown, option.text)
            break
          end
        end
      end
    }

    return dropdown, lbl
  end

  -- Create all the settings controls using standard Blizzard styling
  ScrollTitle("CraftersBoard Settings", 16, -16)
  ScrollSubText("Configure filtering and display options for the addon.", 16, -44)
  
  ScrollSeparator(16, -70, 500)

  -- General Settings Section
  local sectionY = -90
  ScrollTitle("General Settings", 16, sectionY)
  
  -- Create checkboxes with standard spacing
  ScrollCheck("CBOptShowMinimap", "Show minimap button", 
    "Toggle the minimap button visibility", 
    function() return CRAFTERSBOARD_DB.minimap.show end,
    function(v) CRAFTERSBOARD_DB.minimap.show = v; if CB.UpdateMinimapButton then CB.UpdateMinimapButton() end end,
    16, sectionY - 32)

  ScrollCheck("CBOptStrictMode", "Strict filtering", 
    "Drop non-crafting messages more aggressively", 
    function() return CRAFTERSBOARD_DB.filters.strict end,
    function(v) CRAFTERSBOARD_DB.filters.strict = v end,
    16, sectionY - 56)

  ScrollCheck("CBOptDebugMode", "Enable debug output", 
    "Show debug messages in chat for troubleshooting", 
    function() return CRAFTERSBOARD_DB.debug end,
    function(v) CRAFTERSBOARD_DB.debug = v end,
    16, sectionY - 80)

  -- Appearance Section
  local appearanceY = sectionY - 120
  ScrollSeparator(16, appearanceY + 10, 500)
  ScrollTitle("Appearance", 16, appearanceY)
  
  -- Theme selection dropdown
  ScrollDropdown("CBOptThemeSelect", 16, appearanceY - 32, "UI Theme", 
    "Choose a color theme based on Classic WoW expansions",
    {
      { text = "Default Blue", value = "default" },
      { text = "Vanilla Anniversary (Gold)", value = "vanilla" },
      { text = "Hardcore (Red)", value = "hardcore" },
      { text = "Burning Crusade (Fel Green)", value = "tbc" },
      { text = "Wrath of the Lich King (Ice Blue)", value = "wotlk" }
    },
    function() return CRAFTERSBOARD_DB.theme or "default" end,
    function(v) 
      local currentTheme = CRAFTERSBOARD_DB.theme or "default"
      if v == currentTheme then return end -- No change needed
      
      -- Show confirmation dialog for theme change
      CB.ShowThemeChangeConfirmation(v)
    end)

  -- Filtering Section
  local filteringY = appearanceY - 100
  ScrollSeparator(16, filteringY + 10, 500)
  ScrollTitle("Filtering & Channels", 16, filteringY)
  
  -- Channel hints input
  ScrollEdit("CBOptChannelHints", 300, 16, filteringY - 32, "Channel hints (comma-separated)", 
    "Channels to monitor for crafting messages (e.g. general,trade,commerce)",
    function() 
      local hints = CRAFTERSBOARD_DB.filters.channelHints or {}
      return table.concat(hints, ",")
    end,
    function(v)
      local hints = {}
      for hint in (v or ""):gmatch("[^,]+") do
        local trimmed = CB.trim(hint)
        if trimmed ~= "" then
          table.insert(hints, trimmed:lower())
        end
      end
      CRAFTERSBOARD_DB.filters.channelHints = hints
    end)

  -- Max entries input
  ScrollEdit("CBOptMaxEntries", 100, 16, filteringY - 100, "Max entries", 
    "Maximum number of entries to keep in memory",
    function() return tostring(CRAFTERSBOARD_DB.maxEntries or 300) end,
    function(v)
      local n = tonumber(v) or 300
      CRAFTERSBOARD_DB.maxEntries = math.max(50, math.min(1000, n))
    end)

  -- Request Templates section
  local templatesY = filteringY - 160
  ScrollSeparator(16, templatesY + 10, 500)
  ScrollTitle("Request Message Templates", 16, templatesY)
  ScrollSubText("Customize the predefined whisper messages for requesting materials and pricing.", 16, templatesY - 24)

  -- Ask for mats template
  ScrollEdit("CBOptAskMatsTemplate", 450, 16, templatesY - 56, "Ask for materials template", 
    "Template message for asking about required materials",
    function() return CRAFTERSBOARD_DB.requestTemplates.askForMats end,
    function(v) CRAFTERSBOARD_DB.requestTemplates.askForMats = v or CB.DEFAULTS.requestTemplates.askForMats end)

  -- Ask for price template  
  ScrollEdit("CBOptAskPriceTemplate", 450, 16, templatesY - 124, "Ask for price template", 
    "Template message for asking about pricing",
    function() return CRAFTERSBOARD_DB.requestTemplates.askForPrice end,
    function(v) CRAFTERSBOARD_DB.requestTemplates.askForPrice = v or CB.DEFAULTS.requestTemplates.askForPrice end)

  -- Utilities section
  local utilitiesY = templatesY - 190
  ScrollSeparator(16, utilitiesY + 10, 500)
  ScrollTitle("Utilities", 16, utilitiesY)
  
  -- Add utility buttons with standard Blizzard styling
  local pruneBtn = CreateFrame("Button", nil, scrollContent, "UIPanelButtonTemplate")
  pruneBtn:SetSize(120, 24)
  pruneBtn:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 16, utilitiesY - 32)
  pruneBtn:SetText("Prune Old Entries")
  pruneBtn:SetScript("OnClick", function()
    if CB.pruneEntries then
      local removed = CB.pruneEntries(3600) -- 1 hour
      print("|cffffff00CraftersBoard|r Removed " .. removed .. " old entries")
      if UI.Force then UI.Force() end
    end
  end)

  local clearBtn = CreateFrame("Button", nil, scrollContent, "UIPanelButtonTemplate")
  clearBtn:SetSize(120, 24)
  clearBtn:SetPoint("LEFT", pruneBtn, "RIGHT", 8, 0)
  clearBtn:SetText("Clear All Entries")
  clearBtn:SetScript("OnClick", function()
    CRAFTERSBOARD_DB.entries = {}
    print("|cffffff00CraftersBoard|r Cleared all entries")
    if UI.Force then UI.Force() end
  end)

  local resetBtn = CreateFrame("Button", nil, scrollContent, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 24)
  resetBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
  resetBtn:SetText("Reset Settings")
  resetBtn:SetScript("OnClick", function()
    -- Reset to defaults
    for k, v in pairs(CB.DEFAULTS or {}) do
      if k ~= "entries" then -- Don't reset entries
        CRAFTERSBOARD_DB[k] = (type(v) == "table") and CB.deepcopy(v) or v
      end
    end
    print("|cffffff00CraftersBoard|r Settings reset to defaults")
    if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
    if UI.Force then UI.Force() end
  end)

  -- Instructions section
  local instructionsY = utilitiesY - 80
  ScrollSeparator(16, instructionsY + 10, 500)
  ScrollTitle("Usage Instructions", 16, instructionsY)
  ScrollSubText("Use /cb to open the main window, /cb config to open settings, or /cb help for command list.", 16, instructionsY - 24)
  ScrollSubText("Addon automatically scans chat channels for crafting requests and service offers.", 16, instructionsY - 44)
  ScrollSubText("Use mouse wheel to scroll in this panel or the scrollbar on the right.", 16, instructionsY - 64)
  ScrollSubText("Click the gear icon in the main window title bar to quickly access these settings.", 16, instructionsY - 84)

  return panel
end

-- Theme change confirmation dialog using WoW's built-in StaticPopup system
function CB.ShowThemeChangeConfirmation(newTheme)
  -- Get theme name for display
  local themeNames = {
    default = "Default Blue",
    vanilla = "Vanilla Anniversary (Gold)",
    hardcore = "Hardcore (Red)",
    tbc = "Burning Crusade (Fel Green)",
    wotlk = "Wrath of the Lich King (Ice Blue)"
  }
  
  local themeName = themeNames[newTheme] or newTheme
  
  -- Register the popup if it doesn't exist
  if not StaticPopupDialogs["CRAFTERSBOARD_THEME_CHANGE"] then
    StaticPopupDialogs["CRAFTERSBOARD_THEME_CHANGE"] = {
      text = "Changing the theme requires a UI reload to take full effect.\n\nNew theme: %s\n\nReload now?",
      button1 = "OK",
      button2 = "Cancel",
      OnAccept = function(self, data)
        -- Apply the theme change
        CRAFTERSBOARD_DB.theme = data.theme
        print("|cffffff00CraftersBoard|r Theme changed to: " .. data.themeName)
        
        -- Reload UI
        ReloadUI()
      end,
      OnCancel = function()
        -- Refresh the dropdown to show the original value
        if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,  -- Avoid some UI taint issues
    }
  end
  
  -- Show the popup with theme data
  local popup = StaticPopup_Show("CRAFTERSBOARD_THEME_CHANGE", themeName)
  if popup then
    popup.data = { theme = newTheme, themeName = themeName }
  end
end

-- Ensure options category registration
function EnsureOptionsCategory()
  if not UI.optionsPanel then return false end
  if UI.optionsRegistered then return true end -- Prevent duplicate registration
  
  -- Try multiple methods for registering the options panel
  -- Method 1: InterfaceOptions_AddCategory (Classic/TBC)
  if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(UI.optionsPanel)
    UI.optionsRegistered = true
    return true
  end
  
  -- Method 2: Settings.RegisterCanvasLayoutCategory (Retail 10.0+)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(UI.optionsPanel, UI.optionsPanel.name)
    if category then
      Settings.RegisterAddOnCategory(category)
      UI.optionsRegistered = true
      return true
    end
  end
  
  -- Method 3: InterfaceOptionsFrame direct access
  if InterfaceOptionsFrame and InterfaceOptionsFrame.AddOns then
    InterfaceOptionsFrame.AddOns.CraftersBoard = UI.optionsPanel
    UI.optionsRegistered = true
    return true
  end
  
  return false
end

-- Open options panel
function OpenOptionsPanel()
  if not UI.optionsPanel then createOptionsPanel() end
  if not EnsureOptionsCategory() then
    print("|cffffff00CraftersBoard|r Warning: Could not register with Blizzard options. Using standalone mode.")
  end
  
  -- Try multiple methods to open the AddOns tab with CraftersBoard settings
  
  -- Method 1: InterfaceOptionsFrame_OpenToCategory (Classic/TBC/WotLK)
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(UI.optionsPanel)
    
    -- Try to navigate to AddOns category specifically
    if InterfaceOptionsFrame and InterfaceOptionsFrame.SetAddOnCategory then
      InterfaceOptionsFrame:SetAddOnCategory("CraftersBoard")
    end
    
    -- Refresh the options panel to show current values
    if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
    print("|cffffff00CraftersBoard|r Settings opened in Interface Options")
    return
  end
  
  -- Method 2: Settings.OpenToCategory (Retail 10.0+)
  if Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(UI.optionsPanel.name)
    -- Refresh the options panel to show current values
    if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
    print("|cffffff00CraftersBoard|r Settings opened in Settings panel")
    return
  end
  
  -- Method 3: Direct InterfaceOptionsFrame access and navigation
  if InterfaceOptionsFrame then
    -- Show the interface options frame
    if not InterfaceOptionsFrame:IsShown() then
      InterfaceOptionsFrame:Show()
    end
    
    -- Try to select the AddOns category
    if InterfaceOptionsFrameAddOns then
      InterfaceOptionsFrameAddOns:Click()
    elseif InterfaceOptionsFrame.AddOns then
      -- Try to navigate to AddOns section
      local addOnsButton = InterfaceOptionsFrame.AddOns
      if addOnsButton and addOnsButton.Click then
        addOnsButton:Click()
      end
    end
    
    -- Look for CraftersBoard in the addon list
    C_Timer.After(0.1, function()
      if InterfaceOptionsFrameAddOns and InterfaceOptionsFrameAddOns.ScrollFrame then
        local scrollFrame = InterfaceOptionsFrameAddOns.ScrollFrame
        if scrollFrame.buttons then
          for _, button in ipairs(scrollFrame.buttons) do
            if button.element and button.element.name == "CraftersBoard" then
              button:Click()
              break
            end
          end
        end
      end
    end)
    
    -- Refresh the options panel to show current values
    if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
    print("|cffffff00CraftersBoard|r Interface Options opened - look for CraftersBoard in AddOns")
    return
  end
  
  -- Method 4: Fallback - show panel directly with enhanced functionality
  UI.optionsPanel:SetParent(UIParent)
  UI.optionsPanel:SetFrameStrata("HIGH")
  UI.optionsPanel:ClearAllPoints()
  UI.optionsPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  
  -- Add close button for standalone mode
  if not UI.optionsPanel.closeBtn then
    local closeBtn = CreateFrame("Button", nil, UI.optionsPanel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", UI.optionsPanel, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() UI.optionsPanel:Hide() end)
    UI.optionsPanel.closeBtn = closeBtn
  end
  
  UI.optionsPanel:Show()
  UI.optionsPanel:Raise()
  
  -- Refresh the options panel to show current values
  if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
  
  print("|cffffff00CraftersBoard|r Settings panel opened (standalone mode)")
end

-- Export functions
CB.createOptionsPanel = createOptionsPanel
CB.OpenOptionsPanel = OpenOptionsPanel
CB.EnsureOptionsCategory = EnsureOptionsCategory
