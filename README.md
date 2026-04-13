<p align="center">
  <img src="https://raw.githubusercontent.com/bazsec/BazWidgetDrawers/master/logo.png" alt="BazWidgetDrawers Logo" width="300"/>
</p>

<h1 align="center">BazWidgetDrawers</h1>

<p align="center">
  <strong>Slide-out side drawer for World of Warcraft</strong><br/>
  Hosts a stack of dockable widgets in a full-height side panel that fades out of the way when you're not using it.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/WoW-12.0%20Midnight-blue" alt="WoW Version"/>
  <img src="https://img.shields.io/badge/License-GPL%20v2-green" alt="License"/>
  <img src="https://img.shields.io/github/v/tag/bazsec/BazWidgetDrawers?label=Version&color=orange" alt="Version"/>
</p>

> **Requires [BazCore](https://www.curseforge.com/wow/addons/bazcore)**
> BazWidgetDrawers depends on the BazCore framework addon. If you use the CurseForge app, it will be installed automatically. Manual users must install BazCore separately.

---

## What is BazWidgetDrawers?

BazWidgetDrawers is a full-height slide-out panel that docks to either the left or right edge of your screen and hosts a vertical stack of widgets. It ships with a Quest Tracker (which replaces Blizzard's default objective tracker), a Repair widget, a Minimap widget that reparents the real Blizzard minimap, a Minimap Info Bar (zone text, clock, calendar, and tracking), and a Minimap Buttons collector that adopts LibDBIcon buttons from other addons.

The drawer fades down to a discreet outline when you're not using it and pops back to full opacity on hover, so it stays out of the way during gameplay but is always one mouseover away. Other Baz Suite addons (and your own addons) can register their own widgets via the BazCore Dockable Widget API and they'll appear inside BazWidgetDrawers automatically.

<p align="center">
  <img src="https://raw.githubusercontent.com/bazsec/BazWidgetDrawers/master/screenshot.png" alt="BazWidgetDrawers Screenshot" width="800"/>
  <br/>
  <em>The full BazWidgetDrawers stack — Info Bar, Minimap, Minimap Buttons, and Quest Tracker.</em>
</p>

---

## Features

### Slide-Out Drawer
- Full-height side panel with a metal pull-tab handle on the active edge
- Switchable side (left or right) — the tab and slide direction flip automatically
- Configurable width with live re-scaling of every docked widget
- Edge hot zone re-reveals the tab when the drawer is collapsed
- Background and frame opacity sliders for fine control over the at-rest look

### Smart Fade System
- Backdrop, border, tab, and chrome fade as a single unit while widget content stays at full opacity
- Configurable fade delay, fade duration, and faded opacity target
- Optional "force full opacity in combat" mode
- Optional "fade tab when closed" so the tab is always visible

### Lock System
- Padlock icon in the drawer's bottom title bar (visible on hover)
- When locked: drawer cannot collapse, all chrome is hidden, widget title bar space is collapsed, fade settings are greyed out
- Unlock by clicking the padlock again

### Widget Host
- Per-widget title bars with click-to-collapse chevron and live status text
- Drag-to-reorder via Move Up / Move Down on each widget's page
- Floating mode — detach any widget into its own draggable frame and place it via Edit Mode
- Per-widget enable/disable via the Modules subcategory
- Per-widget settings + global overrides via Global Options

### Built-in Widgets

**Quest Tracker** — Full Blizzard objective tracker replica with sections:

| Section | Description |
|---------|-------------|
| Dungeon / Scenario | Decorative stage block + boss list with graphic orb bullets and green checkmarks; dynamic label ("Dungeon", scenario name, "Proving Grounds") based on scenario type |
| Campaign | Story quests classified via `C_QuestInfoSystem.GetQuestClassification` |
| Questlines | Multi-quest storyline tracking |
| Quests | Standard tracked quests with native POI super-track buttons |
| Achievements | Tracked achievements via `C_ContentTracking`; left-click opens the achievement, right-click untracks |

Plus item-level pagination (no half-cut quests when scrolling), TomTom waypoint integration, collapsible group headers, and an option to hide Blizzard's default tracker.

**Repair** — Three-column layout (paper doll / damaged-slot list / durability percent):

| Setting | Description |
|---------|-------------|
| Paper Doll Mode | Custom icon grid / native DurabilityFrame / none |
| Hide Default Durability Frame | Permanently suppress Blizzard's auto-popup armored figure |

**Minimap** — Reparents the real Blizzard minimap into the drawer at a fixed scale.

**Minimap Buttons** — Adopts LibDBIcon and other addon-registered minimap buttons into a tidy grid.

**Minimap Info Bar** — Zone text + scaled clock + day-of-month calendar proxy + native minimap tracking dropdown in one tightly grouped bar.

---

## Slash Commands

| Command | Description |
|---------|-------------|
| `/bd toggle` | Open or close the drawer |
| `/bd show` | Open the drawer |
| `/bd hide` | Close the drawer |
| `/bdrawer` | Same as `/bd` (full alias for all subcommands) |

---

## Installation

### CurseForge / WoW Addon Manager
Search for **BazWidgetDrawers** in your addon manager of choice. BazCore will be installed automatically as a dependency.

### Manual Installation
1. Install [BazCore](https://www.curseforge.com/wow/addons/bazcore) first
2. Download the latest BazWidgetDrawers release
3. Extract to `World of Warcraft/_retail_/Interface/AddOns/BazWidgetDrawers/`
4. Restart WoW or `/reload`

---

## Compatibility

| | |
|---|---|
| **WoW Version** | Retail 12.0.1 (Midnight) |
| **API Safety** | Pure read-only polling — no protected frame reparenting, taint-safe by design |
| **Edit Mode** | Floating widgets register as Edit Mode frames via BazCore |
| **TomTom** | Optional integration for the Quest Tracker waypoint feature |

---

## Dependencies

**Required:**
- [BazCore](https://www.curseforge.com/wow/addons/bazcore) — shared framework for Baz Suite addons

**Optional:**
- [TomTom](https://www.curseforge.com/wow/addons/tomtom) — for super-tracked quest waypoints
- [LibDBIcon-1.0](https://www.curseforge.com/wow/addons/libdbicon-1-0) — for the Minimap Buttons widget to detect addon-registered icons

---

## Adding Your Own Widgets

Any addon can register a dockable widget via BazCore:

```lua
BazCore:RegisterDockableWidget({
    id           = "myaddon_mywidget",
    label        = "My Widget",
    designWidth  = 200,
    designHeight = 60,
    frame        = myFrame,
    GetDesiredHeight = function() return self._height end,
    GetStatusText    = function() return "12", 1, 1, 1 end,
    GetOptionsArgs   = function() return { ... } end,
})
```

The widget appears inside BazWidgetDrawers automatically. See the BazCore developer reference for the full contract.

---

## License

BazWidgetDrawers is licensed under the [GNU General Public License v2](LICENSE) (GPL v2).

---

<p align="center">
  <sub>Built with engineering precision by <strong>Baz4k</strong></sub>
</p>
