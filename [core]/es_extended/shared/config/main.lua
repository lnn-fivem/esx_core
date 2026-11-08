-- ============================================================
--  ESX Core (Optimized by LNN) — Main Configuration
-- ============================================================

Config = {}

-- For ox inventory, this will automatically be adjusted, do not change! For other inventories, change to "resource_name"
Config.CustomInventory = false

Config.Locale = GetConvar("esx:locale", "en")
-- Fall back to English for keys missing in the active locale. Set to false or
-- `setr esx:localeFallback false` in server.cfg to surface missing keys instead.
Config.LocaleFallback = GetConvar("esx:localeFallback", "true") ~= "false"

Config.Accounts = {
    bank = {
        label = TranslateCap("account_bank"),
        round = true,
    },
    black_money = {
        label = TranslateCap("account_black_money"),
        round = true,
    },
    money = {
        label = TranslateCap("account_money"),
        round = true,
    },
}

Config.StartingAccountMoney = { bank = 50000 }

Config.StartingInventoryItems = false -- table/false

Config.DefaultSpawns = { -- If you want to have more spawn positions and select them randomly uncomment commented code or add more locations
    { x = 222.2027, y = -864.0162, z = 30.2922, heading = 1.0 },
    --{x = 224.9865, y = -865.0871, z = 30.2922, heading = 1.0},
    --{x = 227.8436, y = -866.0400, z = 30.2922, heading = 1.0},
    --{x = 230.6051, y = -867.1450, z = 30.2922, heading = 1.0},
    --{x = 233.5459, y = -868.2626, z = 30.2922, heading = 1.0}
}

-- Reject saved/live coordinates outside the playable map bounds and fall back to earlier valid coords or DefaultSpawns.
Config.PlayerCoordinateLimit = 10000.0

-- Ordering goes from lowest to highest permission (user is always lowest and Automatically Added)
Config.AdminGroups = {
    "mod",
    "admin",
}

--[[
    Command group permissions (Exact Groups Execution - NOT inherited from Config.AdminGroups)

    - Keys represent command names (without the slash)
    - Values are arrays of group names allowed to execute the command
    - Modify as needed to customize command access on your server
--]]
Config.CommandPermissions = {
    setcoords = { "admin" },
    tp = { "admin" },
    setjob = { "admin", "mod" },
    car = { "admin" },
    cardel = { "admin", "mod" },
    dv = { "admin", "mod" },
    fix = { "admin" },
    repair = { "admin" },
    setaccountmoney = { "admin" },
    giveaccountmoney = { "admin" },
    removeaccountmoney = { "admin" },
    giveitem = { "admin" },
    giveweapon = { "admin" },
    giveammo = { "admin" },
    giveweaponcomponent = { "admin" },
    clear = { "user", "mod", "admin" },
    cls = { "user", "mod", "admin" },
    clearall = { "admin" },
    clsall = { "admin" },
    refreshjobs = { "admin" },
    refreshitems = { "admin" },
    clearinventory = { "admin", "mod" },
    clearloadout = { "admin", "mod" },
    setgroup = { "admin" },
    save = { "admin" },
    saveall = { "admin" },
    group = { "user", "mod", "admin" },
    job = { "user", "mod", "admin" },
    info = { "user", "mod", "admin" },
    playtime = { "user", "mod", "admin" },
    coords = { "admin" },
    tpm = { "admin", "mod" },
    ["goto"] = { "admin", "mod" },
    bring = { "admin", "mod" },
    kill = { "admin" },
    freeze = { "admin", "mod" },
    unfreeze = { "admin", "mod" },
    noclip = { "admin", "mod" },
    players = { "admin" },
    setdim = { "admin" },
    setbucket = { "admin" },
}

Config.EnablePaycheck = true -- enable paycheck
Config.LogPaycheck = false -- Logs paychecks to a nominated Discord channel via webhook (default is false)
Config.EnableSocietyPayouts = false -- pay from the society account that the player is employed at? Requirement: esx_society
Config.MaxWeight = 24 -- the max inventory weight without a backpack
Config.PaycheckInterval = 7 * 60000 -- how often to receive paychecks in milliseconds
Config.DefaultJobDuty = true -- A players default duty status when changing jobs
Config.OffDutyPaycheckMultiplier = 0.5 -- The multiplier for off duty paychecks. 0.5 = 50% of the on duty paycheck

Config.EnableDebug = false -- Use Debug options?

Config.Multichar = GetResourceState("esx_multicharacter") ~= "missing"
Config.Identity = true -- Select a character identity data before they have loaded in (this happens by default with multichar)
Config.DistanceGive = 4.0 -- Max distance when giving items, weapons etc.

Config.AdminLogging = false -- Logs the usage of certain commands by those with group.admin ace permissions (default is false)

-- ============================================================
--  LNN Optimization Settings (Dirty-Tracking & Batch Save)
-- ============================================================
Config.SaveInterval = 5 * 60000 -- Interval in ms to batch-save dirty players (default: 5 minutes)
Config.SaveBatchSize = 100 -- Number of players per MySQL.prepare.await batch
Config.SaveSerializeChunk = 50 -- Number of players serialized per server frame before Wait(0)
Config.SaveProgressMinPlayers = 200 -- Minimum player count to print progress percentages during save
Config.SaveProgressStep = 20 -- Progress log step percentage
Config.HealthSampleInterval = 30000 -- Interval in ms to sample live health & armor into metadata (0 to disable)

-- ============================================================
--   DO NOT CHANGE BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING
-- ============================================================
Config.EnableDefaultInventory = Config.CustomInventory == false -- Display the default Inventory ( F2 )
Config.Identifier = GetConvar("esx:identifier", "steam")

Config.SpawnVehMaxUpgrades = true -- admin vehicles spawn with max vehicle settings
