-- CraftersBoard - Auctionator Integration
-- Version: 1.0.0
-- Handles price tooltips and Auctionator integration

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

-- Coin texture constants
local GOLD_TEX   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_TEX = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_TEX = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- Money formatting function
function CB.moneyTextureString(c)
  if not c or c <= 0 then return "—" end
  if GetCoinTextureString then return GetCoinTextureString(c) end
  
  local g = math.floor(c/10000)
  local s = math.floor((c%10000)/100)
  local cp = c % 100
  local parts = {}
  
  if g > 0 then table.insert(parts, g..GOLD_TEX) end
  if s > 0 or g > 0 then table.insert(parts, s..SILVER_TEX) end
  table.insert(parts, cp..COPPER_TEX)
  
  return table.concat(parts, " ")
end

-- Auctionator availability check
function CB.AuctionatorAvailable()
  return _G.Auctionator and Auctionator.API and Auctionator.API.v1
end

-- Get item price from Auctionator
function CB.GetItemPriceCopperByLink(link)
  if not CB.AuctionatorAvailable() then return nil end
  if not link then return nil end
  
  local itemId = link:match("item:(%d+)")
  if not itemId then return nil end
  
  return Auctionator.API.v1.GetAuctionPriceByItemID("CraftersBoard", tonumber(itemId))
end

-- Hook Auctionator when it becomes available
function CB.TryHookAuctionator()
  if not CB.AuctionatorAvailable() then return end
  
  -- Mark as available for other functions to use
  CB.auctionatorAvailable = true
end

-- Add price information to tooltips
function CB.AppendTooltipPrices(entry)
  if not CB.AuctionatorAvailable() then
    GameTooltip:AddLine("|cffff8888Auctionator not loaded — price data unavailable.|r")
    return
  end
  
  if not entry or not entry.links or #entry.links == 0 then
    return
  end
  
  local anyPrice = false
  for _, link in ipairs(entry.links) do
    local price = CB.GetItemPriceCopperByLink(link)
    if price and price > 0 then
      GameTooltip:AddLine(("  %s  %s"):format(link, CB.moneyTextureString(price)))
      anyPrice = true
    else
      GameTooltip:AddLine(("  %s  |cffaaaaaaPrice not available|r"):format(link))
    end
  end
  
  if anyPrice then
    GameTooltip:AddLine("|cffaaaaaa(Last scanned values; may be outdated.)|r")
  end
end

-- Initialize Auctionator integration flag
CB.auctionatorAvailable = false
