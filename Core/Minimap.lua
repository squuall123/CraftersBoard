-- CraftersBoard - Minimap Button

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

CB.MMB = CB.MMB or { offset = -4 }
local MMB = CB.MMB

local UI = CB.UI

local cos, sin, rad, deg = math.cos, math.sin, math.rad, math.deg

local function MMB_UpdatePosition()
  if not MMB.button then return end
  local angle = CRAFTERSBOARD_DB.minimap.angle or 200
  local x = cos(rad(angle)) * 80
  local y = sin(rad(angle)) * 80
  MMB.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function MMB_OnDrag(self)
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  cx, cy = cx/scale, cy/scale
  local a = deg(CB.atan2(cy - my, cx - mx))
  if a < 0 then a = a + 360 end
  CRAFTERSBOARD_DB.minimap.angle = a
  MMB_UpdatePosition()
end

local function createMinimapButton()
  if MMB.button then return end
  
  CRAFTERSBOARD_DB.minimap = CRAFTERSBOARD_DB.minimap or { show = true, angle = 200 }
  
  local b = CreateFrame("Button", "CraftersBoard_MinimapButton", Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", MMB_OnDrag) end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

  -- Create textures
  local border = b:CreateTexture(nil, "BACKGROUND")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(54, 54)
  border:SetPoint("CENTER", 0, 0)
  
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_02")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 0)
  
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  hl:SetAllPoints(b)
  hl:SetBlendMode("ADD")

  -- Tooltip
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText("CraftersBoard", 1,1,1)
    GameTooltip:AddLine("Left-click: toggle window", .9,.9,.9)
    GameTooltip:AddLine("Right-click: switch tab", .9,.9,.9)
    GameTooltip:AddLine("Shift-right-click: hide button (/cb mmb on)", .9,.9,.9)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Click handlers
  b:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
      -- Toggle main window
      if CB.ToggleWindow then
        CB.ToggleWindow()
      elseif UI.frame then
        if UI.frame:IsShown() then
          UI.frame:Hide()
        else
          UI.frame:Show()
          if UI.Force then UI.Force() end
        end
      end
    else -- Right click
      if IsShiftKeyDown() then
        -- Hide button
        CRAFTERSBOARD_DB.minimap.show = false
        self:Hide()
        print("|cff00ff88CraftersBoard|r minimap button hidden. Use |cffffff00/cb mmb on|r to show.")
      else
        -- Switch tabs
        if UI.setActiveTab then
          local cur = (UI.activeKind == "PROVIDER") and 1 or (UI.activeKind == "REQUESTER" and 2 or 3)
          local nextId = (cur == 1 and 2) or (cur == 2 and 3) or 1
          UI.setActiveTab(nextId)
        end
      end
    end
  end)

  MMB.button = b
  MMB_UpdatePosition()
  
  -- Show/hide based on settings
  if CRAFTERSBOARD_DB.minimap.show ~= false then
    b:Show()
  else
    b:Hide()
  end
end

-- Update minimap button visibility
function CB.UpdateMinimapButton()
  if not MMB.button then return end
  
  if CRAFTERSBOARD_DB.minimap.show then
    MMB.button:Show()
  else
    MMB.button:Hide()
  end
end

-- Export functions
CB.createMinimapButton = createMinimapButton
CB.MMB_UpdatePosition = MMB_UpdatePosition
