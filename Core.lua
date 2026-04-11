-- BazDrawer Core
-- Addon lifecycle via BazCore framework
--
-- BazDrawer is a slide-out side panel host that other Baz Suite addons
-- can dock widgets into. The visual style mirrors Blizzard's Compact
-- Raid Frame Manager so it feels like a native game UI element.

local ADDON_NAME = "BazDrawer"

local addon
addon = BazCore:RegisterAddon(ADDON_NAME, {
    title = "BazDrawer",
    savedVariable = "BazDrawerDB",
    profiles = true,
    defaults = {
        collapsed = false,
        side = "right",
        width = 222,
        widgetCollapsed = {},         -- [widgetId] = true when the widget's content is hidden
        widgetOrder = {},             -- [widgetId] = numeric order index (lower = higher in the stack)
        widgetSettings = {},          -- [widgetId] = { [key] = value } for widget-specific options
        widgetGlobalOverrides = {},   -- [key] = { enabled = bool, value = <any> } (BazCore global page)
        widgetFloating = {},          -- [widgetId] = true when detached from the drawer into free Edit Mode
        widgetPositions = {},         -- [widgetId] = { point, relPoint, x, y } for floating widgets
        widgetEnabled = {},           -- [widgetId] = false to disable the widget entirely (default true)

        -- Appearance
        backgroundOpacity = 0.9,   -- alpha of the drawer's backdrop fill
        frameOpacity      = 1.0,   -- max alpha of the drawer frame (base for fade)

        -- Fading
        fadeEnabled         = true,
        fadedOpacity        = 0.3,   -- target alpha when faded out
        fadeDelay           = 1.0,   -- seconds to wait after mouse leaves before starting fade
        fadeDuration        = 0.3,   -- fade animation duration in seconds
        edgeRevealPx        = 8,     -- cursor proximity to active screen edge to reveal tab
        fadeTabWhenClosed   = true,  -- whether the tab fades too when drawer is collapsed
        disableFadeInCombat = false, -- force full opacity while in combat

        -- Lock: when true, the drawer ignores user interactions that
        -- would collapse/expand it (toggle button click and edge-hover
        -- auto-reveal). Widgets inside are unaffected.
        locked = false,
    },

    slash = { "/bdrawer", "/bd" },
    commands = {
        toggle = {
            desc = "Toggle the drawer open/closed",
            handler = function()
                if addon.Drawer then addon.Drawer:Toggle() end
            end,
        },
        show = {
            desc = "Open the drawer",
            handler = function()
                if addon.Drawer then addon.Drawer:Expand() end
            end,
        },
        hide = {
            desc = "Close the drawer",
            handler = function()
                if addon.Drawer then addon.Drawer:Collapse() end
            end,
        },
    },

    minimap = {
        label = "BazDrawer",
        icon = "Interface\\Icons\\INV_Misc_Drawer_02",
    },

    onReady = function(self)
        self:SetupDrawer()
    end,
})

function addon:SetupDrawer()
    if not self.Drawer then return end
    self.Drawer:Build()

    -- Restore saved collapsed state
    local saved = self:GetSetting("collapsed")
    if saved then
        self.Drawer:Collapse()
    else
        self.Drawer:Expand()
    end
end

---------------------------------------------------------------------------
-- Widget collapsed state (per-widget, persisted)
---------------------------------------------------------------------------

function addon:IsWidgetCollapsed(id)
    local map = self:GetSetting("widgetCollapsed")
    return (map and map[id]) and true or false
end

function addon:SetWidgetCollapsed(id, val)
    local map = self:GetSetting("widgetCollapsed") or {}
    map[id] = val and true or nil
    self:SetSetting("widgetCollapsed", map)
end

---------------------------------------------------------------------------
-- Widget ordering (per-widget, persisted)
--
-- The drawer's WidgetHost sorts widgets by their stored order index.
-- Widgets without a stored order fall to the bottom in their natural
-- registration order.
---------------------------------------------------------------------------

function addon:GetWidgetOrder(id)
    local map = self:GetSetting("widgetOrder")
    return map and map[id]
end

function addon:SetWidgetOrder(id, n)
    local map = self:GetSetting("widgetOrder") or {}
    map[id] = n
    self:SetSetting("widgetOrder", map)
end

-- Returns an array of widget tables sorted by the user's saved order.
function addon:GetSortedWidgets()
    local widgets = BazCore.GetDockableWidgets and BazCore:GetDockableWidgets() or {}
    local copy = {}
    for i, w in ipairs(widgets) do
        copy[i] = w
    end
    table.sort(copy, function(a, b)
        local oa = addon:GetWidgetOrder(a.id) or 10000
        local ob = addon:GetWidgetOrder(b.id) or 10000
        if oa == ob then return (a.id or "") < (b.id or "") end
        return oa < ob
    end)
    return copy
end

-- Swap `id` with its neighbor in the sorted list and persist the new order.
local function ApplyReorder(sorted)
    for i, w in ipairs(sorted) do
        addon:SetWidgetOrder(w.id, i)
    end
    if addon.WidgetHost and addon.WidgetHost.Reflow then
        addon.WidgetHost:Reflow()
    end
end

function addon:MoveWidgetUp(id)
    local sorted = self:GetSortedWidgets()
    for i, w in ipairs(sorted) do
        if w.id == id and i > 1 then
            sorted[i], sorted[i - 1] = sorted[i - 1], sorted[i]
            ApplyReorder(sorted)
            return
        end
    end
end

function addon:MoveWidgetDown(id)
    local sorted = self:GetSortedWidgets()
    for i, w in ipairs(sorted) do
        if w.id == id and i < #sorted then
            sorted[i], sorted[i + 1] = sorted[i + 1], sorted[i]
            ApplyReorder(sorted)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Generic per-widget settings store. Widgets that need their own
-- persistent options read/write through here instead of maintaining
-- their own SavedVariables, so everything lives in BazDrawer's profile.
---------------------------------------------------------------------------

function addon:GetWidgetSetting(widgetId, key, default)
    local map = self:GetSetting("widgetSettings")
    if map and map[widgetId] and map[widgetId][key] ~= nil then
        return map[widgetId][key]
    end
    return default
end

function addon:SetWidgetSetting(widgetId, key, val)
    local map = self:GetSetting("widgetSettings") or {}
    map[widgetId] = map[widgetId] or {}
    map[widgetId][key] = val
    self:SetSetting("widgetSettings", map)
end

---------------------------------------------------------------------------
-- Global widget overrides (BazCore-style)
--
-- A global override for a given key replaces the per-widget setting of
-- that key across ALL widgets. Stored as:
--   widgetGlobalOverrides[key] = { enabled = bool, value = <any> }
--
-- GetWidgetEffectiveSetting resolves the precedence chain:
--   global override (if enabled) → per-widget setting → default
---------------------------------------------------------------------------

function addon:GetGlobalOverrides()
    local map = self:GetSetting("widgetGlobalOverrides")
    if not map then
        map = {}
        self:SetSetting("widgetGlobalOverrides", map)
    end
    return map
end

function addon:SetGlobalOverride(key, field, value)
    local map = self:GetGlobalOverrides()
    map[key] = map[key] or {}
    map[key][field] = value
    self:SetSetting("widgetGlobalOverrides", map)
    if addon.WidgetHost and addon.WidgetHost.Reflow then
        addon.WidgetHost:Reflow()
    end
    if addon.Drawer and addon.Drawer.EvaluateFade then
        addon.Drawer:EvaluateFade(true)
    end
end

function addon:GetWidgetEffectiveSetting(widgetId, key, default)
    local overrides = self:GetSetting("widgetGlobalOverrides")
    if overrides and overrides[key] and overrides[key].enabled then
        if overrides[key].value ~= nil then
            return overrides[key].value
        end
    end
    return self:GetWidgetSetting(widgetId, key, default)
end

---------------------------------------------------------------------------
-- Floating widget state (per-widget, persisted)
--
-- A widget is either DOCKED (parented into a slot inside the drawer and
-- sized by the widget host) or FLOATING (reparented to UIParent with its
-- own saved anchor and registered with BazCore Edit Mode for drag).
---------------------------------------------------------------------------

function addon:IsWidgetFloating(id)
    local map = self:GetSetting("widgetFloating")
    return (map and map[id]) and true or false
end

function addon:SetWidgetFloating(id, val)
    local map = self:GetSetting("widgetFloating") or {}
    map[id] = val and true or nil
    self:SetSetting("widgetFloating", map)
end

function addon:GetWidgetPosition(id)
    local map = self:GetSetting("widgetPositions")
    return map and map[id]
end

function addon:SetWidgetPosition(id, pos)
    local map = self:GetSetting("widgetPositions") or {}
    map[id] = pos
    self:SetSetting("widgetPositions", map)
end

---------------------------------------------------------------------------
-- Widget enabled state (per-widget, persisted; default enabled)
--
-- A disabled widget is hidden entirely — not in the drawer slot stack,
-- not floating, just parked off-screen with its frame hidden. Re-enabling
-- restores the previous dock/float state.
---------------------------------------------------------------------------

function addon:IsWidgetEnabled(id)
    local map = self:GetSetting("widgetEnabled")
    if not map then return true end
    if map[id] == nil then return true end
    return map[id] and true or false
end

function addon:SetWidgetEnabled(id, val)
    local map = self:GetSetting("widgetEnabled") or {}
    if val == false then
        map[id] = false
    else
        map[id] = nil  -- nil = default enabled, keeps SV small
    end
    self:SetSetting("widgetEnabled", map)
end
