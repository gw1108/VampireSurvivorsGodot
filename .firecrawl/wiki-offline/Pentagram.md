# Pentagram {#firstHeading .firstHeading .mw-first-heading}

[Jump to navigation](#mw-head) [Jump to search](#searchInput)

Pentagram

Erases everything in sight.

Erases everything in sight.

Weapon

ID

`PENTAGRAM`

Type

Normal

Evolution

 [Gorgeous Moon](Gorgeous_Moon.md)

Evolved with

 [Crown](Crown.md)

Max level

8

Rarity

60

Effects

Ignores everything but [Cooldown](Cooldown.md) and [Luck](Luck.md).

Stats

Damage

N/A

Area

N/A

Speed

N/A

Amount

N/A (w/o [Blood Astronomia (XXI)](Blood_Astronomia_(XXI).md))\
1 (with [Blood Astronomia (XXI)](Blood_Astronomia_(XXI).md))

Duration

1.0 second

Pierce

Area of Effect

Cooldown

90 seconds

Projectile Interval

0 seconds

Knockback

-2

Pool Limit

10

Chance

10%

Blocked by walls

No

Cooldown

60 seconds (-30)

Chance

65% (+55%)

{\"evolution-item\":\"Crown\",\"pool\":\"10\",\"max-chance\":\"65% (+55%)\",\"duration\":\"1.0 second\",\"amount\":\"N/A (w/o [Blood Astronomia (XXI)](Blood_Astronomia_(XXI).md))\
1 (with [Blood Astronomia (XXI)](Blood_Astronomia_(XXI).md))\",\"caption\":\"Erases everything in sight.\",\"damage\":\"N/A\",\"type\":\"Normal\",\"rarity\":\"60\",\"max-level\":\"8\",\"evolution\":\"Gorgeous Moon\",\"effects\":\"Ignores everything but [Cooldown](Cooldown.md) and [Luck](Luck.md).\",\"speed\":\"N/A\",\"chance\":\"10%\",\"id\":\"PENTAGRAM\",\"knockback\":\"-2\",\"pierce\":\"Area of Effect\",\"area\":\"N/A\",\"cooldown\":\"90 seconds\",\"max-cooldown\":\"60 seconds (-30)\"}

**Pentagram** is a [weapon](Weapons.md) in *[Vampire Survivors](Vampire_Survivors.md)*. It is the starting weapon of  [Christine Davain](Christine_Davain.md). It is unlocked by surviving for 20 minutes in a stage as any character.

Its [evolution](Evolution.md) is  [Gorgeous Moon](Gorgeous_Moon.md), which requires  [Crown](Crown.md).

## Effects {#Effects}

Pentagram summons a purple glyph with golden lining, visual details of which increase as Pentagram levels up. After summoning, the glyph shatters, instantly erasing every enemy, their drops, and all items on the screen, except for [stage items](Stage_item.md). Pentagram always deals damage equal to the max health of the enemy. If it is lower than 660, the damage number is overwritten to display it between 655 and 665.

Aside from the visibility of items, one way the player can observe if the Pentagram erased items or not, for each time it is activated, is if they have \"Damage Numbers\" enabled in the [Options](Options.md). An indication of damage numbers through enemies means the Pentagram did not erase items, while no indication of damage numbers means it erased the items.

Pentagram\'s symbol gets progressively more complex as its level increases:

- At Level 1, the golden linings are an [Eye of Ra](Eye_of_Ra.md) in the middle within a hexagram symbol having some missing lines from being two completed ones, a ring of small symbols, and three concentric rings on top of a purple circle. The inner ring is in the purple circle and close to its perimeter, and the outer ones are very similar in size, they are bigger than the purple circle. The smallest and the middle ring have a straight line connecting them at 12 points, similar to a clock.
- At Level 4, another golden ring is added and connects to the points at the hexagram, the symbols are much bigger and clearly form words instead of being evenly spaced.
- At Level 5, the hexagram is replaced with a triangle with circles at the tips, each circle has a symbol in it. The triangle is partially covering another two rings with more symbols between them, also clearly forming words.
- At Level 7, two concentric hexagons are added to encompass the inner set of rings and symbols and touch the outer set. The lines connecting the outermost two rings in the cardinal direction are replaced with two lines spreading out from the outer ring, similar to a compass with arrows pointing out.
- At Level 8, the triangle with circle tips is replaced by three concentric hexagons, which are rotated by 30 degrees from the original two. The smallest one is similar in size to the middle one. The biggest hexagon and the middle hexagon have lines connecting between the vertices. Between those two hexagons, each of the six sections has symbols, seemingly replaced and fused with the inner set of circles and symbols. The biggest hexagon\'s vertices touch the only set of circles and symbols left.

Depending on its level and the [Luck](Luck.md) stat, there is a chance for a blue symbol to appear instead, which only erases enemies and not the drops and items, similar to the effect of the [Rosary](Rosary.md). Pentagram can be affected by [Cooldown](Cooldown.md), but there is a hard-coded limit of 15 seconds on how often Pentagram can trigger.

To reach Pentagram\'s 15-second Cooldown limit, a Cooldown bonus of:

- -83.33% is required at level 1
- -81.25% is required at level 2
- -78.57% is required at level 4
- -76.92% is required at level 6
- -75% is required at level 8

Some enemies are completely unaffected by Pentagram.

Pentagram can attack and defeat the otherwise intangible [Stalkers](Stalker.md) and [Drowners](Drowner.md) in [Dairy Plant](Dairy_Plant.md), [Gallo Tower](Gallo_Tower.md), [Cappella Magna](Cappella_Magna.md), and [The Bone Zone](The_Bone_Zone.md) before minute 30. However, they do not drop chests from the blast even if it does not erase any items.

### Chance to not destroy items {#Chance_to_not_destroy_items}

Pentagram initially has a 10% chance to not destroy items, which is increased at levels 3, 5 and 7. This chance is affected by the character\'s [Luck](Luck.md).

For general purposes, the total chance to not erase items can be calculated as:

$chanceWithLuck = chance \cdot totalLuck$

In more detail, the [random number generation](Random_number_generation.md) for the Pentagram is handled via the following procedure:

1.  First, a random number x is generated from the [standard uniform distribution](Continuous_uniform_distribution.md#Standard_uniform): x \~ U\[0,1\]. This is rounded to 2 decimal places.
2.  Next, x is scaled down by the character\'s total [Luck](Luck.md) to become x/totalLuck.
3.  Lastly, the result is compared with the current Pentagram activation threshold, and triggers item destruction if x/totalLuck \> Threshold.

For example, assume a level 5 Pentagram, with x = 0.5. This leads to a threshold of 0.45.

- With +0% Luck (=100% total Luck), 0.5/1 = 0.5 is greater than 0.45, hence item destruction is triggered.
- With +60% Luck (=160% total Luck), 0.5/1.6 = 0.31 is less than 0.45, hence item destruction is not triggered.

With enough Luck, it is possible to ensure that items will not be destroyed even with the max roll of x = 1:

- At level 1, the threshold is 10%, +900% Luck is required (=1000% total Luck) as beyond 1/10 is always less than 0.1.
- At level 3, the threshold is 25%, +300% Luck is required (=400% total Luck) as beyond 1/4 is always less than 0.25.
- At level 5, the threshold is 45%, +123% Luck is required (=223% total Luck) as beyond 1/2.[2]{.underline} is always less than 0.45.
- At level 7, the threshold is 65%, +54% Luck is required (=154% total Luck) as beyond 1.[538461]{.underline} is less less than 0.65.

### Arcanas {#Arcanas}

-  [Blood Astronomia (XXI)](Blood_Astronomia_(XXI).md) - Allows Pentagram to place multiple instant kill zones on the ground.

## Levels {#Levels}

Pentagram has 8 levels. At max level, Pentagram has a +55% chance to not erase [Pickups](Pickup.md) and [Treasure Chests](Treasure_Chest.md), and has -30 seconds of [Cooldown](Cooldown.md).

|         |                                 |
|---------|---------------------------------|
| Level   | Description                     |
| Level 1 | Erases everything in sight.     |
| Level 2 | Cooldown reduced by 10 seconds. |
| Level 3 | 25% chance not to erase items.  |
| Level 4 | Cooldown reduced by 10 seconds. |
| Level 5 | 45% chance not to erase items.  |
| Level 6 | Cooldown reduced by 5 seconds.  |
| Level 7 | 65% chance not to erase items.  |
| Level 8 | Cooldown reduced by 5 seconds.  |

### Limit Break {#Limit_Break}

With [Limit Break](Limit_Break.md), Pentagram can be further leveled up.

|             |        |           |
|-------------|--------|-----------|
| Description | Rarity | Max Total |
| Chance +5%  | 10     | 100%      |

## Combos {#Combos}

*See [Combos](Weapons/Combos.md) for a list of all item interactions.*

### Stats and passive items {#Stats_and_passive_items}

|  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|----|----|
|  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |  ^[\[1\]](#cite_note-1)^ |  |  ^[\[2\]](#cite_note-2)^ |  |  |
|  |  |  |  |     ; |  |  ; |  ; |  |  ; |  |  ; |  |  |
|  |  |  |  |  |  |  |  |  |  |  |  ^[\[3\]](#cite_note-3)^ |  |  |

### Arcanas {#Arcanas_2}

|  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|
|  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |  |  |  ^[\[4\]](#cite_note-4)^ |
|  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  |  ^[\[5\]](#cite_note-5)^ |  |  |  |  |  |  |  ^[\[6\]](#cite_note-6)^ |  |

|  |  |  |  |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|----|----|----|
|  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  ^[\[7\]](#cite_note-7)^ |  |  ^[\[8\]](#cite_note-8)^ |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |  |  |  |
