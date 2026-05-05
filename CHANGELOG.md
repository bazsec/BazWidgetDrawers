# BazWidgetDrawers Changelog

> Renamed from BazDrawer to BazWidgetDrawers in v016. Settings are migrated automatically.

## 058 — Quest Tracker shows tracked recipes

Tracking a recipe from the Professions panel now adds it to the
Quest Tracker widget under a "Professions" header, the same way
Blizzard's default tracker handles it. Each tracked recipe lists
its required reagents with a live "have / need" count; reagents
you've collected enough of show a check mark and dim out as you
loot more. Left-click a recipe to open it in the Professions
panel; right-click to stop tracking it.

## 057 — Quest tracker click opens the quest log properly

Clicking a quest in the Quest Tracker widget when the map was closed
used to open just the world map without the quest log panel — so you'd
see the map but no quest details. The widget now opens the quest log
side panel alongside the map, the same way clicking a quest in
Blizzard's objective tracker does.

## 056 — User guide refresh

The in-game User Manual now has dedicated pages for Auto-Switch
(per-context drawer triggers — Open World, Dungeon, Raid, M+, Delve,
BG, Arena), Choosing Widgets per Drawer (the Widgets-page-then-Drawers-
page workflow with the new opt-in default), Profiles, and a polished
Welcome with current slash commands.

## 055 — Newly enabled widgets stay off in drawers until you add them

Turning a widget on in the Widgets page no longer auto-adds it to every
drawer. Head to the Drawers page and tick the widget on for whichever
drawer(s) you want it in. Existing drawers that were set to "show all"
freeze their current widget list the first time you flip a new widget
on, so nothing already in them disappears.

## 054 — Enabling dormant widgets actually saves now

Widgets that wake up on demand (like the Dungeon Finder widget when
you queue) didn't save their on/off state when you toggled them — the
Widgets page click silently did nothing. Fixed; the toggle now sticks
and the widget shows up correctly on the Drawers page.

## 053 — BazCore widgets group under "BazCore" in the list

The CPU Monitor widget (and any future BazCore-provided widget) used to
appear under "Other" in the Widgets settings list. It now groups under
"BazCore" alongside the other suite widgets.

## 052 — Quest Tracker no longer errors during combat

Clicking a quest title in the tracker while in combat used to spam
"action blocked" errors. The click is now ignored during combat —
re-click after combat ends.

## 051 — Drawers page only lists widgets you've enabled

Disabling a widget in the Widgets page now removes it from every
drawer's checkbox list, instead of leaving an unusable toggle. Re-
enable it and it comes back automatically.

## 050 — No more "action blocked" errors during combat

When dormant widgets registered or unregistered themselves while in
combat (e.g. Trinket Tracker's secure buttons), the drawer's reflow
could trip combat-lockdown errors. Reflow and widget moves now wait
until you leave combat before running.

## 049 and earlier — Multi-drawer support

Multiple drawer presets, each with their own widget list, width, and
fade settings. Switch between them via the tabs at the top of the
drawer or auto-switch based on game context (questing, M+, raid, etc.).

## 016 — Renamed from BazDrawer to BazWidgetDrawers

Also split the Repair and Dungeon Finder widgets out into a separate
BazWidgets addon so this addon stays focused on the drawer plus a
small set of core widgets (Quest Tracker, Minimap, Minimap Buttons,
Minimap Info Bar, Zone Text, Micro Menu).

### Earlier highlights

- **Micro Menu widget** — Blizzard's micro menu button row, scaled to
  the drawer width with optional fade-when-not-hovered.
- **Nudge controls** in Edit Mode — pixel-precise position buttons on
  every floating widget.
- **Zygor + TomTom waypoints** wired into the Quest Tracker.
- **Quest Tracker polish** — Blizzard-matching progress bars, green
  checkmarks on complete objectives, click-to-use quest items.
- **Auto-complete quest popup** — quests ready to turn in show a
  pulsing icon you can click to complete.
- **Bonus Objectives** group at the bottom of the tracker.
- **Mythic+ Challenge Mode** dedicated tracker block — live countdown,
  keystone level, affix icons with tooltips, death counter.
- **Delve / Scenario** Blizzard widgets (tier badge, death counter,
  affix icons, map thumbnail) embedded directly in the tracker.
- **Minimap Buttons** widget with persistent queue-eye capture and
  whitelist-based adoption (no more invisible HandyNotes pins).
- **Quest Tracker modular refactor** — internal cleanup, no behaviour
  change.
