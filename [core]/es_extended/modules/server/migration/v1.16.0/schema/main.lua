local esxVersion = "v1.16.0"

Core.Migrations = Core.Migrations or {}
Core.Migrations[esxVersion] = Core.Migrations[esxVersion] or {}

if GetResourceKvpInt(("esx_migration:%s"):format(esxVersion)) == 1 then
    return
end

local function getColumnInfo(tableName, columnName)
    return MySQL.single.await([[
        SELECT DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, COLUMN_DEFAULT
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
          AND COLUMN_NAME = ?
    ]], { tableName, columnName })
end

local function widenVarchar(tableName, columnName, targetLen)
    local col = getColumnInfo(tableName, columnName)
    if not col then
        return false
    end

    if col.DATA_TYPE == "varchar" and tonumber(col.CHARACTER_MAXIMUM_LENGTH) and tonumber(col.CHARACTER_MAXIMUM_LENGTH) < targetLen then
        local nullable = col.IS_NULLABLE == "YES" and "NULL" or "NOT NULL"
        MySQL.update.await(("ALTER TABLE `%s` MODIFY COLUMN `%s` VARCHAR(%d) %s"):format(tableName, columnName, targetLen, nullable))
        return true
    end

    return false
end

Core.Migrations[esxVersion].addonCompatibility = function()
    widenVarchar("billing", "target", 60)
    widenVarchar("rented_vehicles", "owner", 60)

    local targets = {
        { "billing", "identifier" },
        { "owned_vehicles", "owner" },
        { "user_licenses", "owner" },
        { "society_moneywash", "identifier" },
        { "addon_account_data", "owner" },
        { "addon_inventory_items", "owner" },
        { "datastore_data", "owner" },
    }

    for i = 1, #targets do
        local tableName = targets[i][1]
        local columnName = targets[i][2]

        if getColumnInfo(tableName, columnName) then
            local indexed = MySQL.scalar.await(
                [[
                SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
                    AND SEQ_IN_INDEX = 1 AND SUB_PART IS NULL
            ]],
                { tableName, columnName }
            )

            if indexed and tonumber(indexed) == 0 then
                MySQL.query.await(
                    ("CREATE INDEX `esx_1160_%s_%s` ON `%s` (`%s`)"):format(
                        tableName,
                        columnName,
                        tableName,
                        columnName
                    )
                )
            end
        end
    end

    return false
end
