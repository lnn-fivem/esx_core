ESX.Players = {}
ESX.Jobs = {}
ESX.Items = {}

Core = {}
Core.JobsPlayerCount = {}
Core.UsableItemsCallbacks = {}
Core.RegisteredCommands = {}
Core.Pickups = {}
Core.PickupId = 0
Core.PlayerFunctionOverrides = {}
Core.DatabaseConnected = false
Core.playersByIdentifier = {}
Core.playersByJob = {}
Core.JobsLoaded = false

Core.vehicles = {}
Core.vehicleTypesByModel = {}

GlobalState.playerCount = 0

RegisterNetEvent("esx:onPlayerSpawn", function()
    local xPlayer = ESX.Players[source]
    if xPlayer then
        xPlayer.spawned = true
    end
end)

if Config.OxInventory then
    Config.PlayerFunctionOverride = "OxInventory"
    SetConvarReplicated("inventory:framework", "esx")
    SetConvarReplicated("inventory:weight", tostring(Config.MaxWeight * 1000))
end

local catalogService = nil

local function getCatalogService()
    if catalogService ~= nil then
        return catalogService
    end

    if GetResourceState("esx_lib") == "missing" then
        catalogService = false
        return false
    end

    local source = LoadResourceFile("esx_lib", "imports/catalog/server.lua")
    local dataSource = LoadResourceFile("esx_lib", "imports/catalog/data.json")
    if not source or not dataSource then
        catalogService = false
        return false
    end

    local okChunk, chunk = pcall(load, source, "@@esx_lib/imports/catalog/server.lua", "t", _ENV)
    local okData, data = pcall(json.decode, dataSource)
    if not okChunk or not chunk or not okData or type(data) ~= "table" then
        catalogService = false
        return false
    end

    local okCat, catalog = pcall(chunk)
    if not okCat or type(catalog) ~= "table" or not catalog.service then
        catalogService = false
        return false
    end

    catalogService = catalog.service(MySQL, data, function(result)
        if Core.DatabaseConnected and result and result.catalogs then
            if (result.catalogs.jobs or result.catalogs.job_grades) and ESX.RefreshJobs then
                ESX.RefreshJobs()
            end
        end
        TriggerEvent("esx:sqlCatalogReady", result and result.catalogs or {})
    end)

    return catalogService
end

exports("EnsureSqlCatalog", function(name, locale)
    locale = type(locale) == "string" and locale or (Config.Locale or "en")
    local reconcile = getCatalogService()
    if reconcile then
        while not Core.DatabaseConnected do
            Wait(50)
        end
        local ok, res = pcall(reconcile, name, locale)
        if ok and type(res) == "table" then
            return res
        end
    end

    return {
        imported = 0,
        locale = locale,
        changed = {},
        catalogs = {},
    }
end)

MySQL.ready(function()
    Core.DatabaseConnected = true
    local reconcile = getCatalogService()
    if reconcile then
        pcall(reconcile, GetCurrentResourceName(), Config.Locale or "en")
    end
    ESX.RefreshItems()
    ESX.RefreshJobs()

    print(("^0[^2INFO^0] ESX ^5Optimized by LNN %s^0 initialized!"):format(GetResourceMetadata(GetCurrentResourceName(), "version", 0)))

    StartDBSync()
    StartHealthSampler()
    if Config.EnablePaycheck then
        StartPayCheck()
    end
end)

RegisterNetEvent("esx:clientLog", function(msg)
    if Config.EnableDebug then
        print(("[^2TRACE^7] %s^7"):format(msg))
    end
end)

RegisterNetEvent("esx:ReturnVehicleType", function(Type, Request)
    if Core.ClientCallbacks[Request] then
        Core.ClientCallbacks[Request](Type)
        Core.ClientCallbacks[Request] = nil
    end
end)

AddEventHandler("txAdmin:events:scheduledRestart", function(eventData)
    if eventData.secondsRemaining == 60 then
        CreateThread(function()
            Wait(50000)
            Core.SavePlayers()
        end)
    end
end)

AddEventHandler("txAdmin:events:serverShuttingDown", function()
    Core.SavePlayers()
end)

local DoNotUse = {
    ["essentialmode"] = true,
    ["es_admin2"] = true,
    ["basic-gamemode"] = true,
    ["mapmanager"] = true,
    ["fivem-map-skater"] = true,
    ["fivem-map-hipster"] = true,
    ["qb-core"] = true,
    ["default_spawnpoint"] = true,
}

AddEventHandler("onResourceStart", function(key)
    if DoNotUse[string.lower(key)] then
        while GetResourceState(key) ~= "started" do
            Wait(0)
        end

        StopResource(key)
        error(("WE STOPPED A RESOURCE THAT WILL BREAK ^1ESX^1, PLEASE REMOVE ^5%s^1"):format(key))
    end
end)

for key in pairs(DoNotUse) do
    if GetResourceState(key) == "started" or GetResourceState(key) == "starting" then
        StopResource(key)
        error(("WE STOPPED A RESOURCE THAT WILL BREAK ^1ESX^1, PLEASE REMOVE ^5%s^1"):format(key))
    end
end
