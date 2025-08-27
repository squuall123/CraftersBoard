-- VanillaAccurateLoader.lua
-- Recipe database loader for CraftersBoard
-- Uses Recipe_Master complete dataset

local _, addon = ...

-- Ensure main data structure exists
if not addon.VanillaAccurateData then
    addon.VanillaAccurateData = {}
end

-- Profession mapping
addon.ProfessionIds = {
    ALCHEMY = 171,
    BLACKSMITHING = 164,
    COOKING = 185,
    ENCHANTING = 333,
    ENGINEERING = 202,
    FIRST_AID = 129,
    LEATHERWORKING = 165,
    TAILORING = 197
}

-- Profession names
addon.ProfessionNames = {
    [171] = "Alchemy",
    [164] = "Blacksmithing", 
    [185] = "Cooking",
    [333] = "Enchanting",
    [202] = "Engineering",
    [129] = "First Aid",
    [165] = "Leatherworking",
    [197] = "Tailoring"
}

-- Get all recipes for a profession
function addon:GetRecipesForProfession(professionId)
    return self.VanillaAccurateData[professionId] or {}
end

-- Get a specific recipe
function addon:GetRecipe(professionId, itemId)
    local profession = self.VanillaAccurateData[professionId]
    if profession then
        return profession[itemId]
    end
    return nil
end

-- Get all profession IDs
function addon:GetAllProfessionIds()
    local ids = {}
    for id, _ in pairs(self.VanillaAccurateData) do
        table.insert(ids, id)
    end
    return ids
end

-- Count total recipes
function addon:GetTotalRecipeCount()
    local total = 0
    for professionId, recipes in pairs(self.VanillaAccurateData) do
        for _, _ in pairs(recipes) do
            total = total + 1
        end
    end
    return total
end

-- Get recipe count for a profession
function addon:GetProfessionRecipeCount(professionId)
    local count = 0
    local profession = self.VanillaAccurateData[professionId]
    if profession then
        for _, _ in pairs(profession) do
            count = count + 1
        end
    end
    return count
end

-- Search recipes by spell ID
function addon:SearchRecipeBySpellId(spellId)
    for professionId, recipes in pairs(self.VanillaAccurateData) do
        for itemId, recipe in pairs(recipes) do
            if recipe.spellId == spellId then
                return {
                    professionId = professionId,
                    professionName = self.ProfessionNames[professionId],
                    itemId = itemId,
                    recipe = recipe
                }
            end
        end
    end
    return nil
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
    
    for professionId, recipes in pairs(self.VanillaAccurateData) do
        for itemId, recipe in pairs(recipes) do
            if recipe.spellId then
                -- Create simple recipe name using item ID
                local recipeName = "Recipe_" .. itemId
                legacyCompat.SPELL_TO_RECIPE[recipe.spellId] = recipeName
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

-- Print profession statistics
function addon:PrintProfessionStats()
    print("=== CraftersBoard Recipe Database Statistics ===")
    local totalRecipes = 0
    
    for professionId, recipes in pairs(self.VanillaAccurateData) do
        local count = 0
        for _, _ in pairs(recipes) do
            count = count + 1
        end
        totalRecipes = totalRecipes + count
        print(string.format("%s (%d): %d recipes", 
            self.ProfessionNames[professionId] or "Unknown", 
            professionId, 
            count))
    end
    
    print(string.format("Total Recipes: %d", totalRecipes))
    print("=== End Statistics ===")
end

-- Initialize on addon load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "CraftersBoard" then
        local totalRecipes = addon:GetTotalRecipeCount()
        print("CraftersBoard: Recipe database loaded with " .. totalRecipes .. " recipes")
        
        -- Create legacy compatibility layer
        addon:CreateLegacyCompatibility()
        
        -- Print profession statistics
        addon:PrintProfessionStats()
    end
end)
