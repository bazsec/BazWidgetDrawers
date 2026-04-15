-- QuestTracker: Block Creation, Population & Pool
-- Creates quest/scenario/achievement block frames, renders data into
-- them via PopulateBlock, and manages the block acquisition/release pool.

local addon = BazCore:GetAddon("BazWidgetDrawers")
if not addon then return end
local QT = addon.QT
local C  = QT.C

---------------------------------------------------------------------------
-- Block creation — builds one reusable block frame with all subcomponents
---------------------------------------------------------------------------

function QT.CreateBlock()
    local block = CreateFrame("Frame", nil, QT.scrollChild or QT.frame)
    block:SetWidth(C.DESIGN_WIDTH - C.PAD * 2)

    -- Decorative scenario-stage background texture
    block.stageBg = block:CreateTexture(nil, "BORDER")
    block.stageBg:Hide()

    -- UIWidget container for scenario-specific widgets (Delve tier, deaths, affixes)
    local widgetOk, widgetContainer = pcall(CreateFrame, "Frame", nil, block, "UIWidgetContainerTemplate")
    if widgetOk and widgetContainer then
        widgetContainer:Hide()
        local sizeChangePending = false
        widgetContainer:SetScript("OnSizeChanged", function()
            if sizeChangePending then return end
            sizeChangePending = true
            C_Timer.After(0.1, function()
                sizeChangePending = false
                if QT.ApplyLayout then QT.ApplyLayout() end
            end)
        end)
        block.widgetContainer = widgetContainer
    end

    -- Title button
    local title = CreateFrame("Button", nil, block)
    title:SetPoint("TOPLEFT", block, "TOPLEFT", C.POI_SIZE + C.POI_GAP, 0)
    title:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
    title:SetHeight(C.TITLE_HEIGHT)
    title:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    block.title = title

    -- POI super-track button
    local poi
    local ok = pcall(function()
        poi = CreateFrame("Button", nil, block, "POIButtonTemplate")
    end)
    if ok and poi then
        poi:SetPoint("RIGHT", title, "LEFT", -C.POI_GAP, 0)
        poi:SetSize(C.POI_SIZE, C.POI_SIZE)
        block.poi = poi
    end

    -- Title text
    title.text = title:CreateFontString(nil, "OVERLAY")
    if _G[C.TITLE_FONT] then
        title.text:SetFontObject(_G[C.TITLE_FONT])
    else
        title.text:SetFontObject("GameFontNormal")
    end
    title.text:SetPoint("LEFT", title, "LEFT", 0, 0)
    title.text:SetPoint("RIGHT", title, "RIGHT", 0, 0)
    title.text:SetJustifyH("LEFT")
    title.text:SetJustifyV("MIDDLE")
    title.text:SetWordWrap(true)

    -- Title click handler
    title:SetScript("OnClick", function(self, button)
        local kind = block._kind or "quest"
        if kind == "scenario" then return end
        if not block._questID then return end

        if kind == "achievement" then
            if button == "LeftButton" then
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
            -- Auto-complete quests: open the turn-in dialog directly
            if block._isAutoComplete and block._isComplete and ShowQuestComplete then
                ShowQuestComplete(block._questID)
                return
            end
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
        if title.text then title.text:SetTextColor(QT.GetTitleHiColor()) end
    end)
    title:SetScript("OnLeave", function()
        if title.text then title.text:SetTextColor(QT.GetTitleColor()) end
    end)

    -- Quest item button
    local itemOk, itemBtn = pcall(CreateFrame, "Button", nil, block, "QuestObjectiveItemButtonTemplate")
    if itemOk and itemBtn then
        itemBtn:SetPoint("RIGHT", block, "RIGHT", 0, 0)
        itemBtn:SetSize(26, 26)
        itemBtn:Hide()
        block.itemButton = itemBtn
    end

    -- Find Group ("green eye") button — same Blizzard template the
    -- BonusObjectiveTracker uses. Mixin handles the OnClick → opens
    -- the Premade Group Finder filtered for that WQ.
    local fgOk, findGroupBtn = pcall(CreateFrame, "Button", nil, block, "QuestObjectiveFindGroupButtonTemplate")
    if fgOk and findGroupBtn then
        findGroupBtn:SetPoint("TOPRIGHT", block, "TOPRIGHT", 5, 2)
        findGroupBtn:Hide()
        -- The block's title Button spans the full width including under
        -- the eye, intercepting clicks. Bump our frame level above it
        -- so we get hover/click on the entire eye, not just the bottom.
        findGroupBtn:SetFrameLevel((block:GetFrameLevel() or 0) + 10)
        -- Use the template's default UI-Common-MouseHilight for hover —
        -- matches Blizzard's native look.
        block.findGroupBtn = findGroupBtn
    end

    -- Progress bar — matches Blizzard's bonus-objective bar.
    -- Atlases (bonusobjectives-bar-frame-5 + bonusobjectives-bar-ring)
    -- have segment positions baked in. We scale them down ~80% to fit
    -- our narrower widget while keeping the segments crisp.
    local SCALE = 0.95
    local barW = math.floor(191 * SCALE)        -- ~181
    local barH = math.floor(17 * SCALE)         -- ~16
    local frameW = math.floor(207 * SCALE)      -- atlas native ~207
    local frameH = math.floor(38 * SCALE)       -- atlas native ~38
    local ringSize = math.floor(38 * SCALE)     -- ring atlas native ~38

    local bar = CreateFrame("StatusBar", nil, block)
    bar:SetSize(barW, barH)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.26, 0.42, 1.00, 1)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0.04, 0.07, 0.18, 1)

    -- Force the status fill texture down to a low layer so our frame
    -- overlay can sit cleanly on top of it.
    local statusTex = bar:GetStatusBarTexture()
    if statusTex and statusTex.SetDrawLayer then
        statusTex:SetDrawLayer("ARTWORK", -8)
    end

    -- Decorative segmented frame, scaled to fit the bar. useAtlasSize=false
    -- + explicit Size lets us downscale while keeping the baked segments.
    bar.frame = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    pcall(bar.frame.SetAtlas, bar.frame, "bonusobjectives-bar-frame-5", false)
    bar.frame:SetSize(frameW, frameH)
    bar.frame:SetPoint("LEFT", -math.floor(8 * SCALE), -1)

    -- Crystal ring endcap on the right. useAtlasSize=true preserves the
    -- atlas's native aspect ratio so the ring stays round; we use
    -- SetScale to size it down to match the scaled bar frame.
    bar.endcap = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    pcall(bar.endcap.SetAtlas, bar.endcap, "bonusobjectives-bar-ring", true)
    bar.endcap:SetScale(SCALE)
    bar.endcap:SetPoint("RIGHT", bar.frame, "RIGHT", 0, 0)

    -- Reward icon inside the ring. Anchored directly to the bar's
    -- RIGHT edge (not the scaled endcap, which seems to have wonky
    -- anchor math when SetScale is applied). The ring sits at the
    -- bar's right edge anyway, so this lands the icon dead-center.
    local iconSize = math.floor(28 * SCALE)
    bar.icon = bar:CreateTexture(nil, "OVERLAY", nil, 6)
    bar.icon:SetSize(iconSize, iconSize)
    -- The atlas has internal padding that puts its visible ring further
    -- LEFT than the anchor's RIGHT edge. Empirical offset to land the
    -- icon inside the visible ring.
    bar.icon:SetPoint("CENTER", bar.frame, "RIGHT", -24, 2)
    bar.iconMask = bar:CreateMaskTexture(nil, "OVERLAY")
    bar.iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bar.iconMask:SetAllPoints(bar.icon)
    bar.icon:AddMaskTexture(bar.iconMask)
    bar.icon:Hide()

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFontObject("GameFontHighlightSmall")
    -- Center on the actual fill area, not the whole bar+endcap. The
    -- ring on the right pulls the visual center off; offset left to
    -- compensate.
    bar.text:SetPoint("CENTER", -14, -1)
    bar.text:SetTextColor(1, 1, 1)
    bar:Hide()
    block.progressBar = bar


    block.objectives = {}
    return block
end

---------------------------------------------------------------------------
-- Pool management
---------------------------------------------------------------------------

function QT.AcquireBlock()
    local block = table.remove(QT.blockPool)
    if not block then block = QT.CreateBlock() end
    block:Show()
    return block
end

function QT.ReleaseBlock(block)
    block:Hide()
    block:ClearAllPoints()
    block._questID = nil
    block._title = nil
    block._titleColor = nil
    block._kind = nil
    block._isAutoComplete = nil
    block._isComplete = nil
    for _, line in ipairs(block.objectives) do
        if line and line.Hide then line:Hide() end
    end
    if block.progressBar then block.progressBar:Hide() end
    if block.itemButton then block.itemButton:Hide() end
    if block.findGroupBtn then block.findGroupBtn:Hide() end
    if block.widgetContainer then
        block.widgetContainer:RegisterForWidgetSet(nil)
        block._registeredWidgetSetID = nil
        block.widgetContainer:Hide()
    end
    if block._bottomWidgetOrigParent then
        local blizzBottom = _G.ScenarioObjectiveTracker
            and _G.ScenarioObjectiveTracker.BottomWidgetContainerBlock
            and _G.ScenarioObjectiveTracker.BottomWidgetContainerBlock.WidgetContainer
        if blizzBottom then
            blizzBottom:SetParent(block._bottomWidgetOrigParent)
            blizzBottom:ClearAllPoints()
        end
        block._bottomWidgetOrigParent = nil
    end
    table.insert(QT.blockPool, block)
end

---------------------------------------------------------------------------
-- PopulateBlock — render quest/scenario/achievement data into a block
---------------------------------------------------------------------------

function QT.PopulateBlock(block, quest)
    block._questID = quest.id
    block._title = quest.title
    block._kind = quest.kind or "quest"
    block._isAutoComplete = quest.isAutoComplete
    block._isComplete = quest.isComplete

    local isAchievement = (block._kind == "achievement")
    local isScenario    = (block._kind == "scenario")
    local hideIcon      = isAchievement or isScenario

    -- Scenario stage block rendering
    local useWidgetSet = isScenario and quest.widgetSetID and block.widgetContainer
    if isScenario then
        if useWidgetSet then
            block.stageBg:Hide()
            block.widgetContainer:ClearAllPoints()
            block.widgetContainer:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
            block.widgetContainer:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
            block.widgetContainer:Show()
            if block._registeredWidgetSetID ~= quest.widgetSetID then
                block.widgetContainer:RegisterForWidgetSet(quest.widgetSetID)
                block._registeredWidgetSetID = quest.widgetSetID
            end
        else
            if block.widgetContainer then
                if block._registeredWidgetSetID then
                    block.widgetContainer:RegisterForWidgetSet(nil)
                    block._registeredWidgetSetID = nil
                end
                block.widgetContainer:Hide()
            end
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
        end
    else
        block.stageBg:Hide()
        if block.widgetContainer then
            if block._registeredWidgetSetID then
                block.widgetContainer:RegisterForWidgetSet(nil)
                block._registeredWidgetSetID = nil
            end
            block.widgetContainer:Hide()
        end
    end

    -- POI button
    local isWorldQuest = (block._kind == "worldquest")
    if block.poi then
        if hideIcon then
            block.poi:Hide()
        elseif block.poi.SetQuestID then
            block.poi:SetQuestID(quest.id)
            if POIButtonUtil and POIButtonUtil.Style then
                local style
                if isWorldQuest then
                    -- WorldQuest style renders Blizzard's gold WQ marker
                    -- (the "dragon"/diamond icon you see in the default tracker)
                    style = POIButtonUtil.Style.WorldQuest
                elseif quest.isComplete then
                    style = POIButtonUtil.Style.QuestComplete
                else
                    style = POIButtonUtil.Style.QuestInProgress
                end
                if block.poi.SetStyle then block.poi:SetStyle(style) end
            end
            -- WQs should ping the world map when super-tracked
            if isWorldQuest and block.poi.SetPingWorldMap then
                block.poi:SetPingWorldMap(true)
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

    -- Find Group ("green eye") button — only for WQs that LFG can
    -- create a group for (returns non-nil activityID).
    if block.findGroupBtn then
        local showFindGroup = false
        if isWorldQuest and quest.id and C_LFGList and C_LFGList.GetActivityIDForQuestID then
            local ok, activityID = pcall(C_LFGList.GetActivityIDForQuestID, quest.id)
            if ok and activityID then showFindGroup = true end
        end
        if showFindGroup then
            if block.findGroupBtn.SetUp then
                block.findGroupBtn:SetUp(quest.id)
            end
            block.findGroupBtn:Show()
        else
            block.findGroupBtn:Hide()
        end
    end

    -- Title anchoring
    block.title:ClearAllPoints()
    if useWidgetSet then
        block.title:Hide()
    elseif isScenario then
        block.title:SetPoint("TOPLEFT",  block.stageBg, "TOPLEFT",  16, -8)
        block.title:SetPoint("BOTTOMRIGHT", block.stageBg, "BOTTOMRIGHT", -16, 8)
        block.title:Show()
    elseif hideIcon then
        block.title:SetPoint("TOPLEFT", block, "TOPLEFT", 0, 0)
        block.title:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
        block.title:Show()
    else
        block.title:SetPoint("TOPLEFT", block, "TOPLEFT", C.POI_SIZE + C.POI_GAP, 0)
        block.title:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
        block.title:Show()
    end

    local titleIndent = (not hideIcon) and (C.POI_SIZE + C.POI_GAP) or 0

    -- Title text
    if not useWidgetSet then
        block.title.text:SetText(quest.title)
        if isScenario then
            block.title.text:ClearAllPoints()
            block.title.text:SetPoint("LEFT",  block.title, "LEFT",  0, 0)
            block.title.text:SetPoint("RIGHT", block.title, "RIGHT", 0, 0)
            block.title.text:SetJustifyH("LEFT")
            block.title.text:SetJustifyV("MIDDLE")
            block.title.text:SetTextColor(1.0, 0.914, 0.682)
        else
            block.title.text:SetWidth(C.DESIGN_WIDTH - C.PAD * 2 - titleIndent - C.OBJ_RIGHT_PAD)
            block.title.text:SetTextColor(QT.GetTitleColor())
        end
    end

    -- Title height
    local titleH
    if useWidgetSet then
        titleH = block.widgetContainer:GetHeight()
        if not titleH or titleH < 60 then titleH = 60 end
        local wW = block.widgetContainer:GetWidth()
        if wW and wW > 0 then
            block:SetWidth(math.max(C.DESIGN_WIDTH - C.PAD * 2, wW))
        end
    elseif isScenario then
        titleH = block.stageBg:GetHeight() or 40
        if titleH < 40 then titleH = 40 end
        local atlasW = block.stageBg:GetWidth() or 0
        if atlasW > 0 then
            block:SetWidth(math.max(C.DESIGN_WIDTH - C.PAD * 2, atlasW))
        end
    else
        titleH = block.title.text:GetStringHeight() or C.TITLE_HEIGHT
        if titleH < C.TITLE_HEIGHT then titleH = C.TITLE_HEIGHT end
        if block.poi and titleH < C.POI_SIZE then titleH = C.POI_SIZE end
        block.title:SetHeight(titleH)
    end

    -- Objective anchor
    local anchorTo, anchorGap
    if useWidgetSet then
        anchorTo  = block.widgetContainer
        anchorGap = C.SCENARIO_OBJ_GAP
    elseif isScenario then
        anchorTo  = block.stageBg
        anchorGap = C.SCENARIO_OBJ_GAP
    else
        anchorTo  = block.title
        anchorGap = 0
    end

    local leftIndent = C.OBJ_INDENT
    local objWidth   = C.DESIGN_WIDTH - C.PAD * 2 - leftIndent - C.OBJ_RIGHT_PAD
    if isScenario then
        objWidth = objWidth - (C.NUB_SIZE + C.NUB_TEXT_GAP)
    end

    local lineGap = isScenario and C.SCENARIO_OBJ_LINE_GAP or C.OBJ_LINE_GAP
    local objTotalH = anchorGap

    for i, obj in ipairs(quest.objectives) do
        local entry = block.objectives[i]
        if not entry or not entry.icon then
            local line = CreateFrame("Frame", nil, block)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetSize(C.NUB_SIZE, C.NUB_SIZE)

            line.text = line:CreateFontString(nil, "OVERLAY")
            if _G[C.OBJECTIVE_FONT] then
                line.text:SetFontObject(_G[C.OBJECTIVE_FONT])
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

        line.text:ClearAllPoints()
        line.icon:ClearAllPoints()

        local function PositionCheckOrNub(atlas)
            line.icon:SetSize(C.NUB_SIZE, C.NUB_SIZE)
            line.icon:SetAtlas(atlas, false)
            local _, fontH = line.text:GetFont()
            fontH = fontH or 12
            line.icon:SetPoint("LEFT", line, "TOPLEFT", 0, -fontH / 2)
            line.icon:Show()
            line.text:SetPoint("TOPLEFT", line, "TOPLEFT", C.NUB_SIZE + C.NUB_TEXT_GAP, 0)
        end

        if isScenario then
            PositionCheckOrNub(obj.finished
                and "ui-questtracker-tracker-check"
                or  "ui-questtracker-objective-nub")
            line.text:SetWidth(objWidth)
            line.text:SetText(obj.text or "")
        elseif obj.finished then
            PositionCheckOrNub("ui-questtracker-tracker-check")
            line.text:SetWidth(objWidth - C.NUB_SIZE - C.NUB_TEXT_GAP)
            line.text:SetText(obj.text or "")
        else
            line.icon:Hide()
            line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
            line.text:SetWidth(objWidth)
            -- Keep the inline "(XX%)" — Blizzard's default tracker
            -- shows it both in the objective text and on the bar.
            line.text:SetText("- " .. (obj.text or ""))
        end

        if obj.finished then
            line.text:SetTextColor(QT.GetObjectiveDone())
        else
            line.text:SetTextColor(QT.GetObjectiveColor())
        end

        local lineH = line.text:GetStringHeight() or 12
        local hasIcon = isScenario or obj.finished
        if hasIcon and lineH < C.NUB_SIZE then lineH = C.NUB_SIZE end
        line:SetHeight(lineH)
        line:SetWidth(objWidth + (hasIcon and (C.NUB_SIZE + C.NUB_TEXT_GAP) or 0))
        line:Show()

        objTotalH = objTotalH + lineH + lineGap
    end

    -- Hide unused objective lines
    for i = #quest.objectives + 1, #block.objectives do
        local stale = block.objectives[i]
        if stale then
            if stale.Hide then stale:Hide() end
        end
    end

    -- Progress bar — extra padding above and below so the bar doesn't
    -- crowd the objective text or the next element.
    if block.progressBar then
        if quest.progressBarPct and not isScenario then
            local barH = 13
            local barPad = 8  -- breathing room above and below the bar
            block.progressBar:ClearAllPoints()
            block.progressBar:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT",
                C.OBJ_INDENT, -(objTotalH + C.OBJ_LINE_GAP + barPad))
            block.progressBar:SetValue(quest.progressBarPct)
            block.progressBar.text:SetText(math.floor(quest.progressBarPct) .. "%")

            -- Reward icon inside the ring — same priority chain Blizzard
            -- uses in BonusObjectiveTrackerProgressBarMixin:UpdateReward
            local rewardTex
            if quest.id and HaveQuestRewardData and HaveQuestRewardData(quest.id) then
                if GetQuestLogRewardInfo then
                    local _, tex = pcall(function() return select(2, GetQuestLogRewardInfo(1, quest.id)) end)
                    rewardTex = tex
                end
                -- Currency fallback
                if not rewardTex and C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardCurrencies then
                    local ok, currencies = pcall(C_QuestInfoSystem.GetQuestRewardCurrencies, quest.id)
                    if ok and currencies and currencies[1] then
                        rewardTex = currencies[1].texture
                    end
                end
                -- Money fallback
                if not rewardTex and GetQuestLogRewardMoney and GetQuestLogRewardMoney(quest.id) > 0 then
                    rewardTex = "Interface\\Icons\\inv_misc_coin_02"
                end
                -- XP fallback
                if not rewardTex and GetQuestLogRewardXP and GetQuestLogRewardXP(quest.id) > 0
                   and IsPlayerAtEffectiveMaxLevel and not IsPlayerAtEffectiveMaxLevel() then
                    rewardTex = "Interface\\Icons\\xp_icon"
                end
            end
            if block.progressBar.icon then
                if rewardTex then
                    block.progressBar.icon:SetTexture(rewardTex)
                    block.progressBar.icon:Show()
                else
                    block.progressBar.icon:Hide()
                end
            end

            block.progressBar:Show()
            objTotalH = objTotalH + barH + C.OBJ_LINE_GAP + barPad * 2
        else
            block.progressBar:Hide()
        end
    end

    -- Quest special item button
    if block.itemButton then
        if quest.questLogIndex and quest.specialItem and not isScenario then
            if block.itemButton.SetUp then
                block.itemButton:SetUp(quest.questLogIndex)
            else
                SetItemButtonTexture(block.itemButton, quest.specialItem)
            end
            block.itemButton:ClearAllPoints()
            block.itemButton:SetPoint("RIGHT", block.title, "RIGHT", 0, 0)
            block.itemButton:Show()
            local iconW = 26 + 4
            block.title.text:SetPoint("RIGHT", block.title, "RIGHT", -iconW, 0)
        else
            block.itemButton:Hide()
        end
    end

    -- Bottom scenario widgets (companion level badge)
    local blizzBottom = _G.ScenarioObjectiveTracker
        and _G.ScenarioObjectiveTracker.BottomWidgetContainerBlock
        and _G.ScenarioObjectiveTracker.BottomWidgetContainerBlock.WidgetContainer
    if blizzBottom then
        if isScenario then
            if not block._bottomWidgetOrigParent then
                block._bottomWidgetOrigParent = blizzBottom:GetParent()
            end
            blizzBottom:SetParent(block)
            blizzBottom:ClearAllPoints()
            blizzBottom:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT",
                0, -(objTotalH + C.SCENARIO_OBJ_GAP))
            blizzBottom:Show()
            local bwH = blizzBottom:GetHeight() or 0
            if bwH > 0 then
                objTotalH = objTotalH + C.SCENARIO_OBJ_GAP + bwH
            end
        end
    end

    local totalH = titleH + objTotalH
    block:SetHeight(totalH)
    return totalH
end
