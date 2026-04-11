# BazDrawer Changelog

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
