-- Debug script to test data loading
print("=== Testing Recipe Database Loading ===")

-- Test 1: Check if recipe files loaded data into addon table
local addonName, addon = ...
if addon and addon.VanillaAccurateData then
    print("✓ Recipe data loaded into addon table")
    
    local totalRecipes = 0
    for professionId, professionData in pairs(addon.VanillaAccurateData) do
        local count = 0
        for itemId, recipe in pairs(professionData) do
            count = count + 1
            if count <= 3 then
                print("  Sample: itemId " .. itemId .. " → spellId " .. (recipe.spellId or "nil"))
            end
        end
        totalRecipes = totalRecipes + count
        print("  Profession " .. professionId .. ": " .. count .. " recipes")
    end
    print("  Total: " .. totalRecipes .. " recipes")
else
    print("✗ Recipe data NOT loaded into addon table")
end

-- Test 2: Check if data was copied to global CraftersBoard
if CraftersBoard and CraftersBoard.VanillaAccurateData then
    print("✓ Recipe data copied to CraftersBoard global")
    
    local globalTotal = 0
    for professionId, professionData in pairs(CraftersBoard.VanillaAccurateData) do
        local count = 0
        for _ in pairs(professionData) do
            count = count + 1
        end
        globalTotal = globalTotal + count
    end
    print("  Global total: " .. globalTotal .. " recipes")
else
    print("✗ Recipe data NOT in CraftersBoard global")
end

-- Test 3: Check specific recipe lookup
if CraftersBoard and CraftersBoard.VanillaAccurateData then
    -- Look for Minor Healing Potion (itemId 118, spellId 2330)
    local found = false
    for professionId, professionData in pairs(CraftersBoard.VanillaAccurateData) do
        if professionData[118] then
            local recipe = professionData[118]
            print("✓ Found Minor Healing Potion: itemId 118 → spellId " .. (recipe.spellId or "nil"))
            found = true
            break
        end
    end
    if not found then
        print("✗ Could not find Minor Healing Potion (itemId 118)")
    end
end

-- Test 4: Check legacy compatibility
if CraftersBoard_VanillaData and CraftersBoard_VanillaData.SPELL_TO_RECIPE then
    local count = 0
    for spellId, recipeName in pairs(CraftersBoard_VanillaData.SPELL_TO_RECIPE) do
        count = count + 1
        if count <= 3 then
            print("  Legacy sample: spellId " .. spellId .. " → " .. recipeName)
        end
    end
    print("✓ Legacy compatibility has " .. count .. " mappings")
else
    print("✗ Legacy compatibility NOT created")
end

print("=== Test Complete ===")
