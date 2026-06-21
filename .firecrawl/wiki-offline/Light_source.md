# Light source {#firstHeading .firstHeading .mw-first-heading}

[Jump to navigation](#mw-head) [Jump to search](#searchInput)

<figure class="mw-halign-right" typeof="mw:File">

</figure>

**Light sources** are destructibles that randomly appear within [stages](Stages.md) and drop [pickups](Pickups.md) when destroyed. Light sources have 10 health.  [Luck](Luck.md) increases the spawn rate of light sources and the chance to receive rare pickups.

Destroying 20 light sources unlocks the  [Fire Wand](Fire_Wand.md).

## Types {#Types}

Light sources have a unique look depending on the stage.

|  |  |
|----|----|
| Stage | Sprite |
| [Mad Forest](Mad_Forest.md), [The Bone Zone](The_Bone_Zone.md), [Boss Rash](Boss_Rash.md), [Bat Country](Bat_Country.md), [Mt.Moonspell](Mt.Moonspell.md) |  |
| [Inlaid Library](Inlaid_Library.md), [Gallo Tower](Gallo_Tower.md), [Cappella Magna](Cappella_Magna.md), [Holy Forbidden](Holy_Forbidden.md), [Eudaimonia Machine](Eudaimonia_Machine.md) |  |
| [Dairy Plant](Dairy_Plant.md) |  |
| [Green Acres](Green_Acres.md), [Il Molise](Il_Molise.md), [Moongolow](Moongolow.md), [Tiny Bridge](Tiny_Bridge.md) |  |
| [Lake Foscari](Lake_Foscari.md) |  |
| [Abyss Foscari](Abyss_Foscari.md) |  |

## Drops {#Drops}

The following [pickups](Pickups.md) can be dropped by light sources. Some items cannot drop before the player has reached a certain level in the current run, and some pickups are not available in certain stages.  [Luck](Luck.md) increases the chances of obtaining pickups other than Gold Coin and Coin Bag.

|  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|
| Pickup | Weight | Min player level | Availability | Availability | Availability | Availability |
| Pickup | Weight | Min player level | Holy Forbidden | Eudaimonia Machine | The Bone Zone | Bat Country |
|  [Gold Coin](Gold_Coin_(pickup).md) | 50 | 0 |  |  |  |  |
|  [Coin Bag](Coin_Bag.md) | 10 | 0 |  |  |  |  |
|  [Rich Coin Bag](Rich_Coin_Bag.md) | 1 | 5 |  |  |  |  |
|  [Rosary](Rosary.md) | 1 | 8 |  |  |  |  |
|  [Nduja Fritta Tanto](Nduja_Fritta_Tanto.md) | 1 | 0 |  |  |  |  |
|  [Orologion](Orologion.md) | 2 | 4 |  |  |  |  |
|  [Vacuum](Vacuum.md) | 2 | 12 |  |  |  |  |
|  [Floor Chicken](Floor_Chicken.md) | 12 | 0 |  |  |  |  |
|  [Gilded Clover](Gilded_Clover.md) | 1 | 30 |  |  |  |  |
|  [Little Clover](Little_Clover.md) | 1 | 0 |  |  |  |  |
|  [Rerollo](Rerollo.md) | [**?** (edit)](Light_source.md) | [**?** (edit)](Light_source.md) | [**?** (edit)](Light_source.md) | [**?** (edit)](Light_source.md) | [**?** (edit)](Light_source.md) | [**?** (edit)](Light_source.md) |

## Spawn mechanics {#Spawn_mechanics}

Aside for using [Mad Groove (VIII)](Mad_Groove_(VIII).md) Arcana and [Greatest Jubilee](Greatest_Jubilee.md) weapon, Light sources spawn alongside other destructible, such as [Dairy Cart](Dairy_Cart.md) and [Stained Glass](Stained_Glass.md).

\
All destructibles spawn barely off-screen.

\
In some stages, such as [Inlaid Library](Inlaid_Library.md), [Dairy Plant](Dairy_Plant.md) and [Gallo Tower](Gallo_Tower.md), the light sources have predetermined possible spawn locations, whereas in other maps they spawn in an oval shape around the character.

The game attempts to spawn destructibles every second in all stages, except [The Bone Zone](The_Bone_Zone.md) (every 0.5 seconds) and [Holy Forbidden](Holy_Forbidden.md) (100 seconds).

Worth noting: Light sources can spawn on top of each other.

\
The chance to spawn a destructible is affected by  [Luck](Luck.md) and can be calculated as follows:

$destructibleSpawnChance = mapDestructibleChance \cdot totalLuck$

The chance (with Luck) cannot exceed the stage\'s maximum chance.

Light source spawn attempts won\'t cease once the maximum existing Light Source capacity has been reached: If a light source is spawned at the limit, a new one will spawn in a location closest to the player, while the oldest existing light source will be despawned. As long as the maximum count remains capped, the spawn chance is not influenced by Luck, consequently severely reducing chances for a new Light Source in this scenario.

The chances for each stage are listed in the following table.

|  |  |  |  |
|----|----|----|----|
| Stage | Destructible chance | Destructible chance max | Destructibles max |
| [Mad Forest](Mad_Forest.md) | 10% | 50% | 10 |
| [Inlaid Library](Inlaid_Library.md) | 7.5% | 50% | 10 |
| [Green Acres](Green_Acres.md) | 10% | 50% | 10 |
| [Dairy Plant](Dairy_Plant.md) | 20% | 60% | 10 |
| [Il Molise](Il_Molise.md) | 30% | 60% | 10 |
| [Gallo Tower](Gallo_Tower.md) | 7.5% | 50% | 10 |
| [The Bone Zone](The_Bone_Zone.md) | 40% | 40% | 10 |
| [Moongolow](Moongolow.md) | 30% | 60% | 10 |
| [Holy Forbidden](Holy_Forbidden.md) | 100% | 100% | 100 |
| [Cappella Magna](Cappella_Magna.md) | 20% | 80% | 20 |
| [Boss Rash](Boss_Rash.md) | 10% | 50% | 5 |
| [Eudaimonia Machine](Eudaimonia_Machine.md) | 7.5% | 50% | 10 |
| [Tiny Bridge](Tiny_Bridge.md) | 7.5% | 50% | 10 |
| [Mt.Moonspell](Mt.Moonspell.md) | 7.5% | 50% | 12 |
| [Bat Country](Bat_Country.md) | 1% | 50% | 10 |
| [Abyss Foscari](Abyss_Foscari.md) | 7.5% | 50% | 18 |
| [Lake Foscari](Lake_Foscari.md) | 7.5% | 50% | 12 |
| [Astral Stair](Astral_Stair.md) | 7% | 70% | 12 |
| [Whiteout](Whiteout.md) | 80% | 90% | 10 |
| [Polus Replica](Polus_Replica.md) | 7.5% | 50% | 12 |
| [Space 54](Space_54.md) | 10% | 90% | 16 |
| [Laborratory](Laborratory.md) | 20% | 60% | 12 |
| [Carlo Cart](Carlo_Cart.md) | 20% | 60% | 12 |
| [Neo Galuga](Neo_Galuga.md) | 7.5% | 50% | 12 |
| [Hectic Highway](Hectic_Highway.md) | 20% | 60% | 12 |
| [Room 1665](Room_1665.md) | 50% | 80% | 20 |
| [Ode to Castlevania](Ode_to_Castlevania_(stage).md) | 20% | 80% | 25 |
| [The Coop](The_Coop.md) | 80% | 90% | 8 |
| [Emerald Diorama](Emerald_Diorama_(stage).md) | 10% | 50% | 10 |
| [Westwoods](Westwoods.md) | 7.5% | 50% | 12 |
| [Mazerella](Mazerella.md) | 7% | 70% | 12 |
| [Ante Chamber](Ante_Chamber_(stage).md) | 10% | 50% | 10 |
| [The Lycaeum](The_Lycaeum.md) | 80% | 90% | 16 |
