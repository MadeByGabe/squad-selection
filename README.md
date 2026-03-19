# Squad Selection

**Automagical squad creation and proximity-based squad selection widget for [Beyond All Reason](https://www.beyondallreason.info/).**

*tldr: select some units, right-click to create a squad, then ctrl+click to select the closest squad.*

## Why?

Control groups are limited in number and require manual assignment, auto-groups select units across the entire map which is not always what we want, selectboxes are imprecise and can be difficult to use in the heat of battle.  
**Squad Selection** fills the gap: it tracks groups of units you're actually using together, then lets you re-select them based on which squad is closest to your mouse cursor.  
Works alongside all the other selection methods.

## How it works

Every combat unit (mobile + armed, without build options) starts in a **reserve squad** for its domain (land, air, or naval).  

**Creating squads:** Select some units and **right-click** (with no modifier keys held). Those units are pulled out of their current squads into a new one.  

The reason for the "no modifiers" requirement is that it allows you to use units without creating a new squad if that's what you want. For example, you can send multiple squads together to a target with shift and right mouse button which wouldn't merge them into one squad since shift is a modifier. Then you can use squad selection to easily select each squad individually near the target for good flanking micro.

**Selecting squads:** Move your mouse cursor near the squad you want selected, then use a hotkey or ctrl+leftclick to select that squad (the closest).  
Repeatedly selecting when the closest full squad is already selected **cycles** to the next closest squad (this feature can be disabled).  
*Note: the ctrl modifier is technically not required, but the normal selectbox would interfere without it.*  

There is also a **filtered select** option that only selects the unit types from your current selection, or the closest unit's type if nothing is selected. This is hotkey or alt+ctrl+leftclick. (again, it could be just alt+leftclick).

Both selection methods can be used with shift to append to the current selection instead of replacing it.  

*Note: the left mouse selection methods can be disabled if you prefer to use hotkeys exclusively (set `leftClickSelectsSquad` to false in data/LuaUi/Config/BYAR.lua -> Squad Selection section).*

Each squad is labeled with a colored letter above its units so you can see which units belong together at a glance.

### Hotkeys

If you want to use hotkeys instead of mouse (or in addition to), you can bind the following actions in your `uikeys.txt`:

```
bind           sc_b  closest_squad_select
bind     Shift+sc_b  closest_squad_select append
bind       Alt+sc_b  closest_squad_select_filtered
bind Alt+Shift+sc_b  closest_squad_select_filtered append
```
*(change `sc_b` to your preferred key)*


| Action                                 | What it does                                                                                                          |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `closest_squad_select`                 | Selects the entire squad closest to the cursor                                                                        |
| `closest_squad_select append`          | Appends the closest squad to the current selection                                                                    |
| `closest_squad_select_filtered`        | Selects only the unit types (from your current selection or closest unit if nothing is selected) in the closest squad |
| `closest_squad_select_filtered append` | Same, but appends to selection                                                                                        |

### Mouse controls

With `leftClickSelectsSquad` enabled (default), clicking on empty ground triggers squad selection:

| Click               | Action                          |
| ------------------- | ------------------------------- |
| **Ctrl+click**      | Select closest squad (replace)  |
| **Shift+click**     | Select closest squad (append)   |
| **Alt+Ctrl+click**  | Filtered squad select (replace) |
| **Alt+Shift+click** | Filtered squad select (append)  |

Mouse squad selections are skipped when clicking directly on a unit or when an active command is pending (fight, patrol, build placement, etc.).

**Right-click** (no modifiers) with a selection creates a squad from selected combat units.

### Cycling

When you already have a full squad selected (or all matching types for filtered select), the action automatically excludes your current selection and finds the *next* closest squad. This lets you cycle through squads by pressing the same key repeatedly (can be disabled via `cyclingToNextSquad` in data/LuaUi/Config/BYAR.lua -> Squad Selection section).

## Filtered selection

Filtered selection is useful with some playstyles but unnecessary for others. If your main goal is to just create squads based on unit types (thugs, grunts, etc.), then you could just use autogroups or any kind of selection method to select the thugs, then right-click to create a squad for them, same with grunts. Then you can use the normal closest squad select to get the squad of thugs or grunts, or better yet, cycle between them.

## Configuration

In `data/LuaUi/Config/BYAR.lua` there will be a "Squad Selection" section after you have a game with the widget enabled at least once. You can change the settings there. 

| Setting                 | Default | Description                                     |
| ----------------------- | ------- | ----------------------------------------------- |
| `leftClickSelectsSquad` | `true`  | Modifier+click on empty ground selects squads   |
| `cyclingToNextSquad`    | `true`  | Cycle to next squad when full squad is selected |

*Note: control groups have a nice feature when we double tap their number key to move the camera to that group. Something similar for squads should be possible but in the meantime you can bind `viewselection` to a hotkey for a similar effect (it centers the camera on your current selection).*

## Roadmap

- [ ] **Control group squad intersection**: gets the units from a control group, finds the closest unit from that set, then selects that unit's squad and the control group's intersection.
- [ ] **Split squad**: select a fraction of the closest squad (or any selection?) sorted by distance to the cursor. 
- [ ] **Settings menu**: in-game settings menu integration (WG interface is ready).

*For possible future features check the issues with the idea tag.*

## Installation

Download and drop [squad-selection.lua](https://raw.githubusercontent.com/MadeByGabe/squad-selection/refs/heads/main/squad-selection.lua) into your `data/LuaUI/Widgets/` directory.  
Enable it in-game with **F11** (widget list) or just write this into chat:

```
/luaui togglewidget Squad Selection
```

## Credits

- **yyyy**: original concept and the [Fassst Selectionssss](https://kk1ff.com/bar/select.lua) prototype
- **Baldric**: this implementation
- Built with **assistance** from [Claude Code](https://claude.ai/code)

## License

GNU GPL, v2 or later.
