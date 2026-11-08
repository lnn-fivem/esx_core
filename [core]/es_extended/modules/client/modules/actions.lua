local isInVehicle = false
local isEnteringVehicle = false
local currentVehicle = nil
local currentSeat = nil
local currentPed = nil
local currentWeapon = false
local isPauseMenu = false

local GetPlayerPed = GetPlayerPed
local IsPauseMenuActive = IsPauseMenuActive
local GetCurrentPedWeapon = GetCurrentPedWeapon
local GetVehiclePedIsTryingToEnter = GetVehiclePedIsTryingToEnter
local GetSeatPedIsTryingToEnter = GetSeatPedIsTryingToEnter
local GetVehicleClass = GetVehicleClass
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local IsPedInAnyVehicle = IsPedInAnyVehicle
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetEntityModel = GetEntityModel
local GetDisplayNameFromVehicleModel = GetDisplayNameFromVehicleModel

local function GetPedVehicleSeat(ped, vehicle)
    for i = -1, 16 do
        if GetPedInVehicleSeat(vehicle, i) == ped then
            return i
        end
    end
    return -1
end

local function GetVehicleData(vehicle)
    if not DoesEntityExist(vehicle) then
        return
    end
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleClass = GetVehicleClass(vehicle)
    local netId = NetworkIsEntityIsNetworked(vehicle) and VehToNet(vehicle) or vehicle
    return vehicleClass, netId, vehicleModel, GetDisplayNameFromVehicleModel(vehicleModel)
end

local function ResetData()
    isInVehicle = false
    isEnteringVehicle = false
    currentVehicle = nil
    currentSeat = nil
    currentPed = nil
    currentWeapon = false
    isPauseMenu = false
end

local function SetCurrentPed(ped)
    ESX.SetPlayerData("ped", ped)
    currentPed = ped

    TriggerEvent("esx:playerPedChanged", ped)
    if not Config.EnableDefaultInventory then
        return
    end
    TriggerEvent("esx:restoreLoadout")
end

local function TrackPed()
    local playerPed = GetPlayerPed(-1)

    if currentPed ~= playerPed then
        SetCurrentPed(playerPed)
    end
end

local function TrackPauseMenu()
    local pauseActive = IsPauseMenuActive()

    if pauseActive and not isPauseMenu then
        isPauseMenu = true
        TriggerEvent("esx:pauseMenuActive", isPauseMenu)
    elseif not pauseActive and isPauseMenu then
        isPauseMenu = false
        TriggerEvent("esx:pauseMenuActive", isPauseMenu)
    end
end

local function TrackWeapon()
    if not currentPed then
        return
    end

    local _, weapon = GetCurrentPedWeapon(currentPed, false)
    if weapon == `WEAPON_UNARMED` then
        weapon = false
    end

    if weapon ~= currentWeapon then
        currentWeapon = weapon
        TriggerEvent("esx:weaponChanged", currentWeapon)
    end
end

local function TrackVehicle()
    if not isInVehicle then
        local vehicleIsTryingToEnter = GetVehiclePedIsTryingToEnter(currentPed)

        if DoesEntityExist(vehicleIsTryingToEnter) and not isEnteringVehicle then
            local seat = GetSeatPedIsTryingToEnter(currentPed)
            local vehicleClass, netId, model, displayName = GetVehicleData(vehicleIsTryingToEnter)
            isEnteringVehicle = true

            TriggerEvent("esx:enteringVehicle", vehicleIsTryingToEnter, currentSeat, netId)
            TriggerServerEvent("esx:enteringVehicle", netId, vehicleClass, model, seat, displayName)
        elseif not DoesEntityExist(vehicleIsTryingToEnter) and not IsPedInAnyVehicle(currentPed, true) and isEnteringVehicle then
            TriggerEvent("esx:enteringVehicleAborted")
            TriggerServerEvent("esx:enteringVehicleAborted")
            isEnteringVehicle = false
        elseif IsPedInAnyVehicle(currentPed, false) then
            isEnteringVehicle = false
            isInVehicle = true
            currentVehicle = GetVehiclePedIsIn(currentPed, false)
            currentSeat = GetPedVehicleSeat(currentPed, currentVehicle)
            local vehicleClass, netId, model, displayName = GetVehicleData(currentVehicle)

            ESX.SetPlayerData("vehicle", currentVehicle)
            ESX.SetPlayerData("seat", currentSeat)

            TriggerEvent("esx:enteredVehicle", currentVehicle, currentSeat, displayName, netId, model)
            TriggerServerEvent("esx:enteredVehicle", netId, vehicleClass, model, currentSeat, displayName)
        end
    elseif isInVehicle then
        if not IsPedInAnyVehicle(currentPed, false) then
            local vehicleClass, netId, model, displayName = GetVehicleData(currentVehicle)

            TriggerEvent("esx:exitedVehicle", currentVehicle, currentSeat, displayName, netId, model)
            TriggerServerEvent("esx:exitedVehicle", netId, vehicleClass, model, currentSeat, displayName)

            ESX.SetPlayerData("vehicle", false)
            ESX.SetPlayerData("seat", false)

            isInVehicle = false
            currentVehicle = nil
            currentSeat = nil
        else
            local newVehicle = GetVehiclePedIsIn(currentPed, false)

            if newVehicle ~= currentVehicle then
                local oldClass, oldNetId, oldModel, oldDisplayName = GetVehicleData(currentVehicle)
                TriggerEvent("esx:exitedVehicle", currentVehicle, currentSeat, oldDisplayName, oldNetId, oldModel)
                TriggerServerEvent("esx:exitedVehicle", oldNetId, oldClass, oldModel, currentSeat, oldDisplayName)

                currentVehicle = newVehicle
                currentSeat = GetPedVehicleSeat(currentPed, currentVehicle)
                local vehicleClass, netId, model, displayName = GetVehicleData(currentVehicle)

                ESX.SetPlayerData("vehicle", currentVehicle)
                ESX.SetPlayerData("seat", currentSeat)

                TriggerEvent("esx:enteredVehicle", currentVehicle, currentSeat, displayName, netId, model)
                TriggerServerEvent("esx:enteredVehicle", netId, vehicleClass, model, currentSeat, displayName)
            else
                local newSeat = GetPedVehicleSeat(currentPed, currentVehicle)
                if newSeat ~= currentSeat then
                    currentSeat = newSeat
                    ESX.SetPlayerData("seat", currentSeat)
                    TriggerEvent("esx:vehicleSeatChanged", currentVehicle, currentSeat)
                end
            end
        end
    end
end

local function SlowLoop()
    CreateThread(function()
        while ESX.PlayerLoaded do
            TrackPed()
            TrackWeapon()
            TrackPauseMenu()
            TrackVehicle()
            Wait(200)
        end
    end)
end

function EnableActions()
    ResetData()
    SetCurrentPed(PlayerPedId())
    SlowLoop()
end
