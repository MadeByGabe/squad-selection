# Squad Selection

**Automagical squad creation and proximity-based squad selection widget for [Beyond All Reason](https://www.beyondallreason.info/).**

*tldr: select some units, right-click to create a squad, then ctrl+click to select the closest squad.*

## Why?

Control groups are limited in number and require manual assignment, auto-groups select units across the entire map which is not always what we want, selectboxes are imprecise and can be difficult to use in the heat of battle.  
**Squad Selection** fills the gap: it tracks groups of units you're actually using together, then lets you re-select them based on which squad is closest to your mouse cursor.  
Works alongside all the other selection methods.

Jump straight to [installation](#installation) if you want to get going right away.

## How it works

Every factory (lab) gets its own hidden **reserve squad**, and the squad-eligible units it builds start there. Units that don't come from a factory you built (gifted, resurrected, alive at widget load, etc.) go into a single catch-all **uncategorized reserve**. Reserve squads are invisible by default so you don't see labels for stuff you haven't explicitly grouped — flip `showReserveSquads` on if you want to see them.

Squad-eligible means: unit can move, has speed, and has no build options.

**Creating squads:** Select some units and **right-click** (with no modifier keys held). Those units are pulled out of their current reserve squad into a new one.  

The reason for the "no modifiers" requirement is that it allows you to use units without creating a new squad if that's what you want. For example, you can send multiple squads together to a target with shift and right mouse button which wouldn't merge them into one squad since shift is a modifier. Then you can use squad selection to easily select each squad individually near the target for good flanking micro.

**Selecting squads:** Move your mouse cursor near the squad you want selected, then use a hotkey or ctrl+leftclick to select that squad (the closest).  
Repeatedly selecting when the closest full squad is already selected **cycles** to the next closest squad (this feature can be disabled).  
*Note: the ctrl modifier is technically not required, but the normal selectbox would interfere without it.*  

There is also a **filtered select** option that only selects the unit types from your current selection, or the closest unit's type if nothing is selected. This is hotkey or alt+ctrl+leftclick.

Both selection methods can be used with shift to append to the current selection instead of replacing it.  

*Note: the left mouse selection methods can be disabled if you prefer to use hotkeys exclusively (write `/luaui squad_setting toggle leftClickSelectsSquad` in chat (saved, you don't need to re-enter it each game)).*

Each squad is labeled with a colored letter above its units so you can see which units belong together at a glance. (There's also an experimental convex hull visualization mode and two other modes in the works)

### Hotkeys

If you want to use hotkeys instead of mouse (or in addition to), you can bind the following actions in your `uikeys.txt`:

```
bind           sc_b  closest_squad_select
bind     Shift+sc_b  closest_squad_select append
bind       Alt+sc_b  closest_squad_select_filtered
bind Alt+Shift+sc_b  closest_squad_select_filtered append
```
*(change `sc_b` to your preferred key)*


| Action                                               | What it does                                                                                                                         |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `closest_squad_select`                               | Selects the entire squad closest to the cursor                                                                                       |
| `closest_squad_select append`                        | Appends the closest squad to the current selection                                                                                   |
| `closest_squad_select_filtered`                      | Selects only the unit types (from your current selection or closest unit if nothing is selected) in the closest squad                |
| `closest_squad_select_filtered append`               | Same, but appends to selection                                                                                                       |
| `squad_create_toggle`                                | Toggles right-click squad creation on/off (see next section)                                                                         |
| `squad_create`                                       | Creates a squad from the current selection (useful if you disable right-click squad creation) or you want to assign a lab to a squad |
| `squad_select_group N`                               | Select squad ∩ control group N closest to cursor                                                                                     |
| `squad_select_portion [append] <steps...>`           | Select a portion of the closest squad                                                                                                |
| `squad_select_portion_filtered [append] <steps...>`  | Same, but filtered by unit type                                                                                                      |
| `squad_select_portion_group <N> [append] <steps...>` | Same, but limited to squad ∩ control group N (probably will be removed)                                                              |
| `squad_cycle_recent`                                 | Select + focus camera on the most recently used squad; each press steps further back; wraps around                                   |
| `squad_cycle_idle`                                   | Select + focus camera on the next squad that's mostly idle; each press moves on to the next one                                      |

<!-- TODO: I need to find a suggested hotkey -->

### Mouse controls

With `leftClickSelectsSquad` enabled (default), clicking on empty ground triggers squad selection:

| Click               | Action                          |
| ------------------- | ------------------------------- |
| **Ctrl+click**      | Select closest squad (replace)  |
| **Shift+click**     | Select closest squad (append)   |
| **Alt+Ctrl+click**  | Filtered squad select (replace) |
| **Alt+Shift+click** | Filtered squad select (append)  |

Mouse squad selections are skipped when clicking directly on a unit or when an active command is pending (fight, patrol, build placement, etc.).

**Right-click** (no modifiers) with a selection creates a squad from selected squad-eligible units.

**Ctrl+Alt+right-click** (opt-in via `/luaui squad_setting toggle modifierRightClickCreatesSquad`) also creates a squad. Useful if you disabled plain right-click squad creation but still want a mouse shortcut. Note: the click is not consumed, so a stationary click still fires the engine's "line formation with keep slowest unit's speed" command (a niche default); only dragged Ctrl+Alt+right-clicks cleanly create a squad without also issuing that command. Since players typically drag that combo to draw a line-move, this overlap is usually harmless.

### Cycling

When you already have a full squad selected (or all matching types for filtered select), the action automatically excludes your current selection and finds the *next* closest squad. This lets you cycle through squads by pressing the same key repeatedly (can be disabled via `cyclingToNextSquad` in data/LuaUi/Config/BYAR.lua -> Squad Selection section).

### Filtered selection

Filtered selection is useful with some playstyles but unnecessary for others. If your main goal is to just create squads based on unit types (thugs, grunts, etc.), then you could just use autogroups or any kind of selection method to select the thugs, then right-click to create a squad for them, same with grunts. Then you can use the normal closest squad select to get the squad of thugs or grunts, or better yet, cycle between them.

### Squad creation toggle + hotkey

Right-click squad creation can be toggled on/off. (Detailed explanation for the why soon). 

There's also an action to create a squad on demand (without needing right-click).


| Action                | What it does                               |
| --------------------- | ------------------------------------------ |
| `squad_create`        | Creates a squad from the current selection |
| `squad_create_toggle` | Toggles right-click squad creation on/off  |

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

Previously built units stay in their old squads — those become orphaned hidden reserves and prune themselves once their last unit dies. Future builds from the reassigned factories go into the new shared squad.

Pressing `squad_create` on a single factory that's already alone in its own squad is a no-op.

**Example use case:** You have 3 bot labs, 2 producing cheap spam units for distraction, 1 producing expensive units you want to micro. By default all three are separate, so selecting the expensive lab's units already works. If you'd rather the two spam labs share one squad, select them and press `squad_create`.

### Portion selection

Select a portion of a squad, sorted by distance to the mouse cursor. Define step values in the hotkey bind. Each press advances to the 'next step' until max value.

Step values: `0` selects 1 unit, values between 0 and 1 are percentages (e.g. `0.5` = 50%), values above 1 are fixed counts (e.g. `5` = 5 units).

Both modes always target the squad of the closest unit to your cursor, re-evaluating proximity on each press. This means moving your mouse to a different squad and pressing again will select from that squad instead.

**Replace mode** replaces selection with the closest N units to your cursor. Past the last step, it keeps selecting the last step's count.

**Append mode** appends the closest N *unselected* units to your selection. You can append from a different squad than what's already selected.

In both cases N is based on the step's value and number of selected units in the closest squad.

I know the above sounds a bit complicated and honestly it is, so here's a few examples to clarify:

- If steps is simply `0`, then in replace mode you get the closest unit to your cursor with each press. In append mode you keep the previously selected units and add the next closest unselected unit with each press. That number can be of course 10 or anything.
- If steps is `0.5`, then that's just 50%. 
  - In replace mode if the closest squad has 20 units, the first press selects 10, the second press re-evaluates proximity and selects 10 from whichever squad is now closest. 
  - In append mode the first press selects 10, the second press adds 10 more unselected units. If you point at another squad which has 30 units, then another press will add 15 from that squad. 
- If the steps is `5 10`, 
  - Then in replace mode the first press selects the 5 closest units, the second press replaces that selection with the 10 closest, then each press after that also replaces the selection with the 10 closest.
  - In append mode the first press selects 5, the second press adds 10 to it. Each press after that adds 10 more unselected units to the selection.


| Action                                               | What it does                                 |
| ---------------------------------------------------- | -------------------------------------------- |
| `squad_select_portion [append] <steps...>`           | Select a portion of the closest squad        |
| `squad_select_portion_filtered [append] <steps...>`  | Same, but filtered by unit type              |
| `squad_select_portion_group <N> [append] <steps...>` | Same, but limited to squad ∩ control group N |

### Recent-squad cycling (MRU)

Control groups have a nice double-tap trick that moves the camera to the group. Squads don't have a number key, but the widget tracks the squads you most recently worked with so you can jump back and forth between them. The MRU holds up to 3 entries.

A squad is pushed onto the MRU whenever you create a squad (right-click or `squad_create`) or run one of the squad-selection actions (`closest_squad_select`, the filtered and group variants, and the portion actions). Plain click/box selection does not push. Reserves (per-factory and uncategorized) are never pushed, even when a squad-selection action targets them.

`squad_cycle_recent` selects the most recently pushed squad and centers the camera on it (via `viewselection`). Each press steps to the next entry in the MRU, wrapping around at the end. The step position is derived from the current selection rather than a stored cursor — if you change selection between presses, cycling rebases from wherever you are now.

Suggested keybind:
```
bind sc_v squad_cycle_recent
```

### Finding idle squads

Squads you left behind (e.g. defenders you parked during an attack and forgot) are easy to lose track of. `squad_cycle_idle` walks your squads in order and selects the next one that's mostly idle, centering the camera on it. Press again to step to the next idle squad.

A squad counts as idle when at least 50% of its units have no commands queued. Reserve squads (per-factory and uncategorized) are skipped unless they contain more than 10 units — otherwise a single idle newly-built unit would hijack the action.

Suggested keybind:
```
bind sc_i squad_cycle_idle
```

### Minimap support

All squad selection actions work when your cursor is on the minimap. Both the standard engine minimap and the PIP-style minimap are supported.

**Note on left-click selection with the PIP minimap:** For `leftClickSelectsSquad` (Ctrl+click) to work on the PIP minimap, you need to have the PIP's "left click moves the camera" setting enabled. Without it, the PIP minimap clears the selection immediately after the squad widget creates it.

## Installation

Download and drop [squad-selection.lua](https://raw.githubusercontent.com/MadeByGabe/squad-selection/refs/heads/main/squad-selection.lua) into your `data/LuaUI/Widgets/` directory.  
Enable it in-game with **F11** (widget list) or just write this into chat:

```
/luaui togglewidget Squad Selection
```

### Configuration

For now you can change settings in-game via chat commands:


```
/luaui squad_setting toggle rightClickSquadCreate
/luaui squad_setting toggle cyclingToNextSquad
/luaui squad_setting set visualizationMode convexHull
/luaui squad_setting set visualizationMode coloredLabel
```

These changes persist.


| Setting                 | Default          | Description                                                     |
| ----------------------- | ---------------- | --------------------------------------------------------------- |
| `leftClickSelectsSquad` | `true`           | Modifier+click on empty ground selects squads                   |
| `cyclingToNextSquad`    | `true`           | Cycle to next squad when full squad is selected                 |
| `rightClickSquadCreate` | `true`           | Right-click squad creation is active                            |
| `modifierRightClickCreatesSquad` | `false` | Ctrl+Alt+right-click also creates a squad (click passes through) |
| `visualizationMode`     | `"convexHull"` | `"coloredLabel"` or `"convexHull"`                              |
| `showReserveSquads`     | `false`          | Visualize per-factory and uncategorized reserves as real squads |



| Action                            | What it does                                          |
| --------------------------------- | ----------------------------------------------------- |
| `squad_setting toggle <key>`      | Toggles a boolean setting                             |
| `squad_setting set <key> <value>` | Sets a setting to a specific value                    |
| `squad_setting get <key>`         | Prints the current value of a setting                 |
| `squad_setting reload`            | Resets all settings to the defaults defined in the Lua file |

*Note: for quickly centering the camera on the current selection (the equivalent of double-tapping a control group's number key), bind `viewselection` to a hotkey. See also the [recent-squad cycling](#recent-squad-cycling-mru) feature, which selects a recently-used squad and focuses the camera on it in one press.*

### Hotkey setup

Settings -> Control -> Change keybind preset to `custom` (from grid)

This creates an `uikeys.txt` file in the game's data folder. 

Open that file with any text editor and add the following lines to the end of the file:


```
bind Shift+Meta+1 squad_select_group 1 append
bind Meta+1 squad_select_group 1
//...

unbind Alt+sc_c blueprint_create

unbind Any+sc_c gridmenu_key 1 3
bind sc_c gridmenu_key 1 3
bind Shift+sc_c gridmenu_key 1 3

bind Alt+sc_c squad_create
bind sc_c closest_squad_select
bind shift+sc_c closest_squad_select append
bind Ctrl+sc_c squad_select_portion 0 0.5
bind Ctrl+shift+sc_c squad_select_portion 3 10 append
bind Ctrl+Meta+sc_c squad_create_toggle


unbind Any+sc_x gridmenu_key 1 2
bind sc_x gridmenu_key 1 2
bind Shift+sc_x gridmenu_key 1 2

bind sc_x closest_squad_select_filtered
bind shift+sc_x closest_squad_select_filtered append
bind Ctrl+sc_x squad_select_portion_filtered 0 0.25 0.5 0.75 1
bind Ctrl+shift+sc_x squad_select_portion_filtered 5 10 append

bind Alt selectbox_same
bind sc_b viewselection
```

Then in game write `/keyreload` in chat to apply the changes if the game is already running.

#### Explanation

`x` and `c` are essentially free keys. They are used to start the unit queue in labs but that still can be used with the above rebind (turn on settings -> control -> Factory build mode hotkeys). 

With these changes `c` becomes squad selection, with shift it's append, with ctrl it's squad portion selection. Finally with alt it's squad creation.  
`squad_create` is needed to assign labs to squads and also useful if you disable the right click squad creation with settings or temporarily with the `ctrl+space+c` hotkey.

`x` is pretty much the same except filtered selection.

`Space+1` is the group intersection selection for group 1, feel free to add more lines for more groups, or even rebind to different keys (maybe even replace `group select 1` and bind that to space+1).

I added two bonus hotkeys. Hold `Alt` while you have a unit selected to draw a selectbox. That selectbox will select only the same unit types as the currently selected units. This is very useful together with the squad selection though it's less important now that we have portion selection. 

I also bound `viewselection` to `b` for a quick camera centering on your current selection since that's not yet part of this widget. 

### Guide to learn how it works

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

Note, you can use the closest unit selection (`ctrl+c` once) and then draw a selectbox with alt to select the same type of unit.

Now build two vehicle plants and spam some rascals/rovers. Each vehicle plant has its own squad, so `c` will pick whichever squad is closest to your cursor. If you'd rather have both vehicle plants share one squad, select them and press `alt+c`.

Select some units and right click. Selected squad-eligible units are now a squad of their own, pulled out of whichever reserve they were in. Everything above applies. If you don't want this behavior you can disable the right click squad creation and just use the `alt+c` hotkey to create squads from selected units when you want to.

If you're curious what the reserves look like, toggle them on with `/luaui squad_setting toggle showReserveSquads` — you'll see labels on every lab and its units. Turn it off again for the clean default experience.

If you don't want to bother with `c` and `x`, you can use `ctrl+leftclick` and `alt+ctrl+leftclick` respectively. Both can be used with shift to append instead of replace.

## Credits

- **yyyy**: original concept and the [Fassst Selectionssss](https://kk1ff.com/bar/select.lua) prototype
- **Baldric**: this implementation
- Built with **assistance** from [Claude Code](https://claude.ai/code)

## License

GNU GPL, v2 or later.
