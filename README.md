> **Warning: Requires [BazCore](https://www.curseforge.com/wow/addons/bazcore).** If you use the CurseForge app, it will be installed automatically. Manual users must install BazCore separately.

# BazWidgetDrawers

![WoW](https://img.shields.io/badge/WoW-12.0_Midnight-blue) ![License](https://img.shields.io/badge/License-GPL_v2-green) ![Version](https://img.shields.io/github/v/tag/bazsec/BazWidgetDrawers?label=Version&color=orange)

A full-height slide-out side drawer for World of Warcraft that hosts a vertical stack of dockable widgets and fades out of the way when you're not using it.

BazWidgetDrawers docks to either the left or right edge of your screen and holds a stack of widgets - Quest Tracker, Minimap, Minimap Buttons, Zone Text, Micro Menu, Info Bar, and any widget registered through LibBazWidget-1.0 or BazCore's Dockable Widget API. Instead of scattering a dozen small frames around your UI, BazWidgetDrawers gathers everything into one tidy column that sits flush against the edge of your screen and can be configured, reordered, collapsed, floated, or hidden as a unit.

The drawer fades to completely invisible when you're not interacting with it, while widget content stays at full opacity so quest objectives, minimap pings, and status text remain readable at all times. Hover anywhere over the drawer and the chrome pops back; move away and it disappears into the background.

For an even more minimalist look, the **lock system** hides all chrome entirely, tightens widget spacing, and disables collapse - the drawer reads as a perfectly clean column of widgets with no decoration. Hovering still reveals a padlock icon so you can unlock at any time.

Widgets can also be **dormant** - they register and unregister themselves based on game state. For example, the Dungeon Finder widget (from BazWidgets) only appears when you're queued. No empty "Not queued" state wasting space - the widget simply doesn't exist when it's not relevant.

BazWidgetDrawers is fully extensible: any addon can publish widgets via LibBazWidget-1.0 (no BazCore dependency required) and they appear in the drawer automatically with title bar, scaling, reordering, floating, settings, and more - all for free.

***

## Features

### Slide-Out Side Panel

*   **Full-height anchoring** - spans top to bottom, pinned flush against the chosen edge
*   **Metal pull-tab handle** with Blizzard's own atlas textures - click to slide the drawer on or off screen
*   **Switchable side (Left or Right)** - tab, slide direction, and edge hot zone all flip automatically
*   **Configurable width** (120-400 px) with uniform live re-scaling of every docked widget
*   **Background opacity** and **frame opacity** sliders for fine control

### Smart Fade System

*   **Chrome fades as a unit** — backdrop, border, pull-tab, and bottom bar all fade together
*   **Default faded opacity is 0** (fully invisible) — the drawer disappears when not hovered
*   **Widget content always at full opacity** — quest text, minimap, and status info stay readable
*   **Configurable fade delay** (0-5 s), **fade duration** (0.05-2 s), and **faded opacity target** (0-1)
*   **Force full opacity in combat** (optional)
*   **Fade tab when closed** (optional) — lets the pull-tab disappear when the drawer is collapsed
*   **Edge hot zone** — invisible strip along the screen edge re-reveals the tab when collapsed

### Lock System

The padlock icon on the bottom bar (visible on hover, fades in/out with the same timing as the chrome) toggles locked mode:

*   **Drawer cannot collapse** while locked
*   **All chrome is hidden** - label, widget count, and info button disappear
*   **Widget title bar space is collapsed** - widgets pack flush against each other
*   **Fade settings are greyed out** in the options panel
*   **Only the lock icon remains visible on hover** - click to unlock

### Widget Host

*   **Per-widget title bars** with collapse chevron, widget label, and live status text (quest count, durability %, server time, etc.)
*   **Drag-to-reorder** - hold a title bar for half a second (it turns green), then drag up or down to swap positions
*   **Move Up / Move Down** buttons side by side at the top of each widget's settings page
*   **Floating mode** - detach any widget and position it anywhere via Blizzard's Edit Mode
*   **Enable / disable** individual widgets via the Modules subcategory
*   **Per-widget settings** exposed via each widget's GetOptionsArgs hook
*   **Global overrides** - set a key once and it cascades to every widget
*   **Per-widget collapse** via the title bar chevron - click to collapse, click again to expand

### Dormant Widgets

Some widgets are dormant - they only appear in the drawer when a condition is met:

*   **Automatic lifecycle** - widgets register/unregister based on game events
*   **No wasted space** - dormant widgets have no slot, no title bar, no space in the drawer
*   **Still configurable** - dormant widgets appear in the Widgets settings list marked with [D] and can be reordered while dormant
*   **Built on LibBazWidget-1.0** - any addon can use RegisterDormantWidget with an events list and condition function

***

## Built-In Widgets

### Quest Tracker

Full replica of Blizzard's objective tracker, but as a drawer widget. Read-only by design — never reparents protected frames, so it's safe in combat and doesn't fight Blizzard for control of the tracker.

*   **Dungeon / Scenario section** with stage block, orb bullets that turn into green checkmarks on completion, and auto-hide when leaving the instance
*   **Quest sections** grouped by classification — Campaign, Questlines, Legendary, Callings, Quests — each collapsible
*   **Achievement section** — click to open, right-click to untrack
*   **Bonus objectives** from area-task quests
*   **Progress bars** with Blizzard's native border styling
*   **Quest item buttons** that work like Blizzard's (right-click to use, etc.)
*   **Auto-complete popup** with pulse animation for turn-in quests
*   **POI buttons** — click to super-track, click title to open map, right-click to untrack
*   **Mouse-wheel pagination** — scroll through quests one at a time
*   **M+ Challenge Mode block** with keystone timer, affixes, and death count
*   **Waypoint integration** — TomTom and Zygor support for super-tracked quest waypoints
*   **Hide Default Tracker** option (default on)

### Zone Text

Zone name display colored automatically by PVP status - gold in neutral zones, green in friendly, red in hostile, orange in contested, light blue in sanctuary.

### Minimap

Reparents the real Blizzard minimap into the drawer at a fixed scale. All native functionality preserved - click-to-waypoint, mouse wheel zoom, right-click menu, addon pings, tracking.

### Minimap Buttons

Adopts LibDBIcon and other addon-registered minimap buttons into a centered grid with customizable button ordering. Detects buttons by name pattern + a known-good list. The LFG queue eye always lands in the first slot.

### Micro Menu

Reparents the Blizzard micro menu bar (character, spellbook, talents, LFG, achievements, shop, etc.) into a drawer widget. Scales to fill the drawer width. Fully transparent at rest, fades in on hover. Option to hide the bags bar. Edit Mode highlight always visible.

### Info Bar

Compact horizontal bar combining the Blizzard clock, a calendar shortcut, and the minimap tracking dropdown. Server time also shows in the widget title bar.

***

## Slash Commands

| Command | Description |
| --- | --- |
| `/bwd toggle` | Open or close the drawer |
| `/bwd show` | Open the drawer |
| `/bwd hide` | Close the drawer |

***

## Compatibility

*   **WoW Version:** Retail 12.0 (Midnight)
*   **Midnight API Safe:** Pure read-only polling - no reparenting of protected frames, taint-safe by design
*   **Edit Mode:** Floating widgets register as Edit Mode frames via BazCore with snapping, selection sync, and native styling
*   **TomTom:** Optional waypoint integration for super-tracked quests
*   **Zygor:** Optional waypoint integration via ZGV.Pointer:SetWaypoint
*   **LibDBIcon-1.0:** Auto-detected for Minimap Buttons widget
*   **Combat Safe:** No protected frames modified during combat
*   **LibBazWidget-1.0:** Standalone widget registry library embedded in BazCore - third-party addons can publish widgets without any BazCore dependency

***

## Dependencies

**Required:**

*   [BazCore](https://www.curseforge.com/wow/addons/bazcore) - shared framework for Baz Suite addons (installed automatically by the CurseForge app)

**Optional:**

*   [BazWidgets](https://www.curseforge.com/wow/addons/bazwidgets) - widget pack with Dungeon Finder (dormant), Repair, and more
*   [TomTom](https://www.curseforge.com/wow/addons/tomtom) - for Quest Tracker waypoint integration
*   [LibDBIcon-1.0](https://www.curseforge.com/wow/addons/libdbicon-1-0) - for Minimap Buttons widget

***

## For Widget Authors

Any addon can register widgets via LibBazWidget-1.0 (no BazCore dependency needed):

```lua
local LBW = LibStub("LibBazWidget-1.0")

-- Always-on widget
LBW:RegisterWidget({
    id           = "myaddon_mywidget",
    label        = "My Widget",
    designWidth  = 200,
    designHeight = 60,
    frame        = myFrame,
    GetDesiredHeight = function() return height end,
    GetStatusText    = function() return "text", r, g, b end,
})

-- Dormant widget (only appears when condition is true)
LBW:RegisterDormantWidget(widgetDef, {
    events = { "SOME_EVENT", "ANOTHER_EVENT" },
    condition = function() return ShouldBeActive() end,
})
```

See the [LibBazWidget-1.0 README](https://github.com/bazsec/LibBazWidget) and the [BazWidgets source](https://github.com/bazsec/BazWidgets) for reference implementations.

***

## Part of the Baz Suite

BazWidgetDrawers is part of the **Baz Suite** of addons, all built on the [BazCore](https://www.curseforge.com/wow/addons/bazcore) framework:

*   **[BazBars](https://www.curseforge.com/wow/addons/bazbars)** - Custom extra action bars
*   **[BazWidgetDrawers](https://www.curseforge.com/wow/addons/bazwidgetdrawers)** - Slide-out widget drawer
*   **[BazWidgets](https://www.curseforge.com/wow/addons/bazwidgets)** - Widget pack for BazWidgetDrawers
*   **[BazNotificationCenter](https://www.curseforge.com/wow/addons/baznotificationcenter)** - Toast notification system
*   **[BazLootNotifier](https://www.curseforge.com/wow/addons/bazlootnotifier)** - Animated loot popups
*   **[BazFlightZoom](https://www.curseforge.com/wow/addons/bazflightzoom)** - Auto zoom on flying mounts
*   **[BazMap](https://www.curseforge.com/wow/addons/bazmap)** - Resizable map and quest log window
*   **[BazMapPortals](https://www.curseforge.com/wow/addons/bazmapportals)** - Mage portal/teleport map pins

***

## License

BazWidgetDrawers is licensed under the **GNU General Public License v2** (GPL v2).
