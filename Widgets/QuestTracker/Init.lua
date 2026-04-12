-- QuestTracker: Init, Refresh, Layout, Scroll
-- Main widget lifecycle: frame creation, event registration, data polling
-- loop, item-level pagination, and BazCore widget registration.

local addon = BazCore:GetAddon("BazDrawer")
if not addon then return end
local QT = addon.QT
local C  = QT.C

-- Keep a legacy alias so the widget host's older references still work
addon.QuestTrackerWidget = QT

---------------------------------------------------------------------------
-- Build — create the main widget frame
---------------------------------------------------------------------------

function QT.Build()
    if QT.frame then return QT.frame end
    local f = CreateFrame("Frame", "BazDrawerQuestTrackerWidget", UIParent)
    f:SetSize(C.DESIGN_WIDTH, C.MIN_HEIGHT)
    QT.frame = f
    QT.scrollChild = f

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        QT.Scroll(delta)
    end)

    QT._desiredHeight = C.MIN_HEIGHT
    QT._count = 0
    QT.scrollIndex = 0
    return f
end

---------------------------------------------------------------------------
-- Refresh — main data polling + layout rebuild
---------------------------------------------------------------------------

function QT.Refresh()
    local f = QT.frame; if not f then return end

    -- Release current blocks and headers back into pools
    for _, block in ipairs(QT.activeBlocks) do QT.ReleaseBlock(block) end
    wipe(QT.activeBlocks)
    for _, h in ipairs(QT.activeHeaders) do QT.ReleaseHeader(h) end
    wipe(QT.activeHeaders)
    wipe(QT.items)

    if QT.topHeaderFrame then QT.topHeaderFrame:Hide() end

    local groups = {}
    local groupOrder = {}

    -- M+ Challenge Mode: dedicated block instead of generic scenario
    if QT.IsChallengeModeActive() then
        local cmData = QT.GetChallengeModeData()
        if cmData then
            QT._cmData = cmData
            local cmBlock = QT.CreateChallengeModeBlock()
            local cmH = QT.PopulateChallengeModeBlock(cmData)

            -- Also get scenario criteria (boss kills etc.) as a regular
            -- scenario group rendered below the CM block
            local scenario = QT.GetScenarioData()

            -- Insert the CM block as the first item
            table.insert(QT.items, {
                frame  = cmBlock,
                height = cmH,
                gap    = C.BLOCK_SPACING,
                kind   = "cmblock",
                topPad = 0,
            })

            -- If scenario data has objectives (boss kills), add them as
            -- a regular scenario group below the CM block
            if scenario and #scenario.objectives > 0 then
                local header = QT.AcquireHeader(scenario.sectionLabel or "Dungeon")
                table.insert(QT.activeHeaders, header)
                table.insert(QT.items, {
                    frame  = header,
                    height = C.HEADER_HEIGHT,
                    gap    = QT.IsGroupCollapsed(scenario.sectionLabel) and 0 or C.HEADER_AFTER_GAP,
                    kind   = "header",
                    topPad = C.GROUP_GAP,
                })

                if not QT.IsGroupCollapsed(scenario.sectionLabel) then
                    local block = QT.AcquireBlock()
                    local h = QT.PopulateBlock(block, scenario)
                    table.insert(QT.activeBlocks, block)
                    table.insert(QT.items, {
                        frame  = block,
                        height = h,
                        gap    = C.BLOCK_SPACING,
                        kind   = "block",
                    })
                end
            end
        end
    else
        -- Normal scenario group (dungeons, raids, delves, etc.)
        QT.ResetChallengeMode()
        local scenario = QT.GetScenarioData()
        if scenario and scenario.title ~= "" then
            local scenarioGroupIdx = 0
            groups[scenarioGroupIdx] = {
                label  = scenario.sectionLabel or "Scenario",
                quests = { scenario },
                kind   = "scenario",
            }
            table.insert(groupOrder, scenarioGroupIdx)
        end
    end

    -- Quest groups
    local ids = QT.GetTrackedQuestIDs()
    for _, questID in ipairs(ids) do
        local quest = QT.GetQuestData(questID)
        if quest.title ~= "" then
            local groupIdx, groupLabel = QT.ClassificationGroup(quest.classification)
            if not groups[groupIdx] then
                groups[groupIdx] = { label = groupLabel, quests = {} }
                table.insert(groupOrder, groupIdx)
            end
            table.insert(groups[groupIdx].quests, quest)
        end
    end

    table.sort(groupOrder)

    -- Achievement group
    local achievementIDs = QT.GetTrackedAchievementIDs()
    if #achievementIDs > 0 then
        local achGroupIdx = 100
        groups[achGroupIdx] = { label = "Achievements", quests = {}, kind = "achievement" }
        table.insert(groupOrder, achGroupIdx)
        for _, aid in ipairs(achievementIDs) do
            local data = QT.GetAchievementData(aid)
            if data.title ~= "" then
                table.insert(groups[achGroupIdx].quests, data)
            end
        end
        if #groups[achGroupIdx].quests == 0 then
            groups[achGroupIdx] = nil
            table.remove(groupOrder)
        end
    end

    table.sort(groupOrder)

    -- Build flat items list
    local blockCount = 0
    for groupPosition, groupIdx in ipairs(groupOrder) do
        local group = groups[groupIdx]
        if group and #group.quests > 0 then
            local collapsed = QT.IsGroupCollapsed(group.label)

            local header = QT.AcquireHeader(group.label)
            table.insert(QT.activeHeaders, header)
            table.insert(QT.items, {
                frame  = header,
                height = C.HEADER_HEIGHT,
                gap    = collapsed and 0 or C.HEADER_AFTER_GAP,
                kind   = "header",
                topPad = (groupPosition > 1 or #QT.items > 0) and C.GROUP_GAP or 0,
            })

            if not collapsed then
                for _, quest in ipairs(group.quests) do
                    local block = QT.AcquireBlock()
                    local h = QT.PopulateBlock(block, quest)
                    table.insert(QT.activeBlocks, block)
                    table.insert(QT.items, {
                        frame  = block,
                        height = h,
                        gap    = C.BLOCK_SPACING,
                        kind   = "block",
                    })
                    blockCount = blockCount + 1
                end
            end
        end
    end

    QT._count = blockCount

    -- Clamp scrollIndex
    if QT.scrollIndex == nil then QT.scrollIndex = 0 end
    if QT.scrollIndex > math.max(0, #QT.items - 1) then
        QT.scrollIndex = math.max(0, #QT.items - 1)
    end

    QT.ApplyLayout()

    if addon.WidgetHost and addon.WidgetHost.UpdateWidgetStatus then
        addon.WidgetHost:UpdateWidgetStatus(C.WIDGET_ID)
    end
    if addon.WidgetHost and addon.WidgetHost.Reflow then
        addon.WidgetHost:Reflow()
    end
end

---------------------------------------------------------------------------
-- ApplyLayout — item-level pagination
---------------------------------------------------------------------------

function QT.ApplyLayout()
    local f = QT.frame; if not f then return end
    local maxHeight = addon:GetWidgetSetting(C.WIDGET_ID, "maxHeight", C.MAX_HEIGHT_DEFAULT)

    for _, item in ipairs(QT.items) do
        if item.frame then item.frame:Hide() end
    end

    if #QT.items == 0 then
        QT._desiredHeight = C.MIN_HEIGHT
        f:SetHeight(C.MIN_HEIGHT)
        return
    end

    local y = C.PAD
    local shownCount = 0
    local startIdx = QT.scrollIndex or 0
    if startIdx < 0 then startIdx = 0 end

    for i = startIdx + 1, #QT.items do
        local item = QT.items[i]
        local topPad = item.topPad or 0
        local h = item.height
        local candidateTotal = y + topPad + h + C.PAD

        if shownCount > 0 and candidateTotal > maxHeight then
            break
        end

        y = y + topPad
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT",  f, "TOPLEFT",  C.PAD, -y)
        item.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -C.PAD, -y)
        item.frame:SetHeight(h)
        item.frame:Show()

        y = y + h + item.gap
        shownCount = shownCount + 1
    end

    if shownCount > 0 then
        local lastIdx = (startIdx + shownCount)
        local last = QT.items[lastIdx]
        if last then y = y - last.gap end
    end

    local totalHeight = y + C.PAD
    if totalHeight < C.MIN_HEIGHT then totalHeight = C.MIN_HEIGHT end

    QT._desiredHeight = totalHeight
    f:SetHeight(totalHeight)
end

---------------------------------------------------------------------------
-- Scroll
---------------------------------------------------------------------------

function QT.Scroll(delta)
    local newIdx = (QT.scrollIndex or 0) - delta
    if newIdx < 0 then newIdx = 0 end
    if newIdx > math.max(0, #QT.items - 1) then
        newIdx = math.max(0, #QT.items - 1)
    end
    if newIdx == QT.scrollIndex then return end
    QT.scrollIndex = newIdx
    QT.ApplyLayout()
    if addon.WidgetHost and addon.WidgetHost.Reflow then
        addon.WidgetHost:Reflow()
    end
end

---------------------------------------------------------------------------
-- Widget interface
---------------------------------------------------------------------------

function QT.GetDesiredHeight()
    return QT._desiredHeight or C.MIN_HEIGHT
end

function QT.GetStatusText()
    return tostring(QT._count or 0), 0.85, 0.85, 0.85
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function QT.Init()
    local f = QT.Build()

    BazCore:RegisterDockableWidget({
        id           = C.WIDGET_ID,
        label        = "Quest Tracker",
        designWidth  = C.DESIGN_WIDTH,
        designHeight = C.MIN_HEIGHT,
        frame        = f,
        GetDesiredHeight = function() return QT.GetDesiredHeight() end,
        GetStatusText    = function() return QT.GetStatusText() end,
        GetOptionsArgs   = function() return QT.GetOptionsArgs() end,
    })

    QT.ApplyBlizzardTrackerVisibility()

    -- Events
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("QUEST_WATCH_UPDATE")
    f:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    f:RegisterEvent("QUEST_ACCEPTED")
    f:RegisterEvent("QUEST_REMOVED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("SUPER_TRACKING_CHANGED")
    f:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
    f:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
    f:RegisterEvent("CRITERIA_UPDATE")
    f:RegisterEvent("ACHIEVEMENT_EARNED")
    f:RegisterEvent("SCENARIO_UPDATE")
    f:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    f:RegisterEvent("SCENARIO_COMPLETED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    -- M+ events
    f:RegisterEvent("CHALLENGE_MODE_START")
    f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    f:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    f:RegisterEvent("WORLD_STATE_TIMER_START")
    f:RegisterEvent("WORLD_STATE_TIMER_STOP")

    f:HookScript("OnEvent", function(_, event)
        if event == "SUPER_TRACKING_CHANGED" then
            QT.OnSuperTrackChanged()
            QT.Refresh()
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            QT.ResetChallengeMode()
            QT.Refresh()
        else
            QT.Refresh()
        end
    end)

    C_Timer.After(0.5, function()
        QT.Refresh()
        QT.OnSuperTrackChanged()
    end)
end

BazCore:QueueForLogin(function() QT.Init() end)
