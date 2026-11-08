local isDead = false
local pickups = {}

local function applyPlayerDataCoordsMetatable()
    setmetatable(ESX.PlayerData, {
        __index = function(self, key)
            if key ~= "coords" then
                return
            end

            local ped = self.ped
            local validPed = ped and ped ~= 0 and DoesEntityExist(ped) and ped or PlayerPedId()
            if validPed and validPed ~= 0 and DoesEntityExist(validPed) then
                return GetEntityCoords(validPed)
            end
        end,
    })
end

function Core.FreezePlayer(ped, freeze)
    local player = PlayerId()
    SetPlayerControl(player, not freeze, false)

    if freeze then
        SetEntityCollision(ped, false, false)
        FreezeEntityPosition(ped, true)
    else
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)
    end
end

local function SetVehicleProperties(vehicle, props)
    if DoesEntityExist(vehicle) then
        ESX.Game.SetVehicleProperties(vehicle, props)
    end
end

AddStateBagChangeHandler("VehicleProperties", nil, function(bagName, _, value)
    if not value then
        return
    end

    local netId = tonumber(bagName:gsub("entity:", ""), 10)
    if not netId then
        return
    end

    local entity = NetToVeh(netId)
    local tries = 0

    while not DoesEntityExist(entity) and tries < 100 do
        Wait(50)
        entity = NetToVeh(netId)
        tries = tries + 1
    end

    if DoesEntityExist(entity) and NetworkGetEntityOwner(entity) == PlayerId() then
        SetVehicleProperties(entity, value)
    end
end)

RegisterNetEvent("esx:itemsRefreshed", function(items)
    if type(items) == "table" then
        ESX.Items = items
    end
end)

RegisterNetEvent("esx:playerLoaded", function(xPlayer, isNew, skin)
    ESX.PlayerData = xPlayer
    applyPlayerDataCoordsMetatable()

    if not Config.Multichar then
        Core.FreezePlayer(PlayerPedId(), true)
        ESX.Game.Teleport(PlayerPedId(), {
            x = xPlayer.coords.x,
            y = xPlayer.coords.y,
            z = xPlayer.coords.z + 0.25,
            heading = xPlayer.coords.heading,
        }, function()
            TriggerServerEvent("esx:onPlayerSpawn")
            TriggerEvent("esx:onPlayerSpawn")
            TriggerEvent("esx:restoreLoadout")
            TriggerEvent("playerSpawned")

            Wait(4000)
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
            Core.FreezePlayer(PlayerPedId(), false)
            DoScreenFadeIn(1000)
        end)
    end

    while not DoesEntityExist(PlayerPedId()) do
        Wait(20)
    end

    ESX.PlayerLoaded = true

    local timer = GetGameTimer()
    while not HaveAllStreamingRequestsCompleted(PlayerPedId()) and (GetGameTimer() - timer) < 2000 do
        Wait(0)
    end

    Adjustments:Load()

    ClearPedTasksImmediately(PlayerPedId())

    if not Config.Multichar then
        local playerPed = PlayerPedId()
        SetEntityMaxHealth(playerPed, 200)
        SetEntityHealth(playerPed, xPlayer.metadata.health or 200)
        SetPedArmour(playerPed, xPlayer.metadata.armor or 0)
        if isNew then
            if skin.sex == 0 then
                TriggerEvent("skinchanger:loadDefaultModel", true)
            else
                TriggerEvent("skinchanger:loadDefaultModel", false)
            end
        elseif skin then
            TriggerEvent("skinchanger:loadSkin", skin)
        end
    end

    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
    end

    StartServerSyncLoops()
    NetworkSetLocalPlayerSyncLookAt(true)
    EnableActions()
end)

RegisterNetEvent("esx:onPlayerLogout", function()
    ESX.PlayerLoaded = false
    ESX.PlayerData = {}
end)

RegisterNetEvent("esx:setMaxWeight", function(newMaxWeight)
    ESX.SetPlayerData("maxWeight", newMaxWeight)
end)

local function onPlayerSpawn()
    ESX.SetPlayerData("ped", PlayerPedId())
    ESX.SetPlayerData("dead", false)
    isDead = false
end

AddEventHandler("playerSpawned", onPlayerSpawn)
AddEventHandler("esx:onPlayerSpawn", onPlayerSpawn)

AddEventHandler("esx:onPlayerDeath", function()
    ESX.SetPlayerData("ped", PlayerPedId())
    ESX.SetPlayerData("dead", true)
    isDead = true
end)

AddEventHandler("skinchanger:modelLoaded", function()
    while not ESX.PlayerLoaded do
        Wait(100)
    end
    TriggerEvent("esx:restoreLoadout")
end)

AddEventHandler("esx:restoreLoadout", function()
    local ammoTypes = {}
    local playerPed = PlayerPedId()
    RemoveAllPedWeapons(playerPed, true)

    for _, v in ipairs(ESX.PlayerData.loadout or {}) do
        local weaponName = v.name
        local weaponHash = joaat(weaponName)

        GiveWeaponToPed(playerPed, weaponHash, 0, false, false)
        SetPedWeaponTintIndex(playerPed, weaponHash, v.tintIndex)

        local ammoType = GetPedAmmoTypeFromWeapon(playerPed, weaponHash)

        for _, v2 in ipairs(v.components or {}) do
            local componentHash = ESX.GetWeaponComponent(weaponName, v2).hash
            GiveWeaponComponentToPed(playerPed, weaponHash, componentHash)
        end

        if not ammoTypes[ammoType] then
            AddAmmoToPed(playerPed, weaponHash, v.ammo)
            ammoTypes[ammoType] = true
        end
    end
end)

AddStateBagChangeHandler("metadata", "player:" .. tostring(GetPlayerServerId(PlayerId())), function(_, key, val)
    ESX.SetPlayerData(key, val)
end)

RegisterNetEvent("esx:setAccountMoney", function(account)
    for i = 1, #ESX.PlayerData.accounts do
        if ESX.PlayerData.accounts[i].name == account.name then
            ESX.PlayerData.accounts[i] = account
            break
        end
    end

    ESX.SetPlayerData("accounts", ESX.PlayerData.accounts)
end)

if not Config.OxInventory then
    RegisterNetEvent("esx:addInventoryItem", function(item, count, showNotification, itemData)
        local found = false
        for k, v in ipairs(ESX.PlayerData.inventory) do
            if v.name == item then
                ESX.UI.ShowInventoryItemNotification(true, v.label, count - v.count)
                ESX.PlayerData.inventory[k].count = count
                found = true
                break
            end
        end

        if not found then
            local tpl = type(itemData) == "table" and itemData or (ESX.Items and ESX.Items[item])
            local label = tpl and tpl.label or item
            local weight = tpl and tpl.weight or 0
            local limit = tpl and tpl.limit or -1
            local usable = type(itemData) == "table" and (itemData.usable == true) or false
            local rare = tpl and tpl.rare or false
            local canRemove = tpl and tpl.canRemove
            if canRemove == nil then
                canRemove = true
            end

            ESX.PlayerData.inventory[#ESX.PlayerData.inventory + 1] = {
                name = item,
                count = count,
                label = label,
                weight = weight,
                limit = limit,
                usable = usable,
                rare = rare,
                canRemove = canRemove,
            }
            table.sort(ESX.PlayerData.inventory, function(a, b)
                return a.label < b.label
            end)
            ESX.UI.ShowInventoryItemNotification(true, label, count)
        end

        if showNotification then
            local tpl = type(itemData) == "table" and itemData or (ESX.Items and ESX.Items[item])
            ESX.UI.ShowInventoryItemNotification(true, tpl and tpl.label or item, count)
        end
    end)

    RegisterNetEvent("esx:removeInventoryItem", function(item, count, showNotification)
        local itemLabel = item
        for k, v in ipairs(ESX.PlayerData.inventory) do
            if v.name == item then
                itemLabel = v.label
                local diff = v.count - count
                ESX.UI.ShowInventoryItemNotification(false, v.label, diff)
                if count > 0 then
                    ESX.PlayerData.inventory[k].count = count
                else
                    table.remove(ESX.PlayerData.inventory, k)
                end
                break
            end
        end

        if showNotification then
            ESX.UI.ShowInventoryItemNotification(false, itemLabel, count)
        end
    end)

    RegisterNetEvent("esx:addLoadoutItem", function(weaponName, weaponLabel, ammo)
        table.insert(ESX.PlayerData.loadout, {
            name = weaponName,
            ammo = ammo,
            label = weaponLabel,
            components = {},
            tintIndex = 0,
        })
    end)

    RegisterNetEvent("esx:removeLoadoutItem", function(weaponName)
        for k, v in ipairs(ESX.PlayerData.loadout) do
            if v.name == weaponName then
                table.remove(ESX.PlayerData.loadout, k)
                break
            end
        end
    end)

    RegisterNetEvent("esx:updateWeaponAmmo", function(weaponName, ammo)
        for _, v in ipairs(ESX.PlayerData.loadout) do
            if v.name == weaponName then
                v.ammo = ammo
                break
            end
        end
    end)

    RegisterNetEvent("esx:setWeaponTint", function(weapon, weaponTintIndex)
        SetPedWeaponTintIndex(ESX.PlayerData.ped, joaat(weapon), weaponTintIndex)
        for _, v in ipairs(ESX.PlayerData.loadout) do
            if v.name == weapon then
                v.tintIndex = weaponTintIndex
                break
            end
        end
    end)

    RegisterNetEvent("esx:removeWeaponComponent", function(weapon, weaponComponent)
        local componentHash = ESX.GetWeaponComponent(weapon, weaponComponent).hash
        RemoveWeaponComponentFromPed(ESX.PlayerData.ped, joaat(weapon), componentHash)
    end)
end

RegisterNetEvent("esx:setJob", function(Job)
    ESX.SetPlayerData("job", Job)
end)

RegisterNetEvent("esx:jobDataRefreshed", function(Job)
    ESX.SetPlayerData("job", Job)
end)

RegisterNetEvent("esx:setGroup", function(group)
    ESX.SetPlayerData("group", group)
end)

RegisterNetEvent("esx:updatePlayerData", function(key, val)
    ESX.SetPlayerData(key, val)
end)

RegisterNetEvent("esx:teleport", function(coords)
    ESX.Game.Teleport(ESX.PlayerData.ped, coords)
end)

RegisterNetEvent("esx:repairPedVehicle", function()
    local ped = ESX.PlayerData.ped
    local vehicle = GetVehiclePedIsIn(ped, false)
    SetVehicleEngineHealth(vehicle, 1000)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0)
end)

RegisterNetEvent("esx:freezePlayer", function(input)
    local player = PlayerId()
    if input == "freeze" then
        SetEntityCollision(ESX.PlayerData.ped, false)
        FreezeEntityPosition(ESX.PlayerData.ped, true)
        SetPlayerInvincible(player, true)
    elseif input == "unfreeze" then
        SetEntityCollision(ESX.PlayerData.ped, true)
        FreezeEntityPosition(ESX.PlayerData.ped, false)
        SetPlayerInvincible(player, false)
    end
end)

RegisterNetEvent("esx:killPlayer", function()
    SetEntityHealth(ESX.PlayerData.ped, 0)
end)

local noclip = false
local noclip_pos = vector3(0, 0, 70)
local heading = 0

local function noclipThread()
    while noclip do
        SetEntityCoordsNoOffset(ESX.PlayerData.ped, noclip_pos.x, noclip_pos.y, noclip_pos.z, 0, 0, 0)

        if IsControlPressed(1, 34) then
            heading = heading + 1.5
            if heading > 360 then
                heading = 0
            end

            SetEntityHeading(ESX.PlayerData.ped, heading)
        end

        if IsControlPressed(1, 9) then
            heading = heading - 1.5
            if heading < 0 then
                heading = 360
            end

            SetEntityHeading(ESX.PlayerData.ped, heading)
        end

        if IsControlPressed(1, 8) then
            noclip_pos = GetOffsetFromEntityInWorldCoords(ESX.PlayerData.ped, 0.0, 1.0, 0.0)
        end

        if IsControlPressed(1, 32) then
            noclip_pos = GetOffsetFromEntityInWorldCoords(ESX.PlayerData.ped, 0.0, -1.0, 0.0)
        end

        if IsControlPressed(1, 27) then
            noclip_pos = GetOffsetFromEntityInWorldCoords(ESX.PlayerData.ped, 0.0, 0.0, 1.0)
        end

        if IsControlPressed(1, 173) then
            noclip_pos = GetOffsetFromEntityInWorldCoords(ESX.PlayerData.ped, 0.0, 0.0, -1.0)
        end
        Wait(0)
    end
end

RegisterNetEvent("esx:noclip", function()
    noclip = not noclip

    if noclip then
        noclip_pos = GetEntityCoords(ESX.PlayerData.ped, false)
        heading = GetEntityHeading(ESX.PlayerData.ped)
        Core.FreezePlayer(ESX.PlayerData.ped, true)
        CreateThread(noclipThread)
    else
        Core.FreezePlayer(ESX.PlayerData.ped, false)
    end
end)

RegisterNetEvent("esx:tpm", function()
    local GetEntityCoords = GetEntityCoords
    local GetGroundZFor_3dCoord = GetGroundZFor_3dCoord
    local GetFirstBlipInfoId = GetFirstBlipInfoId
    local DoesBlipExist = DoesBlipExist
    local DoScreenFadeOut = DoScreenFadeOut
    local GetBlipInfoIdCoord = GetBlipInfoIdCoord
    local GetVehiclePedIsIn = GetVehiclePedIsIn

    local blipMarker = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blipMarker) then
        ESX.ShowNotification(TranslateCap("tpm_nowaypoint"), "error")
        return "marker"
    end

    -- Fade screen to hide how clients get teleported.
    DoScreenFadeOut(650)
    while not IsScreenFadedOut() do
        Wait(0)
    end

    local ped, coords = ESX.PlayerData.ped, GetBlipInfoIdCoord(blipMarker)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local oldCoords = GetEntityCoords(ped)

    -- Unpack coords instead of having to unpack them while iterating.
    -- 825.0 seems to be the max a player can reach while 0.0 being the lowest.
    local x, y, groundZ, Z_START = coords["x"], coords["y"], 850.0, 950.0
    local found = false
    FreezeEntityPosition(vehicle > 0 and vehicle or ped, true)

    for i = Z_START, 0, -25.0 do
        local z = i
        if (i % 2) ~= 0 then
            z = Z_START - i
        end

        NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
        local tempTimer = GetGameTimer()
        while IsNetworkLoadingScene() do
            if GetGameTimer() - tempTimer > 1000 then
                break
            end
            Wait(0)
        end
        NewLoadSceneStop()
        SetEntityCoords(vehicle > 0 and vehicle or ped, x, y, z, false, false, false, true)
        tempTimer = GetGameTimer()
        while not HasCollisionLoadedAroundEntity(ped) do
            if GetGameTimer() - tempTimer > 1000 then
                break
            end
            Wait(0)
        end

        found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
        if found then
            Wait(0)
            SetEntityCoords(vehicle > 0 and vehicle or ped, x, y, groundZ, false, false, false, true)
            FreezeEntityPosition(vehicle > 0 and vehicle or ped, false)
            break
        end
        Wait(0)
    end

    -- Remove black screen once the loop has ended.
    DoScreenFadeIn(650)
    FreezeEntityPosition(vehicle > 0 and vehicle or ped, false)

    if not found then
        -- If we can't find the coords, set the coords to the old ones.
        -- We don't unpack them before since they aren't in a loop and only called once.
        SetEntityCoords(vehicle > 0 and vehicle or ped, oldCoords["x"], oldCoords["y"], oldCoords["z"], false, false, false, true)
        ESX.ShowNotification(TranslateCap("tpm_error"), "error")
    end

    -- If Z coord was found, set coords in found coords.
    SetEntityCoords(vehicle > 0 and vehicle or ped, x, y, groundZ, false, false, false, true)
    ESX.ShowNotification(TranslateCap("tpm_success"), "success")
end)

ESX.RegisterClientCallback("esx:GetVehicleType", function(cb, model)
    cb(ESX.Game.GetVehicleTypeClient(model))
end)

if not Config.CustomInventory then
    RegisterNetEvent("esx:createPickup", function(pickupId, label, coords, itemType, name, components, tintIndex)
        local function setObjectProperties(object)
            SetEntityAsMissionEntity(object, true, false)
            PlaceObjectOnGroundProperly(object)
            FreezeEntityPosition(object, true)
            SetEntityCollision(object, false, true)

            pickups[pickupId] = {
                obj = object,
                label = label,
                inRange = false,
                coords = coords,
            }
        end

        if itemType == "item_weapon" then
            local weaponHash = joaat(name)
            ESX.Streaming.RequestWeaponAsset(weaponHash)
            local pickupObject = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
            SetWeaponObjectTintIndex(pickupObject, tintIndex)

            for _, v in ipairs(components) do
                local component = ESX.GetWeaponComponent(name, v)
                GiveWeaponComponentToWeaponObject(pickupObject, component.hash)
            end

            setObjectProperties(pickupObject)
        else
            ESX.Game.SpawnLocalObject("prop_money_bag_01", coords, setObjectProperties)
        end
    end)

    RegisterNetEvent("esx:createMissingPickups", function(missingPickups)
        for pickupId, pickup in pairs(missingPickups) do
            TriggerEvent("esx:createPickup", pickupId, pickup.label, vector3(pickup.coords.x, pickup.coords.y, pickup.coords.z), pickup.type, pickup.name, pickup.components, pickup.tintIndex)
        end
    end)

    RegisterNetEvent("esx:removePickup", function(pickupId)
        if pickups[pickupId] and pickups[pickupId].obj then
            ESX.Game.DeleteObject(pickups[pickupId].obj)
            pickups[pickupId] = nil
        end
    end)
end

function StartServerSyncLoops()
    if Config.CustomInventory then
        return
    end

    -- keep track of ammo
    CreateThread(function()
        local currentWeapon = { Ammo = 0 }
        while ESX.PlayerLoaded do
            local sleep = 1500
            if GetSelectedPedWeapon(ESX.PlayerData.ped) ~= -1569615261 then
                sleep = 1000
                local _, weaponHash = GetCurrentPedWeapon(ESX.PlayerData.ped, true)
                local weapon = ESX.GetWeaponFromHash(weaponHash)
                if weapon then
                    local ammoCount = GetAmmoInPedWeapon(ESX.PlayerData.ped, weaponHash)
                    if weapon.name ~= currentWeapon.name then
                        currentWeapon.Ammo = ammoCount
                        currentWeapon.name = weapon.name
                    else
                        if ammoCount ~= currentWeapon.Ammo then
                            currentWeapon.Ammo = ammoCount
                            TriggerServerEvent("esx:updateWeaponAmmo", weapon.name, ammoCount)
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)

    -- Pickups loop (sleeps 1500ms when no pickups exist on map)
    CreateThread(function()
        while ESX.PlayerLoaded do
            local sleep = 1500
            if next(pickups) then
                local playerCoords = GetEntityCoords(ESX.PlayerData.ped)
                local _, closestDistance = ESX.Game.GetClosestPlayer(playerCoords)

                for pickupId, pickup in pairs(pickups) do
                    local distance = #(playerCoords - pickup.coords)

                    if distance < 5 then
                        sleep = 0
                        local label = pickup.label

                        if distance < 1 then
                            if IsControlJustReleased(0, 38) then
                                if IsPedOnFoot(ESX.PlayerData.ped) and (closestDistance == -1 or closestDistance > 3) and not pickup.inRange then
                                    pickup.inRange = true

                                    local dict, anim = "weapons@first_person@aim_rng@generic@projectile@sticky_bomb@", "plant_floor"
                                    ESX.Streaming.RequestAnimDict(dict)
                                    TaskPlayAnim(ESX.PlayerData.ped, dict, anim, 8.0, 1.0, 1000, 16, 0.0, false, false, false)
                                    RemoveAnimDict(dict)
                                    Wait(1000)

                                    TriggerServerEvent("esx:onPickup", pickupId)
                                    PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
                                end
                            end

                            label = ("%s~n~%s"):format(label, TranslateCap("threw_pickup_prompt"))
                        end

                        ESX.Game.Utils.DrawText3D({
                            x = pickup.coords.x,
                            y = pickup.coords.y,
                            z = pickup.coords.z + 0.25,
                        }, label, 1.2, 1)
                    elseif pickup.inRange then
                        pickup.inRange = false
                    end
                end
            end
            Wait(sleep)
        end
    end)
end
