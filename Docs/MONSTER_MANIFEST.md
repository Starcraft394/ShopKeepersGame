# Monster Manifest

**Generated**: 2026-02-22  
**Total Monsters**: 112

---

## Summary

### Combat Role Distribution

| Combat Role | Count |
|-------------|-------|
| mage | 29 |
| melee | 72 |
| ranged | 11 |
| **Total** | **112** |

### AI Tier Distribution

| AI Tier | Count | Notes |
|---------|-------|-------|
| (none) | 7 | R1 T1 monsters without ai_tier |
| 1 | 38 |  |
| 2 | 53 |  |
| 3 | 14 |  |
| **Total** | **112** | |

### Attack Type Distribution per Region

| Region | Melee | Ranged |
|--------|-------|--------|
| R1: Thornhaven | 16 | 0 |
| R2: Fungal Marsh | 9 | 7 |
| R3: Sunken Shores | 11 | 5 |
| R4: Ashen Highlands | 10 | 6 |
| R5: Shattered Expanse | 9 | 7 |
| R6: Necropolis Crypts | 9 | 7 |
| R7: Fractured Realm | 9 | 7 |
| **Total** | **73** | **39** |

### Ability Coverage (beyond basic_attack)

| Extra Abilities | Monster Count |
|-----------------|---------------|
| 0 | 7 |
| 1 | 77 |
| 2 | 28 |
| **Total** | **112** |

### Monster Ability Usage

| Ability | Times Used |
|---------|------------|
| mon_aimed_shot | 6 |
| mon_arcane_bolt | 8 |
| mon_berserker_rage | 9 |
| mon_chain_lightning | 11 |
| mon_devastating_charge | 10 |
| mon_flame_burst | 7 |
| mon_ground_slam | 18 |
| mon_heavy_strike | 20 |
| mon_life_siphon | 5 |
| mon_mend_ally | 2 |
| mon_meteor | 6 |
| mon_poison_shot | 4 |
| mon_rending_strike | 24 |
| mon_volley | 1 |
| mon_war_cry | 2 |

---

## Monster Ability Pool (18 abilities)

| ID | Display Name | Target | Effect | Base Dmg | Scaling | Cooldown | Status | Damage Type |
|----|-------------|--------|--------|----------|---------|----------|--------|-------------|
| mon_aimed_shot | Aimed Shot | single_enemy | damage | 7 | 60% | 3 | - | physical |
| mon_arcane_bolt | Arcane Bolt | single_enemy | damage | 8 | 50% | 3 | - | magical |
| mon_berserker_rage | Berserker Rage | self | buff | - | - | 5 | - | physical |
| mon_chain_lightning | Chain Lightning | all_enemies | damage | 5 | 40% | 4 | shocked(2t/1s) | magical |
| mon_devastating_charge | Devastating Charge | single_enemy | damage | 12 | 100% | 5 | stun(1t/1s) | physical |
| mon_flame_burst | Flame Burst | single_enemy | damage | 6 | 60% | 3 | burning(3t/2s) | magical |
| mon_ground_slam | Ground Slam | all_enemies | damage | 4 | 50% | 4 | - | physical |
| mon_heavy_strike | Heavy Strike | single_enemy | damage | 6 | 80% | 3 | - | physical |
| mon_life_siphon | Life Siphon | single_enemy | damage_and_heal | 8/heal:8 | 80% | 4 | - | magical |
| mon_mark_prey | Mark Prey | single_enemy | debuff | - | - | 4 | - | physical |
| mon_mend_ally | Mend Ally | single_ally | heal | heal:12 | - | 4 | - | magical |
| mon_meteor | Meteor | all_enemies | damage | 10 | 60% | 5 | burning(3t/2s) | magical |
| mon_poison_shot | Poison Shot | single_enemy | damage | 5 | 60% | 3 | poisoned(3t/2s) | physical |
| mon_rain_of_arrows | Rain of Arrows | all_enemies | damage | 8 | 60% | 5 | bleeding(3t/2s) | physical |
| mon_regeneration | Regeneration Aura | all_allies | heal | heal:10 | - | 5 | - | magical |
| mon_rending_strike | Rending Strike | single_enemy | damage | 5 | 80% | 3 | bleeding(3t/2s) | physical |
| mon_volley | Volley | all_enemies | damage | 4 | 40% | 4 | - | physical |
| mon_war_cry | War Cry | all_allies | buff | - | - | 5 | - | physical |

---

## R1: Thornhaven (16 monsters)

| ID | Display Name | Family | Tier | AI | Attack Type | Role | Abilities | HP | ATK | DEF | SPD | Elite? | Boss? | Portrait |
|----|-------------|--------|------|----|-------------|------|-----------|-----|-----|-----|-----|--------|-------|----------|
| bandit | Bandit | humanoid | 1 | - | melee | melee | - | 58 | 14 | 4 | 13 | - | - | Monsters_LowLevel/PNG/Transperent/Icon44.png |
| bandit_elite | Bandit Captain | humanoid | 1 | - | melee | melee | - | 72 | 16 | 2 | 18 | - | - | Monsters_LowLevel/PNG/Transperent/Icon44.png |
| boar | Boar | beast | 1 | - | melee | melee | - | 58 | 10 | 2 | 13 | - | - | Monsters_LowLevel/PNG/Transperent/Icon46.png |
| giant_spider | Giant Spider | beast | 1 | - | melee | melee | - | 47 | 12 | 2 | 15 | - | - | Monsters_LowLevel/PNG/Transperent/Icon16.png |
| goblin | Goblin | humanoid | 1 | - | melee | melee | - | 54 | 12 | 2 | 14 | - | - | Monsters_LowLevel/PNG/Transperent/Icon7.png |
| slime | Slime | ooze | 1 | - | melee | melee | - | 63 | 8 | 5 | 10 | - | - | Monsters_LowLevel/PNG/Transperent/Icon21.png |
| wolf | Wolf | beast | 1 | - | melee | melee | - | 50 | 16 | 2 | 17 | - | - | Monsters_LowLevel/PNG/Transperent/Icon43.png |
| cultist_enforcer | Cultist Enforcer | humanoid | 2 | 1 | melee | melee | mon_heavy_strike | 54 | 18 | 4 | 17 | - | - | Monsters_LowLevel/PNG/Transperent/Icon34.png |
| cultist_enforcer_elite | Cultist Enforcer (Elite) | humanoid | 2 | 2 | melee | melee | mon_rending_strike, mon_berserker_rage | 120 | 22 | 7 | 18 | ELITE | - | Monsters_LowLevel/PNG/Transperent/Icon34.png |
| gr_bramble_stalker | Bramble Stalker | plant | 2 | 2 | melee | melee | mon_rending_strike | 104 | 24 | 7 | 20 | - | - | Monsters_LowLevel/PNG/Transperent/Icon39.png |
| tf_logsplitter_brute | Logsplitter Brute | humanoid | 2 | 2 | melee | melee | mon_heavy_strike | 122 | 26 | 10 | 13 | - | - | Monsters_LowLevel/PNG/Transperent/Icon4.png |
| tf_rustwood_construct | Rustwood Construct | construct | 2 | 2 | melee | melee | mon_ground_slam | 130 | 20 | 12 | 11 | - | - | Monsters_LowLevel/PNG/Transperent/Icon25.png |
| webspinner | Webspinner | beast | 2 | 1 | melee | ranged | mon_poison_shot | 58 | 16 | 4 | 20 | - | - | Monsters_LowLevel/PNG/Transperent/Icon36.png |
| tf_iron_foreman | Iron Foreman | humanoid | 3 | 3 | melee | melee | mon_devastating_charge, mon_ground_slam | 280 | 32 | 12 | 20 | - | BOSS | Monsters_LowLevel/PNG/Transperent/Icon40.png |
| tf_sawbone_enforcer | Sawbone Enforcer | humanoid | 3 | 2 | melee | melee | mon_rending_strike, mon_heavy_strike | 110 | 24 | 8 | 16 | ELITE | - | Monsters_LowLevel/PNG/Transperent/Icon35.png |
| thorn_ent | Thorn-Ent | beast | 3 | 3 | melee | melee | mon_ground_slam, mon_berserker_rage | 300 | 30 | 10 | 18 | - | BOSS | Monsters_LowLevel/PNG/Transperent/Icon13.png |

## R2: Fungal Marsh (16 monsters)

| ID | Display Name | Family | Tier | AI | Attack Type | Role | Abilities | HP | ATK | DEF | SPD | Elite? | Boss? | Portrait |
|----|-------------|--------|------|----|-------------|------|-----------|-----|-----|-----|-----|--------|-------|----------|
| fm_bog_wisp | Bog Wisp | spore | 1 | 1 | ranged | mage | mon_arcane_bolt | 64 | 18 | 3 | 18 | - | - | Monsters_Recolored/fm_bog_wisp.png |
| fm_cave_shroom | Cave Shroom | spore | 1 | 1 | ranged | mage | mon_flame_burst | 76 | 18 | 6 | 14 | - | - | Monsters_Recolored/fm_cave_shroom.png |
| fm_mire_toad | Mire Toad | spore | 1 | 1 | ranged | ranged | mon_poison_shot | 70 | 16 | 4 | 16 | - | - | Monsters_Recolored/fm_mire_toad.png |
| fm_rot_beetle | Rot Beetle | spore | 1 | 1 | melee | melee | mon_heavy_strike | 88 | 14 | 7 | 13 | - | - | Monsters_Recolored/fm_rot_beetle.png |
| fm_slime_mold | Slime Mold | spore | 1 | 1 | melee | melee | mon_rending_strike | 66 | 21 | 3 | 18 | - | - | Monsters_Recolored/fm_slime_mold.png |
| fm_sporekin_shambler | Sporekin Shambler | spore | 1 | 1 | melee | melee | mon_heavy_strike | 72 | 18 | 4 | 14 | - | - | Monsters_Recolored/fm_sporekin_shambler.png |
| fm_bloom_giant | Bloom Giant | spore | 2 | 2 | melee | melee | mon_ground_slam | 110 | 23 | 8 | 14 | - | - | Monsters_Recolored/fm_bloom_giant.png |
| fm_cordyceps_host | Cordyceps Host | spore | 2 | 2 | melee | melee | mon_rending_strike | 110 | 23 | 6 | 14 | - | - | Monsters_Recolored/fm_cordyceps_host.png |
| fm_fungal_lurker | Fungal Lurker | spore | 2 | 2 | melee | melee | mon_rending_strike | 100 | 25 | 7 | 16 | - | - | Monsters_Recolored/fm_fungal_lurker.png |
| fm_hallucinogenic_cap | Hallucinogenic Cap | spore | 2 | 2 | ranged | mage | mon_chain_lightning | 106 | 25 | 7 | 16 | - | - | Monsters_Recolored/fm_hallucinogenic_cap.png |
| fm_mycelium_brute | Mycelium Brute | spore | 2 | 2 | melee | melee | mon_heavy_strike, mon_ground_slam | 175 | 28 | 12 | 18 | ELITE | - | Monsters_Recolored/fm_mycelium_brute.png |
| fm_rotcap_myconid | Rotcap Myconid | spore | 2 | 2 | melee | melee | mon_heavy_strike | 116 | 21 | 11 | 13 | - | - | Monsters_Recolored/fm_rotcap_myconid.png |
| fm_spore_knight | Spore Knight | spore | 2 | 2 | melee | melee | mon_rending_strike | 110 | 23 | 8 | 14 | - | - | Monsters_Recolored/fm_spore_knight.png |
| fm_sporewarden | Sporewarden | spore | 2 | 2 | ranged | mage | mon_arcane_bolt, mon_chain_lightning | 160 | 30 | 10 | 22 | ELITE | - | Monsters_Recolored/fm_sporewarden.png |
| fm_blight_mother | The Blight Mother | spore | 3 | 3 | ranged | mage | mon_chain_lightning, mon_life_siphon | 400 | 40 | 15 | 22 | - | BOSS | Monsters_Recolored/fm_blight_mother.png |
| fm_spiral_mycelium | The Spiral Mycelium | spore | 3 | 3 | ranged | mage | mon_meteor, mon_mend_ally | 450 | 42 | 16 | 24 | - | BOSS | Monsters_Recolored/fm_spiral_mycelium.png |

## R3: Sunken Shores (16 monsters)

| ID | Display Name | Family | Tier | AI | Attack Type | Role | Abilities | HP | ATK | DEF | SPD | Elite? | Boss? | Portrait |
|----|-------------|--------|------|----|-------------|------|-----------|-----|-----|-----|-----|--------|-------|----------|
| ss_drift_jelly | Drift Jelly | coastal | 1 | 1 | ranged | mage | mon_arcane_bolt | 97 | 28 | 6 | 20 | - | - | Monsters_Recolored/ss_drift_jelly.png |
| ss_reef_snapper | Reef Snapper | coastal | 1 | 1 | melee | melee | mon_heavy_strike | 92 | 30 | 8 | 24 | - | - | Monsters_Recolored/ss_reef_snapper.png |
| ss_salt_lurker | Salt Lurker | coastal | 1 | 1 | melee | melee | mon_rending_strike | 88 | 30 | 6 | 26 | - | - | Monsters_Recolored/ss_salt_lurker.png |
| ss_sandpiper_imp | Sandpiper Imp | coastal | 1 | 1 | ranged | ranged | mon_aimed_shot | 88 | 23 | 6 | 26 | - | - | Monsters_Recolored/ss_sandpiper_imp.png |
| ss_shore_crawler | Shore Crawler | coastal | 1 | 1 | melee | melee | mon_heavy_strike | 110 | 25 | 11 | 16 | - | - | Monsters_Recolored/ss_shore_crawler.png |
| ss_tidewalker | Tidewalker | coastal | 1 | 1 | melee | melee | mon_rending_strike | 106 | 28 | 8 | 18 | - | - | Monsters_Recolored/ss_tidewalker.png |
| ss_abyssal_angler | Abyssal Angler | coastal | 2 | 2 | ranged | ranged | mon_poison_shot | 165 | 40 | 15 | 18 | - | - | Monsters_Recolored/ss_abyssal_angler.png |
| ss_coral_golem | Coral Golem | coastal | 2 | 2 | melee | melee | mon_ground_slam | 180 | 33 | 18 | 16 | - | - | Monsters_Recolored/ss_coral_golem.png |
| ss_crustacean_brute | Crustacean Brute | coastal | 2 | 2 | melee | melee | mon_heavy_strike | 187 | 35 | 20 | 16 | - | - | Monsters_Recolored/ss_crustacean_brute.png |
| ss_deepcaller_shaman | Deepcaller Shaman | coastal | 2 | 2 | ranged | mage | mon_chain_lightning, mon_mend_ally | 200 | 38 | 14 | 28 | ELITE | - | Monsters_Recolored/ss_deepcaller_shaman.png |
| ss_drowned_mariner | Drowned Mariner | coastal | 2 | 2 | melee | melee | mon_rending_strike | 154 | 38 | 15 | 22 | - | - | Monsters_Recolored/ss_drowned_mariner.png |
| ss_leviathan_spawn | Leviathan Spawn | coastal | 2 | 2 | melee | melee | mon_ground_slam, mon_berserker_rage | 220 | 36 | 16 | 24 | ELITE | - | Monsters_Recolored/ss_leviathan_spawn.png |
| ss_mistborn_serpent | Mistborn Serpent | coastal | 2 | 2 | melee | melee | mon_rending_strike | 158 | 40 | 14 | 24 | - | - | Monsters_Recolored/ss_mistborn_serpent.png |
| ss_riptide_wraith | Riptide Wraith | coastal | 2 | 2 | ranged | mage | mon_flame_burst | 143 | 35 | 14 | 26 | - | - | Monsters_Recolored/ss_riptide_wraith.png |
| ss_mistborn_leviathan | Mistborn Leviathan | coastal | 3 | 3 | melee | melee | mon_devastating_charge, mon_ground_slam | 520 | 50 | 20 | 30 | - | BOSS | Monsters_Recolored/ss_mistborn_leviathan.png |
| ss_tide_sovereign | The Tide Sovereign | coastal | 3 | 3 | melee | melee | mon_devastating_charge, mon_war_cry | 580 | 52 | 22 | 28 | - | BOSS | Monsters_Recolored/ss_tide_sovereign.png |

## R4: Ashen Highlands (16 monsters)

| ID | Display Name | Family | Tier | AI | Attack Type | Role | Abilities | HP | ATK | DEF | SPD | Elite? | Boss? | Portrait |
|----|-------------|--------|------|----|-------------|------|-----------|-----|-----|-----|-----|--------|-------|----------|
| ah_ash_crawler | Ash Crawler | volcanic | 1 | 1 | melee | melee | mon_heavy_strike | 145 | 32 | 14 | 20 | - | - | Monsters_Recolored/ah_ash_crawler.png |
| ah_cinder_beetle | Cinder Beetle | volcanic | 1 | 1 | melee | melee | mon_rending_strike | 138 | 35 | 13 | 25 | - | - | Monsters_Recolored/ah_cinder_beetle.png |
| ah_ember_drake | Ember Drake | volcanic | 1 | 1 | ranged | mage | mon_flame_burst | 120 | 41 | 10 | 33 | - | - | Monsters_Recolored/ah_ember_drake.png |
| ah_magma_mite | Magma Mite | volcanic | 1 | 1 | melee | melee | mon_heavy_strike | 125 | 38 | 10 | 30 | - | - | Monsters_Recolored/ah_magma_mite.png |
| ah_scorched_viper | Scorched Viper | volcanic | 1 | 1 | melee | melee | mon_rending_strike | 123 | 38 | 11 | 33 | - | - | Monsters_Recolored/ah_scorched_viper.png |
| ah_soot_imp | Soot Imp | volcanic | 1 | 1 | ranged | mage | mon_arcane_bolt | 120 | 30 | 11 | 30 | - | - | Monsters_Recolored/ah_soot_imp.png |
| ah_ash_wraith | Ash Wraith | volcanic | 2 | 2 | ranged | mage | mon_flame_burst | 195 | 49 | 18 | 30 | - | - | Monsters_Recolored/ah_ash_wraith.png |
| ah_fire_djinn_lord | Fire Djinn Lord | volcanic | 2 | 2 | ranged | mage | mon_meteor, mon_flame_burst | 260 | 44 | 18 | 34 | ELITE | - | Monsters_Recolored/ah_fire_djinn_lord.png |
| ah_flame_stalker | Flame Stalker | volcanic | 2 | 2 | melee | melee | mon_rending_strike | 200 | 51 | 19 | 33 | - | - | Monsters_Recolored/ah_flame_stalker.png |
| ah_inferno_djinn | Inferno Djinn | volcanic | 2 | 2 | ranged | mage | mon_chain_lightning | 188 | 51 | 18 | 33 | - | - | Monsters_Recolored/ah_inferno_djinn.png |
| ah_lava_golem | Lava Golem | volcanic | 2 | 2 | melee | melee | mon_ground_slam | 250 | 43 | 24 | 20 | - | - | Monsters_Recolored/ah_lava_golem.png |
| ah_pyroclast_hurler | Pyroclast Hurler | volcanic | 2 | 2 | ranged | ranged | mon_volley | 230 | 49 | 21 | 23 | - | - | Monsters_Recolored/ah_pyroclast_hurler.png |
| ah_scorpion_ravager | Scorpion Ravager | volcanic | 2 | 2 | melee | melee | mon_rending_strike | 220 | 46 | 22 | 25 | - | - | Monsters_Recolored/ah_scorpion_ravager.png |
| ah_scorpion_titan | Scorpion Titan | volcanic | 2 | 2 | melee | melee | mon_devastating_charge, mon_berserker_rage | 280 | 42 | 20 | 30 | ELITE | - | Monsters_Recolored/ah_scorpion_titan.png |
| ah_cinder_monarch | The Cinder Monarch | volcanic | 3 | 3 | melee | melee | mon_devastating_charge, mon_ground_slam | 750 | 62 | 28 | 35 | - | BOSS | Monsters_Recolored/ah_cinder_monarch.png |
| ah_magma_wyrm | Magma Wyrm | volcanic | 3 | 3 | melee | melee | mon_ground_slam, mon_berserker_rage | 680 | 58 | 25 | 38 | - | BOSS | Monsters_Recolored/ah_magma_wyrm.png |

## R5: Shattered Expanse (16 monsters)

| ID | Display Name | Family | Tier | AI | Attack Type | Role | Abilities | HP | ATK | DEF | SPD | Elite? | Boss? | Portrait |
|----|-------------|--------|------|----|-------------|------|-----------|-----|-----|-----|-----|--------|-------|----------|
| se_echo_wisp | Echo Wisp | crystal | 1 | 1 | ranged | mage | mon_arcane_bolt | 160 | 38 | 15 | 30 | - | - | Monsters_Recolored/se_echo_wisp.png |
| se_glass_viper | Glass Viper | crystal | 1 | 1 | melee | melee | mon_rending_strike | 174 | 43 | 14 | 33 | - | - | Monsters_Recolored/se_glass_viper.png |
| se_prism_scarab | Prism Scarab | crystal | 1 | 1 | ranged | ranged | mon_aimed_shot | 190 | 33 | 19 | 25 | - | - | Monsters_Recolored/se_prism_scarab.png |
| se_reality_flicker | Reality Flicker | crystal | 1 | 1 | melee | melee | mon_heavy_strike | 162 | 40 | 14 | 33 | - | - | Monsters_Recolored/se_reality_flicker.png |
| se_shard_sprite | Shard Sprite | crystal | 1 | 1 | ranged | mage | mon_arcane_bolt | 157 | 35 | 14 | 35 | - | - | Monsters_Recolored/se_shard_sprite.png |
| se_starfall_hare | Starfall Hare | crystal | 1 | 1 | melee | melee | mon_rending_strike | 168 | 38 | 15 | 35 | - | - | Monsters_Recolored/se_starfall_hare.png |
| se_astral_colossus | Astral Colossus | crystal | 2 | 2 | melee | melee | mon_ground_slam, mon_berserker_rage | 360 | 50 | 24 | 36 | ELITE | - | Monsters_Recolored/se_astral_colossus.png |
| se_chrono_warden | Chrono Warden | crystal | 2 | 2 | melee | melee | mon_devastating_charge, mon_heavy_strike | 320 | 52 | 22 | 42 | ELITE | - | Monsters_Recolored/se_chrono_warden.png |
| se_crystal_wraith | Crystal Wraith | crystal | 2 | 2 | ranged | mage | mon_chain_lightning | 266 | 48 | 26 | 28 | - | - | Monsters_Recolored/se_crystal_wraith.png |
| se_paradox_shade | Paradox Shade | crystal | 2 | 2 | melee | melee | mon_rending_strike | 252 | 50 | 24 | 30 | - | - | Monsters_Recolored/se_paradox_shade.png |
| se_refraction_golem | Refraction Golem | crystal | 2 | 2 | melee | melee | mon_ground_slam | 322 | 43 | 29 | 23 | - | - | Monsters_Recolored/se_refraction_golem.png |
| se_starfall_stalker | Starfall Stalker | crystal | 2 | 2 | ranged | ranged | mon_aimed_shot | 258 | 55 | 22 | 35 | - | - | Monsters_Recolored/se_starfall_stalker.png |
| se_timelost_knight | Time-Lost Knight | crystal | 2 | 2 | melee | melee | mon_heavy_strike | 308 | 50 | 29 | 25 | - | - | Monsters_Recolored/se_timelost_knight.png |
| se_void_moth | Void Moth | crystal | 2 | 2 | ranged | mage | mon_flame_burst | 246 | 53 | 24 | 33 | - | - | Monsters_Recolored/se_void_moth.png |
| se_shattered_oracle | The Shattered Oracle | crystal | 3 | 3 | ranged | mage | mon_meteor, mon_chain_lightning | 880 | 68 | 30 | 45 | - | BOSS | Monsters_Recolored/se_shattered_oracle.png |
| se_starfall_titan | Starfall Titan | crystal | 3 | 3 | melee | melee | mon_devastating_charge, mon_ground_slam | 950 | 72 | 32 | 42 | - | BOSS | Monsters_Recolored/se_starfall_titan.png |

## R6: Necropolis Crypts (16 monsters)

| ID | Display Name | Family | Tier | AI | Attack Type | Role | Abilities | HP | ATK | DEF | SPD | Elite? | Boss? | Portrait |
|----|-------------|--------|------|----|-------------|------|-----------|-----|-----|-----|-----|--------|-------|----------|
| nc_bone_legionnaire | Bone Legionnaire | necro | 1 | 1 | ranged | ranged | mon_aimed_shot | 234 | 40 | 20 | 27 | - | - | Monsters_Recolored/nc_bone_legionnaire.png |
| nc_carrion_beetle | Carrion Beetle | necro | 1 | 1 | melee | melee | mon_rending_strike | 216 | 48 | 18 | 33 | - | - | Monsters_Recolored/nc_carrion_beetle.png |
| nc_crypt_rat | Crypt Rat | necro | 1 | 1 | melee | melee | mon_heavy_strike | 195 | 43 | 15 | 39 | - | - | Monsters_Recolored/nc_crypt_rat.png |
| nc_ghoul_stalker | Ghoul Stalker | necro | 1 | 1 | melee | melee | mon_rending_strike | 198 | 50 | 15 | 42 | - | - | Monsters_Recolored/nc_ghoul_stalker.png |
| nc_shambling_husk | Shambling Husk | necro | 1 | 1 | melee | melee | mon_heavy_strike | 240 | 38 | 20 | 27 | - | - | Monsters_Recolored/nc_shambling_husk.png |
| nc_tombdust_wraith | Tombdust Wraith | necro | 1 | 1 | ranged | mage | mon_arcane_bolt | 204 | 45 | 15 | 36 | - | - | Monsters_Recolored/nc_tombdust_wraith.png |
| nc_bone_colossus | Bone Colossus | necro | 2 | 2 | melee | melee | mon_ground_slam | 384 | 53 | 29 | 27 | - | - | Monsters_Recolored/nc_bone_colossus.png |
| nc_death_knight | Death Knight | necro | 2 | 2 | melee | melee | mon_devastating_charge | 360 | 63 | 27 | 30 | - | - | Monsters_Recolored/nc_death_knight.png |
| nc_dread_wight | Dread Wight | necro | 2 | 2 | melee | melee | mon_rending_strike, mon_berserker_rage | 420 | 58 | 28 | 46 | ELITE | - | Monsters_Recolored/nc_dread_wight.png |
| nc_gravefiend | Gravefiend | necro | 2 | 2 | melee | melee | mon_heavy_strike | 390 | 58 | 29 | 27 | - | - | Monsters_Recolored/nc_gravefiend.png |
| nc_plague_revenant | Plague Revenant | necro | 2 | 2 | ranged | ranged | mon_poison_shot | 345 | 50 | 26 | 33 | - | - | Monsters_Recolored/nc_plague_revenant.png |
| nc_spectral_binder | Spectral Binder | necro | 2 | 2 | ranged | mage | mon_chain_lightning | 315 | 60 | 24 | 39 | - | - | Monsters_Recolored/nc_spectral_binder.png |
| nc_wraith_choir_conductor | Wraith Choir Conductor | necro | 2 | 2 | ranged | mage | mon_chain_lightning, mon_life_siphon | 390 | 60 | 26 | 50 | ELITE | - | Monsters_Recolored/nc_wraith_choir_conductor.png |
| nc_wraith_chorister | Wraith Chorister | necro | 2 | 2 | ranged | mage | mon_life_siphon | 300 | 55 | 23 | 36 | - | - | Monsters_Recolored/nc_wraith_chorister.png |
| nc_lich_eternal | The Lich Eternal | necro | 3 | 3 | ranged | mage | mon_meteor, mon_life_siphon | 1050 | 76 | 35 | 55 | - | BOSS | Monsters_Recolored/nc_lich_eternal.png |
| nc_ossuary_king | The Ossuary King | necro | 3 | 3 | melee | melee | mon_devastating_charge, mon_war_cry | 1150 | 80 | 38 | 50 | - | BOSS | Monsters_Recolored/nc_ossuary_king.png |

## R7: Fractured Realm (16 monsters)

| ID | Display Name | Family | Tier | AI | Attack Type | Role | Abilities | HP | ATK | DEF | SPD | Elite? | Boss? | Portrait |
|----|-------------|--------|------|----|-------------|------|-----------|-----|-----|-----|-----|--------|-------|----------|
| fr_blighted_echo | Blighted Echo | void | 1 | 1 | melee | melee | mon_heavy_strike | 282 | 46 | 21 | 42 | - | - | Monsters_Recolored/fr_blighted_echo.png |
| fr_corruption_tendril | Corruption Tendril | void | 1 | 1 | ranged | ranged | mon_aimed_shot | 262 | 48 | 18 | 46 | - | - | Monsters_Recolored/fr_corruption_tendril.png |
| fr_entropy_slug | Entropy Slug | void | 1 | 1 | melee | melee | mon_heavy_strike | 304 | 41 | 24 | 32 | - | - | Monsters_Recolored/fr_entropy_slug.png |
| fr_null_wisp | Null Wisp | void | 1 | 1 | ranged | mage | mon_arcane_bolt | 250 | 51 | 20 | 49 | - | - | Monsters_Recolored/fr_null_wisp.png |
| fr_rift_imp | Rift Imp | void | 1 | 1 | ranged | mage | mon_flame_burst | 243 | 53 | 20 | 53 | - | - | Monsters_Recolored/fr_rift_imp.png |
| fr_void_mite | Void Mite | void | 1 | 1 | melee | melee | mon_rending_strike | 240 | 44 | 18 | 53 | - | - | Monsters_Recolored/fr_void_mite.png |
| fr_abyssal_sentinel | Abyssal Sentinel | void | 2 | 2 | melee | melee | mon_ground_slam | 480 | 53 | 33 | 32 | - | - | Monsters_Recolored/fr_abyssal_sentinel.png |
| fr_corruption_avatar | Corruption Avatar | void | 2 | 2 | melee | melee | mon_rending_strike | 416 | 62 | 29 | 39 | - | - | Monsters_Recolored/fr_corruption_avatar.png |
| fr_corruption_champion | Corruption Champion | void | 2 | 2 | melee | melee | mon_devastating_charge, mon_berserker_rage | 540 | 64 | 32 | 52 | ELITE | - | Monsters_Recolored/fr_corruption_champion.png |
| fr_dimensional_horror | Dimensional Horror | void | 2 | 2 | melee | melee | mon_ground_slam, mon_berserker_rage | 500 | 66 | 30 | 56 | ELITE | - | Monsters_Recolored/fr_dimensional_horror.png |
| fr_entropy_colossus | Entropy Colossus | void | 2 | 2 | melee | melee | mon_ground_slam | 474 | 55 | 32 | 32 | - | - | Monsters_Recolored/fr_entropy_colossus.png |
| fr_reality_shredder | Reality Shredder | void | 2 | 2 | melee | melee | mon_rending_strike | 384 | 64 | 26 | 49 | - | - | Monsters_Recolored/fr_reality_shredder.png |
| fr_thoughtrender | Thoughtrender | void | 2 | 2 | ranged | mage | mon_chain_lightning | 400 | 60 | 27 | 42 | - | - | Monsters_Recolored/fr_thoughtrender.png |
| fr_void_weaver | Void Weaver | void | 2 | 2 | ranged | ranged | mon_aimed_shot | 378 | 58 | 30 | 46 | - | - | Monsters_Recolored/fr_void_weaver.png |
| fr_prime_corruptor | The Prime Corruptor | void | 3 | 3 | ranged | mage | mon_meteor, mon_chain_lightning | 1300 | 86 | 40 | 60 | - | BOSS | Monsters_Recolored/fr_prime_corruptor.png |
| fr_void_sovereign | The Void Sovereign | void | 3 | 3 | ranged | mage | mon_meteor, mon_life_siphon | 1400 | 90 | 42 | 55 | - | BOSS | Monsters_Recolored/fr_void_sovereign.png |

---

## Stat Ranges per Region-Tier

| Region | Tier | Count | HP min/avg/max | ATK min/avg/max | DEF min/avg/max | SPD min/avg/max |
|--------|------|-------|----------------|-----------------|-----------------|-----------------|
| R1 | T1 | 7 | 47/57/72 | 8/13/16 | 2/3/5 | 10/14/18 |
| R1 | T2 | 6 | 54/98/130 | 16/21/26 | 4/7/12 | 11/16/20 |
| R1 | T3 | 3 | 110/230/300 | 24/29/32 | 8/10/12 | 16/18/20 |
| R2 | T1 | 6 | 64/73/88 | 14/18/21 | 3/4/7 | 13/16/18 |
| R2 | T2 | 8 | 100/123/175 | 21/25/30 | 6/9/12 | 13/16/22 |
| R2 | T3 | 2 | 400/425/450 | 40/41/42 | 15/16/16 | 22/23/24 |
| R3 | T1 | 6 | 88/97/110 | 23/27/30 | 6/8/11 | 16/22/26 |
| R3 | T2 | 8 | 143/176/220 | 33/37/40 | 14/16/20 | 16/22/28 |
| R3 | T3 | 2 | 520/550/580 | 50/51/52 | 20/21/22 | 28/29/30 |
| R4 | T1 | 6 | 120/128/145 | 30/36/41 | 10/12/14 | 20/28/33 |
| R4 | T2 | 8 | 188/228/280 | 42/47/51 | 18/20/24 | 20/28/34 |
| R4 | T3 | 2 | 680/715/750 | 58/60/62 | 25/26/28 | 35/36/38 |
| R5 | T1 | 6 | 157/168/190 | 33/38/43 | 14/15/19 | 25/32/35 |
| R5 | T2 | 8 | 246/292/360 | 43/50/55 | 22/25/29 | 23/32/42 |
| R5 | T3 | 2 | 880/915/950 | 68/70/72 | 30/31/32 | 42/44/45 |
| R6 | T1 | 6 | 195/214/240 | 38/44/50 | 15/17/20 | 27/34/42 |
| R6 | T2 | 8 | 300/363/420 | 50/57/63 | 23/26/29 | 27/36/50 |
| R6 | T3 | 2 | 1050/1100/1150 | 76/78/80 | 35/36/38 | 50/52/55 |
| R7 | T1 | 6 | 240/264/304 | 41/47/53 | 18/20/24 | 32/46/53 |
| R7 | T2 | 8 | 378/446/540 | 53/60/66 | 26/30/33 | 32/44/56 |
| R7 | T3 | 2 | 1300/1350/1400 | 86/88/90 | 40/41/42 | 55/58/60 |
