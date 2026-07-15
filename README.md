# BREACHPOINT: ZERO HOUR

A complete playable vertical slice of a five-operation single-player FPS, built in Godot 4.6.3 with an MIT/CC0 Kenney Starter Kit FPS foundation. The repository includes its CC0 Kenney and Quaternius assets, but does not include the Godot editor or generated builds.

## Download Godot and play on Windows

1. Download the **standard Godot Engine 4.6.3 build for Windows** from the [official Godot download page](https://godotengine.org/download/windows/). This project uses GDScript, so the .NET build is not required.
2. Extract the downloaded ZIP file.
3. Rename the main editor executable from `Godot_v4.6.3-stable_win64.exe` to `godot.exe`. The smaller `Godot_v4.6.3-stable_win64_console.exe` companion is not required.
4. Copy `godot.exe` into this project folder, next to `project.godot` and `PLAY_GAME.bat`.
5. Double-click `PLAY_GAME.bat`.

The launcher prefers `builds/BreachpointZeroHour.exe` when a locally exported build is present; otherwise it runs the project with the local `godot.exe` or a compatible Godot found on `PATH`. The downloaded editor, local builds, import cache, and save data are excluded from Git.

For a USB copy, keep the entire folder together. `PLAY_GAME.bat` stores progression and settings in the local `save-data` folder, so cash, weapons, upgrades, loadouts, artifacts, settings, and controller bindings travel with the game.

You can also open `project.godot` in Godot's Project Manager and press **F6/F5**. To make a distributable executable, install Godot's export templates and double-click `EXPORT_WINDOWS.bat`.

## Mission loop

Choose an operation and difficulty from the main menu:

- **Mesa Bank & Trust:** Enter the bank, find the management-office keycard, breach the clearly marked vault, optionally take cash and gear, then return through the lobby to extract.
- **Route 17 Fuel & Service:** Deploy with your selected weapons plus always-available fists, empty the register, search five randomized hiding locations for a reinforced service-key lockbox, break its latch with fists or a pipe wrench, loot snacks, explore the restroom and attached auto shop, build scrap armor, then unlock the garage car and drive away while employees and police react.
- **Mesa Grand Museum:** Explore a map more than twice the bank's floor area, search the dead-end west archive for an access card, cross looping galleries, collect any of ten sellable display artifacts, secure the Golden Sun Disk, survive museum security and tactical reinforcements, and uncover two secrets.
- **Mesa Exchange Pawn & Loan:** Visit a densely stocked pawn shop, appraise and sell artifacts extracted from other maps, browse persistent collection displays, optionally risk the register, and find an unclaimed-property secret. Pawnkeepers remain neutral and only draw and return fire after being attacked.
- **Blacktide Island — Endless Undead:** Free-roam a moonlit island with a lodge, ruins, watchtower, supply caches, and open escape routes while increasingly large waves of tough zombies and fast, anatomically layered skeletons with animated jaws, rib cages, jointed limbs, torn burial cloth, and glowing eyes spawn forever. The island kit always includes the Gravebreaker Bat and Cinder-9 Flamethrower.

Easy, Medium, and Hard change starting armor, incoming damage, enemy accuracy and fire rate, alert growth/decay, reinforcement or undead-wave pressure, score rewards, and civilian-failure limits. There is no mission timer.

## Controls

| Action | Keyboard + mouse | Controller |
|---|---|---|
| Move / look | WASD / mouse | Left / right stick |
| Fire / ADS | LMB / RMB | RT / LT |
| Jump / crouch | Space / Ctrl or C | A / B |
| Sprint | Shift | L3 |
| Reload / interact | R / E | X / Y |
| Grenade / melee | G / V | LB / RB |
| Flashlight | F | D-pad up |
| Weapons / hotbar | Wheel or 1–9 | D-pad left/right |
| Inventory | Tab | View/Back |
| Pause | Escape | Menu/Start |
| Menu/inventory navigation | Arrows + Enter/Escape | D-pad or left stick + A/B |

The settings screen shows whether profile storage is portable and includes adjustable mouse and controller sensitivity, FOV, volume, subtitles/audio cues, reduced camera motion, high-contrast HUD support, toggle crouch, and live input remapping. Map and Easy/Medium/Hard difficulty are selected on the operations board. A confirmed **Reset All Progression** button clears cash, purchases, upgrades, loadouts, and stored artifacts while keeping control and accessibility settings.

## Included systems

- Audible, operation-specific procedural background music across all five maps, with a persistent enable/disable toggle and dedicated music-volume control.
- Weighty first-person controller with acceleration, crouch, sprint, jump, head bob, sway, recoil, ADS, FOV kick, flashlight, and full controller look.
- Expanded weapon system with alternating animated fists, tactical knife, improved pipe wrench, spiked-and-chained Gravebreaker Bat, handgun, carbine, SMG, shotgun, marksman rifle, explosive launcher, and ignition-capable Cinder-9 Flamethrower; magazines, reserves, reload timing, spread, impacts, headshots, knockback, circular ADS optics, muzzle light, and positional sound.
- Reactive security, gas-station employees, police, armored SWAT, civilians, and endless procedural zombies/skeletons with rigged male/female character variants, visible faces and clothing, blended idle/walk/run/aim/shoot/hit/death animations, distinct durability and accuracy, patrol/investigate/combat/flee states, reinforcement waves, barks, and subtitle cues.
- Rules of engagement, accuracy tracking, headshot rewards, clean-run bonus, civilian penalties, alert decay, mission objectives, permanent weapon ownership, three-weapon pre-mission loadouts, long-term rank-100 upgrades with compounding prices and balanced diminishing gameplay returns including punch power, and after-action reports.
- Minecraft-style 9-slot hotbar plus 9×3 inventory, stacking, weight limits, consumables, loot cases, mouse drag-and-drop, and complete D-pad/stick navigation plus direct physical A/Cross controller activation.
- Five procedural maps: Mesa Bank & Trust with dense coin and bullion piles, Route 17's convenience store/restroom/auto-shop complex, the large collectible-filled Mesa Grand Museum, Mesa Exchange Pawn & Loan, and the open-ended Blacktide Island survival arena. The four heist operations have distinct Easter eggs, while extracted artifacts persist between runs and can be sold for cash.
- Operations-board map/difficulty selector, scrollable armory with permanent weapons and next-deployment ammo packs, loadout screen, HUD, circular scope overlay, controller-ready inventory, pause menu, settings/remapping, rank-100 upgrade system, confirmed fresh-profile reset, win/lose report, and Windows launch/export scripts.

## Project structure

```text
breachpoint/
├── project.godot                 Engine, autoload, renderer and window configuration
├── scenes/main.tscn              Minimal composition root
├── scripts/
│   ├── game.gd                   Menu → mission → report lifecycle
│   ├── core/                     Settings, bindings, scoring, alerts, profile persistence
│   ├── player/                   FPS movement, view rig, interaction, damage, hotbar
│   ├── weapons/                  WeaponBase and weapon personalities
│   ├── ai/                       Hostile and civilian state-machine actors
│   ├── inventory/                Stack/weight/grid model
│   ├── world/                    Procedural bank/gas station/museum/pawn shop/island, secrets, doors, loot
│   ├── effects/                  Tactical grenade
│   └── ui/                       Menus, HUD, remapping and draggable slots
├── sounds/                       Kenney CC0 placeholder effects
├── models/, sprites/, fonts/     Kenney Starter Kit source assets
├── assets/quaternius/            CC0 rigged characters and animation source library
├── assets/art/                   Generated bank and museum artwork texture sheets
├── docs/                         Art-replacement and extension guidance
├── PLAY_GAME.bat                 Run exported EXE or launch through Godot
├── EXPORT_WINDOWS.bat            Produce a Windows EXE with installed templates
└── export_presets.cfg            Reproducible Windows export preset
```

## Key scene setup

`scenes/main.tscn` deliberately has one scripted root. `scripts/game.gd` creates the UI once and creates/frees the selected `BankLevel`, `GasStationLevel`, `MuseumLevel`, `PawnShopLevel`, or `ZombieIslandLevel` plus a `PlayerController` for each attempt. All five maps build reusable Godot nodes at runtime, making each zone easy to inspect, modify, or replace. Global `SettingsManager` and `GameManager` autoloads own remappable input, profile settings, scoring, alert escalation, upgrades, and mission reporting.

New weapons are configured in `WeaponBase.configure()`. New heist actor variants belong in `ActorAI.configure()`; undead variants belong in `UndeadAI.configure()`. New inventory entries should use `InventorySystem.item()`. This prototype uses those factories in place of `.tres` files so the whole slice remains easy to copy; converting the dictionaries to custom Resources is a straightforward production refactor.

## Verification

The project was imported, parsed, and smoke-tested by launching the bank, gas-station, museum, pawn-shop, and Blacktide Island missions with official Godot 4.6.3 in headless mode. The smoke-test command is:

```bash
godot --headless --path . -- --smoke-test --boot-smoke --map=bank --difficulty=easy
godot --headless --path . -- --smoke-test --door-smoke --map=bank --difficulty=easy
godot --headless --path . -- --smoke-test --gas-smoke --map=gas_station --difficulty=hard
godot --headless --path . --quit-after 10 -- --smoke-test --map=museum --difficulty=medium --loadout=smg,pipe_wrench,sidearm --fire-smoke
godot --headless --path . --quit-after 10 -- --smoke-test --map=pawn_shop --difficulty=medium
godot --headless --path . --quit-after 20 -- --smoke-test --map=zombie_island --difficulty=hard --loadout=chain_bat --fire-smoke
godot --headless --path . -- --controller-ui-smoke
godot --headless --path . -- --progression-smoke
BREACHPOINT_DATA_DIR=/tmp/breachpoint-portable godot --headless --path . -- --portable-storage-smoke
```

See [docs/ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md) for high-fidelity art/audio replacement steps and [CREDITS.md](CREDITS.md) for licenses.

## Prototype boundaries

This is a polished systems-first vertical slice, not a content-complete commercial campaign. The checked-in characters are animated stylized models and the bank shell is procedurally assembled; photogrammetry, voice acting, navigation meshes, advanced cover selection, facial blendshapes, audio occlusion buses, baked LODs, and platform QA are the logical next content pass. The gameplay interfaces are separated so those upgrades do not require rewriting the mission loop.
