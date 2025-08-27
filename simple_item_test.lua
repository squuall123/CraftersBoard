-- Simple test for item ID lookup without debug dependencies
print("=== CraftersBoard Simple Item ID Test ===")

-- Wait for addon to fully load then test
local function SimpleTest()
    if not CraftersBoard then
        print("CraftersBoard not loaded yet")
        return
    end
    
    if not CraftersBoard.VanillaAccurateData then
        print("VanillaAccurateData not loaded yet")
        return
    end
    
    if not CraftersBoard.ProfessionLinks then
        print("ProfessionLinks not loaded yet")
        return
    end
    
    print("All components loaded, testing item ID lookup...")
    
    -- Test a known alchemy recipe: item 118 should have spell ID 2330
    local testItemId = 118
    local expectedSpellId = 2330
    
    if CraftersBoard.ProfessionLinks.GetSpellIdFromItemId then
        local result = CraftersBoard.ProfessionLinks.GetSpellIdFromItemId(testItemId)
        if result == expectedSpellId then
            print("SUCCESS: Item ID " .. testItemId .. " correctly returned spell ID " .. result)
        elseif result then
            print("PARTIAL: Item ID " .. testItemId .. " returned spell ID " .. result .. " (expected " .. expectedSpellId .. ")")
        else
            print("FAILED: Item ID " .. testItemId .. " returned no spell ID")
        end
    else
        print("ERROR: GetSpellIdFromItemId function not available")
    end
    
    -- Check Recipe_Master data directly
    if CraftersBoard.VanillaAccurateData[171] and CraftersBoard.VanillaAccurateData[171][testItemId] then
        local recipe = CraftersBoard.VanillaAccurateData[171][testItemId]
        print("Recipe_Master data for item " .. testItemId .. ": spellId=" .. tostring(recipe.spellId) .. ", skill=" .. tostring(recipe.skill))
    else
        print("ERROR: Could not find Recipe_Master data for item " .. testItemId)
    end
    
    print("Test completed.")
end

-- Schedule the test after a delay to ensure everything is loaded
C_Timer.After(2, SimpleTest)

print("=== Test scheduled for 2 seconds ===")
