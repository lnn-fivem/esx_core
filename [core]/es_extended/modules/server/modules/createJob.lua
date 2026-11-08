local NOTIFY_TYPES = {
    INFO = "^5[INFO]^7",
    SUCCESS = "^2[SUCCESS]^7",
    ERROR = "^1[ERROR]^7",
}

local function notify(messageType, message, ...)
    if not NOTIFY_TYPES[messageType] then
        return
    end

    return print(("%s %s"):format(NOTIFY_TYPES[messageType], message:format(...)))
end

local function doesJobAndGradesExist(name, grades)
    if ESX.Jobs[name] then
        return true
    end

    for _, grade in ipairs(grades) do
        if not tonumber(grade.grade) then
            return false
        end

        if ESX.DoesJobExist(name, grade.grade) then
            return true
        end
    end

    return false
end

local function generateNewJobTable(name, label, grades)
    local job = { name = name, label = label, grades = {} }
    for _, v in pairs(grades) do
        job.grades[tostring(v.grade)] = { job_name = name, grade = v.grade, name = v.name, label = v.label, salary = v.salary, skin_male = {}, skin_female = {} }
    end

    return job
end

local function addJobToDatabase(name, label, grades)
    local queries = {
        { query = "INSERT INTO jobs (name, label) VALUES (?, ?)", values = { name, label } },
    }

    for _, grade in ipairs(grades) do
        queries[#queries + 1] = {
            query = "INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, '{}', '{}')",
            values = { name, grade.grade, grade.name, grade.label, grade.salary },
        }
    end

    local success = MySQL.transaction.await(queries)
    if not success then
        notify("ERROR", "Failed to create one or more job grades for job: '%s' -> rolling back all changes.", name)
        return
    end

    ESX.Jobs[name] = generateNewJobTable(name, label, grades)
    notify("SUCCESS", "Job created successfully: '%s'", name)

    TriggerEvent("esx:jobCreated", name, ESX.Jobs[name])
end

--- Create a new job with specified grades
---@param name string The name of the job
---@param label string The label of the job
---@param grades table The grades of the job
function ESX.CreateJob(name, label, grades)
    if not name or name == "" then
        notify("ERROR", "Missing argument `name`")
        return
    end

    if not label or label == "" then
        notify("ERROR", "Missing argument `label`")
        return
    end

    if not grades or not next(grades) then
        notify("ERROR", "Missing argument `grades`")
        return
    end

    local currentJobExist = doesJobAndGradesExist(name, grades)
    if currentJobExist then
        notify("ERROR", "Job or grades already exists: '%s'", name)
        return
    end

    addJobToDatabase(name, label, grades)
end
