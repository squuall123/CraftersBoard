-- CraftersBoard - Database Management

local CB = CraftersBoard
CB.DEFAULTS = {
  filters = {
    showProviders = true,
    showRequesters = true,
    search = "",
    channelHints = {"general","trade","commerce","lookingforgroup","services"},
    strict = true,
    noiseCustom = { raids = {}, groups = {}, roles = {}, boosts = {} },
    showOfflineMembers = false,
    showFavoritesOnly = false,
    showRecentOnly = false,
  },
  debug = false,
  entries = {},
  maxEntries = 300,
  minimap = { show = true, angle = 200 },
  collapsed = { PROVIDER = {}, REQUESTER = {}, GUILD = {} },
  guildScan = { lastScan = 0, members = {} },
  window = { w = 840, h = 420, point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
  muted = { players = {}, phrases = {} },
  lastTab = 1,
  theme = "default",
  requestTemplates = {
    askForMats = "Hi! Could you please tell me what materials you need for your crafting services? Thanks!",
    askForPrice = "Hello! Could you please let me know your pricing for crafting services? Thank you!"
  },
}

function CB.InitDatabase()
  if type(CRAFTERSBOARD_DB) ~= "table" then CRAFTERSBOARD_DB = {} end
  
  for k,v in pairs(CB.DEFAULTS) do
    if CRAFTERSBOARD_DB[k] == nil then
      CRAFTERSBOARD_DB[k] = (type(v) == "table") and CB.deepcopy(v) or v
    end
  end
  
  CRAFTERSBOARD_DB.entries   = CRAFTERSBOARD_DB.entries   or {}
  CRAFTERSBOARD_DB.minimap   = CRAFTERSBOARD_DB.minimap   or CB.deepcopy(CB.DEFAULTS.minimap)
  CRAFTERSBOARD_DB.collapsed = CRAFTERSBOARD_DB.collapsed or CB.deepcopy(CB.DEFAULTS.collapsed)
  CRAFTERSBOARD_DB.guildScan = CRAFTERSBOARD_DB.guildScan or CB.deepcopy(CB.DEFAULTS.guildScan)
  CRAFTERSBOARD_DB.window    = CRAFTERSBOARD_DB.window    or CB.deepcopy(CB.DEFAULTS.window)
  CRAFTERSBOARD_DB.muted     = CRAFTERSBOARD_DB.muted     or CB.deepcopy(CB.DEFAULTS.muted)
  CRAFTERSBOARD_DB.lastTab   = CRAFTERSBOARD_DB.lastTab   or CB.DEFAULTS.lastTab
  CRAFTERSBOARD_DB.filters   = CRAFTERSBOARD_DB.filters   or CB.deepcopy(CB.DEFAULTS.filters)
  CRAFTERSBOARD_DB.debug     = (CRAFTERSBOARD_DB.debug ~= nil) and CRAFTERSBOARD_DB.debug or CB.DEFAULTS.debug
  CRAFTERSBOARD_DB.theme     = CRAFTERSBOARD_DB.theme     or CB.DEFAULTS.theme
  CRAFTERSBOARD_DB.requestTemplates = CRAFTERSBOARD_DB.requestTemplates or CB.deepcopy(CB.DEFAULTS.requestTemplates)
  
  local f = CRAFTERSBOARD_DB.filters
  f.noiseCustom = f.noiseCustom or { raids = {}, groups = {}, roles = {}, boosts = {} }
  f.channelHints = f.channelHints or CB.deepcopy(CB.DEFAULTS.filters.channelHints)
  f.showProviders = (f.showProviders ~= nil) and f.showProviders or CB.DEFAULTS.filters.showProviders
  f.showRequesters = (f.showRequesters ~= nil) and f.showRequesters or CB.DEFAULTS.filters.showRequesters
  f.strict = (f.strict ~= nil) and f.strict or CB.DEFAULTS.filters.strict
  f.search = f.search or CB.DEFAULTS.filters.search
  f.showOfflineMembers = (f.showOfflineMembers ~= nil) and f.showOfflineMembers or CB.DEFAULTS.filters.showOfflineMembers
  f.showFavoritesOnly = (f.showFavoritesOnly ~= nil) and f.showFavoritesOnly or CB.DEFAULTS.filters.showFavoritesOnly
  f.showRecentOnly = (f.showRecentOnly ~= nil) and f.showRecentOnly or CB.DEFAULTS.filters.showRecentOnly
end

CB.initDB = CB.InitDatabase