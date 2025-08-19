-- CraftersBoard - Settings Panel
-- Version: 1.0.0

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

-- Helper functions for creating UI controls
local function Title(parent, text, x, y)
  local t = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  t:SetText(text)
  return t
end

local function SubText(parent, text, x, y)
  local t = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  t:SetJustifyH("LEFT"); t:SetJustifyV("TOP")
  t:SetText(text)
  return t
end

local function mkCheck(name, parent, label, tooltip, getter, setter, x, y)
  local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local txt = _G[name.."Text"]
  if txt then txt:SetText(label) end
  cb:SetScript("OnEnter", function(self)
    if not tooltip or tooltip == "" then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(label, 1,1,1)
    GameTooltip:AddLine(tooltip, .9,.9,.9, true)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  cb:SetScript("OnShow", function(self) self:SetChecked(getter() and true or false) end)
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

local function mkEdit(name, parent, width, x, y, label, tooltip, get, set)
  local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  lbl:SetText(label)

  local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetSize(width, 24)
  eb:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -4)
  eb:SetScript("OnEnter", function(self)
    if not tooltip or tooltip=="" then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(label, 1,1,1)
    GameTooltip:AddLine(tooltip, .9,.9,.9, true)
    GameTooltip:Show()
  end)
  eb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  eb:SetScript("OnShow", function(self) self:SetText(get() or "") end)
  eb:SetScript("OnTextChanged", function(self) 
    -- Auto-apply for simple text fields, but keep manual apply for complex ones
    if label == "Channel hints (comma-separated)" then
      set(self:GetText() or "")
    end
  end)
  eb:SetScript("OnEnterPressed", function(self)
    set(self:GetText() or "")
    self:ClearFocus()
    print("|cff00ff88CraftersBoard|r saved: "..label)
    if UI and UI.Force then UI.Force() end
  end)
  eb:SetScript("OnEscapePressed", function(self) 
    self:SetText(get() or "")
    self:ClearFocus()
  end)
  eb:SetCursorPosition(0)

  local btn = CreateFrame("Button", name.."Apply", parent, "UIPanelButtonTemplate")
  btn:SetSize(60, 22)
  btn:SetPoint("LEFT", eb, "RIGHT", 4, 0)
  btn:SetText("Apply")
  btn:SetScript("OnClick", function()
    set(eb:GetText() or "")
    print("|cff00ff88CraftersBoard|r saved: "..label)
    if UI and UI.Force then UI.Force() end
  end)

  -- Store reference for refreshing
  if not UI.optionControls then UI.optionControls = {} end
  UI.optionControls[name] = { editbox = eb, getter = get }

  return eb, btn, lbl
end

-- Helper function to create dropdown menus
local function mkDropdown(name, parent, x, y, label, tooltip, options, getter, setter)
  local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  lbl:SetText(label)

  local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
  dropdown:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -15, -4)
  
  -- Tooltip support
  if tooltip and tooltip ~= "" then
    dropdown:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:SetText(label, 1, 1, 1)
      GameTooltip:AddLine(tooltip, 0.9, 0.9, 0.9, true)
      GameTooltip:Show()
    end)
    dropdown:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
        print("|cff00ff88CraftersBoard|r changed " .. label .. " to: " .. option.text)
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

  -- Parentless; Blizzard options will parent on add
  local panel = CreateFrame("Frame", "CraftersBoardOptionsPanel")
  panel.name = "CraftersBoard"
  panel:SetSize(600, 500) -- Set explicit size
  panel:Hide()
  
  -- Set background
  local bg = panel:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(panel)
  bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
  
  -- Add panel event handlers
  panel:SetScript("OnShow", function(self)
    if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
  end)
  
  UI.optionsPanel = panel

  Title(panel, "CraftersBoard Settings", 20, -20)
  SubText(panel, "Configure filtering and display options for the addon.", 20, -50)

  -- Create checkboxes
  mkCheck("CBOptShowMinimap", panel, "Show minimap button", 
    "Toggle the minimap button visibility", 
    function() return CRAFTERSBOARD_DB.minimap.show end,
    function(v) CRAFTERSBOARD_DB.minimap.show = v; if CB.UpdateMinimapButton then CB.UpdateMinimapButton() end end,
    20, -80)

  mkCheck("CBOptStrictMode", panel, "Strict filtering", 
    "Drop non-crafting messages more aggressively", 
    function() return CRAFTERSBOARD_DB.filters.strict end,
    function(v) CRAFTERSBOARD_DB.filters.strict = v end,
    20, -110)

  mkCheck("CBOptDebugMode", panel, "Enable debug output", 
    "Show debug messages in chat for troubleshooting", 
    function() return CRAFTERSBOARD_DB.debug end,
    function(v) CRAFTERSBOARD_DB.debug = v end,
    20, -140)

  -- Theme selection dropdown
  mkDropdown("CBOptThemeSelect", panel, 20, -180, "UI Theme", 
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

  -- Channel hints input
  mkEdit("CBOptChannelHints", panel, 300, 20, -240, "Channel hints (comma-separated)", 
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
  mkEdit("CBOptMaxEntries", panel, 100, 20, -310, "Max entries", 
    "Maximum number of entries to keep in memory",
    function() return tostring(CRAFTERSBOARD_DB.maxEntries or 300) end,
    function(v)
      local n = tonumber(v) or 300
      CRAFTERSBOARD_DB.maxEntries = math.max(50, math.min(1000, n))
    end)

  -- Request Templates section
  Title(panel, "Request Message Templates", 20, -360)
  SubText(panel, "Customize the predefined whisper messages for requesting materials and pricing.", 20, -385)

  -- Ask for mats template
  mkEdit("CBOptAskMatsTemplate", panel, 450, 20, -410, "Ask for materials template", 
    "Template message for asking about required materials",
    function() return CRAFTERSBOARD_DB.requestTemplates.askForMats end,
    function(v) CRAFTERSBOARD_DB.requestTemplates.askForMats = v or CB.DEFAULTS.requestTemplates.askForMats end)

  -- Ask for price template  
  mkEdit("CBOptAskPriceTemplate", panel, 450, 20, -480, "Ask for price template", 
    "Template message for asking about pricing",
    function() return CRAFTERSBOARD_DB.requestTemplates.askForPrice end,
    function(v) CRAFTERSBOARD_DB.requestTemplates.askForPrice = v or CB.DEFAULTS.requestTemplates.askForPrice end)

  -- Add utility buttons
  local pruneBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  pruneBtn:SetSize(120, 24)
  pruneBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -540)
  pruneBtn:SetText("Prune Old Entries")
  pruneBtn:SetScript("OnClick", function()
    if CB.pruneEntries then
      local removed = CB.pruneEntries(3600) -- 1 hour
      print("|cff00ff88CraftersBoard|r Removed " .. removed .. " old entries")
      if UI.Force then UI.Force() end
    end
  end)
  pruneBtn:SetText("Prune Old Entries")
  pruneBtn:SetScript("OnClick", function()
    if CB.pruneEntries then
      local removed = CB.pruneEntries(3600) -- 1 hour
      print("|cff00ff88CraftersBoard|r Removed " .. removed .. " old entries")
      if UI.Force then UI.Force() end
    end
  end)

  local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  clearBtn:SetSize(120, 24)
  clearBtn:SetPoint("LEFT", pruneBtn, "RIGHT", 10, 0)
  clearBtn:SetText("Clear All Entries")
  clearBtn:SetScript("OnClick", function()
    CRAFTERSBOARD_DB.entries = {}
    print("|cff00ff88CraftersBoard|r Cleared all entries")
    if UI.Force then UI.Force() end
  end)

  local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  resetBtn:SetSize(120, 24)
  resetBtn:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
  resetBtn:SetText("Reset Settings")
  resetBtn:SetScript("OnClick", function()
    -- Reset to defaults
    for k, v in pairs(CB.DEFAULTS or {}) do
      if k ~= "entries" then -- Don't reset entries
        CRAFTERSBOARD_DB[k] = (type(v) == "table") and CB.deepcopy(v) or v
      end
    end
    print("|cff00ff88CraftersBoard|r Settings reset to defaults")
    if UI.RefreshOptionsPanel then UI.RefreshOptionsPanel() end
    if UI.Force then UI.Force() end
  end)

  -- Instructions
  SubText(panel, "Use /cb to open the main window, /cb config to open settings, or /cb help for command list.", 20, -590)
  SubText(panel, "Addon automatically scans chat channels for crafting requests and service offers.", 20, -610)

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
        print("|cff00ff88CraftersBoard|r Theme changed to: " .. data.themeName)
        
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
    print("|cff00ff88CraftersBoard|r Warning: Could not register with Blizzard options. Using standalone mode.")
  end
  
  -- Try multiple methods to open
  -- Method 1: InterfaceOptionsFrame_OpenToCategory (Classic/TBC)
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(UI.optionsPanel)
    return
  end
  
  -- Method 2: Settings.OpenToCategory (Retail 10.0+)
  if Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(UI.optionsPanel.name)
    return
  end
  
  -- Method 3: Direct InterfaceOptionsFrame access
  if InterfaceOptionsFrame then
    if not InterfaceOptionsFrame:IsShown() then
      InterfaceOptionsFrame:Show()
    end
    return
  end
  
  -- Method 4: Fallback - show panel directly
  UI.optionsPanel:SetParent(UIParent)
  UI.optionsPanel:SetFrameStrata("HIGH")
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
  print("|cff00ff88CraftersBoard|r Options panel opened (standalone mode)")
end

-- Export functions
CB.createOptionsPanel = createOptionsPanel
CB.OpenOptionsPanel = OpenOptionsPanel
CB.EnsureOptionsCategory = EnsureOptionsCategory
