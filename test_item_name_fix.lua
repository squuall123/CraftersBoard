-- Test script to validate the CraftedItem_ID fix
print("=== CraftersBoard CraftedItem_ID Fix Test ===")

local function TestItemNameFix()
    if not CraftersBoard_VanillaData or not CraftersBoard_VanillaData.SPELL_TO_RECIPE then
        print("❌ Legacy data not available, waiting...")
        C_Timer.After(3, TestItemNameFix)
        return
    end
    
    print("🔍 Testing item name resolution...")
    
    local totalRecipes = 0
    local craftedItemNames = 0
    local realItemNames = 0
    local sampleCraftedItems = {}
    local sampleRealItems = {}
    
    -- Analyze the current state of recipe names
    for spellId, recipeName in pairs(CraftersBoard_VanillaData.SPELL_TO_RECIPE) do
        totalRecipes = totalRecipes + 1
        
        if recipeName:match("^CraftedItem_") then
            craftedItemNames = craftedItemNames + 1
            if #sampleCraftedItems < 5 then
                table.insert(sampleCraftedItems, {spellId = spellId, name = recipeName})
            end
        else
            realItemNames = realItemNames + 1
            if #sampleRealItems < 5 then
                table.insert(sampleRealItems, {spellId = spellId, name = recipeName})
            end
        end
    end
    
    local craftedPercentage = totalRecipes > 0 and math.floor(craftedItemNames / totalRecipes * 100) or 0
    local realPercentage = 100 - craftedPercentage
    
    print("📊 ITEM NAME ANALYSIS:")
    print("  Total recipes: " .. totalRecipes)
    print("  Real item names: " .. realItemNames .. " (" .. realPercentage .. "%)")
    print("  CraftedItem_X names: " .. craftedItemNames .. " (" .. craftedPercentage .. "%)")
    
    if #sampleRealItems > 0 then
        print("\n✅ REAL ITEM NAME SAMPLES:")
        for _, sample in ipairs(sampleRealItems) do
            print("    Spell " .. sample.spellId .. " → '" .. sample.name .. "'")
        end
    end
    
    if #sampleCraftedItems > 0 then
        print("\n⚠️  CRAFTEDITEM SAMPLES (these should decrease over time):")
        for _, sample in ipairs(sampleCraftedItems) do
            local itemId = sample.name:match("CraftedItem_(%d+)")
            if itemId then
                local realName = GetItemInfo(tonumber(itemId))
                print("    Spell " .. sample.spellId .. " → '" .. sample.name .. "'" .. 
                      (realName and (" (should be: '" .. realName .. "')") or " (item not cached)"))
            end
        end
    end
    
    -- Test the delayed loading system
    if craftedItemNames > 0 then
        print("\n💡 RECOMMENDATIONS:")
        print("  • " .. craftedItemNames .. " recipes still have CraftedItem_X names")
        print("  • Wait a few minutes for the retry system to resolve item names")
        print("  • Check profession viewer - it should refresh automatically")
        print("  • Run this test again in 30 seconds to see improvement")
    else
        print("\n🎉 SUCCESS: All recipes have real item names!")
    end
    
    -- Test a specific item that commonly fails
    print("\n🧪 SPECIFIC ITEM TEST:")
    local testItemId = 118 -- Minor Healing Potion
    local testSpellId = 2330
    
    local recipeName = CraftersBoard_VanillaData.SPELL_TO_RECIPE[testSpellId]
    local itemName = GetItemInfo(testItemId)
    
    print("  Test item " .. testItemId .. " (Minor Healing Potion):")
    print("    Recipe name in database: " .. tostring(recipeName))
    print("    Real item name from API: " .. tostring(itemName))
    
    if recipeName == itemName then
        print("    ✅ Perfect match!")
    elseif recipeName and recipeName:match("^CraftedItem_") then
        print("    ⏳ Still using fallback name - retry system should fix this")
    else
        print("    ❌ Mismatch detected")
    end
    
    print("\n=== Test Complete ===")
end

-- Start the test
TestItemNameFix()
