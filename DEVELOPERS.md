# BazDrawer — Developer Guide

> How to add a widget from your addon to BazDrawer's slot stack.

BazDrawer hosts a vertical stack of **dockable widgets** inside its slide-out side panel. Any addon in the Baz Suite (or any third-party addon you write) can register its own widget through **BazCore's `DockableWidget` API**, and that widget will appear inside BazDrawer automatically — complete with a title bar, drag-to-reorder, floating mode, per-widget settings, and global overrides — without any further wiring.

This guide covers everything you need to know to ship your own BazDrawer-compatible widget.

---

## Table of Contents

1. [Hello World](#hello-world)
2. [The Widget Contract](#the-widget-contract)
3. [Required Fields](#required-fields)
4. [Optional Hooks](#optional-hooks)
5. [Design Width and Scaling](#design-width-and-scaling)
6. [Dynamic Height](#dynamic-height)
7. [Status Text](#status-text)
8. [Per-Widget Settings](#per-widget-settings)
9. [Dock / Undock Callbacks](#dock--undock-callbacks)
10. [Dependencies and Safety Rules](#dependencies-and-safety-rules)
11. [Standalone Fallback](#standalone-fallback)
12. [Full Reference Example](#full-reference-example)

---

## Hello World

The smallest possible widget — a frame with a single line of text:

```lua
local addon = BazCore:GetAddon("MyAddon")
if not addon then return end

local MyWidget = {}

local frame = CreateFrame("Frame", "MyAddonHelloWidget", UIParent)
frame:SetSize(200, 40)

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER")
text:SetText("Hello from MyAddon!")

BazCore:QueueForLogin(function()
    BazCore:RegisterDockableWidget({
        id           = "myaddon_hello",
        label        = "Hello",
        designWidth  = 200,
        designHeight = 40,
        frame        = frame,
    })
end)
```

That's it. After `/reload`, your widget shows up in BazDrawer's slot stack with a "Hello" title bar. The user can:

- Collapse / expand it via the chevron
- Move it up or down in the stack
- Float it into its own draggable frame via Edit Mode
- Disable it in the Modules subcategory

---

## The Widget Contract

A widget is just a plain Lua table you pass to `BazCore:RegisterDockableWidget()`. BazDrawer reads specific keys from that table to drive layout and behavior.

```lua
BazCore:RegisterDockableWidget({
    --- Required ---
    id           = "myaddon_mywidget",  -- unique string
    label        = "My Widget",         -- display name
    designWidth  = 220,                 -- native width in pixels
    designHeight = 60,                  -- initial height hint
    frame        = myFrame,             -- the Frame to dock

    --- Optional ---
    GetDesiredHeight = function() return ... end,
    GetStatusText    = function() return text, r, g, b end,
    GetOptionsArgs   = function() return { ... } end,
    OnDock           = function(host) ... end,
    OnUndock         = function() ... end,
})
```

Everything after the required fields is opt-in — a bare-minimum widget only needs `id`, `label`, `designWidth`, `designHeight`, and `frame`.

---

## Required Fields

### `id` — Unique Identifier

A string that identifies your widget globally. Used as the key in BazDrawer's saved variables for collapse state, floating position, per-widget settings, and custom order. **Must be unique across all registered widgets.**

Convention: `<addonslug>_<widgetname>`, all lowercase, no spaces. Examples:

```
bazdrawer_repair
bazdrawer_questtracker
myaddon_mailtracker
myaddon_currencybar
```

Never use a bare generic name like `"widget"` — you'll collide with some other addon.

### `label` — Display Name

The string shown on the widget's title bar when docked in the drawer, and as the widget's entry name in BazDrawer → Modules and BazDrawer → Widgets. Should be human-readable and capitalized normally ("Quest Tracker", not "questtracker").

### `designWidth` — Native Width

Your widget's **design-space width** in pixels. This is the width your widget was built for at 1.0 scale.

BazDrawer computes a uniform scale factor as `drawerWidth / designWidth` and applies it to your frame via `SetScale`. So a widget with `designWidth = 220` docked inside a 180px-wide drawer renders at scale `180/220 ≈ 0.82`. If the user resizes the drawer wider, every widget scales up together.

**Pick a design width that matches your content's natural layout.** For dense informational widgets (quest trackers, stat bars), 220–260 is typical. For simple one-line widgets, 160–200 works well.

### `designHeight` — Initial Height Hint

Your widget's starting height in design pixels. BazDrawer uses this to compute the slot size on the first reflow before `GetDesiredHeight` has been called.

For fixed-size widgets this is also the final height. For dynamic-height widgets (lists, trackers) this is the height shown before any data is loaded; once you return a real value from `GetDesiredHeight`, BazDrawer reflows to match.

### `frame` — The Frame to Dock

The actual `Frame` (or `Button`, or any derived type) that will be parented into a drawer slot. This should be a frame you've already created via `CreateFrame("Frame", ...)` — BazDrawer does **not** create frames for you, it just parents yours.

Requirements:

- Must be parented to `UIParent` at creation time (BazDrawer will reparent it on dock)
- Must have its initial size set via `SetSize(designWidth, designHeight)`
- Must **not** be a `SecureActionButtonTemplate` or any other protected frame — see [Safety Rules](#dependencies-and-safety-rules)

---

## Optional Hooks

### `GetDesiredHeight() → number`

Called by the widget host on each reflow pass. Return the height (in design pixels) that your widget currently wants to occupy. Typical uses:

- A list widget that grows as rows are added
- A tracker that shrinks when sections collapse
- A repair widget that expands only when gear is damaged

```lua
function MyWidget:GetDesiredHeight()
    return self._contentHeight or designHeight
end
```

If your widget's desired height changes, call `addon.WidgetHost:Reflow()` (via the BazDrawer registry) to trigger a re-layout:

```lua
local bd = BazCore:GetAddon("BazDrawer")
if bd and bd.WidgetHost then bd.WidgetHost:Reflow() end
```

### `GetStatusText() → text, r, g, b`

Returns a short live status string to display on the right side of your widget's title bar, plus an optional color. Typical uses:

- Durability percentage (Repair widget)
- Quest count (Quest Tracker)
- Mail unread count
- Zone / subzone name

```lua
function MyWidget:GetStatusText()
    local avg = self._avgPct or 1.0
    local r, g, b = ColorForPct(avg)
    return string.format("%d%%", avg * 100), r, g, b
end
```

To push a fresh status text to the title bar without a full reflow, call:

```lua
local bd = BazCore:GetAddon("BazDrawer")
if bd and bd.WidgetHost and bd.WidgetHost.UpdateWidgetStatus then
    bd.WidgetHost:UpdateWidgetStatus("myaddon_mywidget")
end
```

### `GetOptionsArgs() → table`

Returns a BazCore options-table fragment that gets rendered on your widget's settings page under **BazDrawer → Widgets → [Your Widget]**. Uses the same widget types as any BazCore options panel: `header`, `description`, `toggle`, `range`, `select`, `execute`, `input`.

```lua
function MyWidget:GetOptionsArgs()
    return {
        appearanceHeader = {
            order = 10,
            type = "header",
            name = "Appearance",
        },
        showIcon = {
            order = 11,
            type = "toggle",
            name = "Show Icon",
            desc = "Display the addon icon in the widget.",
            get = function() return addon:GetSetting("showIcon") end,
            set = function(_, val)
                addon:SetSetting("showIcon", val)
                MyWidget:Refresh()
            end,
        },
    }
end
```

For per-widget settings that should be persisted in BazDrawer's per-widget settings store (not your own addon's DB), use:

```lua
local bd = BazCore:GetAddon("BazDrawer")
bd:GetWidgetSetting("myaddon_mywidget", "showIcon", defaultValue)
bd:SetWidgetSetting("myaddon_mywidget", "showIcon", newValue)
```

This lets your settings live inside the BazDrawer profile system automatically.

### `OnDock(host)` and `OnUndock()`

Called when your widget is parented into a drawer slot (`OnDock`) or removed from one (`OnUndock`). Use these to defer expensive setup until the widget is actually visible in the drawer, or to pause event handlers when the widget is hidden.

```lua
function MyWidget:OnDock(host)
    self:RegisterEvents()
    self:Refresh()
end

function MyWidget:OnUndock()
    self:UnregisterEvents()
end
```

Most widgets don't need these — they're a performance optimization for widgets with heavy update loops.

---

## Design Width and Scaling

**Key insight:** every docked widget gets uniformly scaled by the widget host to fit the drawer width. You don't manage this yourself.

If your widget's `designWidth = 220` and the drawer is 176px wide internally, the host calls `frame:SetScale(176 / 220)` = `0.8`. Every pixel you draw on the frame gets scaled by 0.8 together — icons, text, backgrounds, borders. You design at 1.0 and let the host handle resizing.

**What this means in practice:**

- Lay out your frame at your chosen `designWidth` with real pixel values
- Don't hard-code offsets that assume a specific final screen width
- Test at different drawer widths (120–400) by dragging the width slider in BazDrawer → Settings → Layout
- Title bars are **not** scaled — they always use the full slot width at 1.0 so labels stay legible

---

## Dynamic Height

For widgets whose height changes at runtime, the flow is:

1. Your widget's content state changes (data loaded, row added, section collapsed)
2. You compute the new height
3. You store it somewhere (`self._desiredHeight`)
4. You call `addon.WidgetHost:Reflow()` to trigger a re-layout
5. The widget host calls your `GetDesiredHeight()` which returns the new value
6. The slot stack reflows with the new height

Example skeleton:

```lua
function MyWidget:UpdateContent()
    -- ... update your frame's content ...

    local newHeight = self:ComputeHeight()
    if newHeight ~= self._desiredHeight then
        self._desiredHeight = newHeight
        self.frame:SetHeight(newHeight)
        local bd = BazCore:GetAddon("BazDrawer")
        if bd and bd.WidgetHost then bd.WidgetHost:Reflow() end
    end
end

function MyWidget:GetDesiredHeight()
    return self._desiredHeight or designHeight
end
```

---

## Status Text

The title bar's status text is on the **right** side, matching Blizzard's style. It's rendered at a fixed font (the same font used for the widget label) and can be colored via RGB.

**Tips:**

- Keep it short — 1-4 characters is ideal ("99%", "12", "MAIL", "●")
- Use color to convey state at a glance (green = OK, red = warning)
- Update it frequently via `WidgetHost:UpdateWidgetStatus(id)` so it stays live
- Return `""` if there's nothing to display — title bar just shows the label

---

## Per-Widget Settings

Settings that belong to one specific widget instance (collapsed state, chosen mode, custom options) should live in **BazDrawer's per-widget settings store**, not your own addon's DB. This gives you:

- Automatic profile support via BazCore's profile system
- Global override support via BazDrawer → Global Options
- Clean separation between addon-level and widget-level configuration

**API:**

```lua
local bd = BazCore:GetAddon("BazDrawer")

-- Read with a default fallback
local mode = bd:GetWidgetSetting("myaddon_mywidget", "mode", "default")

-- Write
bd:SetWidgetSetting("myaddon_mywidget", "mode", "advanced")

-- Effective value (checks global override first, falls back to local)
local fade = bd:GetWidgetEffectiveSetting("myaddon_mywidget", "fadeTitleBar", true)
```

Use `GetWidgetEffectiveSetting` for settings that have a global override (like "Fade Title Bar" which can be set at the global level and cascaded). Use `GetWidgetSetting` for settings that are strictly per-widget (like a collapse state).

---

## Dock / Undock Callbacks

`OnDock(host)` fires whenever the host takes ownership of your frame:

- On first registration after login
- On re-enable after being disabled in Modules
- On un-floating (dropping a floating widget back into the drawer)

`OnUndock()` fires whenever the host releases your frame:

- On disable in Modules
- On switch to floating mode
- When your addon calls `BazCore:UnregisterDockableWidget()`

Both are optional. The typical use case is delayed initialization: a heavy widget can skip most of its setup until `OnDock` fires, keeping the login flow fast.

---

## Dependencies and Safety Rules

### Required dependencies in your TOC

```
## Dependencies: BazCore
## OptionalDeps: BazDrawer
```

**BazCore is a hard dependency** — you need it loaded to call `BazCore:RegisterDockableWidget`. **BazDrawer is an optional dependency** — your widget should still work (or gracefully no-op) when BazDrawer isn't installed. See [Standalone Fallback](#standalone-fallback).

### Taint-safe rules

BazDrawer's widgets run in the **non-protected** Lua environment. This imposes a few hard rules:

1. **Never register a `SecureActionButtonTemplate` or any protected frame as your widget frame.** Blizzard's secure execution path will taint when the host reparents it, and downstream Blizzard code (Edit Mode, Scroll frames, Combat Log) will error.
2. **Never hook protected methods on your widget frame** via `hooksecurefunc` on things like `CastSpellByID`, `UseAction`, or secure unit functions.
3. **Poll game state read-only** — `C_QuestLog.*`, `GetInventoryItemDurability`, `GetMoney`, `GetZoneText` are all fine. Avoid calling anything under `C_PetBattles` or other protected namespaces from an in-drawer context.
4. **Don't reparent other addons' frames** into your widget without first checking whether those frames are secure. A taint from reparenting spreads through the frame hierarchy fast.

### If you need a secure button in your widget

Create a **non-secure wrapper frame** as your widget's root, and place your `SecureActionButtonTemplate` as a **child of that wrapper**. The wrapper is what gets registered as the widget; the secure button rides along inside. Blizzard's secure environment traces protected calls through parent-child chains by checking only the innermost protected frame, so a secure button nested inside a non-secure parent is taint-safe as long as the parent isn't itself protected.

---

## Standalone Fallback

Your addon should work **whether or not BazDrawer is installed.** Here's the pattern:

```lua
local addon = BazCore:GetAddon("MyAddon")
if not addon then return end

local function CreateFrame()
    -- Create your widget frame, set it up, etc.
    -- ...
    return myFrame
end

BazCore:QueueForLogin(function()
    local frame = CreateFrame()

    if BazCore.RegisterDockableWidget then
        -- BazCore is new enough to expose the DockableWidget API —
        -- register, and BazDrawer will adopt us if it's installed.
        BazCore:RegisterDockableWidget({
            id           = "myaddon_mywidget",
            label        = "My Widget",
            designWidth  = 200,
            designHeight = 50,
            frame        = frame,
            -- ... other hooks ...
        })
    end

    -- Fallback: if BazDrawer isn't installed, the widget still needs
    -- somewhere to live. Register it as a standalone Edit Mode frame
    -- so the user can position it anywhere on screen.
    local bd = BazCore:GetAddon("BazDrawer")
    if not bd then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:Show()
        if BazCore.RegisterEditModeFrame then
            BazCore:RegisterEditModeFrame(frame, {
                label = "My Widget",
                addonName = "MyAddon",
                positionKey = "position",
                defaultPosition = { x = 0, y = 0 },
            })
        end
    end
end)
```

When BazDrawer **is** installed, it picks up your widget via the registry and parents it into the drawer. Your standalone Edit Mode registration is unused because BazDrawer's widget host takes over the frame's parent.

When BazDrawer **isn't** installed, the registry still exists (it lives in BazCore) but nothing consumes it, so your widget falls back to the standalone path.

---

## Full Reference Example

A complete, production-ready widget that shows the player's gold, updates on `PLAYER_MONEY`, exposes a color toggle in settings, and has a status text showing the copper remainder:

```lua
-- MyAddon/Widgets/GoldWidget.lua

local addon = BazCore:GetAddon("MyAddon")
if not addon then return end

local WIDGET_ID     = "myaddon_gold"
local DESIGN_WIDTH  = 180
local DESIGN_HEIGHT = 36
local PAD           = 6

local GoldWidget = {}
addon.GoldWidget = GoldWidget

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function FormatGold(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    return string.format("%s|cffffd700g|r %s|cffc0c0c0s|r", g, s)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

function GoldWidget:Refresh()
    local f = self.frame; if not f then return end
    local copper = GetMoney() or 0
    f.text:SetText(FormatGold(copper))

    self._copper = copper

    local bd = BazCore:GetAddon("BazDrawer")
    if bd and bd.WidgetHost and bd.WidgetHost.UpdateWidgetStatus then
        bd.WidgetHost:UpdateWidgetStatus(WIDGET_ID)
    end
end

---------------------------------------------------------------------------
-- Widget interface
---------------------------------------------------------------------------

function GoldWidget:GetDesiredHeight()
    return DESIGN_HEIGHT
end

function GoldWidget:GetStatusText()
    local copper = (self._copper or 0) % 100
    return string.format("%dc", copper), 0.8, 0.5, 0.2
end

function GoldWidget:GetOptionsArgs()
    local bd = BazCore:GetAddon("BazDrawer")
    return {
        displayHeader = {
            order = 10,
            type = "header",
            name = "Display",
        },
        showCopper = {
            order = 11,
            type = "toggle",
            name = "Show Copper",
            desc = "Include the copper component in the main display.",
            get = function()
                return bd:GetWidgetSetting(WIDGET_ID, "showCopper", true)
            end,
            set = function(_, val)
                bd:SetWidgetSetting(WIDGET_ID, "showCopper", val)
                GoldWidget:Refresh()
            end,
        },
    }
end

---------------------------------------------------------------------------
-- Build + Init
---------------------------------------------------------------------------

function GoldWidget:Build()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "MyAddonGoldWidget", UIParent)
    f:SetSize(DESIGN_WIDTH, DESIGN_HEIGHT)

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("CENTER")

    self.frame = f
    return f
end

function GoldWidget:Init()
    local f = self:Build()

    if BazCore.RegisterDockableWidget then
        BazCore:RegisterDockableWidget({
            id               = WIDGET_ID,
            label            = "Gold",
            designWidth      = DESIGN_WIDTH,
            designHeight     = DESIGN_HEIGHT,
            frame            = f,
            GetDesiredHeight = function() return GoldWidget:GetDesiredHeight() end,
            GetStatusText    = function() return GoldWidget:GetStatusText() end,
            GetOptionsArgs   = function() return GoldWidget:GetOptionsArgs() end,
        })
    end

    -- Event-driven refresh
    f:RegisterEvent("PLAYER_MONEY")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:HookScript("OnEvent", function() GoldWidget:Refresh() end)

    self:Refresh()
end

BazCore:QueueForLogin(function() GoldWidget:Init() end)
```

This widget is ~100 lines of Lua and gives you:

- A gold display that updates on every money change
- A live status text showing current copper
- A toggle in BazDrawer's widget settings page
- Automatic scaling to the drawer width
- Move Up / Down reordering
- Collapse / expand via title bar chevron
- Float mode via Edit Mode
- Enable / disable via Modules
- Profile support

…all for free, just by returning a handful of fields from `GetOptionsArgs` and implementing three short methods.

---

## Questions?

BazDrawer is part of the [Baz Suite](https://www.curseforge.com/members/baz4k/projects) of addons. The source for every widget that ships with BazDrawer is in `Widgets/` — read those files as reference implementations for patterns like event hookup, frame reparenting, and options integration. Good starting points:

- **`Widgets/Repair.lua`** — simplest widget with a status text and a single select option
- **`Widgets/MinimapButtons.lua`** — shows slot grids, custom ordering, and adopting third-party frames
- **`Widgets/QuestTracker.lua`** — full-featured widget with pagination, events, and complex options

If you hit a taint error or layout bug, file an issue against BazDrawer on GitHub with a minimal repro and we'll take a look.
