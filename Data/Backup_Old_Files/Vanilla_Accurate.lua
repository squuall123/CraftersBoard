-- Vanilla_Accurate.lua
-- Rich recipe database inspired by Recipe Master with comprehensive data for all professions
-- Data structure optimized for CraftersBoard (crafting service platform)
-- Excludes source information as CraftersBoard focuses on crafting availability, not acquisition

VanillaAccurateData = {}

-- Profession constants (matching Blizzard spell IDs)
local PROFESSIONS = {
    ALCHEMY = 171,
    BLACKSMITHING = 164,
    COOKING = 185,
    ENCHANTING = 333,
    ENGINEERING = 202,
    FIRST_AID = 129,
    FISHING = 356,
    HERBALISM = 182,
    LEATHERWORKING = 165,
    MINING = 186,
    TAILORING = 197,
    SKINNING = 393
}

-- Specialization constants
local SPECIALIZATIONS = {
    -- Blacksmithing
    ARMORSMITH = 9787,
    WEAPONSMITH = 9788,
    MASTER_SWORDSMITH = 17039,
    MASTER_HAMMERSMITH = 17040,
    MASTER_AXESMITH = 17041,
    
    -- Engineering  
    GNOMISH_ENGINEERING = 20219,
    GOBLIN_ENGINEERING = 20222,
    
    -- Leatherworking
    DRAGONSCALE_LEATHERWORKING = 10656,
    ELEMENTAL_LEATHERWORKING = 10658,
    TRIBAL_LEATHERWORKING = 10660
}

-- Recipe database structure: [professionId][recipeId] = recipeData
VanillaAccurateData.recipes = {
    -- ALCHEMY (171)
    [PROFESSIONS.ALCHEMY] = {
        [2259] = {
            name = "Minor Healing Potion",
            itemId = 118,
            spellId = 2259,
            skill = 1,
            difficulty = {1, 60, 90, 120},
            category = "Healing Potions"
        },
        [2260] = {
            name = "Minor Mana Potion", 
            itemId = 2455,
            spellId = 2260,
            skill = 25,
            difficulty = {25, 65, 95, 125},
            category = "Mana Potions"
        },
        [2275] = {
            name = "Healing Potion",
            itemId = 929,
            spellId = 2275,
            skill = 55,
            difficulty = {55, 95, 125, 155},
            category = "Healing Potions"
        },
        [3230] = {
            name = "Mana Potion",
            itemId = 3827,
            spellId = 3230,
            skill = 80,
            difficulty = {80, 120, 150, 180},
            category = "Mana Potions"
        },
        [7845] = {
            name = "Greater Healing Potion",
            itemId = 1710,
            spellId = 7845,
            skill = 155,
            difficulty = {155, 195, 225, 255},
            category = "Healing Potions"
        },
        [11449] = {
            name = "Greater Mana Potion",
            itemId = 6149,
            spellId = 11449,
            skill = 205,
            difficulty = {205, 245, 275, 305},
            category = "Mana Potions"
        },
        [15920] = {
            name = "Superior Healing Potion",
            itemId = 3928,
            spellId = 15920,
            skill = 215,
            difficulty = {215, 255, 285, 315},
            category = "Healing Potions"
        },
        [17553] = {
            name = "Superior Mana Potion", 
            itemId = 13443,
            spellId = 17553,
            skill = 260,
            difficulty = {260, 300, 330, 360},
            category = "Mana Potions"
        },
        [24266] = {
            name = "Major Healing Potion",
            itemId = 13446,
            spellId = 24266,
            skill = 275,
            difficulty = {275, 315, 345, 375},
            category = "Healing Potions"
        },
        [17554] = {
            name = "Major Mana Potion",
            itemId = 13444,
            spellId = 17554,
            skill = 295,
            difficulty = {295, 335, 365, 395},
            category = "Mana Potions"
        }
    },

    -- BLACKSMITHING (164)
    [PROFESSIONS.BLACKSMITHING] = {
        [2660] = {
            name = "Rough Sharpening Stone",
            itemId = 2862,
            spellId = 2660,
            skill = 1,
            difficulty = {1, 40, 70, 100},
            category = "Weapon Enhancements"
        },
        [3115] = {
            name = "Rough Copper Vest",
            itemId = 3375,
            spellId = 3115,
            skill = 1,
            difficulty = {1, 25, 47, 70},
            category = "Mail Armor"
        },
        [2661] = {
            name = "Copper Chain Boots",
            itemId = 3376,
            spellId = 2661,
            skill = 20,
            difficulty = {20, 55, 77, 100},
            category = "Mail Armor"
        },
        [3116] = {
            name = "Copper Chain Vest",
            itemId = 3377,
            spellId = 3116,
            skill = 35,
            difficulty = {35, 70, 92, 115},
            category = "Mail Armor"
        },
        [2662] = {
            name = "Copper Bracers",
            itemId = 2853,
            spellId = 2662,
            skill = 1,
            difficulty = {1, 25, 47, 70},
            category = "Mail Armor"
        },
        [7408] = {
            name = "Heavy Copper Maul",
            itemId = 6214,
            spellId = 7408,
            skill = 65,
            difficulty = {65, 100, 122, 145},
            category = "Two-Handed Maces"
        },
        [2672] = {
            name = "Bronze Mace",
            itemId = 2844,
            spellId = 2672,
            skill = 110,
            difficulty = {110, 145, 167, 190},
            category = "One-Handed Maces"
        },
        [3501] = {
            name = "Green Iron Bracers",
            itemId = 3835,
            spellId = 3501,
            skill = 165,
            difficulty = {165, 190, 202, 215},
            category = "Mail Armor"
        },
        [8367] = {
            name = "Iron Shield Spike",
            itemId = 7967,
            spellId = 8367,
            skill = 150,
            difficulty = {150, 185, 205, 225},
            category = "Shield Enhancements"
        },
        [9935] = {
            name = "Steel Weapon Chain",
            itemId = 7922,
            spellId = 9935,
            skill = 215,
            difficulty = {215, 235, 245, 255},
            category = "Weapon Enhancements"
        },
        [16639] = {
            name = "Dense Grinding Stone",
            itemId = 12644,
            spellId = 16639,
            skill = 250,
            difficulty = {250, 255, 257, 260},
            category = "Weapon Enhancements"
        },
        [16641] = {
            name = "Dense Sharpening Stone",
            itemId = 12404,
            spellId = 16641,
            skill = 250,
            difficulty = {250, 255, 257, 260},
            category = "Weapon Enhancements"
        },
        [16742] = {
            name = "Stronghold Gauntlets",
            itemId = 12620,
            spellId = 16742,
            skill = 300,
            difficulty = {300, 320, 330, 340},
            category = "Plate Armor",
            specialization = SPECIALIZATIONS.ARMORSMITH
        },
        [16745] = {
            name = "Ornate Thorium Handaxe",
            itemId = 12618,
            spellId = 16745,
            skill = 300,
            difficulty = {300, 320, 330, 340},
            category = "One-Handed Axes",
            specialization = SPECIALIZATIONS.WEAPONSMITH
        }
    },

    -- COOKING (185)
    [PROFESSIONS.COOKING] = {
        [2538] = {
            name = "Charred Wolf Meat",
            itemId = 2679,
            spellId = 2538,
            skill = 1,
            difficulty = {1, 40, 70, 100},
            category = "Meat"
        },
        [2539] = {
            name = "Spice Bread",
            itemId = 2683,
            spellId = 2539,
            skill = 1,
            difficulty = {1, 40, 70, 100},
            category = "Bread"
        },
        [2540] = {
            name = "Roasted Boar Meat",
            itemId = 2687,
            spellId = 2540,
            skill = 1,
            difficulty = {1, 40, 70, 100},
            category = "Meat"
        },
        [6412] = {
            name = "Kaldorei Spider Kabob",
            itemId = 5472,
            spellId = 6412,
            skill = 10,
            difficulty = {10, 50, 70, 90},
            category = "Meat"
        },
        [15935] = {
            name = "Dragonbreath Chili",
            itemId = 12217,
            spellId = 15935,
            skill = 200,
            difficulty = {200, 240, 260, 280},
            category = "Exotic"
        },
        [18260] = {
            name = "Runn Tum Tuber Surprise",
            itemId = 18045,
            spellId = 18260,
            skill = 275,
            difficulty = {275, 315, 345, 375},
            category = "Exotic"
        }
    },

    -- ENCHANTING (333)
    [PROFESSIONS.ENCHANTING] = {
        [7414] = {
            name = "Enchant Bracer - Minor Health",
            itemId = nil, -- Enchantments don't create items
            spellId = 7414,
            skill = 1,
            difficulty = {1, 70, 90, 110},
            category = "Bracer"
        },
        [7418] = {
            name = "Enchant Bracer - Minor Mana",
            itemId = nil,
            spellId = 7418,
            skill = 80,
            difficulty = {80, 120, 140, 160},
            category = "Bracer"
        },
        [13378] = {
            name = "Enchant Weapon - Minor Beastslaying",
            itemId = nil,
            spellId = 13378,
            skill = 90,
            difficulty = {90, 130, 150, 170},
            category = "Weapon"
        },
        [13419] = {
            name = "Enchant Cloak - Minor Agility",
            itemId = nil,
            spellId = 13419,
            skill = 110,
            difficulty = {110, 150, 170, 190},
            category = "Cloak"
        },
        [13937] = {
            name = "Enchant 2H Weapon - Superior Impact",
            itemId = nil,
            spellId = 13937,
            skill = 295,
            difficulty = {295, 335, 365, 395},
            category = "Weapon"
        },
        [20051] = {
            name = "Enchant Chest - Superior Health",
            itemId = nil,
            spellId = 20051,
            skill = 275,
            difficulty = {275, 315, 345, 375},
            category = "Chest"
        }
    },

    -- ENGINEERING (202)
    [PROFESSIONS.ENGINEERING] = {
        [3918] = {
            name = "Rough Blasting Powder",
            itemId = 4357,
            spellId = 3918,
            skill = 1,
            difficulty = {1, 31, 61, 91},
            category = "Explosives"
        },
        [3919] = {
            name = "Rough Dynamite",
            itemId = 4358,
            spellId = 3919,
            skill = 1,
            difficulty = {1, 50, 75, 100},
            category = "Explosives"
        },
        [3922] = {
            name = "Handful of Copper Bolts",
            itemId = 4359,
            spellId = 3922,
            skill = 30,
            difficulty = {30, 50, 65, 80},
            category = "Parts"
        },
        [3924] = {
            name = "Copper Tube",
            itemId = 4361,
            spellId = 3924,
            skill = 50,
            difficulty = {50, 80, 95, 110},
            category = "Parts"
        },
        [12590] = {
            name = "Gyrofreeze Ice Reflector",
            itemId = 10498,
            spellId = 12590,
            skill = 175,
            difficulty = {175, 175, 195, 215},
            category = "Trinkets"
        },
        [12718] = {
            name = "Goblin Rocket Fuel",
            itemId = 10543,
            spellId = 12718,
            skill = 205,
            difficulty = {205, 225, 235, 245},
            category = "Parts",
            specialization = SPECIALIZATIONS.GOBLIN_ENGINEERING
        },
        [12897] = {
            name = "Gnomish Cloaking Device",
            itemId = 10545,
            spellId = 12897,
            skill = 210,
            difficulty = {210, 230, 240, 250},
            category = "Trinkets",
            specialization = SPECIALIZATIONS.GNOMISH_ENGINEERING
        }
    },

    -- FIRST AID (129)
    [PROFESSIONS.FIRST_AID] = {
        [3273] = {
            name = "Linen Bandage",
            itemId = 2581,
            spellId = 3273,
            skill = 1,
            difficulty = {1, 40, 70, 100},
            category = "Bandages"
        },
        [3274] = {
            name = "Heavy Linen Bandage",
            itemId = 2581,
            spellId = 3274,
            skill = 40,
            difficulty = {40, 80, 110, 140},
            category = "Bandages"
        },
        [7928] = {
            name = "Silk Bandage",
            itemId = 6450,
            spellId = 7928,
            skill = 125,
            difficulty = {125, 165, 195, 225},
            category = "Bandages"
        },
        [7929] = {
            name = "Heavy Silk Bandage",
            itemId = 6451,
            spellId = 7929,
            skill = 150,
            difficulty = {150, 190, 220, 250},
            category = "Bandages"
        },
        [10840] = {
            name = "Mageweave Bandage",
            itemId = 8544,
            spellId = 10840,
            skill = 175,
            difficulty = {175, 215, 245, 275},
            category = "Bandages"
        },
        [10841] = {
            name = "Heavy Mageweave Bandage",
            itemId = 8545,
            spellId = 10841,
            skill = 200,
            difficulty = {200, 240, 270, 300},
            category = "Bandages"
        },
        [18629] = {
            name = "Runecloth Bandage",
            itemId = 14529,
            spellId = 18629,
            skill = 260,
            difficulty = {260, 290, 310, 330},
            category = "Bandages"
        },
        [18630] = {
            name = "Heavy Runecloth Bandage",
            itemId = 14530,
            spellId = 18630,
            skill = 290,
            difficulty = {290, 320, 340, 360},
            category = "Bandages"
        }
    },

    -- LEATHERWORKING (165)
    [PROFESSIONS.LEATHERWORKING] = {
        [2149] = {
            name = "Handstitched Leather Boots",
            itemId = 2302,
            spellId = 2149,
            skill = 1,
            difficulty = {1, 35, 55, 75},
            category = "Leather Armor"
        },
        [2153] = {
            name = "Handstitched Leather Pants",
            itemId = 2303,
            spellId = 2153,
            skill = 15,
            difficulty = {15, 55, 75, 95},
            category = "Leather Armor"
        },
        [2160] = {
            name = "Embossed Leather Vest",
            itemId = 2311,
            spellId = 2160,
            skill = 40,
            difficulty = {40, 80, 100, 120},
            category = "Leather Armor"
        },
        [3753] = {
            name = "Brigandine Vest",
            itemId = 3377,
            spellId = 3753,
            skill = 150,
            difficulty = {150, 190, 210, 230},
            category = "Leather Armor"
        },
        [9068] = {
            name = "Barbaric Shoulders",
            itemId = 7374,
            spellId = 9068,
            skill = 175,
            difficulty = {175, 215, 235, 255},
            category = "Leather Armor"
        },
        [10487] = {
            name = "Icescale Gauntlets",
            itemId = 8348,
            spellId = 10487,
            skill = 190,
            difficulty = {190, 230, 250, 270},
            category = "Mail Armor",
            specialization = SPECIALIZATIONS.DRAGONSCALE_LEATHERWORKING
        },
        [19047] = {
            name = "Stormshroud Pants",
            itemId = 15308,
            spellId = 19047,
            skill = 250,
            difficulty = {250, 290, 310, 330},
            category = "Leather Armor",
            specialization = SPECIALIZATIONS.ELEMENTAL_LEATHERWORKING
        },
        [19049] = {
            name = "Warbear Harness",
            itemId = 15293,
            spellId = 19049,
            skill = 275,
            difficulty = {275, 315, 335, 355},
            category = "Leather Armor",
            specialization = SPECIALIZATIONS.TRIBAL_LEATHERWORKING
        }
    },

    -- TAILORING (197)
    [PROFESSIONS.TAILORING] = {
        [2963] = {
            name = "Bolt of Linen Cloth",
            itemId = 2996,
            spellId = 2963,
            skill = 1,
            difficulty = {1, 27, 52, 77},
            category = "Cloth"
        },
        [2964] = {
            name = "Linen Boots",
            itemId = 2302,
            spellId = 2964,
            skill = 1,
            difficulty = {1, 25, 50, 75},
            category = "Cloth Armor"
        },
        [2968] = {
            name = "Linen Cloak",
            itemId = 2307,
            spellId = 2968,
            skill = 1,
            difficulty = {1, 35, 60, 85},
            category = "Cloaks"
        },
        [3915] = {
            name = "Brown Linen Vest",
            itemId = 4312,
            spellId = 3915,
            skill = 40,
            difficulty = {40, 75, 87, 100},
            category = "Cloth Armor"
        },
        [8762] = {
            name = "Linen Belt",
            itemId = 7046,
            spellId = 8762,
            skill = 70,
            difficulty = {70, 105, 117, 130},
            category = "Cloth Armor"
        },
        [12045] = {
            name = "Mageweave Bag",
            itemId = 10050,
            spellId = 12045,
            skill = 225,
            difficulty = {225, 265, 290, 315},
            category = "Bags"
        },
        [18560] = {
            name = "Mooncloth",
            itemId = 14342,
            spellId = 18560,
            skill = 250,
            difficulty = {250, 290, 315, 340},
            category = "Cloth",
            cooldown = 345600 -- 4 days
        },
        [22902] = {
            name = "Mooncloth Vest",
            itemId = 18486,
            spellId = 22902,
            skill = 300,
            difficulty = {300, 330, 347, 365},
            category = "Cloth Armor"
        }
    }
}

-- Category definitions for organization
VanillaAccurateData.categories = {
    [PROFESSIONS.ALCHEMY] = {
        "Healing Potions", "Mana Potions", "Buff Potions", "Utility Potions", 
        "Transmutation", "Oils", "Elixirs", "Flasks"
    },
    [PROFESSIONS.BLACKSMITHING] = {
        "Weapon Enhancements", "Shield Enhancements", "Mail Armor", "Plate Armor",
        "One-Handed Swords", "Two-Handed Swords", "One-Handed Maces", "Two-Handed Maces",
        "One-Handed Axes", "Two-Handed Axes", "Polearms", "Daggers"
    },
    [PROFESSIONS.COOKING] = {
        "Meat", "Fish", "Bread", "Exotic", "Seasonal"
    },
    [PROFESSIONS.ENCHANTING] = {
        "Weapon", "Chest", "Bracer", "Gloves", "Boots", "Cloak", "Shield"
    },
    [PROFESSIONS.ENGINEERING] = {
        "Explosives", "Parts", "Trinkets", "Goggles", "Guns", "Ammunition", "Devices"
    },
    [PROFESSIONS.FIRST_AID] = {
        "Bandages", "Anti-Venoms"
    },
    [PROFESSIONS.LEATHERWORKING] = {
        "Leather Armor", "Mail Armor", "Cloaks", "Bags", "Weapon Enhancements"
    },
    [PROFESSIONS.TAILORING] = {
        "Cloth", "Cloth Armor", "Robes", "Cloaks", "Bags", "Shirts"
    }
}

-- Specialization information
VanillaAccurateData.specializations = {
    [PROFESSIONS.BLACKSMITHING] = {
        [SPECIALIZATIONS.ARMORSMITH] = "Armorsmith",
        [SPECIALIZATIONS.WEAPONSMITH] = "Weaponsmith", 
        [SPECIALIZATIONS.MASTER_SWORDSMITH] = "Master Swordsmith",
        [SPECIALIZATIONS.MASTER_HAMMERSMITH] = "Master Hammersmith",
        [SPECIALIZATIONS.MASTER_AXESMITH] = "Master Axesmith"
    },
    [PROFESSIONS.ENGINEERING] = {
        [SPECIALIZATIONS.GNOMISH_ENGINEERING] = "Gnomish Engineering",
        [SPECIALIZATIONS.GOBLIN_ENGINEERING] = "Goblin Engineering"
    },
    [PROFESSIONS.LEATHERWORKING] = {
        [SPECIALIZATIONS.DRAGONSCALE_LEATHERWORKING] = "Dragonscale Leatherworking",
        [SPECIALIZATIONS.ELEMENTAL_LEATHERWORKING] = "Elemental Leatherworking", 
        [SPECIALIZATIONS.TRIBAL_LEATHERWORKING] = "Tribal Leatherworking"
    }
}

-- Difficulty color thresholds (orange, yellow, green, gray)
VanillaAccurateData.difficultyColors = {
    ORANGE = 1, -- recipe[1] - always gives skill point
    YELLOW = 2, -- recipe[2] - high chance for skill point
    GREEN = 3,  -- recipe[3] - medium chance for skill point
    GRAY = 4    -- recipe[4] - no skill points
}

-- Utility function to get recipe data
function VanillaAccurateData:GetRecipe(professionId, recipeId)
    if self.recipes[professionId] and self.recipes[professionId][recipeId] then
        return self.recipes[professionId][recipeId]
    end
    return nil
end

-- Utility function to get recipes by profession
function VanillaAccurateData:GetRecipesByProfession(professionId)
    return self.recipes[professionId] or {}
end

-- Utility function to get recipes by category
function VanillaAccurateData:GetRecipesByCategory(professionId, category)
    local recipes = {}
    if self.recipes[professionId] then
        for recipeId, recipeData in pairs(self.recipes[professionId]) do
            if recipeData.category == category then
                recipes[recipeId] = recipeData
            end
        end
    end
    return recipes
end

-- Utility function to get recipes by skill level
function VanillaAccurateData:GetRecipesBySkillLevel(professionId, skillLevel)
    local recipes = {}
    if self.recipes[professionId] then
        for recipeId, recipeData in pairs(self.recipes[professionId]) do
            if recipeData.skill <= skillLevel then
                recipes[recipeId] = recipeData
            end
        end
    end
    return recipes
end

-- Utility function to get recipe difficulty color at current skill
function VanillaAccurateData:GetRecipeDifficulty(professionId, recipeId, currentSkill)
    local recipe = self:GetRecipe(professionId, recipeId)
    if not recipe or not recipe.difficulty then
        return nil
    end
    
    local diff = recipe.difficulty
    if currentSkill >= diff[4] then
        return "gray"
    elseif currentSkill >= diff[3] then
        return "green"  
    elseif currentSkill >= diff[2] then
        return "yellow"
    else
        return "orange"
    end
end

-- Utility function to check if recipe requires specialization
function VanillaAccurateData:RequiresSpecialization(professionId, recipeId)
    local recipe = self:GetRecipe(professionId, recipeId)
    return recipe and recipe.specialization ~= nil
end

-- Export the data globally for addon access
_G.VanillaAccurateData = VanillaAccurateData
