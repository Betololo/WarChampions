# War Champions (BFH) Gameplay, Ballistics & Visual Overhaul Plan

> **For agentic workers:** Executed sequentially via Subagent-Driven Development (`superpowers:subagent-driven-development`), one task per commit, with independent spec & code quality review after each task.

**Goal:** Resolve all gameplay and visual bugs reported from live screenshots (`media_1794655995299_01a1119f`, `media_1794656060789_c3f4023b`) and match Battlefield Heroes reference art (`media_1794656431788_bc12650d`, `media_1794656439526_93016b2a`, `media_1794656445730_600c2a1a`).

**Architecture:** Modular builders (`VehicleMeshBuilder`, `BuildingMeshBuilder`, `HeroMeshBuilder`), unified ballistic arc tracer (`LagCompensator.trace_ballistic_arc`), authoritative enclosed vehicle seat protection + HUD Vehicle HP gauge, and a 2x Seaside Frontline layout with rich village landmarks.

---

### Task 1: Vehicle Seat Protection, Occupant Visibility/Posing, Ejection on Destruction & HUD Vehicle HP Bar
**Files:**
- Modify: `entities/vehicles/vehicle_base.gd`
- Modify: `entities/vehicles/vehicle_tank.gd`
- Modify: `entities/vehicles/vehicle_jeep.gd`
- Modify: `entities/vehicles/vehicle_plane.gd`
- Modify: `entities/vehicles/vehicle_boat.gd`
- Modify: `entities/vehicles/aa_gun.gd`
- Modify: `core/network/lag_compensator.gd`
- Modify: `entities/characters/hero_character.gd`
- Modify: `vfx_shaders/status_effects_vfx.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `core/main_game.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. Extend `VehicleBase.SeatSlot` with `is_enclosed: bool = false` and `seat_pose: String = "stand"` (`"hidden"`, `"sit"`, `"stand"`, `"wing"`), passed to `_add_seat(s_type, offset, allow_shoot, allow_skills, is_enclosed = false, seat_pose = "sit")`.
2. Configure authentic BFH seat occupancy:
   - `VehicleTank`: Driver `offset = Vector3(0.0, 0.95, 0.0)`, `is_enclosed = true`, `seat_pose = "hidden"` (inside tank hull/turret, protected from bullets & completely concealed inside armor); external rear engine-deck passenger `offset = Vector3(0.0, 1.55, 2.35)`, `is_enclosed = false`, `seat_pose = "stand"`.
   - `VehiclePlane`: Pilot `offset = Vector3(0.0, 0.92, -0.15)`, `is_enclosed = true`, `seat_pose = "sit"` (seated low inside glass canopy, protected from small-arms hitboxes); Wing-Riders `is_enclosed = false`, `seat_pose = "stand"`.
   - `VehicleJeep`: Driver & 2 rear passengers `is_enclosed = false`, `seat_pose = "sit"`, lowered seat offsets (`(-0.46, 0.58, -0.05)`, `(-0.48, 0.62, 0.95)`, `(0.48, 0.62, 0.95)`) so characters visibly sit inside the open-top cabin with bent legs instead of standing above the windshield.
   - `VehicleBoat`: Helm Driver `offset = Vector3(0.0, 0.85, 0.35)`, `is_enclosed = true`, `seat_pose = "sit"`; 2 rear deck passengers `is_enclosed = false`, `seat_pose = "sit"` (`(±0.72, 0.72, -1.25)`).
   - `AAGun`: Gunner `offset = Vector3(0.0, 0.88, 0.52)`, `is_enclosed = false`, `seat_pose = "sit"`.
3. Add `VehicleBase.is_hero_enclosed(hero: HeroCharacter, vehicles_by_id: Dictionary) -> bool` and enforce it in:
   - `HeroCharacter.apply_damage_server` (if caller doesn't set `bypass_enclosure`, ignore direct bullet damage when `is_enclosed` inside active vehicle; add optional default parameter `bypass_enclosure: bool = false` so vehicle explosion still injures ejected crew!).
   - `LagCompensator.record_frame`, `trace_rewound_ray`, and live fallback so enclosed heroes' capsules cannot be hit through tank/plane armor.
   - `StatusEffectsVFX.update_hero_client_visuals` (needs access to vehicle lookup via `hero.get_meta("vehicles_ref", {})` or helper argument passed from `MainGame._process`) and `HeroCharacter._animate_character`: hide `visual_root` completely when `seat_pose == "hidden"`, and apply sitting thigh/torso pose (`hips.position.y`, `leg.rotation.x = -1.45`) when `seat_pose == "sit"`.
   - `HeroCharacter.reconcile_with_server`: synchronize `hero_camera.set_vehicle_mode(current_vehicle_id >= 0)` when `current_vehicle_id` changes on non-server multiplayer clients!
4. Fix vehicle destruction & damage math:
   - Remove the double `0.45` bullet reduction between `HitscanWeapon` and `VehicleBase`: `HitscanWeapon` passes `dmg_mult` cleanly (`0.55` reduction happens once in `VehicleBase.apply_damage_server` for non-explosive hits, while explosives deal `1.15x` / `1.25x` anti-armor damage!).
   - Tune vehicle `max_hp` (`Jeep = 280`, `Tank = 520`, `Plane = 340`, `Boat = 380`, `AAGun = 320`) so 3–5 rockets/tank shells or concentrated gunfire visibly destroys any vehicle.
   - In `VehicleBase._on_destroyed(attacker_id)`: eject every seated occupant cleanly (resetting `current_vehicle_id = -1`, `current_seat_index = -1`, enabling `_body_collision`, restoring `hero_camera.set_vehicle_mode(false)`, applying blast knockback + `45` explosion damage with `bypass_enclosure = true`), award attacker XP & broadcast `"vehicle_destroyed"` killfeed event, spawn smoke/wreck feedback.
   - Add client-side low-HP damage smoke/fire emitter on `VehicleBase` when `hp < max_hp * 0.55` / `< 0.25`.
5. Add a dedicated Battlefield Heroes style **HUD Vehicle Health Bar** in `HUDController`: visible bottom-left above hero HP (or bottom-center above hotbar) whenever `_local_hero.current_vehicle_id >= 0` OR targeting/looking within 8m of a damaged vehicle, displaying vehicle icon/name (`Tanque`, `Jipe`, `Caça`, `Lancha`, `Canhão AA`), current/max HP, and animated green/yellow/red fill bar!
6. Add unit & integration assertions in `tests/test_runner.gd` verifying:
   - Tank driver seat `is_enclosed == true`, `seat_pose == "hidden"`, and immune to direct hitscan shot + concealed `visual_root.visible == false`.
   - Vehicle takes measurable damage from hitscan & projectiles, drops to 0 HP cleanly, ejects driver (`current_vehicle_id == -1`, `hp < max_hp`), and emits `destroyed`.
   - HUD creates `_veh_hp_panel` and updates dynamically when seated inside a vehicle.

---

### Task 2: Ballistic Bullet Drop Across All Weapons/Vehicles + Curved Tracers/Projectiles + TPS Camera Pullback
**Files:**
- Modify: `entities/characters/hero_camera.gd`
- Modify: `core/network/lag_compensator.gd`
- Modify: `entities/weapons/weapon_base.gd`
- Modify: `entities/weapons/hitscan_weapon.gd`
- Modify: `entities/weapons/projectile_weapon.gd`
- Modify: `entities/weapons/projectile_entity.gd`
- Modify: `entities/vehicles/vehicle_tank.gd`
- Modify: `entities/vehicles/vehicle_plane.gd`
- Modify: `entities/vehicles/vehicle_boat.gd`
- Modify: `entities/vehicles/aa_gun.gd`
- Modify: `vfx_shaders/status_effects_vfx.gd`
- Modify: `core/main_game.gd`
- Modify: `ui/hud_controller.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. Pull TPS camera slightly back while preserving the clean over-right-shoulder framing:
   - `HeroCamera.TPS_SHOULDER_OFFSET = Vector3(0.36, 1.98, 0.0)`, `TPS_SPRING_LENGTH = 2.48`, `TPS_FOV = 68.0`, `VEHICLE_SPRING_LENGTH = 7.4`, `VEHICLE_OFFSET = Vector3(0.0, 2.75, 0.0)`, `camera.far = 2800.0`.
2. Add `LagCompensator.trace_ballistic_arc(...)` supporting gravity (`gravity_mps2 > 0`) along segmented quadratic steps (`p_next = p_cur + vel * dt + 0.5 * g * dt^2`), testing static geometry + vehicles + destructibles + rewound/live non-enclosed hero hitboxes on every segment and returning `"arc_points": PackedVector3Array`, `"hit"`, `"target_hero_id"`, `"target_object"`, `"is_headshot"`, `"hit_pos"`, `"distance"`.
3. Configure realistic arcade bullet drop on ALL weapons in `WeaponBase`:
   - `bullet_speed_mps`, `bullet_gravity_scale` (`Sniper = 195 m/s / 1.0`, `MG = 145 m/s / 1.0`, `SMG = 135 m/s / 1.0`, `Pistol = 120 m/s / 1.0`, `Shotgun = 105 m/s / 1.1`, `Knife = melee instant`).
   - Route `HitscanWeapon.fire_server` through `trace_ballistic_arc` and include `"arc_points"` in `shot_vfx`!
   - Update `StatusEffectsVFX.spawn_bullet_tracer` (and add `spawn_arc_tracer` / `spawn_client_projectile`) so bullet tracers visibly arc along `arc_points`!
4. Tune `ProjectileEntity` drop & replicate client projectile visuals:
   - `BAZOOKA_ROCKET`: `gravity_scale = 0.72` (speed `42.0`), sculpted winged rocket mesh + flame plume.
   - `TANK_SHELL`: `gravity_scale = 1.08` (speed `60.0`), glowing tracer shell + smoke trail.
   - `AA_FLAK`: `gravity_scale = 0.38` (speed `102.0`), bright flak tracer orb.
   - Broadcast `"proj_vfx"` whenever server spawns `ProjectileEntity` (Bazooka, Tank Shell, AA Flak, Grenade, Keg, TNT) so BOTH Host AND remote Multiplayer clients see full curved projectile flight!
   - Route `VehiclePlane._fire_front_mgs` and `VehicleBoat` bow gun through `trace_ballistic_arc` (`165 m/s`, `gravity = 12.0`).
   - Enhance `HUDController.SniperScopeOverlay` with calibrated mil-dot drop hashes below center crosshair!
5. Add automated tests in `tests/test_runner.gd` verifying:
   - `LagCompensator.trace_ballistic_arc` curves downward (`end_y < origin_y` on horizontal shot over 180m) and drops onto lower targets while missing straight high horizontal rays.
   - `BAZOOKA_ROCKET` and `TANK_SHELL` accelerate downward over simulation ticks (`velocity.y < 0` and parabolic height loss).
   - `HeroCamera` uses pulled-back TPS spring distance (`2.2..2.8m`).

---

### Task 3: Stylized BFH Character Aesthetics Overhaul (Seamless Shoulders, Expressive Heads/Gear, Trenchcoats/Uniforms/Backpacks)
**Files:**
- Modify: `entities/characters/hero_mesh_builder.gd`
- Modify: `entities/characters/hero_character.gd`
- Modify: `vfx_shaders/cartoon_assets.gd`
- Modify: `vfx_shaders/hero_cel_shader.gdshader`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. Fix the #1 visual defect from `media_1794656060789_c3f4023b.jpg`: remove exposed external spherical shoulder/elbow joint balls (`sh_sph`, `el_sph`). Build sculpted continuous shoulder-cap / bicep `upper_arm_mesh` that nests organically inside the coat armhole/deltoid contour, plus rolled sleeve cuff / forearm `forearm_mesh` with continuous elbow lap.
2. Elevate 3rd-person character read & silhouette (`HeroMeshBuilder` + `HeroCharacter`):
   - Tailor `build_torso_mesh` with sharper BFH V-taper, pinched waist, flaring lower jacket/trenchcoat coattails, and crisp shoulder yokes.
   - Add modular sculpted BFH accessories (`build_collar_lapels_mesh`, `build_backpack_mesh`, `build_helmet_mesh`, `build_face_features` with brow ridge, sculpted eyes/aviator shades, nose bridge, jawbeard/mustache per class/team!).
   - Equip Royal/National visual distinctiveness matching `media_1794656431788_bc12650d`, `93016b2a`, `600c2a1a`:
     - Royal Soldier: M1/Brodie style helmet OR khaki cap, khaki collared field jacket with gold lapels/buttons, Y-suspenders & rucksack on back, full blonde/brown beard or handlebar mustache!
     - National Soldier: Officer visor cap / stahlhelm, slate-grey jacket with red collar tabs, leather cross-strap & backpack, sharp dark mustache!
     - Royal Gunner: Skewed crimson paratrooper beret + brass lion badge, aviator sunglasses, muscular rolled/bare tattoo arms (`hero_arm_tattoo`), leather X-harness & heavy drum rucksack!
     - National Gunner: Dark steel/olive beret or peaked cap, thick greatcoat vest & broad pauldrons, heavy ammo belt straps, aviator shades!
     - Royal & National Commando: Wide-brim slouch fedora/cavalier hat (olive/charcoal vs black), glowing amber/dark tactical shades, scarf/cravat collar, ammo belt bandolier across chest, flowing long trenchcoat & dual side hip pouches, gloved hands!
3. Upgrade `CartoonAssets` hero cloth textures (seam stitching, lapels, brass buttons, rolled sleeve tattoos, flared trouser folds, laced leather boots) & enhance `hero_cel_shader.gdshader` with subtle leather/metal specular highlight (`SPECULAR_LIGHT`) and clean warm/cool cel ramp.
4. Keep IK grip (`_pose_arm_ik` `err < 0.025m`) 100% intact and add unit tests in `tests/test_runner.gd`.

---

### Task 4: Sculpted Stylized Cartoon Vehicle Models (`VehicleMeshBuilder`)
**Files:**
- Create: `entities/vehicles/vehicle_mesh_builder.gd`
- Modify: `vfx_shaders/cartoon_assets.gd`
- Modify: `entities/vehicles/vehicle_base.gd`
- Modify: `entities/vehicles/vehicle_tank.gd`
- Modify: `entities/vehicles/vehicle_jeep.gd`
- Modify: `entities/vehicles/vehicle_plane.gd`
- Modify: `entities/vehicles/vehicle_boat.gd`
- Modify: `entities/vehicles/aa_gun.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. Create `VehicleMeshBuilder` using lofted curves, cylinders, sloped hulls, cast turrets, wheel hubs, propeller spinners, canopies, and hand-painted metal/camo textures (`veh_olive`, `veh_panzer`, `veh_steel`, `veh_track`).
2. Overhaul every vehicle mesh and animate sub-parts (`_wheels`, `_propeller_node`, `_barrel_pivot`):
   - `VehicleTank`: Sloped Sherman/Panzer IV lofted armored chassis, tread housings with 5 sculpted road wheels + drive sprockets per side, engine louvers, rounded/angled rotating cast turret, elevating gun mantlet + fluted barrel with muzzle brake, commander hatch, rear passenger rail.
   - `VehicleJeep`: Contoured hood, radiator grille + warm headlights, tilted windshield frame, flared wheel arches, steering wheel, seats, rear spare tire, 4 spinning treaded rubber tires.
   - `VehiclePlane`: Tapered lofted fuselage, engine cowling + nose cone + spinning 3-blade propeller, tinted bubble canopy cockpit (revealing seated pilot inside!), swept cambered wings with faction roundel/cross stripes, tail fin/stabilizer, dual landing gear wheels.
   - `VehicleBoat`: V-hull pointed prow boat with wood/steel deck planks, armored helm wheelhouse with windows, painted team stripes, mounted twin bow MG shield & barrels, life buoy ring.
   - `AAGun`: Sandbag-rimmed octagonal concrete bunker base, rotating armored gun shield, elevating dual Flak barrels + gunner seat.
3. Add test in `tests/test_runner.gd` verifying all 5 vehicle types build multi-part meshes (`get_child_count() >= 6` on `VisualRoot`) without plain single-box stubs.

---

### Task 5: 2x Scale Seaside Frontline Map + Sculpted Village Architecture (`BuildingMeshBuilder`) & All Landmarks
**Files:**
- Create: `maps/building_mesh_builder.gd`
- Modify: `vfx_shaders/cartoon_assets.gd`
- Modify: `maps/map_seaside_frontline.gd`
- Modify: `core/main_game.gd`
- Modify: `tests/test_runner.gd`

**Requirements:**
1. Expand `MapSeasideFrontline` to **2x linear size (`2400m x 2400m` Ocean, `1600m x 1080m` Coastal Island)**:
   - Main Boulevard `~1280m` East-West + North-South Town Avenue + Coastal Ring Road.
   - Keep camera/fog `far = 2800.0` crisp across the whole island.
2. Create `BuildingMeshBuilder` to replace flat "massinha" box houses with sculpted Mediterranean/European cartoon buildings:
   - **True pitched/gabled triangular roofs** (`PrismMesh` / `SurfaceTool` sloped clay-tile gables + protruding timber eaves & ridge tiles), **stone plinth foundations**, **corner quoin trim**, **timber half-timbered beams**, **recessed shuttered glass windows + flower boxes**, **arched timber doorways + striped shop awnings**, **rooftop chimneys**, **balconies + exterior staircases**.
3. Build every requested map landmark cleanly:
   - **Royal & National Spawn Airstrips (`pistas de decolagem no respawn`):** 220m marked tarmac runways right next to Royal Spawn (`X ~ -460`) and National Spawn (`X ~ +460`) with hangars, control towers, runway centerline decals, and **2 Fighter Planes parked ready on each spawn runway**!
   - **Coastal Lighthouse (`Farol na costa`):** Tall (`28m`) cylindrical red-and-white striped stone Lighthouse at Southwest coastal cliff overlooking **Lighthouse Cove**, with upper lookout walkway, glowing beacon lantern dome, keeper's cottage, and cliff jetty!
   - **Watchtowers (`Torres de vigia`):** 6 climbable wooden/stone frontier watchtowers with stairs/platforms overlooking roads, coastline, Windmill Hill, Ruins, and both Airstrips.
   - **Central Town Square Fountain & Mercadinho (`Fonte no meio da cidade` + `Mercadinho`):** Octagonal sculpted stone Fountain with multi-tier basins and shimmering turquoise water in the central cobbled Town Square Plaza, surrounded by a bustling **Mercadinho** (roofed produce stalls, striped market awnings, wooden crates, café benches, flower pots, streetlamps, and festive overhead triangle bunting!).
   - **Accessible Coastal Harbors & Aquatic Vehicles:** Timber docks with wide walkable ramps sloping down to sea level + 6 Patrol Boats moored closely along BOTH Royal Harbor, National Harbor, and Central Cove Jetty so players can board aquatic vehicles effortlessly.
   - **140+ Layered Cartoon Trees & Props:** Broadleaf oaks, tall slender Mediterranean cypress, coastal palms, stone walls, picket fences, hay bales, utility poles.
4. Update & expand `tests/test_runner.gd` to assert doubled island/ocean dimensions, presence of `CentralFountain`, `Mercadinho`, `CoastalLighthouse`, `Watchtower_*`, `RoyalRunway` / `NationalRunway` near spawns, multiple aquatic `VehicleBoat` instances moored near docks, and clean headless boot + 2-process ENet handshake!
