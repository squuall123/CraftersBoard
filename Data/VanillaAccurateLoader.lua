-- VanillaAccurateLoader.lua
-- Complete Recipe_Master integration for CraftersBoard
-- Provides 100% accurate Classic Era recipe data with 1553 recipes

local _, addon = ...

-- Initialize data structure for Recipe_Master format
if not addon.VanillaAccurateData then
    addon.VanillaAccurateData = {}
end

-- Also ensure global CraftersBoard table exists and copy data there
if not CraftersBoard then
    CraftersBoard = {}
end

-- Get all recipe data from profession files
function addon:LoadVanillaAccurateData()
    -- Recipe data is automatically loaded from Data/Recipes/*.lua files
    -- Each profession file populates addon.VanillaAccurateData[professionId]
    -- This function serves as a validation point
    
    local totalRecipes = 0
    for professionId, recipes in pairs(self.VanillaAccurateData) do
        local count = 0
        for _ in pairs(recipes) do
            count = count + 1
        end
        totalRecipes = totalRecipes + count
        -- Debug print only if enabled
        if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
            print("CraftersBoard: Loaded " .. count .. " recipes for profession " .. professionId)
        end
    end
    
    -- Debug print only if enabled
    if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
        print("CraftersBoard: Total recipes loaded: " .. totalRecipes)
    end
    
    -- Copy data to global CraftersBoard namespace for lookup functions
    CraftersBoard.VanillaAccurateData = self.VanillaAccurateData
    
    return totalRecipes > 0
end

-- Get recipe by item ID and profession
function addon:GetRecipe(professionId, itemId)
    if self.VanillaAccurateData[professionId] then
        return self.VanillaAccurateData[professionId][itemId]
    end
    return nil
end

-- Get all recipes for a profession
function addon:GetRecipesForProfession(professionId)
    return self.VanillaAccurateData[professionId] or {}
end

-- Get all item IDs for a profession
function addon:GetItemIdsForProfession(professionId)
    local itemIds = {}
    local profession = self.VanillaAccurateData[professionId]
    if profession then
        for itemId, _ in pairs(profession) do
            table.insert(itemIds, itemId)
        end
    end
    return itemIds
end

-- Get all spell IDs for a profession
function addon:GetSpellIdsForProfession(professionId)
    local spellIds = {}
    local profession = self.VanillaAccurateData[professionId]
    if profession then
        for itemId, recipe in pairs(profession) do
            if recipe.spellId then
                table.insert(spellIds, recipe.spellId)
            end
        end
    end
    return spellIds
end

-- Create backward compatibility for ProfessionLinks
function addon:CreateLegacyCompatibility()
    -- Initialize legacy structures
    if not CraftersBoard then
        CraftersBoard = {}
    end
    
    CraftersBoard.VanillaData = {}
    
    -- Create SPELL_TO_RECIPE lookup table for ProfessionLinks compatibility
    local legacyCompat = {}
    legacyCompat.SPELL_TO_RECIPE = {}
    
    -- Build spell to recipe mapping dynamically from recipe data files
    -- This uses the item IDs from our recipe data and gets real names via WoW API
    -- Important: GetItemInfo() might return nil if item not in cache yet
    local itemsToRetry = {}
    
    for professionId, professionData in pairs(self.VanillaAccurateData) do
        for itemId, recipe in pairs(professionData) do
            if recipe.spellId then
                local itemName = GetItemInfo(itemId)
                if itemName then
                    -- Use the actual item name from WoW API as recipe name
                    -- This gives us real recipe names like "Minor Healing Potion" instead of "CraftedItem_118"
                    legacyCompat.SPELL_TO_RECIPE[recipe.spellId] = itemName
                else
                    -- Schedule for retry instead of using fallback name immediately
                    table.insert(itemsToRetry, {itemId = itemId, spellId = recipe.spellId})
                end
            end
        end
    end
    
    -- If we have items to retry, set up a delayed loader
    if #itemsToRetry > 0 then
        -- Debug print only if enabled
        if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
            print("CraftersBoard: " .. #itemsToRetry .. " items need delayed loading, setting up retry system...")
        end
        
        local retryAttempts = 0
        local maxRetries = 10
        local retryDelay = 2 -- seconds
        
        local function RetryItemLoading()
            retryAttempts = retryAttempts + 1
            local stillMissing = {}
            local resolved = 0
            
            for _, item in ipairs(itemsToRetry) do
                local itemName = GetItemInfo(item.itemId)
                if itemName then
                    -- Successfully got item name
                    legacyCompat.SPELL_TO_RECIPE[item.spellId] = itemName
                    resolved = resolved + 1
                else
                    -- Still missing, try again later
                    table.insert(stillMissing, item)
                end
            end
            
            -- Debug print only if enabled
            if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                print("CraftersBoard: Retry attempt " .. retryAttempts .. " - resolved " .. resolved .. " items, " .. #stillMissing .. " still missing")
            end
            
            if #stillMissing > 0 and retryAttempts < maxRetries then
                -- Schedule another retry
                itemsToRetry = stillMissing
                C_Timer.After(retryDelay, RetryItemLoading)
            else
                -- Finished retrying - use fallback names for any remaining items
                for _, item in ipairs(stillMissing) do
                    local fallbackName = "CraftedItem_" .. item.itemId
                    legacyCompat.SPELL_TO_RECIPE[item.spellId] = fallbackName
                    -- Debug print only if enabled
                    if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                        print("CraftersBoard: Using fallback name '" .. fallbackName .. "' for item " .. item.itemId)
                    end
                end
                
                -- Debug print only if enabled
                if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
                    print("CraftersBoard: Item name loading complete - " .. (retryAttempts >= maxRetries and "max retries reached" or "all items resolved"))
                end
                
                -- Notify any open profession viewers to refresh their display
                if CraftersBoard and CraftersBoard.ProfessionLinks and CraftersBoard.ProfessionLinks.RefreshProfessionViewer then
                    CraftersBoard.ProfessionLinks.RefreshProfessionViewer()
                end
            end
        end
        
        -- Start the retry process
        C_Timer.After(retryDelay, RetryItemLoading)
    end
    
    -- Set global for legacy compatibility
    CraftersBoard_VanillaData = legacyCompat
    
    -- Add version info
    CraftersBoard.VanillaData.VERSION = "2.0.0-RecipeMaster"
    
    local spellCount = 0
    for _ in pairs(legacyCompat.SPELL_TO_RECIPE) do
        spellCount = spellCount + 1
    end
    
    -- Debug print only if enabled
    if CRAFTERSBOARD_DB and CRAFTERSBOARD_DB.debug then
        print("CraftersBoard: Legacy compatibility created with " .. spellCount .. " spell mappings")
    end
end

-- Initialize the data when the addon loads
function addon:InitializeVanillaData()
    self:LoadVanillaAccurateData()
    self:CreateLegacyCompatibility()
end

-- Auto-initialize when this file loads
addon:InitializeVanillaData()

-- Return the addon table for chaining
return addon
