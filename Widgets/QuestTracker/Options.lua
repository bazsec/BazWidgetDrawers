-- QuestTracker: Options & Blizzard Tracker Visibility
-- Per-widget settings exposed in BazDrawer → Widgets → Quest Tracker.

local addon = BazCore:GetAddon("BazDrawer")
if not addon then return end
local QT = addon.QT
local C  = QT.C

---------------------------------------------------------------------------
-- Blizzard tracker visibility
---------------------------------------------------------------------------

local savedBlizzShow

function QT.ApplyBlizzardTrackerVisibility()
    if not ObjectiveTrackerFrame then return end
    local hide = addon:GetWidgetSetting(C.WIDGET_ID, "hideBlizzardTracker", true)
    if hide ~= false then
        if savedBlizzShow == nil then
            savedBlizzShow = ObjectiveTrackerFrame.Show
        end
        ObjectiveTrackerFrame:Hide()
        ObjectiveTrackerFrame.Show = ObjectiveTrackerFrame.Hide
    else
        if savedBlizzShow then
            ObjectiveTrackerFrame.Show = savedBlizzShow
            savedBlizzShow = nil
        end
        ObjectiveTrackerFrame:Show()
    end
end

---------------------------------------------------------------------------
-- Options table
---------------------------------------------------------------------------

function QT.GetOptionsArgs()
    return {
        layoutHeader = {
            order = 10,
            type = "header",
            name = "Layout",
        },
        maxHeight = {
            order = 11,
            type = "range",
            name = "Max Height",
            desc = "Cap the widget's height in pixels. Quests beyond this height scroll via the mouse wheel.",
            min = 120, max = 900, step = 20,
            get = function()
                return addon:GetWidgetSetting(C.WIDGET_ID, "maxHeight", C.MAX_HEIGHT_DEFAULT)
            end,
            set = function(_, val)
                addon:SetWidgetSetting(C.WIDGET_ID, "maxHeight", val)
                QT.Refresh()
            end,
        },
        behaviorHeader = {
            order = 20,
            type = "header",
            name = "Behavior",
        },
        hideBlizzardTracker = {
            order = 21,
            type = "toggle",
            name = "Hide Default Tracker",
            desc = "Hide Blizzard's own Objective Tracker so only this widget is visible. Disable to show both trackers side by side.",
            get = function()
                return addon:GetWidgetSetting(C.WIDGET_ID, "hideBlizzardTracker", true) ~= false
            end,
            set = function(_, val)
                addon:SetWidgetSetting(C.WIDGET_ID, "hideBlizzardTracker", val)
                QT.ApplyBlizzardTrackerVisibility()
            end,
        },

        integrationHeader = {
            order = 30,
            type = "header",
            name = "Integrations",
        },
        tomtomEnabled = {
            order = 31,
            type = "toggle",
            name = "TomTom Waypoint",
            desc = "When TomTom is installed, set the TomTom arrow to the super-tracked quest's next objective. Turn off to leave TomTom alone.",
            get = function()
                return addon:GetWidgetSetting(C.WIDGET_ID, "tomtomEnabled", true) ~= false
            end,
            set = function(_, val)
                addon:SetWidgetSetting(C.WIDGET_ID, "tomtomEnabled", val)
                if val then
                    QT.OnSuperTrackChanged()
                else
                    QT.RemoveActiveWaypoint()
                end
            end,
            disabled = function() return not QT.HasTomTom() end,
        },
    }
end
