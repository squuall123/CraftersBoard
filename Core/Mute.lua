-- CraftersBoard - Mute System
-- Handles player and phrase muting

local CB = CraftersBoard

-- Name normalization
function CB.NormalizeName(name)
  name = name or ""
  name = name:gsub("%-.*$", "")
  return name:lower()
end

-- Player muting
function CB.IsPlayerMuted(name)
  local n = CB.NormalizeName(name)
  return CRAFTERSBOARD_DB.muted
     and CRAFTERSBOARD_DB.muted.players
     and CRAFTERSBOARD_DB.muted.players[n] == true
end

function CB.MutePlayer(name)
  CRAFTERSBOARD_DB.muted = CRAFTERSBOARD_DB.muted or { players = {}, phrases = {} }
  CRAFTERSBOARD_DB.muted.players = CRAFTERSBOARD_DB.muted.players or {}
  local n = CB.NormalizeName(name)
  CRAFTERSBOARD_DB.muted.players[n] = true
end

function CB.UnmutePlayer(name)
  if not CRAFTERSBOARD_DB.muted or not CRAFTERSBOARD_DB.muted.players then return end
  CRAFTERSBOARD_DB.muted.players[CB.NormalizeName(name)] = nil
end

-- Phrase muting
function CB.IsMessageMuted(msg)
  if not msg or msg == "" then return false end
  local m = msg:lower()
  local phrases = CRAFTERSBOARD_DB.muted and CRAFTERSBOARD_DB.muted.phrases
  if not phrases then return false end
  for phrase,_ in pairs(phrases) do
    if phrase ~= "" and m:find(phrase, 1, true) then return true end
  end
  return false
end

function CB.AddMutePhrase(text)
  text = (text or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  if text == "" then return end
  CRAFTERSBOARD_DB.muted = CRAFTERSBOARD_DB.muted or { players = {}, phrases = {} }
  CRAFTERSBOARD_DB.muted.phrases = CRAFTERSBOARD_DB.muted.phrases or {}
  CRAFTERSBOARD_DB.muted.phrases[text] = true
end

function CB.RemoveMutePhrase(text)
  if not CRAFTERSBOARD_DB.muted or not CRAFTERSBOARD_DB.muted.phrases then return end
  text = (text or ""):lower():gsub("^%s+",""):gsub("%s+$","")
  if text ~= "" then CRAFTERSBOARD_DB.muted.phrases[text] = nil end
end

-- Utility functions
function CB.DoWhoQuery(name)
  local q = (Ambiguate and Ambiguate(name or "", "none")) or (name or "")
  if q == "" then return end
  if C_FriendList and C_FriendList.SendWho then
    C_FriendList.SendWho("n-"..q)
  elseif SendWho then
    SendWho("n-"..q)
  else
    ChatFrame_OpenChat("/who "..q, SELECTED_DOCK_FRAME)
  end
end
