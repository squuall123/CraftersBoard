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
        print("CraftersBoard: Loaded " .. count .. " recipes for profession " .. professionId)
    end
    
    print("CraftersBoard: Total recipes loaded: " .. totalRecipes)
    
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
    for professionId, professionData in pairs(self.VanillaAccurateData) do
        for itemId, recipe in pairs(professionData) do
            if recipe.spellId then
                local itemName = GetItemInfo(itemId)
                if itemName then
                    -- Use the actual item name from WoW API as recipe name
                    -- This gives us real recipe names like "Minor Healing Potion" instead of "CraftedItem_118"
                    legacyCompat.SPELL_TO_RECIPE[recipe.spellId] = itemName
                else
                    -- Fallback to synthetic name if API not available (items not in cache yet)
                    legacyCompat.SPELL_TO_RECIPE[recipe.spellId] = "CraftedItem_" .. itemId
                end
            end
        end
    end
    
    -- Set global for legacy compatibility
    CraftersBoard_VanillaData = legacyCompat
    
    -- Add version info
    CraftersBoard.VanillaData.VERSION = "2.0.0-RecipeMaster"
    
    local spellCount = 0
    for _ in pairs(legacyCompat.SPELL_TO_RECIPE) do
        spellCount = spellCount + 1
    end
    
    print("CraftersBoard: Legacy compatibility created with " .. spellCount .. " spell mappings")
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
