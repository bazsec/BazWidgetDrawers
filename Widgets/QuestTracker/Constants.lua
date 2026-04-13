-- QuestTracker: Constants & Color Helpers
-- Shared layout constants, font references, and Blizzard color lookups.

local addon = BazCore:GetAddon("BazWidgetDrawers")
if not addon then return end

-- Create the shared QuestTracker namespace
addon.QT = addon.QT or {}
local QT = addon.QT

-- Constants sub-table
local C = {}
QT.C = C

-- Identity
C.WIDGET_ID    = "bazdrawer_questtracker"

-- Layout
C.DESIGN_WIDTH       = 260
C.MAX_HEIGHT_DEFAULT = 400
C.PAD                = 8
C.BLOCK_SPACING      = 10
C.HEADER_AFTER_GAP   = 8
C.GROUP_GAP          = 18
C.TITLE_HEIGHT       = 18
C.OBJ_INDENT         = 14
C.OBJ_LINE_GAP       = 2
C.OBJ_RIGHT_PAD      = 10
C.POI_SIZE           = 20
C.POI_GAP            = 8
C.SCENARIO_OBJ_GAP       = 6
C.SCENARIO_OBJ_LINE_GAP  = 10
C.NUB_SIZE           = 14
C.NUB_TEXT_GAP       = 5
C.HEADER_HEIGHT      = 32
C.TOP_HEADER_HEIGHT  = 32
C.MIN_HEIGHT         = C.PAD * 2 + C.TOP_HEADER_HEIGHT

-- Blizzard widget set IDs (from Blizzard_ScenarioObjectiveTracker.lua)
C.SCENARIO_TRACKER_WIDGET_SET     = 252
C.SCENARIO_TRACKER_TOP_WIDGET_SET = 514

-- Fonts
C.TITLE_FONT     = "ObjectiveTrackerHeaderFont"
C.OBJECTIVE_FONT = "ObjectiveTrackerLineFont"

---------------------------------------------------------------------------
-- Color helpers — read Blizzard's OBJECTIVE_TRACKER_COLOR table with
-- fallback values so the tracker works even if the table isn't loaded.
---------------------------------------------------------------------------

function QT.BlizzColor(key, fallbackR, fallbackG, fallbackB)
    local c = _G.OBJECTIVE_TRACKER_COLOR and _G.OBJECTIVE_TRACKER_COLOR[key]
    if c then return c.r, c.g, c.b end
    return fallbackR, fallbackG, fallbackB
end

function QT.GetTitleColor()      return QT.BlizzColor("Header",          1.00, 0.82, 0.00) end
function QT.GetTitleHiColor()    return QT.BlizzColor("HeaderHighlight", 1.00, 1.00, 1.00) end
function QT.GetObjectiveColor()  return QT.BlizzColor("Normal",          0.80, 0.80, 0.80) end
function QT.GetObjectiveDone()   return QT.BlizzColor("Complete",        0.60, 0.60, 0.60) end
