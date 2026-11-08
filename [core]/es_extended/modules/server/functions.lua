function ESX.Trace(msg)
    if Config.EnableDebug then
        print(("[^2TRACE^7] %s^7"):format(msg))
    end
end

function Core.FilterCommandGroups(groups)
    if type(groups) == "string" then
        return groups
    end

    if type(groups) ~= "table" then
        return "admin"
    end

    local validGroups = { user = true }
    for i = 1, #(Config.AdminGroups or {}) do
        validGroups[Config.AdminGroups[i]] = true
    end

    local filtered = {}
    for i = 1, #groups do
        local g = groups[i]
        if validGroups[g] then
            filtered[#filtered + 1] = g
        end
    end

    return #filtered > 0 and filtered or "admin"
end

---@param eventName string
---@param playerIds table|number
---@param ... any
function ESX.TriggerClientEvent(eventName, playerIds, ...)
    if type(playerIds) == "number" then
        TriggerClientEvent(eventName, playerIds, ...)
        return
    end

    local payload = msgpack.pack_args(...)
    local payloadLength = #payload

    for i = 1, #playerIds do
        TriggerClientEventInternal(eventName, playerIds[i], payload, payloadLength)
    end
end

function ESX.RegisterCommand(name, group, cb, allowConsole, suggestion)
    if type(name) == "table" then
        for _, v in ipairs(name) do
            ESX.RegisterCommand(v, group, cb, allowConsole, suggestion)
        end
        return
    end

    if Core.RegisteredCommands[name] then
        print(("[^3WARNING^7] Command ^5\"%s\"^7 already overridden, overriding command"):format(name))

        if Core.RegisteredCommands[name].suggestion then
            TriggerClientEvent("chat:removeSuggestion", -1, ("/%s"):format(name))
        end
    end

    if suggestion then
        if not suggestion.arguments then
            suggestion.arguments = {}
        end
        if not suggestion.help then
            suggestion.help = ""
        end

        TriggerClientEvent("chat:addSuggestion", -1, ("/%s"):format(name), suggestion.help, suggestion.arguments)
    end

    Core.RegisteredCommands[name] = { group = group, cb = cb, allowConsole = allowConsole, suggestion = suggestion }

    RegisterCommand(name, function(playerId, args)
        local command = Core.RegisteredCommands[name]

        if not command.allowConsole and playerId == 0 then
            print(("[^3WARNING^7] ^5%s"):format(TranslateCap("commanderror_console")))
        else
            local xPlayer, errorMsg = ESX.Players[playerId], nil

            if command.suggestion then
                if command.suggestion.validate then
                    if #args ~= #command.suggestion.arguments then
                        errorMsg = TranslateCap("commanderror_argumentmismatch", #args, #command.suggestion.arguments)
                    end
                end

                if not errorMsg and command.suggestion.arguments then
                    local newArgs = {}

                    for k, v in ipairs(command.suggestion.arguments) do
                        if v.type then
                            if v.type == "number" then
                                local newArg = tonumber(args[k])

                                if newArg then
                                    newArgs[v.name] = newArg
                                else
                                    errorMsg = TranslateCap("commanderror_argumentmismatch_number", k)
                                end
                            elseif v.type == "player" or v.type == "playerId" then
                                local targetPlayer = tonumber(args[k])

                                if args[k] == "me" then
                                    targetPlayer = playerId
                                end

                                if targetPlayer then
                                    local xTargetPlayer = ESX.GetPlayerFromId(targetPlayer)

                                    if xTargetPlayer then
                                        if v.type == "player" then
                                            newArgs[v.name] = xTargetPlayer
                                        else
                                            newArgs[v.name] = targetPlayer
                                        end
                                    else
                                        errorMsg = TranslateCap("commanderror_invalidplayerid")
                                    end
                                else
                                    errorMsg = TranslateCap("commanderror_argumentmismatch_number", k)
                                end
                            elseif v.type == "string" then
                                local newArg = tonumber(args[k])
                                if not newArg then
                                    newArgs[v.name] = args[k]
                                else
                                    errorMsg = TranslateCap("commanderror_argumentmismatch_string", k)
                                end
                            elseif v.type == "item" then
                                if ESX.Items[args[k]] then
                                    newArgs[v.name] = args[k]
                                else
                                    errorMsg = TranslateCap("commanderror_invaliditem")
                                end
                            elseif v.type == "weapon" then
                                if ESX.GetWeapon(args[k]) then
                                    newArgs[v.name] = string.upper(args[k])
                                else
                                    errorMsg = TranslateCap("commanderror_invalidweapon")
                                end
                            elseif v.type == "any" then
                                newArgs[v.name] = args[k]
                            elseif v.type == "merge" then
                                local length = 0
                                for i = 1, k - 1 do
                                    length = length + string.len(args[i]) + 1
                                end
                                local merge = table.concat(args, " ")

                                newArgs[v.name] = string.sub(merge, length)
                            elseif v.type == "coordinate" then
                                local coord = tonumber(args[k]:match("(-?%d+%.?%d*)"))
                                if not coord then
                                    errorMsg = TranslateCap("commanderror_argumentmismatch_number", k)
                                else
                                    newArgs[v.name] = coord
                                end
                            end
                        end

                        if not v.validate then
                            errorMsg = nil
                        end

                        if errorMsg then
                            break
                        end
                    end

                    args = newArgs
                end
            end

            if errorMsg then
                if playerId == 0 then
                    print(("[^3WARNING^7] %s^7"):format(errorMsg))
                else
                    xPlayer.showNotification(errorMsg)
                end
            else
                cb(xPlayer or false, args, function(msg)
                    if playerId == 0 then
                        print(("[^3WARNING^7] %s^7"):format(msg))
                    else
                        xPlayer.showNotification(msg)
                    end
                end)
            end
        end
    end, true)

    if type(group) == "table" then
        for _, v in ipairs(group) do
            ExecuteCommand(("add_ace group.%s command.%s allow"):format(v, name))
        end
    else
        ExecuteCommand(("add_ace group.%s command.%s allow"):format(group, name))
    end
end

function ESX.GetExtendedPlayers(key, val, onlyIds)
    if not key then
        if onlyIds then
            local ids = {}
            for src in pairs(ESX.Players) do
                ids[#ids + 1] = src
            end
            return ids
        end
        return ESX.Table.ToArray(ESX.Players)
    end

    if key == "job" and type(val) ~= "table" then
        local bucket = Core.playersByJob[val]
        if not bucket then
            return {}
        end
        local out = {}
        local n = 0
        for src, xPlayer in pairs(bucket) do
            n = n + 1
            out[n] = onlyIds and src or xPlayer
        end
        return out
    end

    local xPlayers = {}
    if type(val) == "table" then
        if onlyIds then
            for i = 1, #val do
                xPlayers[val[i]] = {}
            end
            for src, xPlayer in pairs(ESX.Players) do
                local check = (key == "job" and xPlayer.job.name or xPlayer[key])
                if xPlayers[check] then
                    xPlayers[check][#xPlayers[check] + 1] = src
                end
            end
            return xPlayers
        end

        local valSet = {}
        for i = 1, #val do
            valSet[val[i]] = true
        end
        for _, xPlayer in pairs(ESX.Players) do
            local check = (key == "job" and xPlayer.job.name or xPlayer[key])
            if valSet[check] then
                xPlayers[#xPlayers + 1] = xPlayer
            end
        end
    else
        for src, xPlayer in pairs(ESX.Players) do
            if val == (key == "job" and xPlayer.job.name or xPlayer[key]) then
                xPlayers[#xPlayers + 1] = onlyIds and src or xPlayer
            end
        end
    end

    return xPlayers
end

function ESX.GetPlayers()
    local sources = {}
    for k in pairs(ESX.Players) do
        sources[#sources + 1] = k
    end
    return sources
end

function ESX.GetNumPlayers(key, val)
    if not key then
        return #GetPlayers()
    end

    if type(val) == "table" then
        local numPlayers = 0
        if key == "job" then
            for _, v in ipairs(val) do
                numPlayers = numPlayers + (Core.JobsPlayerCount[v] or 0)
            end
            return numPlayers
        end

        local filteredPlayers = ESX.GetExtendedPlayers(key, val)
        return #filteredPlayers
    end

    if key == "job" then
        return (Core.JobsPlayerCount[val] or 0)
    end

    return #ESX.GetExtendedPlayers(key, val)
end

function ESX.GetPlayerFromId(source)
    return ESX.Players[tonumber(source)]
end

function ESX.GetPlayerFromIdentifier(identifier)
    return Core.playersByIdentifier[identifier]
end

function ESX.GetPlayerIdFromIdentifier(identifier)
    local xPlayer = Core.playersByIdentifier[identifier]
    return xPlayer and xPlayer.source or nil
end

function ESX.GetPlayerFromSsn(ssn)
    for _, xPlayer in pairs(ESX.Players) do
        if xPlayer.ssn == ssn then
            return xPlayer
        end
    end
    return nil
end

function ESX.IsPlayerLoaded(playerId)
    return ESX.Players[playerId] ~= nil
end

function ESX.TryGetIdentifier(playerId)
    if GetConvarInt("sv_fxdkMode", 0) == 1 then
        return ("%s:ESX-DEBUG"):format(Config.Identifier)
    end

    -- Keep the full prefixed identifier (e.g. "steam:110000112345678") as the primary identifier.
    return GetPlayerIdentifierByType(tostring(playerId), Config.Identifier)
end

function ESX.GetIdentifier(playerId)
    local identifier = ESX.TryGetIdentifier(playerId)

    assert(identifier, ("[ESX] GetIdentifier failed: no identifier found for playerId %s with type '%s'"):format(tostring(playerId), Config.Identifier))

    return identifier
end

---@param model string|number
---@param player number playerId
---@param cb function
function ESX.GetVehicleType(model, player, cb)
    model = type(model) == "string" and joaat(model) or model

    if Core.vehicleTypesByModel[model] then
        return cb(Core.vehicleTypesByModel[model])
    end

    ESX.TriggerClientCallback(player, "esx:GetVehicleType", function(vehicleType)
        Core.vehicleTypesByModel[model] = vehicleType
        cb(vehicleType)
    end, model)
end

function ESX.DiscordLog(name, title, color, message)
    local webHook = Config.DiscordLogs.Webhooks[name] or Config.DiscordLogs.Webhooks.default
    if not webHook or webHook == "" then
        return
    end

    local embedData = {
        {
            ["title"] = title,
            ["color"] = Config.DiscordLogs.Colors[color] or Config.DiscordLogs.Colors.default,
            ["footer"] = {
                ["text"] = "| ESX Logs | " .. os.date(),
                ["icon_url"] = "https://cdn.discordapp.com/attachments/944789399852417096/1020099828266586193/blanc-800x800.png",
            },
            ["description"] = message,
            ["author"] = {
                ["name"] = "ESX Framework",
                ["icon_url"] = "https://cdn.discordapp.com/emojis/939245183621558362.webp?size=128&quality=lossless",
            },
        },
    }
    PerformHttpRequest(
        webHook,
        nil,
        "POST",
        json.encode({
            username = "Logs",
            embeds = embedData,
        }),
        {
            ["Content-Type"] = "application/json",
        }
    )
end

function ESX.DiscordLogFields(name, title, color, fields)
    local webHook = Config.DiscordLogs.Webhooks[name] or Config.DiscordLogs.Webhooks.default
    if not webHook or webHook == "" then
        return
    end

    local embedData = {
        {
            ["title"] = title,
            ["color"] = Config.DiscordLogs.Colors[color] or Config.DiscordLogs.Colors.default,
            ["footer"] = {
                ["text"] = "| ESX Logs | " .. os.date(),
                ["icon_url"] = "https://cdn.discordapp.com/attachments/944789399852417096/1020099828266586193/blanc-800x800.png",
            },
            ["fields"] = fields,
            ["description"] = "",
            ["author"] = {
                ["name"] = "ESX Framework",
                ["icon_url"] = "https://cdn.discordapp.com/emojis/939245183621558362.webp?size=128&quality=lossless",
            },
        },
    }
    PerformHttpRequest(
        webHook,
        nil,
        "POST",
        json.encode({
            username = "Logs",
            embeds = embedData,
        }),
        {
            ["Content-Type"] = "application/json",
        }
    )
end

function ESX.RegisterPlayerFunctionOverrides(index, overrides)
    Core.PlayerFunctionOverrides[index] = overrides
end

function ESX.SetPlayerFunctionOverride(index)
    if not index or not Core.PlayerFunctionOverrides[index] then
        return print("[^3WARNING^7] No valid index provided.")
    end

    Config.PlayerFunctionOverride = index
end

local adminGroupAces = {}
CreateThread(function()
    local groups = Config.AdminGroups or {}
    for i = 1, #groups do
        adminGroupAces[i] = ("group.%s"):format(groups[i])
    end
end)

function Core.IsPlayerAdmin(playerId)
    if (IsPlayerAceAllowed(playerId, "command") or GetConvar("sv_lan", "") == "true") and true or false then
        return true
    end

    for i = 1, #adminGroupAces do
        if IsPlayerAceAllowed(playerId, adminGroupAces[i]) then
            return true
        end
    end

    return false
end

---@param model string|number
---@param coords vector3
---@param heading? number
---@param properties? table
---@return table? xVehicle
function ESX.CreateExtendedVehicle(model, coords, heading, properties)
    local modelName = type(model) == "string" and model:lower() or model
    local modelHash = type(modelName) == "string" and joaat(modelName) or modelName
    if not modelName then
        return print("[^1ERROR^7] Model was not provided for spawning vehicle!")
    end

    heading = heading or 0

    local xPlayer = ESX.OneSync.GetClosestPlayer(coords, 300)
    if not xPlayer or not xPlayer.id then
        return print("[^1ERROR^7] Suitable Closest Player not found within 300m for spawning vehicle!")
    end

    local vehicleType = promise.new()
    ESX.GetVehicleType(modelHash, xPlayer.id, function(_vehicleType)
        vehicleType:resolve(_vehicleType)
    end)

    vehicleType = Citizen.Await(vehicleType)
    if not vehicleType then
        return print(("[^1ERROR^7] Tried to spawn invalid vehicle - ^5%s^7!"):format(model))
    end

    local entity = CreateVehicleServerSetter(modelHash, vehicleType, coords.x, coords.y, coords.z, heading)
    local hasExist = ESX.Await(function()
        return DoesEntityExist(entity)
    end, ("Failed to spawn vehicle - ^5%s^7!"):format(model), 2500)

    if not hasExist then
        return
    end

    Wait(200)

    Entity(entity).state:set("VehicleProperties", properties, true)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local script = GetInvokingResource()

    local xVehicle = CreateExtendedVehicle(entity, netId, modelName, modelHash, vector4(coords.x, coords.y, coords.z, heading), script)
    Core.vehicles[entity] = xVehicle

    return xVehicle
end

---@param plate string
---@return table? xVehicle
function ESX.GetExtendedVehicleFromPlate(plate)
    plate = ESX.Math.Trim(plate)

    for _, xVehicle in pairs(Core.vehicles) do
        if xVehicle.plate == plate then
            return xVehicle
        end
    end
end

local storing = {}

local function normalizePlate(value)
    if type(value) ~= "string" then
        return nil
    end
    local trimmed = ESX.Math.Trim(value)
    if not trimmed or trimmed == "" then
        return nil
    end
    return string.upper(trimmed)
end

exports("StoreJobVehicle", function(playerId, plates, locations)
    local player = ESX.GetPlayerFromId(playerId)

    if not player or type(plates) ~= "table" or #plates < 1 or #plates > 32 then
        return false
    end

    local job = player.getJob()

    if job.onDuty == false then
        return false
    end

    local ped = GetPlayerPed(playerId)

    if ped == 0 then
        return false
    end

    local coords, near = GetEntityCoords(ped), false

    for _, location in pairs(locations or {}) do
        for _, category in ipairs({ "Vehicles", "Helicopters" }) do
            for _, garage in ipairs(location[category] or {}) do
                if garage.Spawner and #(coords - garage.Spawner) <= 35.0 then
                    near = true
                end
            end
        end
    end

    if not near then
        return false
    end

    local allowed = {}

    for _, value in ipairs(plates) do
        local plate = normalizePlate(value)
        if plate then
            allowed[plate] = true
        end
    end

    for _, entity in ipairs(GetAllVehicles()) do
        local plate = normalizePlate(GetVehicleNumberPlateText(entity))

        if
            plate
            and allowed[plate]
            and not storing[plate]
            and DoesEntityExist(entity)
            and GetEntityRoutingBucket(entity) == GetPlayerRoutingBucket(playerId)
            and #(GetEntityCoords(entity) - coords) <= 30.0
        then
            storing[plate] = true

            local ok, result = pcall(function()
                local row = MySQL.single.await(
                    [[SELECT vehicle FROM owned_vehicles
                    WHERE owner = ? AND plate = ? AND job = ? AND stored = 0]],
                    { player.identifier, plate, job.name }
                )

                if not row or not DoesEntityExist(entity) then
                    return false
                end

                local decoded, props = pcall(json.decode, row.vehicle or "")
                local currentPed = GetPlayerPed(playerId)

                if
                    ESX.GetPlayerFromId(playerId) ~= player
                    or currentPed == 0
                    or #(GetEntityCoords(entity) - GetEntityCoords(currentPed)) > 30.0
                    or GetEntityRoutingBucket(entity) ~= GetPlayerRoutingBucket(playerId)
                    or not decoded
                    or props.model ~= GetEntityModel(entity)
                then
                    return false
                end

                for seat = -1, 15 do
                    if GetPedInVehicleSeat(entity, seat) ~= 0 then
                        return false
                    end
                end

                DeleteEntity(entity)

                local deadline = GetGameTimer() + 2000

                while DoesEntityExist(entity) and GetGameTimer() < deadline do
                    Wait(0)
                end

                if DoesEntityExist(entity) then
                    return false
                end

                local changed = MySQL.update.await(
                    [[UPDATE owned_vehicles SET stored = 1
                    WHERE owner = ? AND plate = ? AND job = ? AND stored = 0]],
                    { player.identifier, plate, job.name }
                )

                return changed == 1 and plate or false
            end)

            storing[plate] = nil

            if not ok then
                print("[es_extended] Job vehicle storage failed: " .. tostring(result))
            end

            if ok and result then
                return result
            end
        end
    end

    return false
end)
