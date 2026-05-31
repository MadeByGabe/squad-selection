This is a feature gallery (draft): a series of short videoclips, each with its section text above it.

# Squad Selection

Automagical squad creation and proximity-based squad selection.

## Selection in BAR is powerful but can still be a bit awkward

-   The number of control groups is limited.
-   Autogroups select across the whole map, often not what you want.
-   Selectboxes are imprecise and fiddly mid-fight.

## The Squad Selection Widget

This widget adds a new kind of unit grouping — ***"Squads"*** — and lets you re-select them (or part of them) based on which one is closest to your cursor (and in other ways). 

It supports both main playstyles: 
- **1v1 / selectbox players** who box-select clusters of units all over the map and would benefit from many small squads they can easily grab again.
- **Team-game / autogroup players** who want a simple spatial layer on top of the groups they already use.

The features below cater to one, the other, or both.

Source & full readme: [github.com/MadeByGabe/squad-selection](https://github.com/MadeByGabe/squad-selection).

Important note: the default settings are intentionally unobtrusive — you won't even notice the widget is installed if you don't change settings or bind hotkeys.

![hook video](assets/videos/hook_2x_cropped.mp4)
<sub>What's happening: I select the closest squad near the grunts. Then I type-filter a squad select near the rascals and create a squad. I portion-select 1 unit near the rascal squad and append a squad near the incisors. A bit later I cycle through recently used squads.</sub>

## Squad creation

You can create a squad from the selected units with a simple right-click, or by hotkey, depending on your settings.

Note: only mobile units without build options are eligible, but you can also exclude any unit type (for example rezbots or fighters).

<details>
<summary>more</summary>

For players who currently prefer autogroups, the `Ctrl+right-click creates squad` option is probably best (or just a hotkey bind).  
For 1v1 players who prefer the selectbox, the `Right-click creates squad` option is probably more useful.  
Neither is on by default.

</details>

![manual squads video](assets/videos/01_2x_cropped.mp4)

## Reserve squads

There are reserve squads as well. Every squad-eligible unit always belongs to a squad — if not to a manually created one, then to a reserve.  
Every lab has its own reserve, and there's one for units made outside of a lab (resurrected units, units made by a Twitcher, gifted units, etc.).  

<details>
<summary>more</summary>

Note: by default reserve squads have no visualization; you can turn it on with `Show reserve squads`.  
Note: labs can be merged so they produce units into a shared reserve squad, which is useful for spam.

</details>

![reserve squads video](assets/videos/02_2x_cropped.mp4)
<sub>What's happening: I select the closest squads near the reserves. I turn on reserve squad visualization with a hotkey, then change the visualization opacity with a chain hotkey.</sub>

## Basic selection

You can select the squad the closest unit belongs to with hotkey actions, or even with a simple modified left-click (modified for example by Ctrl).

Double-clicking or double-tapping the hotkeys moves the camera to focus on that squad.

Most selections also have an 'append' variant (with Shift) that simply adds the squad to your existing selection.

![basic selection video](assets/videos/03_2x_cropped.mp4)
<sub>What's happening: I select the closest squads. I double-tap that to jump to the squads, then append closest squads.</sub>

## Group based selection

You can also select only part of a squad, for example by using your existing autogroups (note: hotkey binds are required).  

The widget finds the closest unit that belongs to your autogroup, then selects the intersection of its squad and the autogroup (or normal control group).  

So squads can act as a sort of spatial subgrouping for your groups, which can be very useful.  
For example, you can have Frigates and Thugs on the same autogroup number but only select the Thugs when your cursor is near them.

<details>
<summary>more</summary>

Note: you don't need to fully replace the autogroup feature — you can use both the original and the squad variant. Just bind one of them to space+number.

</details>

![group based selection video](assets/videos/04_2x_cropped.mp4)
<sub>What's happening: My autogroup is grunts and incisors. I select it all with the normal autogroup key 1. Then I select group-and-squad intersections with space+1, and later append with space+shift+1.</sub>

## Type based selection

Finds the closest unit and its squad, then selects only the same type of units from that squad.  
Or, if you already have a selection, uses that selection as the type filter.  

![type based selection video](assets/videos/05_2x_cropped.mp4)
<sub>What's happening: I type-filter a squad selection near the rascals. I do it again but nothing happens, since there are no more rascal squads. I clear the selection, then type-filter a squad select near the grunts. Then I manually select incisors and rascals to select only those in the nearest squad, without the pounders.</sub>

If you have enabled `Modifier+left-click selects squad` (on by default), you can also do this with `Ctrl+Alt+left-click` to replace and `Shift+Alt+left-click` to append selection, both with type filtering.

<details>
<summary>more</summary>

By default the type is "locked" in replace selection, so repeatedly using this feature only gets you the same type of units, just maybe from different squads. There's a "retarget" variant that, in replace mode, resets the type filter to the closest unit's type even when you already have a selection (`Left-click filtered retargets` option).

![retarget variant video](assets/videos/05_02_2x_cropped.mp4)
<sub>What's happening: I make type-filtered squad selections near various units with retarget. Then I do the same with append.</sub>

</details>

## Portion selection

Selects the closest N units, or the closest percentage of a squad. Each use re-sorts from where the cursor is.

![portion selection video](assets/videos/06_cropped.mp4)
<sub>What's happening: I make 50% portion selections. Then I hold down the hotkey. Then I press a few more times with append (shift).</sub>

Put several sizes on one hotkey and it steps through them: e.g. **1 → 50%** means first you get the single closest unit, then half the squad, then half the squad again but maybe a different half, depending on where the cursor is.

![portion selection steps video](assets/videos/06_02_cropped.mp4)
<sub>What's happening: I use portion selection with steps: first 1 unit, then 50%. Note how the selection doesn't extend when I already have 50% selected — it just replaces the selection.</sub>

Note: which step you get depends on how big the already selected portion is, not on how many times you've used the action.

It also works with the type and group filters, has an append variant, and can be distance-capped to a radius around the cursor.

![portion selection append with filters video](assets/videos/06_03_cropped.mp4)
<sub>What's happening: I make a 50% type-filtered portion selection near the grunts, without retarget.</sub>

<details>
<summary>more</summary>

Optionally, replace left-click selections with the `Use portion steps on left-click` setting, which by default limits selection to an 850-unit radius and selects all units of a squad in that radius — or half of them if they're already selected (this can be changed, of course).

![left-click portion selection video](assets/videos/06_04_cropped.mp4)
<sub>What's happening: My step sizes are 100% then 50%. The long line squad doesn't get fully selected when I click near one of its ends, due to distance capping.</sub>

</details>

## Jumping to and between squads

I already mentioned double-tapping the selection hotkeys/clicks to jump to a squad, but there are several other ways:  

If the `Cycle to next squad on retap` setting is on, reusing the same selection action gets you the next closest squad. This also works with double-tap camera focus.

![cycle squads video](assets/videos/07_cropped.mp4)
<sub>What's happening: I select the closest squad at the same cursor position twice while cycling is on. Then I do it with double-tap to also jump to them.</sub>

<details>
<summary>more (cycling through recent squads, idle squads, and minimap interaction)</summary>

There is a `squad_cycle_recent` action that jumps to the most recently used squad. Pressing it again steps back through your squad history. The size of the history is configurable with the `Recent-squad cycle size` setting (3 by default).

There is a `squad_cycle_idle` action (not bound by default) that jumps to idle squads. A squad is considered idle if at least 50% of its units have no orders. These squads also have a different visualization.

Most actions work on the minimap as well (depending on minimap settings), so you can double-tap a squad selection on the minimap near some units and you'll select and jump to exactly those units, not to where you pointed on the minimap.

</details>

## Small convenience features

### Auto-growing selection 

This keeps a reserve squad fully selected: when a lab finishes a new unit, it joins not only the reserve squad but also your current selection, automatically. The relevant setting is `Auto-extend selection with new units` (off by default). It can also be opted out on individual labs by having that lab's last rally a patrol or wait command.

![auto-growing selection video](assets/videos/08_cropped.mp4)
<sub>What's happening: I have an auto-growing selection for grunts, and those two bot labs are merged. The bot lab at the top doesn't extend the selection because of its patrol rally.</sub>

<details>
<summary>more (Merge into reserves)</summary>

By default, if you have a selection, fully select a reserve squad, and then create a new squad, the selected units are merged into that reserve squad. This can be turned off with the `Merge into reserves` setting.  

Note: I know this seems like a bit of an odd feature, but it's needed to support both main playstyles. If you prefer to constantly create new squads and have a dozen at a time (because you're a 1v1 player), you probably want to turn off merging into reserves. But if you only use a few squads mainly to limit autogroup selections, you probably want merging into reserves left on.

</details>

### Filters append by domain

Most squad selections have an append variant that adds a squad to your existing selection. There's also an `append_domain` variant and a `Left-click append filters by domain` setting. The domain filtered variant only appends squads that are in the same domain as your current selection. Domains are "land", "air", and "naval".  

So if you have Grunts selected (land domain) and want to append a nearby squad, but some fighters (air domain) happen to fly near your cursor, this feature still appends a nearby land squad and not the fighter squad.  

![append by domain video](assets/videos/09_cropped.mp4)
<sub>What's happening: I append squads constrained by domain.</sub>

<details>
<summary>more</summary>

Note: a double-tap/double-click flips the append mode, so if you use append_domain by default, double-tapping lets you append across domains.

</details>


### Squad -> limit -> flip

The `squad_limit_flip` action does one of two things, depending on your current selection. If your selection spans multiple squads, it limits the selection to the closest squad (it doesn't fully select that squad; instead just removes the other squads from the selection).  

If your selection is already limited to one squad, it flips the selection to the rest of that squad (selecting what isn't currently selected and deselecting what is).  

This can be a surprisingly useful action if you also use other selection features.  
For example, if you have a custom selection hotkey that selects support units such as radar and jammer units on screen, and use this action as a follow-up, you can quickly get only those units from the closest squad. Used again and again, it just cycles between the combat units and the support units in that squad.

![squad limit flip video](assets/videos/10_cropped.mp4)
<sub>What's happening: I have an AA, jammer and radar bot selected. `squad_limit_flip` flips the selection to the rest of the squad, then back again.</sub>

### Full featured actions

<details>
<summary>more</summary>

All actions and settings can be used in just about any way.  

For example, holding a squad-related hotkey action repeats the action and can even trigger cycling and camera focus, which is sometimes a weirdly fun way to interact with squads. (Bind `squad_select_portion 0 append` to a key and hold it to effectively paint a growing selection across nearby squads.)

![hold portion select video](assets/videos/11_cropped.mp4)
<sub>What's happening: I hold the hotkey to paint a growing selection across nearby squads. Essentially a time- and proximity-dependent selection growth (how long I hold).</sub>

All actions can be used together with the **chain widget**, so for example you can have a hotkey that selects all nearby healthy assault units and also creates a squad out of them. 

Settings can be bound to hotkeys; for example, you can have Caps Lock toggle the `Right-click creates squad` setting.

The actions and some of the internal features are also exposed, so it's possible to make companion widgets that, for example, implement a different squad visualization, limit squad creation, or override squad selection.

</details>

## Visualization

Out of the box, squads are drawn as convex hulls around their units. You can switch this off entirely if you'd rather keep the screen clean.

Note: idle squads get a distinct color so you can spot the ones you parked and forgot. Idle strafing air squads just disappear to reduce visual noise.

<details>
<summary>more</summary>

Other styles live in **companion widgets** but they aren't really ready for use yet.

</details>

## Getting started

Drop [squad-selection.lua](https://raw.githubusercontent.com/MadeByGabe/squad-selection/refs/heads/main/squad-selection.lua) into your `data/LuaUI/Widgets/` directory and enable it in-game with **F11** or in the settings.

Out of the box nothing really changes until you opt in. A good start would be to:

-   Turn on `Ctrl+right-click creates squad`, then select some units and Ctrl+right-click drag to create a squad (you can simply ctrl+right click too but that will also turn on move in formation).
-   `Modifier+left-click selects squad` is on by default so you can Ctrl+click to select the closest squad without binding anything.

That's enough to create squads and select them.  

Everything else: [full readme](https://github.com/MadeByGabe/squad-selection) has copy-paste hotkey examples, every setting documented, detailed explanations of how the features work.

## Feedback

I'd love to hear how it plays for you, what's confusing, what's missing.  
Open an issue on [GitHub](https://github.com/MadeByGabe/squad-selection) or write a message in the [BAR Discord's related post](https://discord.com/channels/549281623154229250/1483283773939257344), or in the reddit thread (link to be added), or just to me directly (Baldric on both BAR Discord and reddit).

## Credits

-   **Baldric** — this implementation.
-   **yyyy** — original concept, the *Fassst Selectionssss* prototype, and the hull visualization.
-   **LucyGoesAir** — high-quality early feedback and useful feature suggestions.
-   Built with assistance from Claude

Licensed under the GNU GPL, v2 or later.
