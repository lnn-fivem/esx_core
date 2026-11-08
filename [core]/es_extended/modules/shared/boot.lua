ESX = {}

exports("getSharedObject", function()
    return ESX
end)

AddEventHandler("esx:getSharedObject", function(cb)
    if ESX.IsFunctionReference(cb) then
        cb(ESX)
    end
end)

if GetResourceState("ox_inventory") ~= "missing" then
    Config.CustomInventory = "ox"
end

Config.OxInventory = Config.CustomInventory == "ox"
