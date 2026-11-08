function ESX.RegisterUsableItem(item, cb)
    Core.UsableItemsCallbacks[item] = cb
end

function ESX.UseItem(source, item, ...)
    if ESX.Items[item] then
        local itemCallback = Core.UsableItemsCallbacks[item]

        if itemCallback then
            local success, result = pcall(itemCallback, source, item, ...)

            if not success then
                return print(result and result or ("An error occured when using item ^5\"%s\"^7! This was not caused by ESX."):format(item))
            end
        end
    else
        print(("[^3WARNING^7] Item ^5\"%s\"^7 was used, but does not exist!"):format(item))
    end
end

function ESX.GetItemLabel(item)
    if Config.OxInventory then
        item = exports.ox_inventory:Items(item)
        if item then
            return item.label
        end
    end

    if not ESX.Items[item] then
        print(("[^3WARNING^7] Attemting to get invalid Item -> ^5%s^7"):format(item))
        return
    end

    return ESX.Items[item].label
end

function ESX.GetItems()
    return ESX.Items
end

function ESX.GetUsableItems()
    local Usables = {}
    for k in pairs(Core.UsableItemsCallbacks) do
        Usables[k] = true
    end
    return Usables
end

local function refreshPlayerInventories()
    for _, xPlayer in pairs(ESX.Players) do
        if xPlayer then
            local inventory = {}
            local weight = 0

            for _, item in ipairs(xPlayer.inventory) do
                local tpl = ESX.Items[item.name]
                if tpl and item.count > 0 then
                    weight = weight + (tpl.weight * item.count)
                    inventory[#inventory + 1] = {
                        name = item.name,
                        count = item.count,
                        label = tpl.label,
                        weight = tpl.weight,
                        limit = tpl.limit or -1,
                        usable = Core.UsableItemsCallbacks[item.name] ~= nil,
                        rare = tpl.rare,
                        canRemove = tpl.canRemove,
                    }
                end
            end

            table.sort(inventory, function(a, b)
                return a.label < b.label
            end)

            xPlayer.inventory = inventory
            xPlayer.weight = weight

            xPlayer.triggerEvent("esx:setInventory", inventory)
            xPlayer.triggerEvent("esx:updatePlayerData", "inventory", inventory)
            xPlayer.triggerEvent("esx:updatePlayerData", "weight", weight)
        end
    end
end

function ESX.RefreshItems()
    if Config.OxInventory then
        ESX.Items = exports.ox_inventory:Items()
        return
    end

    local rawFile = LoadResourceFile(GetCurrentResourceName(), "shared/config/items.lua")
    local itemsTable = Config.Items
    if rawFile then
        local env = setmetatable({ Config = {} }, { __index = _G })
        local fn, err = load(rawFile, "@shared/config/items.lua", "t", env)
        if fn then
            local ok, res = pcall(fn)
            if ok then
                itemsTable = type(res) == "table" and res or env.Config.Items
                Config.Items = itemsTable
            else
                print(("[^1ERROR^7] Failed executing shared/config/items.lua: %s"):format(tostring(res)))
            end
        else
            print(("[^1ERROR^7] Syntax error in shared/config/items.lua: %s"):format(tostring(err)))
        end
    end

    ESX.Table.Wipe(ESX.Items)

    for name, v in pairs(itemsTable or {}) do
        ESX.Items[name] = {
            name = name,
            label = v.label or name,
            weight = tonumber(v.weight) or 0,
            limit = tonumber(v.limit) or -1,
            rare = v.rare == true or v.rare == 1,
            canRemove = v.canRemove == nil and true or (v.canRemove == true or v.canRemove == 1),
        }
    end

    if next(ESX.Players) ~= nil then
        refreshPlayerInventories()
    end

    TriggerEvent("esx:itemsRefreshed", ESX.Items)
end

---@param items table<string, { label: string, weight?: number, limit?: number, rare?: boolean, canRemove?: boolean }>
function ESX.AddItems(items)
    if type(items) ~= "table" then
        return false
    end

    for name, v in pairs(items) do
        local entry = {
            name = name,
            label = v.label or name,
            weight = tonumber(v.weight) or 0,
            limit = tonumber(v.limit) or -1,
            rare = v.rare == true or v.rare == 1,
            canRemove = v.canRemove == nil and true or (v.canRemove == true or v.canRemove == 1),
        }
        ESX.Items[name] = entry
        if Config.Items then
            Config.Items[name] = entry
        end
    end

    return true
end

if not Config.CustomInventory then
    function ESX.CreatePickup(itemType, name, count, label, playerId, components, tintIndex, coords)
        local pickupId = (Core.PickupId == 65635 and 0 or Core.PickupId + 1)
        local xPlayer = ESX.Players[playerId]
        coords = ((type(coords) == "vector3" or type(coords) == "vector4") and coords.xyz or xPlayer.getCoords(true))

        Core.Pickups[pickupId] = {
            type = itemType,
            name = name,
            count = count,
            label = label,
            coords = coords,
        }

        if itemType == "item_weapon" then
            Core.Pickups[pickupId].components = components
            Core.Pickups[pickupId].tintIndex = tintIndex
        end

        TriggerClientEvent("esx:createPickup", -1, pickupId, label, coords, itemType, name, components, tintIndex)
        Core.PickupId = pickupId
    end
end
