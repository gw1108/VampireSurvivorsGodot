# Enemies {#firstHeading .firstHeading .mw-first-heading}

[Jump to navigation](#mw-head) [Jump to search](#searchInput)

<figure typeof="mw:File/Thumb">

<figcaption>A variety of enemies in the game.<br />
From left to right: <a href="The_Directer.md">The Directer</a> (bottom left corner), <a href="The_Reaper.md">The Reaper</a>, <a href="Pipeestrello.md">Glowing Bat</a>, <a href="Stage_Killer.md">Stage Killer</a>, <a href="Megalo_Impostor_Rina.md">Megalo Impostor Rina</a>, <a href="Je-Ne-Viv_(enemy).md">Je-Ne-Viv</a>, <a href="Moon_Duck.md">Moon Duck</a>.</figcaption>
</figure>

**Enemies** are entities in *[Vampire Survivors](Vampire_Survivors.md)* that attack the player\'s [character](Character.md), simply by approaching them. By killing enemies the player may gain  [experience gems](Experience_Gem.md) and can [level up](Level_up.md), gaining access to more [weapons](Weapon.md) and [passives](Passive.md). A list of all enemies, along with their stats and descriptions, can be found in the game\'s [Bestiary](Bestiary.md).

## Spawning {#Spawning}

Upon entering a [stage](Stage.md), an initial amount of enemies depending on the stage modifiers spawns. Thereafter the game periodically attempts to spawn enemies. Enemies generally spawn just outside the screen and can despawn if the player moves far enough from them.

### Waves {#Waves}

Enemies normally arrive in waves - one wave every minute. Each wave specifies a minimum amount and a spawn interval for the enemies. If the minimum amount is not met when the game attempts to spawn enemies, enemies will be spawned until the quota is filled. If more enemies than the minimum amount is present, one of each type of enemies in the wave will be spawned. When 300 or more enemies are alive the game will not spawn more enemies periodically, and only [bosses](Boss.md) and enemies from [map events](Map_event.md) can spawn.

### Bosses {#Bosses}

Bosses are special enemies that spawn in some waves. They are stronger than other enemies in the wave, having more health, dealing more damage and often also being resistant to some effects. Bosses also have a chance to drop a  [Treasure Chest](Treasure_Chest.md) when they are killed. Bosses do not despawn when the player moves away from them, but get teleported back to the screen.

### Map events {#Map_events}

Map events are short events that spawn groups of enemies outside the regular spawning cycle. Map events can, for example, summon a swarm of enemies that quickly sweep across the screen or encircle the player with high health enemies.

#### Wave events {#Wave_events}

Map events are usually tied to a wave and trigger at the same second marks every time for that wave, making it possible to anticipate them. Multiple events can take place during a wave. Each event specifies how many enemies are spawned, how many times and what intervals the event is repeated.

Wave events usually also have a chance for them to happen, which is reduced by  [Luck](Luck.md):

$chanceWithLuck = \frac{eventChance}{totalLuck}$

The chance is unique for each event and is evaluated for every repeat of the event. If the event has no chance listed or a chance of 0, it is guaranteed to play out.

#### Traps {#Traps}

[Dairy Plant](Dairy_Plant.md) and [Gallo Tower](Gallo_Tower.md) feature circular pressure plates on the ground, which upon being stepped on trigger an unavoidable event. The event chosen at random from a set of predetermined options unique to the stage. The trap events have a global cooldown, which depends on [Luck](Luck.md):

$effectiveCooldown = trapCooldown \cdot totalLuck$

#### Special events {#Special_events}

Special events are usually one time events that are spawned on global timer and/or have unique trigger conditions. They are not part of the stage\'s waves, so the enemies introduced through them cannot appear in [Green Acres](Green_Acres.md).

## Stats {#Stats}

Like the player, enemies have stats, which define how they interact with other effects.

### Base stats {#Base_stats}

Health
: Health describes how much damage is required to kill the enemy.

<!-- -->

Power
: Power describes how much damage the enemy does to the player upon coming in contact with them before modifications, such as [Armor](Armor_(stat).md).

<!-- -->

Speed
: Speed, or MoveSpeed, describes how fast the enemy moves.

<!-- -->

Knockback
: [Knockback](Knockback.md) is a multiplier for the strength of the pushing effect when hit by the player\'s [weapons](Weapon.md).

<!-- -->

XP
: XP describes how much [experience](Experience.md) the enemy grants when killed.

### Resistances {#Resistances}

Freeze resistance
: [Freeze](Freeze.md) resistance prevents the enemy from being frozen by the player. It is given as a numerical value. If the enemy\'s freeze resistance is higher than freeze chance of the weapon they were hit by it will not be frozen. Freeze from [Orologion](Orologion.md) goes through freeze resistance.

<!-- -->

Instant kill resistance
: Instant kill resistance grants immunity to effects that instantly defeat an enemy by dealing damage to them equal to their maximum health. Instant kill can be applied by [Pentagram](Pentagram.md), [Gorgeous Moon](Gorgeous_Moon.md) and [Rosary](Rosary.md).

<!-- -->

Debuff resistance
: Debuff resistance grants an immunity to effects that weaken the affected enemy upon hit. Effects classified as debuffs are the knockback and freeze resistance reductions from [Garlic](Garlic.md) and [Soul Eater](Soul_Eater.md), and the slow effect from [Mannajja](Mannajja.md).

### Skills {#Skills}

Skills are passive effects some enemies have.

HP x Level
: HP x Level multiplies the enemy\'s health based on the player\'s level. This is applied the moment the enemy was spawned, and will not be updated in case the player gains levels while it\'s alive.

<!-- -->

Fixed Direction
: Causes the enemy to only move in a straight line, instead of continuously homing to the player.

<!-- -->

Floaty
: Also known as \"Medusa\". Causes the enemy to move in a wavy pattern.

## Effects {#Effects}

Some mechanics in the game specifically target enemies, altering their stats and spawning.

### Curse {#Curse}

Main article: [Curse](Curse.md)

[Curse](Curse.md) is a stat that increases the [Max Health](Max_Health.md) and [Move Speed](Move_Speed.md) of the enemies and the frequency they spawn. The new spawn interval with any amount of Curse can be calculated as follows:

$effectiveSpawnInterval = \frac{spawnInterval}{totalCurse}$

### Hyper mode {#Hyper_mode}

Main article: [Stage § Modes](Stage.md#Modes)

Hyper mode in each stage increases the minimum amount of enemies spawned and the movement speed of enemies. It may also increase their maximum health.

## Bestiary locator {#Bestiary_locator}

Main article: [Calculators/BestiaryLocator](Calculators/BestiaryLocator.md)

template = Template:BestiaryLocator form = bestiarylocator-form result = bestiarylocator-result name=Find missing bestiary number param = bnum\|Bestiary number\|1\|int\|1-372\|\|Enter the bestiary number you are missing. param = platform\|Platform\|steam\|buttonselect\|Steam, Epic, Xbox, PlayStation, Switch, iOS, Android\|\|Only accounts for rearrangements in DLC ordering, does not account for version differences inserting missing bestiary entries.\
Currently, only mobile platforms have a different bestiary order than all others. param = old_version\|Old version\|false\|toggleswitch\|\|\|Enable to remove the most recently-added bestiary entries from the list.\
Useful if you are on a platform that has not yet received an update adding bestiary entries. param = select_dlc\|Owned DLC\|All\|buttonselect\|All, Free, Select\|Select=owneddlc_group\|**All**: Enable all expansions.\
**Free**: Enable all free expansions.\
**Select**: Enable expansions individually. param = owneddlc_group\|DLC expansions\|\|group\|dlc_lm, dlc_tf, dlc_em, dlc_og, dlc_oc, dlc_ed, dlc_ac\|\| param = dlc_lm\| [Legacy of the Moonspell](Legacy_of_the_Moonspell.md)\|true\|check\|\|\| param = dlc_tf\| [Tides of the Foscari](Tides_of_the_Foscari.md)\|true\|check\|\|\| param = dlc_em\| [Emergency Meeting](Emergency_Meeting.md)\|true\|check\|\|\| param = dlc_og\| [Operation Guns](Operation_Guns.md)\|true\|check\|\|\| param = dlc_oc\| [Ode to Castlevania](Ode_to_Castlevania.md)\|true\|check\|\|\| param = dlc_ed\| [Emerald Diorama](Emerald_Diorama.md)\|true\|check\|\|\| param = dlc_ac\| [Ante Chamber](Ante_Chamber.md)\|true\|check\|\|\|

The calculator form will appear here soon. You will need JavaScript enabled.

The result will appear here when you submit the form.

## List of enemies {#List_of_enemies}

Currently, there are 360 unique bestiary entries in the game (372 in beta). Any enemy that has a yellow name in the [Bestiary](Ars_Gouda.md) is required for an unlock. For example, [Dragon Shrimp](Dragon_Shrimp.md) has a yellow name because the player must kill 3000 for  [O\'Sole Meeo](O'Sole_Meeo.md).

|  |  |  |  |  |  |
|----|----|----|----|----|----|
| \# | Sprite | Name^[\[n\ 1\]](#cite_note-enemy-names-1)^ | Unique | Stages | Notes |
| 001 |  | [Pipeestrello](Pipeestrello.md) |  | [Mad Forest](Mad_Forest.md), [Gallo Tower](Gallo_Tower.md) | N/A |
| 002 |  | [Bloodbath](Bloodbath.md) |  | [Gallo Tower](Gallo_Tower.md) | N/A |
| 003 |  | [Skullino](Skullino.md) |  | [Gallo Tower](Gallo_Tower.md), [The Bone Zone](The_Bone_Zone.md) | N/A |
| 004 |  | [Skulorosso](Skulorosso.md) |  | [Gallo Tower](Gallo_Tower.md), [The Bone Zone](The_Bone_Zone.md) | N/A |
| 005 |  | [Scarleton](Scarleton.md) |  | [Gallo Tower](Gallo_Tower.md), [The Bone Zone](The_Bone_Zone.md) | Has three lives. |
| 006 | ; | [Skeleton](Skeleton.md) |  | [Mad Forest](Mad_Forest.md), [Dairy Plant](Dairy_Plant.md), [Gallo Tower](Gallo_Tower.md), [The Bone Zone](The_Bone_Zone.md) | N/A |
| 007 |  | [Zombie](Zombie.md) |  | [Mad Forest](Mad_Forest.md) | N/A |
| 008 |  | [Mudman](Mudman.md) |  | [Mad Forest](Mad_Forest.md) | N/A |
| 009 |  | [Flower Wall](Flower_Wall.md) |  | [Mad Forest](Mad_Forest.md) | HP x Level |
| 010 |  | [Skelegem](Skelegem.md) |  |  | Only spawns with  [Call of a Mad Moon (XIII)](Call_of_a_Mad_Moon_(XIII).md) |
| 011 |  | [Ghost](Ghost.md) |  | [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), [Gallo Tower](Gallo_Tower.md) | N/A |
| 012 |  | [Werewolf](Werewolf.md) |  | [Mad Forest](Mad_Forest.md) | N/A |
| 013 |  | [Dust Elemental](Dust_Elemental.md) |  | [Inlaid Library](Inlaid_Library.md) | Colossal version has HP x Level. |
| 014 |  | [Lionhead](Lionhead.md) |  | [Inlaid Library](Inlaid_Library.md) | HP x Level |
| 015 |  | [Milk Elemental](Milk_Elemental.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 016 |  | [Dragon Shrimp](Dragon_Shrimp.md) |  | [Gallo Tower](Gallo_Tower.md) | HP x Level |
| 017 |  | [Sig.ra Rossi](Sig.ra_Rossi.md) |  | [Inlaid Library](Inlaid_Library.md) | Self-destruct, HP x Level |
| 018 |  | [Poltergeist](Poltergeist.md) |  | [Gallo Tower](Gallo_Tower.md), [Cappella Magna](Cappella_Magna.md) | Self-destruct, HP x Level |
| 019 |  | [Hag](Hag.md) |  | [Inlaid Library](Inlaid_Library.md) | Resistant to Freeze, Rosary, Debuff and Knockback.; HP x Level. |
| 020 |  | [Nesufritto](Nesufritto.md) |  | [Inlaid Library](Inlaid_Library.md) | Resistant to Freeze.; HP x Level. |
| 021 |  | [Mummy](Mummy.md) |  | [Inlaid Library](Inlaid_Library.md) | N/A |
| 022 |  | [Sneaky Head](Sneaky_Head.md) |  | [Inlaid Library](Inlaid_Library.md) | Colossal version has HP x Level. |
| 023 |  | [Harzia](Harzia.md) |  | [Gallo Tower](Gallo_Tower.md) | Has a version that has fixed direction, moves vertically in a wavy pattern. |
| 024 |  | [Musc Musc](Musc_Musc.md) |  | [Inlaid Library](Inlaid_Library.md) | Colossal version has HP x Level. |
| 025 |  | [Impefinger](Impefinger.md) |  | [Gallo Tower](Gallo_Tower.md) | N/A |
| 026 |  | [Testa di Mano](Testa_di_Mano.md) |  | [Inlaid Library](Inlaid_Library.md), [Gallo Tower](Gallo_Tower.md) | N/A |
| 027 |  | [Ghiavolo](Ghiavolo.md) |  | [Gallo Tower](Gallo_Tower.md) | N/A |
| 028 |  | [Undead Mage](Undead_Mage.md) |  | [Gallo Tower](Gallo_Tower.md) | Shoots bullets at 2 second intervals. |
| 029 |  | [Undead Witch](Undead_Witch.md) |  | [Inlaid Library](Inlaid_Library.md) | N/A |
| 030 |  | [Undead Sassy Witch](Undead_Sassy_Witch.md) |  | [Inlaid Library](Inlaid_Library.md) | N/A |
| 031 |  | [Archon Spada](Archon_Spada.md) |  | [Gallo Tower](Gallo_Tower.md) | N/A |
| 032 |  | [Archon Disco](Archon_Disco.md) |  | [Gallo Tower](Gallo_Tower.md) | N/A |
| 033 |  | [Merdusa](Merdusa.md) |  | [Inlaid Library](Inlaid_Library.md) | N/A |
| 034 |  | [Giant Bat](Giant_Bat.md) |  | [Mad Forest](Mad_Forest.md) | N/A |
| 035 |  | [Mantichana](Mantichana.md) |  | [Mad Forest](Mad_Forest.md) | N/A |
| 036 |  | [Big Mummy](Big_Mummy.md) |  | [Mad Forest](Mad_Forest.md) | N/A |
| 037 |  | [Venus](Venus.md) |  | [Mad Forest](Mad_Forest.md) | N/A |
| 038 |  | [Merman](Merman.md) |  | [Dairy Plant](Dairy_Plant.md), [Moongolow](Moongolow.md) | N/A |
| 039 |  | [Lizard Pawn](Lizard_Pawn.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 040 |  | [Twin Snakes](Twin_Snakes.md) |  | [Dairy Plant](Dairy_Plant.md) | Cannot move, shoots bullets at 2 second intervals. |
| 041 |  | [Lizard Rook](Lizard_Rook.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 042 |  | [Twin Demons](Twin_Demons.md) |  | [Dairy Plant](Dairy_Plant.md), [The Bone Zone](The_Bone_Zone.md) | Cannot move, shoots bullets at 1.5 second intervals. |
| 043 |  | [Jellyfish](Jellyfish.md) |  | [Dairy Plant](Dairy_Plant.md), [Moongolow](Moongolow.md) | Some version has fixed direction. |
| 044 |  | [Skeleton Ninja](Skeleton_Ninja.md) |  | [Dairy Plant](Dairy_Plant.md), [The Bone Zone](The_Bone_Zone.md) | N/A |
| 045 |  | [Lost Twin](Lost_Twin.md) |  | [Dairy Plant](Dairy_Plant.md), [The Bone Zone](The_Bone_Zone.md) | Cannot move, shoots bullets at 1 second intervals. |
| 046 |  | [Melone](Melone.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 047 |  | [Minotaur](Minotaur.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 048 |  | [Mignotaur](Mignotaur.md) |  | [Dairy Plant](Dairy_Plant.md) | Fixed direction |
| 049 |  | [Archon Lancia](Archon_Lancia.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 050 |  | [Archon Ascia](Archon_Ascia.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 051 |  | [Skelewing](Skelewing.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 052 |  | [Tritont](Tritont.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 053 |  | [Manticore](Manticore.md) |  | [Gallo Tower](Gallo_Tower.md) | N/A |
| 054 |  | [Gallotrice](Gallotrice.md) |  | [Dairy Plant](Dairy_Plant.md), [Gallo Tower](Gallo_Tower.md) | N/A |
| 055 |  | [Big Golem](Big_Golem.md) |  | [Dairy Plant](Dairy_Plant.md), [Boss Rash](Boss_Rash.md) | Some version has HP x Level, resistant to freeze. |
| 056 |  | [Meat Golem](Meat_Golem.md) |  | [Gallo Tower](Gallo_Tower.md) | N/A |
| 057 |  | [Sword Guardian](Sword_Guardian.md) |  | [Dairy Plant](Dairy_Plant.md) | N/A |
| 058 |  | [Giant Enemy Crab](Giant_Enemy_Crab.md) | Unique Boss | [Gallo Tower](Gallo_Tower.md) | Appears at 25:00; HP x Level |
| 059 |  | [Sad Molisano](Sad_Molisano.md) |  | [Il Molise](Il_Molise.md) | Cannot move. |
| 060 |  | [Happy Molisano](Happy_Molisano.md) |  | [Il Molise](Il_Molise.md) | Cannot move. |
| 061 |  | [Cute Molisano](Cute_Molisano.md) |  | [Il Molise](Il_Molise.md) | Cannot move. |
| 062 |  | [Old Molisano](Old_Molisano.md) |  | [Il Molise](Il_Molise.md) | Cannot move. |
| 063 |  | [Dead Molisano](Dead_Molisano.md) |  | [Il Molise](Il_Molise.md) | Cannot move. |
| 064 |  | [Bambaman](Bambaman.md) |  | [Whiteout](Whiteout.md) | N/A |
| 065 |  | [Miragellos](Miragellos.md) |  | [Whiteout](Whiteout.md) | N/A |
| 066 |  | [Menta Elemental](Menta_Elemental.md) |  | [Whiteout](Whiteout.md) | N/A |
| 067 |  | [Madd-Onna](Madd-Onna.md) |  | [Whiteout](Whiteout.md) | N/A |
| 068 |  | [Kizzune](Kizzune.md) |  | [Whiteout](Whiteout.md) | Resistant to Freeze, Rosary, Debuff and Knockback.; Hp x Level. |
| 069 |  | [Holy Circuit Creations](Holy_Circuit_Creations.md) |  | [Laborratory](Laborratory.md) | N/A |
| 070 |  | [Bounty Hunter](Bounty_Hunter.md) |  | [Laborratory](Laborratory.md) | N/A |
| 071 |  | [Space Hunter](Space_Hunter.md) |  | [Laborratory](Laborratory.md) | N/A |
| 072 |  | [Tri-Blunder](Tri-Blunder.md) |  | [Laborratory](Laborratory.md) | Resistant to Freeze, Debuff and Knockback |
| 073 |  | [Chickenfantry](Chickenfantry.md) |  | [The Coop](The_Coop.md) |  |
| 074 |  | [Cockreliutennant](Cockreliutennant.md) |  | [The Coop](The_Coop.md) |  |
| 075 |  | [Chik](Chik.md) |  | [The Coop](The_Coop.md) |  |
| 076 |  | [Egge](Egge.md) |  | [The Coop](The_Coop.md) |  |
| 077 |  | [Pol.lo Rosso](Pol.lo_Rosso.md) |  | [The Coop](The_Coop.md) |  |
| 078 |  | [Abraxas](Abraxas.md) |  | [The Coop](The_Coop.md) |  |
| 079 |  | [Abraxas Phronesis](Abraxas_Phronesis.md) |  | [The Coop](The_Coop.md) |  |
| 080 |  | [Abraxas Dynamis](Abraxas_Dynamis.md) |  | [The Coop](The_Coop.md) |  |
| 081 |  | [Gala Invader](Gala_Invader.md) |  | [Space 54](Space_54.md) | N/A |
| 082 |  | [Moon Rabbit](Moon_Rabbit.md) |  | [Space 54](Space_54.md) | Fixed Direction |
| 083 |  | [Moon Duck](Moon_Duck.md) |  | [Space 54](Space_54.md) | Fixed Direction |
| 084 |  | [Space Ant Onion](Space_Ant_Onion.md) |  | [Space 54](Space_54.md) | N/A |
| 085 |  | [Space Pickle](Space_Pickle.md) |  | [Space 54](Space_54.md) | N/A |
| 086 |  | [ECMASlime](ECMASlime.md) |  | [Space 54](Space_54.md) | N/A |
| 087 |  | [Sinistronz](Sinistronz.md) |  | [Space 54](Space_54.md) | Resistant to Freeze, Rosary, Debuff and Knockback |
| 088 |  | [Twin Skulls](Twin_Skulls.md) |  | [The Bone Zone](The_Bone_Zone.md) | Cannot move, shoots bullets at 1 second intervals. |
| 089 |  | [Skullone](Skullone.md) |  | [Inlaid Library](Inlaid_Library.md), [Gallo Tower](Gallo_Tower.md), [The Bone Zone](The_Bone_Zone.md), [Tiny Bridge](Tiny_Bridge.md) | Some version has HP x Level. |
| 090 |  | [Skeleton Panther](Skeleton_Panther.md) |  | [The Bone Zone](The_Bone_Zone.md) | N/A |
| 091 |  | [Giant Skeleton](Giant_Skeleton.md) |  | [The Bone Zone](The_Bone_Zone.md) | N/A |
| 092 | ; | [Skeletone](Skeletone.md) |  | [The Bone Zone](The_Bone_Zone.md) | HPxLevel |
| 093 |  | [Sketamari](Sketamari.md) | Unique Boss | [The Bone Zone](The_Bone_Zone.md) | Absorbs other enemies and gains their health.;  Fixed direction, resistant to freeze, rosary, instant kill, and debuffs. |
| 094 |  | [Sun Atlantean](Sun_Atlantean.md) | Unique Boss | [Moongolow](Moongolow.md), [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), others | Resistant to Freeze, Rosary, Debuff and Knockback |
| 095 |  | [Moon Atlantean](Moon_Atlantean.md) | Unique Boss | [Moongolow](Moongolow.md), [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), others | Resistant to Freeze, Rosary, Debuff and Knockback |
| 096 |  | [City Atlantean](City_Atlantean.md) | Unique Boss | [Moongolow](Moongolow.md), [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), others | Resistant to Freeze, Rosary, Debuff and Knockback |
| 097 |  | [Volcano Atlantean](Volcano_Atlantean.md) | Unique Boss | [Moongolow](Moongolow.md), [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), others | Resistant to Freeze, Rosary, Debuff and Knockback |
| 098 |  | [Moongolow Atlanteans](Moongolow_Atlanteans.md) | Unique Boss | [Moongolow](Moongolow.md) |  |
| 099 |  | [Serpentvine](Serpentvine.md) |  | [Moongolow](Moongolow.md) | N/A |
| 100 |  | [Garlic](Garlic_(enemy).md) |  | [Moongolow](Moongolow.md) | N/A |
| 101 |  | [Nightshade](Nightshade.md) |  | [Moongolow](Moongolow.md) | N/A |
| 102 |  | [Sig.ra Blu](Sig.ra_Blu.md) |  | [Moongolow](Moongolow.md) | Ignores collision. |
| 103 |  | [Non-Giant Enemy Crab](Non-Giant_Enemy_Crab.md) |  | [Moongolow](Moongolow.md) | Fixed Direction HP x Level |
| 104 |  | [Unknown](Unknown.md) | Boss | [Cappella Magna](Cappella_Magna.md) | Appears only during [lunar eclipse](Moongolow.md#lunar_eclipse).;  Resistant to Freeze, Rosary, and Debuffs. HP x Level. |
| 105 | ;  «» | [Reaper Trainee](Reaper_Trainee.md) |  | [Cappella Magna](Cappella_Magna.md) | Resistant to Freeze. HP x Level.;  Changes appearance in «Maddener\'s presence». |
| 106 |  | [Tetrabrachia](Tetrabrachia.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 107 |  | [Archon Fiamma](Archon_Fiamma.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 108 |  | [Succubus](Succubus_(enemy).md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 109 |  | [Archon Rame](Archon_Rame.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 110 |  | [Demon Priest](Demon_Priest.md) |  | [Cappella Magna](Cappella_Magna.md) | Has a \"fast\" variant that moves twice as fast. |
| 111 |  | [Fallen Cherub](Fallen_Cherub.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 112 |  | [Fallen Cherubbello](Fallen_Cherubbello.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 113 |  | [Fallen Throne](Fallen_Throne.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 114 |  | [Archon Oro](Archon_Oro.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 115 |  | [Demon Beast](Demon_Beast.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 116 |  | [Archdemon](Archdemon.md) |  | [Cappella Magna](Cappella_Magna.md) | N/A |
| 117 |  | [Trinacria](Trinacria.md) |  | [Cappella Magna](Cappella_Magna.md) | Resistant to knockback. |
| 118 | ; | [Stage Killer](Stage_Killer.md) |  | [Cappella Magna](Cappella_Magna.md) | HP x Level |
| 119 |  | [The Reaper](The_Reaper.md) |  | [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), [Dairy Plant](Dairy_Plant.md), others | Resistant to Freeze, Rosary, Debuff, Knockback Hp x Level |
| 120 |  | [The Trickster](The_Trickster.md) | Unique Boss | [Inlaid Library](Inlaid_Library.md), [Cappella Magna](Cappella_Magna.md) | Resistant to Freeze, Debuff, Knockback Hp x Level |
| 121 |  | [The Stalker](The_Stalker.md) | Unique Boss | [Dairy Plant](Dairy_Plant.md), [Cappella Magna](Cappella_Magna.md), [The Bone Zone](The_Bone_Zone.md), others | Resistant to Freeze, Debuff, Knockback Hp x Level |
| 122 |  | [The Drowner](The_Drowner.md) | Unique Boss | [Gallo Tower](Gallo_Tower.md), [Cappella Magna](Cappella_Magna.md), [The Bone Zone](The_Bone_Zone.md), others | Resistant to Freeze, Debuff, Knockback Hp x Level |
| 123 |  | [The Maddener](The_Maddener.md) | Unique Boss | [Cappella Magna](Cappella_Magna.md) | Resistant to Freeze, Rosary, Debuff, Knockback Hp x Level |
| 124 |  | [The Blinder](The_Blinder.md) | Boss | [Abyss Foscari](Abyss_Foscari.md) | Resistant to Freeze, Debuff, and Knockback.; Hp x Level |
| 125 |  | [The Ender](The_Ender.md) | Unique Boss | [Cappella Magna](Cappella_Magna.md) | Resistant to Freeze, Rosary, Debuff, Knockback Hp x Level |
| 126 | ; | [Mimic Season One](Mimic_Season_One.md) | Boss | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 127 | ; | [Mimic Season Two](Mimic_Season_Two.md) | Boss | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 128 | ; | [Mimic Season Three](Mimic_Season_Three.md) | Boss | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 129 |  | [Tri-Anchors](Tri-Anchors.md) |  | [Boss Rash](Boss_Rash.md) | Resistant to Freeze, Debuff, Knockback Hp x Level |
| 130 |  | [LV128 Golden Bat](LV128_Golden_Bat.md) |  | [Bat Country](Bat_Country.md), [Green Acres](Green_Acres.md) | N/A |
| 131 |  | [The Directer](The_Directer.md) |  | [Eudaimonia_Machine](Eudaimonia_Machine.md) | Resistant to Freeze, Rosary, Debuff, Knockback Hp x Level |
| 132 | N/A | [Astral Elemental](Astral_Elemental.md) |  | [Astral Stair](Astral_Stair.md) | N/A |
| 133 |  | [Astral Chair](Astral_Chair.md) |  | [Astral Stair](Astral_Stair.md) | Hp x Level |
| 134 |  | [Astral Curtain](Astral_Curtain.md) |  | [Astral Stair](Astral_Stair.md) | N/A |
| 135 |  | [Undead Stars](Undead_Stars.md) |  | [Astral Stair](Astral_Stair.md) | N/A |
| 136 |  | [Poetrait](Poetrait.md) |  | [Astral Stair](Astral_Stair.md) | Hp x Level |
| 137 |  | [Lord Ghost](Lord_Ghost.md) |  | [Astral Stair](Astral_Stair.md) | Resistant to Freeze, Rosary, Debuff, Knockback Hp x Level |
| 138 |  | [Cosmic Egg](Cosmic_Egg.md) |  | [Astral Stair](Astral_Stair.md) | Resistant to Freeze, Rosary, Debuff, Knockback Hp x Level |
| 139 |  | [Ska\'sa Ka\'sos](Ska'sa_Ka'sos.md) |  | [Room 1665](Room_1665.md) |  |
| 140 |  | [Juda R\'kasso](Juda_R'kasso.md) |  | [Room 1665](Room_1665.md) |  |
| 141 |  | [Foo\'Ori Darkasso](Foo'Ori_Darkasso.md) |  | [Room 1665](Room_1665.md) |  |
| 142 |  | [Shendi Darkasso](Shendi_Darkasso.md) |  | [Room 1665](Room_1665.md) |  |
| 143 |  | [Sphon\'Dato Darkasso](Sphon'Dato_Darkasso.md) |  | [Room 1665](Room_1665.md) |  |
| 144 |  | [Eh\'Lleve-Teh Darkasso](Eh'Lleve-Teh_Darkasso.md) |  | [Room 1665](Room_1665.md) |  |
| 145 |  | [Levatee Darkasso](Levatee_Darkasso.md) |  | [Room 1665](Room_1665.md) | [HP x Level](HP_x_Level.md), [Fixed Direction](Fixed_Direction.md) |
| 146 |  | [Levarsee Darkasso](Levarsee_Darkasso.md) |  | [Room 1665](Room_1665.md) | Resistant to Freeze, Rosary, Debuff. HP x Level. |
| 147 |  | [Much Much](Much_Much.md) |  | [Westwoods](Westwoods.md) |  |
| 148 |  | [Gold Pile](Gold_Pile.md) |  | [Westwoods](Westwoods.md) |  |
| 149 |  | [Gold Jellys](Gold_Jellys.md) |  | [Westwoods](Westwoods.md) |  |
| 150 |  | [Mantichana Idol](Mantichana_Idol.md) |  | [Westwoods](Westwoods.md) |  |
| 151 |  | [Knight of Spades](Knight_of_Spades.md) |  | [Westwoods](Westwoods.md) |  |
| 152 |  | [Barm](Barm.md) |  | [Westwoods](Westwoods.md) |  |
| 153 |  | [Ghoulette](Ghoulette.md) |  | [Westwoods](Westwoods.md) |  |
| 154 |  | [Goldie](Goldie.md) |  | [Westwoods](Westwoods.md) |  |
| 155 |  | [Dandybrine](Dandybrine.md) |  | [Westwoods](Westwoods.md) | Hp x Level |
| 156 |  | [Daimon](Daimon.md) |  | [Westwoods](Westwoods.md) | Hp x Level |
| 157 |  | [Gambergar](Gambergar.md) |  | [Westwoods](Westwoods.md) |  |
| 158 |  | [Gamblin](Gamblin.md) |  | [Westwoods](Westwoods.md) |  |
| 159 |  | [Jastor](Jastor.md) |  | [Westwoods](Westwoods.md) |  |
| 160 |  | [Mushroulette](Mushroulette.md) |  | [Westwoods](Westwoods.md) | Hp x Level |
| 161 |  | [Toll](Toll.md) |  | [Westwoods](Westwoods.md) |  |
| 162 |  | [Valentine](Valentine.md) |  | [Westwoods](Westwoods.md) |  |
| 163 |  | [Squillers](Squillers.md) |  | [Westwoods](Westwoods.md) |  |
| 164 |  | [Card Sharp](Card_Sharp.md) |  | [Westwoods](Westwoods.md) |  |
| 165 |  | [Torino](Torino_(enemy).md) |  | [Mazerella](Mazerella.md) |  |
| 166 |  | [Joyatauro](Joyatauro.md) |  | [Mazerella](Mazerella.md) |  |
| 167 |  | [AccumulaTori](AccumulaTori.md) |  | [Mazerella](Mazerella.md) |  |
| 168 |  | [17th Collossus](17th_Collossus.md) | Unique Boss | [Mazerella](Mazerella.md) |  |
| 169 |  | [Bat Dragon](Bat_Dragon.md) | Unique Boss |  |  |
| 170 |  | [Bat Drakelet](Bat_Drakelet.md) |  |  |  |
| 171 |  | [Deep Angellette](Deep_Angellette.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 172 |  | [Sea Ham](Sea_Ham.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 173 |  | [Deep Sluge](Deep_Sluge.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 174 |  | [Itchiocentaur](Itchiocentaur.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 175 |  | [Sea Spinach](Sea_Spinach.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 176 |  | [Olmo](Olmo.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 177 |  | [Awizotl](Awizotl.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 178 |  | [Buklavaca](Buklavaca.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 179 |  | [Enypnastys](Enypnastys.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 180 |  | [Deep Sphynx](Deep_Sphynx.md) |  | [The Lycaeum](The_Lycaeum.md) |  |
| 181 |  | [Spiritello](Spiritello.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 182 |  | [Hitotsume-kozo](Hitotsume-kozo.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | Hp x Level |
| 183 |  | [Kappa](Kappa.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | Hp x Level |
| 184 |  | [Tsuchinoko](Tsuchinoko.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 185 |  | [Mikoshi-nyudo](Mikoshi-nyudo.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 186 |  | [Kamaitachi](Kamaitachi.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 187 |  | [Raiju](Raiju.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 188 |  | [Yamamba](Yamamba.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 189 |  | [Tanuki](Tanuki.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | Hp x Level |
| 190 |  | [Tengu](Tengu.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 191 |  | [Tsuchigumo](Tsuchigumo.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 192 |  | [Windy Oni](Windy_Oni.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 193 |  | [Thunderous Oni](Thunderous_Oni.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 194 |  | [Big Oni](Big_Oni.md) |  | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level |
| 195 |  | [Goshadokuro](Goshadokuro.md) | Boss | [Mt.Moonspell](Mt.Moonspell.md) | Appears when getting close to a stage item Resistant to Rosary Hp x Level |
| 196 |  | [Orochimario](Orochimario.md) | Unique Boss | [Mt.Moonspell](Mt.Moonspell.md) | Appears at 25:00 Resistant to Freeze, Rosary, Debuff, Knockback Hp x Level |
| 197 |  | [Chompo](Chompo.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 198 |  | [Ceffoose](Ceffoose.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 199 |  | [Wiseparke](Wiseparke.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 200 |  | [Nutmeg](Nutmeg.md) |  | [Lake Foscari](Lake_Foscari.md) | Hp x Level |
| 201 |  | [Vulvio](Vulvio.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 202 |  | [Lammuga](Lammuga.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 203 |  | [Hill Trow](Hill_Trow.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 204 |  | [Sea Trow](Sea_Trow.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 205 |  | [Sam the Sandown Clown](Sam_the_Sandown_Clown.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 206 |  | [Sammy the Caterpillar](Sammy_the_Caterpillar.md) |  | [Lake Foscari](Lake_Foscari.md) | Fixed Direction, Hp x Level |
| 207 |  | [Brownie](Brownie.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 208 |  | [Green Knight](Green_Knight.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 209 |  | [Crocifriggitore](Crocifriggitore.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 210 |  | [Notadam](Notadam.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 211 |  | [Hand of Glory](Hand_of_Glory.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 212 |  | [Maronna](Maronna.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 213 |  | [Njuggles](Njuggles.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 214 |  | [Average Hag](Average_Hag.md) |  | [Lake Foscari](Lake_Foscari.md) | N/A |
| 215 |  | [Fungoman](Fungoman.md) |  | [Lake Foscari](Lake_Foscari.md) | Hp x Level |
| 216 |  | [Ghostly Apparition](Ghostly_Apparition.md) |  | [Lake Foscari](Lake_Foscari.md) | Resistant to Freeze, Debuff, and Knockback. Hp x Level |
| 217 |  | [Avatar of Gaea](Avatar_of_Gaea.md) | Unique Boss | [Lake Foscari](Lake_Foscari.md) | Unique; Appears at 25:00 Resistant to Freeze, Debuff, and Knockback. |
| 218 |  | [Cauld](Cauld.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 219 |  | [Redusa Head](Redusa_Head.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 220 |  | [Rellyfish](Rellyfish.md) |  | [Abyss Foscari](Abyss_Foscari.md) | Fixed Direction |
| 221 |  | [Blood Moss](Blood_Moss.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 222 |  | [Rotting Ghoul](Rotting_Ghoul.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 223 |  | [Burning Skull](Burning_Skull.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 224 |  | [Missing Church](Missing_Church.md) |  | [Lake Foscari](Lake_Foscari.md) , [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 225 |  | [Snek](Snek.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 226 |  | [Lost Head](Lost_Head.md) |  | [Abyss Foscari](Abyss_Foscari.md) | Cannot move, shoots bullets at 2 or 1.5 second intervals. |
| 227 |  | [Meatball](Meatball.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 228 |  | [Followa](Followa.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 229 |  | [Edna](Edna.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 230 |  | [Cold Cauld](Cold_Cauld.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 231 |  | [Well Dweller](Well_Dweller.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 232 |  | [Wet Njuggles](Wet_Njuggles.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 233 |  | [Crocifriggitone](Crocifriggitone.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 234 |  | [Still Notadam](Still_Notadam.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 235 |  | [Glove of Glory](Glove_of_Glory.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 236 |  | [Maronna Meea](Maronna_Meea.md) |  | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 237 |  | [Fomorians](Fomorians.md) |  | [Abyss Foscari](Abyss_Foscari.md) | Resistant to Freeze. Hp x Level |
| 238 |  | [Je-Ne-Viv](Je-Ne-Viv_(enemy).md) | Unique Boss | [Abyss Foscari](Abyss_Foscari.md) | Unique; Resistant to Freeze, Rosary, Debuff, and Knockback. Hp x Level |
| 239 |  | [Frijjitello](Frijjitello.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 240 |  | [Brainoid](Brainoid.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 241 |  | [Spotter](Spotter.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 242 |  | [Shapeunshifter](Shapeunshifter.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 243 |  | [Pinthot & Coldellini](Pinthot_&_Coldellini.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 244 |  | [Space Apparition](Space_Apparition.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 245 |  | [Mocholo](Mocholo.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 246 |  | [Meat Bean](Meat_Bean.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 247 |  | [Martian Face](Martian_Face.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 248 |  | [Suspicio](Suspicio.md) |  | [Polus Replica](Polus_Replica.md) | Hp x Level |
| 249 |  | [Victor Frankenstein](Victor_Frankenstein.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 250 |  | [Sponkey](Sponkey.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 251 |  | [Steroid](Steroid.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 252 |  | [Trip Trop](Trip_Trop.md) |  | [Polus Replica](Polus_Replica.md) | N/A |
| 253 |  | [G062T](G062T.md) |  | [Polus Replica](Polus_Replica.md) | Hp x Level |
| 254 |  | [Suspicious Eyes](Suspicious_Eyes.md) | Unique Boss | [Polus Replica](Polus_Replica.md) | Appears at 25:00; Resistant to Freeze, Rosary and Debuff. Hp x Level |
| 255 |  | [Ledder](Ledder.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 256 |  | [Greeder](Greeder.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 257 |  | [Warlord](Warlord.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 258 |  | [Evil Snowman](Evil_Snowman.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 259 |  | [Alien Centipede](Alien_Centipede.md) |  | [Neo Galuga](Neo_Galuga.md) | Hp x Level, Fixed Direction |
| 260 |  | [Gulcan Tank](Gulcan_Tank.md) |  | [Neo Galuga](Neo_Galuga.md) | Resistant to Freeze and Debuff |
| 261 |  | [Metal Alien](Metal_Alien.md) |  | [Neo Galuga](Neo_Galuga.md) | Resistant to Freeze, Rosary and Debuff |
| 262 |  | [Human Faced Dog](Human_Faced_Dog.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 263 |  | [Garth](Garth.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 264 |  | [Ball Walker](Ball_Walker.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 265 |  | [Hellrider](Hellrider.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 266 |  | [Junkyard Car](Junkyard_Car.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 267 |  | [Flight Zako](Flight_Zako.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 268 |  | [M78](M78.md) |  | [Neo Galuga](Neo_Galuga.md) | Resistant to Freeze, Rosary and Debuff |
| 269 |  | [Bugger](Bugger.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 270 |  | [Poisonous Insect Gel](Poisonous_Insect_Gel.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 271 |  | [Bundle](Bundle.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 272 |  | [Zako Alien](Zako_Alien.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 273 |  | [Gigafly](Gigafly.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 274 |  | [Mutant Crawler](Mutant_Crawler.md) |  | [Neo Galuga](Neo_Galuga.md) | N/A |
| 275 |  | [Kimkoh](Kimkoh.md) |  | [Neo Galuga](Neo_Galuga.md) | Resistant to Freeze and Debuff |
| 276 |  | [Big Bot Gordea](Big_Bot_Gordea.md) | Unique Boss | [Neo Galuga](Neo_Galuga.md) | Resistant to Freeze, Rosary and Debuff Hp x Level |
| 277 |  | [Taka](Taka.md) | Unique Boss | [Neo Galuga](Neo_Galuga.md) | Resistant to Freeze, Rosary and Debuff Hp x Level |
| 278 |  | [Big Fuzz](Big_Fuzz.md) | Unique Boss | [Neo Galuga](Neo_Galuga.md) | Resistant to Freeze, Rosary and Debuff Hp x Level |
| 279 |  | [Simondo Belmont](Simondo_Belmont_(enemy).md) | Unique | [Neo Galuga](Neo_Galuga.md) | Resistant to Freeze, Rosary, Debuff and Knockback; Hp x Level |
| 280 |  | [Fleaman](Fleaman_(enemy).md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Run across the screen |
| 281 |  | [Flea Rider](Flea_Rider.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 282 |  | [Flea Armor](Flea_Armor.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 283 |  | [Spellbook](Spellbook.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 284 |  | [Frozen Shade](Frozen_Shade.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 285 |  | [Harpy](Harpy.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 286 |  | [Hippogryph](Hippogryph.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 287 |  | [Imp](Imp.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 288 |  | [Moldy Corpse](Moldy_Corpse.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 289 |  | [Spittle Bone](Spittle_Bone.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 290 |  | [Ukoback](Ukoback.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Run across the screen; Hp x Level |
| 291 |  | [Spectre](Spectre.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 292 |  | [Valhalla Knight](Valhalla_Knight.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze |
| 293 |  | [Warg](Warg.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze |
| 294 |  | [Bitterfly](Bitterfly.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 295 |  | [Bloody Painting](Bloody_Painting.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 296 |  | [OG Merman](OG_Merman.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 297 |  | [Persephone](Persephone_(enemy).md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 298 |  | [OG Ghost](OG_Ghost.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 299 |  | [Flying Zombie](Flying_Zombie.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 300 |  | [Dullahan](Dullahan.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 301 |  | [Yorick](Yorick.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 302 |  | [Amalaric Sniper](Amalaric_Sniper.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 303 |  | [Gurkha Knife Master](Gurkha_Knife_Master.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 304 |  | [Gorgon](Gorgon.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 305 |  | [Bone Golem](Bone_Golem.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze |
| 306 |  | [Disc Armor](Disc_Armor.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 307 |  | [Alastor](Alastor.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 308 |  | [Malachi](Malachi.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 309 |  | [OG Werewolf](OG_Werewolf.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 310 |  | [Axe Armor](Axe_Armor_(enemy).md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 311 |  | [Killer Doll](Killer_Doll.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 312 |  | [Corpseweed](Corpseweed.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Hp x Level |
| 313 |  | [Bone Ark](Bone_Ark.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 314 |  | [Bone Pillar](Bone_Pillar.md) |  | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | N/A |
| 315 |  | [Jiang Shi](Jiang_Shi.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [Refectio](Refectio.md) |
| 316 |  | [Keremet](Keremet_(enemy).md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [Keremet Bubbles](Keremet_Bubbles.md) |
| 317 |  | [Zephyr](Zephyr_(enemy).md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [Gale Force](Gale_Force.md) |
| 318 |  | [Gaibon](Gaibon.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level |
| 319 |  | [Slogra](Slogra.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level |
| 320 |  | [Behemoth](Behemoth.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [Rock Riot](Rock_Riot.md) |
| 321 |  | [Treant](Treant.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [Wood Carving Score](Wood_Carving_Score.md) |
| 322 |  | [Abbadon](Abbadon.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [King\'s Gate](King's_Gate.md) |
| 323 |  | [Menace](Menace.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level |
| 324 |  | [Eligor](Eligor.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [Beast Gate](Beast_Gate.md) |
| 325 |  | [Gergoth](Gergoth.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level |
| 326 |  | [Giant Medusa Head](Giant_Medusa_Head.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level |
| 327 |  | [Puppet Master](Puppet_Master.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [Scorpion Gate](Scorpion_Gate.md) |
| 328 |  | [Blackmore](Blackmore_(enemy).md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level |
| 329 |  | [Paranoia](Paranoia.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level; Drops  [Capra Gate](Capra_Gate.md) |
| 330 |  | [Death](Death_(boss).md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff |
| 331 | Mimic the character\'s appearance | [Doppelganger](Doppelganger.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Freeze, Rosary and Debuff; Hp x Level |
| 332 |  | [The Creature](The_Creature.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Rosary; Hp x Level; Drops  [Fulgur](Fulgur.md) |
| 333 |  | [Bugbear](Bugbear.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Hp x Level |
| 334 |  | [Devil](Devil.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Hp x Level |
| 335 |  | [OG Minotaur](OG_Minotaur.md) | Unique Boss | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Resistant to Rosary; Hp x Level |
| 336 |  | [Calamity](Calamity.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) | Floaty, Fixed Direction |
| 337 |  | [Divine Wood Spirit](Divine_Wood_Spirit.md) | Unique Boss | [Emerald Diorama](Emerald_Diorama_(stage).md) | Drops  [Pummarola](Pummarola.md) |
| 338 |  | [Boar Infantry](Boar_Infantry.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 339 |  | [Earth Dragon](Earth_Dragon.md) | Unique Boss | [Emerald Diorama](Emerald_Diorama_(stage).md) | Drops  [Glaive](Glaive.md) |
| 340 |  | [Forest Hermit](Forest_Hermit.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 341 |  | [Maggot Ball](Maggot_Ball.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 342 |  | [Skydiver](Skydiver.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 343 |  | [Psychic Ogre](Psychic_Ogre.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 344 |  | [Decobat](Decobat.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 345 |  | [Failinis](Failinis.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 346 |  | [Rana Combatant](Rana_Combatant.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 347 |  | [Kelpie](Kelpie.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 348 |  | [Rascal](Rascal.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 349 |  | [Golden Baum](Golden_Baum.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 350 |  | [Alraune](Alraune.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 351 |  | [Anti-Ant](Anti-Ant.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 352 |  | [Moch](Moch.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 353 |  | [Skeleton from Beyond](Skeleton_from_Beyond.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 354 |  | [Werewolf from Beyond](Werewolf_from_Beyond.md) |  | [Emerald Diorama](Emerald_Diorama_(stage).md) |  |
| 355 |  | [Specter of Iwanaga-hime](Specter_of_Iwanaga-hime.md) | Unique Boss | [Emerald Diorama](Emerald_Diorama_(stage).md) | Drops  [Bullova](Bullova.md) |
| 356 |  | [Iron Maiden](Iron_Maiden.md) | Unique Boss | [Emerald Diorama](Emerald_Diorama_(stage).md) | Drops  [Khukuri](Khukuri.md) |
| 357 |  | [Malevolent Door Spirit](Malevolent_Door_Spirit_(enemy).md) | Unique Boss | [Emerald Diorama](Emerald_Diorama_(stage).md) | Drops  [Flamberge](Flamberge.md) |
| 358 |  | [Living Anguish](Living_Anguish.md) | Unique Boss | [Emerald Diorama](Emerald_Diorama_(stage).md) | Drops  [Skull O\'Maniac](Skull_O'Maniac.md) |
| 359 |  | [Jimbats](Jimbats.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 360 |  | [Zombalatro](Zombalatro.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 361 |  | [Mr Bones](Mr_Bones.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 362 |  | [Spectral Joker](Spectral_Joker.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 363 |  | [Playing Mantis](Playing_Mantis.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 364 |  | [Flower Pot](Flower_Pot.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 365 |  | [Blue Venus](Blue_Venus.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 366 |  | [Moonlover](Moonlover.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 367 |  | [Small Blind](Small_Blind.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 368 |  | [Big Blind](Big_Blind.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 369 |  | [The Ox](The_Ox.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 370 |  | [The Wall](The_Wall.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 371 |  | [The Manacle](The_Manacle.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| 372 |  | [Crimson Heart](Crimson_Heart.md) |  | [Ante Chamber](Ante_Chamber_(stage).md) |  |
| N/A |  «» | [Fallen Angel](Fallen_Angel.md) |  | [Cappella Magna](Cappella_Magna.md) | Changes appearance in «Maddener\'s presence». |
| N/A |  «» | [Elite Fallen Angel](Elite_Fallen_Angel.md) |  | [Cappella Magna](Cappella_Magna.md) | Changes appearance in «Maddener\'s presence». |
| N/A |  «» | [Fallen Archangel](Fallen_Archangel.md) |  | [Cappella Magna](Cappella_Magna.md) | Changes appearance in «Maddener\'s presence». |
| N/A |  «» | [Bell Angel](Bell_Angel.md) |  | [Holy Forbidden](Holy_Forbidden.md) | Changes appearance in «Maddener\'s presence». |
| N/A |  | [Big Molisano](Molisano_Grosso.md) |  | [Il Molise](Il_Molise.md) | Cannot move. |
| N/A |  | [Molisano Anfora](Molisano_Anfora.md) |  | [Il Molise](Il_Molise.md) | Cannot move. Drops [coins](Gold_Coin_(pickup).md) instead of [Experience Gems](Experience_Gem.md). |
| N/A |  | [Swordian](Swordian.md) |  | [Tiny Bridge](Tiny_Bridge.md) | N/A |
| N/A |  | [Bridge Minion](Bridge_Minion.md) |  | [Tiny Bridge](Tiny_Bridge.md) | N/A |

### Boss {#Boss}

|  |  |  |  |  |
|----|----|----|----|----|
| \# | Sprite | Name^[\[n\ 1\]](#cite_note-enemy-names-1)^ | Stages | Notes |
| 012 |  | [Giant Werewolf](Giant_Werewolf.md), [Colossal Werewolf](Werewolf.md#Werewolf_(boss_2)) | [Mad Forest](Mad_Forest.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 034 |  | [Giant Bat](Giant_Bat.md), [Colossal Bat](Giant_Bat.md#Giant_Bat_(boss)) | [Mad Forest](Mad_Forest.md), [Boss Rash](Boss_Rash.md) | Resistant to freeze. Some variant has HP x Level. |
| 035 |  | [Mantichana](Mantichana.md), [Giant Mantichana](Mantichana.md#Mantichana_(boss)) | [Mad Forest](Mad_Forest.md), [Boss Rash](Boss_Rash.md) | Resistant to freeze. Some variant has HP x Level. |
| 036 |  | [Big Mummy](Big_Mummy.md), [Giant Mummy](Giant_Mummy.md) | [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | Resistant to freeze. Some variant has HP x Level. |
| 037 |  | [Venus](Venus.md), [Giant Blue Venus](Giant_Blue_Venus.md) | [Mad Forest](Mad_Forest.md), [Boss Rash](Boss_Rash.md) | Defeating Giant Blue Venus unlocks Hyper Mode for [Mad Forest](Mad_Forest.md).  Resistant to freeze. Some variant has HP x Level. |
| 024 |  | [Colossal Musc Musc](Colossal_Musc_Musc.md) | [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 014 |  | [Colossal Lionhead](Colossal_Lionhead.md) | [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 022 |  | [Colossal Sneaky Head](Colossal_Sneaky_Head.md) | [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 013 |  | [Colossal Dust Elemental](Colossal_Dust_Elemental.md) | [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 033 |  | [Queen Merdusa](Queen_Medusa.md) | [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | HP x Level, resistant to freeze. |
| 030 |  | [Master Witch](Master_Witch.md) | [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | HP x Level, resistant to freeze. |
| 020 |  | [Nesufritto](Nesufritto.md) | [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | HP x Level, resistant to freeze. |
| 019 |  | [Hag](Hag.md) | [Inlaid Library](Inlaid_Library.md), [Boss Rash](Boss_Rash.md) | Defeating unlocks the hyper mode for [Inlaid Library](Inlaid_Library.md).;  HP x Level, resistant to freeze, knockback, instant kill, and debuffs. Ignores collision. |
| 041 |  | [Lizard Rook](Lizard_Rook.md) | [Dairy Plant](Dairy_Plant.md) | N/A |
| 047 |  | [Minotaur Champion](Minotaur_Champion.md) | [Dairy Plant](Dairy_Plant.md) | HP x Level |
| 038 |  | [Merman Boss](Merman_Boss.md) | [Dairy Plant](Dairy_Plant.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 045 |  | [Colossal Lost Twin](Giant_Goat-Horned_Shooter.md) | [Dairy Plant](Dairy_Plant.md), [Boss Rash](Boss_Rash.md) | [Arcana](Arcana.md) holder; only spawns if Arcanas are enabled in Boss Rash.;  HP x Level, cannot move. |
| 052 |  | [King Tritont](King_Triton.md) | [Dairy Plant](Dairy_Plant.md), [Boss Rash](Boss_Rash.md) | HP x Level, resistant to freeze, instant kill, and debuffs. |
| 050 |  | [Axe Guardian](Axe_Guardian.md) | [Dairy Plant](Dairy_Plant.md), [Cappella Magna](Cappella_Magna.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 055 |  | [Big Golem](Big_Golem.md) | [Dairy Plant](Dairy_Plant.md), [Boss Rash](Boss_Rash.md) | HP x Level, resistant to freeze. |
| 047 |  | [Minotaur Boss](Minotaur_Boss.md) | [Dairy Plant](Dairy_Plant.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 057 |  | [Sword Guardian](Sword_Guardian.md) | [Dairy Plant](Dairy_Plant.md), [Boss Rash](Boss_Rash.md) | Defating unlocks hyper mode for [Dairy Plant](Dairy_Plant.md).;  Some version has HP x Level, resistant to freeze, instant kill, and debuffs. |
| 054 |  | [Colossal Gallotrice](Colossal_Gallotrice.md) | [Dairy Plant](Dairy_Plant.md), [Gallo Tower](Gallo_Tower.md), [Boss Rash](Boss_Rash.md) | HP x Level, resistant to freeze, instant kill, and debuffs. |
| 005 |  | [Scarleton](Scarleton.md) | [Gallo Tower](Gallo_Tower.md) | Has three lives. |
| N/A |  | [Elite Devil](Elite_Devil.md) | [Gallo Tower](Gallo_Tower.md) | HP x Level |
| 028 |  | [Undead Mage](Undead_Mage.md) | [Gallo Tower](Gallo_Tower.md) | Shoots bullets at 2 second intervals. |
| 089 |  | [Giant Skullone](Giant_Skull.md) | [Gallo Tower](Gallo_Tower.md), [The Bone Zone](The_Bone_Zone.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 023 |  | [Colossal Harzia](Colossal_Harpy.md) | [Gallo Tower](Gallo_Tower.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 016 |  | [Colossal Bone Dragon](Colossal_Bone_Dragon.md) | [Gallo Tower](Gallo_Tower.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 016 |  | [Colossal Flame Dragon](Colossal_Flame_Dragon.md) | [Gallo Tower](Gallo_Tower.md), [Boss Rash](Boss_Rash.md) | HP x Level, [Treasure Chest](Treasure_Chest.md) dropped by this enemy can evolve up to 3 weapons. |
| N/A |  | [Gallo](Gallo_(enemy).md) | [Gallo Tower](Gallo_Tower.md) | HP x Level, resistant to freeze, instant kill, and debuffs. Ignores collision. |
| 032 |  | [Shield Guardian](Shield_Guardian.md) | [Gallo Tower](Gallo_Tower.md), [Boss Rash](Boss_Rash.md) | HP x Level, resistant to freeze. |
| N/A |  | [Colossal Panther](Colossal_Panther.md) | [Gallo Tower](Gallo_Tower.md), [Boss Rash](Boss_Rash.md) | HP x Level |
| 058 |  | [Giant Enemy Crab](Giant_Enemy_Crab.md) | [Gallo Tower](Gallo_Tower.md), [Boss Rash](Boss_Rash.md) | Defeating unlocks hyper mode for [Gallo Tower](Gallo_Tower.md). [Treasure Chests](Treasure_Chest.md) dropped by this enemy can evolve up to 5 weapons.;  HP x Level, resistant to freeze, instant kill, and debuffs. Can regenerate its pincers and summon [Drowner](Drowner.md). |
| 053 |  | [Colossal Manticore](Colossal_Manticore.md) | [Gallo Tower](Gallo_Tower.md), [Boss Rash](Boss_Rash.md) | HP x Level, resistant to freeze, instant kill, and debuffs. |
| N/A | «» | [Fallen Archangel](Fallen_Archangel.md) | [Cappella Magna](Cappella_Magna.md) | Changes appearance in «Maddener\'s presence». |
| 104 |  | [Colossal Unknown](Colossal_Eyeball.md) | [Cappella Magna](Cappella_Magna.md), [Boss Rash](Boss_Rash.md) | HPxLevel, resistant to knockback. |
| N/A | «» | [Colossal Fallen Archangel](Colossal_Fallen_Archangel.md) | [Cappella Magna](Cappella_Magna.md) | Changes appearance in «Maddener\'s presence».;  HPxLevel |
| 108 |  | [Colossal Succubus](Succubus_(enemy).md) | [Cappella Magna](Cappella_Magna.md), [Boss Rash](Boss_Rash.md) | HPxLevel |
| 109 |  | [Colossal Archon Rame](Colossal_Green_Knight.md) | [Cappella Magna](Cappella_Magna.md), [Boss Rash](Boss_Rash.md), [Tiny Bridge](Tiny_Bridge.md) | HPxLevel |
| 116 |  | [Colossal Archdemon](Colossal_Archdemon.md) | [Cappella Magna](Cappella_Magna.md), [Boss Rash](Boss_Rash.md) | HPxLevel |
| 117 |  | [Trinacria](Trinacria.md) | [Cappella Magna](Cappella_Magna.md), [Boss Rash](Boss_Rash.md) | Defeating unlocks [hyper mode](Hyper_mode.md) for [Cappella Magna](Cappella_Magna.md);  HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. |
| 125 |  | [The Ender](The_Ender.md) | [Cappella Magna](Cappella_Magna.md), [Boss Rash](Boss_Rash.md) | The Ender fires small scythes projectiles and creates beams of Reaper Trainees, [coffins](Coffin.md), fire explosions, and sprite work of the base weapons. It also has a shield that temporarily absorbs damage.;  HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. |
| 063 |  | [Dead Molisano](Dead_Molisano.md) | [Il Molise](Il_Molise.md) | [Arcana](Arcana.md) holder; only spawns if Arcanas are enabled.;  Cannot move. |
| 103 |  | [Non-Giant Enemy Crab](Non-Giant_Enemy_Crab.md) | [Moongolow](Moongolow.md), [Boss Rash](Boss_Rash.md) | HPxLevel |
| 100 |  | [Colossal Garlic](Colossal_Moon_Garlic.md) | [Moongolow](Moongolow.md), [Boss Rash](Boss_Rash.md) | Resistant to knockback. |
| 101 |  | [Colossal Nightshade](Colossal_Moon_Nightshade.md) | [Moongolow](Moongolow.md), [Boss Rash](Boss_Rash.md) | Resistant to knockback. |
| 104 |  | [Unknown](Unknown.md) | [Moongolow](Moongolow.md), [Boss Rash](Boss_Rash.md) | Appears only during [lunar eclipse](Moongolow.md#lunar_eclipse).;  HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. Ignores collision. |
| 117 |  | [Moon Trinacria](Moon_Trinacria.md) | [Moongolow](Moongolow.md) | Appears only during [lunar eclipse](Moongolow.md#lunar_eclipse).;  HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. |
| 098 |  | [Moongolow Atlanteans](Moongolow_Atlanteans.md) | [Moongolow](Moongolow.md) | Drops a [Golden Egg](Golden_Egg.md) upon death.;  Resistant to knockback, freeze, instant kill, and debuffs. |
| N/A |  | [Glowing Skeleton](Glowing_Skeleton.md) | [The Bone Zone](The_Bone_Zone.md) | HPxLevel |
| 091 |  | [Colossal Skeleton](Colossal_Skeleton.md) | [The Bone Zone](The_Bone_Zone.md), [Boss Rash](Boss_Rash.md) | HPxLevel, resistant to freeze. |
| 031 |  | [Red Knight Guardian](Red_Knight_Guardian.md) | [Boss Rash](Boss_Rash.md) | HPxLevel, resistant to freeze. |
| 105 | ; | [Elite Reaper Trainee](Elite_Reaper_Trainee.md) | [Boss Rash](Boss_Rash.md) | [Arcana](Arcana.md) holder; only spawns if Arcanas are enabled.;  HPxLevel, resistant to knockback and freeze. |
| 119 |  [The Reaper](The_Reaper.md) | [The Reaper](The_Reaper.md) | [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), [Dairy Plant](Dairy_Plant.md), [Gallo Tower](Gallo_Tower.md), [Cappella Magna](Cappella_Magna.md), [Il Molise](Il_Molise.md), [Moongolow](Moongolow.md), [Green Acres](Green_Acres.md), [The Bone Zone](The_Bone_Zone.md), [Boss Rash](Boss_Rash.md) | Appears at the time limit of each stage, spawning every minute thereafter.;  HP x Level, resistant to freeze, instant kill, and debuffs. Negates knockback. |
| 120 |  | [The Trickster](The_Trickster.md) | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 121 |  | [The Stalker](The_Stalker.md) | [Boss Rash](Boss_Rash.md) | Can drop a [Treasure Chest](Treasure_Chest.md) when defeated.;  HP x Level, resistant to knockback, freeze, and debuffs. |
| 122 |  | [The Drowner](The_Drowner.md) | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 123 |  | [The Maddener](The_Maddener.md) | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 126 | ; | [Mimic Season One](Mimic_Season_One.md) | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 127 | ; | [Mimic Season Two](Mimic_Season_Two.md) | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 128 | ; | [Mimic Season Three](Mimic_Season_Three.md) | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 129 |  | [Tri-Anchors](Tri-Anchors.md) | [Boss Rash](Boss_Rash.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| N/A |  | [Swordian](Swordian.md) | [Tiny Bridge](Tiny_Bridge.md) | [Arcana](Arcana.md) holder; only spawns if Arcanas are enabled.;  HP x Level, fixed direction, floaty. |
| 161 |  | [Spiritello Boss](Spiritello_Boss.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level |
| 165 |  | [Mikoshi-nyudo](Mikoshi-nyudo.md) | [Mt.Moonspell](Mt.Moonspell.md) | N/A |
| 166 |  | [Kamaitachi Boss](Kamaitachi_Boss.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to knockback. |
| 167 |  | [Raiju Boss](Raiju_Boss.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to knockback. |
| 169 |  | [Tanuki Boss](Tanuki_Boss.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to knockback. |
| 170 |  | [Tengu Boss](Tengu_Boss.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to knockback. |
| 171 |  | [Tsuchigumo](Tsuchigumo.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to knockback. |
| 172 |  | [Windy Oni](Windy_Oni.md) | [Mt.Moonspell](Mt.Moonspell.md) | Resistant to knockback. |
| 173 |  | [Thunderous Oni](Thunderous_Oni.md) | [Mt.Moonspell](Mt.Moonspell.md) | Resistant to knockback. |
| 176 |  | [Orochimario](Orochimario.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to knockback, freeze, instant kill, and debuffs. |
| 054 | [A sprite icon representing Foscaritrice linking to Foscaritrice](/w/Special:Upload?wpDestFile=Sprite-Foscaritrice.png "File:Sprite-Foscaritrice.png") | [Foscaritrice](Foscaritrice.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback. |
| 054 | [A sprite icon representing Foscaritrice-3 linking to Colossal Foscaritrice](/w/Special:Upload?wpDestFile=Sprite-Foscaritrice-3.png "File:Sprite-Foscaritrice-3.png") | [Colossal Foscaritrice](Colossal_Foscaritrice.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback. |
| 054 | [A sprite icon representing Foscaritrice-4 linking to Arcana Foscaritrice](/w/Special:Upload?wpDestFile=Sprite-Foscaritrice-4.png "File:Sprite-Foscaritrice-4.png") | [Arcana Foscaritrice](Arcana_Foscaritrice.md) | [Lake Foscari](Lake_Foscari.md) | [Arcana](Arcana.md) holder; only spawns if Arcanas are enabled.;  HP x Level, resistant to knockback. |
| 180 |  | [Nutmeg Boss](Nutmeg_Boss.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level. |
| 181 |  | [Vulvio Boss](Vulvio_Boss.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback. |
| 182 |  | [Lammuga Boss](Lammuga_Boss.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback. |
| 185 |  | [Sam the Boss Clown](Sam_the_Boss_Clown.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback. |
| 193 |  | [Njuggles Boss](Njuggles_Boss.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback. |
| 204 |  | [Missing Church Boss](Missing_Church_Boss.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback. |
| 188 |  | [Deep Green Knight](Deep_Green_Knight.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback. |
| 197 |  | [Avatar of Gaea](Avatar_of_Gaea.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback, freeze, and debuffs. |
| 188 |  | [Big Green Knight](Big_Green_Knight.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level, resistant to knockback and freeze. |
| 199 |  | [Colossal Redusa Head](Colossal_Redusa_Head.md) | [Abyss Foscari](Abyss_Foscari.md) | [Arcana](Arcana.md) holder; some only spawns if Arcanas are enabled.;  HP x Level, resistant to knockback. |
| 202 |  | [Rotting Ghoul](Rotting_Ghoul.md) | [Abyss Foscari](Abyss_Foscari.md) | Resistant to knockback. |
| 203 |  | [Flaming Skull](Flaming_Skull.md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback. |
| 207 |  | [Colossal Meatball](Colossal_Meatball.md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback and freeze. |
| 209 |  | [Edna Boss](Edna_Boss.md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback. |
| 210 |  | [Warm Cauld](Warm_Cauld.md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback, freeze, instant kill, and debuffs. |
| 211 |  | [Well Well Well Dweller](Well_Well_Well_Dweller.md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback, freeze, instant kill, and debuffs. |
| 216 |  | [Maronna Meea Boss](Maronna_Meea_Boss.md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback, freeze, instant kill, and debuffs. |
| 217 |  | [Fomorian Bosses](Fomorian_Bosses.md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback and freeze. |
| 218 |  | [Je-Ne-Viv](Je-Ne-Viv_(enemy).md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback, freeze, instant kill, and debuffs. |

### Event {#Event}

|  |  |  |  |  |
|----|----|----|----|----|
| \# | Sprite | Name^[\[n\ 1\]](#cite_note-enemy-names-1)^ | Stages | Notes |
| 001 |  | [Bat Swarm](Bat_Swarm.md) | [Mad Forest](Mad_Forest.md) | Fixed direction, spawns in the Bat Swarm event |
| 006 | ; | [Skeleton Swarm](Swarm.md) | [Dairy Plant](Dairy_Plant.md) | Spawn as a generic [Swarm](Swarm.md) event. |
| 009 |  | [Flower Wall](Flower_Wall_(event).md) | [Mad Forest](Mad_Forest.md) | HP x Level |
| 011 |  | [Ghost Swarm](Ghost_Swarm.md) | [Mad Forest](Mad_Forest.md) | Fixed movement, spawns in the Ghost Swarm event. |
| 015 |  | [Milk Elemental Swarm](Swarm.md) | [Dairy Plant](Dairy_Plant.md) | Spawn as a generic [Swarm](Swarm.md) event. |
| 016 |  | [Dragon Swarm](Dragon_Swarm.md) | [Gallo Tower](Gallo_Tower.md) | HP x Level, fixed direction, ignores collision. |
| 016 |  | [Dragon Stream](Dragon_Stream.md) | [Gallo Tower](Gallo_Tower.md) | HP x Level, fixed direction, ignores collision. |
| 017 |  | [Shade Bomb](Shade_Bomb.md) | [Inlaid Library](Inlaid_Library.md) | Self-destruct attack, ignores collision. |
| 018 |  | [Poltergeist Roulette](Poltergeist_Roulette.md) | [Gallo Tower](Gallo_Tower.md) | Cannot move, ignores collision. Can be spawned by [The Trickster](The_Trickster.md) |
| 022 |  | [Medusa Wall](Medusa_Wall.md) | [Inlaid Library](Inlaid_Library.md) | Fixed direction, moves horizontally in a wavy pattern, ignores collision. |
| 022 |  | [Medusa Swarm](Medusa_Swarm.md) | [Inlaid Library](Inlaid_Library.md) | Fixed direction, spawns in the Sneaky Head Swarm event. |
| 024 |  | [Musc Musc Swarm](Musc_Musc_Swarm.md) | [Dairy Plant](Dairy_Plant.md) | There is a 1/9 chance to trigger the Musc Musc Swarm event, which summons a large amount of [Big Musc Muscs](Big_Musc_Musc.md), upon stepping on trap. |
| 024 |  | [Impefinger Swarm](Impefinger_Swarm.md) | [Gallo Tower](Gallo_Tower.md) | There is a 1/7 chance to trigger the Impefinger Swarm event, upon stepping on a trap. |
| 028 040 042 045 | ; | [Pile Assault](Pile_Assault.md) | [Dairy Plant](Dairy_Plant.md), [Gallo Tower](Gallo_Tower.md), [Abyss Foscari](Abyss_Foscari.md) | Spawn a lot of bullet shooting enemies around that appear in the stage. |
| 035 |  | [Foscari Mantichana Circle](Circle.md) | [Lake Foscari](Lake_Foscari.md) | Spawn as a generic [Circle](Circle.md) event. |
| 043 |  | [Jellyfish Wall](Jellyfish_Wall.md) | [Dairy Plant](Dairy_Plant.md) | Fixed movement, ignores collision |
| 043 |  | [Jellyfish Swarm](Jellyfish_Swarm.md) | [Dairy Plant](Dairy_Plant.md) | Fixed direction |
| 048 |  | [Minotaur Rush](Minotaur_Rush.md) | [Dairy Plant](Dairy_Plant.md) | Appears in the Minotaur Rush event. Fixed direction. |
| 088 |  | [Skull Pile Pile](Skull_Pile_Pile.md) | [The Bone Zone](The_Bone_Zone.md) | Spawns a pair of columns of 12 [Twin Skulls](Twin_Skulls.md) on both sides of the player. |
| 089 |  | [Skull Swarm](Skull_Swarm.md) | [Inlaid Library](Inlaid_Library.md), [The Bone Zone](The_Bone_Zone.md), [Lake Foscari](Lake_Foscari.md) | Fixed direction, ignores collision. |
| 104 |  | [Eyespin](Eyespin.md) | [Moongolow](Moongolow.md), [Holy Forbidden](Holy_Forbidden.md) | Appears only during [lunar eclipse](Moongolow.md#lunar_eclipse) in Moongolow.;  HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. Ignores collision. Circles the player at set distance. |
| 117 |  | [Trinacria X](Trinacria_X.md) | [Holy Forbidden](Holy_Forbidden.md) | HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. |
| 120 |  | [The Trickster](The_Trickster.md) | [Cappella Magna](Cappella_Magna.md) | Summons [Poltergeist Gems](Poltergeist.md#Poltergeist_Gem) around the player that [self-destruct](Self-destruct.md) when approached. Trickster can also chase and attack the player directly.;  HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. |
| 121 |  | [The Stalker](The_Stalker.md) | [Dairy Plant](Dairy_Plant.md), [The Bone Zone](The_Bone_Zone.md), [Cappella Magna](Cappella_Magna.md) | Can drop a [Treasure Chest](Treasure_Chest.md) when defeated.;  HP x Level, resistant to knockback, freeze, and debuffs. |
| 122 |  | [The Drowner](The_Drowner.md) | [Gallo Tower](Gallo_Tower.md), [The Bone Zone](The_Bone_Zone.md), [Cappella Magna](Cappella_Magna.md) | Appears at the time limit of Gallo Tower or when summoned by [Giant Enemy Crab](Giant_Enemy_Crab.md). Can drop a chest when defeated.;  HP x Level, resistant to knockback, freeze, and debuffs. Cannot be defeated using [Pentagram](Pentagram.md), or when it spawns at the time limit. |
| 123 |  | [The Maddener](The_Maddener.md) | [Cappella Magna](Cappella_Magna.md), [Holy Forbidden](Holy_Forbidden.md) | Changes the appearance of some enemies. Has a unique attack sequence in [Holy Forbidden](Holy_Forbidden.md). Spawns weakened in [Cappella Magna](Cappella_Magna.md). ; HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. |
| 161 |  | [Spiritello Swarm](Swarm.md) | [Mt.Moonspell](Mt.Moonspell.md) | Spawn as a generic [Swarm](Swarm.md) event. |
| 179 |  | [Wiseparke Swarm](Medusa_Swarm.md) | [Lake Foscari](Lake_Foscari.md) | Spawn as a [Medusa Swarm](Medusa_Swarm.md) event. |
| 185 |  | [Sam Swarm](Swarm.md) | [Lake Foscari](Lake_Foscari.md) | Spawn as a generic [Swarm](Swarm.md) event. |
| 186 |  | [Sammy Swarm](Medusa_Swarm.md) | [Lake Foscari](Lake_Foscari.md) | Spawn as a [Medusa Swarm](Medusa_Swarm.md) event. |
| 200 | [A sprite icon representing Jellyfish linking to Jellyfish Wall](/w/Special:Upload?wpDestFile=Sprite-Jellyfish.png "File:Sprite-Jellyfish.png") | [Rellyfish Wall](Jellyfish_Wall.md) | [Abyss Foscari](Abyss_Foscari.md) | Spawn as a [Jellyfish Wall](Jellyfish_Wall.md) event. |
| 201 |  | [Blood Moss Swarm](Swarm.md) | [Abyss Foscari](Abyss_Foscari.md) | Spawn as a generic [Swarm](Swarm.md) event. |
| 124 |  | [The Blinder](The_Blinder.md) | [Abyss Foscari](Abyss_Foscari.md) | Can drop a [Treasure Chest](Treasure_Chest.md) when defeated.;  HP x Level, resistant to knockback, freeze, and debuffs. |
| 202 |  | [Rotting Ghoul Swarm](Swarm.md) | [Abyss Foscari](Abyss_Foscari.md) | Spawn as a generic [Swarm](Swarm.md) event. |
| 203 |  | [Burning Skull Swarm](Swarm.md) | [Abyss Foscari](Abyss_Foscari.md) | Spawn as a generic [Swarm](Swarm.md) event. |
| 205 |  | [Snek Swarm](Skull_Swarm.md) | [Lake Foscari](Lake_Foscari.md) | Spawn as a [Skull Swarm](Skull_Swarm.md) event. |
| 205 |  | [Snek Swarm](Swarm.md) | [Abyss Foscari](Abyss_Foscari.md) | Spawn as a generic [Swarm](Swarm.md) event. |
| N/A |  | [Shooting Star](Shooting_Star.md) | [Gallo Tower](Gallo_Tower.md), [Holy Forbidden](Holy_Forbidden.md) | N/A |
| N/A |  | [Moon Anfora](Moon_Anfora.md) | [Moongolow](Moongolow.md) | Drops a [Gold Coin](Gold_Coin_(pickup).md) instead of [XP](XP.md) upon death.;  Cannot move. |
| N/A | «» | [Bell Angel Striker](Bell_Angel_Striker.md) | [Holy Forbidden](Holy_Forbidden.md) | Changes appearance in «Maddener\'s presence».;  Fixed direction, ignores collision. |
| N/A | «» | [Bell Angel Bomber](Bell_Angel_Bomber.md) | [Holy Forbidden](Holy_Forbidden.md) | Changes appearance in «Maddener\'s presence».;  Self-destruct attack, ignores collision. |
| N/A |  | [Serpentine Skeleton Dragon](Serpentine_Skeleton_Dragon.md) | [The Bone Zone](The_Bone_Zone.md) | HP x Level, fixed direction, ignores collision. |
| N/A |  | [Monster Rain](Monster_Rain.md) | [Tiny Bridge](Tiny_Bridge.md) |  |
| N/A |  | [Foscari Pot Circle](Circle.md) | [Lake Foscari](Lake_Foscari.md) | Spawn as a generic [Circle](Circle.md) event. |

### Special {#Special}

|  |  |  |  |  |
|----|----|----|----|----|
| \# | Sprite | Name^[\[n\ 1\]](#cite_note-enemy-names-1)^ | Stages | Notes |
| 094; 095 096 097 | [A sprite icon representing Moongolow Atlanteans-3 linking to Moongolow_Atlanteans#Moongolow_Atlanteans](/w/Special:Upload?wpDestFile=Sprite-Moongolow_Atlanteans-3.png "File:Sprite-Moongolow Atlanteans-3.png"); [A sprite icon representing Moongolow Atlanteans-1 linking to Moongolow_Atlanteans#Moongolow_Atlanteans](/w/Special:Upload?wpDestFile=Sprite-Moongolow_Atlanteans-1.png "File:Sprite-Moongolow Atlanteans-1.png")[A sprite icon representing Moongolow Atlanteans-2 linking to Moongolow_Atlanteans#Moongolow_Atlanteans](/w/Special:Upload?wpDestFile=Sprite-Moongolow_Atlanteans-2.png "File:Sprite-Moongolow Atlanteans-2.png") [A sprite icon representing Moongolow Atlanteans-4 linking to Moongolow_Atlanteans#Moongolow_Atlanteans](/w/Special:Upload?wpDestFile=Sprite-Moongolow_Atlanteans-4.png "File:Sprite-Moongolow Atlanteans-4.png")[A sprite icon representing Moongolow Atlanteans-5 linking to Moongolow_Atlanteans#Moongolow_Atlanteans](/w/Special:Upload?wpDestFile=Sprite-Moongolow_Atlanteans-5.png "File:Sprite-Moongolow Atlanteans-5.png") | [Sun Atlantean](Sun_Atlantean.md) [Moon Atlantean](Moon_Atlantean.md) [City Atlantean](City_Atlantean.md) [Volcano Atlantean](Volcano_Atlantean.md) | [Mad Forest](Mad_Forest.md), [Inlaid Library](Inlaid_Library.md), [Dairy Plant](Dairy_Plant.md), [Gallo Tower](Gallo_Tower.md), [Cappella Magna](Cappella_Magna.md), [Il Molise](Il_Molise.md), [Moongolow](Moongolow.md), [Green Acres](Green_Acres.md), [The Bone Zone](The_Bone_Zone.md), [Boss Rash](Boss_Rash.md), [Mt.Moonspell](Mt.Moonspell.md) , [Lake Foscari](Lake_Foscari.md) , [Abyss Foscari](Abyss_Foscari.md) | Spawns when player gets near a hidden [stage item](Stage_item.md) that was unlocked by [Yellow Sign](Yellow_Sign.md). Drops [Golden Egg](Golden_Egg.md) instead of XP upon death.;  Resistant to knockback, freeze, instant kill, and debuffs. |
| 120 |  | [The Trickster](The_Trickster.md) | [Inverse](Inverse.md) [Inlaid Library](Inlaid_Library.md) | Spawns naturally by a piano due east when playing on inverse mode.;  HPxLevel, resistant to knockback, freeze, instant kill, and debuffs. |
| 122 |  | [The Drowner](The_Drowner.md) | [Gallo Tower](Gallo_Tower.md) | Summoned by Giant Enemy Crab when the player is under it for a while.;  Resistant to knockback, freeze, instant kill, debuffs. |
| 130 |  | [LV128 Golden Bat](LV128_Golden_Bat.md) | [Green Acres](Green_Acres.md) | Spawns after teleporting into an unknown area whentravelling to the southwest of Green Acres.;  Resistant to knockback, freeze, instant kill, debuffs. |
| 131 |  | [The Directer](The_Directer.md) | [Eudaimonia Machine](Eudaimonia_Machine.md) |  |
| 162 |  | [Hitotsume-kozo](Hitotsume-kozo.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level |
| 163 |  | [Kappa](Kappa.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level |
| 169 |  | [Tanuki](Tanuki.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level |
| 174 |  | [Big Oni](Big_Oni.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to knockback. |
| 009 |  | [Moonspell Flower Wall 2](Moonspell_Flower_Wall_2.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to knockback. |
| 175 |  | [Goshadokuro](Goshadokuro.md) | [Mt.Moonspell](Mt.Moonspell.md) | HP x Level, resistant to instant kill. |
| 193 |  | [Scaling Fish-tailed Njuggles](Scaling_Fish-tailed_Njuggles.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level |
| 195 |  | [Fungoman](Fungoman.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level |
| N/A |  | [Foscari Crate](Foscari_Crate.md) | [Lake Foscari](Lake_Foscari.md) | HP x Level |
| 009 |  | [Foscari Flower Wall](Foscari_Flower_Wall.md) | [Lake Foscari](Lake_Foscari.md) | N/A |
| N/A |  | [Abyss Anfora](Abyss_Anfora.md) | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 191 |  | [Hand of Glory](Hand_of_Glory.md) | [Abyss Foscari](Abyss_Foscari.md) | N/A |
| 218 |  | [Je-Ne-Viv](Je-Ne-Viv_(enemy).md) | [Abyss Foscari](Abyss_Foscari.md) | HP x Level, resistant to knockback, freeze, instant kill, and debuffs. |
| N/A |  | [Beelzebub](Beelzebub.md) | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Drops  [Pile of Secrets](Pile_of_Secrets.md) |
| N/A |  | [Legion](Legion.md) | [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | Drops  [Ebony and Crimson Stones](Ebony_and_Crimson_Stones.md) |
| N/A |  | [Leda](Leda_(enemy).md) | [Gallo Tower](Gallo_Tower.md) | Naturally spawns at the very bottom of Gallo Tower.;  Resistant to knockback, freeze, instant kill, debuffs. |
| N/A |  | [Boon Marrabio](Boon_Marrabbio_(enemy).md) | [Mad Forest](Mad_Forest.md) | Spawns under [certain conditions](Boon_Marrabbio.md).;  Resistant to knockback, freeze, instant kill, debuffs. |
| N/A |  | [Avatar Infernas](Avatar_Infernas_(enemy).md) | [Inverse](Inverse.md) [Inlaid Library](Inlaid_Library.md) | Spawns under [certain conditions](Avatar_Infernas.md). |
| N/A |  | [Scorej-Oni](Scorej-Oni_(enemy).md) | [Tiny Bridge](Tiny_Bridge.md) | Naturally spawns at the very east of Tiny Bridge. |

## Other Information {#Other_Information}

-  [White Hand](White_Hand.md) is not added here because it is not considered an enemy or a mob by the games code as well as not appearing in the Bestiary.

## Notes {#Notes}
