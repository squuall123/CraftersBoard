-- CraftersBoard - Data Dictionary

local CB = CraftersBoard

if not CB then
    error("CraftersBoard namespace not found! Make sure Init.lua loads first.")
    return
end

CB.DataDictionary = CB.DataDictionary or {}
local DD = CB.DataDictionary

local VanillaData = CraftersBoard_VanillaData
if not VanillaData then
    CB.Debug("Warning: Vanilla data not loaded! Dictionary compression will be limited.")
    VanillaData = {
        SPELL_TO_RECIPE = {},
        RECIPES_BY_PROFESSION = {},
        PROFESSION_IDS = {},
        CATEGORY_NAMES = {[99] = "Other"},
        TYPE_NAMES = {[1] = "craft"}
    }
end

DD.SPELL_TO_RECIPE = VanillaData.SPELL_TO_RECIPE or {}
DD.RECIPES_BY_PROFESSION = VanillaData.RECIPES_BY_PROFESSION or {}
DD.PROFESSION_IDS = VanillaData.PROFESSION_IDS or {}
DD.CATEGORY_NAMES = VanillaData.CATEGORY_NAMES or {[99] = "Other"}
DD.TYPE_NAMES = VanillaData.TYPE_NAMES or {[1] = "craft"}

-- Legacy mappings for backward compatibility
DD.CATEGORY_TO_ID = {}
DD.TYPE_TO_ID = {
    ["craft"] = 1,
    ["trade"] = 2,
    ["optimal"] = 3,
    ["easy"] = 4,
    ["medium"] = 5,
    ["difficult"] = 6
}

-- Reverse lookup for encoding
DD.RECIPE_TO_SPELL = {}
for spellId, recipeName in pairs(DD.SPELL_TO_RECIPE) do
    DD.RECIPE_TO_SPELL[recipeName] = spellId
end

-- Create reverse category/type mappings for backward compatibility
DD.ID_TO_CATEGORY = {}
for id, categoryName in pairs(DD.CATEGORY_NAMES) do
    DD.ID_TO_CATEGORY[id] = categoryName
    DD.CATEGORY_TO_ID[categoryName] = id
end

DD.ID_TO_TYPE = {}
for id, typeName in pairs(DD.TYPE_NAMES) do
    DD.ID_TO_TYPE[id] = typeName
end

-- Profession name lookup
DD.GetProfessionName = function(professionId)
    if DD.RECIPES_BY_PROFESSION[professionId] then
        return DD.RECIPES_BY_PROFESSION[professionId].name
    end
    return "Unknown"
end

-- Get profession ID by name
DD.GetProfessionId = function(professionName)
    for id, name in pairs(DD.PROFESSION_IDS) do
        if string.upper(name) == string.upper(professionName) then
            return id
        end
    end
    return nil
end

-- Filter recipes by profession ID for efficient lookups
DD.GetRecipesByProfession = function(professionId)
    if DD.RECIPES_BY_PROFESSION[professionId] then
        return DD.RECIPES_BY_PROFESSION[professionId].recipes
    end
    return {}
end

-- Check if a spell ID belongs to a specific profession
DD.IsRecipeInProfession = function(spellId, professionId)
    local professionRecipes = DD.GetRecipesByProfession(professionId)
    return professionRecipes[spellId] ~= nil
end

-- Get all profession IDs that have recipes
DD.GetAvailableProfessions = function()
    local professions = {}
    for professionId, professionData in pairs(DD.RECIPES_BY_PROFESSION) do
        table.insert(professions, {
            id = professionId,
            name = professionData.name,
            recipeCount = 0
        })
        -- Count recipes
        for _ in pairs(professionData.recipes) do
            professions[#professions].recipeCount = professions[#professions].recipeCount + 1
        end
    end
    return professions
end

-- Type mappings
DD.TYPE_TO_ID = {
    ["craft"] = 1,
    ["trade"] = 2,
    ["optimal"] = 3,
    ["easy"] = 4,
    ["medium"] = 5,
    ["difficult"] = 6
}

DD.ID_TO_TYPE = {}
for type, id in pairs(DD.TYPE_TO_ID) do
    DD.ID_TO_TYPE[id] = type
end

-- Compress profession data using spell IDs and numeric mappings
function DD.CompressProfessionData(snapshot)
    if not snapshot or not snapshot.recipes then return nil end
    
    CB.Debug("Compressing profession data using dictionary approach")
    
    local compressed = {
        n = snapshot.name,           -- Keep name as-is (short anyway)
        r = snapshot.rank,           -- Keep rank as-is  
        mr = snapshot.maxRank,       -- Keep maxRank as-is
        t = snapshot.timestamp,      -- Keep timestamp as-is
        rc = {}                      -- Compressed recipes
    }
    
    local compressedCount = 0
    local uncompressedCount = 0
    
    for i, recipe in ipairs(snapshot.recipes) do
        local spellId = DD.RECIPE_TO_SPELL[recipe.name]
        
        if spellId then
            -- Use spell ID instead of recipe name (major space saving)
            local compactRecipe = {
                id = spellId,  -- Spell ID instead of name
                t = DD.TYPE_TO_ID[recipe.type] or 1,     -- Type as number
                c = DD.CATEGORY_TO_ID[recipe.category] or 99  -- Category as number
            }
            
            -- Compress reagents if present
            if recipe.reagents and #recipe.reagents > 0 then
                compactRecipe.rg = {}
                for j, reagent in ipairs(recipe.reagents) do
                    -- Try to use item ID if available, otherwise use name
                    local reagentData = {
                        n = reagent.name,        -- Keep name for now (could be optimized later)
                        r = reagent.required,
                        a = reagent.available
                    }
                    table.insert(compactRecipe.rg, reagentData)
                end
            end
            
            table.insert(compressed.rc, compactRecipe)
            compressedCount = compressedCount + 1
        else
            -- Recipe not in dictionary, store as-is (fallback for unknown recipes)
            local fallbackRecipe = {
                n = recipe.name,  -- Use name since no spell ID available
                t = DD.TYPE_TO_ID[recipe.type] or 1,
                c = DD.CATEGORY_TO_ID[recipe.category] or 99
            }
            
            if recipe.reagents and #recipe.reagents > 0 then
                fallbackRecipe.rg = {}
                for j, reagent in ipairs(recipe.reagents) do
                    table.insert(fallbackRecipe.rg, {
                        n = reagent.name,
                        r = reagent.required,
                        a = reagent.available
                    })
                end
            end
            
            table.insert(compressed.rc, fallbackRecipe)
            uncompressedCount = uncompressedCount + 1
        end
    end
    
    CB.Debug("Dictionary compression: " .. compressedCount .. " recipes compressed, " .. uncompressedCount .. " fallback")
    return compressed
end

-- Decompress profession data using spell IDs and mappings
function DD.DecompressProfessionData(compressed)
    if not compressed or not compressed.rc then return nil end
    
    CB.Debug("Decompressing profession data using dictionary approach")
    
    local snapshot = {
        name = compressed.n,
        rank = compressed.r,
        maxRank = compressed.mr,
        timestamp = compressed.t,
        recipes = {},
        categories = {}
    }
    
    for i, compactRecipe in ipairs(compressed.rc) do
        local recipe = {}
        
        -- Decompress recipe name from spell ID or use fallback
        if compactRecipe.id then
            recipe.name = DD.SPELL_TO_RECIPE[compactRecipe.id]
            if not recipe.name then
                CB.Debug("Warning: Unknown spell ID " .. compactRecipe.id .. ", skipping recipe")
                -- Skip this recipe instead of using goto
            else
                -- Process the recipe normally
                -- Decompress type and category
                recipe.type = DD.ID_TO_TYPE[compactRecipe.t] or "craft"
                recipe.category = DD.ID_TO_CATEGORY[compactRecipe.c] or "Other"
                
                -- Decompress reagents
                recipe.reagents = {}
                if compactRecipe.rg then
                    for j, reagent in ipairs(compactRecipe.rg) do
                        table.insert(recipe.reagents, {
                            name = reagent.n,
                            required = reagent.r,
                            available = reagent.a
                        })
                    end
                end
                
                table.insert(snapshot.recipes, recipe)
                
                -- Rebuild categories
                if not snapshot.categories[recipe.category] then
                    snapshot.categories[recipe.category] = {}
                end
                table.insert(snapshot.categories[recipe.category], recipe)
            end
        else
            recipe.name = compactRecipe.n  -- Fallback for unknown recipes
            -- Decompress type and category
            recipe.type = DD.ID_TO_TYPE[compactRecipe.t] or "craft"
            recipe.category = DD.ID_TO_CATEGORY[compactRecipe.c] or "Other"
            
            -- Decompress reagents
            recipe.reagents = {}
            if compactRecipe.rg then
                for j, reagent in ipairs(compactRecipe.rg) do
                    table.insert(recipe.reagents, {
                        name = reagent.n,
                        required = reagent.r,
                        available = reagent.a
                    })
                end
            end
            
            table.insert(snapshot.recipes, recipe)
            
            -- Rebuild categories
            if not snapshot.categories[recipe.category] then
                snapshot.categories[recipe.category] = {}
            end
            table.insert(snapshot.categories[recipe.category], recipe)
        end
    end
    
    CB.Debug("Decompressed " .. #snapshot.recipes .. " recipes from dictionary data")
    return snapshot
end

-- Calculate compression efficiency 
function DD.CalculateCompressionRatio(original, compressed)
    if not original or not compressed then return 0 end
    
    -- Use simple string length calculation instead of undefined PL functions
    local function tableSize(t)
        if not t then return 0 end
        local count = 0
        for k,v in pairs(t) do
            count = count + 1
            if type(v) == "table" then
                count = count + tableSize(v)
            end
        end
        return count
    end
    
    local originalSize = tableSize(original)
    local compressedSize = tableSize(compressed)
    
    if originalSize == 0 then return 0 end
    
    local ratio = (originalSize - compressedSize) / originalSize * 100
    CB.Debug("Compression ratio: " .. string.format("%.1f", ratio) .. "% (from " .. originalSize .. " to " .. compressedSize .. " elements)")
    
    return ratio
end

-- Export functions to ProfessionLinks module
if CB.ProfessionLinks then
    CB.ProfessionLinks.CompressProfessionData = DD.CompressProfessionData
    CB.ProfessionLinks.DecompressProfessionData = DD.DecompressProfessionData
    CB.ProfessionLinks.CalculateCompressionRatio = DD.CalculateCompressionRatio
    -- Export new profession filtering functions
    CB.ProfessionLinks.GetRecipesByProfession = DD.GetRecipesByProfession
    CB.ProfessionLinks.IsRecipeInProfession = DD.IsRecipeInProfession
    CB.ProfessionLinks.GetProfessionName = DD.GetProfessionName
    CB.ProfessionLinks.GetProfessionId = DD.GetProfessionId
    CB.ProfessionLinks.GetAvailableProfessions = DD.GetAvailableProfessions
end

-- Add profession filtering and statistics functions
function DD.GetProfessionStatistics()
    local stats = {
        totalRecipes = 0,
        professions = {},
        dataSource = VanillaData and "External" or "Fallback"
    }
    
    for professionId, professionData in pairs(DD.RECIPES_BY_PROFESSION) do
        local recipeCount = 0
        for _ in pairs(professionData.recipes) do
            recipeCount = recipeCount + 1
        end
        
        stats.professions[professionId] = {
            name = professionData.name,
            recipeCount = recipeCount
        }
        stats.totalRecipes = stats.totalRecipes + recipeCount
    end
    
    return stats
end

-- Filter snapshot recipes by profession for efficient processing
function DD.FilterSnapshotByProfession(snapshot, professionId)
    if not snapshot or not snapshot.recipes then return nil end
    
    local filtered = {
        name = snapshot.name,
        rank = snapshot.rank,
        maxRank = snapshot.maxRank,
        timestamp = snapshot.timestamp,
        recipes = {},
        categories = {}
    }
    
    local professionRecipes = DD.GetRecipesByProfession(professionId)
    if not professionRecipes then
        CB.Debug("No recipes found for profession ID: " .. tostring(professionId))
        return filtered
    end
    
    -- Filter recipes that belong to the specified profession
    for i, recipe in ipairs(snapshot.recipes) do
        local spellId = DD.RECIPE_TO_SPELL[recipe.name]
        if spellId and professionRecipes[spellId] then
            table.insert(filtered.recipes, recipe)
            
            -- Rebuild categories for filtered data
            if not filtered.categories[recipe.category] then
                filtered.categories[recipe.category] = {}
            end
            table.insert(filtered.categories[recipe.category], recipe)
        end
    end
    
    CB.Debug("Filtered " .. #filtered.recipes .. " recipes for profession: " .. DD.GetProfessionName(professionId))
    return filtered
end

-- Get count of dictionary entries
local function getTableCount(t)
    local count = 0
    if t then
        for _ in pairs(t) do count = count + 1 end
    end
    return count
end

CB.Debug("DataDictionary module loaded with " .. getTableCount(DD.SPELL_TO_RECIPE) .. " spell mappings")
