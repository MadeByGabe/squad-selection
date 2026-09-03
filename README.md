# Squad Selection

**Automagical squad creation and proximity-based squad selection widget for [Beyond All Reason](https://www.beyondallreason.info/).**

*tldr: select some units, right-click to create a squad, then ctrl+click to select the closest squad.*

[Feature gallery](https://bar-stuff.madebygabe.dev/squad-selection) - start here.

## Why?

Control groups are limited in number and require manual assignment, auto-groups select units across the entire map which is not always what we want, selectboxes are imprecise and can be difficult to use in the heat of battle.  
**Squad Selection** fills the gap: it tracks groups of units you're actually using together, then lets you re-select them based on which squad is closest to your mouse cursor.  
Works alongside all the other selection methods.

Jump straight to [installation](#installation) if you want to get going right away.

## How it works

Every factory (lab) gets its own **reserve squad**, and the squad-eligible units it builds start there. Units that don't come from a factory you built (gifted, resurrected, alive at widget load, etc.) go into **uncategorized reserves**, which are clustered by domain (`land`, `air`, `naval`) *and* by position: a unit joins the nearest same-domain reserve within 850 elmos, or starts a new one. So a batch of units resurrected on one flank is its own squad rather than being lumped in with everything ever raised across the map. Reserve squads are hidden by default — turn them on with `/squad_setting set showReserveSquads true` if you want to visualize reserves as squads.

Squad-eligible means: any mobile unit, minus exclusions. Exclusions come from independent sources that are unioned together: the **Exclude constructors & commanders** toggle (on by default), the **Exclude resurrection units** toggle (off by default), the **Exclude combat engineers** toggle (off by default), and your own manual `excludedUnitTypes` list. Each toggle covers a curated unit list; flipping one never touches your manual list, and your manual exclusions never affect the toggles. To track an otherwise-excluded unit type, turn the corresponding toggle off (settings panel, or `/squad_setting toggle excludeConstructors` / `excludeResurrectionUnits` / `excludeCombatEngineers`).

**Creating squads:** Select some units and **right-click** (with no modifier keys held). Those units are pulled out of their current reserve squad into a new one.

The reason for the "no modifiers" requirement is that it allows you to use units without creating a new squad if that's what you want. For example, you can send multiple squads together to a target with shift and right mouse button which wouldn't merge them into one squad since shift is a modifier. Then you can use squad selection to easily select each squad individually near the target for good flanking micro.

**Selecting squads:** Move your mouse cursor near the squad you want selected, then use a hotkey or ctrl+leftclick to select that squad (the closest).  
Repeatedly selecting when the closest full squad is already selected **cycles** to the next closest squad (this feature can be disabled).  
*Note: the ctrl modifier is technically not required, but the normal selectbox would interfere without it.*  

There is also a **filtered select** option that only selects the unit types from your current selection, or the closest unit's type if nothing is selected. This is hotkey or alt+ctrl+leftclick.

All selection methods can be used with shift to append to the current selection instead of replacing it.  

*Note: the left mouse selection methods can be disabled if you prefer to use hotkeys exclusively (write `/squad_setting toggle leftClickSelectsSquad` in chat (saved, you don't need to re-enter it each game)).*


### Hotkeys

*Want to try an action before committing a keybind to it?* The **cursor-independent** actions — `squad_cycle_idle`, `squad_cycle_recent` and `squad_create` — can be run straight from chat by typing them with a leading slash (e.g. `/squad_cycle_idle`), or clicked from the optional [`squad-selection--buttons.lua`](#companion-widgets) companion widget, which drops Idle / Recent / Create / Exclude / Include buttons above the player list. (The cursor-based actions like `squad_select` need a mouse position, so they really want a hotkey.) Once you know which actions you want, bind them properly below.

If you want to use hotkeys instead of mouse (or in addition to), you can bind the following actions in your `uikeys.txt`:

```
bind           sc_c  squad_select
bind     Shift+sc_c  squad_select append
bind       Alt+sc_x  squad_select_filtered
bind Alt+Shift+sc_x  squad_select_filtered append
```
*(change to your preferred keys)*


| Action                                  | What it does                                                                                                                                                                                                                                                                             |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `squad_select`                          | Selects the entire squad closest to the cursor                                                                                                                                                                                                                                           |
| `squad_select append`                   | Appends the closest squad to the current selection                                                                                                                                                                                                                                       |
| `squad_select_filtered`                 | Selects only the unit types (from your current selection or closest unit if nothing is selected) in the closest squad                                                                                                                                                                    |
| `squad_select_filtered append`          | Same, but appends to selection                                                                                                                                                                                                                                                           |
| `squad_select_filtered retarget`        | Replace-mode only. Always peeks the closest unit: if its type is in your current selection it filters by the selection's types (same as plain), otherwise it uses the closest unit's type as the new type. Lets you swing the filter to a different unit type without first deselecting. |
| `squad_create`                          | Runs squad creation for the current selection                                                                                                                                                                                                                                            |
| `squad_limit_flip`                      | Limits to the squad nearest your cursor *and* flips within it: result is that squad's *other* units (`squad \ selection`). Drops any other squads                                                                                                                                          |
| `squad_limit`                           | Always narrows: keep only the cursor's squad's units from your current selection (`selection ∩ squad`)                                                                                                                                                                                    |
| `squad_flip`                            | Always flips: in every squad you have units selected from, swap them for that squad's *other* units. Cursor-independent                                                                                                                                                                   |
| `squad_select_group N`                  | Select squad ∩ control group N closest to cursor                                                                                                                                                                                                                                         |
| `squad_select_portion [append           | append_domain] [distance_<N>] <steps...>`                                                                                                                                                                                                                                                | Select a portion of the closest squad                                   |
| `squad_select_portion_filtered [append  | append_domain                                                                                                                                                                                                                                                                            | retarget] [distance_<N>] <steps...>`                                    | Same, but filtered by unit type (`retarget` works the same as on `squad_select_filtered`) |
| `squad_select_portion_group <N> [append | append_domain] [distance_<N>] <steps...>`                                                                                                                                                                                                                                                | Same, but limited to squad ∩ control group N (probably will be removed) |
| `squad_cycle_recent`                    | Select + focus camera on the most recently used squad; each press steps further back; wraps around (up to `mruSize` entries, default 3)                                                                                                                                                  |
| `squad_cycle_idle`                      | Select + focus camera on the next squad that's mostly idle; each press moves on to the next one                                                                                                                                                                                          |
| `squad_lock [lock\|unlock]`             | Lock (park) the selected squads so no other squad action can touch them; press again on the same selection to unlock. With nothing tracked selected, it selects the nearest locked squad instead (so the next press unlocks it). The optional `lock`/`unlock` argument forces one direction |
| `squad_select locked`                   | Select the nearest locked squad (any selection action takes the `locked` squad-kind token; add `append` to keep collecting the next-nearest ones)                                                                                                                                        |

### Mouse controls

With `leftClickSelectsSquad` enabled (default), clicking on empty ground triggers squad selection:

| Click                | Action                          |
| -------------------- | ------------------------------- |
| **Ctrl+click**       | Select closest squad (replace)  |
| **Ctrl+Shift+click** | Select closest squad (append)   |
| **Alt+Ctrl+click**   | Filtered squad select (replace) |
| **Alt+Shift+click**  | Filtered squad select (append)  |

Mouse squad selections are skipped when clicking directly on a unit or when an active command is pending (fight, patrol, build placement, etc.).

**Alternative left-click selection.** Out of the box left-click selects the whole closest squad, of any kind, with no distance cap. `leftClickAlternativeSelection` (default `false`) switches all four combos above to a second, fully configurable selection defined by `leftClickAlternativeArgs`, which takes the same tokens as the `squad_select_portion` action: step values, an optional `distance_<N>` cap, and an optional `manual`/`reserve` squad-kind filter. Filter/append flags still come from the modifiers. The default is `1 0.5 distance_850` (= whole squad capped to 850 elmos around the cursor, half the squad if the whole squad is already selected). Examples:

```
/squad_setting set leftClickAlternativeArgs 0.25 0.5 1          # 25% → 50% → 100% on successive clicks
/squad_setting set leftClickAlternativeArgs 0.5                 # selects the closest 50%
/squad_setting set leftClickAlternativeArgs 5 10                # fixed counts
/squad_setting set leftClickAlternativeArgs distance_850 0.5 1  # same but capped to units within 850 elmos
/squad_setting set leftClickAlternativeArgs manual              # whole squad, but only player-created squads
/squad_setting set leftClickAlternativeArgs                     # clear → back to whole-squad (equivalent to 1)
```

Bind `squad_setting toggle leftClickAlternativeSelection` to a hotkey (e.g. `bind capslock squad_setting toggle leftClickAlternativeSelection`) to flip between the normal and the alternative selection on demand, without losing the keyboard-only path to full-map, whole-squad selection. 

Append (Ctrl+Shift+click) always keeps growing the selection and extends into the next squad once the current one is exhausted. Replace (Ctrl+click) in portion mode snaps to the closest N each time. See [Portion selection](#portion-selection) for how step values work.

**Right-click** (no modifiers) with a selection runs `squad_create`: it creates a squad from selected squad-eligible combat units, and for factory-only selections it merges/splits factory reserve squads. The click still passes through to the engine, so the normal move command issues alongside the grouping.

**Ctrl+right-click** (opt-in via `/squad_setting toggle ctrlRightClickCreatesSquad`) also runs `squad_create`. Useful if you disabled plain right-click squad creation but still want a mouse shortcut. The click passes through to the engine, so it also issues Ctrl+RMB's move-in-formation command. Be careful with this one since it also turns on the keep slowest unit's speed option for move commands, you can turn that off with a normal right click, right click drag won't work.  

**Ctrl+right-click drag** (on by default via `ctrlRightClickDragCreatesSquad`) runs `squad_create` only once you drag past the engine's front-command threshold — a plain Ctrl+RMB with no drag never creates a squad. This pairs creating the squad with the line-move you're already drawing, so the slowest-unit-speed issue above doesn't apply. Toggle with `/squad_setting toggle ctrlRightClickDragCreatesSquad`.

*You can avoid move-in-formation by drawing a line move while holding ctrl, or if you switch to fight mode first.*

### Cycling

When you already have a full squad selected (or all matching types for filtered select), the action automatically excludes your current selection and finds the *next* closest squad. This lets you cycle through squads by pressing the same key repeatedly. `cyclingToNextSquad` (default on) controls this for **replace** actions only — append actions always cycle to the next squad when the current one is exhausted, since growing the selection across squads is the whole point of append.

### Double-tap to focus camera

Tap any non-append squad-select (hotkey or modifier-click) twice in quick succession at the same screen spot and the second tap centers the camera on the squad you just selected. (Same effect as the engine's `viewselection`)  
Useful when the closest squad (or the squad you just cycled to) is off-screen: the first tap selects it, the second tap shows you where it is. Works on minimap too.

Works for `squad_select`, `squad_select_filtered`, `squad_select_group`, the equivalent left-click commands, and any portion call (single-step like `leftClickAlternativeArgs = 0.5`, or multi-step like `0.25 0.5 1` once you've already reached the last step so only a tap that *would* re-select the same count fires the gesture). 

Append calls are skipped (their repeat semantics is "keep growing"). Tunables: `viewselectionDoubleTapMs` (default 300, set to 0 to disable) and `viewselectionDoubleTapPx` (default 5).

### Filtered selection

Filtered selection is useful with some playstyles but unnecessary for others. If your main goal is to just create squads based on unit types (thugs, grunts, etc.), then you could just use autogroups or any kind of selection method to select the thugs, then right-click to create a squad for them, same with grunts. Then you can use the normal closest squad select to get the squad of thugs or grunts, or better yet, cycle between them.

### Retargeting filtered selection (`retarget`)

By default `squad_select_filtered` (and the portion variant) keeps the existing selection's unit types as the filter when you have one. That's great when you're pulling in more of the same, but if you have tanks selected and click near artillery, replace-mode does nothing useful: there are no tanks there. The simple workaround is to deselect first, then click.

Or you can add the `retarget` keyword and the action checks the closest unit on every press:

- If its type is already in your selection, it filters by the selection's types (same as plain filtered).
- If not, it ignores the selection entirely and treats the click as a fresh filtered selection on that one new type.

So with `retarget` bound, you can move tanks forward, then point at the artillery and tap once to grab them, without deselecting first.

`retarget` is **replace-mode only** — it's incompatible with `append`/`append_domain`. If both keywords are present `retarget` is silently ignored, so it's safe to put on the same hotkey root as your append variant.

```
bind sc_x squad_select_filtered retarget
bind Ctrl+sc_x squad_select_portion_filtered retarget 0.5 1
```

The same behavior is available on Alt+Ctrl-click (replace-mode left-click filtered) via `/squad_setting toggle leftClickFilteredRetargets` — default on.

### Squad-kind filter (`manual` / `reserve`)

Every `squad_select*` action accepts an optional squad-kind keyword that restricts which squads it will consider:

- `manual` — only squads you created yourself.
- `reserve` — only the automatic ones: the per-factory reserves and the uncategorized reserves.
- `any` — the default. It only exists so a bind can state it explicitly.

The keyword is position-independent and combines with everything else (`append`, `append_domain`, `retarget`, `distance_<N>`, step values):

```
bind sc_v squad_select manual
bind Shift+sc_v squad_select append_domain manual
bind Ctrl+sc_v squad_select_portion reserve distance_850 0.5 1
```

Use `reserve` to grab fresh factory output without touching your organized squads, or `manual` to cycle only through the squads you built by hand. The same filter is available on left-click through `leftClickAlternativeArgs`.

### Limit-or-flip selection

These three actions shape your *existing* selection rather than picking units from squads by cursor proximity. They're the answer to two related problems:

1. You used another selection method (autogroup, control group, custom select hotkey, box-select) and ended up with units across multiple squads. You want to keep only the ones in a particular squad. Point at that squad then tap `squad_limit` so the selection narrows to that squad's slice.
2. You select the damaged units of a squad and retreat them. Now you want the rest of the squad (the healthy ones still on the line). Tap `squad_limit_flip` (point at the squad) or `squad_flip` (any number of squads): the damaged units are deselected and the squad's other units are selected.

All three pick a **target squad** = the squad that owns the tracked-selected unit closest to your cursor (except `squad_flip`, which is cursor-independent and acts on every selected squad), and all three fall back to a plain squad_select when no tracked units are selected (empty, or only untracked units like Commander/scouts).

- `squad_limit_flip` — limits to the target squad **and** flips within it: result = `target_squad \ selection` (the target squad's *other* units). Any other squads in the selection are dropped. A fully-selected squad flips to empty; tap again to re-select the closest squad via the fallback. Works the same whether one or several squads are selected.
- `squad_limit` — narrow only: result = `selection ∩ target_squad`. Keeps the target squad's selected units, drops the rest. On a single-squad selection this is a no-op (already within the squad).
- `squad_flip` — flip only, in **every** squad you have units selected from (not just the one under the cursor): each such squad's selected units are swapped for its unselected ones. So if you retreated the damaged units out of several squads at once, one tap re-selects all the healthy survivors across all of them. Cursor-independent.

Suggested keybinds:
```
bind sc_v squad_limit_flip
bind Alt+sc_v squad_limit
bind Shift+sc_v squad_flip
```

### Domain filtering (`append_domain`)

In long games it's easy to accidentally pull a nearby air squad into your land selection when you're shift-spamming nearby squads together for a squad merge. `append_domain` is an alternative to the `append` keyword that prevents this: it appends like normal but only from squads whose **domain** matches your current selection. Domains are `land`, `air`, and `naval`.

With a pure-land selection, mixed land+air squads are skipped entirely (not just their air units): a squad is either fully compatible or rejected at the squad level, so no air units leak in when you later `squad_create`. With nothing selected the filter is bypassed, so the first append works normally.

`append_domain` is accepted in place of `append` in every action that takes the append keyword — `squad_select`, `squad_select_filtered`, `squad_select_group`, and the three portion variants.

**Left-click default.** Ctrl+Shift+click (and Alt+Shift+click) use domain filtering by default. Turn off with `/squad_setting toggle leftClickAppendFiltersDomain` if you'd rather have unrestricted append on the mouse.

**Double-tap flip.** Tap any append twice in quick succession at the same screen spot and the second tap flips the domain filter: `append` becomes `append_domain` and `append_domain` becomes `append`. So if your usual hotkey/click is plain append, double-tap to constrain by domain on demand; if it's `append_domain`, double-tap to broaden out of the filter and pull in a cross-domain squad. Uses the same window as the camera-focus double-tap (`viewselectionDoubleTapMs` / `viewselectionDoubleTapPx`).

### Squad creation toggle + hotkey

Right-click squad creation can be toggled on/off via `squad_setting toggle rightClickSquadCreate` (bind it to a hotkey for on-the-fly flipping). (Detailed explanation for the why soon).

There's also an action to create a squad on demand (without needing right-click).


| Action         | What it does                                                                                           |
| -------------- | ------------------------------------------------------------------------------------------------------ |
| `squad_create` | Same create behavior as right-click, including factory reserve merge/split for factory-only selections |

### Right-click moves nearest squad

When `rightClickMovesSquad` is on (default) a right-click-drag move-orders the squad **nearest the press point** to the release point — without disturbing your current selection. With nothing selected this is the most natural way to command squads: aim near a squad, right-click and then drag where you want it to go. 

Modifiers stack:

| Hotkeys                | Action                                                                       |
| ---------------------- | ---------------------------------------------------------------------------- |
| `RMB`                  | Move the closest squad                                                        |
| `Ctrl+RMB`             | Move in formation (slowest-speed) — closest squad                            |
| `Shift+RMB`            | Lock the closest squad and append the move to its queue                      |
| `Ctrl+Shift+RMB`       | Lock the closest squad and queue a formation move                            |
| `Space+RMB`            | Any of the above, but **also selects the squad** |
| `Alt+RMB`              | Do all of the above even when you already have a selection (your selection stays put) |

Without `Alt`, the gesture only fires when nothing is selected, so it never hijacks a normal right-click move of your current selection. `Alt` opts in even with a selection; `Alt+anything` works the same as the unmodified variants above but applies while units are selected. The `Space` variant is the way to grab a squad for follow-up micro: it issues the move *and* selects the squad, so it doubles as a "select and command in one click."

The pick range is capped by `rightClickMoveRange` (elmos from the cursor; `0` = unlimited). While the gesture is armed the targeted squad is highlighted so you can see which one will receive the order.

Reserve squads are left alone by default: the gesture only picks **manual** squads, so a right-click near a factory won't drag its fresh output off the rally point. The reserve still highlights, at half strength, because left-click select can still take it. Turn on `rightClickMoveControlsReserves` and the gesture commands reserves too — and the commanded reserve is promoted to a manual squad on the spot, so it stops collecting new factory output.

The gesture is skipped whenever an active command is pending (fight, patrol, build placement, etc.), since right-click is how you cancel that command.

### Control group intersection

Select the intersection of a squad and a control group. Uses the closest unit from the control group to determine which squad, then selects only the units that are in both that squad and the control group.

Suggested keybinds:
```
bind Shift+Meta+1 squad_select_group 1 append //shift+space+1
bind Meta+1 squad_select_group 1 //space+1
bind Shift+Meta+2 squad_select_group 2 append
bind Meta+2 squad_select_group 2
...
```

| Action                        | What it does                             |
| ----------------------------- | ---------------------------------------- |
| `squad_select_group N`        | Select squad ∩ group N closest to cursor |
| `squad_select_group N append` | Same, but appends to selection           |

### Factory / lab assignment

Every factory starts out with its own hidden reserve squad, and its units go there. If you want two or more labs to **share** a squad (so selecting them picks up units from all of them at once), select those factories and press `squad_create`. A new shared squad is created and all selected factories are reassigned to it. Press `squad_create` on a single factory that's currently sharing a squad to **split** it back out into its own squad.

**Example use case:** You have 3 bot labs, 2 producing cheap spam units for distraction, 1 producing expensive units you want to micro. By default all three are separate. If you'd rather the two spam labs share one squad, select them and press `squad_create`, this way all your ticks or rascals will be in the same squad and easier to select together with one click. 

### Merging units into a reserve squad

`squad_create` can move your selection INTO a reserve squad instead of creating a new manual squad. Two conditions must hold:

1. Your **last widget squad-select** targeted that reserve.
2. Every unit of that reserve is in your current selection.

Typical flow: select your manual squad first (however you like), then squad-select the reserve in append mode so the manual squad stays in the selection. Press `squad_create` (hotkey or right-click). The manual squad's units are moved into the reserve and the reserve is left selected.

Selecting *only* a reserve squad and pressing `squad_create` still creates a new manual squad from those units, so use this to promote reserve units into a tracked manual squad.

If you don't want the merge behavior at all, then turn it off with `/squad_setting set mergeIntoReserves false` (also exposed in the settings panel as "Merge into reserves").

### Portion selection

Select a portion of a squad, sorted by distance to the mouse cursor. Define step values in the hotkey bind. Each press advances to the 'next step' until max value.

Step values: `0` selects 1 unit, values between 0 and 1 are percentages (e.g. `0.5` = 50%), values above 1 are fixed counts (e.g. `5` = 5 units).

Both modes always target the squad of the closest unit to your cursor, re-evaluating proximity on each press. This means moving your mouse to a different squad and pressing again will select from that squad instead.

**Replace mode** replaces selection with the closest N units to your cursor. Past the last step, it keeps selecting the last step's count.

**Append mode** appends the closest N *unselected* units to your selection. You can append from a different squad than what's already selected.

In both cases N is based on the step's value and number of selected units in the closest squad.

I know the above sounds a bit complicated and honestly it is, so here's a few examples to clarify:

- If steps is simply `0`, then in replace mode you get the closest unit to your cursor with each press (this can already be useful, think of spybot micro). In append mode you keep the previously selected units and add the next closest unselected unit with each press. That number can be of course 10 or anything.
- If steps is `0.5`, then that's just 50%. 
  - In replace mode if the closest squad has 20 units, the first press selects 10, the second press re-evaluates proximity and selects 10 from whichever squad is now closest. 
  - In append mode the first press selects 10, the second press adds 10 more unselected units. If you point at another squad which has 30 units, then another press will add 15 from that squad. 
- If the steps is `5 10`, 
  - Then in replace mode the first press selects the 5 closest units, the second press replaces that selection with the 10 closest, then each press after that also replaces the selection with the 10 closest.
  - In append mode the first press selects 5, the second press adds 10 to it. Each press after that adds 10 more unselected units to the selection.

**Distance cap (`distance_<N>`).** Add a token like `distance_800` anywhere in the bind to cap selection by units within `N` world-distance of your cursor. The closest squad is still picked as normal, and the step percentage/count is resolved against that squad's full eligible pool first; then only units within the radius are actually selected. 

```
bind Ctrl+Shift+c_c squad_select_portion 0.5 distance_800 append
```


| Action                                  | What it does                              |
| --------------------------------------- | ----------------------------------------- |
| `squad_select_portion [append           | append_domain] [distance_<N>] <steps...>` | Select a portion of the closest squad        |
| `squad_select_portion_filtered [append  | append_domain] [distance_<N>] <steps...>` | Same, but filtered by unit type              |
| `squad_select_portion_group <N> [append | append_domain] [distance_<N>] <steps...>` | Same, but limited to squad ∩ control group N |

### Recent-squad cycling (MRU)

Control groups have a nice double-tap feature that moves the camera to the group. Squads don't have a number key, but the widget tracks the squads you most recently worked with so you can jump back and forth between them. The MRU holds `mruSize` entries (default 3) — tune with `/squad_setting set mruSize 5`.

A squad is pushed onto the MRU whenever you create a squad (right-click or `squad_create`) or run one of the squad-selection actions (`squad_select`, the filtered and group variants, and the portion actions). Plain click/box selection does not push. 

`squad_cycle_recent` selects the most recently pushed squad and centers the camera on it (via `viewselection`). Each press steps to the next entry in the MRU, wrapping around at the end. The step position is derived from the current selection rather than a stored cursor — if you change selection between presses, cycling rebases from wherever you are now.

Suggested keybind:
```
bind Shift+sc_s squad_cycle_recent
```

### Finding idle squads

Squads you left behind (e.g. defenders you parked during an attack and forgot) are easy to lose track of. `squad_cycle_idle` walks your squads in order and selects the next one that's mostly idle, centering the camera on it. Press again to step to the next idle squad.

A squad counts as idle when more than 50% of its units have no commands queued. 

Idle squads also get a darker visualization color in convex-hull mode so they stand out when you're scanning the map.

There is one special case for air: if an idle squad is entirely strafing air units and those units are currently flying, then its convex hull fades out completely instead of leaving a big floating visual noise on the screen.

Suggested keybind:
```
bind Shift+sc_d squad_cycle_idle
```

### Locking squads

Some squads should be left alone: early-warning scouts on random patrol, anti-air group parked somewhere, etc.. `squad_lock` marks the selected squads as *locked*, which parks them — every action that *finds* a squad (all the select actions, `squad_cycle_recent`, `squad_cycle_idle`, right-click move and the closest-squad preview highlight) skips locked squads entirely, so they can't be scooped up by accident.

Their membership is frozen too: a selection that spills over a locked squad splits off the rest and leaves the locked squad whole, so `squad_create` never eats one. To split or merge a locked squad, unlock it first.

- Press `squad_lock` with squads selected → lock them (press again with the same selection → unlock).
- Selected units belonging to an automatic (reserve) squad are extracted into a fresh manual squad which is then locked — reserves keep receiving factory output, so they are never locked themselves.
- Press it with nothing tracked selected → it selects the nearest locked squad, so a second press unlocks it.
- `squad_lock lock` / `squad_lock unlock` force one direction instead of toggling.

Actions that only *shape* the current selection (`squad_limit`, `squad_flip`) still work on a locked squad you deliberately selected, and the selection is kept after locking — "select scouts, lock, send them off" works in either order.

To reach a locked squad on purpose, any selection action accepts the `locked` squad-kind token, e.g. `squad_select locked`. Bound with `append`, repeated presses collect the next-nearest locked squads, so one `squad_lock` press afterwards unlocks them all at once.

Locked squads are drawn outline-only and dimmed instead of filled, and only while they have selected units (plus a short bright flash whenever you lock or unlock one). Set `squad_setting toggle showLockedSquads` to keep their outline visible at all times.

Suggested keybinds:
```
bind Meta+sc_v squad_lock
bind Meta+shift+sc_v squad_select append locked
```

### Minimap support

All squad selection actions work when your cursor is on the minimap. Both the standard engine minimap and the PIP-style minimap are supported.

**Note on left-click selection with the PIP minimap:** For `leftClickSelectsSquad` (Ctrl+click) to work on the PIP minimap, you need to have the PIP's "left click moves the camera" setting enabled. Without it, the PIP minimap clears the selection immediately after the squad widget creates it.

## Installation

Download and drop [squad-selection.lua](https://raw.githubusercontent.com/MadeByGabe/squad-selection/refs/heads/main/squad-selection.lua) into your `data/LuaUI/Widgets/` directory. (or into a subdirectory such as `squad-selection` to keep things organized) 
Enable it in-game with **F11** (widget list) or just write this into chat:

```
/luaui togglewidget Squad Selection
```

Optionally install any [companion widgets](#companion-widgets) the same way for additional visualization styles.

### Configuration

Most settings can be changed through the **in-game settings panel**.

**Playstyle presets.** The widget has more switches than most players want to think about, so the settings panel leads with a **Playstyle preset** select. Picking one writes every setting that preset owns in a single step:

| Preset | For |
| ------ | --- |
| `minimal` | The least surprising behaviour: no cycling, no domain filtering on append, Ctrl+right-click drag creates squads, reserves stay hidden |
| `autogroup` | Mostly filtering group selections, occasionally building a manual squad: cycling and domain-filtered appends on, reserves visualized |
| `squad` | Constantly creating and merging squads: alternative left-click selection, plain right-click creates squads, right-click move commands reserves, per-squad hull colors |
| `custom` | Your own mix. This is the default, so a fresh install (or a config saved before presets existed) never has its settings rewritten |

Presets are also reachable from chat: `/squad_setting preset squad` (no argument prints the active one). Changing any setting a preset owns — from the panel, from chat, or through the `WG` API — drops the active preset back to `custom`, so what the panel shows always matches what the config holds.

For settings that don't have a panel control (like `leftClickAlternativeArgs` and `excludedUnitTypes`), use chat commands:

```
/squad_setting toggle rightClickSquadCreate
/squad_setting toggle cyclingToNextSquad
/squad_setting set visualizationMode convexHull
/squad_setting set visualizationMode none
/squad_setting set leftClickAlternativeArgs 0.5
/squad_setting set excludedUnitTypes armrectr cornecro legrezbot
/squad_setting add excludedUnitTypes armrectr cornecro legrezbot
/squad_setting remove excludedUnitTypes armrectr cornecro legrezbot
/squad_setting set hullPulseRate 2.0                 # animation tuning (no panel control)
/squad_setting preset squad
```

All changes persist across games.


| Setting                          | Default                         | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| -------------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `preset`                         | `"custom"`                      | Active playstyle preset: `minimal`, `autogroup`, `squad` or `custom`. Set it with `squad_setting preset <name>`; writing any setting a preset owns drops it back to `custom`                                                                                                    |
| `leftClickSelectsSquad`          | `true`                          | Modifier+click on empty ground selects squads                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `leftClickAlternativeSelection`  | `false`                         | When enabled, left-click (replace and append) uses `leftClickAlternativeArgs`; when disabled, both select the whole closest squad, any kind, with no distance cap. Toggle with `squad_setting toggle leftClickAlternativeSelection` (bind to a hotkey for on-the-fly flipping)                                                                                                                                                                                                                                                                                                                                                                                                    |
| `leftClickAlternativeArgs`       | `1 0.5 distance_850`            | What the alternative left-click selection does (only honored when `leftClickAlternativeSelection` is true). Same tokens as `squad_select_portion`: `1` = whole squad, `0.5 1` = 50% then 100%, `distance_<N>` anywhere in the list caps selection to units within N elmos of the cursor, and `manual`/`reserve` restricts it to that kind of squad                                                                                                                                                                                                                                                                                                                                |
| `leftClickAppendFiltersDomain`   | `true`                          | When enabled, left-click append (Ctrl+Shift / Alt+Shift) uses `append_domain`; when disabled, it uses plain `append` (on double click it switches mode)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `leftClickFilteredRetargets`     | `true`                          | When enabled, replace-mode left-click filtered (Alt+Ctrl-click) acts like the `retarget` keyword — peeks the closest unit and uses its type as the filter when it isn't already in the selection. Append left-click is unaffected.                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `cyclingToNextSquad`             | `true`                          | Cycle to next squad when full squad is selected                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `rightClickSquadCreate`          | `false`                         | Right-click squad creation is active                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `ctrlRightClickCreatesSquad`     | `false`                         | Ctrl+right-click also creates a squad (click passes through)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `ctrlRightClickDragCreatesSquad` | `true`                          | Ctrl+right-click *drag* (past the engine's front-command threshold) creates a squad; a no-drag Ctrl+RMB does nothing (click passes through)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `rightClickMovesSquad`           | `true`                          | Right-click-drag move-orders the nearest squad (nearest to the press point) without disturbing your selection. Hold Alt to do it while have a selection, Shift to lock+queue, Ctrl for formation move, Space to also select the squad.                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `rightClickMoveRange`            | `850`                           | Max distance (elmos) from the cursor for right-click-move to highlight and pick a squad; `0` = unlimited                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `rightClickMoveControlsReserves` | `false`                         | When enabled, right-click-move can also command reserve squads, and promotes the commanded reserve to a manual squad. When disabled, the gesture only picks manual squads and a nearby reserve previews at half strength                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `viewselectionDoubleTapMs`       | `300`                           | Max ms between two single-step replace selects for the double-tap → `viewselection` gesture; `0` disables                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `viewselectionDoubleTapPx`       | `5`                             | Max screen-pixel distance between the two taps of the `viewselection` double-tap                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `mruSize`                        | `3`                             | How many recent squads `squad_cycle_recent` cycles through                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `visualizationMode`              | `"convexHull"`                  | `"convexHull"` or `"none"`. Additional styles are provided by companion widgets                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `showReserveSquads`              | `false`                         | Visualize per-factory and uncategorized reserves as squads                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `excludedUnitTypes`              | `"armrectr cornecro legrezbot"` | Unit names to exclude from squad tracking (e.g. `"armrectr cornecro legrezbot"`). Applied immediately — the widget re-classifies and re-routes every unit (so you need to remake the squads). Use `add`/`remove` to build the list in smaller batches to stay within the chat length limit. To find a unit's name by hand, open its page on [beyondallreason.info](https://www.beyondallreason.info) — the name is the last segment of the URL (e.g. `https://www.beyondallreason.info/unit/cornecro`, cornecro = Graverobber). Note: the [`squad-selection--buttons.lua`](#companion-widgets) companion widget can add/remove the currently selected units' types with a click. |
| `reserveStripePeriod`            | `64`                            | Diagonal-stripe period (in world elmos) for reserve squad fills. No panel control — set via chat                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `reserveStripeAlphaMul`          | `0.2`                           | Opacity of the dim stripe band relative to the bright band for reserve fills. No panel control — set via chat                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `hullPulseAmplitude`             | `0.25`                          | Amplitude of the breathing pulse on squad-hull alpha. No panel control — set via chat                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `hullPulseRate`                  | `1.5`                           | Rate of the breathing pulse (period ≈ 2π / rate seconds). No panel control — set via chat                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `idleColorBlendSeconds`          | `0.5`                           | Seconds for a squad's hull to fully crossfade between its active and idle color (`0` = instant). No panel control — set via chat                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |



| Action                                           | What it does                                                                    |
| ------------------------------------------------ | ------------------------------------------------------------------------------- |
| `squad_setting toggle <key>`                     | Toggles a boolean setting                                                       |
| `squad_setting set <key> <value>`                | Sets a setting to a specific value                                              |
| `squad_setting add excludedUnitTypes <name> [name ...]`     | Adds one or more unit names to the exclusion list (applied immediately)      |
| `squad_setting remove excludedUnitTypes <name> [name ...]`  | Removes one or more unit names from the exclusion list (applied immediately) |
| `squad_setting get <key>`                        | Prints the current value of a setting                                           |
| `squad_setting preset [name]`                    | Applies a playstyle preset, or prints the active one when called without a name |
| `squad_setting reload`                           | Resets all settings to the defaults defined in the Lua file                     |

*Note: for quickly centering the camera on the current selection (the equivalent of double-tapping a control group's number key), you can either double-tap a squad-select hotkey/click (see [Double-tap to focus camera](#double-tap-to-focus-camera)) or bind `viewselection` directly to a hotkey. See also the [recent-squad cycling](#recent-squad-cycling-mru) feature, which selects a recently-used squad and focuses the camera on it in one press.*

### Hotkey setup

Settings -> Control -> Change keybind preset to `custom` (from grid)

This creates an `uikeys.txt` file in the game's data folder. 

Open that file with any text editor and add the following lines to the end of the file:


```
bind Shift+Meta+1 squad_select_group 1 append_domain
bind Meta+1 squad_select_group 1
//...

unbind Alt+sc_c blueprint_create

unbind Any+sc_c gridmenu_key 1 3
bind sc_c gridmenu_key 1 3
bind Shift+sc_c gridmenu_key 1 3

bind Alt+sc_c squad_create
bind sc_c squad_select
bind shift+sc_c squad_select append_domain
bind Ctrl+sc_c squad_select_portion 0 0.5
bind Ctrl+shift+sc_c squad_select_portion 3 10 append_domain

keysym scrollock sc_0x047
bind scrollock squad_setting toggle rightClickSquadCreate

unbind Any+sc_x gridmenu_key 1 2
bind sc_x gridmenu_key 1 2
bind Shift+sc_x gridmenu_key 1 2

bind sc_x squad_select_filtered retarget
bind shift+sc_x squad_select_filtered append
bind Ctrl+sc_x squad_select_portion_filtered 0 0.25 0.5 0.75 1 retarget
bind Ctrl+shift+sc_x squad_select_portion_filtered 5 10 append


unbind Any+sc_s gridmenu_key 2 2 //maybe set target is on s key as well? TODO: test the default hotkeys
bind sc_s gridmenu_key 2 2
bind Shift+sc_s gridmenu_key 2 2

bind sc_s squad_cycle_recent

unbind Any+sc_d gridmenu_key 2 3
bind sc_d gridmenu_key 2 3
bind Shift+sc_d gridmenu_key 2 3

bind Shift+sc_d squad_cycle_idle

bind Meta+sc_v squad_lock
bind Meta+shift+sc_v squad_select append locked

bind Alt selectbox_same

keysym capslock sc_0x039
bind capslock squad_setting toggle leftClickAlternativeSelection
```

Then in game write `/keyreload` in chat to apply the changes if the game is already running.

#### Explanation

`x` and `c` are essentially free keys. They are used to start the unit queue in labs but that still can be used with the above rebind (turn on settings -> control -> Factory build mode hotkeys). 

With these changes `c` becomes squad selection, with shift it's append, with ctrl it's squad portion selection. Finally with alt it's squad creation.  
`squad_create` is needed to assign labs to squads and also useful if you disable the right click squad creation with settings or temporarily with the `ctrl+space+c` hotkey.

`x` is pretty much the same except filtered selection.

`Space+1` is the group intersection selection for group 1, feel free to add more lines for more groups, or even rebind to different keys (maybe even replace `group select 1` and bind that to space+1).

I added a bonus hotkeys. Hold `Alt` while you have a unit selected to draw a selectbox. That selectbox will select only the same unit types as the currently selected units. This is very useful together with the squad selection though it's less important now that we have portion selection. 

### Guide to learn how it works

*TODO: add some screenshots and maybe a video, update with the recently added features*

Set up the hotkeys as described above, then launch a skirmish game against an inactive ai. 

Build a bot lab and an air lab (you can increase speed with `alt++` and decrease with `alt+-`) to do it very quickly.  

Make some Thugs, Grunts, and Shurikens. Assign all three unit types to autogroup 1 with `alt+1`.

Each lab has its own hidden reserve squad, so the Thugs+Grunts are in the bot lab's squad and the Shurikens are in the air lab's. Pressing `space+1` will select either the bot lab's units (Thugs and Grunts) or the air lab's (Shurikens), depending on which is closer to your mouse cursor. If you press it again, you will get the units from the other squad with cycling (can be disabled).

Press `c` to select the closest squad to your cursor — same idea. Cycling applies if you press it again.  
Press `shift+c` to append the other squad to your selection.  

Click on the ground to unselect everything and press `x` to select the closest unit's type from its squad. So for example either Thugs, or Grunts. With shift you could add the same type of units from other squads but you don't have any other that have them (if you followed these instructions).

Click on the ground to unselect everything and press `ctrl+c` to select one unit from the closest squad. Press it again to select half of them from that squad. Press again to reselect the same count but re-sorted by your current cursor position.
Press `ctrl+shift+c` to append 10 units to your selection from the same squad or to add 3 from other squads. 

Same with `x` but filtered by type and my hotkey example had different step values for `x`. 

Note, you can use the closest unit selection (`ctrl+c` once) and then draw a selectbox with alt to select the same type of unit in an area.

Now build two vehicle plants and spam some rascals/rovers. Each vehicle plant has its own squad, so `c` will pick whichever squad is closest to your cursor. If you'd rather have both vehicle plants share one squad, select them and press `alt+c` or just right click add a waypoint for them to merge them into one squad. If you want to assign different waypoints to each plant but still have them share a squad, you can shift right click or fight plus left click or do any other command that isn't a plain right click. 

Select some units and right click. Selected squad-eligible units are now a squad of their own, pulled out of whichever reserve they were in. Everything above applies. If you don't want this behavior you can disable the right click squad creation and just use the `alt+c` hotkey to create squads from selected units when you want to or turn on the ctrl right click option.

If you don't want to bother with `c` and `x`, you can use `ctrl+leftclick` and `alt+ctrl+leftclick` respectively. Both can be used with shift to append instead of replace.  

There are many options worth experimenting with. For example I use hotkeys to select full squads but I use `leftClickAlternativeArgs = 0.5` (toggled on with capslock) to select half squads with the mouse to quickly split off a portion of a squad for micro.  
There are also many convenience features like the double-tap to focus camera, the recent squad cycling, and the idle squad finder that you can set up hotkeys for and use to quickly jump between squads.

## Companion widgets

Visualization and other features that sit on top of Squad Selection are implemented as **companion widgets**, these are separate `.lua` files that talk to the main widget through a public API. The main widget tracks squads and handles selection; companions read that state and draw things.

Install any companion by dropping its file into `data/LuaUI/Widgets/` alongside `squad-selection.lua` and enabling it in-game with **F11**.

| Widget file                            | What it does                                                                                | Status                                                                                                |
| -------------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `squad-selection--colored-labels.lua`  | CPU-drawn squad letter labels (A, B, C…) floating above each unit, colored per squad        | Complete (example/reference, not GPU accelerated so has a high CPU cost, it's mostly just an example) |
| `squad-selection--colored-markers.lua` | GPU-accelerated (GL4) colored circle markers drawn under each unit                          | Work in progress                                                                                      |
| `squad-selection--metaballs.lua`       | GPU-accelerated (GL4) metaball blobs that merge units in the same squad into organic shapes | Work in progress                                                                                      |
| `squad-selection--buttons.lua`         | A small row of on-screen buttons (Idle / Recent / Create / Exclude / Include) above the player list, for trying the cursor-independent actions without binding hotkeys first; Exclude / Include add/remove the selected units' types from `excludedUnitTypes` | Complete |

There's also a **pre-select hook example** ([pre-select-hook-example.lua](pre-select-hook-example.lua)) that demonstrates how to veto or override squad selection, for example, skipping selection when a factory is in the current selection.

### Companion widget API

Companion widgets access squad state through `WG['squadselection']`, which exposes:

**`getSquadState()`** which returns live references to internal state:

```lua
local state = WG['squadselection'].getSquadState()
-- state.squads               — array of squad arrays (integer keys = unitIDs)
-- state.unitSquad            — unitID → squad table
-- state.factorySquad         — factoryUnitID → squad table
-- state.squadIdleState       — squad → bool
-- state.squadIdleBlend       — squad → 0..1
```

Each squad array carries metadata on string keys: `.index` (monotonic ID), `.tagSeed` (golden-ratio phase offset), `.isReserve`, `.fromFactory`, and `.uncatDomain` on uncategorized reserves.

**`addSquadChangeListener(fn)` / `removeSquadChangeListener(fn)`**: Register for incremental notifications. The callback receives `(event, unitID, squad)`:

- `"add"`: unitID was added to squad
- `"remove"`: unitID is about to be removed from squad
- `"rebuild"`: wholesale state change; unitID and squad are nil — re-read `getSquadState()`

Registering a listener immediately fires `"rebuild"` so the companion can sync with existing state.

**`setBeforeSquadSelectCallback(fn)`**: Install a hook that fires before every squad selection. The callback receives a context table:

```lua
function my_hook(ctx)
    -- ctx.selected  — current selection (unit IDs)
    -- ctx.opts      — selection options (e.g. ctx.opts.isMousePress)
    -- ctx.mx, ctx.my — screen coords
    -- ctx.wx, ctx.wz — world coords
    return false              -- veto the selection
    -- return { cycleWhenFull = false }  -- override options
    -- return nil              -- proceed normally
end
```

**`createSquadFromUnits(unitIds)`**: Create a new manual squad from an explicit list of unit IDs. 

There are also exposed settings such as **`getShowReserveSquads()`**. Every config key has `get<Key>()` / `set<Key>(value)` pairs (e.g. `getCyclingToNextSquad()`, `setCyclingToNextSquad(true)`).

## Breaking changes

### Action renames

| Old name                        | New name                |
| ------------------------------- | ----------------------- |
| `closest_squad_select`          | `squad_select`          |
| `closest_squad_select_filtered` | `squad_select_filtered` |

Update any `uikeys.txt` bindings that use the old names.

## Credits

- **yyyy**: original concept and the [Fassst Selectionssss](https://kk1ff.com/bar/select.lua) prototype, also hull visualization
- **Baldric**: this implementation
- **LucyGoesAir**: High quality early feedback and suggestions
- Built with **assistance** from [Claude Code](https://claude.ai/code)

## License

GNU GPL, v2 or later.
