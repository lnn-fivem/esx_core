local GetPlayerPed = GetPlayerPed
local DoesEntityExist = DoesEntityExist
local GetEntityCoords = GetEntityCoords
local GetEntityHeading = GetEntityHeading
local TriggerEvent = TriggerEvent
local TriggerClientEvent = TriggerClientEvent
local IsPlayerAceAllowed = IsPlayerAceAllowed
local GiveWeaponToPed = GiveWeaponToPed
local GiveWeaponComponentToPed = GiveWeaponComponentToPed
local SetPedAmmo = SetPedAmmo
local RemoveWeaponFromPed = RemoveWeaponFromPed
local SetEntityCoords = SetEntityCoords
local SetEntityHeading = SetEntityHeading
local DropPlayer = DropPlayer

local function compareByLabel(a, b)
    return a.label < b.label
end

local function copyJob(job)
    local copiedJob = {}
    for key, value in pairs(job) do
        copiedJob[key] = value
    end
    return copiedJob
end

local function decodeJobSkin(value)
    if type(value) == "table" then
        return value
    end
    if type(value) ~= "string" or value == "" then
        return {}
    end
    local ok, decoded = pcall(json.decode, value)
    if not ok or type(decoded) ~= "table" then
        return {}
    end
    return decoded
end

function CreateExtendedPlayer(playerId, identifier, ssn, group, accounts, inventory, weight, job, loadout, name, coords, metadata)
    local self = {}

    self.accounts = accounts
    self.coords = coords
    self.group = group
    self.identifier = identifier
    self.ssn = ssn
    self.inventory = inventory
    self.job = job
    self.loadout = loadout
    self.name = name
    self.playerId = playerId
    self.source = playerId
    self.variables = {}
    self.weight = weight
    self.maxWeight = Config.MaxWeight
    self.metadata = metadata
    self.lastPlaytime = self.metadata.lastPlaytime or 0
    self.paycheckEnabled = true
    self.isDirty = false
    self.admin = Core.IsPlayerAdmin(playerId)

    if Config.Multichar then
        local startIndex = identifier:find(":", 1)
        self.license = startIndex and identifier:sub(startIndex + 1) or identifier
    else
        self.license = identifier
    end

    if not self.license:find(":", 1) then
        self.license = ("%s:%s"):format(Config.Identifier, self.license)
    end

    local accountsByName = {}
    for i = 1, #accounts do
        local acc = accounts[i]
        accountsByName[acc.name] = acc
    end

    local invByName = {}
    for i = 1, #inventory do
        local item = inventory[i]
        invByName[item.name] = item
    end

    local pendingAccountOperations = 0
    local accountMutationsLocked = false

    ExecuteCommand(("add_principal identifier.%s group.%s"):format(self.license, self.group))

    local stateBag = Player(self.source).state
    stateBag:set("identifier", self.identifier, false)
    stateBag:set("ssn", self.ssn, false)
    stateBag:set("license", self.license, false)
    stateBag:set("job", self.job, true)
    stateBag:set("group", self.group, true)
    stateBag:set("name", self.name, true)

    function self.triggerEvent(eventName, ...)
        assert(type(eventName) == "string", "eventName should be string!")
        TriggerClientEvent(eventName, self.source, ...)
    end

    function self.isCurrent()
        return ESX.Players[self.source] == self
    end

    function self.togglePaycheck(toggle)
        self.paycheckEnabled = toggle
    end

    function self.isPaycheckEnabled()
        return self.paycheckEnabled
    end

    function self.beginAccountOperation()
        if accountMutationsLocked or not self.isCurrent() then
            return false
        end

        pendingAccountOperations = pendingAccountOperations + 1
        return true
    end

    function self.beginAccountShutdown()
        accountMutationsLocked = true
    end

    function self.endAccountOperation()
        if pendingAccountOperations > 0 then
            pendingAccountOperations = pendingAccountOperations - 1
        end
    end

    function self.getPendingAccountOperations()
        return pendingAccountOperations
    end

    function self.setCoords(coordinates)
        local ped <const> = GetPlayerPed(self.source)
        if not DoesEntityExist(ped) then
            return
        end

        local vector = type(coordinates) == "vector4" and coordinates
            or type(coordinates) == "vector3" and vector4(coordinates, 0.0)
            or vec(coordinates.x, coordinates.y, coordinates.z, coordinates.heading or 0.0)

        SetEntityCoords(ped, vector.xyz, false, false, false, false)
        SetEntityHeading(ped, vector.w)
    end

    function self.getCoords(vector)
        local ped <const> = GetPlayerPed(self.source)
        if DoesEntityExist(ped) then
            local coordinates = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local liveCoords = {
                x = ESX.Math.Round(coordinates.x, 1),
                y = ESX.Math.Round(coordinates.y, 1),
                z = ESX.Math.Round(coordinates.z, 1),
                heading = ESX.Math.Round(heading, 1),
            }

            if Core.IsValidPosition(liveCoords) then
                self.coords = liveCoords
            end
        end

        if not Core.IsValidPosition(self.coords) then
            self.coords = Config.DefaultSpawns[1] or { x = 222.2, y = -864.0, z = 30.3, heading = 1.0 }
        end

        if vector then
            return vector4(self.coords.x, self.coords.y, self.coords.z, self.coords.heading or 0.0)
        end

        return self.coords
    end

    function self.kick(reason)
        DropPlayer(tostring(self.source), reason)
    end

    function self.getPlayTime()
        return self.metadata.lastPlaytime + GetPlayerTimeOnline(self.source)
    end

    function self.setMoney(money, reason)
        assert(type(money) == "number", "money should be number!")
        money = ESX.Math.Round(money)
        return self.setAccountMoney("money", money, reason)
    end

    function self.getMoney()
        return self.getAccount("money").money
    end

    function self.addMoney(money, reason)
        money = ESX.Math.Round(money)
        return self.addAccountMoney("money", money, reason)
    end

    function self.removeMoney(money, reason)
        money = ESX.Math.Round(money)
        return self.removeAccountMoney("money", money, reason)
    end

    function self.getIdentifier()
        return self.identifier
    end

    function self.getSsn()
        return self.ssn
    end

    function self.setGroup(newGroup)
        local lastGroup = self.group

        ExecuteCommand(("remove_principal identifier.%s group.%s"):format(self.license, self.group))
        self.group = newGroup
        self.isDirty = true
        Player(self.source).state:set("group", self.group, true)
        self.admin = Core.IsPlayerAdmin(self.source)
        ExecuteCommand(("add_principal identifier.%s group.%s"):format(self.license, self.group))

        TriggerEvent("esx:setGroup", self.source, self.group, lastGroup)
        self.triggerEvent("esx:setGroup", self.group, lastGroup)
    end

    function self.getGroup()
        return self.group
    end

    function self.set(k, v, replicate)
        self.variables[k] = v
        self.triggerEvent("esx:updatePlayerData", "variables", self.variables)
        if replicate ~= false then
            Player(self.source).state:set(k, v, true)
        end
    end

    function self.get(k)
        return self.variables[k]
    end

    function self.getAccounts(minimal)
        if not minimal then
            return self.accounts
        end

        local minimalAccounts = {}
        for i = 1, #self.accounts do
            minimalAccounts[self.accounts[i].name] = self.accounts[i].money
        end

        return minimalAccounts
    end

    function self.getAccount(account)
        return accountsByName[string.lower(account)]
    end

    function self.getInventory(minimal)
        if not minimal then
            return self.inventory
        end

        local minimalInventory = {}
        for _, v in ipairs(self.inventory) do
            if v.count > 0 then
                minimalInventory[v.name] = v.count
            end
        end

        return minimalInventory
    end

    function self.getJob()
        return self.job
    end

    function self.getLoadout(minimal)
        if not minimal then
            return self.loadout
        end

        local minimalLoadout = {}
        for _, v in ipairs(self.loadout) do
            minimalLoadout[v.name] = { ammo = v.ammo }
            if v.tintIndex > 0 then
                minimalLoadout[v.name].tintIndex = v.tintIndex
            end

            if #v.components > 0 then
                local components = {}
                for _, component in ipairs(v.components) do
                    if component ~= "clip_default" then
                        components[#components + 1] = component
                    end
                end
                if #components > 0 then
                    minimalLoadout[v.name].components = components
                end
            end
        end

        return minimalLoadout
    end

    function self.getName()
        return self.name
    end

    function self.setName(newName)
        self.name = newName
        self.isDirty = true
        Player(self.source).state:set("name", self.name, true)
    end

    function self.setAccountMoney(accountName, money, reason)
        reason = reason or "unknown"
        if not tonumber(money) then
            print(("[^1ERROR^7] Tried To Set Account ^5%s^0 For Player ^5%s^0 To An Invalid Number -> ^5%s^7"):format(accountName, self.playerId, money))
            return false
        end
        if money >= 0 then
            local account = self.getAccount(accountName)

            if account and self.beginAccountOperation() then
                money = account.round and ESX.Math.Round(money) or money
                self.accounts[account.index].money = money
                self.isDirty = true

                self.triggerEvent("esx:setAccountMoney", account)
                TriggerEvent("esx:setAccountMoney", self.source, accountName, money, reason)
                self.endAccountOperation()
                return true
            end
        else
            print(("[^1ERROR^7] Tried To Set Account ^5%s^0 For Player ^5%s^0 To A Invalid Number -> ^5%s^7"):format(accountName, self.playerId, money))
        end

        return false
    end

    function self.addAccountMoney(accountName, money, reason)
        reason = reason or "unknown"
        if not tonumber(money) then
            print(("[^1ERROR^7] Tried To Add Account ^5%s^0 For Player ^5%s^0 To An Invalid Number -> ^5%s^7"):format(accountName, self.playerId, money))
            return false
        end
        if money > 0 then
            local account = self.getAccount(accountName)
            if account and self.beginAccountOperation() then
                money = account.round and ESX.Math.Round(money) or money
                self.accounts[account.index].money = self.accounts[account.index].money + money
                self.isDirty = true

                self.triggerEvent("esx:setAccountMoney", account)
                TriggerEvent("esx:addAccountMoney", self.source, accountName, money, reason)
                self.endAccountOperation()
                return true
            end
        else
            print(("[^1ERROR^7] Tried To Add Account ^5%s^0 For Player ^5%s^0 To A Invalid Number -> ^5%s^7"):format(accountName, self.playerId, money))
        end

        return false
    end

    function self.removeAccountMoney(accountName, money, reason)
        reason = reason or "unknown"
        if not tonumber(money) then
            print(("[^1ERROR^7] Tried To Remove Account ^5%s^0 For Player ^5%s^0 To An Invalid Number -> ^5%s^7"):format(accountName, self.playerId, money))
            return false
        end
        if money > 0 then
            local account = self.getAccount(accountName)

            if account and self.beginAccountOperation() then
                money = account.round and ESX.Math.Round(money) or money
                if self.accounts[account.index].money - money > self.accounts[account.index].money then
                    print(("[^1ERROR^7] Tried To Underflow Account ^5%s^0 For Player ^5%s^0!"):format(accountName, self.playerId))
                    self.endAccountOperation()
                    return false
                end
                self.accounts[account.index].money = self.accounts[account.index].money - money
                self.isDirty = true

                self.triggerEvent("esx:setAccountMoney", account)
                TriggerEvent("esx:removeAccountMoney", self.source, accountName, money, reason)
                self.endAccountOperation()
                return true
            end
        else
            print(("[^1ERROR^7] Tried To Remove Account ^5%s^0 For Player ^5%s^0 To A Invalid Number -> ^5%s^7"):format(accountName, self.playerId, money))
        end

        return false
    end

    function self.getInventoryItem(itemName)
        local active = invByName[itemName]
        if active then
            return active
        end

        local tpl = ESX.Items[itemName]
        if not tpl then
            return nil
        end

        return {
            name = itemName,
            count = 0,
            label = tpl.label,
            weight = tpl.weight,
            limit = tpl.limit or -1,
            usable = Core.UsableItemsCallbacks[itemName] ~= nil,
            rare = tpl.rare,
            canRemove = tpl.canRemove,
        }
    end

    function self.addInventoryItem(itemName, count)
        count = ESX.Math.Round(count)
        if count <= 0 then
            return
        end

        local item = invByName[itemName]
        if not item then
            local tpl = ESX.Items[itemName]
            if not tpl then
                return
            end
            item = {
                name = itemName,
                count = count,
                label = tpl.label,
                weight = tpl.weight,
                limit = tpl.limit or -1,
                usable = Core.UsableItemsCallbacks[itemName] ~= nil,
                rare = tpl.rare,
                canRemove = tpl.canRemove,
            }
            self.inventory[#self.inventory + 1] = item
            invByName[itemName] = item
            table.sort(self.inventory, compareByLabel)
        else
            item.count = item.count + count
        end

        self.weight = self.weight + (item.weight * count)
        self.isDirty = true

        TriggerEvent("esx:onAddInventoryItem", self.source, item.name, item.count)
        self.triggerEvent("esx:addInventoryItem", item.name, item.count, false, item)
    end

    function self.removeInventoryItem(itemName, count)
        count = ESX.Math.Round(count)
        if count <= 0 then
            return
        end

        local item = invByName[itemName]
        if not item then
            return
        end

        local newCount = item.count - count
        if newCount > 0 then
            self.weight = self.weight - (item.weight * count)
            item.count = newCount
            self.isDirty = true

            TriggerEvent("esx:onRemoveInventoryItem", self.source, item.name, item.count)
            self.triggerEvent("esx:removeInventoryItem", item.name, item.count)
        else
            local removed = item.count
            self.weight = self.weight - (item.weight * removed)
            item.count = 0
            invByName[itemName] = nil
            for i = 1, #self.inventory do
                if self.inventory[i] == item then
                    table.remove(self.inventory, i)
                    break
                end
            end
            self.isDirty = true

            TriggerEvent("esx:onRemoveInventoryItem", self.source, item.name, 0)
            self.triggerEvent("esx:removeInventoryItem", item.name, 0)
        end
    end

    function self.setInventoryItem(itemName, count)
        local item = self.getInventoryItem(itemName)

        if item and count >= 0 then
            count = ESX.Math.Round(count)

            if count > item.count then
                self.addInventoryItem(item.name, count - item.count)
            else
                self.removeInventoryItem(item.name, item.count - count)
            end
        end
    end

    function self.getWeight()
        return self.weight
    end

    function self.getMaxWeight()
        return self.maxWeight
    end

    function self.canCarryItem(itemName, count)
        local tpl = ESX.Items[itemName]
        if not tpl then
            print(("[^3WARNING^7] Item ^5'%s'^7 was used but does not exist!"):format(itemName))
            return false
        end

        if count <= 0 then
            return true
        end

        local currentCount = invByName[itemName] and invByName[itemName].count or 0
        local itemLimit = tpl.limit or -1
        if itemLimit ~= -1 and (currentCount + count) > itemLimit then
            return false
        end

        local newWeight = self.weight + (tpl.weight * count)
        return newWeight <= self.maxWeight
    end

    function self.canSwapItem(firstItem, firstItemCount, testItem, testItemCount)
        local firstItemObject = invByName[firstItem]
        local testTpl = ESX.Items[testItem]
        if not firstItemObject or not testTpl then
            return false
        end

        if firstItemObject.count < firstItemCount then
            return false
        end

        local currentTestCount = invByName[testItem] and invByName[testItem].count or 0
        local testLimit = testTpl.limit or -1
        if testLimit ~= -1 and (currentTestCount + testItemCount) > testLimit then
            return false
        end

        local weightWithoutFirstItem = ESX.Math.Round(self.weight - (firstItemObject.weight * firstItemCount))
        local weightWithTestItem = ESX.Math.Round(weightWithoutFirstItem + (testTpl.weight * testItemCount))
        return weightWithTestItem <= self.maxWeight
    end

    function self.setMaxWeight(newWeight)
        self.maxWeight = newWeight
        self.triggerEvent("esx:setMaxWeight", self.maxWeight)
    end

    function self.setJob(newJob, grade, onDuty)
        grade = tostring(grade)
        local lastJob = self.job

        if not ESX.DoesJobExist(newJob, grade) then
            return print(("[ESX] [^3WARNING^7] Ignoring invalid ^5.setJob()^7 usage for ID: ^5%s^7, Job: ^5%s^7"):format(self.source, newJob))
        end

        if newJob == "unemployed" then
            onDuty = false
        end

        if type(onDuty) ~= "boolean" then
            onDuty = Config.DefaultJobDuty
        end

        local jobObject, gradeObject = ESX.Jobs[newJob], ESX.Jobs[newJob].grades[grade]

        self.job = {
            id = jobObject.id,
            name = jobObject.name,
            label = jobObject.label,
            type = jobObject.type,
            onDuty = onDuty,

            grade = tonumber(grade) or 0,
            grade_name = gradeObject.name,
            grade_label = gradeObject.label,
            grade_salary = gradeObject.salary,

            skin_male = decodeJobSkin(gradeObject.skin_male),
            skin_female = decodeJobSkin(gradeObject.skin_female),
        }

        self.metadata.jobDuty = onDuty
        self.isDirty = true
        TriggerEvent("esx:setJob", self.source, self.job, lastJob)
        self.triggerEvent("esx:setJob", self.job, lastJob)
        Player(self.source).state:set("job", self.job, true)
    end

    function self.refreshJob()
        local jobObject = ESX.Jobs[self.job.name]
        local gradeObject = jobObject and jobObject.grades[tostring(self.job.grade)]

        if not gradeObject then
            self.setJob("unemployed", 0, false)
            return false
        end

        local lastJob = copyJob(self.job)

        self.job = {
            id = jobObject.id,
            name = jobObject.name,
            label = jobObject.label,
            type = jobObject.type,
            onDuty = lastJob.onDuty,

            grade = lastJob.grade,
            grade_name = gradeObject.name,
            grade_label = gradeObject.label,
            grade_salary = gradeObject.salary,

            skin_male = decodeJobSkin(gradeObject.skin_male),
            skin_female = decodeJobSkin(gradeObject.skin_female),
        }

        TriggerEvent("esx:jobDataRefreshed", self.source, self.job, lastJob)
        self.triggerEvent("esx:jobDataRefreshed", self.job, lastJob)
        Player(self.source).state:set("job", self.job, true)

        return true
    end

    function self.addWeapon(weaponName, ammo)
        if not self.hasWeapon(weaponName) then
            local weaponLabel <const> = ESX.GetWeaponLabel(weaponName)

            table.insert(self.loadout, {
                name = weaponName,
                ammo = ammo,
                label = weaponLabel,
                components = {},
                tintIndex = 0,
            })

            self.isDirty = true
            GiveWeaponToPed(GetPlayerPed(self.source), joaat(weaponName), ammo, false, false)
            self.triggerEvent("esx:showInventoryItemNotification", true, weaponLabel, 1)
            self.triggerEvent("esx:addLoadoutItem", weaponName, weaponLabel, ammo)
            return true
        end

        return false
    end

    function self.addWeaponComponent(weaponName, weaponComponent)
        local loadoutNum <const>, weapon <const> = self.getWeapon(weaponName)

        if weapon then
            local component = ESX.GetWeaponComponent(weaponName, weaponComponent)

            if component then
                if not self.hasWeaponComponent(weaponName, weaponComponent) then
                    self.loadout[loadoutNum].components[#self.loadout[loadoutNum].components + 1] = weaponComponent
                    self.isDirty = true
                    local componentHash = ESX.GetWeaponComponent(weaponName, weaponComponent).hash
                    GiveWeaponComponentToPed(GetPlayerPed(self.source), joaat(weaponName), componentHash)
                    self.triggerEvent("esx:showInventoryItemNotification", true, component.label, 1)
                    return true
                end
            end
        end

        return false
    end

    function self.addWeaponAmmo(weaponName, ammoCount)
        local _, weapon = self.getWeapon(weaponName)

        if weapon then
            weapon.ammo = weapon.ammo + ammoCount
            self.isDirty = true
            SetPedAmmo(GetPlayerPed(self.source), joaat(weaponName), weapon.ammo)
            self.triggerEvent("esx:updateWeaponAmmo", weaponName, weapon.ammo)
            return true
        end

        return false
    end

    function self.updateWeaponAmmo(weaponName, ammoCount)
        local _, weapon = self.getWeapon(weaponName)

        if not weapon then
            return false
        end

        weapon.ammo = ammoCount
        self.isDirty = true
        self.triggerEvent("esx:updateWeaponAmmo", weaponName, weapon.ammo)

        if weapon.ammo <= 0 then
            local _, weaponConfig = ESX.GetWeapon(weaponName)
            if weaponConfig.throwable then
                self.removeWeapon(weaponName)
            end
        end

        return true
    end

    function self.setWeaponTint(weaponName, weaponTintIndex)
        local loadoutNum <const>, weapon <const> = self.getWeapon(weaponName)

        if weapon then
            local _, weaponObject <const> = ESX.GetWeapon(weaponName)

            if weaponObject.tints and weaponObject.tints[weaponTintIndex] then
                self.loadout[loadoutNum].tintIndex = weaponTintIndex
                self.isDirty = true
                self.triggerEvent("esx:setWeaponTint", weaponName, weaponTintIndex)
                self.triggerEvent("esx:showInventoryItemNotification", true, weaponObject.tints[weaponTintIndex], 1)
                return true
            end
        end

        return false
    end

    function self.getWeaponTint(weaponName)
        local _, weapon <const> = self.getWeapon(weaponName)

        if weapon then
            return weapon.tintIndex
        end

        return 0
    end

    function self.removeWeapon(weaponName)
        local weaponLabel, playerPed <const> = nil, GetPlayerPed(self.source)

        if not playerPed then
            error("xPlayer.removeWeapon ^5invalid^1 player ped!")
        end

        for k, v in ipairs(self.loadout) do
            if v.name == weaponName then
                weaponLabel = v.label

                for _, v2 in ipairs(v.components) do
                    self.removeWeaponComponent(weaponName, v2)
                end

                local weaponHash = joaat(v.name)
                RemoveWeaponFromPed(playerPed, weaponHash)
                SetPedAmmo(playerPed, weaponHash, 0)

                table.remove(self.loadout, k)
                self.isDirty = true
                break
            end
        end

        if weaponLabel then
            self.triggerEvent("esx:showInventoryItemNotification", false, weaponLabel, 1)
            self.triggerEvent("esx:removeLoadoutItem", weaponName, weaponLabel)
            return true
        end

        return false
    end

    function self.removeWeaponComponent(weaponName, weaponComponent)
        local loadoutNum <const>, weapon <const> = self.getWeapon(weaponName)

        if weapon then
            local component <const> = ESX.GetWeaponComponent(weaponName, weaponComponent)

            if component then
                if self.hasWeaponComponent(weaponName, weaponComponent) then
                    for k, v in ipairs(self.loadout[loadoutNum].components) do
                        if v == weaponComponent then
                            table.remove(self.loadout[loadoutNum].components, k)
                            self.isDirty = true
                            break
                        end
                    end

                    self.triggerEvent("esx:removeWeaponComponent", weaponName, weaponComponent)
                    self.triggerEvent("esx:showInventoryItemNotification", false, component.label, 1)
                    return true
                end
            end
        end

        return false
    end

    function self.removeWeaponAmmo(weaponName, ammoCount)
        local _, weapon = self.getWeapon(weaponName)

        if weapon then
            weapon.ammo = weapon.ammo - ammoCount
            self.isDirty = true
            SetPedAmmo(GetPlayerPed(self.source), joaat(weaponName), weapon.ammo)
            self.triggerEvent("esx:updateWeaponAmmo", weaponName, weapon.ammo)
            return true
        end

        return false
    end

    function self.hasWeaponComponent(weaponName, weaponComponent)
        local _, weapon <const> = self.getWeapon(weaponName)

        if weapon then
            for _, v in ipairs(weapon.components) do
                if v == weaponComponent then
                    return true
                end
            end

            return false
        end

        return false
    end

    function self.hasWeapon(weaponName)
        for _, v in ipairs(self.loadout) do
            if v.name == weaponName then
                return true
            end
        end

        return false
    end

    function self.getWeapon(weaponName)
        for k, v in ipairs(self.loadout) do
            if v.name == weaponName then
                return k, v
            end
        end

        return nil, nil
    end

    function self.showNotification(msg, notifyType, length, title, position)
        self.triggerEvent("esx:showNotification", msg, notifyType, length, title, position)
    end

    function self.showAdvancedNotification(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
        self.triggerEvent("esx:showAdvancedNotification", sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
    end

    function self.showHelpNotification(msg, thisFrame, beep, duration)
        self.triggerEvent("esx:showHelpNotification", msg, thisFrame, beep, duration)
    end

    function self.getMeta(index, subIndex)
        if not index then
            return self.metadata
        end

        if type(index) ~= "string" then
            error("xPlayer.getMeta ^5index^1 should be ^5string^1!")
            return
        end

        local metaData = self.metadata[index]
        if metaData == nil then
            return Config.EnableDebug and error(("xPlayer.getMeta ^5%s^1 not exist!"):format(index)) or nil
        end

        if subIndex and type(metaData) == "table" then
            local _type = type(subIndex)

            if _type == "string" then
                return metaData[subIndex]
            end

            if _type == "table" then
                local returnValues = {}

                for i = 1, #subIndex do
                    local key = subIndex[i]
                    if type(key) == "string" then
                        returnValues[key] = self.getMeta(index, key)
                    else
                        error(("xPlayer.getMeta subIndex should be ^5string^1 or ^5table^1! that contains ^5string^1, received ^5%s^1!, skipping..."):format(type(key)))
                    end
                end

                return returnValues
            end

            error(("xPlayer.getMeta subIndex should be ^5string^1 or ^5table^1!, received ^5%s^1!"):format(_type))
            return
        end

        return metaData
    end

    function self.setMeta(index, value, subValue)
        if not index then
            return error("xPlayer.setMeta ^5index^1 is Missing!")
        end

        if type(index) ~= "string" then
            return error("xPlayer.setMeta ^5index^1 should be ^5string^1!")
        end

        if value == nil then
            return error("xPlayer.setMeta value is missing!")
        end

        local _type = type(value)

        if not subValue then
            if _type ~= "number" and _type ~= "string" and _type ~= "table" then
                return error(("xPlayer.setMeta ^5%s^1 should be ^5number^1 or ^5string^1 or ^5table^1!"):format(value))
            end

            self.metadata[index] = value
        else
            if _type ~= "string" then
                return error(("xPlayer.setMeta ^5value^1 should be ^5string^1 as a subIndex!"):format(value))
            end

            if not self.metadata[index] or type(self.metadata[index]) ~= "table" then
                self.metadata[index] = {}
            end

            self.metadata[index] = type(self.metadata[index]) == "table" and self.metadata[index] or {}
            self.metadata[index][value] = subValue
        end
        self.isDirty = true
        self.triggerEvent("esx:updatePlayerData", "metadata", self.metadata)
    end

    function self.clearMeta(index, subValues)
        if not index then
            return error("xPlayer.clearMeta ^5index^1 is Missing!")
        end

        if type(index) ~= "string" then
            return error("xPlayer.clearMeta ^5index^1 should be ^5string^1!")
        end

        local metaData = self.metadata[index]
        if metaData == nil then
            if Config.EnableDebug then
                error(("xPlayer.clearMeta ^5%s^1 does not exist!"):format(index))
            end

            return
        end

        if not subValues then
            self.metadata[index] = nil
        elseif type(subValues) == "string" then
            if type(metaData) == "table" then
                metaData[subValues] = nil
            else
                return error(("xPlayer.clearMeta ^5%s^1 is not a table! Cannot clear subValue ^5%s^1."):format(index, subValues))
            end
        elseif type(subValues) == "table" then
            for i = 1, #subValues do
                local subValue = subValues[i]
                if type(subValue) == "string" then
                    if type(metaData) == "table" then
                        metaData[subValue] = nil
                    else
                        error(("xPlayer.clearMeta ^5%s^1 is not a table! Cannot clear subValue ^5%s^1."):format(index, subValue))
                    end
                else
                    error(("xPlayer.clearMeta subValues should contain ^5string^1, received ^5%s^1, skipping..."):format(type(subValue)))
                end
            end
        else
            return error(("xPlayer.clearMeta ^5subValues^1 should be ^5string^1 or ^5table^1, received ^5%s^1!"):format(type(subValues)))
        end
        self.isDirty = true
        self.triggerEvent("esx:updatePlayerData", "metadata", self.metadata)
    end

    function self.executeCommand(command)
        if type(command) ~= "string" then
            error("xPlayer.executeCommand must be of type string!")
            return
        end

        ExecuteCommand(command)
    end

    if Config.PlayerFunctionOverride and Core.PlayerFunctionOverrides[Config.PlayerFunctionOverride] then
        for fnName, fn in pairs(Core.PlayerFunctionOverrides[Config.PlayerFunctionOverride]) do
            self[fnName] = fn(self)
        end
    end

    return self
end

local function runStaticPlayerMethod(src, method, ...)
    local xPlayer = ESX.Players[src]
    if not xPlayer then
        return
    end

    if not ESX.IsFunctionReference(xPlayer[method]) then
        error(("Invalid method '%s' when calling StaticPlayer!"):format(method))
    end

    return xPlayer[method](...)
end

exports("RunStaticPlayerMethod", runStaticPlayerMethod)
