-- BazWidgetDrawers Widget: Minimap Info Bar
--
-- Horizontal bar that combines the Blizzard clock button, the
-- calendar/game-time button, and the minimap tracking button.
-- Zone text lives in its own Zone widget now. Left side is
-- intentionally empty for future info buttons (bag count, mail, etc.).

local addon = BazCore:GetAddon("BazWidgetDrawers")
if not addon then return end

local WIDGET_ID     = "bazdrawer_minimap_infobar"
local DESIGN_WIDTH  = 220
local DESIGN_HEIGHT = 28
local PAD           = 6

local InfoBarWidget = {}
addon.InfoBarWidget = InfoBarWidget

local wrapper
local widgetInfo
local isAttached = false

---------------------------------------------------------------------------
-- Attach the three native frames into the wrapper in the layout:
--   [ ...empty left side...     Clock  Calendar  Tracking ]
-- Left side is intentionally empty so additional info buttons (bag
-- count, mail, gold, fps/ms, etc.) can be added later without
-- disturbing the existing right cluster.
---------------------------------------------------------------------------

local function AttachFrames()
    if isAttached or not wrapper then return end

    local iconSize = DESIGN_HEIGHT - 4

    -- Tracking button on the far right
    local trackingBtn
    if MinimapCluster and MinimapCluster.Tracking then
        trackingBtn = MinimapCluster.Tracking
        trackingBtn:SetParent(wrapper)
        trackingBtn:ClearAllPoints()
        trackingBtn:SetPoint("RIGHT", wrapper, "RIGHT", -PAD, 0)
        trackingBtn:SetSize(iconSize, iconSize)
        trackingBtn:Show()
    end

    -- Calendar proxy button. We do NOT reparent GameTimeFrame — it's a
    -- secure/protected button and reparenting it taints Blizzard code
    -- paths (notably Edit Mode and any scroll list that inspects frame
    -- attributes downstream). Instead we build a plain Button that
    -- mimics its behaviour: day-of-month label + click to open calendar
    -- + red glow when invites are pending.
    local calendarBtn = CreateFrame("Button", nil, wrapper)
    calendarBtn:SetSize(iconSize, iconSize)
    -- Tight gap between calendar and tracking — they're visually paired
    -- via the shared `ui-hud-minimap-button` background, so they read
    -- better snug together rather than with the full PAD between them.
    local CAL_TRACK_GAP = 1
    if trackingBtn then
        calendarBtn:SetPoint("RIGHT", trackingBtn, "LEFT", -CAL_TRACK_GAP, 0)
    else
        calendarBtn:SetPoint("RIGHT", wrapper, "RIGHT", -PAD, 0)
    end

    -- Background frame — same rounded bevel atlas used behind the
    -- minimap tracking button, so both icons share the same chrome.
    calendarBtn.bg = calendarBtn:CreateTexture(nil, "BACKGROUND")
    calendarBtn.bg:SetAllPoints()
    calendarBtn.bg:SetAtlas("ui-hud-minimap-button", false)

    -- Day-of-month label centered on the button. Color #A29580 — warm
    -- desaturated tan that matches the minimap-button bevel chrome.
    calendarBtn.text = calendarBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    calendarBtn.text:SetPoint("CENTER", 0, 0)
    calendarBtn.text:SetTextColor(0xA2 / 255, 0x95 / 255, 0x80 / 255)

    -- Pending-invite overlay — only shown when C_Calendar reports invites
    calendarBtn.pending = calendarBtn:CreateTexture(nil, "OVERLAY")
    calendarBtn.pending:SetAllPoints()
    calendarBtn.pending:SetAtlas("Calendar-PendingInvite", false)
    calendarBtn.pending:Hide()

    local function RefreshCalendar()
        local day
        if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
            local t = C_DateAndTime.GetCurrentCalendarTime()
            if t and t.monthDay then day = t.monthDay end
        end
        calendarBtn.text:SetText(day or "?")

        local pending = 0
        if C_Calendar and C_Calendar.GetNumPendingInvites then
            pending = C_Calendar.GetNumPendingInvites() or 0
        end
        calendarBtn.pending:SetShown(pending > 0)
    end

    calendarBtn:SetScript("OnClick", function()
        if ToggleCalendar then ToggleCalendar() end
    end)
    calendarBtn:SetScript("OnEnter", function(self)
        -- Hover color #BA9B51 — a slightly brighter warm gold than the
        -- at-rest #A29580 tan so the button reads as interactive.
        if self.text then
            self.text:SetTextColor(0xBA / 255, 0x9B / 255, 0x51 / 255)
        end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Calendar")
        GameTooltip:AddLine("Click to open the calendar", 1, 1, 1, true)
        local pending = (C_Calendar and C_Calendar.GetNumPendingInvites and C_Calendar.GetNumPendingInvites()) or 0
        if pending > 0 then
            GameTooltip:AddLine(pending .. " pending invite" .. (pending > 1 and "s" or ""), 1, 0.4, 0.4)
        end
        GameTooltip:Show()
    end)
    calendarBtn:SetScript("OnLeave", function(self)
        -- Restore the at-rest tan color
        if self.text then
            self.text:SetTextColor(0xA2 / 255, 0x95 / 255, 0x80 / 255)
        end
        GameTooltip:Hide()
    end)

    -- Event-driven refresh + periodic fallback (every 60s) for the day rollover
    local ev = CreateFrame("Frame", nil, calendarBtn)
    ev:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
    ev:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", RefreshCalendar)
    C_Timer.NewTicker(60, RefreshCalendar)
    RefreshCalendar()

    -- Clock button just to the left of the calendar (or tracking, if
    -- calendar isn't available). TimeManagerClockButton is load-on-demand;
    -- force-load its owning addon if it hasn't loaded yet and retry.
    local function AttachClock()
        local clock = TimeManagerClockButton
        if not clock then
            if C_AddOns and C_AddOns.LoadAddOn then
                C_AddOns.LoadAddOn("Blizzard_TimeManager")
            elseif LoadAddOn then
                LoadAddOn("Blizzard_TimeManager")
            end
            clock = TimeManagerClockButton
        end
        if not clock then
            C_Timer.After(1, AttachClock)
            return
        end
        clock:SetParent(wrapper)
        clock:ClearAllPoints()
        -- Upscale the clock so it reads at the same visual weight as
        -- the tracking and calendar icons next to it. The clock is a
        -- compound frame (text + bevel), so SetScale is safer than
        -- SetSize here.
        clock:SetScale(1.25)
        -- The clock's internal text baseline sits a touch above the
        -- anchor y=0 midline, so it looked raised compared to the
        -- zone text. Small negative y nudge drops its baseline back
        -- in line with the zone text visually.
        local CLOCK_Y_OFFSET = -1
        local anchorTarget = calendarBtn or trackingBtn
        if anchorTarget then
            -- Keep the clock-to-calendar gap tight to match the
            -- calendar-to-tracking gap — the whole right cluster reads
            -- as one unit instead of three spaced-out icons.
            clock:SetPoint("RIGHT", anchorTarget, "LEFT", -1, CLOCK_Y_OFFSET)
        else
            clock:SetPoint("RIGHT", wrapper, "RIGHT", -PAD, CLOCK_Y_OFFSET)
        end
        clock:Show()
    end
    AttachClock()

    isAttached = true
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function InfoBarWidget:Init()
    if wrapper then return end

    wrapper = CreateFrame("Frame", "BazWidgetDrawersMinimapInfoBarWrapper", UIParent)
    wrapper:SetSize(DESIGN_WIDTH, DESIGN_HEIGHT)

    widgetInfo = {
        id           = WIDGET_ID,
        label        = "Info Bar",
        designWidth  = DESIGN_WIDTH,
        designHeight = DESIGN_HEIGHT,
        frame        = wrapper,
        OnDock       = function() AttachFrames() end,
    }

    BazCore:RegisterDockableWidget(widgetInfo)

    -- Attach frames immediately so they're ready before the first reflow
    AttachFrames()
end

BazCore:QueueForLogin(function()
    C_Timer.After(0.2, function() InfoBarWidget:Init() end)
end)
