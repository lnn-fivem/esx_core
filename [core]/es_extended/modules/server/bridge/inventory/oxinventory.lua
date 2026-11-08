if not Config.OxInventory then
    return
end

local function setPlayerInventory(playerId, xPlayer, inventory, isNew)
    exports.ox_inventory:setPlayerInventory(xPlayer, inventory)

    if isNew then
        local shared = json.decode(GetConvar("inventory:accounts", '["money"]'))

        for i = 1, #shared do
            local name = shared[i]
            local account = Config.StartingAccountMoney[name]
            if account then
                exports.ox_inventory:AddItem(playerId, name, account)
            end
        end
    end
end

AddEventHandler("esx:jobsLoaded", function(jobs)
    exports.ox_inventory:setupGroups(jobs)
end)

exports("setPlayerInventory", setPlayerInventory)
