-- QuestTracker: Init, Refresh, Layout, Scroll
-- Main widget lifecycle: frame creation, event registration, data polling
-- loop, item-level pagination, and BazCore widget registration.

local addon = BazCore:GetAddon("BazWidgetDrawers")
if not addon then return end
local QT = addon.QT
local C  = QT.C

-- Keep a legacy alias so the widget host's older references still work
addon.QuestTrackerWidget = QT

---------------------------------------------------------------------------
-- Auto-complete popup (singleton frame, reused each Refresh)
---------------------------------------------------------------------------

local autoCompletePopup

local function EnsureAutoCompletePopup()
    if autoCompletePopup then return autoCompletePopup end

    local popup = CreateFrame("Button", nil, QT.frame or UIParent)
    popup:SetHeight(68)
    popup:Hide()

    -- Dark background (inset from the icon area)
    popup.bg = popup:CreateTexture(nil, "BACKGROUND")
    popup.bg:SetPoint("TOPLEFT", 36, -4)
    popup.bg:SetPoint("BOTTOMRIGHT", 0, 4)
    popup.bg:SetColorTexture(0, 0, 0, 0.5)

    -- Ornamental gold border - all pieces from Interface\QuestFrame\AutoQuest-Parts
    local PARTS = "Interface\\QuestFrame\\AutoQuest-Parts"

    local borderTL = popup:CreateTexture(nil, "BORDER")
    borderTL:SetTexture(PARTS)
    borderTL:SetSize(16, 16)
    borderTL:SetTexCoord(0.02539063, 0.05664063, 0.01562500, 0.26562500)
    borderTL:SetPoint("TOPLEFT", 32, 0)

    local borderTR = popup:CreateTexture(nil, "BORDER")
    borderTR:SetTexture(PARTS)
    borderTR:SetSize(16, 16)
    borderTR:SetTexCoord(0.02539063, 0.05664063, 0.29687500, 0.54687500)
    borderTR:SetPoint("TOPRIGHT", 0, 0)

    local borderBL = popup:CreateTexture(nil, "BORDER")
    borderBL:SetTexture(PARTS)
    borderBL:SetSize(16, 16)
    borderBL:SetTexCoord(0.02539063, 0.05664063, 0.57812500, 0.82812500)
    borderBL:SetPoint("BOTTOMLEFT", 32, 0)

    local borderBR = popup:CreateTexture(nil, "BORDER")
    borderBR:SetTexture(PARTS)
    borderBR:SetSize(16, 16)
    borderBR:SetTexCoord(0.06054688, 0.09179688, 0.01562500, 0.26562500)
    borderBR:SetPoint("BOTTOMRIGHT", 0, 0)

    local borderL = popup:CreateTexture(nil, "BORDER")
    borderL:SetTexture("Interface\\QuestFrame\\AutoQuestToastBorder-LeftRight")
    borderL:SetTexCoord(0, 0.5, 0, 1)
    borderL:SetWidth(8)
    borderL:SetPoint("TOPLEFT", borderTL, "BOTTOMLEFT")
    borderL:SetPoint("BOTTOMLEFT", borderBL, "TOPLEFT")

    local borderR = popup:CreateTexture(nil, "BORDER")
    borderR:SetTexture("Interface\\QuestFrame\\AutoQuestToastBorder-LeftRight")
    borderR:SetTexCoord(0.5, 1, 0, 1)
    borderR:SetWidth(8)
    borderR:SetPoint("TOPRIGHT", borderTR, "BOTTOMRIGHT")
    borderR:SetPoint("BOTTOMRIGHT", borderBR, "TOPRIGHT")

    local borderT = popup:CreateTexture(nil, "BORDER")
    borderT:SetTexture("Interface\\QuestFrame\\AutoQuestToastBorder-TopBot")
    borderT:SetTexCoord(0, 1, 0, 0.5)
    borderT:SetHeight(8)
    borderT:SetPoint("TOPLEFT", borderTL, "TOPRIGHT")
    borderT:SetPoint("TOPRIGHT", borderTR, "TOPLEFT")

    local borderB = popup:CreateTexture(nil, "BORDER")
    borderB:SetTexture("Interface\\QuestFrame\\AutoQuestToastBorder-TopBot")
    borderB:SetTexCoord(0, 1, 0.5, 1)
    borderB:SetHeight(8)
    borderB:SetPoint("BOTTOMLEFT", borderBL, "BOTTOMRIGHT")
    borderB:SetPoint("BOTTOMRIGHT", borderBR, "BOTTOMLEFT")

    -- Question mark icon (left side, overlapping the border)
    popup.iconBg = popup:CreateTexture(nil, "ARTWORK")
    popup.iconBg:SetSize(60, 60)
    popup.iconBg:SetPoint("CENTER", popup, "LEFT", 36, 0)
    popup.iconBg:SetTexture("Interface\\QuestFrame\\AutoQuest-Parts")
    popup.iconBg:SetTexCoord(0.30273438, 0.41992188, 0.01562500, 0.95312500)

    popup.questionMark = popup:CreateTexture(nil, "ARTWORK", nil, 1)
    popup.questionMark:SetTexture(PARTS)
    popup.questionMark:SetSize(19, 33)
    popup.questionMark:SetTexCoord(0.17578125, 0.21289063, 0.01562500, 0.53125000)
    popup.questionMark:SetPoint("CENTER", popup.iconBg, "CENTER", 0.5, 0)

    -- Gold badge border ring around the icon
    popup.badgeBorder = popup:CreateTexture(nil, "ARTWORK", nil, 2)
    popup.badgeBorder:SetAtlas("AutoQuest-badgeborder", true)
    popup.badgeBorder:SetPoint("TOPLEFT", popup.iconBg, "TOPLEFT", 8, -8)

    -- "Click to complete quest" header
    popup.topText = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.topText:SetPoint("TOPLEFT", popup.iconBg, "TOPRIGHT", -6, -6)
    popup.topText:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
    popup.topText:SetText(_G.QUEST_WATCH_POPUP_CLICK_TO_COMPLETE or "Click to complete quest")

    -- Quest name in large serif font
    popup.questName = popup:CreateFontString(nil, "OVERLAY", "QuestFont_Large")
    popup.questName:SetPoint("TOPLEFT", popup.topText, "BOTTOMLEFT", 0, -2)
    popup.questName:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
    popup.questName:SetTextColor(1, 1, 1)


    -- Red pulse on the ? icon only - a red-tinted copy of the icon
    -- background that pulses via a BOUNCE animation group.
    popup.iconPulse = popup:CreateTexture(nil, "ARTWORK", nil, 3)
    popup.iconPulse:SetAllPoints(popup.iconBg)
    popup.iconPulse:SetTexture("Interface\\QuestFrame\\AutoQuest-Parts")
    popup.iconPulse:SetTexCoord(0.30273438, 0.41992188, 0.01562500, 0.95312500)
    popup.iconPulse:SetVertexColor(1, 0, 0)
    popup.iconPulse:SetBlendMode("ADD")
    popup.iconPulse:SetAlpha(0)

    local pulseAG = popup.iconPulse:CreateAnimationGroup()
    pulseAG:SetLooping("BOUNCE")
    local pulse = pulseAG:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0)
    pulse:SetToAlpha(0.5)
    pulse:SetDuration(0.75)
    popup._pulseAG = pulseAG

    popup:HookScript("OnShow", function(self)
        if self._pulseAG then self._pulseAG:Play() end
    end)
    popup:HookScript("OnHide", function(self)
        if self._pulseAG then self._pulseAG:Stop() end
    end)

    popup:SetScript("OnClick", function(self)
        if self._questID and ShowQuestComplete then
            ShowQuestComplete(self._questID)
        end
    end)
    popup:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)
    end)
    popup:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0, 0, 0, 0.5)
    end)
    popup:RegisterForClicks("LeftButtonUp")

    autoCompletePopup = popup
    return popup
end

---------------------------------------------------------------------------
-- Build - create the main widget frame
---------------------------------------------------------------------------

function QT.Build()
    if QT.frame then return QT.frame end
    local f = CreateFrame("Frame", "BazWidgetDrawersQuestTrackerWidget", UIParent)
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
-- Refresh - main data polling + layout rebuild
---------------------------------------------------------------------------

function QT.Refresh()
    local f = QT.frame; if not f then return end

    -- Release current blocks and headers back into pools
    for _, block in ipairs(QT.activeBlocks) do QT.ReleaseBlock(block) end
    wipe(QT.activeBlocks)
    for _, h in ipairs(QT.activeHeaders) do QT.ReleaseHeader(h) end
    wipe(QT.activeHeaders)
    wipe(QT.items)

    -- Hide the auto-complete popup from the previous frame
    if autoCompletePopup then autoCompletePopup:Hide() end

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

    -- Bonus objectives (area task quests - auto-track when you enter
    -- the zone, auto-hide when you leave). Sorted after achievements.
    local bonusObjs = QT.GetBonusObjectives()
    if #bonusObjs > 0 then
        local bonusGroupIdx = 200
        groups[bonusGroupIdx] = {
            label  = _G.TRACKER_HEADER_BONUS_OBJECTIVES or "Bonus Objectives",
            quests = bonusObjs,
        }
        table.insert(groupOrder, bonusGroupIdx)
    end

    -- World Quests (nearby tasks + explicitly watched). Sorted last so
    -- they sit at the bottom of the tracker, matching Blizzard's order.
    if QT.GetWorldQuests then
        local worldQuests = QT.GetWorldQuests()
        if #worldQuests > 0 then
            local wqGroupIdx = 250
            groups[wqGroupIdx] = {
                label  = _G.TRACKER_HEADER_WORLD_QUESTS or "World Quests",
                quests = worldQuests,
            }
            table.insert(groupOrder, wqGroupIdx)
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
                -- Check for auto-complete quests - show the popup
                -- inside this group, before the quest blocks
                for _, quest in ipairs(group.quests) do
                    if quest.isAutoComplete and quest.isComplete then
                        local popup = EnsureAutoCompletePopup()
                        if popup then
                            popup._questID = quest.id
                            popup.questName:SetText(quest.title)
                            popup:SetParent(QT.frame)
                            table.insert(QT.items, {
                                frame  = popup,
                                height = 68,
                                gap    = C.BLOCK_SPACING,
                                kind   = "popup",
                            })
                        end
                        break  -- only one popup at a time
                    end
                end

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
-- ApplyLayout - item-level pagination
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
    f:RegisterEvent("QUEST_AUTOCOMPLETE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("SUPER_TRACKING_CHANGED")
    f:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
    f:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
    -- CONTENT_TRACKING_UPDATE is the modern event for the
    -- C_ContentTracking API (used by the Achievement window's
    -- right-click > Untrack). Without this we'd only catch the
    -- legacy tracker events and miss untrack actions.
    f:RegisterEvent("CONTENT_TRACKING_UPDATE")
    f:RegisterEvent("CRITERIA_UPDATE")
    f:RegisterEvent("ACHIEVEMENT_EARNED")
    f:RegisterEvent("SCENARIO_UPDATE")
    f:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    f:RegisterEvent("SCENARIO_COMPLETED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    -- World quest events
    f:RegisterEvent("WORLD_QUEST_COMPLETED_BY_SPELL")
    f:RegisterEvent("TASK_PROGRESS_UPDATE")
    -- M+ events
    f:RegisterEvent("CHALLENGE_MODE_START")
    f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    f:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    f:RegisterEvent("WORLD_STATE_TIMER_START")
    f:RegisterEvent("WORLD_STATE_TIMER_STOP")

    -- Coalesce refresh requests. During login the server fires
    -- QUEST_LOG_UPDATE / CRITERIA_UPDATE / TASK_PROGRESS_UPDATE etc.
    -- dozens of times within a few seconds while syncing state. Each
    -- call to QT.Refresh() rebuilds every block and header from
    -- scratch - running it 100+ times in a single frame trips WoW's
    -- "script execution time limit" addon-misbehaving error. Instead,
    -- multiple events in the same frame set a pending flag and we run
    -- exactly one Refresh at end-of-frame.
    local refreshPending = false
    local refreshFlush = CreateFrame("Frame")
    refreshFlush:Hide()
    refreshFlush:SetScript("OnUpdate", function(self)
        self:Hide()
        refreshPending = false
        QT.Refresh()
    end)
    local function QueueRefresh()
        if refreshPending then return end
        refreshPending = true
        refreshFlush:Show()
    end
    -- Expose for any external trigger that wants debounced refresh
    QT.QueueRefresh = QueueRefresh

    f:HookScript("OnEvent", function(_, event)
        if event == "SUPER_TRACKING_CHANGED" then
            QT.OnSuperTrackChanged()
            QueueRefresh()
        elseif event == "CHALLENGE_MODE_COMPLETED" then
            QT.ResetChallengeMode()
            QueueRefresh()
        else
            QueueRefresh()
        end
    end)

    C_Timer.After(0.5, function()
        QT.Refresh()
        QT.OnSuperTrackChanged()
    end)
end

BazCore:QueueForLogin(function() QT.Init() end)
