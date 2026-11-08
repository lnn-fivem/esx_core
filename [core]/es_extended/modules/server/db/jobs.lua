local DefaultJob = {
    name = "unemployed",
    label = "Unemployed",
    type = "civ",
    grades = {
        ["0"] = {
            grade = 0,
            label = "Unemployed",
            name = "unemployed",
            salary = 200,
            skin_male = {},
            skin_female = {},
        },
    },
}

local function decodeGradeSkin(skinJson)
    if type(skinJson) == "table" then
        return skinJson
    end

    if type(skinJson) ~= "string" or skinJson == "" or skinJson == "{}" then
        return {}
    end

    local ok, decoded = pcall(json.decode, skinJson)
    return (ok and type(decoded) == "table") and decoded or {}
end

function ESX.RefreshJobs()
    local Jobs = {}
    local jobs = MySQL.query.await("SELECT * FROM `jobs`")

    for _, v in ipairs(jobs or {}) do
        Jobs[v.name] = v
        Jobs[v.name].grades = {}
    end

    local jobGrades = MySQL.query.await("SELECT * FROM `job_grades`")

    for _, v in ipairs(jobGrades or {}) do
        if Jobs[v.job_name] then
            v.skin_male = decodeGradeSkin(v.skin_male)
            v.skin_female = decodeGradeSkin(v.skin_female)
            Jobs[v.job_name].grades[tostring(v.grade)] = v
        else
            print(("[^3WARNING^7] Ignoring job grades for ^5\"%s\"^0 due to missing job"):format(v.job_name))
        end
    end

    for _, v in pairs(Jobs) do
        if next(v.grades) == nil then
            Jobs[v.name] = nil
            print(("[^3WARNING^7] Ignoring job ^5\"%s\"^0 due to no job grades found"):format(v.name))
        end
    end

    if next(Jobs) == nil then
        ESX.Jobs = { [DefaultJob.name] = DefaultJob }
        print(("[^3WARNING^7] No jobs loaded, Fallback to DefaultJob ^5\"%s\"^0"):format(ESX.Jobs.unemployed.label))
    else
        ESX.Jobs = Jobs
        if not ESX.Jobs[DefaultJob.name] then
            ESX.Jobs[DefaultJob.name] = DefaultJob
        end
    end

    for _, xPlayer in pairs(ESX.Players) do
        if xPlayer and xPlayer.refreshJob then
            xPlayer.refreshJob()
        end
    end

    Core.JobsLoaded = true
    TriggerEvent("esx:JobsLoaded", ESX.Jobs)
end

function ESX.GetJobs()
    return ESX.Jobs
end

function ESX.DoesJobExist(job, grade)
    return (job and grade and ESX.Jobs[job] and ESX.Jobs[job].grades[tostring(grade)] ~= nil) or false
end
