-- ============================================================
--  ESX Core (Optimized by LNN) — Item Definitions
-- ============================================================
--  Define all server items here instead of querying the SQL `items` table.
--  Supports both weight-based (weight) and limit-based (limit) systems:
--    • label:     Display name of the item
--    • weight:    Weight per unit (used when checking Config.MaxWeight)
--    • limit:     Max stack count per player (-1 = unlimited)
--    • rare:      Rare item flag (default: false)
--    • canRemove: Whether the item can be dropped/given (default: true)
-- ============================================================

Config.Items = {
    ["bread"] = {
        label = "Bread",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["water"] = {
        label = "Water",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["phone"] = {
        label = "Phone",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["radio"] = {
        label = "Radio",
        weight = 2,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["bandage"] = {
        label = "Bandage",
        weight = 2,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["medikit"] = {
        label = "Medikit",
        weight = 2,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["armour"] = {
        label = "Bulletproof Vest",
        weight = 3,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["alive_chicken"] = {
        label = "Living chicken",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["Slaughtered_chicken"] = {
        label = "Slaughtered chicken",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["packaged_chicken"] = {
        label = "Chicken fillet",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["fish"] = {
        label = "Fish",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["stone"] = {
        label = "Stone",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["washed_stone"] = {
        label = "Washed stone",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["copper"] = {
        label = "Copper",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["iron"] = {
        label = "Iron",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["gold"] = {
        label = "Gold",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["diamond"] = {
        label = "Diamond",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["wood"] = {
        label = "Wood",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["cutted_wood"] = {
        label = "Cut wood",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["packaged_plank"] = {
        label = "Packaged wood",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["petrol"] = {
        label = "Oil",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["petrol_raffin"] = {
        label = "Processed oil",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["essence"] = {
        label = "Gas",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["wool"] = {
        label = "Wool",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["fabric"] = {
        label = "Fabric",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["clothe"] = {
        label = "Cloth",
        weight = 1,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["blowpipe"] = {
        label = "Blowtorch",
        weight = 2,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["carokit"] = {
        label = "Body Kit",
        weight = 3,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["carotool"] = {
        label = "Tools",
        weight = 2,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["fixkit"] = {
        label = "Repair Kit",
        weight = 3,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["fixtool"] = {
        label = "Repair Tools",
        weight = 2,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["gazbottle"] = {
        label = "Gas Bottle",
        weight = 2,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["marijuana"] = {
        label = "Marijuana",
        weight = 2,
        limit = -1,
        rare = false,
        canRemove = true,
    },
    ["cannabis"] = {
        label = "Cannabis",
        weight = 3,
        limit = -1,
        rare = false,
        canRemove = true,
    },
}

return Config.Items
