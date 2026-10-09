# AGENTS.md

## Project overview

**blueworks_v2** ("blueworks") is a Roblox first-person combat/extraction-style game written in **Luau** (Roblox Lua). The codebase is managed on disk with **Rojo** and synced into Roblox Studio; the built place file is `blueworks_v2.rbxlx` (gitignored).

The game features guns (projectile-based via FastCastRedux), melee, NPCs (server-side entities like `Human` and `Proxy`), character movement/stamina, per-player persistent data, and ragdoll deaths. `SmartBone` (bone physics) and `ShapecastHitbox` are vendored libraries under `ReplicatedStorage/Modules`.

## Toolchain and build

Tools are pinned in `aftman.toml` (install them with [Aftman](https://github.com/LPGhatguy/aftman), run `aftman install`):

- **Rojo 7.7.0** — filesystem ↔ Studio sync (`default.project.json` is the project file)
- **Wally 0.3.2** — package manager (`wally.toml`, lockfile `wally.lock`)
- **Selene 0.29.0** — linter (`selene.toml`, `std = "roblox"`)

Commands:

```bash
rojo build -o "blueworks_v2.rbxlx"   # build the place file from scratch
rojo serve                           # live-sync src/ into Roblox Studio
wally install                        # install/update packages into src/ReplicatedStorage/Packages
selene src                           # lint (no script wrapper exists; run directly)
```

There is no test runner configured. The only `*.spec.lua(u)` files live inside vendored libraries (SmartBone, Promise) and use TestEZ; they are not wired up to run. Do not add a test framework unless asked.

## Repository / runtime layout

`default.project.json` maps `src/<Service>` folders onto Roblox services (`ReplicatedFirst`, `ReplicatedStorage`, `ServerScriptService`, `StarterGui`, `StarterPlayer`). `$ignoreUnknownInstances = true` is set everywhere, so instances that only exist in Studio (map, GUI assets, `ServerStorage` content like `FootstepSounds`) are preserved.

- `src/ServerScriptService/Server.server.lua` — server entry point: requires Red, sets up `_G.Signal`/`_G.Knit`, `Knit.AddServices(...)`, `Knit.Start()`, proximity-prompt defaults, spawns a debug NPC.
- `src/ServerScriptService/Libraries/Services/` — Knit services (one per domain: CharService, GunService, MeleeService, DataService, NPCService, InventoryService, etc.). `_templateService.lua` is the template for new services.
- `src/ServerScriptService/Libraries/Classes/CharacterClass/` — per-character OOP class composed of sub-classes (Ammo, Effect, Gun, Health, Hitbox, Inventory, Movement, Noise, Score, Stamina, Team). Each sub-class takes the parent `CharacterClass` in `.new()`, exposes `.ClassName`, and may implement `:Start()`, `:Step(dt)`, `:Destroy()`. Used for both players and NPCs.
- `src/ServerScriptService/Libraries/ProfileStore/` — vendored ProfileStore (server-only Wally dependency, `lm-loleris/profilestore@1.0.3`) including its own `_Index`.
- `src/StarterGui/SGUI.client.lua` — main client entry point: starts Knit, adds controllers, detects platform (`Desktop`/`Mobile`/`Console`, stored as the player's `Device` attribute), disables core GUI, then dynamically requires every module under `PlayerGui/Libraries` (skipping `_`-prefixed templates and Controllers) and calls its `.Function()`.
- `src/StarterGui/Libraries/Controllers/` — Knit controllers (only `DataController` so far).
- `src/StarterGui/Libraries/Environment/` — client-side gameplay modules (camera, guns/bullets, viewmodel, VFX, melee). Each returns a table with a `Function()` that the bootstrap calls.
- `src/StarterGui/Libraries/Gui/` — custom HUD modules (health, stamina, inventory, gun stats, etc.), same `Function()` convention.
- `src/StarterPlayer/StarterCharacterScripts/SCLocal.client.lua` — per-character client bootstrap; requires every module in its `Libraries/` folder and calls `.Function()` after `Knit` is ready and the `Device` attribute is set.
- `src/ReplicatedFirst/SmartBoneRuntime.client.lua` — SmartBone client runtime bootstrap.
- `src/ReplicatedStorage/Modules/` — shared modules:
  - `Data/` — static data: `DataTemplate` (ProfileStore template incl. keybinds), `BulletInfo`, `MovementSettings`, `Tiers`, dialog/effect messages.
  - `Util/` — helpers (`GetPath`/`SetPath` for dot-path table access, `PlaySound`, `GunAttach`, `InvRep`, `Math/`).
  - `SmartBone/`, `ShapecastHitbox/` — vendored third-party libraries; avoid editing these.
- `src/ReplicatedStorage/Remotes/` — **Red** networking definitions. Each ModuleScript returns `Red.Event(script.Name, ...)` with `Guard` type-checking of arguments.
- `src/ReplicatedStorage/Packages/` — Wally-installed packages (Knit, Red, Guard, FastCastRedux + transitive deps), committed to git. Require them via `ReplicatedStorage.Packages.<Name>`; a few scripts reach into `Packages._Index` directly for specific Signal versions.

## Architecture notes

- **Knit** is the backbone. Services expose client-callable members via the `Client = {}` table (`Knit.CreateSignal()` for client→server events, `Service.Client:Method()` for request/response). Knit itself is stored in `_G.Knit` and sleitnick's Signal in `_G.Signal`; both entry points set these up, and `_G.Knit.Loaded` / `_G.Knit.Ready` gate dependent code.
- **Two networking layers coexist**: Knit's built-in `Client` signals and Red remotes in `ReplicatedStorage/Remotes` (Red events are used like `UpdateData:FireAll(player, path, value)` / `GetData:SetCallback(fn)`; the module name defines the event name). `Red` must be required before any remote module is used — the entry points do this.
- **Persistence**: `DataService` wraps ProfileStore. Store key is `"PlayerData"` with a `_Dev` suffix in Studio. Data is accessed via dot-separated string paths (`DataService:Get/Set/Increment(player, path, ...)`) and replicated to clients through the `GetData`/`UpdateData` Red remotes. Extend the schema in `src/ReplicatedStorage/Modules/Data/DataTemplate.lua`.
- **Characters** (players and NPCs alike) are managed by `CharService`, which wraps each model in a `CharacterClass` and parents them to `Workspace/Characters`. Humanoids have `BreakJointsOnDeath = false` because death ragdolling is done client-side (`StarterCharacterScripts/Libraries/Ragdolls`).
- `StarterPlayer/StarterPlayerScripts` is currently empty; client code lives in `StarterGui` and `StarterCharacterScripts`.

## Code style and conventions

- Language: Luau with inline type annotations on function signatures (`function Foo:Bar(x : number) : boolean`). Mixed tab/space indentation exists across files — match the surrounding file.
- Standard file header sections, in order: `-- Services`, `-- Modules and objects`, optionally `-- Player`, `-- Vars and consts`, then `-- [[ funcs ]] --`. Keep this structure when adding modules.
- Naming: PascalCase for services/classes/modules and most locals (`local RepStorage = game:GetService("ReplicatedStorage")`); services are created with `Name = "XxxService"`. Get services via `game:GetService(...)`, never global shortcuts.
- Files/folders prefixed with `_` are templates or partial modules (`_templateService.lua`, `_templateController.lua`, `_template.lua`, `_general.lua`) — the client bootstrapper skips them; copy them when creating new modules.
- Lua file extensions: game code uses `.lua`; vendored libraries use `.luau`. Match the existing convention of the folder you are working in.
- Selene config (`selene.toml`) allows `multiple_statements`, `parenthese_conditions`, `global_usage` (needed for `_G.Knit`/`_G.Signal`), and `empty_if`; `unused_variable` is warn-only. Run `selene src` before committing.

## Security considerations

- All hit detection, damage, gun/melee requests, and data writes are validated server-side; Red remote definitions use `Guard` to type-check client input — keep argument validation when adding or changing remotes.
- Never trust client-reported positions/damage; server services (GunService, MeleeService, HitDetection remote) are the authority.
- ProfileStore session handling in `DataService` (kicking on session end, ending sessions on leave) is deliberate — preserve it.
- There are no secrets in this repo; DataStore keys are hardcoded strings, not credentials.
