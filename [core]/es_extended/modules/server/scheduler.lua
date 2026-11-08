local nextPaycheckAt = {}
local PAYCHECK_TICK_MS <const> = 1000
local MAX_PAYCHECKS_PER_TICK <const> = 50

AddEventHandler("esx:playerLoaded", function(playerId)
    nextPaycheckAt[playerId] = GetGameTimer() + Config.PaycheckInterval
end)

AddEventHandler("esx:playerDropped", function(playerId)
    nextPaycheckAt[playerId] = nil
end)

local function payFromSocietyIfPossible(xPlayer, job, jobLabel, salary, societyCache)
    local cached = societyCache[job]
    if cached == nil then
        local resolved = false
        TriggerEvent("esx_society:getSociety", job, function(s)
            resolved = s or false
        end)
        societyCache[job] = resolved
        cached = resolved
    end

    if not cached then
        xPlayer.addAccountMoney("bank", salary, "Paycheck")
        xPlayer.showAdvancedNotification(TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
        if Config.LogPaycheck then
            ESX.DiscordLogFields("Paycheck", "Paycheck - " .. jobLabel, "green", {
                { name = "Player", value = xPlayer.name, inline = true },
                { name = "ID", value = xPlayer.source, inline = true },
                { name = "Amount", value = salary, inline = true },
            })
        end
        return
    end

    TriggerEvent("esx_addonaccount:getSharedAccount", cached.account, function(account)
        if account and account.money >= salary then
            xPlayer.addAccountMoney("bank", salary, "Paycheck")
            account.removeMoney(salary)
            xPlayer.showAdvancedNotification(TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
            if Config.LogPaycheck then
                ESX.DiscordLogFields("Paycheck", "Paycheck - " .. cached.label, "green", {
                    { name = "Player", value = xPlayer.name, inline = true },
                    { name = "ID", value = xPlayer.source, inline = true },
                    { name = "Amount", value = salary, inline = true },
                })
            end
        else
            xPlayer.showAdvancedNotification(TranslateCap("bank"), "", TranslateCap("company_nomoney"), "CHAR_BANK_MAZE", 1)
        end
    end)
end

local function processPlayerPaycheck(xPlayer, societyCache)
    local job = xPlayer.job.name
    local jobLabel = xPlayer.job.label
    local grade = xPlayer.job.grade_name
    local onDuty = xPlayer.job.onDuty
    local salary = (grade == "unemployed" or onDuty) and xPlayer.job.grade_salary or ESX.Math.Round(xPlayer.job.grade_salary * Config.OffDutyPaycheckMultiplier)

    if not xPlayer.paycheckEnabled or salary <= 0 then
        return
    end

    if grade == "unemployed" then
        xPlayer.addAccountMoney("bank", salary, "Welfare Check")
        xPlayer.showAdvancedNotification(TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_help", salary), "CHAR_BANK_MAZE", 9)
        if Config.LogPaycheck then
            ESX.DiscordLogFields("Paycheck", "Paycheck - Unemployment Benefits", "green", {
                { name = "Player", value = xPlayer.name, inline = true },
                { name = "ID", value = xPlayer.source, inline = true },
                { name = "Amount", value = salary, inline = true },
            })
        end
    elseif Config.EnableSocietyPayouts then
        payFromSocietyIfPossible(xPlayer, job, jobLabel, salary, societyCache)
    else
        xPlayer.addAccountMoney("bank", salary, "Paycheck")
        xPlayer.showAdvancedNotification(TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
        if Config.LogPaycheck then
            ESX.DiscordLogFields("Paycheck", "Paycheck - " .. jobLabel, "green", {
                { name = "Player", value = xPlayer.name, inline = true },
                { name = "ID", value = xPlayer.source, inline = true },
                { name = "Amount", value = salary, inline = true },
            })
        end
    end
end

function StartPayCheck()
    local initNow = GetGameTimer()
    for src in pairs(ESX.Players) do
        if not nextPaycheckAt[src] then
            nextPaycheckAt[src] = initNow + Config.PaycheckInterval
        end
    end

    CreateThread(function()
        while true do
            Wait(PAYCHECK_TICK_MS)

            local now = GetGameTimer()
            local interval = Config.PaycheckInterval
            local societyCache = Config.EnableSocietyPayouts and {} or nil
            local processed = 0

            for src, dueAt in pairs(nextPaycheckAt) do
                if now >= dueAt then
                    local xPlayer = ESX.Players[src]
                    if not xPlayer then
                        nextPaycheckAt[src] = nil
                    else
                        nextPaycheckAt[src] = now + interval
                        processPlayerPaycheck(xPlayer, societyCache)
                        processed = processed + 1
                        if processed >= MAX_PAYCHECKS_PER_TICK then
                            break
                        end
                    end
                end
            end
        end
    end)
end

function StartDBSync()
    local saveInterval = tonumber(Config.SaveInterval) or (5 * 60000)
    if saveInterval <= 0 then
        return
    end

    CreateThread(function()
        while true do
            Wait(saveInterval)
            Core.SaveDirtyPlayers()
        end
    end)
end

function StartHealthSampler()
    local interval = tonumber(Config.HealthSampleInterval) or 30000
    if interval <= 0 then
        return
    end

    CreateThread(function()
        while true do
            Wait(interval)
            Core.SampleHealthAndArmor()
        end
    end)
end
