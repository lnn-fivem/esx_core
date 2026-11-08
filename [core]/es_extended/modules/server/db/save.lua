local saveQuery <const> = "UPDATE `users` SET `accounts` = ?, `job` = ?, `job_grade` = ?, `group` = ?, `position` = ?, `inventory` = ?, `loadout` = ?, `metadata` = ? WHERE `identifier` = ?"

local persistenceLocks = {}
local saveQueues = {}

local function isFiniteCoordinate(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Core.IsValidPosition(pos)
    if type(pos) ~= "table" and type(pos) ~= "vector3" and type(pos) ~= "vector4" then
        return false
    end

    if not isFiniteCoordinate(pos.x) or not isFiniteCoordinate(pos.y) or not isFiniteCoordinate(pos.z) then
        return false
    end

    if pos.heading ~= nil and not isFiniteCoordinate(pos.heading) then
        return false
    end

    local limit = tonumber(Config.PlayerCoordinateLimit) or 10000.0
    if limit <= 0 then
        limit = 10000.0
    end

    return math.abs(pos.x) <= limit and math.abs(pos.y) <= limit and math.abs(pos.z) <= limit
end

local function livePlayerCoords(xPlayer)
    local ped = GetPlayerPed(xPlayer.source)
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        local live = {
            x = ESX.Math.Round(coords.x, 1),
            y = ESX.Math.Round(coords.y, 1),
            z = ESX.Math.Round(coords.z, 1),
            heading = ESX.Math.Round(heading, 1),
        }
        if Core.IsValidPosition(live) then
            xPlayer.coords = live
            return live
        end
    end

    if Core.IsValidPosition(xPlayer.coords) then
        return xPlayer.coords
    end

    local fallback = Config.DefaultSpawns[1] or { x = 222.2, y = -864.0, z = 30.3, heading = 1.0 }
    return {
        x = ESX.Math.Round(fallback.x, 1),
        y = ESX.Math.Round(fallback.y, 1),
        z = ESX.Math.Round(fallback.z, 1),
        heading = ESX.Math.Round(fallback.heading or 0.0, 1),
    }
end

local function updateHealthAndArmorInMetadata(xPlayer)
    local ped = GetPlayerPed(xPlayer.source)
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        xPlayer.metadata.health = GetEntityHealth(ped)
        xPlayer.metadata.armor = GetPedArmour(ped)
    end
end

local function buildPlayerSaveParams(xPlayer)
    local coords = livePlayerCoords(xPlayer)
    return {
        json.encode(xPlayer.getAccounts(true)),
        xPlayer.job.name,
        xPlayer.job.grade,
        xPlayer.group,
        json.encode(coords),
        json.encode(xPlayer.getInventory(true)),
        json.encode(xPlayer.getLoadout(true)),
        json.encode(xPlayer.getMeta()),
        xPlayer.identifier,
    }
end

function Core.SampleHealthAndArmor()
    for _, xPlayer in pairs(ESX.Players) do
        if xPlayer.spawned then
            updateHealthAndArmorInMetadata(xPlayer)
        end
    end
end

function Core.WithPlayerPersistence(identifier, action, failClosed)
    if type(identifier) ~= "string" or identifier == "" or not ESX.IsFunctionReference(action) then
        if failClosed then
            error("Core.WithPlayerPersistence requires a valid identifier and action")
        end
        return
    end

    local previous = persistenceLocks[identifier]
    local done = promise.new()
    persistenceLocks[identifier] = done

    if previous then
        Citizen.Await(previous)
    end

    local ok, result = xpcall(action, debug.traceback)
    done:resolve(true)

    if persistenceLocks[identifier] == done then
        persistenceLocks[identifier] = nil
    end

    if not ok then
        if failClosed then
            error(result, 0)
        end
        print(("^1[ERROR]^7 Player persistence action failed for %s:\n%s"):format(identifier, tostring(result)))
        return
    end

    return result
end

exports("WithPlayerPersistence", Core.WithPlayerPersistence)

local function runQueuedSaves(queue)
    CreateThread(function()
        while true do
            local ok, err = pcall(Core.WithPlayerPersistence, queue.identifier, function()
                local xPlayer = queue.xPlayer
                local callbacks = queue.callbacks
                queue.callbacks = {}

                updateHealthAndArmorInMetadata(xPlayer)
                local params = buildPlayerSaveParams(xPlayer)
                xPlayer.isDirty = false

                local affectedRows = MySQL.prepare.await(saveQuery, params)

                print(("[^2INFO^7] Saved player ^5\"%s\"^7"):format(xPlayer.name))
                TriggerEvent("esx:playerSaved", xPlayer.playerId, xPlayer)

                for i = 1, #callbacks do
                    local callbackOk, callbackErr = pcall(callbacks[i], affectedRows)
                    if not callbackOk then
                        print(("^1[ERROR]^7 SavePlayer callback failed for %s: %s"):format(queue.identifier, tostring(callbackErr)))
                    end
                end
            end)

            if not ok then
                local callbacks = queue.callbacks
                queue.callbacks = {}

                for i = 1, #callbacks do
                    pcall(callbacks[i], false)
                end

                print(("^1[ERROR]^7 SavePlayer failed for %s: %s"):format(queue.identifier, tostring(err)))
            end

            if not queue.Dirty then
                saveQueues[queue.identifier] = nil
                return
            end

            queue.Dirty = false
        end
    end)
end

function Core.SavePlayer(xPlayer, cb, force)
    if type(xPlayer) ~= "table" or type(xPlayer.identifier) ~= "string" then
        if cb then
            cb(false)
        end
        return
    end

    if not force and not xPlayer.spawned then
        if cb then
            cb()
        end
        return
    end

    local identifier = xPlayer.identifier
    local queue = saveQueues[identifier]

    if queue then
        queue.xPlayer = xPlayer
        queue.Dirty = true
        if cb then
            queue.callbacks[#queue.callbacks + 1] = cb
        end
        return
    end

    queue = {
        identifier = identifier,
        xPlayer = xPlayer,
        Dirty = false,
        callbacks = cb and { cb } or {},
    }

    saveQueues[identifier] = queue
    runQueuedSaves(queue)
end

exports("SavePlayer", Core.SavePlayer)

local function batchSavePlayers(playerList, label, cb)
    local total = #playerList
    if total == 0 then
        if cb then
            cb()
        end
        return
    end

    local startTime = os.clock()
    local serializeChunk = tonumber(Config.SaveSerializeChunk) or 50
    local batchSize = tonumber(Config.SaveBatchSize) or 100
    local minPlayersForProgress = tonumber(Config.SaveProgressMinPlayers) or 200
    local progressStep = tonumber(Config.SaveProgressStep) or 20

    local parameters = table.create(total, 0)
    for i = 1, total do
        local xPlayer = playerList[i]
        updateHealthAndArmorInMetadata(xPlayer)
        parameters[i] = buildPlayerSaveParams(xPlayer)
        xPlayer.isDirty = false

        if serializeChunk > 0 and i % serializeChunk == 0 and i < total then
            Wait(0)
        end
    end

    local savedCount = 0
    local nextProgressPct = progressStep

    for startIdx = 1, total, batchSize do
        local endIdx = math.min(startIdx + batchSize - 1, total)
        local batchCount = endIdx - startIdx + 1
        local batchParams

        if batchCount == 1 then
            batchParams = parameters[startIdx]
        else
            batchParams = table.create(batchCount, 0)
            for j = 1, batchCount do
                batchParams[j] = parameters[startIdx + j - 1]
            end
        end

        local ok, err = pcall(MySQL.prepare.await, saveQuery, batchParams)
        if not ok then
            print(("^1[ERROR]^7 Batch save failed (%d-%d/%d): %s"):format(startIdx, endIdx, total, tostring(err)))
        else
            savedCount = savedCount + batchCount
            for idx = startIdx, endIdx do
                local xPlayer = playerList[idx]
                if xPlayer then
                    TriggerEvent("esx:playerSaved", xPlayer.playerId, xPlayer)
                end
            end
        end

        if total >= minPlayersForProgress then
            local pct = math.floor((endIdx / total) * 100)
            if pct >= nextProgressPct and endIdx < total then
                print(("[^2INFO^7] %s progress: ^5%d%%^7 (%d/%d)"):format(label, pct, endIdx, total))
                nextProgressPct = pct + progressStep
            end
        end
    end

    print(("[^2INFO^7] Saved ^5%d/%d^7 %s over ^5%.2f^7 ms"):format(savedCount, total, label, (os.clock() - startTime) * 1000))

    if cb then
        cb()
    end
end

function Core.SaveDirtyPlayers(cb)
    local dirtyPlayers = {}
    for _, xPlayer in pairs(ESX.Players) do
        if xPlayer.spawned and xPlayer.isDirty and not persistenceLocks[xPlayer.identifier] then
            dirtyPlayers[#dirtyPlayers + 1] = xPlayer
        end
    end

    batchSavePlayers(dirtyPlayers, "dirty player(s)", cb)
end

function Core.SavePlayers(cb)
    local spawnedPlayers = {}
    for _, xPlayer in pairs(ESX.Players) do
        if xPlayer.spawned then
            spawnedPlayers[#spawnedPlayers + 1] = xPlayer
        end
    end

    batchSavePlayers(spawnedPlayers, "player(s)", cb)
end
