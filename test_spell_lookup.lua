-- Test spell ID lookup functionality
-- This script verifies that our Recipe_Master integration correctly finds spell IDs

print("=== Testing Recipe_Master Spell ID Lookup ===")

-- Test the lookup function
local function testSpellIdLookup()
    -- Test function should be available in ProfessionLinks.lua
    if PL and PL.GetSpellIdFromRecipeMasterData then
        print("✓ Function PL.GetSpellIdFromRecipeMasterData is available")
        
        -- Test with known recipes
        local testRecipes = {
            "Minor Healing Potion",  -- Should be itemId 118, spellId 2330
            "Lesser Healing Potion", -- Should be itemId 858, spellId 2337
            "Healing Potion"         -- Should be itemId 929, spellId 3447
        }
        
        for _, recipeName in ipairs(testRecipes) do
            local spellId = PL.GetSpellIdFromRecipeMasterData(recipeName)
            if spellId then
                print("✓ " .. recipeName .. " → Spell ID: " .. spellId)
            else
                print("✗ " .. recipeName .. " → No spell ID found")
            end
        end
    else
        print("✗ Function PL.GetSpellIdFromRecipeMasterData is not available")
    end
end

-- Test data access
local function testDataAccess()
    if CraftersBoard and CraftersBoard.VanillaAccurateData then
        print("✓ CraftersBoard.VanillaAccurateData is available")
        
        local totalRecipes = 0
        for professionId, professionData in pairs(CraftersBoard.VanillaAccurateData) do
            local count = 0
            for itemId, recipe in pairs(professionData) do
                count = count + 1
            end
            totalRecipes = totalRecipes + count
            print("  Profession " .. professionId .. ": " .. count .. " recipes")
        end
        print("  Total recipes: " .. totalRecipes)
    else
        print("✗ CraftersBoard.VanillaAccurateData is not available")
    end
    
    if CraftersBoard_VanillaData and CraftersBoard_VanillaData.SPELL_TO_RECIPE then
        local count = 0
        for _ in pairs(CraftersBoard_VanillaData.SPELL_TO_RECIPE) do
            count = count + 1
        end
        print("✓ Legacy compatibility layer has " .. count .. " spell mappings")
    else
        print("✗ Legacy compatibility layer not available")
    end
end

-- Run tests
testDataAccess()
testSpellIdLookup()

print("=== Test Complete ===")
