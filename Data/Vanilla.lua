-- CraftersBoard - Vanilla Classic Era Dictionary Data
-- WoW Classic Era profession spell ID to recipe name mappings
-- Version: 1.0.0

-- Create namespace for vanilla data
local VanillaData = {}

-- Profession ID constants (matching WoW's profession skill line IDs)
VanillaData.PROFESSION_IDS = {
    ALCHEMY = 171,
    BLACKSMITHING = 164,
    ENCHANTING = 333,
    ENGINEERING = 202,
    LEATHERWORKING = 165,
    TAILORING = 197,
    COOKING = 185,
    FIRST_AID = 129,
    FISHING = 356,
    HERBALISM = 182,
    MINING = 186,
    SKINNING = 393
}

-- Recipe Spell ID Dictionary organized by profession ID
-- This allows efficient filtering by profession without scanning all data
VanillaData.RECIPES_BY_PROFESSION = {
    -- ========================================
    -- ALCHEMY (ID: 171) - COMPREHENSIVE
    -- ========================================
    [171] = {
        name = "Alchemy",
        recipes = {
            -- Flasks (High-Level)
            [17635] = "Flask of the Titans",
            [17636] = "Flask of Distilled Wisdom",
            [17637] = "Flask of Supreme Power",
            [17638] = "Flask of Chromatic Resistance",
            [17634] = "Flask of Petrification",
            
            -- Transmutes
            [17560] = "Transmute: Fire to Earth",
            [17565] = "Transmute: Life to Earth",
            [17561] = "Transmute: Earth to Water",
            [17563] = "Transmute: Undeath to Water",
            [17562] = "Transmute: Water to Air",
            [17564] = "Transmute: Water to Undeath",
            [17566] = "Transmute: Earth to Life",
            [17559] = "Transmute: Air to Fire",
            [17187] = "Transmute: Arcanite",
            [11479] = "Transmute: Iron to Gold",
            [11480] = "Transmute: Mithril to Truesilver",
            [25146] = "Transmute: Elemental Fire",
            
            -- Healing Potions (All Ranks)
            [17556] = "Major Healing Potion",
            [11457] = "Superior Healing Potion",
            [7181] = "Greater Healing Potion",
            [3447] = "Healing Potion",
            [2337] = "Lesser Healing Potion",
            [2330] = "Minor Healing Potion",
            [2332] = "Minor Rejuvenation Potion",
            [4508] = "Discolored Healing Potion",
            [11458] = "Wildvine Potion",
            
            -- Mana Potions (All Ranks)
            [17580] = "Major Mana Potion",
            [17553] = "Superior Mana Potion",
            [11448] = "Greater Mana Potion",
            [3173] = "Mana Potion",
            [2335] = "Lesser Mana Potion",
            [2331] = "Minor Mana Potion",
            [3826] = "Mighty Troll's Blood Potion",
            
            -- Guardian Elixirs (Defensive)
            [11453] = "Greater Arcane Elixir",
            [9155] = "Arcane Elixir",
            [11465] = "Elixir of Greater Intellect",
            [3171] = "Elixir of Intellect",
            [11463] = "Elixir of Superior Defense",
            [9187] = "Elixir of Greater Defense",
            [5997] = "Elixir of Minor Defense",
            [3188] = "Elixir of Fortitude",
            [2334] = "Elixir of Minor Fortitude",
            [3170] = "Elixir of Wisdom",
            [11459] = "Elixir of the Sages",
            
            -- Battle Elixirs (Offensive)
            [11451] = "Elixir of Arcane Power",
            [2329] = "Elixir of Lion's Strength",
            [11467] = "Elixir of Greater Agility",
            [11449] = "Elixir of Agility",
            [2454] = "Elixir of Lesser Agility",
            [2457] = "Elixir of Minor Agility",
            [8240] = "Elixir of Giant Growth",
            [11464] = "Elixir of Brute Force",
            [11477] = "Elixir of the Mongoose",
            [7845] = "Elixir of Firepower",
            [9264] = "Elixir of Shadow Power",
            [11406] = "Elixir of Demonslaying",
            
            -- Utility Potions
            [6617] = "Elixir of Water Breathing",
            [7179] = "Elixir of Water Walking",
            [6662] = "Elixir of Swimming",
            [7841] = "Swim Speed Potion",
            [6624] = "Free Action Potion",
            [7359] = "Swiftness Potion",
            [2459] = "Swiftness Potion",
            [11460] = "Elixir of Detect Undead",
            [11466] = "Elixir of Detect Lesser Invisibility",
            
            -- Protection Potions
            [3385] = "Lesser Stoneshield Potion",
            [17573] = "Greater Stoneshield Potion",
            [4623] = "Lesser Invisibility Potion",
            [11407] = "Greater Invisibility Potion",
            [11456] = "Elixir of Poison Resistance",
            [9179] = "Elixir of Poison Resistance",
            [3386] = "Potion of Poison Resistance",
            
            -- Combat Potions
            [7183] = "Rage Potion",
            [5631] = "Rage Potion",
            [3220] = "Blood of the Mountain",
            
            -- Restoration & Sleep
            [9030] = "Restorative Potion",
            [11452] = "Restorative Potion",
            [17572] = "Purification Potion",
            [24366] = "Greater Dreamless Sleep Potion",
            [24367] = "Major Dreamless Sleep Potion",
            [2333] = "Elixir of Minor Fortune"
        }
    },

    -- ========================================
    -- BLACKSMITHING (ID: 164) - COMPREHENSIVE
    -- ========================================
    [164] = {
        name = "Blacksmithing",
        recipes = {
            -- Legendary & Epic Weapons
            [16994] = "Arcanite Reaper",
            [16995] = "Arcanite Champion",
            [16993] = "Arcanite Skeleton Key",
            [20201] = "Sulfuron Hammer",
            [21161] = "Eye of Sulfuras",
            
            -- High-Level Weapons
            [16969] = "Thorium Greatsword",
            [16978] = "Thorium Boots",
            [16979] = "Thorium Helm",
            [16960] = "Thorium Rifle",
            [16965] = "Thorium Tube",
            [16967] = "Thorium Shield Spike",
            
            -- Imperial Plate Set
            [16970] = "Imperial Plate Shoulders",
            [16971] = "Imperial Plate Belt",
            [16972] = "Imperial Plate Boots",
            [16973] = "Imperial Plate Bracer",
            [16974] = "Imperial Plate Chest",
            [16975] = "Imperial Plate Helm",
            [16976] = "Imperial Plate Leggings",
            
            -- Ornate Mithril Set
            [9950] = "Ornate Mithril Breastplate",
            [9952] = "Ornate Mithril Pants",
            [9959] = "Ornate Mithril Shoulder",
            [9961] = "Ornate Mithril Boots",
            [9964] = "Ornate Mithril Gloves",
            [9966] = "Ornate Mithril Helm",
            
            -- Enchanted Mithril Set
            [11643] = "Enchanted Mithril Breastplate",
            [11644] = "Enchanted Mithril Pants",
            [11645] = "Enchanted Mithril Helm",
            
            -- Low-Level Copper Items
            [2674] = "Copper Chain Boots",
            [8880] = "Copper Chain Vest",
            [3319] = "Copper Chain Pants",
            [3296] = "Copper Mace",
            [3297] = "Copper Axe",
            [3298] = "Copper Shortsword",
            [2738] = "Copper Battle Axe",
            [9983] = "Copper Claymore",
            
            -- Bronze Items
            [8607] = "Bronze Warhammer",
            [2739] = "Bronze Warhammer",
            [2741] = "Bronze Mace",
            [2742] = "Bronze Axe",
            [2743] = "Bronze Sword",
            [3328] = "Rough Bronze Shoulders",
            
            -- Green Iron Items
            [3330] = "Bright Boots",
            [3331] = "Bright Gloves",
            [3333] = "Bright Bracers",
            [3334] = "Green Iron Boots",
            [3336] = "Green Iron Gauntlets",
            [3337] = "Green Iron Bracers",
            [15292] = "Green Iron Hauberk",
            
            -- Heavy Mithril Items
            [7975] = "Heavy Mithril Pants",
            [7979] = "Heavy Mithril Shoulder",
            
            -- Sharpening Stones & Tools
            [3500] = "Coarse Grinding Stone",
            [3326] = "Coarse Sharpening Stone",
            [3501] = "Coarse Weightstone",
            [3502] = "Coarse Weightstone",
            [7408] = "Heavy Grinding Stone",
            [7817] = "Heavy Sharpening Stone",
            [7818] = "Heavy Weightstone",
            [7819] = "Solid Grinding Stone",
            [7820] = "Solid Sharpening Stone",
            [7821] = "Solid Weightstone",
            [16639] = "Dense Grinding Stone",
            [16641] = "Dense Sharpening Stone",
            [16640] = "Dense Weightstone",
            [16642] = "Dense Grinding Stone",
            
            -- Engineering Components
            [8608] = "Iron Strut",
            [6517] = "Inlaid Mithril Cylinder",
            [12404] = "Dense Blasting Powder",
            [19669] = "Arcanite Rod",
            
            -- Specialty Items
            [12259] = "Mithril Spurs",
            [12260] = "Thorium Spurs",
            [9939] = "Mithril Spurs"
        }
    },

    -- ========================================
    -- ========================================
    -- ENCHANTING (ID: 333) - COMPREHENSIVE
    -- ========================================
    [333] = {
        name = "Enchanting",
        recipes = {
            -- Weapon Enchantments - Lesser
            [7786] = "Enchant Weapon - Minor Beastslayer",
            [7788] = "Enchant Weapon - Minor Striking",
            [13529] = "Enchant 2H Weapon - Lesser Intellect",
            [13537] = "Enchant 2H Weapon - Lesser Impact",
            [13693] = "Enchant Weapon - Striking",
            [13695] = "Enchant 2H Weapon - Impact",
            [13898] = "Enchant Weapon - Fiery Weapon",
            [13915] = "Enchant Weapon - Demonslaying",
            [13943] = "Enchant Weapon - Greater Striking",
            [13947] = "Enchant 2H Weapon - Greater Impact",
            [20034] = "Enchant Weapon - Crusader",
            [20035] = "Enchant 2H Weapon - Major Spirit",
            [20036] = "Enchant 2H Weapon - Major Intellect",
            
            -- Weapon Enchantments - Advanced
            [13503] = "Enchant Weapon - Lesser Striking",
            [13668] = "Enchant Weapon - Unholy Weapon",
            [16250] = "Enchant Weapon - Superior Striking",
            [20029] = "Enchant Weapon - Icy Chill",
            [20030] = "Enchant Weapon - Superior Striking",
            [23799] = "Enchant Weapon - Strength",
            [23800] = "Enchant Weapon - Agility",
            [27837] = "Enchant 2H Weapon - Agility",
            
            -- Armor Enchantments - Chest
            [13538] = "Enchant Chest - Lesser Health",
            [13607] = "Enchant Chest - Mana",
            [13640] = "Enchant Chest - Greater Health",
            [13663] = "Enchant Chest - Greater Mana",
            [13917] = "Enchant Chest - Superior Health",
            [13941] = "Enchant Chest - Superior Mana",
            [20025] = "Enchant Chest - Greater Stats",
            [20026] = "Enchant Chest - Major Health",
            [20028] = "Enchant Chest - Major Mana",
            
            -- Armor Enchantments - Boots
            [13630] = "Enchant Boots - Minor Stamina",
            [13631] = "Enchant Boots - Minor Agility",
            [13637] = "Enchant Boots - Lesser Agility",
            [13644] = "Enchant Boots - Lesser Stamina",
            [13890] = "Enchant Boots - Minor Speed",
            [13935] = "Enchant Boots - Agility",
            [20023] = "Enchant Boots - Greater Agility",
            [20024] = "Enchant Boots - Spirit",
            
            -- Armor Enchantments - Gloves
            [13815] = "Enchant Gloves - Agility",
            [13817] = "Enchant Gloves - Strength",
            [13820] = "Enchant Gloves - Fishing",
            [13822] = "Enchant Gloves - Herbalism",
            [13841] = "Enchant Gloves - Advanced Mining",
            [13868] = "Enchant Gloves - Advanced Herbalism",
            [13887] = "Enchant Gloves - Strength",
            [13933] = "Enchant Gloves - Superior Agility",
            [13934] = "Enchant Gloves - Greater Strength",
            [20012] = "Enchant Gloves - Greater Agility",
            [20013] = "Enchant Gloves - Shadow Power",
            [25072] = "Enchant Gloves - Threat",
            
            -- Armor Enchantments - Bracers
            [13501] = "Enchant Bracer - Minor Health",
            [13536] = "Enchant Bracer - Lesser Spirit",
            [13622] = "Enchant Bracer - Lesser Intellect",
            [13642] = "Enchant Bracer - Spirit",
            [13661] = "Enchant Bracer - Strength",
            [13939] = "Enchant Bracer - Greater Strength",
            [13945] = "Enchant Bracer - Greater Stamina",
            [20008] = "Enchant Bracer - Greater Intellect",
            [20009] = "Enchant Bracer - Superior Spirit",
            [20010] = "Enchant Bracer - Superior Strength",
            [20011] = "Enchant Bracer - Superior Stamina",
            [23802] = "Enchant Bracer - Healing Power",
            
            -- Shield Enchantments
            [13485] = "Enchant Shield - Minor Protection",
            [13659] = "Enchant Shield - Lesser Block",
            [13689] = "Enchant Shield - Lesser Parry",
            [13931] = "Enchant Shield - Frost Resistance",
            [13937] = "Enchant Shield - Superior Spirit",
            [20015] = "Enchant Shield - Superior Stamina",
            [20016] = "Enchant Shield - Vitality",
            [20017] = "Enchant Shield - Greater Stamina",
            
            -- Cloak Enchantments
            [13522] = "Enchant Cloak - Minor Protection",
            [13635] = "Enchant Cloak - Defense",
            [13657] = "Enchant Cloak - Fire Resistance",
            [13746] = "Enchant Cloak - Greater Defense",
            [13794] = "Enchant Cloak - Resistance",
            [25086] = "Enchant Cloak - Dodge"
        }
    },

    -- ========================================
    -- ENGINEERING (ID: 202) - COMPREHENSIVE
    -- ========================================
    [202] = {
        name = "Engineering",
        recipes = {
            -- Gnomish Engineering Specialization
            [12902] = "Gnomish Cloaking Device",
            [12905] = "Gnomish Rocket Boots",
            [12906] = "Gnomish Battle Chicken",
            [12895] = "Inlaid Mithril Cylinder Plans",
            [12897] = "Gnomish Goggles",
            [12903] = "Gnomish Harm Prevention Belt",
            [12907] = "Gnomish Mind Control Cap",
            [12759] = "Gnomish Death Ray",
            [12899] = "Gnomish Shrink Ray",
            [12901] = "Gnomish Net-o-Matic Projector",
            
            -- Goblin Engineering Specialization
            [8895] = "Goblin Rocket Fuel",
            [8334] = "Clockwork Box",
            [7430] = "Goblin Jumper Cables",
            [12760] = "Goblin Sapper Charge",
            [12755] = "Goblin Bomb",
            [12758] = "Goblin Rocket Helmet",
            [8339] = "Goblin Rocket Boots",
            [12718] = "Goblin Construction Helmet",
            [12717] = "Goblin Mining Helmet",
            [8243] = "Goblin Land Mine",
            [12754] = "Big Bronze Bomb",
            [4390] = "Iron Grenade",
            [4392] = "Advanced Target Dummy",
            [12419] = "Big Iron Bomb",
            [12562] = "The Big One",
            [19790] = "Thorium Grenade",
            
            -- Explosives & Bombs
            [4380] = "Big Bronze Bomb",
            [4381] = "Minor Recombobulator",
            [4386] = "Ice Deflector",
            [4398] = "Large Seaforium Charge",
            [4407] = "Accurate Scope",
            [4412] = "Moonsight Rifle",
            [4413] = "Discombobulator Ray",
            [19825] = "Thorium Rifle",
            [19830] = "Arcanite Dragonling",
            [19831] = "Arcane Bomb",
            
            -- Mechanical Pets & Dragonlings
            [4073] = "Mechanical Dragonling",
            [4074] = "Mithril Mechanical Dragonling",
            [15633] = "Lil' Smoky",
            [15628] = "Pet Bombling",
            
            -- Scopes & Weapon Attachments
            [3977] = "Crude Scope",
            [4405] = "Crude Scope",
            [4406] = "Standard Scope",
            [4408] = "Deadly Scope",
            [12597] = "Sniper Scope",
            [19799] = "Dark Iron Rifle",
            
            -- Goggles & Helmets
            [3956] = "Green Tinted Goggles",
            [4385] = "Green Lens",
            [10506] = "Deepdive Helmet",
            [10507] = "Bright-Eye Goggles",
            [10518] = "Parachute Cloak",
            [10558] = "Gold Power Core",
            [10559] = "Mithril Tube",
            
            -- Utility Items
            [18631] = "Major Recombobulator",
            [4395] = "Goblin Land Mine",
            [4397] = "Gnomish Cloaking Device",
            [7189] = "Goblin Rocket Fuel",
            [9269] = "Gnomish Universal Remote",
            [12590] = "Felcloth Hood",
            [19567] = "Salt Shaker",
            
            -- Mechanical Squirrel Box & Trinkets
            [4068] = "Mechanical Squirrel Box",
            [10720] = "Gnomish Net-o-Matic Projector",
            
            -- Ammunition
            [3930] = "Rough Copper Bomb",
            [3931] = "Coarse Dynamite",
            [3932] = "Target Dummy",
            [4852] = "Flash Powder",
            [12543] = "Hi-Explosive Bomb",
            [19791] = "Thorium Widget",
            
            -- Advanced Engineering
            [23071] = "Truesilver Transformer",
            [23077] = "Gyrofreeze Ice Reflector",
            [23081] = "Powerful Seaforium Charge",
            [26011] = "Tranquil Mechanical Yeti",
            [26416] = "Small Blue Rocket",
            [26417] = "Small Green Rocket",
            [26418] = "Small Red Rocket"
        }
    },

    -- ========================================
    -- ========================================
    -- LEATHERWORKING (ID: 165) - COMPREHENSIVE
    -- ========================================
    [165] = {
        name = "Leatherworking",
        recipes = {
            -- Dragonscale Leatherworking
            [10650] = "Dragonscale Breastplate",
            [10619] = "Dragonscale Gauntlets",
            [10621] = "Dragonscale Leggings",
            [10651] = "Dragonscale Cloak",
            [19047] = "Black Dragonscale Breastplate",
            [19048] = "Black Dragonscale Leggings",
            [19049] = "Black Dragonscale Boots",
            [19050] = "Black Dragonscale Shoulders",
            [19085] = "Wicked Leather Gauntlets",
            [19086] = "Wicked Leather Bracers",
            [19087] = "Wicked Leather Headband",
            [19088] = "Wicked Leather Pants",
            [19089] = "Wicked Leather Armor",
            
            -- Tribal Leatherworking
            [10482] = "Frostsaber Tunic",
            [10487] = "Iceclaw Cloak",
            [10499] = "Stormcloth Headband",
            [10508] = "Frostsaber Leggings",
            [10509] = "Frostsaber Boots",
            [19059] = "Volcanic Leggings",
            [19060] = "Volcanic Breastplate",
            [19061] = "Living Shoulders",
            [19062] = "Living Leggings",
            [19063] = "Living Breastplate",
            [19064] = "Ironfeather Breastplate",
            [19065] = "Ironfeather Shoulders",
            [19066] = "Frostsaber Boots",
            [19067] = "Frostsaber Gloves",
            
            -- Elemental Leatherworking
            [19068] = "Warbear Harness",
            [19071] = "Warbear Woolies",
            [19072] = "Chromatic Gauntlets",
            [19073] = "Chromatic Cloak",
            [19074] = "Chromatic Leggings",
            [19075] = "Chimeric Gloves",
            [19076] = "Chimeric Boots",
            [19077] = "Chimeric Leggings",
            [19078] = "Chromatic Boots",
            
            -- Leather Armor Sets
            [2160] = "Embossed Leather Vest",
            [2161] = "Embossed Leather Pants",
            [2162] = "Embossed Leather Boots",
            [2163] = "Embossed Leather Cloak",
            [3753] = "Handstitched Leather Vest",
            [3756] = "Handstitched Leather Pants",
            [3759] = "Handstitched Leather Boots",
            [3761] = "Handstitched Leather Bracers",
            [7135] = "Barbaric Shoulders",
            [7147] = "Guardian Pants",
            [7149] = "Barbaric Leggings",
            [7151] = "Barbaric Gloves",
            [7153] = "Guardian Cloak",
            [9206] = "Dusky Boots",
            [9207] = "Dusky Belt",
            [9208] = "Dusky Bracers",
            [9196] = "Dusky Leather Leggings",
            [9197] = "Dusky Leather Armor",
            
            -- Mail Armor
            [3818] = "Rough Leather Vest",
            [3816] = "Rough Leather Pants",
            [3817] = "Rough Leather Boots",
            [3780] = "Rough Leather Belt",
            [7126] = "Rugged Leather",
            [17721] = "Primal Leggings",
            [17722] = "Corehound Boots",
            [17723] = "Molten Helm",
            [17724] = "Green Dragonscale Leggings",
            [17725] = "Blue Dragonscale Leggings",
            
            -- Bags & Utility
            [3957] = "Knapsack",
            [14930] = "Runecloth Bag",
            [14932] = "Imbued Netherweave Bag",
            [7028] = "Rugged Leather",
            [20648] = "Medium Leather",
            [20649] = "Heavy Leather",
            [20650] = "Thick Leather",
            [20974] = "Rugged Hide",
            
            -- Cloaks & Accessories
            [2159] = "Fine Leather Belt",
            [2158] = "Fine Leather Gloves",
            [2157] = "Fine Leather Boots",
            [2156] = "Fine Leather Pants",
            [2153] = "Fine Leather Tunic",
            [9065] = "Light Leather Bracers",
            [9074] = "Nimble Leather Gloves",
            [9145] = "Fletcher's Gloves",
            [9146] = "Herbalist's Gloves",
            [9147] = "Wicked Leather Bracers",
            [2166] = "Leather Cloak"
        }
    },

    -- ========================================
    -- TAILORING (ID: 197) - COMPREHENSIVE
    -- ========================================
    [197] = {
        name = "Tailoring",
        recipes = {
            -- Mooncloth Items
            [18401] = "Mooncloth",
            [18409] = "Mooncloth Vest",
            [18413] = "Mooncloth Robe",
            [18415] = "Mooncloth Bag",
            [18417] = "Mooncloth Shoulders",
            [18418] = "Mooncloth Circlet",
            [18419] = "Felcloth Hood",
            [18420] = "Brightcloth Robe",
            [18425] = "Felcloth Robe",
            [18426] = "Ghostweave Vest",
            [18423] = "Felcloth Gloves",
            [18424] = "Felcloth Shoulders",
            [18427] = "Felcloth Pants",
            [18428] = "Robe of Winter Night",
            [18429] = "Felcloth Boots",
            [18430] = "Cindercloth Vest",
            [18431] = "Cindercloth Robe",
            [18440] = "Cindercloth Gloves",
            [18432] = "Cindercloth Cloak",
            [18442] = "Felcloth Hood",
            [18444] = "Runecloth Pants",
            [18445] = "Runecloth Boots",
            [18446] = "Runecloth Robe",
            [18447] = "Runecloth Gloves",
            [18448] = "Runecloth Headband",
            [18449] = "Runecloth Shoulders",
            [18450] = "Wizardweave Leggings",
            [18451] = "Wizardweave Robe",
            [18452] = "Wizardweave Turban",
            
            -- Shadoweave Specialization
            [26403] = "Shadoweave Mask",
            [26407] = "Shadoweave Robe",
            [26408] = "Shadoweave Boots",
            [26409] = "Shadow Hood",
            
            -- Spellfire Specialization
            [26279] = "Spellfire Robe",
            [26280] = "Spellfire Belt",
            [26281] = "Spellfire Gloves",
            [26282] = "Spellfire Bag",
            
            -- Primal Mooncloth Specialization
            [26751] = "Primal Mooncloth",
            [26752] = "Primal Mooncloth Belt",
            [26753] = "Primal Mooncloth Shoulders",
            [26754] = "Primal Mooncloth Robe",
            
            -- Bags
            [4292] = "Woolen Bag",
            [4293] = "Silk Bag",
            [4294] = "Linen Bag",
            [8799] = "Runecloth Bag",
            [12059] = "Mageweave Bag",
            [14046] = "Runecloth Bag",
            [14155] = "Mooncloth Bag",
            [18405] = "Belt Pouch",
            [21154] = "Festive Red Pant Suit",
            [21160] = "Festival Dress",
            
            -- Robes & Clothing
            [2385] = "Brown Linen Vest",
            [2386] = "Linen Boots",
            [2387] = "Linen Belt",
            [2389] = "Linen Cloak",
            [2963] = "Barbaric Loincloth",
            [3758] = "Barbaric Cloth Vest",
            [3839] = "Barbaric Cloth Robe",
            [3840] = "Barbaric Cloth Boots",
            [3841] = "Woolen Cape",
            [3842] = "Woolen Boots",
            [3843] = "Thick Cloth Vest",
            [3844] = "Thick Cloth Pants",
            [3845] = "Reinforced Woolen Shoulders",
            [3847] = "Bright Yellow Shirt",
            [3848] = "White Linen Shirt",
            [7623] = "White Swashbuckler's Shirt",
            [7624] = "Green Holiday Shirt",
            [8465] = "Mageweave Gloves",
            [8467] = "Shadoweave Mask",
            [8782] = "Truefaith Vestments",
            [10030] = "Shadoweave Shoulders",
            [10033] = "Red Mageweave Vest",
            [10034] = "Tuxedo Jacket",
            [10035] = "Tuxedo Pants",
            [10036] = "Formal White Shirt",
            [12044] = "Simple Dress",
            [12045] = "Simple Kilt",
            [12046] = "Simple Blouse",
            [12047] = "Red Linen Shirt",
            [12048] = "Blue Linen Vest",
            [12049] = "Blue Overalls",
            [12050] = "Brown Linen Pants",
            [12051] = "Green Woolen Vest",
            [12052] = "Red Woolen Boots",
            [12053] = "Azure Shoulders",

            
            -- High-End Robes
            [14153] = "Robe of the Archmage",
            [14154] = "Truefaith Vestments",
            [18416] = "Mooncloth Leggings",
            
            -- Cloaks and Cindercloth
            [18421] = "Cloak of Warding",
            [18422] = "Cloak of Fire",
            [18434] = "Cindercloth Pants",
            [18436] = "Robe of Winter Night",
            [18438] = "Cindercloth Gloves",
            [18439] = "Cindercloth Cloak",
            [18441] = "Cindercloth Vest"
        },
    },

    -- ========================================
    -- COOKING (ID: 185)
    -- ========================================
    [185] = {
        name = "Cooking",
        recipes = {
            -- High-End Cooking
            [18247] = "Runn Tum Tuber Surprise",
            [18245] = "Tender Wolf Steak",
            [18246] = "Grilled Squid",
            [15915] = "Dragonbreath Chili",
            [15906] = "Charred Bear Kabobs",
            [15910] = "Heavy Kodo Stew",
            
            -- Standard Cooking
            [2795] = "Beer Basted Boar Ribs",
            [2797] = "Cooked Crab Claw",
            [3370] = "Crocolisk Steak",
            [3371] = "Crocolisk Gumbo",
            [4094] = "Barbecued Buzzard Wing",
            [15853] = "Smooth Raptor Stew",
            [20626] = "Undermine Clam Chowder",
            [21175] = "Spider Sausage"
        }
    },

    -- ========================================
    -- FIRST AID (ID: 129)
    -- ========================================
    [129] = {
        name = "First Aid",
        recipes = {
            -- Bandages
            [7928] = "Heavy Silk Bandage",
            [7929] = "Silk Bandage",
            [3275] = "Linen Bandage",
            [3276] = "Heavy Linen Bandage",
            [18629] = "Runecloth Bandage",
            [18630] = "Heavy Runecloth Bandage",
            
            -- Anti-Venoms
            [7934] = "Anti-Venom",
            [7935] = "Strong Anti-Venom"
        }
    },

    -- ========================================
    -- FISHING (ID: 356) - GATHERING PROFESSION
    -- ========================================
    [356] = {
        name = "Fishing",
        recipes = {
            -- Fish Gathering (no recipes, but tracking fish types for completeness)
            -- Fishing doesn't have traditional "recipes" but we can track special catches
            [7738] = "Stonescale Eel", -- High-level fish
            [13888] = "Darkclaw Lobster",
            [13889] = "Raw Redgill",
            [13893] = "Large Raw Mightfish",
            [21071] = "Raw Sagefish",
            [8365] = "Raw Mithril Head Trout",
            [6522] = "Deviate Fish",
            [6643] = "Bloated Smallfish",
            [21153] = "Raw Greater Sagefish"
        }
    },

    -- ========================================
    -- HERBALISM (ID: 182) - GATHERING PROFESSION  
    -- ========================================
    [182] = {
        name = "Herbalism",
        recipes = {
            -- Herb Gathering (no recipes, but tracking herbs for completeness)
            [2447] = "Peacebloom",
            [765] = "Silverleaf", 
            [2449] = "Earthroot",
            [785] = "Mageroyal",
            [2450] = "Briarthorn",
            [3820] = "Stranglekelp",
            [2453] = "Bruiseweed",
            [3369] = "Grave Moss",
            [3356] = "Kingsblood",
            [3357] = "Liferoot",
            [3821] = "Goldthorn",
            [3358] = "Khadgar's Whisker",
            [3819] = "Wintersbite",
            [4625] = "Firebloom",
            [8831] = "Purple Lotus",
            [8836] = "Arthas' Tears",
            [8838] = "Sungrass",
            [8839] = "Blindweed",
            [8845] = "Ghost Mushroom",
            [8846] = "Gromsblood",
            [13464] = "Golden Sansam",
            [13465] = "Mountain Silversage",
            [13466] = "Sorrowmoss",
            [13467] = "Icecap",
            [13468] = "Black Lotus"
        }
    },

    -- ========================================
    -- MINING (ID: 186) - GATHERING PROFESSION
    -- ========================================  
    [186] = {
        name = "Mining",
        recipes = {
            -- Smelting recipes (this is what miners actually "craft")
            [2657] = "Smelt Copper",
            [2658] = "Smelt Tin", 
            [3307] = "Smelt Bronze",
            [2659] = "Smelt Silver",
            [3308] = "Smelt Iron",
            [3569] = "Smelt Gold",
            [10097] = "Smelt Mithril",
            [10098] = "Smelt Truesilver",
            [16153] = "Smelt Dark Iron",
            [22967] = "Smelt Thorium",
            [29686] = "Smelt Elementium",
            
            -- Ore tracking for gathering
            [2770] = "Copper Ore",
            [2771] = "Tin Ore",
            [2772] = "Iron Ore", 
            [2775] = "Silver Ore",
            [2776] = "Gold Ore",
            [3858] = "Mithril Ore",
            [7911] = "Truesilver Ore",
            [10620] = "Thorium Ore",
            [11370] = "Dark Iron Ore",
            [12365] = "Dense Stone",
            [11382] = "Blood of the Mountain"
        }
    },

    -- ========================================
    -- SKINNING (ID: 393) - GATHERING PROFESSION
    -- ========================================
    [393] = {
        name = "Skinning", 
        recipes = {
            -- Leather processing/skinning (no recipes but tracking leather types)
            [2318] = "Light Leather",
            [2319] = "Medium Leather", 
            [4234] = "Heavy Leather",
            [4304] = "Thick Leather",
            [8170] = "Rugged Leather",
            [17012] = "Core Leather",
            [15408] = "Heavy Scorpid Scale",
            [8154] = "Scorpid Scale",
            [7392] = "Green Whelp Scale",
            [7286] = "Black Whelp Scale",
            [8165] = "Worn Dragonscale",
            [15412] = "Green Dragonscale",
            [15414] = "Red Dragonscale", 
            [15415] = "Blue Dragonscale",
            [15416] = "Black Dragonscale",
            [12607] = "Brilliant Chromatic Scale",
            [15417] = "Devilsaur Leather",
            [19767] = "Primal Bat Leather",
            [19768] = "Primal Tiger Leather"
        }
    }
}

-- Category mappings - These provide additional compression for common patterns
VanillaData.CATEGORY_NAMES = {
    [1] = "Flask",
    [2] = "Transmute", 
    [3] = "Healing Potion",
    [4] = "Mana Potion",
    [5] = "Elixir",
    [6] = "Weapon",
    [7] = "Armor",
    [8] = "Enchant",
    [9] = "Bandage",
    [10] = "Anti-Venom",
    [11] = "Cloak",
    [12] = "Robe",
    [13] = "Leather Set",
    [14] = "Engineering Device",
    [15] = "Food"
}

-- Type mappings for further compression
VanillaData.TYPE_NAMES = {
    [1] = "Superior",
    [2] = "Greater", 
    [3] = "Lesser",
    [4] = "Major",
    [5] = "Minor",
    [6] = "Heavy",
    [7] = "Ornate",
    [8] = "Enchanted",
    [9] = "Mooncloth",
    [10] = "Runic",
    [11] = "Wicked",
    [12] = "Cindercloth"
}

-- Create backward compatibility table (flattened view)
VanillaData.SPELL_TO_RECIPE = {}

-- Populate the flattened table from organized data for backward compatibility
for professionId, professionData in pairs(VanillaData.RECIPES_BY_PROFESSION) do
    for spellId, recipeName in pairs(professionData.recipes) do
        VanillaData.SPELL_TO_RECIPE[spellId] = recipeName
    end
end

-- Export to global namespace for addon usage
CraftersBoard_VanillaData = VanillaData

return VanillaData
