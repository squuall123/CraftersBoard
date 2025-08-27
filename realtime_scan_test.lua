-- Real-time profession scanning test to identify exactly which recipes fail
-- Run this while you have a profession window open

print("=== CraftersBoard Real-Time Profession Scan Test ===")

local function RealTimeScanTest()
    -- Check if profession window is open
    if not TradeSkillFrame or not TradeSkillFrame:IsVisible() then
        print("❌ Please open your profession window first!")
        print("💡 Open Alchemy, Blacksmithing, or any other profession window")
        return
    end
    
    if not GetNumTradeSkills or GetNumTradeSkills() == 0 then
        print("❌ No trade skills available or API not working")
        return
    end
    
    local numSkills = GetNumTradeSkills()
    print("🔍 Scanning " .. numSkills .. " recipes in open profession window...")
    
    local results = {
        total = 0,
        successful = 0,
        failed = 0,
        failedRecipes = {},
        successByMethod = {
            direct_spell = 0,
            item_lookup = 0,
            spell_key = 0,
            name_match = 0
        }
    }
    
    -- Scan each recipe in the profession window
    for i = 1, numSkills do
        local name, type, numAvailable, isExpanded, _, _, skillType = GetTradeSkillInfo(i)
        
        -- Only process actual recipes (not headers)
        if name and type ~= "header" and type ~= "subheader" then
            results.total = results.total + 1
            
            print("\n📝 Recipe " .. i .. ": " .. name .. " (type: " .. tostring(type) .. ")")
            
            local spellId = nil
            local method = "none"
            
            -- Method 1: Try GetTradeSkillRecipeLink (direct spell ID)
            if GetTradeSkillRecipeLink then
                local recipeLink = GetTradeSkillRecipeLink(i)
                if recipeLink then
                    spellId = recipeLink:match("|H.-:(%d+)|h")
                    if spellId then
                        spellId = tonumber(spellId)
                        method = "direct_spell"
                        results.successByMethod.direct_spell = results.successByMethod.direct_spell + 1
                        print("  ✅ Method 1 (Direct): Found spell ID " .. spellId)
                    else
                        print("  ⚠️  Method 1: Recipe link found but no spell ID: " .. recipeLink)
                    end
                else
                    print("  ⚠️  Method 1: No recipe link available")
                end
            end
            
            -- Method 2: Try item link approach
            if not spellId and GetTradeSkillItemLink then
                local itemLink = GetTradeSkillItemLink(i)
                if itemLink then
                    local itemId = itemLink:match("|Hitem:(%d+):")
                    if itemId then
                        itemId = tonumber(itemId)
                        print("  🔍 Method 2: Found item ID " .. itemId)
                        
                        -- Look up in Recipe_Master
                        if CraftersBoard and CraftersBoard.ProfessionLinks then
                            spellId = CraftersBoard.ProfessionLinks.GetSpellIdFromItemId(itemId)
                            if spellId then
                                method = "item_lookup"
                                results.successByMethod.item_lookup = results.successByMethod.item_lookup + 1
                                print("  ✅ Method 2 (Item ID): Found spell ID " .. spellId)
                            else
                                print("  ❌ Method 2: Item ID " .. itemId .. " not found in Recipe_Master")
                            end
                        end
                    else
                        print("  ⚠️  Method 2: Could not extract item ID from: " .. itemLink)
                    end
                else
                    print("  ⚠️  Method 2: No item link available (might be enchantment)")
                end
            end
            
            -- Method 2.5: Try spell key lookup (for enchantments)
            if not spellId and GetTradeSkillRecipeLink then
                local recipeLink = GetTradeSkillRecipeLink(i)
                if recipeLink then
                    local potentialSpellId = recipeLink:match("|H.-:(%d+)|h")
                    if potentialSpellId then
                        potentialSpellId = tonumber(potentialSpellId)
                        print("  🔍 Method 2.5: Trying spell key " .. potentialSpellId)
                        
                        if CraftersBoard and CraftersBoard.ProfessionLinks then
                            local confirmedSpellId = CraftersBoard.ProfessionLinks.GetSpellIdBySpellKey(potentialSpellId)
                            if confirmedSpellId then
                                spellId = confirmedSpellId
                                method = "spell_key"
                                results.successByMethod.spell_key = results.successByMethod.spell_key + 1
                                print("  ✅ Method 2.5 (Spell Key): Confirmed spell ID " .. spellId)
                            else
                                print("  ❌ Method 2.5: Spell ID " .. potentialSpellId .. " not confirmed in Recipe_Master")
                            end
                        end
                    end
                end
            end
            
            -- Method 3: Name matching fallback
            if not spellId then
                print("  🔍 Method 3: Trying name matching for '" .. name .. "'")
                
                if CraftersBoard and CraftersBoard.ProfessionLinks then
                    spellId = CraftersBoard.ProfessionLinks.GetSpellIdFromRecipeMasterData(name)
                    if spellId then
                        method = "name_match"
                        results.successByMethod.name_match = results.successByMethod.name_match + 1
                        print("  ✅ Method 3 (Name): Found spell ID " .. spellId)
                    else
                        print("  ❌ Method 3: No match for recipe name '" .. name .. "'")
                    end
                end
            end
            
            -- Record final result
            if spellId then
                results.successful = results.successful + 1
                print("  🎯 FINAL: spell ID " .. spellId .. " via " .. method)
            else
                results.failed = results.failed + 1
                
                -- Collect detailed failure info
                local failureInfo = {
                    index = i,
                    name = name,
                    type = type,
                    recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i),
                    itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i),
                    difficulty = GetTradeSkillDifficulty and GetTradeSkillDifficulty(i),
                    description = GetTradeSkillDescription and GetTradeSkillDescription(i)
                }
                
                table.insert(results.failedRecipes, failureInfo)
                print("  ❌ FAILED: No spell ID found for '" .. name .. "'")
            end
        end
    end
    
    -- Print summary
    local successRate = results.total > 0 and math.floor(results.successful / results.total * 100) or 0
    print("\n📊 SCAN RESULTS SUMMARY:")
    print("  Total recipes: " .. results.total)
    print("  Successful: " .. results.successful .. " (" .. successRate .. "%)")
    print("  Failed: " .. results.failed .. " (" .. (100 - successRate) .. "%)")
    
    print("\n  Success by method:")
    print("    Direct spell link: " .. results.successByMethod.direct_spell)
    print("    Item ID lookup: " .. results.successByMethod.item_lookup)
    print("    Spell key lookup: " .. results.successByMethod.spell_key)
    print("    Name matching: " .. results.successByMethod.name_match)
    
    -- Show failed recipes details
    if #results.failedRecipes > 0 then
        print("\n❌ FAILED RECIPES DETAILED ANALYSIS:")
        for i, failure in ipairs(results.failedRecipes) do
            print("  " .. i .. ". " .. failure.name .. " (index " .. failure.index .. "):")
            print("     Type: " .. tostring(failure.type))
            print("     Recipe Link: " .. tostring(failure.recipeLink))
            print("     Item Link: " .. tostring(failure.itemLink))
            print("     Difficulty: " .. tostring(failure.difficulty))
            
            -- Try to extract IDs for manual checking
            if failure.recipeLink then
                local extractedId = failure.recipeLink:match("|H.-:(%d+)|h")
                if extractedId then
                    print("     Extracted ID from recipe link: " .. extractedId)
                end
            end
            
            if failure.itemLink then
                local itemId = failure.itemLink:match("|Hitem:(%d+):")
                if itemId then
                    print("     Extracted item ID: " .. itemId)
                end
            end
            print("")
        end
        
        print("💡 RECOMMENDATIONS FOR FAILED RECIPES:")
        print("  • Check if these recipes need special handling")
        print("  • Verify the extracted IDs exist in Recipe_Master database")
        print("  • Some might be skill-ups or special recipes not in database")
    end
    
    print("\n=== Real-Time Scan Test Complete ===")
end

-- Start the test
RealTimeScanTest()
