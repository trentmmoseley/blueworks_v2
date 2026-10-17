# AGENTS.md

## Project overview

**blueworks_v2** is a Roblox first-person combat game written in **Luau**. The Rojo project name is `blueworks`, and the Wally package is `trent-moseley/blueworks` version `0.1.0`.

The game includes projectile firearms, melee and unarmed combat, inventories and dropped loot, movement and stamina, teams, status effects, server-side NPCs, persistent player settings/keybinds, client-side VFX, and ragdoll deaths. `src/` is the Rojo-managed source tree. The local place file is `blueworks_v2.rbxlx`; it is ignored by Git.

## Configuration and technology stack

Key root files:

- `default.project.json` — Rojo project. It maps `src/ReplicatedFirst`, `src/ReplicatedStorage`, `src/ServerScriptService`, `src/StarterGui`, and the two `src/StarterPlayer` folders into the DataModel. It also sets Workspace filtering/input properties and `SoundService.RespectFilteringEnabled`.
- `aftman.toml` — pinned tools: **Rojo 7.7.0**, **Wally 0.3.2**, and **Selene 0.29.0**, installed through Aftman.
- `wally.toml` — direct Wally dependencies. `wally.lock` is generated and records the resolved versions; do not edit it manually.
- `selene.toml` — Selene with the Roblox standard library and project-specific lint rule settings.
- `.gitignore` — ignores the place file, Studio place-lock files, and `sourcemap.json`.
- `README.md` — minimal Rojo build and Studio workflow.

Resolved direct dependencies in `wally.lock` are Knit `1.7.0`, Red `2.3.2`, Guard `1.0.1`, FastCastRedux `0.1.3`, and ProfileStore `1.0.3`. Wally-generated shared packages live in `src/ReplicatedStorage/Packages/`; the server-only ProfileStore package lives in `src/ServerScriptService/Libraries/ProfileStore/`. Their `_Index` directories and one-line package linkers are generated code. SmartBone and ShapecastHitbox are separately vendored under `src/ReplicatedStorage/Modules/`.

## Build, sync, and lint commands

Run commands from the repository root:

```bash
aftman install                      # install the pinned toolchain
wally install                       # install/regenerate Wally dependencies
rojo build -o "blueworks_v2.rbxlx" # build the place from default.project.json
rojo serve                          # serve the project for live Studio sync
selene src                          # lint the source tree
```

The README's workflow is to build/open the place in Roblox Studio and run `rojo serve` for live sync. There are no npm, Python, Rust, or other package/build wrappers in this repository.

## Source layout and main modules

- `src/ServerScriptService/Server.server.lua` — server entry point. It initializes Signal, Red, Knit, and the VMAnim Red endpoint; adds all services; starts Knit; configures ProximityPrompt defaults; initializes map interactables; and currently spawns a `Proxy` NPC.
- `src/ServerScriptService/Libraries/Services/` — Knit services grouped by gameplay domain: characters, combat/health, guns/melee/punching, inventory, movement, effects, NPCs, map interactions, teams, scoring, communication, settings, VFX, loot/sounds, persistence, metadata, and round progress. `CharacterService.lua` creates the service named **`CharService`**. `InventoryService`, `NPCService`, and `MapService` use `init.lua` plus child modules. `_templateService.lua` is the service template.
- `src/ServerScriptService/Libraries/Classes/CharacterClass/` — server-side per-character composition used for both players and NPCs. The parent constructs Ammo, Effect, Gun, Health, Hitbox, Inventory, Lean, Movement, Noise, Score, Stamina, and Team classes.
- `src/StarterGui/SGUI.client.lua` — main client bootstrap and dynamic module loader.
- `src/StarterGui/Libraries/Controllers/` — Knit client controllers (`DataController` plus a template).
- `src/StarterGui/Libraries/Environment/` — camera, gun/projectile, viewmodel, melee, noise, and VFX client logic.
- `src/StarterGui/Libraries/Gui/` — HUD and interface modules for health, stamina, inventory, gun stats, effects, communication, detection, prompts, and performance.
- `src/StarterPlayer/StarterCharacterScripts/SCLocal.client.lua` and `Libraries/` — per-character client bootstrap, movement, leaning, material sounds, stray loot/sound behavior, and client ragdolls. `Animate.client.lua` is also present.
- `src/ReplicatedFirst/SmartBoneRuntime.client.lua` — starts the SmartBone client runtime.
- `src/ReplicatedStorage/Modules/Data/` — static configuration such as `DataTemplate`, `BulletInfo`, `MovementSettings`, `Tiers`, and effect messages.
- `src/ReplicatedStorage/Modules/Util/` — shared helpers for dot-path data access, sounds, gun attachments, inventory replication, welding, springs, pathing, and math.
- `src/ReplicatedStorage/Modules/Environment/FastCastRedux.lua` — linker to the Wally-installed FastCastRedux package used by client projectiles.
- `src/ReplicatedStorage/Modules/SmartBone/` and `ShapecastHitbox/` — vendored third-party code; avoid editing unless a task explicitly requires it.
- `src/ReplicatedStorage/Remotes/` — Red event/function definitions. `GetData` is a `Red.Function`; the other current modules define `Red.Event` instances.
- `src/StarterPlayer/StarterPlayerScripts/` — currently empty; gameplay client code is in StarterGui and StarterCharacterScripts.

### Studio-only instances and assets

The Rojo source tree does not contain the game's models or other place assets. Code expects instances supplied by the place/Studio, including examples such as `Workspace.Playspace`, `ServerStorage.Tools`, `ServerStorage.Player.Character.FootstepSounds`, `ReplicatedStorage.Rigs`, `VFX`, `GameValues`, `Events`, `RemFuncs`, `PlayerRep`, `ServerStats`, and the `Squadmates`/`Spectators` teams.

`$ignoreUnknownInstances = true` is set on each mapped source directory so live sync preserves unknown children below those mapped nodes. It does not add those assets to version control or recreate them in a source-only build. A full gameplay playtest therefore requires the expected place assets, not just the scripts from a fresh clone.

## Runtime architecture

### Startup and Knit

- Knit is the service/controller backbone. Both entry points store Knit in `_G.Knit` and sleitnick Signal `2.0.3` in `_G.Signal`. Server startup sets `_G.Knit.Loaded`; client startup sets `_G.Knit.Ready`.
- Server services are registered with `Knit.AddServices(ServerScriptService.Libraries.Services)` before `Knit.Start()`. Client controllers are registered from StarterGui's `Libraries/Controllers` before client `Knit.Start()`.
- Preserve the explicit Red require and `VMAnim:Server()` initialization in `Server.server.lua`; the source comments mark both as required by the current networking/viewmodel setup.
- The client detects `Desktop`, `Mobile`, or `Console` and fires `CharService.DeviceUpdate`; the server stores the result in the player's `Device` attribute. GUI and character module loading waits for this attribute.

### Characters and combat

- `CharService` manages models in `Workspace.Characters`, wraps each in `CharacterClass`, assigns character IDs/NPC attributes, and configures humanoids for client ragdolling (`BreakJointsOnDeath = false`).
- Character subclasses use `.new(parentCharacterClass)`, expose `ClassName`, and may implement `Start()` and `Destroy()`. The parent's `RunService.PreSimulation` connection explicitly steps only `MovementClass` and `StaminaClass`; adding a `Step` method to another subclass does not automatically register it.
- Client `Environment/Guns/Bullets.lua` simulates cosmetic projectile travel with FastCastRedux and reports hits. Server `GunService` registers bullets and applies weapon data from the equipped tool's server-side `ItemInfo`; hit handling checks bullet ownership/registration, teams, and the shot's ray path before calling `CombatService`.
- Melee validates the equipped tool; melee and punch handlers both perform server-side hitbox, range, and cooldown checks. `CombatService` centralizes damage, team rules, hitbox multipliers, score/VFX notifications, and respawning; `HealthService` handles downing and death.
- `InventoryService` clones tools from `ServerStorage.Tools` and dispatches item behavior by `ItemInfo.Class` to child modules such as `Ranged`, `Melee`, `Healer`, and `Chemlight`. `NPCService/Entities` modules export behavior functions called with a rig, and `MapService` child modules expose `Init(map)`.

### Networking

Two networking systems coexist:

1. **Knit networking** — services expose client-callable methods and signals through their `Client` tables, using `Knit.CreateSignal()` where needed.
2. **Red remotes** — modules in `ReplicatedStorage/Remotes` use `script.Name` as the event/function name and are required through `:Server()` or `:Client()` where applicable. Examples include gun/melee/movement requests, hit detection, data replication, damage indicators, and respawning.

Follow the networking mechanism already used by the surrounding domain rather than adding another transport.

### Persistence and client data

- `DataService` wraps ProfileStore. Its store key is `PlayerData` in live games and `PlayerData_Dev` in Studio; profile session keys are based on `player.UserId`.
- The persistent schema is `src/ReplicatedStorage/Modules/Data/DataTemplate.lua`, currently containing keybinds and client preferences.
- Server code uses dot-separated paths through `DataService:Get`, `Set`, and `Increment`. `Set` uses `SetPath`, checks that the new value matches the current value's type, broadcasts the update, and fires any data-changed signal.
- `DataController` obtains the initial snapshot with `GetData`, caches data by stringified user ID, applies `UpdateData` messages, and exposes client-side `Get`, `AwaitLoaded`, and data-changed signals.
- The current initial snapshot contains data for **all active players**, and updates are fired to all clients. Treat this as replicated client-visible data, not a private server-only storage channel.
- ProfileStore session handling is deliberate: profiles are reconciled, users are kicked if their session ends or fails to load, and sessions end when players leave. Preserve this lifecycle when modifying `DataService`.

## Code style and module conventions

- Write Luau and match the surrounding file's inline type-annotation style, for example `function Foo:Bar(x : number) : boolean`. Indentation and alignment vary between files; match the local style rather than reformatting unrelated code.
- Common section banners are `-- Services`, `-- Modules and objects`, optionally `-- Player`, `-- Vars and consts`, and `-- [[ funcs ]] --`. Preserve this structure where it is already used.
- Services, classes, modules, and most service-local aliases use PascalCase. Knit service names use `Name = "XxxService"`. Methods generally use PascalCase, local helper functions often use camelCase, and constants often use `UPPER_SNAKE_CASE`.
- Obtain Roblox services with `game:GetService(...)`. `_G.Knit` and `_G.Signal` are established project globals; avoid introducing new global shortcuts.
- First-party code uses `.lua`; vendored code predominantly uses `.luau`, with some `.lua` linkers/entry files. Match the folder. Rojo suffixes matter: `.server.lua` is a server Script, `.client.lua` is a LocalScript, and `init.lua` turns a directory into a module with children.
- Modules eligible for SGUI's dynamic loader return a table with `Function()`. SGUI calls them in `task.spawn`; it excludes Controllers, modules named exactly `_template` or `_mousetracking`, and modules whose direct parent is a ModuleScript. Container modules such as Guns and Camerawork load or drive their own children, so nested implementation modules can have different contracts.
- SCLocal requires each direct child of StarterCharacterScripts' `Libraries` and calls `Function()`. New direct children must therefore follow that contract.
- An underscore prefix is neither a universal loader exclusion nor a reliable template marker. `_STATIC.lua` is active GUI code, and `InventoryService/_general.lua` is shared item implementation. Explicit templates include `_templateService.lua`, `_templateController.lua`, `_templateClass.lua`, `_templateEffect.lua`, and several `_template.lua` files. Check the specific bootstrap before adding a module.
- Selene allows `multiple_statements`, `parenthese_conditions`, `global_usage`, and `empty_if`; `unused_variable` is warn-only. Run `selene src` after source changes. No formatter is configured.

## Testing and deployment

There is no configured first-party automated test runner or project test command. Test/spec files under Wally packages, SmartBone, and ProfileStore belong to those dependencies and are not a project test suite. Do not add a test framework unless asked.

For changes, use the available checks as appropriate:

```bash
selene src
rojo build -o "blueworks_v2.rbxlx"
```

Use Roblox Studio playtests for runtime behavior, especially replication, character lifecycle, combat, data persistence, and Studio-only asset integration. No CI workflow, release script, or automated Roblox publishing/deployment process is present; the documented workflow ends with Rojo build/sync in Studio.

## Security and external services

- Keep gameplay authority on the server. Clients report actions and hit information, but server services own inventory state, weapon configuration, damage application, teams, persistence, and NPC logic. Preserve existing team, equipped-item, distance, cooldown, bullet-ownership, and raycast checks when changing request handlers.
- Do not assume every Red remote validates its payload. Many definitions use Guard, but some accept unchecked or only partially checked data; for example, `HitDetection` currently returns `true` from its guard callback. Review both the Red definition and its server handler, and retain or improve server-side validation rather than relying on client-reported damage or positions.
- Do not put secrets or server-only values in `DataTemplate`: the current `GetData`/`UpdateData` design replicates player profile data to clients.
- Persistence requires Roblox DataStore access. `MetaService` additionally uses a `GameVersion` DataStore and makes an HTTP request to `http://ip-api.com/json/` to populate server region information; HTTP access must be permitted for that feature to work.
