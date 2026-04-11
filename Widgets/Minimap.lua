-- BazDrawer Widget: Minimap
--
-- Reparents the real Minimap into a wrapper frame and registers that
-- wrapper as a dockable BazDrawer widget. The Minimap becomes a first-
-- class widget that can be docked (sized by the drawer's widget host)
-- or floated (Edit Mode draggable on UIParent).
--
-- At startup the component also hides Blizzard's default MinimapCluster
-- shell — same treatment BazMiniMap does — so the native minimap chrome
-- doesn't occupy screen space alongside the widget.
--
-- Replaces (and supersedes) BazMiniMap/Dock.lua and BazMiniMap/Map.lua.
-- If BazMiniMap is still loaded alongside this widget, you'll get double-
-- reparenting conflicts. Disable BazMiniMap after enabling this widget.

local addon = BazCore:GetAddon("BazDrawer")
if not addon then return end

local WIDGET_ID    = "bazdrawer_minimap"
local DEFAULT_SIZE = 140
local VISUAL_PAD   = 18  -- breathing room around the minimap inside the wrapper
                        -- (bigger than it looks because the cardinal
                        -- decoration points extend past GetWidth/Height)

---------------------------------------------------------------------------
-- Raw method helpers
--
-- Minimap is a special widget type and requires unhooked method calls
-- for reparenting (otherwise it stops rendering entirely). `raw` gives
-- us a plain Frame we can use to access native methods on Minimap.
---------------------------------------------------------------------------

local raw = CreateFrame("Frame")

local MinimapWidget = {}
addon.MinimapWidget = MinimapWidget

local wrapper
local widgetInfo
local minimapParentedInto = nil

---------------------------------------------------------------------------
-- Parent the Minimap into the given frame (either the wrapper when docked,
-- or the wrapper when floating — the wrapper is always its immediate
-- parent; only the wrapper's own parent changes based on dock/float).
---------------------------------------------------------------------------

local function AttachMinimap(parent)
    if not Minimap or not parent then return end
    if minimapParentedInto == parent then return end

    -- Lock strata/level BEFORE reparenting or the Minimap widget stops
    -- rendering. Fixed so inherited strata from our wrapper can't leak
    -- back in after some future SetParent.
    raw.SetFrameStrata(Minimap, "MEDIUM")
    raw.SetFrameLevel(Minimap, (parent:GetFrameLevel() or 0) + 2)
    raw.SetFixedFrameStrata(Minimap, true)
    raw.SetFixedFrameLevel(Minimap, true)

    raw.SetParent(Minimap, parent)
    raw.ClearAllPoints(Minimap)
    raw.SetPoint(Minimap, "CENTER", parent, "CENTER", 0, 0)

    -- Pin Minimap's own scale to 1.0 — the widget host's SetScale on the
    -- wrapper handles all visual sizing. A non-1.0 Minimap scale on top
    -- would multiply and break the layout.
    Minimap:SetScale(1.0)

    -- Suppress Blizzard Edit Mode handling for the Minimap
    if MinimapCluster and MinimapCluster.Selection then
        MinimapCluster.Selection:Hide()
        MinimapCluster.Selection.Show = MinimapCluster.Selection.Hide
    end

    minimapParentedInto = parent
end

---------------------------------------------------------------------------
-- Hide the MinimapCluster shell so it doesn't occupy screen space
-- alongside the reparented Minimap. Same trick BazMiniMap uses.
---------------------------------------------------------------------------

local function HideMinimapCluster()
    if not MinimapCluster then return end
    MinimapCluster:SetSize(1, 1)
    MinimapCluster:SetAlpha(0)
    MinimapCluster:EnableMouse(false)
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function MinimapWidget:Init()
    if wrapper then return end
    if not Minimap then return end

    -- Query the Minimap's native (unscaled) size BEFORE we do anything.
    -- GetWidth returns the logical size regardless of SetScale.
    local mapW = Minimap:GetWidth() or DEFAULT_SIZE
    local mapH = Minimap:GetHeight() or DEFAULT_SIZE
    if not mapW or mapW == 0 then mapW = DEFAULT_SIZE end
    if not mapH or mapH == 0 then mapH = DEFAULT_SIZE end

    -- Hide Blizzard's cluster shell
    HideMinimapCluster()

    -- Wrapper is slightly larger than the minimap so the circular edge
    -- isn't flush against the widget border. The minimap is centered in
    -- the wrapper, so the padding appears evenly on all sides.
    local wrapperW = mapW + VISUAL_PAD * 2
    local wrapperH = mapH + VISUAL_PAD * 2

    wrapper = CreateFrame("Frame", "BazDrawerMinimapWrapper", UIParent)
    wrapper:SetSize(wrapperW, wrapperH)

    widgetInfo = {
        id           = WIDGET_ID,
        label        = "Minimap",
        designWidth  = wrapperW,
        designHeight = wrapperH,
        frame        = wrapper,
        OnDock       = function() AttachMinimap(wrapper) end,
        OnUndock     = function()
            -- When switching to floating mode or re-docking, we keep the
            -- wrapper as the Minimap's parent so the Minimap follows the
            -- wrapper wherever WidgetHost puts it.
            AttachMinimap(wrapper)
        end,
    }

    BazCore:RegisterDockableWidget(widgetInfo)

    -- Parent the minimap right away so it's ready before the widget
    -- host's first reflow.
    AttachMinimap(wrapper)
end

BazCore:QueueForLogin(function()
    -- Small delay gives Blizzard Minimap finish init before we grab it.
    C_Timer.After(0.2, function() MinimapWidget:Init() end)
end)
