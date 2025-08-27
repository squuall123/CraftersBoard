-- Detailed diagnostic to identify exactly which recipes are failing and why
print("=== CraftersBoard Missing Recipe Diagnostic ===")

local function MissingRecipeDiagnostic()
    if not CraftersBoard or not CraftersBoard.VanillaAccurateData or not CraftersBoard.ProfessionLinks then
        print("⏳ Waiting for CraftersBoard to fully load...")
        C_Timer.After(2, MissingRecipeDiagnostic)
        return
    end
    
    print("🔍 Starting detailed analysis of missing recipes...")
    
    -- Simulate profession scanning to identify failures
    local testResults = {
        successful = {},
        failed = {},
        byMethod = {
            method1 = 0, -- Direct spell link
            method2 = 0, -- Item ID lookup
            method25 = 0, -- Spell key lookup
            method3 = 0, -- Name matching
            failed = 0
        }
    }
    
    -- Sample some recipes from different professions to test
    local testProfessions = {
        [171] = "Alchemy",
        [333] = "Enchanting", 
        [164] = "Blacksmithing",
        [202] = "Engineering",
        [197] = "Tailoring"
    }
    
    for professionId, professionName in pairs(testProfessions) do
        if CraftersBoard.VanillaAccurateData[professionId] then
            print("\n📋 Testing " .. professionName .. " (ID: " .. professionId .. "):")
            
            local tested = 0
            local maxTests = 10 -- Test first 10 recipes per profession
            
            for keyId, recipe in pairs(CraftersBoard.VanillaAccurateData[professionId]) do
                if tested >= maxTests then break end
                tested = tested + 1
                
                print("  Recipe " .. keyId .. ":")
                local spellId = nil
                local method = "unknown"
                
                -- Simulate the lookup methods
                
                -- Method 1: Direct spell ID (would need actual recipe link)
                -- Skip for now as we don't have actual GetTradeSkillRecipeLink data
                
                -- Method 2: Item ID lookup
                if not spellId then
                    spellId = CraftersBoard.ProfessionLinks.GetSpellIdFromItemId(keyId)
                    if spellId then
                        method = "item_id_lookup"
                        testResults.byMethod.method2 = testResults.byMethod.method2 + 1
                    end
                end
                
                -- Method 2.5: Spell key lookup
                if not spellId then
                    spellId = CraftersBoard.ProfessionLinks.GetSpellIdBySpellKey(keyId)
                    if spellId then
                        method = "spell_key_lookup"
                        testResults.byMethod.method25 = testResults.byMethod.method25 + 1
                    end
                end
                
                -- Method 3: Name matching
                if not spellId then
                    -- Try to get item name if recipe has itemId
                    local recipeName = nil
                    if recipe.itemId then
                        recipeName = GetItemInfo(recipe.itemId)
                    elseif type(keyId) == "number" then
                        -- Try spell name
                        recipeName = GetSpellInfo and GetSpellInfo(keyId)
                    end
                    
                    if recipeName then
                        spellId = CraftersBoard.ProfessionLinks.GetSpellIdFromRecipeMasterData(recipeName)
                        if spellId then
                            method = "name_matching"
                            testResults.byMethod.method3 = testResults.byMethod.method3 + 1
                        end
                    end
                end
                
                -- Record results
                if spellId then
                    table.insert(testResults.successful, {
                        professionId = professionId,
                        professionName = professionName,
                        keyId = keyId,
                        spellId = spellId,
                        method = method,
                        recipe = recipe
                    })
                    print("    ✅ SUCCESS via " .. method .. " → spellId " .. spellId)
                else
                    table.insert(testResults.failed, {
                        professionId = professionId,
                        professionName = professionName,
                        keyId = keyId,
                        recipe = recipe
                    })
                    testResults.byMethod.failed = testResults.byMethod.failed + 1
                    print("    ❌ FAILED - no spell ID found")
                    
                    -- Detailed analysis of why it failed
                    print("      Recipe details:")
                    print("        itemId: " .. tostring(recipe.itemId))
                    print("        spellId: " .. tostring(recipe.spellId))
                    print("        skill: " .. tostring(recipe.skill))
                    
                    if recipe.itemId then
                        local itemName = GetItemInfo(recipe.itemId)
                        print("        Item name: " .. tostring(itemName))
                    end
                    
                    if type(keyId) == "number" then
                        local spellName = GetSpellInfo and GetSpellInfo(keyId)
                        print("        Spell name (keyId): " .. tostring(spellName))
                    end
                end
            end
        else
            print("❌ No data found for " .. professionName)
        end
    end
    
    -- Summary statistics
    local totalTested = #testResults.successful + #testResults.failed
    local successRate = totalTested > 0 and math.floor(#testResults.successful / totalTested * 100) or 0
    
    print("\n📊 DIAGNOSTIC SUMMARY:")
    print("  Total recipes tested: " .. totalTested)
    print("  Successful: " .. #testResults.successful .. " (" .. successRate .. "%)")
    print("  Failed: " .. #testResults.failed .. " (" .. (100 - successRate) .. "%)")
    print("\n  Success by method:")
    print("    Item ID lookup: " .. testResults.byMethod.method2)
    print("    Spell key lookup: " .. testResults.byMethod.method25)
    print("    Name matching: " .. testResults.byMethod.method3)
    print("    Failed: " .. testResults.byMethod.failed)
    
    -- Analyze failure patterns
    if #testResults.failed > 0 then
        print("\n🔍 FAILURE PATTERN ANALYSIS:")
        
        local failurePatterns = {
            noItemIdNoSpellId = 0,
            hasItemIdNoSpellId = 0,
            hasSpellIdNoItemId = 0,
            hasBothButFailed = 0,
            itemNameMissing = 0,
            spellNameMissing = 0
        }
        
        for _, failure in ipairs(testResults.failed) do
            local recipe = failure.recipe
            local hasItemId = recipe.itemId ~= nil
            local hasSpellId = recipe.spellId ~= nil
            
            if not hasItemId and not hasSpellId then
                failurePatterns.noItemIdNoSpellId = failurePatterns.noItemIdNoSpellId + 1
            elseif hasItemId and not hasSpellId then
                failurePatterns.hasItemIdNoSpellId = failurePatterns.hasItemIdNoSpellId + 1
                
                -- Check if item name is available
                local itemName = GetItemInfo(recipe.itemId)
                if not itemName then
                    failurePatterns.itemNameMissing = failurePatterns.itemNameMissing + 1
                end
            elseif not hasItemId and hasSpellId then
                failurePatterns.hasSpellIdNoItemId = failurePatterns.hasSpellIdNoItemId + 1
            else
                failurePatterns.hasBothButFailed = failurePatterns.hasBothButFailed + 1
            end
            
            -- Check spell name availability
            if type(failure.keyId) == "number" then
                local spellName = GetSpellInfo and GetSpellInfo(failure.keyId)
                if not spellName then
                    failurePatterns.spellNameMissing = failurePatterns.spellNameMissing + 1
                end
            end
        end
        
        print("  Failure patterns:")
        for pattern, count in pairs(failurePatterns) do
            if count > 0 then
                print("    " .. pattern .. ": " .. count)
            end
        end
        
        -- Show some failed examples
        print("\n❌ FAILED RECIPE EXAMPLES:")
        for i = 1, math.min(5, #testResults.failed) do
            local failure = testResults.failed[i]
            print("  " .. failure.professionName .. " key " .. failure.keyId .. ":")
            print("    itemId=" .. tostring(failure.recipe.itemId) .. 
                  ", spellId=" .. tostring(failure.recipe.spellId) ..
                  ", skill=" .. tostring(failure.recipe.skill))
        end
    end
    
    print("\n💡 RECOMMENDATIONS:")
    if testResults.byMethod.failed > 0 then
        print("  • Investigate the " .. testResults.byMethod.failed .. " failed recipes")
        print("  • Check if failed recipes need special handling")
        print("  • Verify WoW API functions return expected data")
    end
    
    if testResults.byMethod.method2 > testResults.byMethod.method25 then
        print("  • Item ID lookup works best - prioritize this method")
    end
    
    if testResults.byMethod.method3 > 0 then
        print("  • Name matching still needed as fallback")
    end
    
    print("\n=== Missing Recipe Diagnostic Complete ===")
end

-- Start the diagnostic
MissingRecipeDiagnostic()
