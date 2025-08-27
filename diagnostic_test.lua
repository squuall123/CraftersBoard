-- Add this to test the complete data flow in-game
-- Use /cb diagnose to run this test

SLASH_CBDIAGNOSE1 = "/cbdiagnose"
SlashCmdList["CBDIAGNOSE"] = function(msg)
    print("|cffffff00CraftersBoard|r === Complete Diagnostic Test ===")
    
    -- Test 1: Check if recipe data is loaded
    local _, addon = ...
    if addon and addon.VanillaAccurateData then
        local count = 0
        for profId, profData in pairs(addon.VanillaAccurateData) do
            for itemId, recipe in pairs(profData) do
                count = count + 1
                if count == 1 then
                    print("Sample recipe: itemId " .. itemId .. " → spellId " .. (recipe.spellId or "nil"))
                end
            end
        end
        print("✓ Addon table has " .. count .. " recipes")
    else
        print("✗ Addon table has no recipe data")
    end
    
    -- Test 2: Check global CraftersBoard data
    if CraftersBoard and CraftersBoard.VanillaAccurateData then
        local count = 0
        for profId, profData in pairs(CraftersBoard.VanillaAccurateData) do
            for itemId, recipe in pairs(profData) do
                count = count + 1
            end
        end
        print("✓ CraftersBoard global has " .. count .. " recipes")
    else
        print("✗ CraftersBoard global has no recipe data")
    end
    
    -- Test 3: Test spell ID lookup
    if PL and PL.GetSpellIdFromRecipeMasterData then
        local testRecipes = {"Minor Healing Potion", "Lesser Healing Potion"}
        for _, recipeName in ipairs(testRecipes) do
            local spellId = PL.GetSpellIdFromRecipeMasterData(recipeName)
            if spellId then
                print("✓ Lookup: " .. recipeName .. " → spellId " .. spellId)
            else
                print("✗ Lookup failed: " .. recipeName)
            end
        end
    else
        print("✗ Lookup function not available")
    end
    
    -- Test 4: Check current profession scanning
    local currentProf = nil
    if GetTradeSkillLine then
        currentProf = GetTradeSkillLine()
    end
    
    if currentProf then
        print("Current profession: " .. currentProf)
        local snapshot = professionSnapshots[currentProf]
        if snapshot then
            local spellIdCount = 0
            for _, recipe in ipairs(snapshot.recipes) do
                if recipe.spellID then
                    spellIdCount = spellIdCount + 1
                end
            end
            print("✓ Snapshot has " .. #snapshot.recipes .. " recipes, " .. spellIdCount .. " with spell IDs")
        else
            print("✗ No snapshot for " .. currentProf)
        end
    else
        print("No profession window open")
    end
    
    print("=== Diagnostic Complete ===")
end

print("Diagnostic command registered: /cbdiagnose")
