# copy_audio.ps1 — Copy and rename all selected audio files into project
# Run from project root: powershell -File DevTools\copy_audio.ps1

$proj = "c:\Users\rober\OneDrive\ShopKeepers Game\Assets\Audio"
$bundles = "c:\Users\rober\Downloads\Bundles"
$dungeon = "$bundles\Dungeon Music Pack\MP3s\MP3s"
$orchestra = "$bundles\Fantasy RPG Orchestra Music Pack\Fantasy RPG Orchestra Music Pack"
$combat = "$bundles\RPG Combat SFX Pack\RPG Combat SFX\SFX"
$magic = "$bundles\Magic Spells SFX Bundle\Magic Spells SFX Bundle\Stereo"

$count = 0

function CopyAudio($src, $dest) {
    if (Test-Path $src) {
        Copy-Item $src $dest -Force
        $script:count++
        Write-Host "  OK: $(Split-Path $dest -Leaf)"
    } else {
        Write-Host "  MISSING: $src" -ForegroundColor Red
    }
}

# === BGM: Region Themes (Dungeon Music Pack) ===
Write-Host "`n=== BGM Region Themes ==="
CopyAudio "$dungeon\Mystical Forest.mp3"      "$proj\BGM\Region\bgm_region_1_forest_haven.mp3"
CopyAudio "$dungeon\Alien Hive.mp3"            "$proj\BGM\Region\bgm_region_2_fungalmire.mp3"
CopyAudio "$dungeon\Underwater Temple.mp3"     "$proj\BGM\Region\bgm_region_3_sunken_strand.mp3"
CopyAudio "$dungeon\Fire Dungeon.mp3"          "$proj\BGM\Region\bgm_region_4_ashen_horizons.mp3"
CopyAudio "$dungeon\Crystal Caves.mp3"         "$proj\BGM\Region\bgm_region_5_starfall_expanse.mp3"
CopyAudio "$dungeon\Necropolis.mp3"            "$proj\BGM\Region\bgm_region_6_necropolis.mp3"
CopyAudio "$dungeon\Final Dungeon.mp3"         "$proj\BGM\Region\bgm_region_7_final_realm.mp3"

# === BGM: Scene Music (Fantasy Orchestra) ===
Write-Host "`n=== BGM Scene Music ==="
CopyAudio "$orchestra\Provincial Village (LOOP).wav"  "$proj\BGM\Region\bgm_town.wav"
CopyAudio "$orchestra\The Apothecary (LOOP).wav"      "$proj\BGM\Region\bgm_shop.wav"
CopyAudio "$orchestra\Sacred Shrine (LOOP).wav"       "$proj\BGM\Region\bgm_dungeon_camp.wav"

# === BGM: Combat Music (Fantasy Orchestra) ===
Write-Host "`n=== BGM Combat Music ==="
CopyAudio "$orchestra\Narrow Escape (LOOP).wav"       "$proj\BGM\Combat\bgm_combat_normal.wav"
CopyAudio "$orchestra\Desperate Moment (LOOP).wav"    "$proj\BGM\Combat\bgm_combat_boss.wav"

# === BGM: Stingers (RPG Combat SFX) ===
Write-Host "`n=== BGM Stingers ==="
CopyAudio "$combat\Complete.wav"        "$proj\BGM\Stingers\stinger_victory.wav"
CopyAudio "$combat\Damage Retro.wav"    "$proj\BGM\Stingers\stinger_defeat.wav"

# === SFX: Combat Melee ===
Write-Host "`n=== SFX Combat Melee ==="
CopyAudio "$combat\Sword 1.wav"          "$proj\SFX\Combat\Melee\sword_attack_01.wav"
CopyAudio "$combat\Swipe and Smack.wav"  "$proj\SFX\Combat\Melee\axe_attack_01.wav"
CopyAudio "$combat\Hard Punch Gut.wav"   "$proj\SFX\Combat\Melee\mace_attack_01.wav"
CopyAudio "$combat\Stab.wav"             "$proj\SFX\Combat\Melee\dagger_attack_01.wav"
CopyAudio "$combat\Sword Swipe.wav"      "$proj\SFX\Combat\Melee\attack_generic.wav"

# === SFX: Combat Ranged ===
Write-Host "`n=== SFX Combat Ranged ==="
CopyAudio "$combat\Swipe.wav"            "$proj\SFX\Combat\Ranged\bow_attack_01.wav"

# === SFX: Combat Impact ===
Write-Host "`n=== SFX Combat Impact ==="
CopyAudio "$combat\Punch Flesh Damage.wav"      "$proj\SFX\Combat\Impact\hit_damage.wav"
CopyAudio "$combat\Hard Punch Flesh.wav"         "$proj\SFX\Combat\Impact\hit_critical.wav"
CopyAudio "$combat\Block 1.wav"                  "$proj\SFX\Combat\Impact\block.wav"
CopyAudio "$combat\Dodge.wav"                    "$proj\SFX\Combat\Impact\miss.wav"
CopyAudio "$combat\Stab Damage.wav"              "$proj\SFX\Combat\Impact\death_hero.wav"
CopyAudio "$combat\Stab Damage (Monster).wav"    "$proj\SFX\Combat\Impact\death_enemy.wav"
CopyAudio "$combat\Sword Clash.wav"              "$proj\SFX\Combat\Impact\combat_start.wav"

# === SFX: Combat Magic (generic + elemental) ===
Write-Host "`n=== SFX Combat Magic ==="
CopyAudio "$magic\Generic\Summon 1.mp3"        "$proj\SFX\Combat\Magic\spell_generic.mp3"
CopyAudio "$magic\Fire\Fire 1.mp3"             "$proj\SFX\Combat\Magic\spell_fire.mp3"
CopyAudio "$magic\Ice\Ice 1.mp3"               "$proj\SFX\Combat\Magic\spell_ice.mp3"
CopyAudio "$magic\Electric\Electric 1.mp3"     "$proj\SFX\Combat\Magic\spell_lightning.mp3"
CopyAudio "$magic\Nature\Nature 1.mp3"         "$proj\SFX\Combat\Magic\spell_nature.mp3"
CopyAudio "$magic\Madness\Madness 1.mp3"       "$proj\SFX\Combat\Magic\spell_void.mp3"
CopyAudio "$magic\Fear\Fear 5.mp3"             "$proj\SFX\Combat\Magic\spell_shadow.mp3"
CopyAudio "$magic\Water\Water 1.mp3"           "$proj\SFX\Combat\Magic\spell_water.mp3"
CopyAudio "$magic\Earthquake\Earthquake 1.mp3" "$proj\SFX\Combat\Magic\spell_earth.mp3"
CopyAudio "$magic\Wind\Wind 1.mp3"             "$proj\SFX\Combat\Magic\spell_wind.mp3"
CopyAudio "$magic\Thunder\Thunder 8.mp3"       "$proj\SFX\Combat\Magic\spell_doom.mp3"

# === SFX: Combat Status ===
Write-Host "`n=== SFX Combat Status ==="
CopyAudio "$magic\Heal\Heal 1.mp3"                    "$proj\SFX\Combat\Status\heal.mp3"
CopyAudio "$magic\Shield\Shield 1.mp3"                "$proj\SFX\Combat\Status\buff_apply.mp3"
CopyAudio "$magic\Fear\Fear 1.mp3"                    "$proj\SFX\Combat\Status\debuff_apply.mp3"
CopyAudio "$magic\Sleep-Silence\Sleep-Silence 1.mp3"  "$proj\SFX\Combat\Status\stun_applied.mp3"
CopyAudio "$magic\Generic\Loop 1.mp3"                 "$proj\SFX\Combat\Status\status_tick.mp3"
CopyAudio "$magic\Generic\Dissipate 1.mp3"            "$proj\SFX\Combat\Status\status_expire.mp3"
CopyAudio "$magic\Misc\Mana Potion 1.mp3"             "$proj\SFX\Combat\Status\consumable_use.mp3"
CopyAudio "$magic\Tomes-Books\Open Tome 1.mp3"        "$proj\SFX\Combat\Status\passive_trigger.mp3"

# === SFX: Town ===
Write-Host "`n=== SFX Town ==="
CopyAudio "$combat\Coins 1.wav"        "$proj\SFX\Town\gold_gain.wav"
CopyAudio "$combat\Coins 3.wav"        "$proj\SFX\Town\gold_spend.wav"
CopyAudio "$combat\Discovery 1.wav"    "$proj\SFX\Town\hero_recruit.wav"
CopyAudio "$combat\Drop Item 1.wav"    "$proj\SFX\Town\hero_dismiss.wav"
CopyAudio "$combat\Open Door.wav"      "$proj\SFX\Town\facility_access.wav"
CopyAudio "$combat\Complete.wav"        "$proj\SFX\Town\facility_upgrade.wav"
CopyAudio "$combat\Completion.wav"      "$proj\SFX\Town\unlock_purchase.wav"
CopyAudio "$combat\Fade.wav"           "$proj\SFX\Town\travel_region.wav"
CopyAudio "$magic\Misc\Spell Fail 1.mp3"  "$proj\SFX\Town\error_insufficient.mp3"

# === SFX: Inventory ===
Write-Host "`n=== SFX Inventory ==="
CopyAudio "$combat\Item Equip 1.wav"   "$proj\SFX\Inventory\item_pickup.wav"
CopyAudio "$combat\Item Equip 2.wav"   "$proj\SFX\Inventory\equip_weapon.wav"
CopyAudio "$combat\Item Equip 3.wav"   "$proj\SFX\Inventory\equip_armor.wav"
CopyAudio "$combat\Metal Hit.wav"      "$proj\SFX\Inventory\equip_accessory.wav"
CopyAudio "$combat\Drop Item 2.wav"    "$proj\SFX\Inventory\equip_bag.wav"
CopyAudio "$combat\Drop Item 1.wav"    "$proj\SFX\Inventory\unequip.wav"
CopyAudio "$magic\Misc\Mana Potion 2.mp3"  "$proj\SFX\Inventory\consume_potion.mp3"
CopyAudio "$combat\Patch Up.wav"       "$proj\SFX\Inventory\consume_food.wav"

# === SFX: Shop ===
Write-Host "`n=== SFX Shop ==="
CopyAudio "$combat\Coins 2.wav"        "$proj\SFX\Inventory\item_buy.wav"
CopyAudio "$combat\Coins 4.wav"        "$proj\SFX\Inventory\item_sell.wav"
CopyAudio "$combat\Metal Jingle.wav"   "$proj\SFX\Inventory\item_select.wav"

# === SFX: Events ===
Write-Host "`n=== SFX Events ==="
CopyAudio "$magic\Tomes-Books\Open Scroll 1.mp3"  "$proj\SFX\Events\event_trigger.mp3"
CopyAudio "$magic\Tomes-Books\Turn Page 3.mp3"    "$proj\SFX\Events\event_choice.mp3"
CopyAudio "$combat\Discovery 2.wav"               "$proj\SFX\Events\event_outcome_good.wav"
CopyAudio "$magic\Misc\Spell Fail 3.mp3"          "$proj\SFX\Events\event_outcome_bad.mp3"
CopyAudio "$magic\Generic\Spell End 1.mp3"        "$proj\SFX\Events\event_outcome_neutral.mp3"

# === SFX: Dungeon/Camp ===
Write-Host "`n=== SFX Dungeon ==="
CopyAudio "$magic\Tomes-Books\Turn Page 1.mp3"    "$proj\SFX\Events\room_choice.mp3"
CopyAudio "$combat\Complete.wav"                   "$proj\SFX\Events\extraction.wav"
CopyAudio "$combat\Footstep on Gravel.wav"         "$proj\SFX\Events\descend_floor.wav"
CopyAudio "$combat\Step Indoors.wav"               "$proj\SFX\Events\camp_arrive.wav"

# === SFX: Loot ===
Write-Host "`n=== SFX Loot ==="
CopyAudio "$combat\Discovery 1.wav"    "$proj\SFX\Loot\loot_appear.wav"
CopyAudio "$combat\Coins 5.wav"        "$proj\SFX\Loot\loot_assign.wav"
CopyAudio "$combat\Drop Item 2.wav"    "$proj\SFX\Loot\loot_discard.wav"

# === SFX: Phase Stingers ===
Write-Host "`n=== SFX Stingers ==="
CopyAudio "$combat\Fade.wav"                      "$proj\SFX\Stingers\dungeon_enter.wav"
CopyAudio "$combat\Completion.wav"                 "$proj\SFX\Stingers\extraction_success.wav"
CopyAudio "$magic\Bravery\Bravery 1.mp3"          "$proj\SFX\Stingers\level_up.mp3"

Write-Host "`n=== DONE: $count files copied ==="
