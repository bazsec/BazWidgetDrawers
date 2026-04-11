-- BazDrawer Widget: QuestTracker
--
-- Replica of Blizzard's default objective tracker, reimplemented from
-- scratch as a BazDrawer widget. Pure read-only polling of C_QuestLog.
--
-- Layout:
--   * Each quest (or section header) is a "mini widget" item. The
--     widget maintains a flat items list and a scrollIndex.
--   * ApplyLayout shows items starting from scrollIndex and stops when
--     the max-height is reached — whole items only, no partial rendering.
--   * Mouse wheel advances the scrollIndex by one item. Scrolling makes
--     entire quests appear/disappear, never half-visible ones.
--   * Because nothing is clipped, POI button glows can extend freely.
--
-- Data: pure C_QuestLog polling, no taint-prone hooks.

local addon = BazCore:GetAddon("BazDrawer")
if not addon then return end

local WIDGET_ID    = "bazdrawer_questtracker"
local DESIGN_WIDTH = 260
local MAX_HEIGHT_DEFAULT = 400    -- widget height cap; content beyond this scrolls
local PAD          = 8
local BLOCK_SPACING = 10          -- vertical gap between consecutive quest blocks
local HEADER_AFTER_GAP  = 6       -- gap below a section header before its first block
local GROUP_GAP         = 8       -- extra gap between one group's last block and the next header
local TITLE_HEIGHT = 18
local OBJ_INDENT   = 14
local OBJ_LINE_GAP = 2
local POI_SIZE     = 20           -- POI button width/height
local POI_GAP      = 4            -- space between POI button and title
local SCENARIO_OBJ_GAP      = 6   -- gap between scenario stage box and first objective
local SCENARIO_OBJ_LINE_GAP = 10  -- vertical gap between scenario boss lines
local NUB_SIZE     = 14           -- bullet "nub" icon size (orb/check)
local NUB_TEXT_GAP = 5            -- gap between nub icon and objective text
local HEADER_HEIGHT = 32          -- section header row (matches Blizzard atlas height)
local TOP_HEADER_HEIGHT = 32      -- "All Objectives" top header
local MIN_HEIGHT   = PAD * 2 + TOP_HEADER_HEIGHT

-- Use Blizzard's own Objective Tracker color constants + font objects so
-- the widget visually matches the default tracker. OBJECTIVE_TRACKER_COLOR
-- and the font objects are defined by Blizzard_ObjectiveTracker, which is
-- loaded at the time our widget initializes.
local function BlizzColor(key, fallbackR, fallbackG, fallbackB)
    local c = _G.OBJECTIVE_TRACKER_COLOR and _G.OBJECTIVE_TRACKER_COLOR[key]
    if c then return c.r, c.g, c.b end
    return fallbackR, fallbackG, fallbackB
end

local function GetTitleColor()      return BlizzColor("Header",          1.00, 0.82, 0.00) end
local function GetTitleHiColor()    return BlizzColor("HeaderHighlight", 1.00, 1.00, 1.00) end
local function GetObjectiveColor()  return BlizzColor("Normal",          0.80, 0.80, 0.80) end
local function GetObjectiveDone()   return BlizzColor("Complete",        0.60, 0.60, 0.60) end

local TITLE_FONT     = "ObjectiveTrackerHeaderFont"
local OBJECTIVE_FONT = "ObjectiveTrackerLineFont"

---------------------------------------------------------------------------
-- Widget
---------------------------------------------------------------------------

local QuestTracker = {}
addon.QuestTrackerWidget = QuestTracker

local blockPool = {}
local activeBlocks = {}
local headerPool = {}
local activeHeaders = {}
local topHeaderFrame  -- persistent "All Objectives" bar
local items = {}      -- flat list of current items: { frame, height, gap, kind = "header"|"block" }

---------------------------------------------------------------------------
-- Group collapse state helpers (per-widget, persisted via widgetSettings)
--
-- Hoisted above CreateSectionHeader/AcquireHeader so those functions'
-- OnClick closures can capture them as upvalues at definition time.
---------------------------------------------------------------------------

local function GetCollapsedMap()
    return addon:GetWidgetSetting(WIDGET_ID, "groupsCollapsed", nil) or {}
end

local function IsGroupCollapsed(label)
    local map = GetCollapsedMap()
    return map[label] and true or false
end

local function SetGroupCollapsed(label, val)
    local map = GetCollapsedMap()
    if val then
        map[label] = true
    else
        map[label] = nil
    end
    addon:SetWidgetSetting(WIDGET_ID, "groupsCollapsed", map)
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------

local function GetTrackedQuestIDs()
    local ids = {}
    if C_QuestLog.GetAllQuestWatches then
        local all = C_QuestLog.GetAllQuestWatches()
        if all then
            for _, info in ipairs(all) do
                -- GetAllQuestWatches may return table entries or raw IDs
                if type(info) == "table" then
                    if info.questID then ids[#ids + 1] = info.questID end
                else
                    ids[#ids + 1] = info
                end
            end
        end
    else
        local n = C_QuestLog.GetNumQuestWatches() or 0
        for i = 1, n do
            local qid = C_QuestLog.GetQuestIDForQuestWatchIndex
                and C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if qid then ids[#ids + 1] = qid end
        end
    end
    return ids
end

---------------------------------------------------------------------------
-- TomTom integration (hoisted above option/setter closures)
--
-- When the super-tracked quest changes, set a TomTom waypoint to the
-- quest's next objective location. The previous waypoint is removed
-- before a new one is placed so we never leave orphaned arrows behind.
---------------------------------------------------------------------------

local currentTomTomUID = nil

local function HasTomTom()
    return _G.TomTom and type(_G.TomTom.AddWaypoint) == "function"
end

-- Resolve (mapID, x, y) for a quest. Uses C_QuestLog.GetNextWaypoint
-- first, falls back to the quest's UI map + GetQuestsOnMap if that
-- returns nothing (world quests / dailies often rely on the fallback).
local function ResolveQuestWaypoint(questID)
    if not questID or questID == 0 then return nil end

    if C_QuestLog.GetNextWaypoint then
        local mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
        if mapID and x and y then
            return mapID, x, y
        end
    end

    local uiMapID = GetQuestUiMapID and GetQuestUiMapID(questID)
    if uiMapID and uiMapID > 0 and C_QuestLog.GetQuestsOnMap then
        local quests = C_QuestLog.GetQuestsOnMap(uiMapID)
        if quests then
            for _, info in ipairs(quests) do
                if info.questID == questID and info.x and info.y then
                    return uiMapID, info.x, info.y
                end
            end
        end
    end

    return nil
end

local function RemoveActiveWaypoint()
    if currentTomTomUID and _G.TomTom and type(_G.TomTom.RemoveWaypoint) == "function" then
        pcall(_G.TomTom.RemoveWaypoint, _G.TomTom, currentTomTomUID)
    end
    currentTomTomUID = nil
end

local function SetTomTomForQuest(questID)
    if not HasTomTom() then return end
    if not addon:GetWidgetSetting(WIDGET_ID, "tomtomEnabled", true) then return end

    RemoveActiveWaypoint()

    if not questID or questID == 0 then return end

    local mapID, x, y = ResolveQuestWaypoint(questID)
    if not (mapID and x and y) then return end

    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or ""

    local ok, uid = pcall(_G.TomTom.AddWaypoint, _G.TomTom, mapID, x, y, {
        title       = title,
        from        = "BazDrawer",
        silent      = true,
        persistent  = false,
        minimap     = true,
        world       = true,
        crazy       = true,   -- show the TomTom arrow
    })
    if ok then currentTomTomUID = uid end
end

local function OnSuperTrackChanged()
    local qid = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
        and C_SuperTrack.GetSuperTrackedQuestID() or 0
    SetTomTomForQuest(qid)
end

---------------------------------------------------------------------------
-- Blizzard tracker visibility (hoisted above the option closures so the
-- GetOptionsArgs setter can capture it as an upvalue)
---------------------------------------------------------------------------

local savedBlizzShow  -- original Show method, so we can restore it

local function ApplyBlizzardTrackerVisibility()
    if not ObjectiveTrackerFrame then return end
    local hide = addon:GetWidgetSetting(WIDGET_ID, "hideBlizzardTracker", true)
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

local function GetQuestClassification(questID)
    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        local ok, cls = pcall(C_QuestInfoSystem.GetQuestClassification, questID)
        if ok then return cls end
    end
    return nil
end

local function GetQuestData(questID)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or ""
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}
    local isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or false
    return {
        kind           = "quest",
        id             = questID,
        title          = title,
        objectives     = objectives,
        isComplete     = isComplete,
        classification = GetQuestClassification(questID),
    }
end

---------------------------------------------------------------------------
-- Achievement tracking
--
-- Blizzard's default tracker module (Blizzard_AchievementObjectiveTracker)
-- reads the player-tracked achievement list via
--   C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
-- and surfaces each tracked achievement the same way it surfaces quests.
-- We mirror that here and convert each achievement into a quest-shaped
-- table so PopulateBlock can render it with minimal branching.
---------------------------------------------------------------------------

local function GetTrackedAchievementIDs()
    local ids = {}
    if C_ContentTracking and C_ContentTracking.GetTrackedIDs
       and Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement then
        local ok, list = pcall(C_ContentTracking.GetTrackedIDs, Enum.ContentTrackingType.Achievement)
        if ok and type(list) == "table" then
            for _, id in ipairs(list) do
                ids[#ids + 1] = id
            end
        end
    end
    return ids
end

---------------------------------------------------------------------------
-- Scenario tracking
--
-- Blizzard's Blizzard_ScenarioObjectiveTracker uses C_Scenario.GetInfo() +
-- C_Scenario.GetStepInfo() + C_ScenarioInfo.GetCriteriaInfo(i) to render
-- dungeon boss lists, M+ criteria, raid encounter lists, delve objectives,
-- proving ground waves, and pet battle stages. We read the same APIs and
-- emit a single block per scenario with the current stage as the title
-- and each criterion as an "objective" line.
---------------------------------------------------------------------------

local function GetScenarioData()
    if not C_Scenario or not C_Scenario.IsInScenario or not C_Scenario.IsInScenario() then
        return nil
    end

    if not C_Scenario.GetInfo then return nil end
    local scenarioName, currentStage, numStages, flags, _, _, _, xp, money,
          scenarioType, _, textureKit, scenarioID = C_Scenario.GetInfo()
    if not scenarioName then return nil end

    local stageName, stageDescription, numCriteria
    if C_Scenario.GetStepInfo then
        stageName, stageDescription, numCriteria = C_Scenario.GetStepInfo()
    end
    numCriteria = numCriteria or 0

    -- Match Blizzard's tracker header labeling logic. "Dungeon" is
    -- displayed for anything using LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY,
    -- challenge modes show the scenario name, proving grounds get their
    -- own header, and normal scenarios use either the scenario name or
    -- the generic "Scenario" string.
    local inChallengeMode = (scenarioType == _G.LE_SCENARIO_TYPE_CHALLENGE_MODE)
    local inProvingGrounds = (scenarioType == _G.LE_SCENARIO_TYPE_PROVING_GROUNDS)
    local dungeonDisplay  = (scenarioType == _G.LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY)

    local sectionLabel
    if inChallengeMode then
        sectionLabel = scenarioName
    elseif inProvingGrounds then
        sectionLabel = _G.TRACKER_HEADER_PROVINGGROUNDS or "Proving Grounds"
    elseif dungeonDisplay then
        sectionLabel = _G.TRACKER_HEADER_DUNGEON or "Dungeon"
    else
        sectionLabel = scenarioName or (_G.TRACKER_HEADER_SCENARIO or "Scenario")
    end

    -- The stage block's title is just the stage name (or scenario name
    -- fallback). We no longer pre-concatenate scenarioName/stage info
    -- since the decorative box already implies the stage context.
    local title = stageName
    if not title or title == "" then
        title = scenarioName or ""
    end

    local objectives = {}

    -- Optional stage description as a flavor line (italic? just append).
    if stageDescription and stageDescription ~= "" and stageDescription ~= stageName then
        -- Strip trailing newlines/whitespace
        objectives[#objectives + 1] = {
            text     = stageDescription,
            finished = false,
        }
    end

    -- Each criterion is an objective. We mirror Blizzard's own format:
    -- weighted/formatted criteria keep their description as-is; counted
    -- criteria get "quantity/total description" prepended.
    local allComplete = numCriteria > 0
    for i = 1, numCriteria do
        local info
        if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
            local ok, data = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
            if ok then info = data end
        end
        if info then
            local text = info.description or ""
            -- Always prepend "quantity/total" for non-weighted/non-formatted
            -- criteria, even when total is 1 (boss kills, single-target
            -- objectives). This mirrors the default scenario tracker's
            -- "0/1 Kystia Manaheart defeated" format.
            if not info.isWeightedProgress and not info.isFormatted
               and info.totalQuantity and info.totalQuantity >= 1 then
                text = string.format("%d/%d %s",
                    info.quantity or 0, info.totalQuantity, text)
            end
            objectives[#objectives + 1] = {
                text     = text,
                finished = info.completed and true or false,
            }
            if not info.completed then allComplete = false end
        end
    end

    -- Fallback: if there are no criteria at all (some invasion scenarios
    -- use UIWidgets instead), keep the block with just the title so the
    -- user at least knows they're in a scenario.
    if #objectives == 0 then
        objectives[#objectives + 1] = {
            text     = stageDescription or "In progress",
            finished = false,
        }
        allComplete = false
    end

    return {
        kind         = "scenario",
        id           = 0,
        title        = title,
        objectives   = objectives,
        isComplete   = allComplete,
        sectionLabel = sectionLabel,
        textureKit   = textureKit,
    }
end

local function GetAchievementData(achievementID)
    local title = ""
    local completed = false
    if GetAchievementInfo then
        local ok, _, name, _, c = pcall(GetAchievementInfo, achievementID)
        if ok then
            title = name or ""
            completed = c and true or false
        end
    end

    local objectives = {}
    local numCriteria = (GetAchievementNumCriteria and GetAchievementNumCriteria(achievementID)) or 0
    for i = 1, numCriteria do
        if GetAchievementCriteriaInfo then
            local ok, critString, _, critCompleted, quantity, reqQuantity =
                pcall(GetAchievementCriteriaInfo, achievementID, i)
            if ok and critString then
                local text = critString
                if reqQuantity and reqQuantity > 1 and quantity then
                    text = text .. " (" .. quantity .. "/" .. reqQuantity .. ")"
                end
                objectives[#objectives + 1] = {
                    text     = text,
                    finished = critCompleted and true or false,
                }
            end
        end
    end

    return {
        kind       = "achievement",
        id         = achievementID,
        title      = title,
        objectives = objectives,
        isComplete = completed,
    }
end

---------------------------------------------------------------------------
-- Block construction + pool
---------------------------------------------------------------------------

local function CreateBlock()
    local block = CreateFrame("Frame", nil, QuestTracker.scrollChild or QuestTracker.frame)
    block:SetWidth(DESIGN_WIDTH - PAD * 2)

    -- Decorative scenario-stage background texture. Hidden by default,
    -- shown + atlased in PopulateBlock when block._kind == "scenario".
    -- Uses Blizzard's own `<textureKit>-trackerheader` atlas with
    -- useAtlasSize=true so the border renders at its native dimensions.
    block.stageBg = block:CreateTexture(nil, "BORDER")
    block.stageBg:Hide()

    -- Title first, so the POI button can anchor its middle-right to the
    -- title's middle-left below (vertically centering the icon on the
    -- title text regardless of title text height).
    local title = CreateFrame("Button", nil, block)
    title:SetPoint("TOPLEFT", block, "TOPLEFT", POI_SIZE + POI_GAP, 0)
    title:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
    title:SetHeight(TITLE_HEIGHT)
    title:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    block.title = title

    -- POI super-track button anchored to the title's middle-left so
    -- the icon is always vertically centered on the title text line.
    -- Parented to the block (no ScrollFrame clipping anymore since the
    -- QuestTracker uses item-level pagination instead).
    local poi
    local ok = pcall(function()
        poi = CreateFrame("Button", nil, block, "POIButtonTemplate")
    end)
    if ok and poi then
        poi:SetPoint("RIGHT", title, "LEFT", -POI_GAP, 0)
        poi:SetSize(POI_SIZE, POI_SIZE)
        block.poi = poi
    end

    title.text = title:CreateFontString(nil, "OVERLAY")
    if _G[TITLE_FONT] then
        title.text:SetFontObject(_G[TITLE_FONT])
    else
        title.text:SetFontObject("GameFontNormal")
    end
    -- Anchor the text to the title frame's LEFT/RIGHT (middle points)
    -- so the text is vertically centered in the title frame. This makes
    -- the text's vertical midline match the POI button's midline, which
    -- is anchored to the same LEFT edge.
    title.text:SetPoint("LEFT", title, "LEFT", 0, 0)
    title.text:SetPoint("RIGHT", title, "RIGHT", 0, 0)
    title.text:SetJustifyH("LEFT")
    title.text:SetJustifyV("MIDDLE")
    title.text:SetWordWrap(true)

    title:SetScript("OnClick", function(self, button)
        local kind = block._kind or "quest"

        -- Scenario rows are informational only — no click target
        if kind == "scenario" then return end
        if not block._questID then return end

        if kind == "achievement" then
            if button == "LeftButton" then
                -- Open the Blizzard achievement frame to this achievement.
                -- AchievementFrame is load-on-demand, so we may need to
                -- force-load it first before calling the selector.
                if not _G.AchievementFrame and UIParentLoadAddOn then
                    UIParentLoadAddOn("Blizzard_AchievementUI")
                end
                if AchievementFrame_ToggleAchievementFrame then
                    if not AchievementFrame or not AchievementFrame:IsShown() then
                        AchievementFrame_ToggleAchievementFrame()
                    end
                end
                if AchievementFrame_SelectAchievement then
                    pcall(AchievementFrame_SelectAchievement, block._questID)
                end
            elseif button == "RightButton" then
                -- Untrack the achievement
                if C_ContentTracking and C_ContentTracking.StopTracking
                   and Enum and Enum.ContentTrackingType
                   and Enum.ContentTrackingStopType then
                    pcall(C_ContentTracking.StopTracking,
                          Enum.ContentTrackingType.Achievement,
                          block._questID,
                          Enum.ContentTrackingStopType.Manual)
                end
            end
            return
        end

        -- Quest
        if button == "LeftButton" then
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
                C_SuperTrack.SetSuperTrackedQuestID(block._questID)
            end
            if WorldMapFrame and not WorldMapFrame:IsShown() and ToggleWorldMap then
                ToggleWorldMap()
            end
        elseif button == "RightButton" then
            if C_QuestLog.RemoveQuestWatch then
                C_QuestLog.RemoveQuestWatch(block._questID)
            end
        end
    end)

    title:SetScript("OnEnter", function(self)
        if title.text then
            title.text:SetTextColor(GetTitleHiColor())
        end
    end)
    title:SetScript("OnLeave", function()
        if title.text then
            title.text:SetTextColor(GetTitleColor())
        end
    end)

    block.objectives = {}  -- pool of FontStrings reused per quest
    return block
end

local function AcquireBlock()
    local block = table.remove(blockPool)
    if not block then block = CreateBlock() end
    block:Show()
    return block
end

local function ReleaseBlock(block)
    block:Hide()
    block:ClearAllPoints()
    block._questID = nil
    block._title = nil
    block._titleColor = nil
    block._kind = nil
    for _, line in ipairs(block.objectives) do
        if line and line.Hide then line:Hide() end
    end
    table.insert(blockPool, block)
end


---------------------------------------------------------------------------
-- Section header (Campaign / Quests / etc.) using Blizzard's secondary
-- objective header atlas so it visually matches the default tracker.
---------------------------------------------------------------------------

local function CreateSectionHeader()
    -- Button (not Frame) so we can catch clicks to toggle collapse.
    local f = CreateFrame("Button", nil, QuestTracker.scrollChild or QuestTracker.frame)
    f:SetHeight(HEADER_HEIGHT)

    -- Blizzard's ornamental secondary header atlas. Used with
    -- useAtlasSize = true and a CENTER anchor (same pattern as
    -- Blizzard's own tracker modules) so the texture renders at its
    -- native size without stretching / smearing.
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAtlas("UI-QuestTracker-Secondary-Objective-Header", true)
    f.bg:SetPoint("CENTER", f, "CENTER", 0, 0)

    -- Collapse / expand chevron on the right (same Blizzard atlases used
    -- by BazDrawer's slot title bars and Blizzard's own tracker modules).
    f.chevron = f:CreateTexture(nil, "OVERLAY")
    f.chevron:SetSize(16, 16)
    f.chevron:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    f.chevron:SetAtlas("ui-questtrackerbutton-secondary-collapse")

    f.text = f:CreateFontString(nil, "OVERLAY")
    if _G[TITLE_FONT] then
        f.text:SetFontObject(_G[TITLE_FONT])
    else
        f.text:SetFontObject("GameFontNormal")
    end
    f.text:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.text:SetPoint("RIGHT", f.chevron, "LEFT", -6, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetTextColor(GetTitleColor())

    f:RegisterForClicks("LeftButtonUp")
    f:SetScript("OnClick", function(self)
        local label = self._label
        if not label then return end
        SetGroupCollapsed(label, not IsGroupCollapsed(label))
        QuestTracker:Refresh()
    end)
    f:SetScript("OnEnter", function(self)
        -- Brighten the atlas slightly on hover (SetColorTexture would
        -- replace the atlas with a solid fill, hence SetVertexColor).
        self.bg:SetVertexColor(1.2, 1.2, 1.2, 1)
    end)
    f:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(1, 1, 1, 1)
    end)

    return f
end

local function AcquireHeader(label)
    local h = table.remove(headerPool)
    if not h then h = CreateSectionHeader() end
    h._label = label
    h.text:SetText(label or "")
    -- Flip the chevron based on the group's current collapse state
    h.chevron:SetAtlas(IsGroupCollapsed(label)
        and "ui-questtrackerbutton-secondary-expand"
        or  "ui-questtrackerbutton-secondary-collapse")
    h:Show()
    return h
end

local function ReleaseHeader(h)
    h:Hide()
    h:ClearAllPoints()
    table.insert(headerPool, h)
end

---------------------------------------------------------------------------
-- "All Objectives" top header — persistent frame at the top of the widget
---------------------------------------------------------------------------

local function EnsureTopHeader()
    if topHeaderFrame then return topHeaderFrame end
    local f = CreateFrame("Frame", nil, QuestTracker.scrollChild or QuestTracker.frame)
    f:SetHeight(TOP_HEADER_HEIGHT)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    f.bg:SetColorTexture(0.14, 0.10, 0.03, 0.75)

    f.underline = f:CreateTexture(nil, "BORDER")
    f.underline:SetColorTexture(0.7, 0.55, 0.15, 0.9)
    f.underline:SetPoint("BOTTOMLEFT", 0, 0)
    f.underline:SetPoint("BOTTOMRIGHT", 0, 0)
    f.underline:SetHeight(1)

    f.text = f:CreateFontString(nil, "OVERLAY")
    if _G[TITLE_FONT] then
        f.text:SetFontObject(_G[TITLE_FONT])
    else
        f.text:SetFontObject("GameFontNormal")
    end
    f.text:SetPoint("LEFT", f, "LEFT", 12, 0)
    f.text:SetText("All Objectives")
    f.text:SetTextColor(GetTitleColor())

    topHeaderFrame = f
    return f
end

---------------------------------------------------------------------------
-- Group sorting — quests are binned by classification so Campaign quests
-- render above normal ones, matching Blizzard's default tracker layout.
---------------------------------------------------------------------------

local function ClassificationGroup(cls)
    if cls == 2 then return 1, "Campaign"   end  -- Enum.QuestClassification.Campaign
    if cls == 6 then return 2, "Questlines"  end  -- Questline
    if cls == 1 then return 3, "Legendary"   end  -- Legendary
    if cls == 3 then return 4, "Callings"    end  -- Calling
    return 5, "Quests"
end

---------------------------------------------------------------------------
-- Populate one block with quest data. Returns the block's total height.
---------------------------------------------------------------------------

local function PopulateBlock(block, quest)
    block._questID = quest.id
    block._title = quest.title
    block._kind = quest.kind or "quest"

    local isAchievement = (block._kind == "achievement")
    local isScenario    = (block._kind == "scenario")
    local hideIcon      = isAchievement or isScenario

    -- Scenario stage background: set the atlas and size the title to
    -- match. The atlas draws a decorative border around just the title;
    -- objectives render outside/below the box (same as Blizzard).
    if isScenario then
        local textureKit = quest.textureKit or ""
        local atlas = textureKit .. "-trackerheader"
        if not C_Texture or not C_Texture.GetAtlasInfo
           or not C_Texture.GetAtlasInfo(atlas) then
            atlas = "evergreen-scenario-trackerheader"
        end
        block.stageBg:SetAtlas(atlas, true)
        block.stageBg:ClearAllPoints()
        block.stageBg:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
        block.stageBg:Show()
    else
        block.stageBg:Hide()
    end

    -- Configure POI button for quests only. Achievements and scenarios
    -- don't have a map POI so we hide the button entirely and remove its
    -- horizontal indent from the title.
    if block.poi then
        if hideIcon then
            block.poi:Hide()
        elseif block.poi.SetQuestID then
            block.poi:SetQuestID(quest.id)
            -- Set style + apply visuals — without this the button renders
            -- as a blank circle (symbol comes from the style's texture).
            if POIButtonUtil and POIButtonUtil.Style then
                local style = quest.isComplete
                    and POIButtonUtil.Style.QuestComplete
                    or POIButtonUtil.Style.QuestInProgress
                if block.poi.SetStyle then block.poi:SetStyle(style) end
            end
            if block.poi.SetSelected and C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
                block.poi:SetSelected(C_SuperTrack.GetSuperTrackedQuestID() == quest.id)
            end
            if block.poi.UpdateButtonStyle then
                block.poi:UpdateButtonStyle()
            end
            block.poi:Show()
        end
    end

    -- Title anchoring. Scenarios center the title inside the decorative
    -- stageBg box; achievements go flush-left; quests reserve an indent
    -- wide enough for the POI icon.
    block.title:ClearAllPoints()
    if isScenario then
        -- Pin title to the stageBg with modest left/right padding so the
        -- text sits within the decorative border
        block.title:SetPoint("TOPLEFT",  block.stageBg, "TOPLEFT",  16, -8)
        block.title:SetPoint("BOTTOMRIGHT", block.stageBg, "BOTTOMRIGHT", -16, 8)
    elseif hideIcon then
        block.title:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
        block.title:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
    else
        block.title:SetPoint("TOPLEFT", block, "TOPLEFT", POI_SIZE + POI_GAP, 0)
        block.title:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
    end

    local titleIndent = (not hideIcon) and (POI_SIZE + POI_GAP) or 0
    block.title.text:SetText(quest.title)
    if isScenario then
        -- Inside the stage box the title spans the full box minus padding
        block.title.text:ClearAllPoints()
        block.title.text:SetPoint("LEFT",  block.title, "LEFT",  0, 0)
        block.title.text:SetPoint("RIGHT", block.title, "RIGHT", 0, 0)
        block.title.text:SetJustifyH("LEFT")
        block.title.text:SetJustifyV("MIDDLE")
        -- Warm off-white matching Blizzard's ScenarioStageMixin text color
        block.title.text:SetTextColor(1.0, 0.914, 0.682)
    else
        block.title.text:SetWidth(DESIGN_WIDTH - PAD * 2 - titleIndent)
        block.title.text:SetTextColor(GetTitleColor())
    end

    local titleH
    if isScenario then
        -- The stageBg's native atlas size drives the title area height.
        -- The title text is anchored inside it so it doesn't need its
        -- own explicit height set here.
        titleH = block.stageBg:GetHeight() or 40
        if titleH < 40 then titleH = 40 end
        -- Widen the block to fit the native atlas width if needed so the
        -- decorative border isn't cropped.
        local atlasW = block.stageBg:GetWidth() or 0
        if atlasW > 0 then
            block:SetWidth(math.max(DESIGN_WIDTH - PAD * 2, atlasW))
        end
    else
        titleH = block.title.text:GetStringHeight() or TITLE_HEIGHT
        if titleH < TITLE_HEIGHT then titleH = TITLE_HEIGHT end
        -- Make sure the POI button fits vertically next to the title
        if block.poi and titleH < POI_SIZE then titleH = POI_SIZE end
        block.title:SetHeight(titleH)
    end

    -- Objectives stacked below the title. Scenarios prepend a graphical
    -- "nub" atlas as a bullet to mirror Blizzard's scenario tracker;
    -- everything else uses a simple "- " text dash.
    --
    -- IMPORTANT: the text width must be explicitly set before calling
    -- GetStringHeight(), otherwise GetStringHeight returns a single-line
    -- height even for wrapped text. Anchors alone don't tell the
    -- FontString how wide it is for wrap calculation.
    --
    -- Scenarios anchor the objective list below the decorative stage
    -- box (not below the title inside the box), with a small fixed gap.
    local anchorTo, anchorGap
    if isScenario then
        anchorTo  = block.stageBg
        anchorGap = SCENARIO_OBJ_GAP
    else
        anchorTo  = block.title
        anchorGap = 0
    end

    local leftIndent = OBJ_INDENT
    local objWidth   = DESIGN_WIDTH - PAD * 2 - leftIndent
    -- Scenarios reserve space for the bullet icon on the left
    if isScenario then
        objWidth = objWidth - (NUB_SIZE + NUB_TEXT_GAP)
    end

    -- Per-kind vertical rhythm. Scenarios get more breathing room
    -- between boss entries than quest objectives do.
    local lineGap = isScenario and SCENARIO_OBJ_LINE_GAP or OBJ_LINE_GAP

    -- Seed the running y offset with the anchor gap so the first line
    -- is pushed below the anchor (stage box or title) by that amount.
    local objTotalH = anchorGap
    for i, obj in ipairs(quest.objectives) do
        local entry = block.objectives[i]
        -- Compound lines have a `.icon` field; anything else (including
        -- legacy raw FontStrings from a pre-refactor pool) is replaced.
        if not entry or not entry.icon then
            -- Create a compound line (Frame + Icon + Text). The Frame is
            -- the line's bounding box; Icon and Text live inside it.
            local line = CreateFrame("Frame", nil, block)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetSize(NUB_SIZE, NUB_SIZE)

            line.text = line:CreateFontString(nil, "OVERLAY")
            if _G[OBJECTIVE_FONT] then
                line.text:SetFontObject(_G[OBJECTIVE_FONT])
            else
                line.text:SetFontObject("GameFontHighlightSmall")
            end
            line.text:SetJustifyH("LEFT")
            line.text:SetJustifyV("TOP")
            line.text:SetWordWrap(true)

            entry = line
            block.objectives[i] = entry
        end

        local line = entry
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", leftIndent, -(objTotalH + lineGap))

        -- Position the text and icon based on bullet style
        line.text:ClearAllPoints()
        line.icon:ClearAllPoints()
        if isScenario then
            line.icon:SetSize(NUB_SIZE, NUB_SIZE)
            -- Graphical nub bullet on the left, or green check if done.
            if obj.finished then
                line.icon:SetAtlas("ui-questtracker-tracker-check", false)
            else
                line.icon:SetAtlas("ui-questtracker-objective-nub", false)
            end
            -- Pull the per-font pixel height so we can center the icon
            -- on the FIRST text line (not the middle of the whole frame,
            -- which would drift downward for two-line boss names).
            local _, fontH = line.text:GetFont()
            fontH = fontH or 12
            line.icon:SetPoint("LEFT", line, "TOPLEFT", 0, -fontH / 2)
            line.icon:Show()
            line.text:SetPoint("TOPLEFT", line, "TOPLEFT", NUB_SIZE + NUB_TEXT_GAP, 0)
            line.text:SetWidth(objWidth)
            line.text:SetText(obj.text or "")
        else
            -- Plain "- " text dash, no icon
            line.icon:Hide()
            line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
            line.text:SetWidth(objWidth)
            line.text:SetText("- " .. (obj.text or ""))
        end

        if obj.finished then
            line.text:SetTextColor(GetObjectiveDone())
        else
            line.text:SetTextColor(GetObjectiveColor())
        end

        local lineH = line.text:GetStringHeight() or 12
        if isScenario and lineH < NUB_SIZE then lineH = NUB_SIZE end
        line:SetHeight(lineH)
        line:SetWidth(objWidth + (isScenario and (NUB_SIZE + NUB_TEXT_GAP) or 0))
        line:Show()

        objTotalH = objTotalH + lineH + lineGap
    end

    -- Hide any unused leftover lines from a previous quest
    for i = #quest.objectives + 1, #block.objectives do
        local stale = block.objectives[i]
        if stale then
            if stale.Hide then stale:Hide() end
        end
    end

    local totalH = titleH + objTotalH
    block:SetHeight(totalH)
    return totalH
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

function QuestTracker:Refresh()
    local f = self.frame; if not f then return end

    -- Release current blocks and headers back into pools
    for _, block in ipairs(activeBlocks) do ReleaseBlock(block) end
    wipe(activeBlocks)
    for _, h in ipairs(activeHeaders) do ReleaseHeader(h) end
    wipe(activeHeaders)
    wipe(items)

    if topHeaderFrame then topHeaderFrame:Hide() end

    local groups = {}
    local groupOrder = {}

    -- Scenario group (dungeons, raids, M+, delves, scenarios, pet battles,
    -- proving grounds). Sorted to the very top so boss lists / M+ timers
    -- are the first thing a player sees when in an instance. The section
    -- label is dynamic — "Dungeon" in a dungeon, scenario name in M+, etc.
    local scenario = GetScenarioData()
    if scenario and scenario.title ~= "" then
        local scenarioGroupIdx = 0  -- sorts before every quest classification
        groups[scenarioGroupIdx] = {
            label  = scenario.sectionLabel or "Scenario",
            quests = { scenario },
            kind   = "scenario",
        }
        table.insert(groupOrder, scenarioGroupIdx)
    end

    -- Gather all quest data and bin by classification group
    local ids = GetTrackedQuestIDs()

    for _, questID in ipairs(ids) do
        local quest = GetQuestData(questID)
        if quest.title ~= "" then
            local groupIdx, groupLabel = ClassificationGroup(quest.classification)
            if not groups[groupIdx] then
                groups[groupIdx] = { label = groupLabel, quests = {} }
                table.insert(groupOrder, groupIdx)
            end
            table.insert(groups[groupIdx].quests, quest)
        end
    end

    table.sort(groupOrder)

    -- Append the Achievements group after the quest groups. We only
    -- create the group when the player is actually tracking at least
    -- one achievement — empty sections must not emit a header.
    local achievementIDs = GetTrackedAchievementIDs()
    if #achievementIDs > 0 then
        local achGroupIdx = 100  -- sorts after every quest classification
        groups[achGroupIdx] = { label = "Achievements", quests = {}, kind = "achievement" }
        table.insert(groupOrder, achGroupIdx)
        for _, aid in ipairs(achievementIDs) do
            local data = GetAchievementData(aid)
            if data.title ~= "" then
                table.insert(groups[achGroupIdx].quests, data)
            end
        end
        -- If every fetched achievement came back empty-titled, drop the group.
        if #groups[achGroupIdx].quests == 0 then
            groups[achGroupIdx] = nil
            table.remove(groupOrder)
        end
    end

    table.sort(groupOrder)

    -- Build the flat items list in display order. Each item carries its
    -- own height + trailing gap so ApplyLayout can place it by adding
    -- up heights top-down without re-querying each frame. Collapsed
    -- groups still include their header (so the user can click to
    -- expand) but all of their quest blocks are skipped.
    local blockCount = 0
    for groupPosition, groupIdx in ipairs(groupOrder) do
        local group = groups[groupIdx]
        -- Safety: empty groups must never emit a header. Quest groups
        -- are only created when a quest is added, so they're guaranteed
        -- non-empty; achievement groups are filtered above; this check
        -- is belt-and-suspenders for any future group type.
        if group and #group.quests > 0 then
            local collapsed = IsGroupCollapsed(group.label)

            local header = AcquireHeader(group.label)
            table.insert(activeHeaders, header)
            table.insert(items, {
                frame  = header,
                height = HEADER_HEIGHT,
                -- Collapsed groups don't have the "header-then-block" gap
                -- because there's no first block right below the header.
                gap    = collapsed and 0 or HEADER_AFTER_GAP,
                kind   = "header",
                topPad = (groupPosition > 1) and GROUP_GAP or 0,
            })

            if not collapsed then
                for _, quest in ipairs(group.quests) do
                    local block = AcquireBlock()
                    local h = PopulateBlock(block, quest)
                    table.insert(activeBlocks, block)
                    table.insert(items, {
                        frame  = block,
                        height = h,
                        gap    = BLOCK_SPACING,
                        kind   = "block",
                    })
                    blockCount = blockCount + 1
                end
            end
        end
    end

    self._count = blockCount

    -- Clamp scrollIndex in case quests were untracked
    if self.scrollIndex == nil then self.scrollIndex = 0 end
    if self.scrollIndex > math.max(0, #items - 1) then
        self.scrollIndex = math.max(0, #items - 1)
    end

    self:ApplyLayout()

    if addon.WidgetHost and addon.WidgetHost.UpdateWidgetStatus then
        addon.WidgetHost:UpdateWidgetStatus(WIDGET_ID)
    end
    if addon.WidgetHost and addon.WidgetHost.Reflow then
        addon.WidgetHost:Reflow()
    end
end

---------------------------------------------------------------------------
-- ApplyLayout — position and show/hide items from scrollIndex forward,
-- stopping when the next item wouldn't fit inside the max-height cap.
-- At least one item is always shown (so a single tall item doesn't
-- starve the user).
---------------------------------------------------------------------------

function QuestTracker:ApplyLayout()
    local f = self.frame; if not f then return end
    local maxHeight = addon:GetWidgetSetting(WIDGET_ID, "maxHeight", MAX_HEIGHT_DEFAULT)

    -- First hide everything
    for _, item in ipairs(items) do
        if item.frame then item.frame:Hide() end
    end

    if #items == 0 then
        self._desiredHeight = MIN_HEIGHT
        f:SetHeight(MIN_HEIGHT)
        return
    end

    local y = PAD
    local shownCount = 0
    local startIdx = self.scrollIndex or 0
    if startIdx < 0 then startIdx = 0 end

    for i = startIdx + 1, #items do
        local item = items[i]
        local topPad = item.topPad or 0
        local h = item.height
        local candidateTotal = y + topPad + h + PAD

        if shownCount > 0 and candidateTotal > maxHeight then
            break
        end

        y = y + topPad
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, -y)
        item.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -y)
        item.frame:SetHeight(h)
        item.frame:Show()

        y = y + h + item.gap
        shownCount = shownCount + 1
    end

    -- Remove the trailing gap from the last visible item
    if shownCount > 0 then
        local lastIdx = (startIdx + shownCount)
        local last = items[lastIdx]
        if last then y = y - last.gap end
    end

    local totalHeight = y + PAD
    if totalHeight < MIN_HEIGHT then totalHeight = MIN_HEIGHT end

    self._desiredHeight = totalHeight
    f:SetHeight(totalHeight)
end

---------------------------------------------------------------------------
-- Scroll — advance the scrollIndex by one item in the given direction.
-- delta > 0 means mouse wheel up (scroll up toward earlier items).
---------------------------------------------------------------------------

function QuestTracker:Scroll(delta)
    local newIdx = (self.scrollIndex or 0) - delta
    if newIdx < 0 then newIdx = 0 end
    if newIdx > math.max(0, #items - 1) then
        newIdx = math.max(0, #items - 1)
    end
    if newIdx == self.scrollIndex then return end
    self.scrollIndex = newIdx
    self:ApplyLayout()
    -- Let the widget host resize the slot around us
    if addon.WidgetHost and addon.WidgetHost.Reflow then
        addon.WidgetHost:Reflow()
    end
end

---------------------------------------------------------------------------
-- Widget interface
---------------------------------------------------------------------------

function QuestTracker:GetDesiredHeight()
    return self._desiredHeight or MIN_HEIGHT
end

function QuestTracker:GetStatusText()
    return tostring(self._count or 0), 0.85, 0.85, 0.85
end

function QuestTracker:GetOptionsArgs()
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
                return addon:GetWidgetSetting(WIDGET_ID, "maxHeight", MAX_HEIGHT_DEFAULT)
            end,
            set = function(_, val)
                addon:SetWidgetSetting(WIDGET_ID, "maxHeight", val)
                QuestTracker:Refresh()
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
                return addon:GetWidgetSetting(WIDGET_ID, "hideBlizzardTracker", true) ~= false
            end,
            set = function(_, val)
                addon:SetWidgetSetting(WIDGET_ID, "hideBlizzardTracker", val)
                ApplyBlizzardTrackerVisibility()
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
                return addon:GetWidgetSetting(WIDGET_ID, "tomtomEnabled", true) ~= false
            end,
            set = function(_, val)
                addon:SetWidgetSetting(WIDGET_ID, "tomtomEnabled", val)
                if val then
                    OnSuperTrackChanged()
                else
                    RemoveActiveWaypoint()
                end
            end,
            disabled = function() return not HasTomTom() end,
        },
    }
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function QuestTracker:Build()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "BazDrawerQuestTrackerWidget", UIParent)
    f:SetSize(DESIGN_WIDTH, MIN_HEIGHT)
    self.frame = f
    -- ScrollChild is aliased to the root frame — no more ScrollFrame.
    -- Items are parented directly to f and positioned by ApplyLayout.
    self.scrollChild = f

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        QuestTracker:Scroll(delta)
    end)

    self._desiredHeight = MIN_HEIGHT
    self._count = 0
    self.scrollIndex = 0
    return f
end

function QuestTracker:Init()
    local f = self:Build()

    BazCore:RegisterDockableWidget({
        id           = WIDGET_ID,
        label        = "Quest Tracker",
        designWidth  = DESIGN_WIDTH,
        designHeight = MIN_HEIGHT,
        frame        = f,
        GetDesiredHeight = function() return QuestTracker:GetDesiredHeight() end,
        GetStatusText    = function() return QuestTracker:GetStatusText() end,
        GetOptionsArgs   = function() return QuestTracker:GetOptionsArgs() end,
    })

    ApplyBlizzardTrackerVisibility()

    -- Event-driven refresh
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("QUEST_WATCH_UPDATE")
    f:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    f:RegisterEvent("QUEST_ACCEPTED")
    f:RegisterEvent("QUEST_REMOVED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("SUPER_TRACKING_CHANGED")
    -- Achievement tracking
    f:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
    f:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
    f:RegisterEvent("CRITERIA_UPDATE")
    f:RegisterEvent("ACHIEVEMENT_EARNED")
    -- Scenario / dungeon / M+ / delve / raid encounter tracking
    f:RegisterEvent("SCENARIO_UPDATE")
    f:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    f:RegisterEvent("SCENARIO_COMPLETED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:HookScript("OnEvent", function(_, event)
        if event == "SUPER_TRACKING_CHANGED" then
            OnSuperTrackChanged()
            -- Also refresh so POI button "selected" state updates
            QuestTracker:Refresh()
        else
            QuestTracker:Refresh()
        end
    end)

    -- Initial populate (slight delay so quest log is loaded)
    C_Timer.After(0.5, function()
        QuestTracker:Refresh()
        -- If a quest is already super-tracked at login, set its waypoint
        OnSuperTrackChanged()
    end)
end

BazCore:QueueForLogin(function() QuestTracker:Init() end)
