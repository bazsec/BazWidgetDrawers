-- BazWidgetDrawers: WidgetHost
--
-- Owns the vertical slot layout inside the drawer's display frame.
-- Listens to BazCore's DockableWidget registry and reflows whenever
-- widgets are added/removed/reordered.
--
-- Slot layout:
--   slot
--     ├── titleBar   (clickable, owns widget.label + optional status text
--     │               + collapse chevron; click toggles collapsed state)
--     └── content    (hosts the widget frame, scaled to fit)
--
-- Scaling model:
--   Each widget declares a native designWidth it was built for. The host
--   computes a uniform scale factor (usableWidth / designWidth) and
--   applies it to the widget frame via SetScale. The title bar is NOT
--   scaled — it owns the full slot width so it stays legible regardless
--   of drawer width.
--
-- Widget contract:
--   widget.id                 unique string
--   widget.label              display label
--   widget.designWidth        native width in pixels (default 200)
--   widget.designHeight       native height in pixels (default 60) — initial hint
--   widget.frame              the actual Frame to parent into a slot's content area
--   widget:GetDesiredHeight() optional — overrides designHeight each reflow
--   widget:GetStatusText()    optional — returns (text, r, g, b) for the title bar
--   widget:OnDock(host)       optional — called when parented
--   widget:OnUndock()         optional — called when removed

local addon = BazCore:GetAddon("BazWidgetDrawers")

local WidgetHost = {}
addon.WidgetHost = WidgetHost

local SLOT_SPACING = 6
local WIDGET_SIDE_INSET = 4           -- breathing room on each side of the widget inside its slot
local TITLE_HEIGHT = 20
local TITLE_CONTENT_GAP = 2
local DEFAULT_DESIGN_WIDTH = 200
local DEFAULT_DESIGN_HEIGHT = 60

---------------------------------------------------------------------------
-- Compute the usable interior width of the host. GetWidth() can return 0
-- on the first reflow before anchors have settled, so fall back to the
-- drawer width minus the display-frame + host insets.
---------------------------------------------------------------------------

local DRAWER_DISPLAY_INSET = 8        -- must match Drawer.lua display anchor inset
local DRAWER_HOST_INSET = 4           -- must match Drawer.lua widget host anchor inset

local function ComputeHostWidth(parent)
    local w = parent and parent:GetWidth() or 0
    if w and w > 0 then return w end
    local drawerWidth = addon:GetSetting("width") or 222
    return drawerWidth - DRAWER_DISPLAY_INSET * 2 - DRAWER_HOST_INSET * 2
end

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------

function WidgetHost:Initialize(parent)
    self.parent = parent
    self.slots = {}  -- { [id] = slotFrame }

    -- Prefer LibBazWidget-1.0 directly when available; fall back to BazCore shim
    local LBW = LibStub and LibStub("LibBazWidget-1.0", true)
    if LBW then
        LBW:RegisterCallback(function() self:Reflow() end)
    elseif BazCore.RegisterDockableWidgetCallback then
        BazCore:RegisterDockableWidgetCallback(function()
            self:Reflow()
        end)
    end

    self:Reflow()
end

---------------------------------------------------------------------------
-- Slot construction
---------------------------------------------------------------------------

function WidgetHost:CreateSlot(widget)
    local slot = CreateFrame("Frame", nil, self.parent)
    slot._widget = widget

    -- Title bar (unscaled, slot-owned). Click anywhere on it to toggle
    -- the widget's collapsed state.
    local title = CreateFrame("Button", nil, slot)
    title:SetHeight(TITLE_HEIGHT)
    title:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
    title:SetPoint("TOPRIGHT", slot, "TOPRIGHT", 0, 0)

    title.bg = title:CreateTexture(nil, "BACKGROUND")
    title.bg:SetAllPoints()
    title.bg:SetColorTexture(0.08, 0.08, 0.12, 0.7)

    -- Slot content background — owned by the slot, drawn beneath the
    -- widget's content area. Widgets no longer draw their own background.
    slot.contentBg = slot:CreateTexture(nil, "BACKGROUND")
    slot.contentBg:SetColorTexture(0.05, 0.05, 0.08, 0.6)

    title.label = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title.label:SetPoint("LEFT", 6, 0)
    title.label:SetText(widget.label or widget.id or "")
    title.label:SetTextColor(1, 0.82, 0)

    title.chevron = title:CreateTexture(nil, "OVERLAY")
    title.chevron:SetSize(16, 16)
    title.chevron:SetPoint("RIGHT", -6, 0)
    title.chevron:SetAtlas("ui-questtrackerbutton-secondary-collapse")

    title.status = title:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title.status:SetPoint("RIGHT", title.chevron, "LEFT", -6, 0)
    title.status:SetJustifyH("RIGHT")
    title.status:SetText("")

    title:SetScript("OnClick", function()
        local collapsed = addon:IsWidgetCollapsed(widget.id)
        addon:SetWidgetCollapsed(widget.id, not collapsed)
        WidgetHost:Reflow()
    end)
    title:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.22, 0.9)
    end)
    title:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.08, 0.08, 0.12, 0.7)
    end)

    slot.titleBar = title

    -- Content area (hosts the widget). Sized by Reflow to fit the
    -- scaled widget height.
    local content = CreateFrame("Frame", nil, slot)
    content:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -TITLE_CONTENT_GAP)
    content:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -TITLE_CONTENT_GAP)
    slot.content = content

    -- Slot background fills the content area
    slot.contentBg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    slot.contentBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    -- Reparent the widget's frame into the slot's content area
    if widget.frame then
        widget.frame:SetParent(content)
        widget.frame:ClearAllPoints()
        widget.frame:Show()
    end

    if widget.OnDock then
        pcall(widget.OnDock, widget, self)
    end

    return slot
end

---------------------------------------------------------------------------
-- Float / Dock transitions
--
-- A widget can live in one of two states:
--   1. Docked   — parented into a slot inside the drawer's widget host
--                 (sized/scaled by Reflow, title bar + collapse, etc.)
--   2. Floating — parented to UIParent with its own saved anchor and
--                 registered with BazCore Edit Mode for drag.
--
-- Transitions are reversible at any time.
---------------------------------------------------------------------------

-- Translate a widget's Ace-style GetOptionsArgs() into BazCore Edit Mode
-- `settings` + `actions` so clicking the floating widget in Edit Mode
-- opens a popup with its configuration. Toggle → checkbox, range → slider,
-- execute → action button. Other types are skipped.
local function BuildEditModeConfig(widget)
    local settings, actions = {}, {}
    if not widget.GetOptionsArgs then return settings, actions end

    local ok, args = pcall(widget.GetOptionsArgs, widget)
    if not ok or type(args) ~= "table" then return settings, actions end

    -- Sort by order so the popup matches the settings page layout
    local sorted = {}
    for key, opt in pairs(args) do
        if type(opt) == "table" then
            table.insert(sorted, { key = key, opt = opt })
        end
    end
    table.sort(sorted, function(a, b)
        return (a.opt.order or 100) < (b.opt.order or 100)
    end)

    -- Always include nudge controls so every floating widget can be
    -- pixel-positioned via the Edit Mode popup
    table.insert(settings, { type = "nudge" })

    for _, entry in ipairs(sorted) do
        local key, opt = entry.key, entry.opt

        if opt.type == "toggle" then
            table.insert(settings, {
                type = "checkbox",
                key = key,
                label = opt.name or key,
                get = opt.get,
                set = function(v) if opt.set then opt.set(nil, v) end end,
            })
        elseif opt.type == "range" then
            table.insert(settings, {
                type = "slider",
                key = key,
                label = opt.name or key,
                min = opt.min or 0,
                max = opt.max or 100,
                step = opt.step or 1,
                format = opt.format,
                get = opt.get,
                set = function(v) if opt.set then opt.set(nil, v) end end,
            })
        elseif opt.type == "execute" then
            table.insert(actions, {
                label = opt.name or key,
                callback = opt.func,
            })
        end
    end

    return settings, actions
end

function WidgetHost:FloatWidget(widget)
    if not widget or not widget.frame then return end
    local id = widget.id

    -- Release any existing slot for this widget
    local slot = self.slots[id]
    if slot then
        slot:Hide()
        self.slots[id] = nil
    end

    local f = widget.frame
    f:SetParent(UIParent)
    f:SetScale(1.0)
    f:SetSize(widget.designWidth or 200, widget.designHeight or 60)
    f:ClearAllPoints()

    local pos = addon:GetWidgetPosition(id)
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    f:Show()

    -- Register with BazCore Edit Mode so the user can drag + configure it.
    -- The popup that opens on click is built from the widget's own
    -- GetOptionsArgs so the settings that appear match what's in the
    -- Widgets subcategory of the options panel.
    if BazCore.RegisterEditModeFrame and not widget._editModeRegistered then
        local settings, actions = BuildEditModeConfig(widget)

        -- Always append an "Open Full Settings" action so the user has a
        -- one-click path to the complete options page.
        table.insert(actions, {
            label = "Open Full Settings",
            callback = function()
                if BazCore.OpenOptionsPanel then
                    BazCore:OpenOptionsPanel("BazWidgetDrawers")
                end
            end,
        })

        BazCore:RegisterEditModeFrame(f, {
            label = widget.label or id,
            addonName = "BazWidgetDrawers",
            positionKey = false,
            onPositionChanged = function()
                local point, _, relPoint, x, y = f:GetPoint()
                if point then
                    addon:SetWidgetPosition(id, {
                        point = point, relPoint = relPoint, x = x, y = y,
                    })
                end
            end,
            settings = settings,
            actions  = actions,
        })
        widget._editModeRegistered = true
    end

    widget._floating = true
end

function WidgetHost:DockWidget(widget)
    if not widget or not widget.frame then return end

    -- Unregister from BazCore Edit Mode
    if widget._editModeRegistered and BazCore.UnregisterEditModeFrame then
        BazCore:UnregisterEditModeFrame(widget.frame)
        widget._editModeRegistered = nil
    end

    widget._floating = nil
    -- The next Reflow will re-create a slot and reparent the frame
    self:Reflow()
end

-- Disable the widget entirely: release its slot, unregister it from
-- Edit Mode, and hide its frame. The widget table stays in the
-- registry so it can be re-enabled later.
function WidgetHost:DisableWidget(widget)
    if not widget or not widget.frame then return end
    local id = widget.id

    local slot = self.slots[id]
    if slot then
        slot:Hide()
        self.slots[id] = nil
    end

    if widget._editModeRegistered and BazCore.UnregisterEditModeFrame then
        BazCore:UnregisterEditModeFrame(widget.frame)
        widget._editModeRegistered = nil
    end

    widget.frame:Hide()
    widget._floating = nil
end

-- Public toggle used by the Modules subcategory
function WidgetHost:SetWidgetEnabled(widgetId, enabled)
    local widget = BazCore.GetDockableWidget and BazCore:GetDockableWidget(widgetId)
    if not widget then return end

    addon:SetWidgetEnabled(widgetId, enabled)

    if enabled then
        -- Restore: let Reflow pick it back up based on its floating state
        if widget.frame then widget.frame:Show() end
        self:Reflow()
    else
        self:DisableWidget(widget)
    end

    -- Let widgets react to their own enable/disable transition. This is
    -- how the Repair widget re-applies DurabilityFrame suppression after
    -- the user toggles it from the Modules page, for example.
    if addon.RepairWidget and widgetId == "bazdrawer_repair"
       and addon.RepairWidget.ApplyVisibility then
        addon.RepairWidget:ApplyVisibility()
    end

    if addon.Drawer and addon.Drawer.EvaluateFade then
        addon.Drawer:EvaluateFade(true)
    end
end

-- Public toggle used by the settings page
function WidgetHost:SetWidgetFloating(widgetId, shouldFloat)
    local widget = BazCore.GetDockableWidget and BazCore:GetDockableWidget(widgetId)
    if not widget then return end

    addon:SetWidgetFloating(widgetId, shouldFloat)

    if shouldFloat then
        self:FloatWidget(widget)
    else
        self:DockWidget(widget)
    end

    -- Re-evaluate fade state since the slot set changed
    if addon.Drawer and addon.Drawer.EvaluateFade then
        addon.Drawer:EvaluateFade(true)
    end
end

---------------------------------------------------------------------------
-- Apply a fade alpha to each slot's title bar and content bg based on
-- the widget's fadeTitleBar / fadeBackground settings (with global
-- overrides resolved by addon:GetWidgetEffectiveSetting). Called by the
-- Drawer's fade controller whenever the chrome target alpha changes.
---------------------------------------------------------------------------

function WidgetHost:ApplyFadeTargets(chromeAlpha, fullAlpha)
    if not self.slots then return end
    for id, slot in pairs(self.slots) do
        local fadeTitle = addon:GetWidgetEffectiveSetting(id, "fadeTitleBar", true) ~= false
        local fadeBg    = addon:GetWidgetEffectiveSetting(id, "fadeBackground", true) ~= false

        if slot.titleBar then
            slot.titleBar:SetAlpha(fadeTitle and chromeAlpha or fullAlpha)
        end
        if slot.contentBg then
            slot.contentBg:SetAlpha(fadeBg and chromeAlpha or fullAlpha)
        end
    end
end

---------------------------------------------------------------------------
-- Refresh the status text on a slot's title bar without a full reflow.
-- Widgets call this after computing new status so the title bar updates
-- live without causing layout churn.
---------------------------------------------------------------------------

function WidgetHost:UpdateWidgetStatus(widgetId)
    local slot = self.slots and self.slots[widgetId]
    if not slot or not slot.titleBar then return end
    local widget = slot._widget
    if widget and widget.GetStatusText then
        local ok, text, r, g, b = pcall(widget.GetStatusText, widget)
        if ok then
            slot.titleBar.status:SetText(text or "")
            if r and g and b then
                slot.titleBar.status:SetTextColor(r, g, b)
            else
                slot.titleBar.status:SetTextColor(0.8, 0.8, 0.8)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Reflow — rebuild the vertical slot stack from the current registry
---------------------------------------------------------------------------

function WidgetHost:Reflow()
    if not self.parent then return end

    -- Locked drawers collapse their widget title-bar space so faded-out
    -- title bars don't leave awkward gaps between widgets. When unlocked
    -- the normal TITLE_HEIGHT is used so the title bars stack like usual.
    local locked = addon:GetSetting("locked") and true or false
    local effectiveTitleH = locked and 0 or TITLE_HEIGHT
    local effectiveGap    = locked and 0 or TITLE_CONTENT_GAP

    local allWidgets = addon.GetSortedWidgets and addon:GetSortedWidgets()
        or (BazCore.GetDockableWidgets and BazCore:GetDockableWidgets())
        or {}

    -- Split: disabled widgets are hidden entirely, floating widgets are
    -- handled by FloatWidget (reparented to UIParent, Edit Mode
    -- registered) and NOT included in the slot stack. Docked + enabled
    -- widgets get normal slot treatment.
    local widgets = {}
    for _, w in ipairs(allWidgets) do
        if not addon:IsWidgetEnabled(w.id) then
            self:DisableWidget(w)
        elseif addon:IsWidgetFloating(w.id) then
            self:FloatWidget(w)
        else
            table.insert(widgets, w)
        end
    end

    -- Hide slots whose widgets are no longer docked (either unregistered
    -- or transitioned to floating).
    local seen = {}
    for _, w in ipairs(widgets) do seen[w.id] = true end
    for id, slot in pairs(self.slots) do
        if not seen[id] then
            slot:Hide()
            local w = slot._widget
            if w and w.OnUndock then pcall(w.OnUndock, w) end
            self.slots[id] = nil
        end
    end

    local hostWidth = ComputeHostWidth(self.parent)
    local usableWidth = math.max(hostWidth - WIDGET_SIDE_INSET * 2, 20)
    local yOffset = 0

    for _, widget in ipairs(widgets) do
        local slot = self.slots[widget.id]
        if not slot then
            slot = self:CreateSlot(widget)
            self.slots[widget.id] = slot
        end

        -- Label can change if widget re-registers; keep it in sync
        slot.titleBar.label:SetText(widget.label or widget.id or "")

        -- Status text + chevron update
        self:UpdateWidgetStatus(widget.id)
        local isCollapsed = addon:IsWidgetCollapsed(widget.id)
        slot.titleBar.chevron:SetAtlas(isCollapsed
            and "ui-questtrackerbutton-secondary-expand"
            or  "ui-questtrackerbutton-secondary-collapse")

        -- Apply the effective title-bar height. When locked, the title
        -- bar collapses to 0 and becomes non-interactive so the widget
        -- content hangs directly below any preceding slot's content.
        slot.titleBar:SetHeight(math.max(effectiveTitleH, 0.001))
        slot.titleBar:SetShown(not locked)
        slot.content:ClearAllPoints()
        slot.content:SetPoint("TOPLEFT",  slot.titleBar, "BOTTOMLEFT",  0, -effectiveGap)
        slot.content:SetPoint("TOPRIGHT", slot.titleBar, "BOTTOMRIGHT", 0, -effectiveGap)

        local designWidth = widget.designWidth or DEFAULT_DESIGN_WIDTH
        local designHeight = widget.designHeight or DEFAULT_DESIGN_HEIGHT
        if widget.GetDesiredHeight then
            local ok, h = pcall(widget.GetDesiredHeight, widget)
            if ok and type(h) == "number" and h > 0 then
                designHeight = h
            end
        end
        local scale = usableWidth / designWidth
        if scale <= 0 then scale = 1 end

        if widget.frame then
            widget.frame:SetSize(designWidth, designHeight)
            widget.frame:SetScale(scale)
            widget.frame:ClearAllPoints()
            widget.frame:SetPoint("TOP", slot.content, "TOP", 0, 0)
        end

        local renderedContentHeight = designHeight * scale

        if isCollapsed then
            slot.content:Hide()
            if slot.contentBg then slot.contentBg:Hide() end
        else
            slot.content:Show()
            slot.content:SetHeight(renderedContentHeight)
            if slot.contentBg then slot.contentBg:Show() end
        end

        local slotHeight = effectiveTitleH
            + (isCollapsed and 0 or (effectiveGap + renderedContentHeight))

        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", self.parent, "TOPLEFT", 0, yOffset)
        slot:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", 0, yOffset)
        slot:SetHeight(slotHeight)
        slot:Show()

        yOffset = yOffset - slotHeight - SLOT_SPACING
    end

    if addon.Drawer and addon.Drawer.SetWidgetCount then
        addon.Drawer:SetWidgetCount(#widgets)
    end
end
