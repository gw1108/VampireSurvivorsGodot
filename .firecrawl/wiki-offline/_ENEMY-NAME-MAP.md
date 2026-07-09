# Enemy name map (read this before searching the offline wiki)

The wiki files in this folder are named after Vampire Survivors' *official* enemy names,
which often differ from the common names this project (and most players) use. Also note:
**one wiki page usually holds SEVERAL enemies** — a "Variants" section lists the normal
enemy, boss/treasure variants, swarm variants, etc., each with its own stats table, and
the "Notes:" rows give the common alias ("May also be referred to as ..."). So if a page
with an enemy's common name doesn't exist, it is almost certainly a variant inside one of
the pages below — don't conclude the enemy is undocumented.

| Common name (this project) | Wiki page | Variant on that page |
|---|---|---|
| Bat | `Pipeestrello.md` | Pipeestrello 1 |
| Silver Bat | `Pipeestrello.md` | Pipeestrello 5 (aka "Silver Bat") |
| Bat Swarm | `Pipeestrello.md` / `Bat_Swarm.md` | Pipeestrello (swarm) |
| Glow Bat / Giant Bat | `Giant_Bat.md` | Giant Bat |
| Zombie | `Zombie.md` | Zombie |
| Skeleton | `Skeleton.md` | Skeleton |
| Ghost | `Ghost.md` | Ghost 1 (swarm variant also here) |
| Mummy | `Big_Mummy.md` | Big Mummy (normal enemy, ID `XLMUMMY`) |
| Giant Mummy | `Big_Mummy.md` | Big Mummy (boss) (aka "Giant Mummy") |
| Mantis | `Mantichana.md` | Mantichana (normal enemy, ID `XLMANTIS`) |
| Mantis Warrior | `Mantichana.md` | Mantichana (boss) |
| Giant Mantichana | `Mantichana.md` | Mantichana (boss) (aka "Giant Mantichana") |
| Mudman | `Mudman.md` | Mudman |
| Werewolf | `Werewolf.md` | Werewolf |
| Giant Werewolf | `Werewolf.md` | Werewolf (boss 1) / (boss 2) |
| Venus | `Venus.md` | Venus |
| Giant Blue Venus | `Venus.md` | Giant Blue Venus |
| Reaper / Death | `The_Reaper.md` | The Reaper 1 |

## Gotchas when reading stats

- Stats appear per-variant as `Health; ; N`, `Power; ; N`, `MSpeed; ; N`, etc. Make sure
  you read the row of the variant you actually mean — variants on one page can differ.
- Large numbers use thousands separators: The Reaper 1's MSpeed is written `1,200`
  (i.e. 1200). A regex like `MSpeed; ; \d+` silently truncates it to `1`.
- Raw wiki numbers are copied **verbatim** into `data/balance.csv` — never rescale them
  to a local "speed economy" (see CLAUDE.md Operating Principles).
