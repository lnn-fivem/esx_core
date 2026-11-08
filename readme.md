<h1 align="center">esx_core (Optimized by LNN)</h1>
<p align="center">
  <b>High-Performance, Standalone Drop-in Replacement for ESX Legacy (esx_core)</b><br>
  Maintained by <a href="https://github.com/lnn-fivem">LNN FiveM</a>
</p>

<hr>

## 🚀 Key Optimizations by LNN

1. **Zero-SQL File-Based Item Registry (`shared/config/items.lua`)**
   - Items are loaded directly into memory from `shared/config/items.lua` on both Server & Client instead of querying the `items` SQL table.
   - Supports hot-reloading at runtime via `/refreshitems` or `ESX.RefreshItems()`, and dynamic item registration via `ESX.AddItems(items)`.
   - Dual support for **Weight (`weight`)** and **Stack Limit (`limit`)** systems in `canCarryItem` and `canSwapItem`.

2. **Sparse Player Inventory & $O(1)$ Indexing (`modules/server/player/factory.lua`)**
   - `xPlayer.inventory` only stores items with `count > 0` in memory and network payloads, drastically reducing memory footprint and `esx:playerLoaded` packet size.
   - Closure-local $O(1)$ hash maps (`invByName`, `accountsByName`) eliminate linear array scans on `getInventoryItem` and `getAccount`.
   - `xPlayer.getInventoryItem(name)` and `ESX.SearchInventory(name)` automatically construct zero-count fallback objects for valid items in `ESX.Items` so legacy scripts never fail with `nil` index errors.

3. **Dirty-Flag Tracking & Chunked Batch Persistence (`modules/server/db/save.lua`)**
   - Tracks state mutations via `xPlayer.isDirty = true` (money, accounts, inventory, job, group, loadout, metadata).
   - Periodic background sync (`Core.SaveDirtyPlayers`) only saves players whose data actually changed, serializing JSON in chunks (`Config.SaveSerializeChunk = 50` with `Wait(0)`) and executing batched `MySQL.prepare.await` (`Config.SaveBatchSize = 100`).
   - Includes per-identifier persistence locks (`Core.WithPlayerPersistence`) and queued saves (`Core.SavePlayer`) to prevent race conditions during character switch/disconnect.
   - Built-in coordinate validation (`Core.IsValidPosition`) prevents deleted peds on `playerDropped` from corrupting saved coordinates.

4. **Reverse Job Index (`Core.playersByJob`)**
   - `ESX.GetExtendedPlayers("job", jobName)` uses an $O(1)$ reverse index maintained on `esx:playerLoaded`, `esx:setJob`, and `playerDropped` instead of iterating all online players.

5. **Single-Thread Paycheck & Native DB Sync Scheduler (`modules/server/scheduler.lua`)**
   - Single-thread join-relative paycheck scheduler capped at `MAX_PAYCHECKS_PER_TICK = 50` per frame with society account caching.
   - Built-in native timer threads for `StartDBSync()` and `StartHealthSampler()` — no external `cron` resource required.

6. **Optimized Client Loops & Pre-Packed Multicast (`modules/client/*`)**
   - `ESX.TriggerClientEvent` pre-packs arguments once with `msgpack.pack_args` before broadcasting to multiple players.
   - Pickup thread sleeps `1500ms` when no pickups exist on the map (`next(pickups) == nil`).
   - Ped/vehicle/weapon/pause-menu tracking consolidated into a `200ms` loop with lazy `ESX.PlayerData.coords` metatable lookup.

---

## 📂 Directory Structure (`[core]/es_extended`)

```text
[core]/es_extended/
├── fxmanifest.lua
├── imports.lua
├── locale.lua
├── locale.js
├── shared/
│   └── config/
│       ├── main.lua          # Main configuration + LNN optimization settings
│       ├── items.lua         # Local item registry (weight & limit support)
│       ├── weapons.lua       # Weapons & components catalog
│       ├── adjustments.lua   # Client HUD/world adjustments
│       └── logs.lua          # Discord webhook configuration
├── modules/
│   ├── shared/               # math, table, timeout, functions, boot
│   ├── server/               # boot, callbacks, inventory, functions, scheduler, vehicle, main
│   │   ├── db/               # save.lua, jobs.lua, ssn.lua
│   │   ├── player/           # factory.lua + overrides/oxinventory.lua
│   │   ├── bridge/           # inventory/oxinventory.lua
│   │   ├── modules/          # commands.lua, createJob.lua, onesync.lua, npwd.lua
│   │   └── migration/        # Automatic database schema migrations
│   └── client/               # boot, functions, modules/* (events, actions, points, etc.)
└── client/
    └── imports/              # class.lua, point.lua
```
