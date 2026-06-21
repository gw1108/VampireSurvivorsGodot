# Level up {#firstHeading .firstHeading .mw-first-heading}

[Jump to navigation](#mw-head) [Jump to search](#searchInput)

<figure typeof="mw:File/Thumb">

<figcaption>An example of a level up bar, as shown on the top of the game HUD.</figcaption>
</figure>

<figure typeof="mw:File/Thumb">

<figcaption>An example of a level up screen. Here, the player has leveled up and is given the choice between three items: <a href="Eight_The_Sparrow.md">Eight The Sparrow</a>, the <a href="Crown.md">Crown</a>, and <a href="Flames_of_Misspell.md">Flames of Misspell</a>.<br />
<strong>Note:</strong>  <a href="Rerolls.md">Rerolls</a>,  <a href="Skips.md">Skips</a>, and/or  <a href="Banishes.md">Banishes</a> become available in this screen if the player invests in these <a href="PowerUps.md">PowerUps</a> and/or uses a character that may start with these characteristics.</figcaption>
</figure>

When the player collects enough [experience](Experience_Gem.md), they will gain a **level up**. Each successive level up requires more experience than the previous. Upon leveling up, the game is paused and the player is given 3 or 4 unique options consisting of [weapons](Weapons.md) and [passive items](Passive_items.md) to choose from. If the player chooses an item they do not have, it will be added to their inventory. If they already have the chosen item, the item will be upgraded to its next level. After selecting an item, the game resumes and the character gains a brief moment of invulnerability.

The player cannot be offered new items if the already have 6 different passive items or weapons. Similarly, if an item is at its maximum level, it also cannot be offered to the player. When both of these conditions are met and player has nothing left to upgrade, level ups will instead grant the options to gain extra [Gold](Gold_Coin_(currency).md) or restore health with [Floor Chicken](Floor_Chicken.md), with the option to always receive either Floor Chickens or Gold once the player has received 100  [Big Coin Bags](Big_Coin_Bag.md) from any source.

- The \"Always Floor Chicken\" option will only give Floor Chickens if the player has missing health. If the player is fully healed, they will receive Gold instead.

Alternatively, if a player has nothing left to upgrade, but [Limit Breaking](Limit_Break.md) is active, level ups will then offer extra levels to already maxed weapons.

If the player has invested in the [Skip](Skip.md) or [Reroll](Reroll.md) [PowerUps](PowerUps.md), they will also have the option to skip the item selection and retain some experience or shuffle the current items for a new set. Skips and Rerolls are unavailable when the player has maxed out their inventory.

Upon obtaining the  [Brave Story](Brave_Story.md), Random LevelUp is added as an option in the Stage Selection menu. When it is toggled on, each level up randomly chooses an option for the player.

## Mechanics {#Mechanics}

### Experience requirement {#Experience_requirement}

The player starts at level 1 and has to collect 5 XP to level up to level 2. Thereafter, the requirement increases by 10 XP each level until level 20 (i.e. 15 XP is required to go from level 2 to 3, 25 XP from 3 to 4 and so on). From level 21 to 40 the requirement increases by 13 XP each level, and from level 41 onwards the requirement increases by 16 XP each level.

Additionally, at levels 20 and 40 an additional amount of XP -- 600 and 2400 respectively -- is required to level up to the next level. However, at these levels the player also gains +100% [Growth](Growth.md), increasing their experience gain, until they reach the next level.

template = Template:Experience form = ExpCalc result = ExpCalcResult param = from\|From level\|1\|int\|1-\|\| param = to\|To level\|1\|int\|1-\|\| param = show_chart\|Show chart\|false\|toggleswitch\|\|\|

|  |
|----|
| Experience Calculator |
| The calculator form will appear here soon. You will need JavaScript enabled. |
| Result |
| The result will appear here when you submit the form. |

    {"type":"scatter","options":{"tooltips":{"intersect":false},"scales":{"y":{"scaleLabel":{"display":true,"labelString":"Total XP"}},"x":{"min":1,"ticks":{"stepSize":1},"max":60,"scaleLabel":{"display":true,"labelString":"Level"}}},"aspectRatio":3,"title":{"display":true,"font":{"size":18},"text":"Total experience by level","position":"top"},"maintainAspectRatio":false,"fill":false},"minWidth":"300px","resizable":true,"width":"min(30vw, 100%, 100vw - 2em)","isChartObj":true,"height":"min(10vh, 100vh - 2em)","isFinished":true,"minHeight":"300px","data":{"datasets":[{"pointRadius":0,"label":"XP","color":"rgba(200,25,0,1)","showLine":true,"data":[{"y":0,"x":1},{"y":5,"x":2},{"y":20,"x":3},{"y":45,"x":4},{"y":80,"x":5},{"y":125,"x":6},{"y":180,"x":7},{"y":245,"x":8},{"y":320,"x":9},{"y":405,"x":10},{"y":500,"x":11},{"y":605,"x":12},{"y":720,"x":13},{"y":845,"x":14},{"y":980,"x":15},{"y":1125,"x":16},{"y":1280,"x":17},{"y":1445,"x":18},{"y":1620,"x":19},{"y":1805,"x":20},{"y":2600,"x":21},{"y":2866.5,"x":22},{"y":3146,"x":23},{"y":3438.5,"x":24},{"y":3744,"x":25},{"y":4062.5,"x":26},{"y":4394,"x":27},{"y":4738.5,"x":28},{"y":5096,"x":29},{"y":5466.5,"x":30},{"y":5850,"x":31},{"y":6246.5,"x":32},{"y":6656,"x":33},{"y":7078.5,"x":34},{"y":7514,"x":35},{"y":7962.5,"x":36},{"y":8424,"x":37},{"y":8898.5,"x":38},{"y":9386,"x":39},{"y":9886.5,"x":40},{"y":12800,"x":41},{"y":13448,"x":42},{"y":14112,"x":43},{"y":14792,"x":44},{"y":15488,"x":45},{"y":16200,"x":46},{"y":16928,"x":47},{"y":17672,"x":48},{"y":18432,"x":49},{"y":19208,"x":50},{"y":20000,"x":51},{"y":20808,"x":52},{"y":21632,"x":53},{"y":22472,"x":54},{"y":23328,"x":55},{"y":24200,"x":56},{"y":25088,"x":57},{"y":25992,"x":58},{"y":26912,"x":59},{"y":27848,"x":60}],"fill":false,"hoverBackgroundColor":"rgba(190,24,0,0.5)","backgroundColor":"rgba(200,25,0,0.3)","borderColor":"rgba(200,25,0,1)","hoverBorderColor":"rgba(190,24,0,1)","clip":5,"baseColor":"rgba(200,25,0,1)"}]}}

### Random selection of items {#Random_selection_of_items}

Each item in the item pool has weight that is specified by their rarity value. The weight of the whole item pool is the sum of the rarity values of eligible items. Three (or four) items are then selected from the pool at random without repetitions (i.e. an item cannot be offered more than once per level up). The rough probability of an option to be a certain item is:

$P(item) = \frac{itemRarity}{itemPoolWeight}$

Currently, the total weight of the [weapon](Weapon.md) pool with all DLCs is 8,130 and the [passive item](Passive_item.md) pool with all DLCs is 1,370 (total 9,500). Rough probabilities of receiving a certain item of a rarity value can be found in the table below.

|        |           |
|--------|-----------|
| Rarity | \~P(item) |
| 1      | 0.011 %   |
| 40     | 0.421 %   |
| 50     | 0.526 %   |
| 60     | 0.632 %   |
| 70     | 0.737 %   |
| 80     | 0.842 %   |
| 90     | 0.947 %   |
| 100    | 1.053 %   |

### Receiving owned items {#Receiving_owned_items}

If the player\'s inventory is not full, there is first an attempt to specifically offer items already owned by the player. The chance to be offered items already in their inventory is affected by Luck and can be calculated as:

$ownedChance = 1 + 0.3x - \frac{1}{totalLuck}$

where *x=2* if the player\'s level is even and *x=1* if the level is odd.

The check is performed twice and, if successful, an item already owned by the player will be randomly selected to appear as an option for each successful check. However, if the second roll selects the same item as the first it is discarded and a new item is pulled from the pool of all items, as the same item is not be offered more than once in the same level up.

### Fourth option {#Fourth_option}

It is possible to sometimes gain four item choices upon leveling up. This depends on the character\'s [Luck](Luck.md). The chance to receive a fourth option is:

$chanceFourth = 1 - \left( \frac{1}{totalLuck} \right)$
