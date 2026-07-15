# Extending the prototype

## Weapon

Add a new branch in `WeaponBase.configure()`, then add the item to a loot container or the player's starting inventory. Preserve `ammo_changed`, `hit_confirmed`, and `fired`; the HUD and player controller already listen to them.

## Enemy or civilian variant

Add a value to `ActorAI.Kind`, configure its durability, movement, damage, accuracy, cadence and detection range, then give it a distinct visual in `_build_character()`. Add its score reward in `GameManager.hostile_neutralized()` and spawn it from `BankLevel`.

## Inventory item

Construct an entry with `InventorySystem.item()`. Consumables also need a behavior branch in `InventorySystem.use_slot()`. Mission keys can be queried through `count_item()` and consumed with `remove_item()`.

## Level zone

Add architecture and props in `BankLevel`, then update the objective thresholds in `_process()`. For larger maps, split each zone into a `.tscn` and keep `BankLevel` as the mission director.

## Recommended production refactors

1. Convert weapon/item dictionaries into custom `.tres` Resources.
2. Replace direct steering with a baked `NavigationRegion3D` and `NavigationAgent3D` on each actor.
3. Add animation trees and humanoid retargeting while preserving actor gameplay methods.
4. Move encounter composition into mission data so additional heists can reuse the same systems.
5. Add automated scene tests for score math, inventory stacking, penalties, and mission transitions.
