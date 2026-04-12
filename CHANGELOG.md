# BazDrawer Changelog

## 006 - Developer Guide
- Added `DEVELOPERS.md` — comprehensive guide for addon authors who want to register their own widgets with BazDrawer
  - Full reference for the DockableWidget contract (id, label, designWidth, designHeight, frame, and optional hooks)
  - Sections on design-width scaling, dynamic height, status text, per-widget settings, dock/undock callbacks, taint-safety rules, and standalone fallback pattern
  - ~100-line Gold Widget reference implementation showing every hook and the full lifecycle from Build to Init

## 005 - Zone Widget, Queue Eye, Custom Button Order, Zygor Compat
### New Widgets
- **Zone** widget — centered zone text in its own dedicated widget. Auto-colored by PVP status (gold neutral, green friendly, red hostile, orange contested, light blue sanctuary). Updates on all `ZONE_CHANGED*` events.

### Minimap Buttons Widget
- **Queue eye adoption** — Blizzard's `QueueStatusButton` (the dungeon/raid/PVP LFG eye) is now captured into the button grid when you queue. It appears dynamically on queue and disappears when you leave, rescaled to match the other button sizes while preserving its glow and click behavior.
- **Fixed slot grid** — refactored from computed SetPoint offsets to pre-built slot frames. Each adopted button is reparented into its slot and anchored to its center, making positioning immune to Blizzard SetPoint clobbering and eliminating a whole class of layout race conditions.
- **Custom button order** — new "Button Order" section on the widget settings page with Move Up / Move Down controls for each adopted button. The order is persisted per-character and honored by the grid layout; new buttons are auto-appended. Friendly names strip the `LibDBIcon10_` prefix and CamelCase-split (e.g. `LibDBIcon10_BazNotificationCenter` → `Baz Notification Center`).
- **Queue eye visibility hooks** — `hooksecurefunc` on `QueueStatusButton:Show/Hide` triggers immediate relayout when Blizzard flips queue state, with a `layoutInProgress` reentry guard to prevent recursion.

### Minimap Info Bar
- **Zone text moved out** — the scrolling zone label has been removed from the Info Bar (it lives in the new Zone widget now). The Info Bar is now a clean right-cluster of Clock + Calendar + Tracking with empty left space reserved for future info buttons.
- **Calendar hover color** — the day-of-month number tints from `#A29580` tan to `#BA9B51` warm gold on mouseover.

### Quest Tracker
- **POI-to-title padding** — `POI_GAP` bumped from 4px to 8px so the super-track icons aren't flush against the quest title text.
- **Objective right-edge padding** — new `OBJ_RIGHT_PAD = 10` constant reserves breathing room between objective text and the drawer's right border. Applied to both objective lines and quest/achievement titles so long wrapped text doesn't hug the edge.

### Third-party Compatibility
- **Zygor Guides Viewer shim** (`Compat.lua`) — pre-hooks `ZGV.NotificationCenter.UpdatePosition` with a nil-guard that defers and retries when `ZygorGuidesViewerMapIcon:GetLeft()` returns nil during Zygor's threaded `NC2 startup` phase. Fixes "attempt to compare number with nil" that happens when BazDrawer reparents the minimap before Zygor's anchor chain has resolved. Installs only when Zygor is loaded; uses `ADDON_LOADED` so load order doesn't matter.

### Assorted polish
- Zone widget padding tightened — auto-sizes to actual font string height instead of the inflated hardcoded minimum.

## 004 - CurseForge Project Metadata
- Added `X-Curse-Project-ID: 1511379` and `X-Website` TOC headers so the BigWigs packager can upload releases to CurseForge automatically

## 003 - Real Drawer Icon
- Switched both the addon settings icon and the minimap button icon to the Suramar Dresser FileDataID (7416769) — an actual in-game drawer model instead of the previous `INV_Misc_Drawer_02` path that didn't resolve to any real texture

## 002 - Icon Fix
- Fixed missing in-game settings icon — TOC now references `Interface\Icons\INV_Misc_Drawer_02` (the same wooden drawer icon used by the minimap button) instead of a bundled PNG path that didn't exist

## 001 - Initial Release
- Slide-out side drawer addon for the Baz Suite
- Full-height side panel with metal pull-tab handle, switchable between left and right edges
- Configurable width with uniform widget scaling
- Smart fade controller — backdrop, border, tab, and chrome fade as a unit while widget content stays at full opacity
- Edge hot zone re-reveals the tab when the drawer is collapsed
- Lock system — padlock icon hides chrome, freezes layout, tightens widget spacing, and disables fade controls
- Per-widget collapse via clickable title bar chevron
- Drag-to-reorder widgets via Move Up / Move Down on each widget's settings page
- Floating mode — detach any widget from the drawer and place it via Edit Mode
- Per-widget settings + global override system via BazCore's CreateGlobalOptionsPage
- Module enable/disable via BazCore's CreateModulesPage

### Built-in Widgets
- **Quest Tracker** — full Blizzard objective tracker replica with Dungeon/Scenario, Campaign, Questlines, Legendary, Callings, Quests, and Achievements sections; collapsible group headers using Blizzard atlases; native POI buttons with super-track integration; item-level pagination; TomTom waypoint integration; option to hide Blizzard's default tracker
- **Repair** — three-column layout (paper doll / damaged-slot list / durability percent) with three paper-doll modes (custom icon grid, native DurabilityFrame, none); robust suppression of Blizzard's auto-popup durability figure
- **Minimap** — reparents the real Blizzard minimap into the drawer at fixed scale
- **Minimap Buttons** — adopts LibDBIcon and other addon-registered minimap buttons into a tidy grid
- **Minimap Info Bar** — zone text + scaled clock + day-of-month calendar proxy + native tracking dropdown in one bar

### Quest Tracker — Dungeon Section
- Decorative stage block using Blizzard's `<textureKit>-trackerheader` atlas
- Graphic orb bullets via `ui-questtracker-objective-nub`, swapped to `ui-questtracker-tracker-check` on completed criteria
- "0/1 Boss Name defeated" format matching the default tracker
- Dynamic section label ("Dungeon" / scenario name / "Proving Grounds") based on scenario type
- Auto-hide when leaving the instance, empty sections never emit a header

### Developer
- BazCore DockableWidget API (`RegisterDockableWidget`, `UnregisterDockableWidget`, `RegisterDockableWidgetCallback`)
- Standard BazCore landing page, settings, modules, global options, widgets, and profiles subcategories
- Comprehensive in-game user manual on the landing page
