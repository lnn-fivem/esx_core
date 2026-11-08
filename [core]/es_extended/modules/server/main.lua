SetMapName("San Andreas")
SetGameType("ESX Legacy")

local oneSyncState = GetConvar("onesync", "off")
local newPlayer = "INSERT INTO `users` SET `accounts` = ?, `identifier` = ?, `ssn` = ?, `group` = ?"
local loadPlayer = "SELECT `accounts`, `job`, `job_grade`, `group`, `position`, `inventory`, `skin`, `loadout`, `metadata`, `ssn` FROM `users` WHERE `identifier` = ?"

if Config.Multichar then
    newPlayer = newPlayer .. ", `firstname` = ?, `lastname` = ?, `dateofbirth` = ?, `sex` = ?, `height` = ?"
end

if Config.StartingInventoryItems then
    newPlayer = newPlayer .. ", `inventory` = ?"
end

if Config.Multichar or Config.Identity then
    loadPlayer = "SELECT `accounts`, `job`, `job_grade`, `group`, `position`, `inventory`, `skin`, `loadout`, `firstname`, `lastname`, `dateofbirth`, `sex`, `height`, `disabled`, `metadata`, `ssn` FROM `users` WHERE `identifier` = ?"
end

local function createESXPlayer(identifier, playerId, data)
    local accounts = {}

    for account, money in pairs(Config.StartingAccountMoney) do
        accounts[account] = money
    end

    local defaultGroup = "user"
    if Core.IsPlayerAdmin(playerId) then
        print(("[^2INFO^0] Player ^5%s^0 Has been granted admin permissions via ^5Ace Perms^7."):format(playerId))
        defaultGroup = "admin"
    end

    local parameters = Config.Multichar and {
        json.encode(accounts),
        identifier,
        Core.generateSSN(),
        defaultGroup,
        data.firstname,
        data.lastname,
        data.dateofbirth,
        data.sex,
        data.height,
    } or {
        json.encode(accounts),
        identifier,
        Core.generateSSN(),
        defaultGroup,
    }

    if Config.StartingInventoryItems then
        table.insert(parameters, json.encode(Config.StartingInventoryItems))
    end

    MySQL.prepare.await(newPlayer, parameters)
end

local function loadESXPlayer(identifier, playerId, isNew)
    local userData = {
        accounts = {},
        inventory = {},
        loadout = {},
        weight = 0,
        identifier = identifier,
        firstName = "John",
        lastName = "Doe",
        dateofbirth = "01/01/2000",
        height = 120,
        dead = false,
    }

    local result = MySQL.prepare.await(loadPlayer, { identifier })
    if not result then
        return
    end

    local accounts = result.accounts
    accounts = (accounts and accounts ~= "") and json.decode(accounts) or {}

    for account, data in pairs(Config.Accounts) do
        data.round = data.round or data.round == nil

        local index = #userData.accounts + 1
        userData.accounts[index] = {
            name = account,
            money = accounts[account] or Config.StartingAccountMoney[account] or 0,
            label = data.label,
            round = data.round,
            index = index,
        }
    end

    local job, grade = result.job, tostring(result.job_grade)

    if not ESX.DoesJobExist(job, grade) then
        print(("[^3WARNING^7] Ignoring invalid job for ^5%s^7 [job: ^5%s^7, grade: ^5%s^7]"):format(identifier, job, grade))
        job, grade = "unemployed", "0"
    end

    local jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]

    userData.metadata = (result.metadata and result.metadata ~= "") and json.decode(result.metadata) or {}

    userData.job = {
        id = jobObject.id,
        name = jobObject.name,
        label = jobObject.label,
        type = jobObject.type,
        onDuty = userData.metadata.jobDuty ~= nil and userData.metadata.jobDuty or (jobObject.name == "unemployed" and false or Config.DefaultJobDuty),

        grade = tonumber(grade),
        grade_name = gradeObject.name,
        grade_label = gradeObject.label,
        grade_salary = gradeObject.salary,

        skin_male = gradeObject.skin_male or {},
        skin_female = gradeObject.skin_female or {},
    }

    if not Config.CustomInventory then
        local foundItems = {}

        if result.inventory and result.inventory ~= "" then
            local inventory = json.decode(result.inventory)

            for name, count in pairs(inventory) do
                local item = ESX.Items[name]

                if item then
                    foundItems[name] = count
                else
                    print(("[^3WARNING^7] Ignoring invalid item ^5\"%s\"^7 for ^5\"%s^7\""):format(name, identifier))
                end
            end
        end

        for name, count in pairs(foundItems) do
            if count > 0 then
                local item = ESX.Items[name]
                userData.weight = userData.weight + (item.weight * count)

                userData.inventory[#userData.inventory + 1] = {
                    name = name,
                    count = count,
                    label = item.label,
                    weight = item.weight,
                    limit = item.limit or -1,
                    usable = Core.UsableItemsCallbacks[name] ~= nil,
                    rare = item.rare,
                    canRemove = item.canRemove,
                }
            end
        end

        table.sort(userData.inventory, function(a, b)
            return a.label < b.label
        end)
    elseif result.inventory and result.inventory ~= "" then
        userData.inventory = json.decode(result.inventory)
    end

    if result.group then
        if result.group == "superadmin" then
            userData.group = "admin"
            print("[^3WARNING^7] ^5Superadmin^7 detected, setting group to ^5admin^7")
        else
            userData.group = result.group
        end
    else
        userData.group = "user"
    end

    if not Config.CustomInventory then
        if result.loadout and result.loadout ~= "" then
            local loadout = json.decode(result.loadout)

            for name, weapon in pairs(loadout) do
                local label = ESX.GetWeaponLabel(name)

                if label then
                    userData.loadout[#userData.loadout + 1] = {
                        name = name,
                        ammo = weapon.ammo,
                        label = label,
                        components = {},
                        tintIndex = weapon.tintIndex or 0,
                    }

                    if not weapon.components then
                        weapon.components = {}
                    end

                    for _, component in ipairs(weapon.components) do
                        local componentInfo = ESX.GetWeaponComponent(name, component)

                        if componentInfo then
                            userData.loadout[#userData.loadout].components[#userData.loadout[#userData.loadout].components + 1] = component
                        end
                    end
                end
            end
        end
    end

    local decodedCoords = result.position and json.decode(result.position) or nil
    if Core.IsValidPosition(decodedCoords) then
        userData.coords = decodedCoords
    else
        userData.coords = Config.DefaultSpawns[ESX.Math.Random(1, #Config.DefaultSpawns)]
    end

    userData.skin = (result.skin and result.skin ~= "") and json.decode(result.skin) or { sex = userData.sex == "f" and 1 or 0 }

    if result.firstname and result.firstname ~= "" then
        userData.firstName = result.firstname
        userData.lastName = result.lastname

        local name = ("%s %s"):format(result.firstname, result.lastname)
        userData.name = name

        if result.dateofbirth then
            userData.dateofbirth = result.dateofbirth
        end
        if result.sex then
            userData.sex = result.sex
        end
        if result.height then
            userData.height = result.height
        end
    end

    if not result.ssn or result.ssn == "" then
        result.ssn = Core.generateSSN()
        MySQL.update("UPDATE `users` SET `ssn` = ? WHERE `identifier` = ?", { result.ssn, identifier })
    end
    userData.ssn = result.ssn

    if not userData.metadata.health then
        userData.metadata.health = 200
    end

    if not userData.metadata.armor then
        userData.metadata.armor = 0
    end

    if not userData.metadata.lastPlaytime then
        userData.metadata.lastPlaytime = 0
    end

    local xPlayer = CreateExtendedPlayer(playerId, identifier, userData.ssn, userData.group, userData.accounts, userData.inventory, userData.weight, userData.job, userData.loadout, userData.name or GetPlayerName(playerId), userData.coords, userData.metadata)
    ESX.Players[playerId] = xPlayer
    Core.playersByIdentifier[identifier] = xPlayer

    if userData.firstName then
        xPlayer.set("firstName", userData.firstName)
        xPlayer.set("lastName", userData.lastName)
        if userData.dateofbirth then
            xPlayer.set("dateofbirth", userData.dateofbirth)
        end
        if userData.sex then
            xPlayer.set("sex", userData.sex)
        end
        if userData.height then
            xPlayer.set("height", userData.height)
        end
    end

    TriggerEvent("esx:playerLoaded", playerId, xPlayer, isNew)
    userData.money = xPlayer.getMoney()
    userData.maxWeight = xPlayer.getMaxWeight()
    userData.variables = xPlayer.variables
    xPlayer.triggerEvent("esx:playerLoaded", userData, isNew, userData.skin)

    if not Config.OxInventory then
        xPlayer.triggerEvent("esx:createMissingPickups", Core.Pickups)
    else
        exports.ox_inventory:setPlayerInventory(xPlayer, userData.inventory)

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

    xPlayer.triggerEvent("chat:addSuggestions", Core.RegisteredCommands)
end

local function onPlayerJoined(playerId, char, data)
    local identifier

    if not char then
        identifier = ESX.GetIdentifier(playerId)
    else
        identifier = ("%s:%s"):format(char, ESX.GetIdentifier(playerId))
    end

    if identifier then
        if ESX.GetPlayerFromIdentifier(identifier) then
            DropPlayer(
                playerId,
                ("there was an error loading your character!\nError code: identifier-active-ingame\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s"):format(
                    identifier
                )
            )
        else
            Core.WithPlayerPersistence(identifier, function()
                local result = MySQL.scalar.await("SELECT 1 FROM `users` WHERE `identifier` = ?", { identifier })
                if result then
                    loadESXPlayer(identifier, playerId, false)
                else
                    createESXPlayer(identifier, playerId, data)
                    loadESXPlayer(identifier, playerId, true)
                end
            end)
        end
    else
        DropPlayer(playerId, "there was an error loading your character!\nError code: identifier-missing-ingame\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.")
    end
end

if Config.Multichar then
    AddEventHandler("esx:onPlayerJoined", function(src, char, data)
        while not next(ESX.Jobs) do
            Wait(50)
        end

        if not ESX.Players[src] then
            onPlayerJoined(src, char, data)
        end
    end)
else
    AddEventHandler("playerConnecting", function(_, _, deferrals)
        local playerId = source
        deferrals.defer()
        Wait(0)
        local identifier

        if oneSyncState == "off" or oneSyncState == "legacy" then
            return deferrals.done(("[ESX] ESX Requires Onesync Infinity to work. This server currently has Onesync set to: %s"):format(oneSyncState))
        end

        if not Core.DatabaseConnected then
            return deferrals.done("[ESX] OxMySQL Was Unable To Connect to your database. Please make sure it is turned on and correctly configured in your server.cfg")
        end

        local ok = ESX.Await(function()
            identifier = ESX.TryGetIdentifier(playerId)
            return identifier ~= nil
        end, nil, 60000)

        if not ok or not identifier then
            return deferrals.done(
                ("[ESX] Unable to retrieve your %s identifier while connecting.\nPlease make sure Steam/Rockstar is running and try reconnecting."):format(
                    Config.Identifier
                )
            )
        end

        if ESX.GetPlayerFromIdentifier(identifier) then
            return deferrals.done(
                ("[ESX] There was an error loading your character!\nError code: identifier-active\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same account.\n\nYour identifier: %s"):format(
                    identifier
                )
            )
        end

        return deferrals.done()
    end)

    RegisterNetEvent("esx:onPlayerJoined", function()
        local _source = source
        while not next(ESX.Jobs) do
            Wait(50)
        end

        if not ESX.Players[_source] then
            onPlayerJoined(_source)
        end
    end)
end

AddEventHandler("esx:jobsLoaded", function()
    for _, xPlayer in pairs(ESX.Players) do
        local job = xPlayer.job.name
        local jobObject = ESX.Jobs[job]
        local gradeObject = jobObject and jobObject.grades[tostring(xPlayer.job.grade)]

        if not gradeObject then
            print(("[^3WARNING^7] Invalid job ^5\"%s\"^7 or grade ^5\"%s\"^7 for player ^5%s^7 on job refresh!"):format(job, xPlayer.job.grade, xPlayer.source))
            job, xPlayer.job.grade = "unemployed", "0"
            jobObject = ESX.Jobs[job]
            gradeObject = jobObject.grades["0"]
        end

        xPlayer.setJob(job, xPlayer.job.grade, xPlayer.job.onDuty)
    end
end)

AddEventHandler("playerDropped", function(reason)
    local playerId = source
    local xPlayer = ESX.Players[playerId]

    if xPlayer then
        TriggerEvent("esx:playerDropped", playerId, reason)

        if xPlayer.beginAccountShutdown then
            xPlayer.beginAccountShutdown()
        end

        if xPlayer.getPendingAccountOperations then
            local deadline = GetGameTimer() + 5000
            while xPlayer.getPendingAccountOperations() > 0 and GetGameTimer() < deadline do
                Wait(0)
            end
        end

        local job = xPlayer.getJob().name
        local currentJob = Core.JobsPlayerCount[job]
        Core.JobsPlayerCount[job] = ((currentJob and currentJob > 0) and currentJob or 1) - 1
        GlobalState[("%s:count"):format(job)] = Core.JobsPlayerCount[job]

        local jobBucket = Core.playersByJob[job]
        if jobBucket then
            jobBucket[playerId] = nil
        end

        Core.playersByIdentifier[xPlayer.identifier] = nil
        ESX.Players[playerId] = nil
        GlobalState.playerCount = GlobalState.playerCount - 1

        if xPlayer.metadata and xPlayer.metadata.lastPlaytime then
            xPlayer.metadata.lastPlaytime = xPlayer.getPlayTime()
        end

        Core.SavePlayer(xPlayer, nil, true)
    end
end)

AddEventHandler("esx:playerLoaded", function(playerId, xPlayer)
    local job = xPlayer.getJob().name
    local jobKey = ("%s:count"):format(job)

    Core.JobsPlayerCount[job] = (Core.JobsPlayerCount[job] or 0) + 1
    GlobalState[jobKey] = Core.JobsPlayerCount[job]

    local jobBucket = Core.playersByJob[job]
    if not jobBucket then
        jobBucket = {}
        Core.playersByJob[job] = jobBucket
    end
    jobBucket[playerId] = xPlayer

    GlobalState.playerCount = GlobalState.playerCount + 1
end)

AddEventHandler("esx:setJob", function(playerId, job, lastJob)
    local lastJobKey = ("%s:count"):format(lastJob.name)
    local jobKey = ("%s:count"):format(job.name)
    local currentLastJob = Core.JobsPlayerCount[lastJob.name]

    Core.JobsPlayerCount[lastJob.name] = ((currentLastJob and currentLastJob > 0) and currentLastJob or 1) - 1
    Core.JobsPlayerCount[job.name] = (Core.JobsPlayerCount[job.name] or 0) + 1

    GlobalState[lastJobKey] = Core.JobsPlayerCount[lastJob.name]
    GlobalState[jobKey] = Core.JobsPlayerCount[job.name]

    local lastBucket = Core.playersByJob[lastJob.name]
    if lastBucket then
        lastBucket[playerId] = nil
    end

    local xPlayer = ESX.Players[playerId]
    if xPlayer then
        local newBucket = Core.playersByJob[job.name]
        if not newBucket then
            newBucket = {}
            Core.playersByJob[job.name] = newBucket
        end
        newBucket[playerId] = xPlayer
    end
end)

AddEventHandler("esx:playerLogout", function(playerId, cb)
    local xPlayer = ESX.Players[playerId]
    if xPlayer then
        TriggerEvent("esx:playerDropped", playerId)

        if xPlayer.beginAccountShutdown then
            xPlayer.beginAccountShutdown()
        end

        if xPlayer.getPendingAccountOperations then
            local deadline = GetGameTimer() + 5000
            while xPlayer.getPendingAccountOperations() > 0 and GetGameTimer() < deadline do
                Wait(0)
            end
        end

        local job = xPlayer.getJob().name
        local currentJob = Core.JobsPlayerCount[job]
        Core.JobsPlayerCount[job] = ((currentJob and currentJob > 0) and currentJob or 1) - 1
        GlobalState[("%s:count"):format(job)] = Core.JobsPlayerCount[job]

        local jobBucket = Core.playersByJob[job]
        if jobBucket then
            jobBucket[playerId] = nil
        end

        Core.playersByIdentifier[xPlayer.identifier] = nil
        ESX.Players[playerId] = nil
        GlobalState.playerCount = GlobalState.playerCount - 1

        if xPlayer.metadata and xPlayer.metadata.lastPlaytime then
            xPlayer.metadata.lastPlaytime = xPlayer.getPlayTime()
        end

        Core.SavePlayer(xPlayer, function()
            if cb then
                cb()
            end
        end, true)
    else
        if cb then
            cb()
        end
    end
    TriggerClientEvent("esx:onPlayerLogout", playerId)
end)

if not Config.CustomInventory then
    RegisterNetEvent("esx:updateWeaponAmmo", function(weaponName, ammoCount)
        local xPlayer = ESX.GetPlayerFromId(source)

        if xPlayer then
            xPlayer.updateWeaponAmmo(weaponName, ammoCount)
        end
    end)

    RegisterNetEvent("esx:giveInventoryItem", function(target, itemType, itemName, itemCount)
        local playerId = source
        local sourceXPlayer = ESX.GetPlayerFromId(playerId)
        local targetXPlayer = ESX.GetPlayerFromId(target)
        if not sourceXPlayer or not targetXPlayer then
            return
        end

        local distance = #(GetEntityCoords(GetPlayerPed(playerId)) - GetEntityCoords(GetPlayerPed(target)))
        if distance > Config.DistanceGive then
            print(("[^3WARNING^7] Player ^5%s^7 attempted to give item from out of range!"):format(playerId))
            return
        end

        if itemType == "item_standard" then
            local sourceItem = sourceXPlayer.getInventoryItem(itemName)

            if itemCount > 0 and sourceItem.count >= itemCount then
                if targetXPlayer.canCarryItem(itemName, itemCount) then
                    sourceXPlayer.removeInventoryItem(itemName, itemCount)
                    targetXPlayer.addInventoryItem(itemName, itemCount)

                    sourceXPlayer.showNotification(TranslateCap("gave_item", itemCount, sourceItem.label, targetXPlayer.name))
                    targetXPlayer.showNotification(TranslateCap("received_item", itemCount, sourceItem.label, sourceXPlayer.name))
                else
                    sourceXPlayer.showNotification(TranslateCap("ex_inv_lim", targetXPlayer.name))
                end
            else
                sourceXPlayer.showNotification(TranslateCap("imp_invalid_quantity"))
            end
        elseif itemType == "item_account" then
            if itemCount > 0 and sourceXPlayer.getAccount(itemName).money >= itemCount then
                sourceXPlayer.removeAccountMoney(itemName, itemCount, "Gave to " .. targetXPlayer.name)
                targetXPlayer.addAccountMoney(itemName, itemCount, "Received from " .. sourceXPlayer.name)

                sourceXPlayer.showNotification(TranslateCap("gave_account_money", ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName].label, targetXPlayer.name))
                targetXPlayer.showNotification(TranslateCap("received_account_money", ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName].label, sourceXPlayer.name))
            else
                sourceXPlayer.showNotification(TranslateCap("imp_invalid_amount"))
            end
        elseif itemType == "item_weapon" then
            if sourceXPlayer.hasWeapon(itemName) then
                local weaponLabel = ESX.GetWeaponLabel(itemName)
                if not targetXPlayer.hasWeapon(itemName) then
                    local _, weapon = sourceXPlayer.getWeapon(itemName)
                    local components = ESX.Table.Clone(weapon.components)
                    local weaponAmmo = weapon.ammo
                    local tint = weapon.tintIndex
                    sourceXPlayer.removeWeapon(itemName)
                    targetXPlayer.addWeapon(itemName, weaponAmmo)
                    if tint then
                        targetXPlayer.setWeaponTint(itemName, tint)
                    end
                    for _, v in ipairs(components) do
                        targetXPlayer.addWeaponComponent(itemName, v)
                    end

                    if weaponAmmo > 0 then
                        sourceXPlayer.showNotification(TranslateCap("gave_weapon_withammo", weaponLabel, weaponAmmo, targetXPlayer.name))
                        targetXPlayer.showNotification(TranslateCap("received_weapon_withammo", weaponLabel, weaponAmmo, sourceXPlayer.name))
                    else
                        sourceXPlayer.showNotification(TranslateCap("gave_weapon", weaponLabel, targetXPlayer.name))
                        targetXPlayer.showNotification(TranslateCap("received_weapon", weaponLabel, sourceXPlayer.name))
                    end
                else
                    sourceXPlayer.showNotification(TranslateCap("gave_weapon_hasalready", targetXPlayer.name, weaponLabel))
                    targetXPlayer.showNotification(TranslateCap("received_weapon_hasalready", sourceXPlayer.name, weaponLabel))
                end
            end
        elseif itemType == "item_ammo" then
            if sourceXPlayer.hasWeapon(itemName) then
                local _, weapon = sourceXPlayer.getWeapon(itemName)

                if targetXPlayer.hasWeapon(itemName) then
                    local _, weaponObject = ESX.GetWeapon(itemName)

                    if weaponObject.ammo then
                        local ammoLabel = weaponObject.ammo.label

                        if weapon.ammo >= itemCount then
                            sourceXPlayer.removeWeaponAmmo(itemName, itemCount)
                            targetXPlayer.addWeaponAmmo(itemName, itemCount)

                            sourceXPlayer.showNotification(TranslateCap("gave_weapon_ammo", itemCount, ammoLabel, weapon.label, targetXPlayer.name))
                            targetXPlayer.showNotification(TranslateCap("received_weapon_ammo", itemCount, ammoLabel, weapon.label, sourceXPlayer.name))
                        end
                    end
                else
                    sourceXPlayer.showNotification(TranslateCap("gave_weapon_noweapon", targetXPlayer.name))
                    targetXPlayer.showNotification(TranslateCap("received_weapon_noweapon", sourceXPlayer.name, weapon.label))
                end
            end
        end
    end)

    RegisterNetEvent("esx:removeInventoryItem", function(itemType, itemName, itemCount)
        local playerId = source
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then
            return
        end

        if itemType == "item_standard" then
            if itemCount == nil or itemCount < 1 then
                xPlayer.showNotification(TranslateCap("imp_invalid_quantity"))
            else
                local xItem = xPlayer.getInventoryItem(itemName)

                if not xItem or itemCount > xItem.count or xItem.count < 1 then
                    xPlayer.showNotification(TranslateCap("imp_invalid_quantity"))
                else
                    xPlayer.removeInventoryItem(itemName, itemCount)
                    local pickupLabel = ("%s [%s]"):format(xItem.label, itemCount)
                    ESX.CreatePickup("item_standard", itemName, itemCount, pickupLabel, playerId)
                    xPlayer.showNotification(TranslateCap("threw_standard", itemCount, xItem.label))
                end
            end
        elseif itemType == "item_account" then
            if itemCount == nil or itemCount < 1 then
                xPlayer.showNotification(TranslateCap("imp_invalid_amount"))
            else
                local account = xPlayer.getAccount(itemName)

                if not account or itemCount > account.money or account.money < 1 then
                    xPlayer.showNotification(TranslateCap("imp_invalid_amount"))
                else
                    xPlayer.removeAccountMoney(itemName, itemCount, "Threw away")
                    local pickupLabel = ("%s [%s]"):format(account.label, TranslateCap("locale_currency", ESX.Math.GroupDigits(itemCount)))
                    ESX.CreatePickup("item_account", itemName, itemCount, pickupLabel, playerId)
                    xPlayer.showNotification(TranslateCap("threw_account", ESX.Math.GroupDigits(itemCount), string.lower(account.label)))
                end
            end
        elseif itemType == "item_weapon" then
            itemName = string.upper(itemName)

            if xPlayer.hasWeapon(itemName) then
                local _, weapon = xPlayer.getWeapon(itemName)

                if not weapon.components then
                    weapon.components = {}
                end

                local components = ESX.Table.Clone(weapon.components)
                local pickupLabel = weapon.ammo and ("%s [%s]"):format(weapon.label, weapon.ammo) or ("%s"):format(weapon.label)
                xPlayer.removeWeapon(itemName)
                ESX.CreatePickup("item_weapon", itemName, weapon.ammo, pickupLabel, playerId, components, weapon.tintIndex)

                if weapon.ammo then
                    xPlayer.showNotification(TranslateCap("threw_weapon_ammo", weapon.label, weapon.ammo))
                else
                    xPlayer.showNotification(TranslateCap("threw_weapon", weapon.label))
                end
            end
        end
    end)

    RegisterNetEvent("esx:useItem", function(itemName)
        local source = source
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then
            return
        end
        local item = xPlayer.getInventoryItem(itemName)

        if item and item.count > 0 then
            ESX.UseItem(source, itemName)
        else
            xPlayer.showNotification(TranslateCap("act_imp"))
        end
    end)

    RegisterNetEvent("esx:onPickup", function(pickupId)
        local pickup, xPlayer, success = Core.Pickups[pickupId], ESX.GetPlayerFromId(source)

        if xPlayer and pickup then
            local distance = #(pickup.coords - xPlayer.getCoords(true))
            if distance > 5.0 then
                print(("[^3WARNING^7] Player ^5%s^7 attempted to pickup from out of range!"):format(xPlayer.playerId))
                return
            end

            if pickup.type == "item_standard" then
                if xPlayer.canCarryItem(pickup.name, pickup.count) then
                    xPlayer.addInventoryItem(pickup.name, pickup.count)
                    success = true
                else
                    xPlayer.showNotification(TranslateCap("threw_cannot_pickup"))
                end
            elseif pickup.type == "item_account" then
                success = true
                xPlayer.addAccountMoney(pickup.name, pickup.count, "Picked up")
            elseif pickup.type == "item_weapon" then
                if xPlayer.hasWeapon(pickup.name) then
                    xPlayer.showNotification(TranslateCap("threw_weapon_already"))
                else
                    success = true
                    xPlayer.addWeapon(pickup.name, pickup.count)
                    xPlayer.setWeaponTint(pickup.name, pickup.tintIndex)

                    for _, v in ipairs(pickup.components) do
                        xPlayer.addWeaponComponent(pickup.name, v)
                    end
                end
            end

            if success then
                Core.Pickups[pickupId] = nil
                TriggerClientEvent("esx:removePickup", -1, pickupId)
            end
        end
    end)
end

ESX.RegisterServerCallback("esx:getPlayerData", function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return cb(nil)
    end

    cb({
        identifier = xPlayer.identifier,
        accounts = xPlayer.getAccounts(),
        inventory = xPlayer.getInventory(),
        job = xPlayer.getJob(),
        loadout = xPlayer.getLoadout(),
        money = xPlayer.getMoney(),
        position = xPlayer.getCoords(true),
        metadata = xPlayer.getMeta(),
    })
end)

ESX.RegisterServerCallback("esx:isUserAdmin", function(source, cb)
    cb(Core.IsPlayerAdmin(source))
end)

ESX.RegisterServerCallback("esx:getGameBuild", function(_, cb)
    cb(tonumber(GetConvar("sv_enforceGameBuild", "1604")))
end)

ESX.RegisterServerCallback("esx:getOtherPlayerData", function(_, cb, target)
    local xPlayer = ESX.GetPlayerFromId(target)
    if not xPlayer then
        return cb(nil)
    end

    cb({
        identifier = xPlayer.identifier,
        accounts = xPlayer.getAccounts(),
        inventory = xPlayer.getInventory(),
        job = xPlayer.getJob(),
        loadout = xPlayer.getLoadout(),
        money = xPlayer.getMoney(),
        position = xPlayer.getCoords(true),
        metadata = xPlayer.getMeta(),
    })
end)

ESX.RegisterServerCallback("esx:getPlayerNames", function(source, cb, players)
    players[source] = nil

    for playerId, _ in pairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)

        if xPlayer then
            players[playerId] = xPlayer.getName()
        else
            players[playerId] = nil
        end
    end

    cb(players)
end)

ESX.RegisterServerCallback("esx:spawnVehicle", function(source, cb, vehData)
    local ped = GetPlayerPed(source)
    ESX.OneSync.SpawnVehicle(vehData.model or `ADDER`, vehData.coords or GetEntityCoords(ped), vehData.heading or 0.0, vehData.props or {}, cb)
end)
