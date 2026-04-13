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

    -- Progress bar — matches Blizzard's ObjectiveTrackerProgressBar
    -- style with the UI-Character-Skills-BarBorder left/right caps
    -- and tiled middle border.
    -- Shorter width than objectives — matches Blizzard's 180px bar
    -- scaled to our design width proportionally
    local barW = math.min(180, C.DESIGN_WIDTH - C.PAD * 2 - C.OBJ_INDENT - C.OBJ_RIGHT_PAD)
    local bar = CreateFrame("StatusBar", nil, block)
    bar:SetSize(barW, 13)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.26, 0.42, 0.75, 1)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0.08, 0.08, 0.10, 0.7)

    -- Border (left cap, right cap, tiled middle)
    local BORDER_TEX = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
    bar.borderLeft = bar:CreateTexture(nil, "ARTWORK")
    bar.borderLeft:SetTexture(BORDER_TEX)
    bar.borderLeft:SetSize(9, 22)
    bar.borderLeft:SetTexCoord(0.007843, 0.043137, 0.193548, 0.774193)
    bar.borderLeft:SetPoint("LEFT", -3, 0)

    bar.borderRight = bar:CreateTexture(nil, "ARTWORK")
    bar.borderRight:SetTexture(BORDER_TEX)
    bar.borderRight:SetSize(9, 22)
    bar.borderRight:SetTexCoord(0.043137, 0.007843, 0.193548, 0.774193)
    bar.borderRight:SetPoint("RIGHT", 3, 0)

    bar.borderMid = bar:CreateTexture(nil, "ARTWORK")
    bar.borderMid:SetTexture(BORDER_TEX)
    bar.borderMid:SetTexCoord(0.113726, 0.1490196, 0.193548, 0.774193)
    bar.borderMid:SetPoint("TOPLEFT", bar.borderLeft, "TOPRIGHT")
    bar.borderMid:SetPoint("BOTTOMRIGHT", bar.borderRight, "BOTTOMLEFT")

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFontObject("GameFontHighlightMedium")
    bar.text:SetPoint("CENTER")
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
    if block.poi then
        if hideIcon then
            block.poi:Hide()
        elseif block.poi.SetQuestID then
            block.poi:SetQuestID(quest.id)
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
            -- Strip redundant "(XX%)" from the text when a progress
            -- bar is showing the percentage visually already
            local displayText = obj.text or ""
            if quest.progressBarPct and obj.type == "progressbar" then
                displayText = displayText:gsub("%s*%(%d+%%%)", "")
            end
            line.text:SetText("- " .. displayText)
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
            local barPad = 4  -- breathing room above and below the bar
            block.progressBar:ClearAllPoints()
            block.progressBar:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT",
                C.OBJ_INDENT, -(objTotalH + C.OBJ_LINE_GAP + barPad))
            block.progressBar:SetValue(quest.progressBarPct)
            block.progressBar.text:SetText(math.floor(quest.progressBarPct) .. "%")
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
