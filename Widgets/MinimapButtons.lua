-- BazDrawer Widget: MinimapButtons
--
-- Scans the Minimap for LibDBIcon-registered addon buttons and reparents
-- them into a grid inside the drawer. Most addon minimap buttons are
-- LibDBIcon ones with a consistent naming pattern (LibDBIcon10_<Name>),
-- so we use that as the adoption filter to avoid disturbing Blizzard's
-- own minimap chrome (mail, tracking, zone text, etc).
--
-- Buttons are adopted once at login (after a short delay so other addons
-- finish registering their LibDBIcon icons) and again on demand via the
-- widget's "Re-scan" option. Original parent + anchor are saved so we
-- can release buttons back to the minimap on unload if ever needed.

local addon = BazCore:GetAddon("BazDrawer")
if not addon then return end

local WIDGET_ID    = "bazdrawer_minimapbuttons"
local DESIGN_WIDTH = 220
local PAD          = 8
local BUTTON_SIZE  = 28
local BUTTON_GAP   = 4
local MIN_HEIGHT   = PAD * 2 + BUTTON_SIZE

-- Slot grid: the widget pre-builds this many empty slot frames. Each
-- adopted button gets reparented into a slot, which pins its CENTER to
-- the slot's CENTER so positioning is immune to SetPoint clobbering.
-- Empty slots are hidden; visible buttons fill slots in order. Future
-- custom-ordering can map button name → slot index via a persisted
-- table without changing any of the rendering code.
local MAX_SLOTS    = 12

-- Queue eye (dungeon/raid/PVP LFG button). Lives in MicroMenuContainer,
-- not Minimap, so it needs special handling outside the normal scanner.
-- It's also dynamically shown/hidden by Blizzard based on queue state —
-- LayoutButtons already filters by IsShown() so we just need to re-run
-- the layout on queue events.
local QUEUE_EYE_EVENTS = {
    "LFG_UPDATE",
    "LFG_PROPOSAL_SHOW",
    "LFG_PROPOSAL_FAILED",
    "LFG_PROPOSAL_SUCCEEDED",
    "LFG_LIST_APPLICATION_STATUS_UPDATED",
    "LFG_ROLE_CHECK_SHOW",
    "LFG_ROLE_CHECK_HIDE",
    "PVP_QUEUE_STATUS_UPDATE",
    "UPDATE_BATTLEFIELD_STATUS",
    "PVEFRAME_SHOW",
    "PLAYER_ENTERING_WORLD",
}

---------------------------------------------------------------------------
-- Adoption filter: any named Button child of Minimap. In Midnight, all
-- Blizzard minimap chrome (zoom, tracking, zone text, etc.) lives under
-- MinimapCluster — direct children of Minimap are effectively just addon
-- buttons: LibDBIcon ones (LibDBIcon10_*), custom ones like
-- BazCoreMinimapButton, HandyNotes, Rematch, etc. A blacklist of known
-- Blizzard names keeps us safe if any slip through.
---------------------------------------------------------------------------

local BLIZZARD_NAME_BLACKLIST = {
    ["MinimapBackdrop"]         = true,
    ["MinimapZoomIn"]           = true,
    ["MinimapZoomOut"]          = true,
    ["MiniMapTrackingButton"]   = true,
    ["MiniMapMailFrame"]        = true,
    ["MiniMapBattlefieldFrame"] = true,
    ["MinimapCompassTexture"]   = true,
    ["MinimapCluster"]          = true,
}

local function IsAdoptable(frame)
    if not frame or not frame.IsObjectType or not frame:IsObjectType("Button") then
        return false
    end
    if frame:GetParent() ~= Minimap then return false end
    local name = frame:GetName()
    if not name or name == "" then return false end
    if BLIZZARD_NAME_BLACKLIST[name] then return false end
    return true
end

---------------------------------------------------------------------------
-- Widget
---------------------------------------------------------------------------

local MinimapButtonsWidget = {}
addon.MinimapButtonsWidget = MinimapButtonsWidget

---------------------------------------------------------------------------
-- Custom button order.
--
-- The per-widget setting `buttonOrder` is a list of button names in
-- display order. Buttons not listed appear after the listed ones in
-- alphabetical order. New buttons are appended to the list on first
-- adoption so the order is complete by default; the user can then
-- rearrange via Move Up / Move Down controls on the widget's settings
-- page. The sort in LayoutButtons uses this order first, then
-- alphabetical for any unlisted button.
---------------------------------------------------------------------------

local function GetButtonOrder()
    return addon:GetWidgetSetting(WIDGET_ID, "buttonOrder", nil) or {}
end

local function SetButtonOrder(list)
    addon:SetWidgetSetting(WIDGET_ID, "buttonOrder", list)
end

local function EnsureButtonInOrder(name)
    if not name or name == "" then return end
    local order = GetButtonOrder()
    for _, n in ipairs(order) do
        if n == name then return end
    end
    table.insert(order, name)
    SetButtonOrder(order)
end

local function MoveButtonInOrder(name, delta)
    local order = GetButtonOrder()
    local idx
    for i, n in ipairs(order) do
        if n == name then idx = i; break end
    end
    if not idx then return end
    local newIdx = idx + delta
    if newIdx < 1 or newIdx > #order then return end
    order[idx], order[newIdx] = order[newIdx], order[idx]
    SetButtonOrder(order)
end

function MinimapButtonsWidget:MoveButtonUp(name)
    MoveButtonInOrder(name, -1)
    self:LayoutButtons()
end

function MinimapButtonsWidget:MoveButtonDown(name)
    MoveButtonInOrder(name, 1)
    self:LayoutButtons()
end

-- [button] = { parent, points = {{point, rel, relPoint, x, y}, ...},
--               isScaled = bool, nativeSize = {w,h}, nativeScale = number }
local adopted = {}

local function RestoreButton(btn)
    local orig = adopted[btn]
    if not orig then return end
    btn:SetParent(orig.parent or Minimap)
    btn:ClearAllPoints()
    if #orig.points > 0 then
        for _, p in ipairs(orig.points) do
            btn:SetPoint(unpack(p))
        end
    else
        btn:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    end
    adopted[btn] = nil
end

-- Build the fixed slot grid. Each slot is a frame at a pre-computed
-- (col, row) position with a fixed BUTTON_SIZE footprint. Buttons are
-- reparented into these slots and anchored CENTER-to-CENTER, which
-- makes positioning completely immune to Blizzard SetPoint clobbering.
function MinimapButtonsWidget:BuildSlots()
    if self.slots then return end
    self.slots = {}

    local f = self.frame
    local usableWidth = DESIGN_WIDTH - PAD * 2
    local cols = math.max(1, math.floor((usableWidth + BUTTON_GAP) / (BUTTON_SIZE + BUTTON_GAP)))
    self._cols = cols

    for i = 1, MAX_SLOTS do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local slot = CreateFrame("Frame", nil, f)
        slot:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        slot:SetPoint("TOPLEFT", f, "TOPLEFT",
            PAD + col * (BUTTON_SIZE + BUTTON_GAP),
            -PAD - row * (BUTTON_SIZE + BUTTON_GAP))
        slot:Hide()  -- empty until a button is assigned in LayoutButtons
        self.slots[i] = slot
    end
end

-- opts.useScale = true to rescale the button via SetScale instead of SetSize
-- (required for compound frames like QueueStatusButton whose child frames
-- have their own hard-coded sizes that SetSize can't reach).
function MinimapButtonsWidget:AdoptButton(btn, opts)
    if adopted[btn] then return end
    opts = opts or {}
    local orig = {
        parent      = btn:GetParent(),
        points      = {},
        isScaled    = opts.useScale and true or false,
        nativeW     = btn:GetWidth(),
        nativeH     = btn:GetHeight(),
        nativeScale = btn:GetScale(),
    }
    for i = 1, btn:GetNumPoints() do
        orig.points[i] = { btn:GetPoint(i) }
    end
    adopted[btn] = orig

    -- Preliminary parenting to the widget frame so the button's z-order
    -- and scale inheritance are correct before it's assigned to a slot
    -- in LayoutButtons (which re-parents to the slot frame).
    btn:SetParent(self.frame)
    btn:SetFrameStrata("MEDIUM")

    -- Register this button in the custom-order list so the user can
    -- move it up/down from the widget's settings page. First adoption
    -- appends to the end; subsequent calls are no-ops (preserving any
    -- existing user-chosen position).
    EnsureButtonInOrder(btn:GetName() or "")

    if opts.useScale then
        -- Keep native size; scale the whole button (children + animations
        -- included) so the effective footprint matches BUTTON_SIZE.
        local nativeW = orig.nativeW
        if not nativeW or nativeW <= 0 then nativeW = BUTTON_SIZE end
        btn:SetScale(BUTTON_SIZE / nativeW)
    else
        btn:SetScale(1)
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    end
    -- Actual slot assignment + anchor happens in LayoutButtons
end

-- Reentry guard. LayoutButtons is called from hooksecurefunc hooks on
-- QueueStatusButton (Show/Hide/SetPoint), and any frame operation we
-- perform during a layout pass can re-trigger those hooks. Without this
-- guard the stack blows up in a few frames.
local layoutInProgress = false

function MinimapButtonsWidget:LayoutButtons()
    if layoutInProgress then return end
    layoutInProgress = true

    local f = self.frame
    if not f then layoutInProgress = false return end
    if not self.slots then self:BuildSlots() end

    -- Collect + sort visible buttons. The custom `buttonOrder` list
    -- drives primary ordering; anything not listed falls back to an
    -- alphabetical sort at the end.
    local list = {}
    for btn in pairs(adopted) do
        if btn:IsVisible() or btn:IsShown() then
            table.insert(list, btn)
        end
    end

    local order = GetButtonOrder()
    local orderIndex = {}
    for i, n in ipairs(order) do orderIndex[n] = i end

    -- QueueStatusButton always gets the leftmost slot (index 1)
    -- regardless of custom order or alphabetical fallback. Everything
    -- else sorts by the user's custom order, then alphabetically.
    table.sort(list, function(a, b)
        local aIsEye = (a == QueueStatusButton)
        local bIsEye = (b == QueueStatusButton)
        if aIsEye then return true end
        if bIsEye then return false end
        local ia = orderIndex[a:GetName() or ""]
        local ib = orderIndex[b:GetName() or ""]
        if ia and ib then return ia < ib end
        if ia then return true end
        if ib then return false end
        return (a:GetName() or "") < (b:GetName() or "")
    end)

    -- Compute grid dimensions and centering offset. The grid's total
    -- width is based on how many columns the visible buttons actually
    -- occupy (not the max the widget could hold). The offset pushes
    -- the grid right so the occupied columns are horizontally centered.
    local cols = self._cols or 1
    local used = #list
    local rows = used > 0 and math.ceil(used / cols) or 1
    local occupiedCols = used > 0 and math.min(used, cols) or 0
    local gridWidth = occupiedCols * BUTTON_SIZE + math.max(0, occupiedCols - 1) * BUTTON_GAP
    local usableWidth = DESIGN_WIDTH - PAD * 2
    local xOffset = PAD + math.max(0, math.floor((usableWidth - gridWidth) / 2))

    -- Reposition slots to the centered grid and assign buttons. We
    -- DO NOT call btn:Show() — the buttons are already shown (they're
    -- in `list` because we filtered for visibility), and calling Show
    -- would retrigger the hooksecurefunc hooks and recurse.
    for i = 1, MAX_SLOTS do
        local slot = self.slots[i]
        local btn = list[i]
        if btn then
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", f, "TOPLEFT",
                xOffset + col * (BUTTON_SIZE + BUTTON_GAP),
                -PAD - row * (BUTTON_SIZE + BUTTON_GAP))
            -- Always force reparent + re-anchor. Blizzard's
            -- MicroMenu:Layout can steal the QueueStatusButton back
            -- between our layout passes, so we can't rely on a
            -- parent-check guard here — we must assert ownership
            -- every single pass.
            btn:SetParent(slot)
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", slot, "CENTER", 0, 0)
            slot:Show()
        else
            slot:Hide()
        end
    end
    local h = PAD + rows * BUTTON_SIZE + (rows - 1) * BUTTON_GAP + PAD
    if used == 0 then h = MIN_HEIGHT end
    self._desiredHeight = h
    f:SetHeight(h)
    self._count = used

    layoutInProgress = false

    if addon.WidgetHost and addon.WidgetHost.Reflow then
        addon.WidgetHost:Reflow()
    end
end

---------------------------------------------------------------------------
-- Queue eye adoption. QueueStatusButton is a global Button parented to
-- MicroMenuContainer with the mixin `QueueStatusButtonMixin`. It's
-- auto-shown/hidden by Blizzard based on active LFG / PVP queues. We
-- steal it into our widget and let its natural show/hide state drive
-- whether it appears in the grid.
--
-- We also remove it from `MicroMenu.buttonsToLayout` so MicroMenu:Layout
-- stops clobbering its position on every layout pass.
---------------------------------------------------------------------------

local queueAdopted = false

local function AdoptQueueEye(widget)
    if queueAdopted then return end
    if not QueueStatusButton then return end

    -- Remove from MicroMenu's layout list. This is a one-time removal
    -- but MicroMenu:Layout can re-add the button, so we also hook
    -- Layout below to persistently keep it out.
    local function RemoveFromMicroMenu()
        if MicroMenu and MicroMenu.buttonsToLayout then
            for i = #MicroMenu.buttonsToLayout, 1, -1 do
                if MicroMenu.buttonsToLayout[i] == QueueStatusButton then
                    table.remove(MicroMenu.buttonsToLayout, i)
                end
            end
        end
    end
    RemoveFromMicroMenu()

    -- Hook MicroMenu:Layout to persistently keep QueueStatusButton
    -- out of the micro menu's layout. Blizzard rebuilds the layout
    -- on various events (instance entry, queue changes, UI reload)
    -- which can re-add the button and re-parent it back. After each
    -- Layout pass, we re-remove it and trigger a deferred relayout
    -- of our widget so it re-adopts the button into our grid.
    if MicroMenu and MicroMenu.Layout then
        hooksecurefunc(MicroMenu, "Layout", function()
            RemoveFromMicroMenu()
            -- If Blizzard stole the button back during Layout,
            -- re-adopt it on the next frame
            C_Timer.After(0, function()
                if QueueStatusButton and QueueStatusButton:IsShown() then
                    widget:LayoutButtons()
                end
            end)
        end)
    end

    -- Use SetScale — QueueStatusButton has a child Eye frame at 30×30
    -- plus a 96×96 glow overlay child, and those aren't reachable via
    -- SetSize. Scaling the whole button proportionally keeps everything
    -- in alignment.
    widget:AdoptButton(QueueStatusButton, { useScale = true })
    queueAdopted = true

    -- Hook visibility transitions. Blizzard flips the button's Shown
    -- state on LFG state changes as part of its own OnEvent handlers,
    -- which run BEFORE any C_Timer.After(0, ...) we schedule from our
    -- own handler. By hooking Show/Hide directly, we catch every
    -- transition the same frame it happens and re-run the grid layout
    -- immediately. The `layoutInProgress` guard in LayoutButtons
    -- prevents recursion when this hook fires as a downstream effect of
    -- a layout pass (e.g. from slot:Show cascading effective visibility
    -- changes on child buttons).
    hooksecurefunc(QueueStatusButton, "Show", function()
        widget:LayoutButtons()
    end)
    hooksecurefunc(QueueStatusButton, "Hide", function()
        widget:LayoutButtons()
    end)
end

function MinimapButtonsWidget:Scan()
    -- Normal minimap-child scan
    if Minimap then
        for _, child in ipairs({ Minimap:GetChildren() }) do
            if IsAdoptable(child) then
                self:AdoptButton(child)
            end
        end
    end

    -- Queue eye (special case — different parent)
    AdoptQueueEye(self)

    self:LayoutButtons()
end

function MinimapButtonsWidget:GetDesiredHeight()
    return self._desiredHeight or MIN_HEIGHT
end

function MinimapButtonsWidget:GetStatusText()
    return tostring(self._count or 0), 0.85, 0.85, 0.85
end

---------------------------------------------------------------------------
-- Friendly-name map for known addon minimap buttons so the options
-- page shows something human-readable instead of raw frame names like
-- `LibDBIcon10_BazNotificationCenter`.
---------------------------------------------------------------------------

local function FriendlyName(btnName)
    if not btnName or btnName == "" then return "Unknown" end
    -- Strip the LibDBIcon prefix
    local stripped = btnName:gsub("^LibDBIcon10_", "")
    -- Split CamelCase: "BazNotificationCenter" → "Baz Notification Center"
    stripped = stripped:gsub("([a-z])([A-Z])", "%1 %2")
    -- Special-case the queue eye
    if btnName == "QueueStatusButton" then return "Queue Eye" end
    return stripped
end

function MinimapButtonsWidget:GetOptionsArgs()
    local args = {
        rescanHeader = {
            order = 10,
            type = "header",
            name = "Detection",
        },
        rescan = {
            order = 11,
            type = "execute",
            name = "Re-scan Minimap",
            desc = "Scan the minimap for LibDBIcon addon buttons and adopt any new ones. Run this after loading a new addon that adds a minimap button.",
            func = function() MinimapButtonsWidget:Scan() end,
        },
        orderHeader = {
            order = 20,
            type = "header",
            name = "Button Order",
        },
        orderDescription = {
            order = 21,
            type = "description",
            name = "Reorder the buttons in the grid. Buttons appear left-to-right, top-to-bottom in the order listed below. New buttons detected by Re-scan are appended to the end.",
        },
    }

    -- Build one row per ordered button with Move Up / Move Down
    -- controls. The row order is driven by the live `buttonOrder`
    -- setting so it always reflects the current state (including after
    -- a move that happened earlier in this same options session).
    local order = GetButtonOrder()
    local total = #order
    local baseOrder = 30
    for i, btnName in ipairs(order) do
        local nameCopy = btnName  -- capture for closures
        local label = FriendlyName(btnName)

        args["btn_" .. i .. "_label"] = {
            order = baseOrder + (i - 1) * 10 + 0,
            type = "description",
            name = "|cffffd700" .. label .. "|r",
        }
        args["btn_" .. i .. "_up"] = {
            order = baseOrder + (i - 1) * 10 + 1,
            type = "execute",
            name = "Move Up",
            desc = "Move " .. label .. " one position earlier in the grid.",
            func = function() MinimapButtonsWidget:MoveButtonUp(nameCopy) end,
            disabled = function()
                local cur = GetButtonOrder()
                for idx, n in ipairs(cur) do
                    if n == nameCopy then return idx <= 1 end
                end
                return true
            end,
        }
        args["btn_" .. i .. "_down"] = {
            order = baseOrder + (i - 1) * 10 + 2,
            type = "execute",
            name = "Move Down",
            desc = "Move " .. label .. " one position later in the grid.",
            func = function() MinimapButtonsWidget:MoveButtonDown(nameCopy) end,
            disabled = function()
                local cur = GetButtonOrder()
                for idx, n in ipairs(cur) do
                    if n == nameCopy then return idx >= #cur end
                end
                return true
            end,
        }
    end

    if total == 0 then
        args.orderEmpty = {
            order = 29,
            type = "description",
            name = "|cff888888No adopted buttons yet. Load an addon that adds a minimap button, then run Re-scan.|r",
        }
    end

    return args
end

function MinimapButtonsWidget:Build()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "BazDrawerMinimapButtonsWidget", UIParent)
    f:SetSize(DESIGN_WIDTH, MIN_HEIGHT)

    self.frame = f
    self._desiredHeight = MIN_HEIGHT
    self._count = 0

    -- Pre-build the fixed slot grid so LayoutButtons always has frames
    -- to slot buttons into.
    self:BuildSlots()
    return f
end

function MinimapButtonsWidget:Init()
    local f = self:Build()

    BazCore:RegisterDockableWidget({
        id = WIDGET_ID,
        label = "Minimap Buttons",
        designWidth = DESIGN_WIDTH,
        designHeight = MIN_HEIGHT,
        frame = f,
        GetDesiredHeight = function() return MinimapButtonsWidget:GetDesiredHeight() end,
        GetStatusText    = function() return MinimapButtonsWidget:GetStatusText() end,
        GetOptionsArgs   = function() return MinimapButtonsWidget:GetOptionsArgs() end,
    })

    -- Queue eye event handler — re-run layout whenever LFG/PVP queue
    -- state changes so the adopted QueueStatusButton appears or
    -- disappears in the grid as Blizzard shows/hides it.
    for _, ev in ipairs(QUEUE_EYE_EVENTS) do
        pcall(f.RegisterEvent, f, ev)
    end
    f:HookScript("OnEvent", function()
        -- Blizzard toggles the queue eye's Shown state asynchronously
        -- on these events, so defer the relayout by a frame.
        C_Timer.After(0, function() MinimapButtonsWidget:LayoutButtons() end)
    end)

    -- Delay the first scan so LibDBIcon-using addons finish registering
    C_Timer.After(1.5, function() MinimapButtonsWidget:Scan() end)
end

BazCore:QueueForLogin(function() MinimapButtonsWidget:Init() end)
