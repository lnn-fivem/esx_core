local SSN_BATCH_SIZE <const> = 8

local function formatRandomSSN()
    return ("%03d-%02d-%04d"):format(
        math.random(0, 999),
        math.random(0, 99),
        math.random(0, 9999)
    )
end

---@param onlyFormat? boolean
---@return string
function Core.generateSSN(onlyFormat)
    if onlyFormat then
        return formatRandomSSN()
    end

    while true do
        local candidates = {}
        local seen = {}
        for i = 1, SSN_BATCH_SIZE do
            local ssn
            repeat
                ssn = formatRandomSSN()
            until not seen[ssn]
            seen[ssn] = true
            candidates[i] = ssn
        end

        local taken = MySQL.query.await(
            "SELECT `ssn` FROM `users` WHERE `ssn` IN (?, ?, ?, ?, ?, ?, ?, ?)",
            candidates
        )
        local takenSet = {}
        if taken then
            for i = 1, #taken do
                takenSet[taken[i].ssn] = true
            end
        end

        for i = 1, SSN_BATCH_SIZE do
            if not takenSet[candidates[i]] then
                return candidates[i]
            end
        end
    end
end
