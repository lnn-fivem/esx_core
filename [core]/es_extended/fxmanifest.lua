fx_version "cerulean"

game "gta5"
description "esx_core optimized by lnn"
author "LNN (Based on ESX-Framework)"
lua54 "yes"
version "1.0.0"

shared_scripts {
    "locale.lua",

    "shared/config/main.lua",
    "shared/config/items.lua",
    "shared/config/weapons.lua",
    "shared/config/adjustments.lua",

    "modules/shared/boot.lua",
    "modules/shared/math.lua",
    "modules/shared/table.lua",
    "modules/shared/timeout.lua",
    "modules/shared/functions.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "shared/config/logs.lua",

    "modules/server/boot.lua",
    "modules/server/callbacks.lua",
    "modules/server/db/save.lua",
    "modules/server/db/jobs.lua",
    "modules/server/db/ssn.lua",
    "modules/server/inventory.lua",
    "modules/server/functions.lua",
    "modules/server/player/factory.lua",
    "modules/server/player/overrides/*.lua",
    "modules/server/vehicle.lua",
    "modules/server/scheduler.lua",
    "modules/server/main.lua",

    "modules/server/bridge/**/*.lua",
    "modules/server/modules/*.lua",

    "modules/server/migration/**/main.lua",
    "modules/server/migration/main.lua",
}

client_scripts {
    "modules/client/boot.lua",
    "modules/client/functions.lua",
    "modules/client/modules/wrapper.lua",
    "modules/client/modules/callback.lua",
    "modules/client/modules/adjustments.lua",
    "modules/client/modules/points.lua",
    "modules/client/modules/events.lua",
    "modules/client/modules/actions.lua",
    "modules/client/modules/death.lua",
    "modules/client/modules/interactions.lua",
    "modules/client/modules/scaleform.lua",
    "modules/client/modules/streaming.lua",
    "modules/client/modules/npwd.lua",
}

ui_page {
    "html/ui.html",
}

files {
    "imports.lua",
    "locale.js",
    "locales/*.lua",
    "shared/config/items.lua",
    "html/ui.html",
    "html/css/app.css",
    "html/js/mustache.min.js",
    "html/js/wrapper.js",
    "html/js/app.js",
    "html/fonts/pdown.ttf",
    "html/fonts/bankgothic.ttf",
    "client/imports/*.lua",
}

dependencies {
    "/native:0x6AE51D4B",
    "/native:0xA61C8FC6",
    "oxmysql",
}
