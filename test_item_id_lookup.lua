-- Test the new item ID-based lookup functionality
-- This file tests the Recipe_Master item ID lookup vs name matching

print("=== CraftersBoard Item ID Lookup Test ===")

-- Test function to check if our new item ID lookup is working
local function TestItemIdLookup()
    print("Testing item ID lookup functionality...")
    
    -- Wait for addon to load
    local function CheckAndTest()
        if not CraftersBoard or not CraftersBoard.VanillaAccurateData then
            print("CraftersBoard data not loaded yet, waiting...")
            return false
        end
        
        print("CraftersBoard data available, testing lookup...")
        
        -- Sample test with known alchemy recipes
        local testItems = {
            -- Common alchemy items from Recipe_Master data
            {itemId = 2454, expectedName = "Elixir of Lion's Strength", profession = "Alchemy"},
            {itemId = 2457, expectedName = "Elixir of Minor Agility", profession = "Alchemy"},
            {itemId = 5631, expectedName = "Rage Potion", profession = "Alchemy"},
        }
        
        for _, test in ipairs(testItems) do
            print("Testing item " .. test.itemId .. " (" .. test.expectedName .. "):")
            
            -- Test our new function
            if CraftersBoard.ProfessionLinks and CraftersBoard.ProfessionLinks.GetSpellIdFromItemId then
                local spellId = CraftersBoard.ProfessionLinks.GetSpellIdFromItemId(test.itemId)
                if spellId then
                    print("  ✓ Found spell ID " .. spellId .. " via item ID lookup")
                else
                    print("  ✗ No spell ID found via item ID lookup")
                end
            else
                print("  ! GetSpellIdFromItemId function not available")
            end
            
            -- Compare with name-based lookup
            local itemName = GetItemInfo(test.itemId)
            if itemName then
                print("  Item name from WoW API: '" .. itemName .. "'")
                if CraftersBoard.ProfessionLinks and CraftersBoard.ProfessionLinks.GetSpellIdFromRecipeMasterData then
                    local spellId2 = CraftersBoard.ProfessionLinks.GetSpellIdFromRecipeMasterData(itemName)
                    if spellId2 then
                        print("  ✓ Found spell ID " .. spellId2 .. " via name matching")
                    else
                        print("  ✗ No spell ID found via name matching")
                    end
                else
                    print("  ! GetSpellIdFromRecipeMasterData function not available")
                end
            else
                print("  ! Could not get item name from WoW API for item " .. test.itemId)
            end
        end
        
        -- Test Recipe_Master data structure
        print("\nTesting Recipe_Master data structure:")
        if CraftersBoard.VanillaAccurateData then
            local totalRecipes = 0
            local professionsFound = {}
            
            for professionId, professionData in pairs(CraftersBoard.VanillaAccurateData) do
                local count = 0
                for itemId, recipe in pairs(professionData) do
                    count = count + 1
                end
                professionsFound[professionId] = count
                totalRecipes = totalRecipes + count
                print("  Profession " .. professionId .. ": " .. count .. " recipes")
            end
            
            print("  Total recipes loaded: " .. totalRecipes)
        else
            print("  ! No Recipe_Master data available")
        end
        
        return true
    end
    
    -- Try immediately, then retry if needed
    if not CheckAndTest() then
        -- Schedule retry after addon loads
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        frame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "CraftersBoard" then
                print("CraftersBoard addon loaded, running test...")
                C_Timer.After(1, CheckAndTest) -- Wait 1 second for full initialization
                frame:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

-- Run the test
TestItemIdLookup()

print("=== End Item ID Lookup Test ===")
