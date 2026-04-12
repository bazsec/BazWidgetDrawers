-- QuestTracker: Scenario Data
-- Reads C_Scenario / C_ScenarioInfo to build a quest-shaped data table
-- for dungeon boss lists, Delve objectives, M+ criteria, etc.

local addon = BazCore:GetAddon("BazDrawer")
if not addon then return end
local QT = addon.QT

function QT.GetScenarioData()
    if not C_Scenario or not C_Scenario.IsInScenario or not C_Scenario.IsInScenario() then
        return nil
    end

    if not C_Scenario.GetInfo then return nil end
    local scenarioName, currentStage, numStages, flags, _, _, _, xp, money,
          scenarioType, _, textureKit, scenarioID = C_Scenario.GetInfo()
    if not scenarioName then return nil end

    local stageName, stageDescription, numCriteria, widgetSetID
    if C_Scenario.GetStepInfo then
        local s1, s2, s3, _, _, _, _, _, _, _, _, s12 = C_Scenario.GetStepInfo()
        stageName        = s1
        stageDescription = s2
        numCriteria      = s3
        widgetSetID      = s12
    end
    numCriteria = numCriteria or 0

    -- Section label logic matching Blizzard's tracker header
    local inChallengeMode  = (scenarioType == _G.LE_SCENARIO_TYPE_CHALLENGE_MODE)
    local inProvingGrounds = (scenarioType == _G.LE_SCENARIO_TYPE_PROVING_GROUNDS)
    local dungeonDisplay   = (scenarioType == _G.LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY)

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

    local title = stageName
    if not title or title == "" then
        title = scenarioName or ""
    end

    local objectives = {}

    if stageDescription and stageDescription ~= "" and stageDescription ~= stageName then
        objectives[#objectives + 1] = {
            text     = stageDescription,
            finished = false,
        }
    end

    local allComplete = numCriteria > 0
    for i = 1, numCriteria do
        local info
        if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
            local ok, data = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
            if ok then info = data end
        end
        if info then
            local text = info.description or ""
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
        widgetSetID  = widgetSetID,
    }
end
