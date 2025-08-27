-- CraftersBoard Auctionator Integration
-- Version: 1.0.0
-- Handles price tooltips and Auctionator integration

local ADDON_NAME = ...
local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
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
