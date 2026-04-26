# Squad Selection

**Automagical squad creation and proximity-based squad selection widget for [Beyond All Reason](https://www.beyondallreason.info/).**

*tldr: select some units, right-click to create a squad, then ctrl+click to select the closest squad.*

## Why?

Control groups are limited in number and require manual assignment, auto-groups select units across the entire map which is not always what we want, selectboxes are imprecise and can be difficult to use in the heat of battle.  
**Squad Selection** fills the gap: it tracks groups of units you're actually using together, then lets you re-select them based on which squad is closest to your mouse cursor.  
Works alongside all the other selection methods.

Jump straight to [installation](#installation) if you want to get going right away.

## How it works

Every factory (lab) gets its own **reserve squad**, and the squad-eligible units it builds start there. Units that don't come from a factory you built (gifted, resurrected, alive at widget load, etc.) go into domain-specific **uncategorized reserves** (`land`, `air`, `naval`). Reserve squads are hidden by default — turn them on with `/luaui squad_setting set showReserveSquads true` if you want to visualize reserves as squads.

When you have a **full reserve squad selected** and the factory produces a new unit into it, that unit is **automatically added to your selection**. This keeps your selection in sync as units roll off the production line without requiring any extra input.

*Exception:* units are NOT auto-added to your selection in these cases:
- **Factory rally ending with wait or patrol** — new units sit at the rally waiting or patrolling, and the widget remembers this on the reserve. While the trailing wait/patrol is there, the reserve-merge behavior below is also disabled: pressing `squad_create` with the reserve fully selected creates a new manual squad instead of swallowing your selection into the reserve.
- **Freshly resurrected units still healing** — rez bots leave units in wait state until healed, so they don't extend their reserve's selection.

Squad-eligible means: unit can move and has no build options.

**Creating squads:** Select some units and **right-click** (with no modifier keys held). Those units are pulled out of their current reserve squad into a new one.

The reason for the "no modifiers" requirement is that it allows you to use units without creating a new squad if that's what you want. For example, you can send multiple squads together to a target with shift and right mouse button which wouldn't merge them into one squad since shift is a modifier. Then you can use squad selection to easily select each squad individually near the target for good flanking micro.

**Selecting squads:** Move your mouse cursor near the squad you want selected, then use a hotkey or ctrl+leftclick to select that squad (the closest).  
Repeatedly selecting when the closest full squad is already selected **cycles** to the next closest squad (this feature can be disabled).  
*Note: the ctrl modifier is technically not required, but the normal selectbox would interfere without it.*  

There is also a **filtered select** option that only selects the unit types from your current selection, or the closest unit's type if nothing is selected. This is hotkey or alt+ctrl+leftclick.

All selection methods can be used with shift to append to the current selection instead of replacing it.  

*Note: the left mouse selection methods can be disabled if you prefer to use hotkeys exclusively (write `/luaui squad_setting toggle leftClickSelectsSquad` in chat (saved, you don't need to re-enter it each game)).*


### Hotkeys

If you want to use hotkeys instead of mouse (or in addition to), you can bind the following actions in your `uikeys.txt`:

```
bind           sc_c  squad_select
bind     Shift+sc_c  squad_select append
bind       Alt+sc_x  squad_select_filtered
bind Alt+Shift+sc_x  squad_select_filtered append
```
*(change to your preferred keys)*


| Action                                               | What it does                                                                                                                                             |
| ---------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `squad_select`                               | Selects the entire squad closest to the cursor                                                                                                           |
| `squad_select append`                        | Appends the closest squad to the current selection                                                                                                       |
| `squad_select_filtered`                      | Selects only the unit types (from your current selection or closest unit if nothing is selected) in the closest squad                                    |
| `squad_select_filtered append`               | Same, but appends to selection                                                                                                                           |
| `squad_create`                                       | Runs squad creation for the current selection                                                                                                            |
| `squad_select_group N`                               | Select squad ∩ control group N closest to cursor                                                                                                         |
| `squad_select_portion [append|append_domain] [distance_<N>] <steps...>`           | Select a portion of the closest squad                                                                                                     |
| `squad_select_portion_filtered [append|append_domain] [distance_<N>] <steps...>`  | Same, but filtered by unit type                                                                                                           |
| `squad_select_portion_group <N> [append|append_domain] [distance_<N>] <steps...>` | Same, but limited to squad ∩ control group N (probably will be removed)                                                                   |
| `squad_cycle_recent`                                 | Select + focus camera on the most recently used squad; each press steps further back; wraps around (up to `mruSize` entries, default 3)                  |
| `squad_cycle_idle`                                   | Select + focus camera on the next squad that's mostly idle; each press moves on to the next one                                                          |

### Mouse controls

With `leftClickSelectsSquad` enabled (default), clicking on empty ground triggers squad selection:

| Click                | Action                          |
| -------------------- | ------------------------------- |
| **Ctrl+click**       | Select closest squad (replace)  |
| **Ctrl+Shift+click** | Select closest squad (append)   |
| **Alt+Ctrl+click**   | Filtered squad select (replace) |
| **Alt+Shift+click**  | Filtered squad select (append)  |

Mouse squad selections are skipped when clicking directly on a unit or when an active command is pending (fight, patrol, build placement, etc.).

**Portion-mode left-click.** `leftClickSteps` controls how many units each click selects when enabled. Default is `1 distance_850` (= whole squad capped to 850 elmos around the cursor). Set anything else like `0.5` or `5` and the four combos above switch to portion selection: closest N units, re-sorted by cursor proximity on each press. Filter/append flags still come from the modifiers. A `distance_<N>` token anywhere in the list caps selection to units within N world-distance of the cursor, the same way it works for hotkey actions. Examples:

```
/luaui squad_setting set leftClickSteps 0.25 0.5 1          # 25% → 50% → 100% on successive clicks
/luaui squad_setting set leftClickSteps 0.5                 # selects the closest 50%
/luaui squad_setting set leftClickSteps 5 10                # fixed counts
/luaui squad_setting set leftClickSteps distance_850 0.5 1  # same but capped to units within 850 elmos
/luaui squad_setting set leftClickSteps                     # clear → back to whole-squad (equivalent to 1)
```

`leftClickSteps` is gated by `leftClickStepsEnabled` (default `false`). Out of the box left-click selects the whole squad with no distance cap. Bind `squad_setting toggle leftClickStepsEnabled` to a hotkey (e.g. `bind capslock squad_setting toggle leftClickStepsEnabled`) to flip your configured `leftClickSteps` (and any distance cap) on and off without losing the keyboard-only path to full-map selection. 

Append (Ctrl+Shift+click) always keeps growing the selection and extends into the next squad once the current one is exhausted. Replace (Ctrl+click) in portion mode snaps to the closest N each time. See [Portion selection](#portion-selection) for how step values work.

**Right-click** (no modifiers) with a selection runs `squad_create`: it creates a squad from selected squad-eligible combat units, and for factory-only selections it merges/splits factory reserve squads. The click still passes through to the engine, so the normal move command issues alongside the grouping.

**Ctrl+right-click** (opt-in via `/luaui squad_setting toggle modifierRightClickCreatesSquad`) also runs `squad_create`. Useful if you disabled plain right-click squad creation but still want a mouse shortcut. The click passes through to the engine, so it also issues Ctrl+RMB's move-in-formation command. Be careful with this one since it also turns on the keep slowest unit's speed option for move commands, you can turn that off with a normal right click, right click drag won't work.  

*You can avoid move-in-formation by drawing a line move while holding ctrl, or if you switch to fight mode first.*

### Cycling

When you already have a full squad selected (or all matching types for filtered select), the action automatically excludes your current selection and finds the *next* closest squad. This lets you cycle through squads by pressing the same key repeatedly. `cyclingToNextSquad` (default on) controls this for **replace** actions only — append actions always cycle to the next squad when the current one is exhausted, since growing the selection across squads is the whole point of append.

### Double-tap to focus camera

Tap any non-append squad-select (hotkey or modifier-click) twice in quick succession at the same screen spot and the second tap centers the camera on the squad you just selected. (Same effect as the engine's `viewselection`)  
Useful when the closest squad (or the squad you just cycled to) is off-screen: the first tap selects it, the second tap shows you where it is. Works on minimap too.

Works for `squad_select`, `squad_select_filtered`, `squad_select_group`, the equivalent left-click commands, and any portion call (single-step like `leftClickSteps = 0.5`, or multi-step like `0.25 0.5 1` once you've already reached the last step so only a tap that *would* re-select the same count fires the gesture). 

Append calls are skipped (their repeat semantics is "keep growing"). Tunables: `viewselectionDoubleTapMs` (default 300, set to 0 to disable) and `viewselectionDoubleTapPx` (default 5).

### Filtered selection

Filtered selection is useful with some playstyles but unnecessary for others. If your main goal is to just create squads based on unit types (thugs, grunts, etc.), then you could just use autogroups or any kind of selection method to select the thugs, then right-click to create a squad for them, same with grunts. Then you can use the normal closest squad select to get the squad of thugs or grunts, or better yet, cycle between them.

### Domain filtering (`append_domain`)

In long games it's easy to accidentally pull a nearby air squad into your land selection when you're shift-spamming nearby squads together for a squad merge. `append_domain` is an alternative to the `append` keyword that prevents this: it appends like normal but only from squads whose **domain** matches your current selection. Domains are `land`, `air`, and `naval`.

With a pure-land selection, mixed land+air squads are skipped entirely (not just their air units): a squad is either fully compatible or rejected at the squad level, so no air units leak in when you later `squad_create`. With nothing selected the filter is bypassed, so the first append works normally.

`append_domain` is accepted in place of `append` in every action that takes the append keyword — `squad_select`, `squad_select_filtered`, `squad_select_group`, and the three portion variants.

**Left-click default.** Ctrl+Shift+click (and Alt+Shift+click) use domain filtering by default. Turn off with `/luaui squad_setting toggle leftClickAppendFiltersDomain` if you'd rather have unrestricted append on the mouse.

**Double-tap flip.** Tap any append twice in quick succession at the same screen spot and the second tap flips the domain filter: `append` becomes `append_domain` and `append_domain` becomes `append`. So if your usual hotkey/click is plain append, double-tap to constrain by domain on demand; if it's `append_domain`, double-tap to broaden out of the filter and pull in a cross-domain squad. Uses the same window as the camera-focus double-tap (`viewselectionDoubleTapMs` / `viewselectionDoubleTapPx`).

### Squad creation toggle + hotkey

Right-click squad creation can be toggled on/off via `squad_setting toggle rightClickSquadCreate` (bind it to a hotkey for on-the-fly flipping). (Detailed explanation for the why soon).

There's also an action to create a squad on demand (without needing right-click).


| Action                | What it does                                                                                           |
| --------------------- | ------------------------------------------------------------------------------------------------------ |
| `squad_create`        | Same create behavior as right-click, including factory reserve merge/split for factory-only selections |

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

When your selection spans multiple squads AND fully contains a reserve squad (every one of its units is selected), `squad_create` moves the rest of the selection INTO that reserve instead of creating a new manual squad. First matching reserve wins when multiple qualify.

Typical use: dissolve a manual squad back into a factory's reserve. Select the manual squad together with that factory's reserve units, then press `squad_create` (hotkey or right-click). All of the manual squad's units are merged into the reserve and the combined reserve is left selected.

Selecting *only* a reserve squad and pressing `squad_create` still creates a new manual squad from those units so use this to promote reserve units into a tracked manual squad.

**Opting out with a wait or patrol rally.** If the factory's rally ends with a wait or patrol command, the merge path is skipped for that reserve even when it's fully selected, `squad_create` falls back to creating a new manual squad. This is the explicit way to say "I'm still going to select this reserve a lot, but don't keep swallowing my new squads into it." Remove the trailing wait/patrol (or change the rally) to turn the merge behavior back on (takes effect on the next unit built at that factory).

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


| Action                                               | What it does                                 |
| ---------------------------------------------------- | -------------------------------------------- |
| `squad_select_portion [append|append_domain] [distance_<N>] <steps...>`           | Select a portion of the closest squad        |
| `squad_select_portion_filtered [append|append_domain] [distance_<N>] <steps...>`  | Same, but filtered by unit type              |
| `squad_select_portion_group <N> [append|append_domain] [distance_<N>] <steps...>` | Same, but limited to squad ∩ control group N |

### Recent-squad cycling (MRU)

Control groups have a nice double-tap feature that moves the camera to the group. Squads don't have a number key, but the widget tracks the squads you most recently worked with so you can jump back and forth between them. The MRU holds `mruSize` entries (default 3) — tune with `/luaui squad_setting set mruSize 5`.

A squad is pushed onto the MRU whenever you create a squad (right-click or `squad_create`) or run one of the squad-selection actions (`squad_select`, the filtered and group variants, and the portion actions). Plain click/box selection does not push. 

`squad_cycle_recent` selects the most recently pushed squad and centers the camera on it (via `viewselection`). Each press steps to the next entry in the MRU, wrapping around at the end. The step position is derived from the current selection rather than a stored cursor — if you change selection between presses, cycling rebases from wherever you are now.

Suggested keybind:
```
bind Shift+sc_s squad_cycle_recent
```

### Finding idle squads

Squads you left behind (e.g. defenders you parked during an attack and forgot) are easy to lose track of. `squad_cycle_idle` walks your squads in order and selects the next one that's mostly idle, centering the camera on it. Press again to step to the next idle squad.

A squad counts as idle when at least 50% of its units have no commands queued. 

Idle squads also get a distinct visualization color in convex-hull mode so they stand out when you're scanning the map.

There is one special case for air: if an idle squad is entirely strafing air units and those units are currently flying, then its convex hull fades out completely instead of leaving a big floating visual noise on the screen.

Suggested keybind:
```
bind Shift+sc_d squad_cycle_idle
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

For now you can change settings in-game via chat commands like so:


```
/luaui squad_setting toggle rightClickSquadCreate
/luaui squad_setting toggle cyclingToNextSquad
/luaui squad_setting set visualizationMode convexHull
/luaui squad_setting set visualizationMode coloredLabel
/luaui squad_setting set leftClickSteps 0.5
/luaui squad_setting set excludedUnitTypes armrectr cornecro legrezbot
```

These changes persist.


| Setting                          | Default        | Description                                                                                               |
| -------------------------------- | -------------- | --------------------------------------------------------------------------------------------------------- |
| `leftClickSelectsSquad`          | `true`         | Modifier+click on empty ground selects squads                                                             |
| `leftClickSteps`                 | `1 distance_850` | Step values for left-click selection (only honored when `leftClickStepsEnabled` is true); `1` = whole squad, `0.5 1` = 50% then 100%; add `distance_<N>` anywhere in the list to cap selection to units within N elmos of the cursor |
| `leftClickStepsEnabled`          | `false`        | When enabled, left-click (replace and append) uses `leftClickSteps`; when disabled, both use whole-squad with no distance cap. Toggle with `squad_setting toggle leftClickStepsEnabled` (bind to a hotkey for on-the-fly flipping) |
| `leftClickAppendFiltersDomain`   | `true`         | When enabled, left-click append (Ctrl+Shift / Alt+Shift) uses `append_domain`; when disabled, it uses plain `append` (on double click it switches mode) |
| `cyclingToNextSquad`             | `true`         | Cycle to next squad when full squad is selected                                                           |
| `rightClickSquadCreate`          | `false`        | Right-click squad creation is active                                                                      |
| `modifierRightClickCreatesSquad` | `false`        | Ctrl+right-click also creates a squad (click passes through)                                              |
| `viewselectionDoubleTapMs`       | `300`          | Max ms between two single-step replace selects for the double-tap → `viewselection` gesture; `0` disables |
| `viewselectionDoubleTapPx`       | `5`            | Max screen-pixel distance between the two taps of the `viewselection` double-tap                          |
| `mruSize`                        | `3`            | How many recent squads `squad_cycle_recent` cycles through                                                |
| `visualizationMode`              | `"convexHull"` | `"coloredLabel"`, `"convexHull"`, (soon `"metaballs"`)                                                    |
| `showReserveSquads`              | `false`        | Visualize per-factory and uncategorized reserves as squads                                                |
| `excludedUnitTypes`              | `""`           | Comma or space separated unit IDs to exclude from squad tracking (e.g. `"armrectr,cornecro,legrezbot"`). Takes effect on next widget load. To find a unit's name, open its page on [beyondallreason.info](https://www.beyondallreason.info) — the name is the last segment of the URL (e.g. `https://www.beyondallreason.info/unit/cornecro`, cornecro = Graverobber). Note, there is a chat message limit to set a setting so you might want to edit this setting in *data/LuaUi/Config/BYAR.lua* while you're not in game.  |



| Action                            | What it does                                                |
| --------------------------------- | ----------------------------------------------------------- |
| `squad_setting toggle <key>`      | Toggles a boolean setting                                   |
| `squad_setting set <key> <value>` | Sets a setting to a specific value                          |
| `squad_setting get <key>`         | Prints the current value of a setting                       |
| `squad_setting reload`            | Resets all settings to the defaults defined in the Lua file |

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
bind Ctrl+Meta+sc_c squad_setting toggle rightClickSquadCreate


unbind Any+sc_x gridmenu_key 1 2
bind sc_x gridmenu_key 1 2
bind Shift+sc_x gridmenu_key 1 2

bind sc_x squad_select_filtered
bind shift+sc_x squad_select_filtered append
bind Ctrl+sc_x squad_select_portion_filtered 0 0.25 0.5 0.75 1
bind Ctrl+shift+sc_x squad_select_portion_filtered 5 10 append


unbind Any+sc_s gridmenu_key 2 2 //maybe set target is on s key as well? TODO: test the default hotkeys
bind sc_s gridmenu_key 2 2
bind Shift+sc_s gridmenu_key 2 2

bind sc_s squad_cycle_recent

unbind Any+sc_d gridmenu_key 2 3
bind sc_d gridmenu_key 2 3
bind Shift+sc_d gridmenu_key 2 3

bind Shift+sc_d squad_cycle_idle

bind Alt selectbox_same

keysym capslock sc_0x039
bind capslock squad_setting toggle leftClickStepsEnabled
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

There are many options worth experimenting with. For example I use hotkeys to select full squads but I use `leftClickSteps = 0.5` to select half squads with the mouse to quickly split off a portion of a squad for micro.  
There are also many convenience features like the double-tap to focus camera, the recent squad cycling, and the idle squad finder that you can set up hotkeys for and use to quickly jump between squads.

## Breaking changes

### Action renames

| Old name                        | New name                |
| ------------------------------- | ----------------------- |
| `closest_squad_select`          | `squad_select`          |
| `closest_squad_select_filtered` | `squad_select_filtered` |

Update any `uikeys.txt` bindings that use the old names.

## Credits

- **yyyy**: original concept and the [Fassst Selectionssss](https://kk1ff.com/bar/select.lua) prototype
- **Baldric**: this implementation
- Built with **assistance** from [Claude Code](https://claude.ai/code)

## License

GNU GPL, v2 or later.
