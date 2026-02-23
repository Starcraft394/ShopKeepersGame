# Balance Reference

> Auto-generated reference for game balance analysis.

---

## 1. Abilities

### Damage Abilities

| id | display_name | damage_type | base_power | cooldown | target_type | atk_scaling | status_applied |
|----|-------------|-------------|-----------|---------|-------------|------------|----------------|
| basic_attack | Basic Attack | physical | 10 | 0 | single_enemy | -- | -- |
| cinder_strike | Cinder Strike | fire | 16 | 2 | single_enemy | 1.4 | burning (2t, 1s) |
| death_bolt | Death Bolt | dark | 22 | 2 | single_enemy | 1.5 | -- |
| def_fortify | Fortify | physical | 4 | 3 | single_enemy | 0.5 | -- |
| def_shield_bash | Shield Bash | physical | 6 | 4 | single_enemy | 0.8 | stun (1s) |
| entropy_blast | Entropy Blast | void | 12 | 5 | all_enemies | 1.0 | debuff: ATK -4 (2t) |
| fungal_frenzy | Fungal Frenzy | physical | 12 | 2 | single_enemy | 1.3 | self: ATK+4/DEF-2 (2t) |
| guardian_challenge | Guardian's Challenge | physical | 5 | 2 | single_enemy | 0.6 | bleeding (2t, 1s) |
| life_drain | Life Drain | dark | 10 | 2 | single_enemy | 0.8 | heals ally 12 |
| light_lance | Light Lance | magical | 18 | 2 | single_enemy | 1.3 | -- |
| lightning_bolt | Lightning Bolt | magical | 14 | 2 | single_enemy | 1.2 | -- |
| phase_strike | Phase Strike | void | 14 | 4 | single_enemy | 1.1 | armor piercing |
| prismatic_burst | Prismatic Burst | magical | 10 | 5 | all_enemies | 0.9 | blinded (1t) |
| pyre_slam | Pyre Slam | fire | 12 | 4 | single_enemy | 1.0 | burning (3t, 2s) |
| spore_burst | Spore Burst | physical | 7 | 4 | all_enemies | 0.6 | poisoned (3t, 2s) |
| spore_cloud | Spore Cloud | magical | 6 | 4 | all_enemies | 0.4 | poisoned (3t, 2s) |
| storm_surge | Storm Surge | magical | 8 | 5 | all_enemies | 0.8 | shocked (2t, 1s) |
| str_crippling_blow | Crippling Blow | physical | 8 | 2 | single_enemy | 1.0 | -- |
| str_precise_strike | Precise Strike | physical | 12 | 3 | single_enemy | 1.2 | -- |
| stunning_blow | Stunning Blow | physical | 8 | 4 | single_enemy | -- | stun (1s) |
| twin_strike | Twin Strike | physical | 4x2 | 2 | single_enemy | 0.7 | poisoned (2t, 1s) |
| void_tear | Void Tear | void | 16 | 2 | single_enemy | 1.2 | -- |
| weapon_sword_strike | Sword Strike | physical | 0 (1.5x) | 3 | single_enemy | 1.5x | -- |
| aegis_slam | Aegis Slam | physical | 10 | 4 | single_enemy | 1.0 | stunned (1t) |

### Heal Abilities

| id | display_name | base_heal | cooldown | target_type | notes |
|----|-------------|----------|---------|-------------|-------|
| cleansing_wave | Cleansing Wave | 8 | 4 | all_allies | cleanses 1 debuff |
| healing_tide | Healing Tide | 18 | 2 | single_ally | targets lowest HP% |
| natures_embrace | Nature's Embrace | 15 | 2 | single_ally | applies regenerating (2t) |
| natures_grace | Nature's Grace | 12 | 2 | single_ally | targets lowest HP% |
| shadow_mend | Shadow Mend | 18 | 3 | single_ally | costs 5 self HP |

### Buff Abilities

| id | display_name | cooldown | target_type | buff_effect | status_applied |
|----|-------------|---------|-------------|------------|----------------|
| barkskin_blessing | Barkskin Blessing | 4 | single_ally | DEF +5 (3t) | -- |
| flame_guard | Flame Guard | 3 | self | DEF +6 (2t) | taunting (2t) |
| light_refraction | Light Refraction | 5 | self | -- | reflecting (2t, 50%) |
| prism_barrier | Prism Barrier | 3 | self | shield 20 (2t) | taunting (2t) |
| raise_dead | Raise Dead | 5 | all_allies | ATK/SPD +3 (3t) | -- |
| shadowstep | Shadowstep | 4 | self | ATK +4, SPD +3 (3t) | -- |
| smoke_dash | Smoke Dash | 4 | self | SPD +6 (2t) | evasive (1t) |

### Debuff Abilities

| id | display_name | cooldown | target_type | debuff_effect | status_applied |
|----|-------------|---------|-------------|--------------|----------------|
| void_anchor | Void Anchor | 3 | all_enemies | SPD -3 (2t) | taunting (2t) |

---

## 2. Passives

### Class Passives

| id | display_name | trigger | effect | source_class |
|----|-------------|---------|--------|-------------|
| ash_veil | Ash Veil | combat_start | SPD +(2+level) | ashblade |
| bulwark_stance | Bulwark Stance | combat_start | DEF +(2+level) | defender |
| burning_presence | Burning Presence | combat_start | DEF +(3+level) | pyrewarden |
| burning_wounds | Burning Wounds | on_attack | +2 fire dmg vs burning targets | ashblade |
| crystal_resonance | Crystal Resonance | on_kill | next ability +3 bonus dmg | prism_lancer |
| crystal_shell | Crystal Shell | combat_start | DEF +(2+level/2) | prism_sentinel |
| dark_pact | Dark Pact | combat_start | ATK +(2+level), -5 max HP | dark_channeler |
| dimensional_shift | Dimensional Shift | combat_start | DEF +(3+level) | voidwalker |
| ember_shield | Ember Shield | on_melee_hit_received | 3+level/2 fire retaliation | pyrewarden |
| eye_of_storm | Eye of the Storm | on_kill | all cooldowns -1 | stormcaller |
| finishers_instinct | Finisher's Instinct | always | ATK +3 | striker |
| focused_light | Focused Light | combat_start | ATK +(3+level) | prism_lancer |
| fungal_symbiosis | Fungal Symbiosis | on_heal_ally | self heal 1+level/3 | druid |
| killer_instinct | Killer Instinct | on_kill | ATK +(1+level/2), stacks | striker |
| living_bond | Living Bond | always | HP +5 | warden |
| mushroom_rage | Mushroom Rage | hp_threshold (<50%) | ATK +(4+level) | fungal_berserker |
| necrotic_aura | Necrotic Aura | round_start | 2+level/3 dark dmg all enemies | lich |
| ocean_blessing | Ocean Blessing | combat_start | all allies DEF +(1+level) | tidechaser |
| phylactery | Phylactery | on_death | revive at 15% HP (1x) | lich |
| prismatic_ward | Prismatic Ward | round_start | shield +(2+level/2) | prism_sentinel |
| reality_warp | Reality Warp | combat_start | ATK +(2+level/2) | void_herald |
| shielding_presence | Shielding Presence | always | allies DEF +2 | defender |
| soul_siphon | Soul Siphon | on_enemy_death | heal 3+level/2 | dark_channeler |
| static_charge | Static Charge | combat_start | ATK +(3+level) | stormcaller |
| tidal_flow | Tidal Flow | round_start | heal lowest HP% ally 2+level | tidechaser |
| toxic_blood | Toxic Blood | on_melee_hit_received | 2+level/2 poison retaliation | fungal_berserker |
| verdant_growth | Verdant Growth | combat_start | all allies HP +(2+level) | druid |
| verdant_renewal | Verdant Renewal | round_start | heal lowest HP% ally 3+level | warden |
| void_resonance | Void Resonance | on_kill | ATK +1 per kill (max 5) | void_herald |
| void_shell | Void Shell | on_hit_received | 20% negate damage | voidwalker |

### Racial Passives

| id | display_name | trigger | effect | source |
|----|-------------|---------|--------|--------|
| crystalborn_refraction | Prismatic Refraction | combat_start | DEF +2, magic dmg -15% | crystalborn |
| dragonkin_scales | Draconic Scales | on_damage_received | all dmg -10%, burn immune | dragonkin |
| dwarf_deep_miner | Deep Miner | combat_start | DEF +1, HP +(5+level*2) | dwarf |
| elf_keen_sight | Keen Sight | combat_start | SPD +2 | elf |
| human_adaptability | Adaptability | combat_start | ATK +1, DEF +1, SPD +1 @lv3 | human |
| mossfolk_regeneration | Natural Regeneration | turn_start | heal 3% max HP | mossfolk |
| tideling_flow | Tidal Flow | combat_start | SPD +1, water resist 20% | tideling |
| undead_persistence | Deathless Persistence | combat_start | ATK +2, poison/bleed immune | undead |
| voidwalker_phase | Phase Shift | combat_start | SPD +2, 15% dodge | voidwalker |

### Legacy Passives (Older Versions)

| id | display_name | trigger | effect | source_class |
|----|-------------|---------|--------|-------------|
| def_front_line_bonus | Front Line | on_front_row | HP +10 | defender |
| def_iron_skin | Iron Skin | always | DEF +2 | defender |
| str_execute_momentum | Execute Momentum | on_kill | weapon CD -1 | striker |
| str_killer_instinct | Killer Instinct | always | ATK +2 | striker |

---

## 3. Status Effects

### Debuffs / Damage Over Time

| id | display_name | category | base_value | per_stack | max_stacks | duration | cleansable | notes |
|----|-------------|----------|-----------|----------|-----------|---------|-----------|-------|
| bleeding | Bleeding | dot | 2 dmg/t | +1 | 3 | 3 | yes | physical DoT |
| blinded | Blinded | debuff | 50% miss | -- | 1 | 1 | yes | miss chance |
| burn | Burn | dot | 3 dmg/t | +1 | 5 | 3 | yes | fire DoT |
| burning | Burning | dot | 3 dmg/t | +1 | 5 | 3 | yes | fire DoT (alt id) |
| doom | Doom | countdown | 10 dmg | -- | 5 | 0 | yes | detonates at 0 |
| poisoned | Poisoned | dot | 3 dmg/t | +1 | 3 | 3 | yes | poison DoT |
| shocked | Shocked | dot | 2 dmg/t | +1 | 3 | 2 | yes | lightning DoT, SPD -2 |
| stun | Stun | control | skip turn | -- | 1 | 1 | yes | legacy id |
| stunned | Stunned | control | skip turn | -- | 1 | 1 | yes | skip turn |

### Buffs

| id | display_name | category | base_value | per_stack | max_stacks | duration | dispellable | notes |
|----|-------------|----------|-----------|----------|-----------|---------|------------|-------|
| evasive | Evasive | buff | 50% dodge | -- | 1 | 1 | buff | avoid attacks |
| reflecting | Reflecting | buff | 50% reflect | -- | 1 | 2 | buff | reflect dmg |
| regenerating | Regenerating | buff | 4 heal/t | +2 | 3 | 2 | buff | heal over time |
| taunting | Taunting | buff | taunt | -- | 1 | 2 | buff | force target |

---

## 4. Equipment Stat Curves

### Stat Budget Summary (ATK + DEF + HP + SPD totals)

| Tier | Slot | Count | Min | Avg | Max |
|------|------|-------|-----|-----|-----|
| 1 | accessory_1 | 2 | 2 | 3.5 | 5 |
| 1 | accessory_2 | 2 | 2 | 3.0 | 4 |
| 1 | backpack | 1 | 0 | 0.0 | 0 |
| 1 | chest | 2 | 3 | 4.5 | 6 |
| 1 | head | 3 | 2 | 2.7 | 4 |
| 1 | legs | 2 | 3 | 3.5 | 4 |
| 1 | weapon_main | 4 | 3 | 4.2 | 6 |
| 1 | weapon_offhand | 2 | 4 | 6.0 | 8 |
| 2 | accessory_1 | 2 | 8 | 9.5 | 11 |
| 2 | accessory_2 | 2 | 8 | 9.5 | 11 |
| 2 | backpack | 1 | 0 | 0.0 | 0 |
| 2 | chest | 2 | 11 | 14.0 | 17 |
| 2 | head | 2 | 8 | 8.5 | 9 |
| 2 | legs | 2 | 7 | 8.0 | 9 |
| 2 | weapon_main | 7 | 6 | 9.1 | 15 |
| 2 | weapon_offhand | 4 | 8 | 11.8 | 16 |
| 3 | accessory_1 | 1 | 14 | 14.0 | 14 |
| 3 | accessory_2 | 2 | 12 | 14.5 | 17 |
| 3 | chest | 4 | 7 | 18.5 | 28 |
| 3 | head | 2 | 12 | 13.0 | 14 |
| 3 | legs | 2 | 5 | 7.5 | 10 |
| 3 | weapon_main | 7 | 12 | 16.3 | 25 |
| 3 | weapon_offhand | 4 | 14 | 19.2 | 25 |
| 4 | accessory_1 | 2 | 19 | 21.0 | 23 |
| 4 | accessory_2 | 2 | 17 | 20.0 | 23 |
| 4 | chest | 4 | 18 | 30.0 | 43 |
| 4 | head | 2 | 22 | 23.0 | 24 |
| 4 | legs | 2 | 12 | 13.5 | 15 |
| 4 | weapon_main | 8 | 18 | 23.5 | 39 |
| 4 | weapon_offhand | 4 | 20 | 27.5 | 37 |
| 5 | accessory_1 | 1 | 28 | 28.0 | 28 |
| 5 | accessory_2 | 1 | 13 | 13.0 | 13 |
| 5 | chest | 2 | 29 | 40.5 | 52 |
| 5 | head | 1 | 27 | 27.0 | 27 |
| 5 | legs | 1 | 17 | 17.0 | 17 |
| 5 | weapon_main | 5 | 24 | 29.6 | 46 |
| 5 | weapon_offhand | 2 | 30 | 38.0 | 46 |

### Tier Scaling Factor (avg total stat budget across all slots)

| Tier | Avg Budget (weapon_main) | Avg Budget (chest) | Avg Budget (offhand) |
|------|--------------------------|--------------------|--------------------|
| 1 | 4.2 | 4.5 | 6.0 |
| 2 | 9.1 | 14.0 | 11.8 |
| 3 | 16.3 | 18.5 | 19.2 |
| 4 | 23.5 | 30.0 | 27.5 |
| 5 | 29.6 | 40.5 | 38.0 |

### Full Equipment List

| id | name | tier | slot | ATK | DEF | HP | SPD | total |
|----|------|------|------|-----|-----|-----|------|-------|
| copper_band | Copper Band | 1 | accessory_1 | 0 | 1 | 0 | 1 | 2 |
| simple_ring | Simple Ring | 1 | accessory_1 | 0 | 0 | 5 | 0 | 5 |
| bone_charm | Bone Charm | 1 | accessory_2 | 1 | 0 | 0 | 1 | 2 |
| lucky_charm | Lucky Charm | 1 | accessory_2 | 0 | 1 | 3 | 0 | 4 |
| small_backpack | Small Backpack | 1 | backpack | 0 | 0 | 0 | 0 | 0 |
| leather_vest | Leather Vest | 1 | chest | 0 | 2 | 0 | 1 | 3 |
| cloth_robe | Cloth Robe | 1 | chest | 0 | 1 | 5 | 0 | 6 |
| cloth_cap | Cloth Cap | 1 | head | 0 | 1 | 3 | 0 | 4 |
| padded_coif | Padded Coif | 1 | head | 0 | 2 | 0 | 0 | 2 |
| tanned_leather_hood | Tanned Leather Hood | 1 | head | 0 | 1 | 0 | 1 | 2 |
| cloth_leggings | Cloth Leggings | 1 | legs | 0 | 1 | 3 | 0 | 4 |
| tanned_leather_greaves | Tanned Leather Greaves | 1 | legs | 0 | 2 | 0 | 1 | 3 |
| hunting_bow | Hunting Bow | 1 | weapon_main | 3 | 0 | 0 | 1 | 4 |
| oak_staff | Oak Staff | 1 | weapon_main | 3 | 0 | 3 | 0 | 6 |
| rusty_sword | Rusty Sword | 1 | weapon_main | 3 | 0 | 0 | 0 | 3 |
| wooden_mace | Wooden Mace | 1 | weapon_main | 5 | 0 | 0 | -1 | 4 |
| apprentice_focus | Apprentice Focus | 1 | weapon_offhand | 1 | 0 | 3 | 0 | 4 |
| wooden_shield | Wooden Shield | 1 | weapon_offhand | 0 | 3 | 5 | 0 | 8 |
| silver_ring | Silver Ring | 2 | accessory_1 | 0 | 0 | 8 | 0 | 8 |
| fm_bioluminescent_ring | Bioluminescent Ring | 2 | accessory_1 | 0 | 0 | 10 | 1 | 11 |
| warriors_pendant | Warrior's Pendant | 2 | accessory_2 | 3 | 2 | 3 | 0 | 8 |
| fm_mycelium_pendant | Mycelium Pendant | 2 | accessory_2 | 0 | 3 | 8 | 0 | 11 |
| sturdy_backpack | Sturdy Backpack | 2 | backpack | 0 | 0 | 0 | 0 | 0 |
| chainmail_vest | Chainmail Vest | 2 | chest | 0 | 4 | 8 | -1 | 11 |
| fm_mycelium_vest | Mycelium Vest | 2 | chest | 0 | 6 | 12 | -1 | 17 |
| iron_helmet | Iron Helmet | 2 | head | 0 | 3 | 5 | 0 | 8 |
| fm_sporeguard_helm | Sporeguard Helm | 2 | head | 0 | 4 | 6 | -1 | 9 |
| iron_greaves | Iron Greaves | 2 | legs | 0 | 3 | 6 | 0 | 9 |
| fm_mycelium_leggings | Mycelium Leggings | 2 | legs | 0 | 3 | 4 | 0 | 7 |
| composite_bow | Composite Bow | 2 | weapon_main | 5 | 0 | 0 | 2 | 7 |
| iron_sword | Iron Sword | 2 | weapon_main | 6 | 0 | 0 | 1 | 7 |
| iron_greataxe | Iron Greataxe | 2 | weapon_main | 8 | 0 | 0 | -2 | 6 |
| arcane_staff | Arcane Staff | 2 | weapon_main | 5 | 0 | 6 | 0 | 11 |
| fm_spore_blade | Spore Blade | 2 | weapon_main | 8 | 0 | 0 | 1 | 9 |
| fm_fungal_longbow | Fungal Longbow | 2 | weapon_main | 7 | 0 | 0 | 2 | 9 |
| fm_fungal_staff | Fungal Staff | 2 | weapon_main | 7 | 0 | 8 | 0 | 15 |
| wooden_focus | Wooden Focus | 2 | weapon_offhand | 2 | 0 | 5 | 1 | 8 |
| reinforced_shield | Reinforced Shield | 2 | weapon_offhand | 0 | 5 | 8 | 0 | 13 |
| fm_spore_focus | Spore Focus | 2 | weapon_offhand | 3 | 0 | 6 | 1 | 10 |
| fm_sporecap_shield | Sporecap Shield | 2 | weapon_offhand | 0 | 6 | 10 | 0 | 16 |
| ss_tidecaller_ring | Tidecaller's Ring | 3 | accessory_1 | 2 | 0 | 12 | 0 | 14 |
| ss_pearl_amulet | Pearl Amulet | 3 | accessory_2 | 3 | 3 | 6 | 0 | 12 |
| ah_cinder_amulet | Cinder Amulet | 3 | accessory_2 | 3 | 0 | 14 | 0 | 17 |
| ss_kelp_vest | Kelp Vest | 3 | chest | 0 | 5 | 0 | 2 | 7 |
| ah_drake_jerkin | Drake Jerkin | 3 | chest | 0 | 7 | 8 | 1 | 16 |
| ss_barnacle_plate | Barnacle Plate | 3 | chest | 0 | 8 | 16 | -1 | 23 |
| ah_magma_plate | Magma Plate | 3 | chest | 0 | 10 | 20 | -2 | 28 |
| ss_tidecrest_helm | Tidecrest Helm | 3 | head | 0 | 5 | 8 | -1 | 12 |
| ah_volcanic_helm | Volcanic Helm | 3 | head | 0 | 5 | 10 | -1 | 14 |
| ss_kelp_greaves | Kelp Greaves | 3 | legs | 0 | 4 | 0 | 1 | 5 |
| ah_drake_greaves | Drake Greaves | 3 | legs | 0 | 4 | 5 | 1 | 10 |
| ss_coral_blade | Coral Blade | 3 | weapon_main | 11 | 0 | 0 | 1 | 12 |
| ss_tidestriker_bow | Tidestriker Bow | 3 | weapon_main | 10 | 0 | 0 | 3 | 13 |
| ah_ember_blade | Ember Blade | 3 | weapon_main | 13 | 0 | 0 | 2 | 15 |
| ah_volcanic_maul | Volcanic Maul | 3 | weapon_main | 15 | 0 | 0 | -2 | 13 |
| ah_scorched_longbow | Scorched Longbow | 3 | weapon_main | 12 | 0 | 0 | 3 | 15 |
| ss_coral_staff | Coral Staff | 3 | weapon_main | 9 | 0 | 12 | 0 | 21 |
| ah_obsidian_staff | Obsidian Staff | 3 | weapon_main | 11 | 0 | 14 | 0 | 25 |
| ss_sea_glass_focus | Sea Glass Focus | 3 | weapon_offhand | 4 | 0 | 8 | 2 | 14 |
| ah_ember_focus | Ember Focus | 3 | weapon_offhand | 5 | 0 | 10 | 1 | 16 |
| ss_abalone_shield | Abalone Shield | 3 | weapon_offhand | 0 | 8 | 14 | 0 | 22 |
| ah_drake_buckler | Drake Buckler | 3 | weapon_offhand | 0 | 9 | 16 | 0 | 25 |
| se_temporal_band | Temporal Band | 4 | accessory_1 | 0 | 0 | 16 | 3 | 19 |
| nc_deathward_ring | Deathward Ring | 4 | accessory_1 | 0 | 3 | 20 | 0 | 23 |
| se_echo_amulet | Echo Amulet | 4 | accessory_2 | 5 | 4 | 8 | 0 | 17 |
| nc_bonecaller_amulet | Bonecaller Amulet | 4 | accessory_2 | 0 | 5 | 18 | 0 | 23 |
| se_astral_robe | Astral Robe | 4 | chest | 0 | 8 | 8 | 2 | 18 |
| nc_wraith_robe | Wraith Robe | 4 | chest | 0 | 10 | 12 | 2 | 24 |
| se_crystal_ward | Crystal Ward | 4 | chest | 0 | 12 | 24 | -1 | 35 |
| nc_ossuary_plate | Ossuary Plate | 4 | chest | 0 | 15 | 30 | -2 | 43 |
| se_prism_helm | Prism Helm | 4 | head | 0 | 8 | 15 | -1 | 22 |
| nc_bone_crown | Bone Crown | 4 | head | 0 | 9 | 16 | -1 | 24 |
| se_astral_leggings | Astral Leggings | 4 | legs | 0 | 5 | 5 | 2 | 12 |
| nc_wraith_leggings | Wraith Leggings | 4 | legs | 0 | 6 | 8 | 1 | 15 |
| se_chrono_cleaver | Chrono Cleaver | 4 | weapon_main | 20 | 0 | 0 | -2 | 18 |
| se_prism_blade | Prism Blade | 4 | weapon_main | 16 | 0 | 0 | 2 | 18 |
| nc_grave_dagger | Grave Dagger | 4 | weapon_main | 14 | 0 | 0 | 5 | 19 |
| se_starfall_bow | Starfall Bow | 4 | weapon_main | 15 | 0 | 0 | 4 | 19 |
| nc_soul_reaver | Soul Reaver | 4 | weapon_main | 19 | 0 | 0 | 2 | 21 |
| nc_wraith_bow | Wraith Bow | 4 | weapon_main | 18 | 0 | 0 | 4 | 22 |
| se_prism_staff | Prism Staff | 4 | weapon_main | 14 | 0 | 18 | 0 | 32 |
| nc_bone_staff | Bone Staff | 4 | weapon_main | 17 | 0 | 22 | 0 | 39 |
| se_starlight_focus | Starlight Focus | 4 | weapon_offhand | 6 | 0 | 12 | 2 | 20 |
| nc_soulfire_focus | Soulfire Focus | 4 | weapon_offhand | 7 | 0 | 14 | 1 | 22 |
| se_echo_shield | Echo Shield | 4 | weapon_offhand | 0 | 11 | 20 | 0 | 31 |
| nc_spectral_aegis | Spectral Aegis | 4 | weapon_offhand | 0 | 13 | 24 | 0 | 37 |
| fr_dimensional_locket | Dimensional Locket | 5 | accessory_2 | 6 | 5 | 0 | 2 | 13 |
| fr_rift_band | Rift Band | 5 | accessory_1 | 0 | 0 | 24 | 4 | 28 |
| fr_void_shroud | Void Shroud | 5 | chest | 0 | 12 | 14 | 3 | 29 |
| fr_dimensional_plate | Dimensional Plate | 5 | chest | 0 | 18 | 36 | -2 | 52 |
| fr_void_helm | Void Helm | 5 | head | 0 | 10 | 18 | -1 | 27 |
| fr_void_greaves | Void Greaves | 5 | legs | 0 | 7 | 8 | 2 | 17 |
| fr_void_fang | Void Fang | 5 | weapon_main | 17 | 0 | 0 | 7 | 24 |
| fr_entropy_maul | Entropy Maul | 5 | weapon_main | 28 | 0 | 0 | -3 | 25 |
| fr_void_edge | Void Edge | 5 | weapon_main | 23 | 0 | 0 | 3 | 26 |
| fr_entropy_bow | Entropy Bow | 5 | weapon_main | 22 | 0 | 0 | 5 | 27 |
| fr_rift_staff | Rift Staff | 5 | weapon_main | 20 | 0 | 26 | 0 | 46 |
| fr_null_focus | Null Focus | 5 | weapon_offhand | 9 | 0 | 18 | 3 | 30 |
| fr_null_barrier | Null Barrier | 5 | weapon_offhand | 0 | 16 | 30 | 0 | 46 |

---

## 5. Class Stat Blocks

| id | display_name | archetype | region | HP | ATK | DEF | SPD | HP/lv | ATK/lv | DEF/lv | SPD/lv | ability_a | ability_b | passive_a | passive_b |
|----|-------------|-----------|--------|-----|------|------|------|-------|--------|--------|--------|-----------|-----------|-----------|-----------|
| striker | Striker | striker | 1 | 80 | 14 | 5 | 12 | +6 | +2 | +1 | +2 | twin_strike | shadowstep | killer_instinct | finishers_instinct |
| defender | Defender | vanguard | 1 | 120 | 8 | 15 | 6 | +9 | +1 | +2 | +1 | guardian_challenge | aegis_slam | bulwark_stance | shielding_presence |
| warden | Warden | warden | 1 | 100 | 6 | 12 | 8 | +7 | +1 | +1 | +2 | natures_grace | barkskin_blessing | living_bond | verdant_renewal |
| druid | Druid | healer | 2 | 90 | 6 | 10 | 8 | +6 | +1 | +1 | +2 | natures_embrace | spore_cloud | verdant_growth | fungal_symbiosis |
| fungal_berserker | Fungal Berserker | dps | 2 | 100 | 14 | 8 | 9 | +7 | +2 | +1 | +2 | fungal_frenzy | spore_burst | mushroom_rage | toxic_blood |
| tidechaser | Tidechaser | healer | 3 | 95 | 7 | 11 | 10 | +7 | +1 | +1 | +2 | healing_tide | cleansing_wave | tidal_flow | ocean_blessing |
| stormcaller | Stormcaller | dps | 3 | 85 | 16 | 7 | 11 | +5 | +2 | +1 | +3 | lightning_bolt | storm_surge | static_charge | eye_of_storm |
| pyrewarden | Pyrewarden | vanguard | 4 | 130 | 10 | 16 | 5 | +10 | +1 | +2 | +1 | flame_guard | pyre_slam | burning_presence | ember_shield |
| ashblade | Ashblade | dps | 4 | 80 | 18 | 6 | 14 | +5 | +3 | +1 | +3 | cinder_strike | smoke_dash | ash_veil | burning_wounds |
| prism_sentinel | Prism Sentinel | vanguard | 5 | 120 | 9 | 18 | 4 | +11 | +1 | +2 | +1 | prism_barrier | light_refraction | crystal_shell | prismatic_ward |
| prism_lancer | Prism Lancer | dps | 5 | 90 | 17 | 9 | 12 | +6 | +3 | +1 | +2 | light_lance | prismatic_burst | focused_light | crystal_resonance |
| dark_channeler | Dark Channeler | healer | 6 | 85 | 10 | 9 | 9 | +5 | +2 | +1 | +2 | life_drain | shadow_mend | dark_pact | soul_siphon |
| lich | Lich | dps | 6 | 70 | 16 | 5 | 10 | +4 | +2 | +1 | +2 | death_bolt | raise_dead | phylactery | necrotic_aura |
| voidwalker | Voidwalker | vanguard | 7 | 125 | 11 | 14 | 8 | +10 | +2 | +2 | +2 | void_anchor | phase_strike | dimensional_shift | void_shell |
| void_herald | Void Herald | dps | 7 | 75 | 18 | 4 | 13 | +5 | +3 | +1 | +3 | void_tear | entropy_blast | reality_warp | void_resonance |

### Archetype Stat Ranges (base stats)

| Archetype | Classes | HP Range | ATK Range | DEF Range | SPD Range |
|-----------|---------|----------|-----------|-----------|-----------|
| vanguard | Defender, Pyrewarden, Prism Sentinel, Voidwalker | 120-130 | 8-11 | 14-18 | 4-8 |
| dps | Striker, Fungal Bersrk, Stormcaller, Ashblade, Prism Lancer, Lich, Void Herald | 70-100 | 14-18 | 4-9 | 9-14 |
| healer | Druid, Tidechaser, Dark Channeler | 85-95 | 6-10 | 9-11 | 8-10 |
| warden | Warden | 100 | 6 | 12 | 8 |

---

## 6. Monster Stat Overview

| Tier | Count | Avg HP | Avg ATK | Avg DEF | Avg SPD | Bosses | Elites |
|------|-------|--------|---------|---------|---------|--------|--------|
| 1 | 43 | 141.1 | 31.3 | 11.0 | 27.1 | 0 | 0 |
| 2 | 54 | 252.1 | 43.2 | 19.4 | 28.1 | 0 | 13 |
| 3 | 15 | 720.0 | 57.5 | 24.9 | 35.9 | 14 | 1 |

**Total: 112 monsters (14 bosses, 14 elites, 84 normal)**

### Tier Progression Ratios

| Stat | T1 -> T2 | T2 -> T3 |
|------|----------|----------|
| HP | x1.79 | x2.86 |
| ATK | x1.38 | x1.33 |
| DEF | x1.76 | x1.28 |
| SPD | x1.04 | x1.28 |

### Balance Notes

- **Monster HP scales most aggressively** between tiers, especially T2->T3 (nearly 3x).
- **Monster ATK** scales more moderately (~1.35x per tier).
- **Monster SPD** stays relatively flat at T1->T2, then jumps at T3.
- **T3 monsters are predominantly bosses/elites** (14 bosses + 1 elite out of 15 total), explaining the large stat jump.
- **Hero base ATK** (14-18 for DPS) vs **T1 monster DEF** (11.0 avg) suggests roughly 3-7 effective damage per unscaled hit at level 1.
- **Equipment stat budgets** roughly double per tier: T1 weapon ~4, T2 ~9, T3 ~16, T4 ~24, T5 ~30.

---

## 7. Monster Combat Overview

### Targeting Rules
- **Melee (GRID_DEFAULT)**: Must target frontmost alive row. Within row, targets lowest absolute HP.
- **Ranged (GRID_DEFAULT)**: Can target any row. Targets lowest %HP hero.

### Combat Role System

| Role | Count | Description |
|------|-------|-------------|
| melee | 72 | Frontline fighters, beasts, constructs — physical damage |
| mage | 29 | Casters, elementals, wraiths — magical damage, AoE |
| ranged | 11 | Archers, hurlers, spitters — physical ranged attacks |

### AI Tier System

| ai_tier | Name | Behavior | Count |
|---------|------|----------|-------|
| 0 | Feral | Basic/weapon only — ignores ability slots | 7 |
| 1 | Basic | Fixed priority: A → B → weapon → basic | 35 |
| 2 | Tactical | Random pick from ready abilities | 56 |
| 3 | Strategic | Fixed priority (context-aware deferred) | 14 |

### Ability Coverage

| Extra Abilities | Monster Count | Notes |
|----------------|---------------|-------|
| 0 | 7 | R1 T1 normals only (ai_tier 0) |
| 1 | 77 | T1 normals (R2+) + T2 normals |
| 2 | 28 | Elites + bosses |

### Monster Ability Pool (18 abilities)

**Melee Role:**
| Ability | Target | Damage | Scale | CD | Status |
|---------|--------|--------|-------|----|--------|
| mon_heavy_strike | single | 6 | 0.8 | 3 | — |
| mon_rending_strike | single | 5 | 0.8 | 3 | bleeding (2s, 3t) |
| mon_ground_slam | AoE | 4 | 0.5 | 4 | — |
| mon_berserker_rage | self | buff | — | 5 | ATK +6 (3t) |
| mon_devastating_charge | single | 12 | 1.0 | 5 | stun |

**Ranged Role:**
| Ability | Target | Damage | Scale | CD | Status |
|---------|--------|--------|-------|----|--------|
| mon_aimed_shot | single | 7 | 0.6 | 3 | — |
| mon_poison_shot | single | 5 | 0.6 | 3 | poisoned (2s, 3t) |
| mon_volley | AoE | 4 | 0.4 | 4 | — |
| mon_mark_prey | single | debuff | — | 4 | DEF -5 (3t) |
| mon_rain_of_arrows | AoE | 8 | 0.6 | 5 | bleeding (2s, 3t) |

**Mage Role:**
| Ability | Target | Damage | Scale | CD | Status |
|---------|--------|--------|-------|----|--------|
| mon_arcane_bolt | single | 8 | 0.5 | 3 | — |
| mon_flame_burst | single | 6 | 0.6 | 3 | burning (2s, 3t) |
| mon_chain_lightning | AoE | 5 | 0.4 | 4 | shocked (1s, 2t) |
| mon_life_siphon | single | 8 | 0.8 | 4 | heal self 8 |
| mon_meteor | AoE | 10 | 0.6 | 5 | burning (2s, 3t) |

**Support (shared):**
| Ability | Target | Effect | CD |
|---------|--------|--------|----|
| mon_mend_ally | lowest HP% ally | heal 12 | 4 |
| mon_war_cry | all allies | ATK +4 (3t) | 5 |
| mon_regeneration | all allies | heal 10 | 5 |

### Balance Notes

- **R1 T1 monsters** (ai_tier 0) use basic attack only — tutorial-difficulty fights
- **R2+ T1 normals** (ai_tier 1) have 1 ability each — predictable but dangerous
- **T2 normals + elites** (ai_tier 2) use 1-2 abilities with random selection — unpredictable
- **Bosses** (ai_tier 3) have 2 abilities on fixed priority — strong openers, then sustained pressure
- **6 ranged conversions** in R5-R7 (2 per region) add targeting variety to late-game encounters
- No monsters have passives yet (future pass)
- See `Docs/MONSTER_MANIFEST.md` for complete per-monster data
