# BazDrawer Changelog

## 013 - Fix UnitFrame Taint Errors
- **Fixed "secret number value tainted by BazDrawer" errors** on UnitFrame health bars, mana bars, and text status bars when targeting enemies or entering combat
  - Root cause: BazDrawer was replacing `ObjectiveTrackerFrame.Show` and `DurabilityFrame.Show` with `Hide` directly, which taints the frame's method table. The taint propagated through `UIParentRightManagedFrameContainer` to PlayerFrame/TargetFrame health and mana bars.
  - Fix: replaced all method overrides (`frame.Show = frame.Hide`) with `hooksecurefunc(frame, "Show", function() if suppressed then self:Hide() end end)`. `hooksecurefunc` appends to the original secure method without replacing it, so no taint is introduced. The suppression behavior is identical — the frame briefly Shows then immediately re-Hides (imperceptible single-frame flicker).
  - `ObjectiveTrackerFrame` suppression (Options.lua) and `DurabilityFrame` suppression (Repair.lua) both converted to the hooksecurefunc pattern.
  - Removed `UIParentRightManagedFrameContainer:RemoveManagedFrame(DurabilityFrame)` call — uses `ignoreFramePositionManager = true` flag instead, which the container checks without tainting its internal state.
  - Removed the pcall wrapper on `UnitFrameHealthBar_Update` from Compat.lua since the taint source is eliminated.

## 012 - Auto-Complete Popup, Bonus Objectives, Whitelist Filter
### Quest Tracker
- **Auto-complete quest popup** — quests with `isAutoComplete` that are ready to turn in now show a decorative popup inside the Quests group with Blizzard's question mark icon, gold ornamental border (all 8 pieces from AutoQuest-Parts tex coords), serif quest name in `QuestFont_Large`, and "Click to complete quest" header. Clicking opens the turn-in dialog via `ShowQuestComplete(questID)`. The question mark icon pulses red via a BOUNCE animation group.
- **Title click for auto-complete** — left-clicking the quest title also calls `ShowQuestComplete` when the quest is auto-completable, matching Blizzard's default tracker behavior
- **Bonus Objectives section** — area task quests (bonus objectives that auto-track when you enter the zone) now appear in a "Bonus Objectives" group at the bottom of the tracker, using `GetTasksTable()` + `GetTaskInfo()` to detect in-area tasks that aren't world quests or already-watched quests
- **`QUEST_AUTOCOMPLETE` event** registered for immediate refresh when a quest becomes auto-completable

### Minimap Buttons Widget
- **Whitelist adoption filter** — switched from blacklist ("adopt everything except Blizzard frames") to whitelist (`LibDBIcon10_*` prefix + known buttons table). Prevents map-pin addons like HandyNotes from flooding the grid with invisible pin frames. Zygor's map icon whitelisted explicitly.

## 011 - Minimap Buttons: Centered Grid, Persistent Eye Capture, Eye-First Sort
### Minimap Buttons Widget
- **Centered button grid** — the grid now computes how many columns are actually occupied and horizontally centers them within the widget instead of left-aligning from the padding edge. Re-centers dynamically when the queue eye appears or disappears.
- **Persistent queue eye capture** — hooked `MicroMenu:Layout` to continuously remove `QueueStatusButton` from Blizzard's layout list after every micro menu re-layout. Previously a one-time removal that Blizzard would undo on instance entry, queue changes, and other events. Also forces reparent + re-anchor on every `LayoutButtons` pass unconditionally instead of relying on a parent-check guard.
- **Queue eye always takes slot 1** — `QueueStatusButton` sorts to the leftmost grid position regardless of the user's custom button order or alphabetical fallback, so the eye is always the first thing you see when it appears.

## 010 - Code Cleanup
- Deleted the old monolithic `Widgets/QuestTracker.lua` (1596 lines) that was left in the repo after the v009 modular refactor
- Removed dead `topHeaderFrame` variable from State.lua and its nil-hide in Init.lua (defined but never created or shown)
- Cleaned stale BazMiniMap supersession comments from Minimap.lua, MinimapInfoBar.lua, and the Settings.lua user manual
- Verified: no TODO/FIXME markers, no dead functions, no unused variables, no stale colon-call references in the modular QuestTracker files

## 009 - Quest Tracker Modular Refactor + M+ Challenge Mode Block
### Modular Refactor
- Split the monolithic `Widgets/QuestTracker.lua` (1596 lines) into 11 focused modules under `Widgets/QuestTracker/`:
  - **Constants.lua** (61) — layout constants, font refs, color helpers
  - **State.lua** (24) — shared mutable state (pools, items list, scroll position)
  - **Collapse.lua** (26) — group collapse state management
  - **Data.lua** (160) — quest, achievement, and classification data polling
  - **Scenario.lua** (99) — dungeon/delve/scenario data from C_Scenario APIs
  - **TomTom.lua** (78) — TomTom waypoint integration
  - **Headers.lua** (72) — section header creation and pool
  - **Blocks.lua** (495) — block creation, population (scenario/quest/achievement rendering), pool management
  - **ChallengeMode.lua** (315) — NEW M+ block (see below)
  - **Options.lua** (101) — settings panel + Blizzard tracker visibility
  - **Init.lua** (352) — Build, Init, Refresh, ApplyLayout, Scroll, event registration
- All modules share state through `addon.QT` — no globals, no circular dependencies, strict TOC load order
- Zero behavioral changes from the refactor itself — the tracker renders identically to v008

### M+ Challenge Mode Block (NEW)
- Dedicated frame for Mythic+ dungeon runs, completely separate from the generic scenario block:
  - **Live countdown timer** — StatusBar driven by `GetWorldElapsedTime()` on a 0.1s OnUpdate tick; color transitions green → yellow → red as time runs out; shows `+MM:SS` overtime in red when depleted
  - **Keystone level** — displays `+N` in gold next to the dungeon name
  - **Affix icons** — up to 4 circular icons from `C_ChallengeMode.GetAffixInfo()` with hover tooltips showing affix name and description; masked to circles matching the minimap button style
  - **Death counter** — graveyard icon + death count from `C_ChallengeMode.GetDeathCount()`; tooltip shows time penalty via `SecondsToClock(timeLost)`
- Activates automatically when `C_ChallengeMode.IsChallengeModeActive()` returns true; scenario criteria (boss kills) render as a collapsible group below the M+ block
- Events: `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED`, `CHALLENGE_MODE_DEATH_COUNT_UPDATED`, `WORLD_STATE_TIMER_START`, `WORLD_STATE_TIMER_STOP`
- Cleans up on key completion via `QT.ResetChallengeMode()`

## 008 - Delve UIWidget Support, Spacing Overhaul
### Delve / Scenario Stage Block
- **UIWidget container** — scenario stage blocks now embed a `UIWidgetContainerTemplate` registered to the step's `widgetSetID` from `C_Scenario.GetStepInfo()`. This renders Blizzard's own Delve-specific widgets (tier badge, death counter, affix icons, map thumbnail) inside the quest tracker, matching the default tracker's Delve stage block. When a `widgetSetID` is present, the decorative atlas + title text are hidden — the widget container replaces them entirely, same pattern as Blizzard's own `ScenarioObjectiveTrackerStageMixin:UpdateWidgetRegistration`.
- **Companion level badge** — reparents Blizzard's `ScenarioObjectiveTracker.BottomWidgetContainerBlock.WidgetContainer` (widget set 252) into the scenario block below the objectives. This is Blizzard's real frame moved into our layout — we don't create a duplicate registration, avoiding the global-singleton conflict that would steal the widget set from Blizzard's tracker. The frame is returned to its original parent on block release.
- **Widget set guard** — tracks `block._registeredWidgetSetID` so `RegisterForWidgetSet` is only called when the widget set ID actually changes, preventing intro/flash animations from replaying on every `Refresh` cycle.
- **OnSizeChanged throttle** — widget container resize events trigger a throttled (0.1s) `ApplyLayout` instead of a full `Refresh`, breaking the infinite teardown→rebuild→resize→OnSizeChanged loop that was causing execution time limit errors and animation replay.
- Falls back to the decorative `<textureKit>-trackerheader` atlas rendering for scenarios without a `widgetSetID` (dungeons, raids, M+, proving grounds).

### Spacing Overhaul
- `GROUP_GAP` increased from 8 to 18 — the vertical gap above each section header is now visually consistent and generous enough to separate tall Delve widget blocks from the section that follows.
- `HEADER_AFTER_GAP` increased from 6 to 8 — the gap below a section header before its first block, slightly more breathing room.
- Spacing is now uniform across all group transitions (Delves → Campaign, Campaign → Quests, Quests → Achievements, etc.).

## 007 - Quest Tracker: Checkmarks, Progress Bars, Quest Item Buttons
### Quest Tracker
- **Green checkmarks on completed objectives** — finished quest and achievement objectives now show a green `ui-questtracker-tracker-check` icon in place of the "- " dash prefix, matching Blizzard's default tracker. The check icon is vertically centered on the first line of text and the objective text renders in the dimmed "Complete" color.
- **Progress bar for percentage-based objectives** — quests with `objectiveType == "progressbar"` (like "Arcana siphoned 88%") now render a proper StatusBar below the objective text, matching the default tracker's blue fill bar. Percentage is sourced from `GetQuestProgressBarPercent(questID)` and displayed as centered text on the bar.
- **Clickable quest item button** — quests that provide a usable special item (wands, torches, quest tools) now show a clickable item icon on the right edge of the quest title row. Uses Blizzard's own `QuestObjectiveItemButtonTemplate` for the icon frame, cooldown sweep, range indicator, and glow animation. Click calls `UseQuestLogSpecialItem(questLogIndex)`. Title text shrinks to avoid overlapping the item icon.
- `GetQuestData` now captures `progressBarPct`, `questLogIndex`, `specialItem`, and `specialItemCharges` alongside the existing title/objectives/classification data
- `CreateBlock` pre-builds a `StatusBar` (progress bar) and a `QuestObjectiveItemButtonTemplate` (item button) per block; both are hidden by default and shown/hidden per-quest in `PopulateBlock`
- `ReleaseBlock` cleans up both new elements when blocks return to the pool

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
