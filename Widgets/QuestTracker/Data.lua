-- QuestTracker: Data Retrieval
-- Quest, achievement, and classification data polling. Pure read-only
-- API calls - no frame creation or visual work.

local addon = BazCore:GetAddon("BazWidgetDrawers")
if not addon then return end
local QT = addon.QT

---------------------------------------------------------------------------
-- Tracked quest IDs
---------------------------------------------------------------------------

function QT.GetTrackedQuestIDs()
    local ids = {}
    if C_QuestLog.GetAllQuestWatches then
        local all = C_QuestLog.GetAllQuestWatches()
        if all then
            for _, info in ipairs(all) do
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
-- Quest classification
---------------------------------------------------------------------------

function QT.GetQuestClassification(questID)
    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        local ok, cls = pcall(C_QuestInfoSystem.GetQuestClassification, questID)
        if ok then return cls end
    end
    return nil
end

function QT.ClassificationGroup(cls)
    if cls == 2 then return 1, "Campaign"   end  -- Enum.QuestClassification.Campaign
    if cls == 6 then return 2, "Questlines"  end  -- Questline
    if cls == 1 then return 3, "Legendary"   end  -- Legendary
    if cls == 3 then return 4, "Callings"    end  -- Calling
    return 5, "Quests"
end

---------------------------------------------------------------------------
-- Quest data builder
---------------------------------------------------------------------------

function QT.GetQuestData(questID)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or ""
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}
    local isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or false

    -- Progress bar detection
    local progressBarPct
    for _, obj in ipairs(objectives) do
        if obj and obj.type == "progressbar" then
            if GetQuestProgressBarPercent then
                local ok, pct = pcall(GetQuestProgressBarPercent, questID)
                if ok then progressBarPct = pct end
            end
            break
        end
    end

    -- Quest special item
    local questLogIndex, specialItem, specialItemCharges
    if C_QuestLog.GetLogIndexForQuestID then
        questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    end
    if questLogIndex and GetQuestLogSpecialItemInfo then
        local ok, link, item, charges = pcall(GetQuestLogSpecialItemInfo, questLogIndex)
        if ok and item then
            specialItem        = item
            specialItemCharges = charges
        end
    end

    -- Auto-complete flag: quests that can be turned in from anywhere
    -- without visiting an NPC. When isComplete + isAutoComplete, the
    -- tracker shows "Click to complete quest" and clicking opens the
    -- quest completion dialog via ShowQuestComplete(questID).
    local isAutoComplete = false
    if questLogIndex then
        local questInfo = C_QuestLog.GetInfo and C_QuestLog.GetInfo(questLogIndex)
        if questInfo and questInfo.isAutoComplete then
            isAutoComplete = true
        end
    end

    -- Completion text for non-auto-complete quests (e.g. "Return to
    -- NPC Name"). Shown instead of objectives when the quest is done.
    local completionText
    if isComplete and not isAutoComplete and questLogIndex then
        if GetQuestLogCompletionText then
            completionText = GetQuestLogCompletionText(questLogIndex)
        end
    end

    return {
        kind               = "quest",
        id                 = questID,
        title              = title,
        objectives         = objectives,
        isComplete         = isComplete,
        isAutoComplete     = isAutoComplete,
        completionText     = completionText,
        classification     = QT.GetQuestClassification(questID),
        progressBarPct     = progressBarPct,
        questLogIndex      = questLogIndex,
        specialItem        = specialItem,
        specialItemCharges = specialItemCharges,
    }
end

---------------------------------------------------------------------------
-- Achievement tracking
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Bonus objectives (task quests in the current area)
---------------------------------------------------------------------------

function QT.GetBonusObjectives()
    local results = {}
    if not GetTasksTable then return results end

    local tasks = GetTasksTable()
    for _, questID in ipairs(tasks) do
        -- Skip world quests and already-tracked quests - those show
        -- in their own sections. Bonus objectives are area-specific
        -- tasks that auto-track when you enter the zone.
        local isWorldQuest = QuestUtils_IsQuestWorldQuest and QuestUtils_IsQuestWorldQuest(questID)
        local isWatched = QuestUtils_IsQuestWatched and QuestUtils_IsQuestWatched(questID)

        if not isWorldQuest and not isWatched then
            local isInArea, isOnMap, numObjectives, taskName = GetTaskInfo(questID)
            if isInArea and numObjectives and numObjectives > 0 then
                local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}
                local isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or false

                results[#results + 1] = {
                    kind       = "quest",
                    id         = questID,
                    title      = taskName or "",
                    objectives = objectives,
                    isComplete = isComplete,
                }
            end
        end
    end
    return results
end

---------------------------------------------------------------------------
-- World Quests
-- Returns a list of all world quests the player should see in the
-- tracker. Includes both nearby-area WQs (auto-tracked while in zone)
-- and explicitly watched WQs. Each entry carries objective lines and,
-- when applicable, a progressBarPct value so the existing bar widget
-- in PopulateBlock renders the Blizzard-style progress bar.
---------------------------------------------------------------------------

local function GetWorldQuestTitle(questID)
    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local title = C_TaskQuest.GetQuestInfoByQuestID(questID)
        if title and title ~= "" then return title end
    end
    if QuestUtils_GetQuestName then
        local title = QuestUtils_GetQuestName(questID)
        if title and title ~= "" then return title end
    end
    return ""
end

local function BuildWorldQuestEntry(questID)
    local title = GetWorldQuestTitle(questID)
    if title == "" then return nil end

    local objectives = {}
    local progressBarPct = nil

    local rawObjectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or {}
    for _, obj in ipairs(rawObjectives) do
        objectives[#objectives + 1] = {
            text     = obj.text or "",
            finished = obj.finished and true or false,
            type     = obj.type,
        }
        if obj.type == "progressbar" and not progressBarPct then
            local ok, pct = pcall(GetQuestProgressBarPercent, questID)
            if ok and pct then progressBarPct = pct end
        end
    end

    -- Time-left line (only when getting close to expiration)
    local timeLeftMinutes
    if C_TaskQuest and C_TaskQuest.GetQuestTimeLeftMinutes then
        local ok, mins = pcall(C_TaskQuest.GetQuestTimeLeftMinutes, questID)
        if ok then timeLeftMinutes = mins end
    end
    local critical = (_G.WORLD_QUESTS_TIME_CRITICAL_MINUTES) or 60
    if timeLeftMinutes and timeLeftMinutes > 0 and timeLeftMinutes <= critical then
        local timeText
        if timeLeftMinutes < 60 then
            timeText = string.format("%d min remaining", timeLeftMinutes)
        else
            local h = math.floor(timeLeftMinutes / 60)
            local m = timeLeftMinutes % 60
            timeText = string.format("%dh %dm remaining", h, m)
        end
        objectives[#objectives + 1] = {
            text     = timeText,
            finished = false,
            isTimer  = true,
        }
    end

    local isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or false

    return {
        kind            = "worldquest",
        id              = questID,
        title           = title,
        objectives      = objectives,
        isComplete      = isComplete,
        progressBarPct  = progressBarPct,
        timeLeftMinutes = timeLeftMinutes,
    }
end

local function SortWorldQuests(a, b)
    -- Mirror Blizzard's WorldQuestObjectiveTracker sort: in-area first,
    -- then on-map, then by questID.
    if not GetTaskInfo then return a.id < b.id end
    local inArea1, onMap1 = GetTaskInfo(a.id)
    local inArea2, onMap2 = GetTaskInfo(b.id)
    if inArea1 ~= inArea2 then return inArea1 and true or false end
    if onMap1  ~= onMap2  then return onMap1  and true or false end
    return a.id < b.id
end

function QT.GetWorldQuests()
    local results = {}
    local seen = {}

    -- Nearby WQs (auto-tracked when you're in the zone)
    if GetTasksTable then
        for _, questID in ipairs(GetTasksTable()) do
            if QuestUtils_IsQuestWorldQuest and QuestUtils_IsQuestWorldQuest(questID)
               and not seen[questID] then
                local entry = BuildWorldQuestEntry(questID)
                if entry then
                    results[#results + 1] = entry
                    seen[questID] = true
                end
            end
        end
    end

    -- Explicitly watched WQs (super-tracked / pinned from the map)
    if C_QuestLog and C_QuestLog.GetNumWorldQuestWatches and C_QuestLog.GetQuestIDForWorldQuestWatchIndex then
        for i = 1, C_QuestLog.GetNumWorldQuestWatches() do
            local questID = C_QuestLog.GetQuestIDForWorldQuestWatchIndex(i)
            if questID and not seen[questID] then
                local entry = BuildWorldQuestEntry(questID)
                if entry then
                    results[#results + 1] = entry
                    seen[questID] = true
                end
            end
        end
    end

    table.sort(results, SortWorldQuests)
    return results
end

---------------------------------------------------------------------------
-- Achievement tracking
---------------------------------------------------------------------------

function QT.GetTrackedAchievementIDs()
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

function QT.GetAchievementData(achievementID)
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
