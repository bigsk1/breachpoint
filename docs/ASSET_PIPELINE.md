# High-fidelity asset upgrade pipeline

The playable prototype requires no downloads. Use this guide only when replacing the procedural stand-ins with production art.

## 1. Bank architecture and props

Keep one Godot unit equal to one meter. Model modules on a 0.25 m grid with 2.4–2.8 m doors, 0.9 m counters, and 4–4.5 m commercial ceilings. Export static modules as glTF 2.0 (`.glb`) with transforms applied, +Y up, -Z forward, and descriptive material names.

Useful free sources:

- [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit) — 140 CC0 furniture/interior files.
- [Kenney Modular Buildings](https://kenney.nl/assets/modular-buildings) — CC0 modular exterior pieces.
- [Poly Haven](https://polyhaven.com/) — CC0 HDRIs, PBR textures and models.
- [ambientCG](https://ambientcg.com/) — CC0 PBR surfaces, HDRIs and models.

Search terms that fit this level: `polished marble floor`, `office carpet tiles`, `acoustic ceiling tile`, `brushed stainless steel`, `laminated walnut`, `security camera`, `office cubicle`, `bank queue barrier`, `vault door`, and `bulletproof teller glass`.

Import PBR texture sets with albedo/sRGB enabled only for Base Color. Normal, Roughness, Metallic and AO maps must be imported as data. Pack AO/Roughness/Metallic into the channels expected by the Godot ORM material where practical. Start with 2K textures; reserve 4K for the vault hero asset and large continuous surfaces.

## 2. Characters and animation

- [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) provides CC0, rigged, game-ready base characters in glTF/FBX with a humanoid rig.
- Import a single consistent skeleton, then use Godot's retargeting to share idle, patrol, panic, cover, reload, hit, and death animations.
- Build outfit/material variants for Security, Police, SWAT and at least four civilian silhouettes. Preserve the gameplay script on the `CharacterBody3D`; replace only its generated visual children with an instanced character scene.

Recommended animation set: relaxed idle, guarded idle, walk, jog, sprint, crouch locomotion, pistol/rifle/shotgun aim offsets, fire, tactical reload, empty reload, flinch directions, surrender, panic run, cower, phone call, and grounded death poses.

## 3. Weapons and first-person hands

The current weapon interface expects a camera-mounted `WeaponBase`. Replace `build_visual()` with instanced view-model scenes while keeping `try_fire()`, `start_reload()`, signals, and weapon tuning intact.

For every weapon scene:

1. Add named `Muzzle`, `ShellEject`, `LeftHandIK`, and `RightHandIK` markers.
2. Keep the view model on its own render layer if clipping becomes visible.
3. Author separate hip, ADS, sprint, reload, inspect, melee, and equip animations.
4. Align the optic center to camera -Z and verify at FOV 65–105.

## 4. Audio and spatial polish

Replace the bundled CC0 placeholder shots with licensed recordings that explicitly allow redistribution in games. Record or source separate close shot, mechanical tail, indoor tail, distant tail, suppressed shot, magazine, bolt, cloth, footstep, glass, impact, siren, radio and civilian layers.

Create environment-specific buses for `LobbyMarble`, `OfficeCarpet`, `VaultMetal`, and `Exterior`. Godot `Area3D` zones can crossfade bus sends; add low-pass filtering when a wall blocks the listener-to-source ray. Keep spoken lines on the Voice bus so subtitle and accessibility cues stay synchronized.

## 5. Lighting and performance

The prototype uses Compatibility rendering for broad laptop support. For a high-end target, switch the project to Forward+ and use baked lightmaps or SDFGI after the art is stable. Keep emergency/muzzle lights dynamic; bake architectural lighting.

- Merge truly static architectural meshes by zone, not across the whole bank.
- Add occluders at each corridor/door transition.
- Provide LODs for furniture and characters; cap unique PBR materials per room.
- Prefer MultiMesh for repeated chairs, lamps and ceiling panels.
- Profile with the same number of reinforcements as alert tier 3, plus every civilian visible.

## 6. Replacement checklist

- Preserve collision layers: World 1, Actors 2, Interactables 3, Player 4.
- Preserve `interact()`, `take_damage()`, `is_headshot_point()` and emitted gameplay signals.
- Keep civilian silhouettes and colors clearly distinct from armed responders.
- Verify door pivots at the hinge, collision follows animation, and AI paths remain traversable.
- Re-run `godot --headless --path . --quit-after 10 -- --smoke-test` after each asset batch.
- Record the exact asset URL, author, license, and local files in `CREDITS.md` before committing.
