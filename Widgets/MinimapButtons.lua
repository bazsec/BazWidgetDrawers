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

-- [button] = { parent, points = {{point, rel, relPoint, x, y}, ...} }
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

function MinimapButtonsWidget:AdoptButton(btn)
    if adopted[btn] then return end
    local orig = { parent = btn:GetParent(), points = {} }
    for i = 1, btn:GetNumPoints() do
        orig.points[i] = { btn:GetPoint(i) }
    end
    adopted[btn] = orig

    btn:SetParent(self.frame)
    btn:SetFrameStrata("MEDIUM")
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    -- Anchors get set in LayoutButtons
end

function MinimapButtonsWidget:LayoutButtons()
    local f = self.frame
    if not f then return end

    -- Collect + sort for stable order
    local list = {}
    for btn in pairs(adopted) do
        if btn:IsVisible() or btn:IsShown() then
            table.insert(list, btn)
        end
    end
    table.sort(list, function(a, b)
        return (a:GetName() or "") < (b:GetName() or "")
    end)

    local usableWidth = DESIGN_WIDTH - PAD * 2
    local cols = math.max(1, math.floor((usableWidth + BUTTON_GAP) / (BUTTON_SIZE + BUTTON_GAP)))

    for i, btn in ipairs(list) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", f, "TOPLEFT",
            PAD + col * (BUTTON_SIZE + BUTTON_GAP),
            -PAD - row * (BUTTON_SIZE + BUTTON_GAP))
        btn:Show()
    end

    -- Compute desired height
    local rows = math.max(1, math.ceil(#list / cols))
    local h = PAD + rows * BUTTON_SIZE + (rows - 1) * BUTTON_GAP + PAD
    if #list == 0 then h = MIN_HEIGHT end
    self._desiredHeight = h
    f:SetHeight(h)
    self._count = #list

    if addon.WidgetHost and addon.WidgetHost.Reflow then
        addon.WidgetHost:Reflow()
    end
end

function MinimapButtonsWidget:Scan()
    if not Minimap then return end
    for _, child in ipairs({ Minimap:GetChildren() }) do
        if IsAdoptable(child) then
            self:AdoptButton(child)
        end
    end
    self:LayoutButtons()
end

function MinimapButtonsWidget:GetDesiredHeight()
    return self._desiredHeight or MIN_HEIGHT
end

function MinimapButtonsWidget:GetStatusText()
    return tostring(self._count or 0), 0.85, 0.85, 0.85
end

function MinimapButtonsWidget:GetOptionsArgs()
    return {
        rescanHeader = {
            order = 20,
            type = "header",
            name = "Detection",
        },
        rescan = {
            order = 21,
            type = "execute",
            name = "Re-scan Minimap",
            desc = "Scan the minimap for LibDBIcon addon buttons and adopt any new ones. Run this after loading a new addon that adds a minimap button.",
            func = function() MinimapButtonsWidget:Scan() end,
        },
    }
end

function MinimapButtonsWidget:Build()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "BazDrawerMinimapButtonsWidget", UIParent)
    f:SetSize(DESIGN_WIDTH, MIN_HEIGHT)

    self.frame = f
    self._desiredHeight = MIN_HEIGHT
    self._count = 0
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

    -- Delay the first scan so LibDBIcon-using addons finish registering
    C_Timer.After(1.5, function() MinimapButtonsWidget:Scan() end)
end

BazCore:QueueForLogin(function() MinimapButtonsWidget:Init() end)
