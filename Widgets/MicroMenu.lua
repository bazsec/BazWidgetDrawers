-- BazDrawer Widget: Micro Menu
--
-- Reparents Blizzard's MicroMenuContainer into the drawer so the
-- micro menu buttons (character, spellbook, talents, collections,
-- LFG, achievements, shop, etc.) live inside BazDrawer instead of
-- floating at the bottom of the screen.

local addon = BazCore:GetAddon("BazDrawer")
if not addon then return end

local WIDGET_ID    = "bazdrawer_micromenu"
local DESIGN_WIDTH = 300
local DESIGN_HEIGHT = 40
local PAD = 4

local MicroMenuWidget = {}
addon.MicroMenuWidget = MicroMenuWidget

local wrapper
local isAttached = false

---------------------------------------------------------------------------
-- Attach
---------------------------------------------------------------------------

local function AttachMicroMenu()
    if isAttached or not wrapper then return end
    if not MicroMenu then return end

    -- Reparent MicroMenu (the actual button row) instead of
    -- MicroMenuContainer — the container is oversized because it
    -- reserves space for QueueStatusButton (the eye) which we
    -- already captured into the MinimapButtons widget.
    wrapper._origParent = MicroMenu:GetParent()

    MicroMenu:SetParent(wrapper)
    MicroMenu:ClearAllPoints()
    MicroMenu:SetPoint("CENTER", wrapper, "CENTER", 0, 0)

    -- Scale the button row to fill the widget width
    local nativeW = MicroMenu:GetWidth()
    if nativeW and nativeW > 0 then
        local targetW = wrapper:GetWidth() - PAD * 2
        if targetW <= 0 then targetW = DESIGN_WIDTH - PAD * 2 end
        local scale = targetW / nativeW
        MicroMenu:SetScale(scale)
    end

    -- Conditionally hide the bags bar based on widget setting
    local bagsHooked = false
    local function ApplyBagsVisibility()
        if not BagsBar then return end
        local hide = addon:GetWidgetSetting(WIDGET_ID, "hideBagsBar", true)
        if hide ~= false then
            BagsBar:Hide()
            if not bagsHooked then
                hooksecurefunc(BagsBar, "Show", function(self)
                    if addon:GetWidgetSetting(WIDGET_ID, "hideBagsBar", true) ~= false then
                        self:Hide()
                    end
                end)
                bagsHooked = true
            end
        else
            BagsBar:Show()
        end
    end
    MicroMenuWidget._applyBags = ApplyBagsVisibility
    ApplyBagsVisibility()

    -- Hide the now-empty container so it doesn't take screen space
    if MicroMenuContainer then
        MicroMenuContainer:SetSize(1, 1)
        MicroMenuContainer:SetAlpha(0)
        MicroMenuContainer:EnableMouse(false)
        MicroMenuContainer:ClearAllPoints()
        MicroMenuContainer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)

        -- Kill the Edit Mode selection highlight — it sits at frame
        -- level 1000 with its own anchors that don't follow the
        -- parent's off-screen position, leaving a visible blue
        -- crosshair on screen.
        if MicroMenuContainer.Selection then
            MicroMenuContainer.Selection:Hide()
            MicroMenuContainer.Selection:ClearAllPoints()
            MicroMenuContainer.Selection:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
            MicroMenuContainer.Selection:SetAlpha(0)
            hooksecurefunc(MicroMenuContainer.Selection, "Show", function(self)
                self:Hide()
            end)
        end
    end

    isAttached = true
end

---------------------------------------------------------------------------
-- Widget interface
---------------------------------------------------------------------------

function MicroMenuWidget:GetDesiredHeight()
    if not MicroMenu then return DESIGN_HEIGHT + PAD * 2 end
    local h = MicroMenu:GetHeight()
    local scale = MicroMenu:GetScale() or 1
    if not h or h < 10 then h = DESIGN_HEIGHT end
    return (h * scale) + PAD * 2
end

function MicroMenuWidget:GetStatusText()
    return "", 0.85, 0.85, 0.85
end

function MicroMenuWidget:GetOptionsArgs()
    return {
        fadeHeader = {
            order = 1,
            type = "header",
            name = "Fading",
        },
        fadeEnabled = {
            order = 2,
            type = "toggle",
            name = "Fade When Not Hovered",
            desc = "Fade the micro menu to a low opacity when not hovered. Useful when floating so the buttons stay out of the way until you need them.",
            get = function()
                return addon:GetWidgetSetting(WIDGET_ID, "fadeEnabled", false) and true or false
            end,
            set = function(_, val)
                addon:SetWidgetSetting(WIDGET_ID, "fadeEnabled", val)
                MicroMenuWidget:ApplyFade()
            end,
        },
        behaviorHeader = {
            order = 10,
            type = "header",
            name = "Behavior",
        },
        hideBagsBar = {
            order = 11,
            type = "toggle",
            name = "Hide Bags Bar",
            desc = "Hide Blizzard's bag buttons bar at the bottom of the screen. With the micro menu in the drawer, the floating bags bar is usually unnecessary.",
            get = function()
                return addon:GetWidgetSetting(WIDGET_ID, "hideBagsBar", true) ~= false
            end,
            set = function(_, val)
                addon:SetWidgetSetting(WIDGET_ID, "hideBagsBar", val)
                if MicroMenuWidget._applyBags then
                    MicroMenuWidget._applyBags()
                end
            end,
        },
    }
end

---------------------------------------------------------------------------
-- Mouseover fade
---------------------------------------------------------------------------

function MicroMenuWidget:ApplyFade()
    if not wrapper then return end
    local enabled = addon:GetWidgetSetting(WIDGET_ID, "fadeEnabled", false)

    if not enabled then
        wrapper:SetAlpha(1)
        if wrapper._fadePoller then
            wrapper._fadePoller:SetScript("OnUpdate", nil)
            wrapper._fadePoller = nil
        end
        return
    end

    -- Fully transparent when not hovered
    wrapper:SetAlpha(0)

    if not wrapper._fadePoller then
        wrapper._fadePoller = CreateFrame("Frame")
    end

    local isHovered = false
    local wasEditMode = false
    wrapper._fadePoller:SetScript("OnUpdate", function()
        -- Always visible during Edit Mode so the highlight is usable
        local inEditMode = EditModeManagerFrame
            and EditModeManagerFrame.IsEditModeActive
            and EditModeManagerFrame:IsEditModeActive()
        if inEditMode then
            if not wasEditMode then
                wasEditMode = true
                wrapper:SetAlpha(1)
            end
            return
        elseif wasEditMode then
            wasEditMode = false
            isHovered = false
            wrapper:SetAlpha(0)
        end

        local over = wrapper:IsMouseOver(6, -6, -6, 6)
        if over and not isHovered then
            isHovered = true
            UIFrameFadeIn(wrapper, 0.15, wrapper:GetAlpha(), 1)
        elseif not over and isHovered then
            isHovered = false
            UIFrameFadeOut(wrapper, 0.3, wrapper:GetAlpha(), 0)
        end
    end)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function MicroMenuWidget:Init()
    if wrapper then return end

    -- Get the button row's natural width for proper scaling
    local menuW = DESIGN_WIDTH
    if MicroMenu then
        local w = MicroMenu:GetWidth()
        if w and w > 0 then menuW = w + PAD * 2 end
    end

    wrapper = CreateFrame("Frame", "BazDrawerMicroMenuWrapper", UIParent)
    wrapper:SetSize(menuW, DESIGN_HEIGHT + PAD * 2)

    BazCore:RegisterDockableWidget({
        id           = WIDGET_ID,
        label        = "Micro Menu",
        designWidth  = menuW,
        designHeight = DESIGN_HEIGHT + PAD * 2,
        frame        = wrapper,
        GetDesiredHeight = function() return MicroMenuWidget:GetDesiredHeight() end,
        GetStatusText    = function() return MicroMenuWidget:GetStatusText() end,
        GetOptionsArgs   = function() return MicroMenuWidget:GetOptionsArgs() end,
        OnDock       = function() AttachMicroMenu() end,
    })

    -- Attach immediately and apply fade state
    AttachMicroMenu()
    MicroMenuWidget:ApplyFade()
end

BazCore:QueueForLogin(function()
    C_Timer.After(0.3, function() MicroMenuWidget:Init() end)
end)
