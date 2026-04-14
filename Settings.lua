-- BazWidgetDrawers Settings
-- Landing page + Settings subcategory + Widgets subcategory.
-- The Widgets subcategory uses BazCore's list/detail options pattern
-- (same shape BazBars uses for per-bar options).

local addon = BazCore:GetAddon("BazWidgetDrawers")

---------------------------------------------------------------------------
-- General settings (side + width + toggle)
---------------------------------------------------------------------------

local function GetSettingsOptionsTable()
    return {
        name = "Settings",
        type = "group",
        args = {
            layoutHeader = {
                order = 1,
                type = "header",
                name = "Layout",
            },
            side = {
                order = 2,
                type = "select",
                name = "Screen Side",
                desc = "Which edge of the screen the drawer slides out from.",
                values = { right = "Right", left = "Left" },
                get = function() return addon:GetSetting("side") or "right" end,
                set = function(_, val)
                    if addon.Drawer then addon.Drawer:SetSide(val) end
                end,
            },
            width = {
                order = 3,
                type = "range",
                name = "Drawer Width",
                desc = "Width of the drawer. Docked widgets scale proportionally to fill this width.",
                min = (addon.Drawer and addon.Drawer.MIN_WIDTH) or 120,
                max = (addon.Drawer and addon.Drawer.MAX_WIDTH) or 400,
                step = 2,
                get = function()
                    return addon:GetSetting("width")
                        or (addon.Drawer and addon.Drawer.DEFAULT_WIDTH)
                        or 222
                end,
                set = function(_, val)
                    if addon.Drawer then addon.Drawer:SetWidth(val) end
                end,
            },
            behaviorHeader = {
                order = 10,
                type = "header",
                name = "Behavior",
            },
            toggle = {
                order = 11,
                type = "execute",
                name = "Toggle Drawer",
                desc = "Open or close the drawer now.",
                func = function()
                    if addon.Drawer then addon.Drawer:Toggle() end
                end,
            },

            appearanceHeader = {
                order = 20,
                type = "header",
                name = "Appearance",
            },
            backgroundOpacity = {
                order = 21,
                type = "range",
                name = "Background Opacity",
                desc = "Alpha of the drawer's backdrop fill (the dark panel colour).",
                min = 0, max = 1, step = 0.05,
                get = function() return addon:GetSetting("backgroundOpacity") or 0.9 end,
                set = function(_, val)
                    addon:SetSetting("backgroundOpacity", val)
                    if addon.Drawer then addon.Drawer:ApplyAppearance() end
                end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },
            frameOpacity = {
                order = 22,
                type = "range",
                name = "Frame Opacity",
                desc = "Maximum alpha of the drawer's border and tab chrome when fully visible. Docked widgets always stay at full opacity.",
                min = 0.2, max = 1, step = 0.05,
                get = function() return addon:GetSetting("frameOpacity") or 1.0 end,
                set = function(_, val)
                    addon:SetSetting("frameOpacity", val)
                    if addon.Drawer then addon.Drawer:EvaluateFade(true) end
                end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },

            fadingHeader = {
                order = 30,
                type = "header",
                name = "Fading",
            },
            fadeEnabled = {
                order = 31,
                type = "toggle",
                name = "Enable Fade",
                desc = "Fade the drawer's backdrop and tab when the mouse isn't over it. Docked widgets stay at full opacity so their content is always readable.",
                get = function() return addon:GetSetting("fadeEnabled") ~= false end,
                set = function(_, val)
                    addon:SetSetting("fadeEnabled", val)
                    if addon.Drawer then addon.Drawer:EvaluateFade(true) end
                end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },
            fadedOpacity = {
                order = 32,
                type = "range",
                name = "Faded Opacity",
                desc = "Target alpha when the drawer is faded out.",
                min = 0, max = 1, step = 0.05,
                get = function() return addon:GetSetting("fadedOpacity") or 0.3 end,
                set = function(_, val)
                    addon:SetSetting("fadedOpacity", val)
                    if addon.Drawer then addon.Drawer:EvaluateFade(true) end
                end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },
            fadeDelay = {
                order = 33,
                type = "range",
                name = "Fade Delay",
                desc = "Seconds to wait after the mouse leaves before starting to fade.",
                min = 0, max = 5, step = 0.1,
                get = function() return addon:GetSetting("fadeDelay") or 1.0 end,
                set = function(_, val) addon:SetSetting("fadeDelay", val) end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },
            fadeDuration = {
                order = 34,
                type = "range",
                name = "Fade Duration",
                desc = "Length of the fade animation in seconds.",
                min = 0.05, max = 2, step = 0.05,
                get = function() return addon:GetSetting("fadeDuration") or 0.3 end,
                set = function(_, val) addon:SetSetting("fadeDuration", val) end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },
            edgeRevealPx = {
                order = 35,
                type = "range",
                name = "Edge Reveal Distance",
                desc = "Width of the invisible hot zone along the active screen edge. Moving the cursor anywhere inside this strip reveals the tab when the drawer is closed.",
                min = 2, max = 50, step = 1,
                get = function() return addon:GetSetting("edgeRevealPx") or 8 end,
                set = function(_, val)
                    addon:SetSetting("edgeRevealPx", val)
                    if addon.Drawer and addon.Drawer.ApplyEdgeHotZone then
                        addon.Drawer:ApplyEdgeHotZone()
                    end
                end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },
            fadeTabWhenClosed = {
                order = 36,
                type = "toggle",
                name = "Fade Tab When Closed",
                desc = "When off, the tab stays at full opacity while the drawer is collapsed (edge reveal no longer needed).",
                get = function() return addon:GetSetting("fadeTabWhenClosed") ~= false end,
                set = function(_, val)
                    addon:SetSetting("fadeTabWhenClosed", val)
                    if addon.Drawer then addon.Drawer:EvaluateFade(true) end
                end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },
            disableFadeInCombat = {
                order = 37,
                type = "toggle",
                name = "Disable Fade In Combat",
                desc = "Force full opacity whenever you're in combat, ignoring fade settings.",
                get = function() return addon:GetSetting("disableFadeInCombat") and true or false end,
                set = function(_, val)
                    addon:SetSetting("disableFadeInCombat", val)
                    if addon.Drawer then addon.Drawer:EvaluateFade(true) end
                end,
                disabled = function() return addon:GetSetting("locked") and true or false end,
            },
        },
    }
end

-- Build a combined list of all widgets (active + dormant inactive),
-- sorted by saved order. Used for the settings list and reorder ops.
local function GetAllWidgetsSorted()
    local sorted = addon:GetSortedWidgets() or {}
    local seen = {}
    for _, w in ipairs(sorted) do seen[w.id] = true end

    -- Append dormant (inactive) widgets
    local LBW = LibStub and LibStub("LibBazWidget-1.0", true)
    if LBW and LBW.dormant then
        for id, entry in pairs(LBW.dormant) do
            if not entry.active and not seen[id] then
                sorted[#sorted + 1] = entry.widget
            end
        end
    end

    -- Re-sort the full list by saved order so dormant widgets
    -- appear in their correct position, not just appended
    table.sort(sorted, function(a, b)
        local oa = addon:GetWidgetOrder(a.id) or 10000
        local ob = addon:GetWidgetOrder(b.id) or 10000
        if oa == ob then return (a.id or "") < (b.id or "") end
        return oa < ob
    end)

    return sorted
end

-- Move a widget up/down in the combined list (includes dormant)
local function MoveWidgetInFullList(id, direction)
    local sorted = GetAllWidgetsSorted()
    for i, w in ipairs(sorted) do
        if w.id == id then
            local swapIdx = i + direction
            if swapIdx >= 1 and swapIdx <= #sorted then
                sorted[i], sorted[swapIdx] = sorted[swapIdx], sorted[i]
                for j, sw in ipairs(sorted) do
                    addon:SetWidgetOrder(sw.id, j)
                end
                if addon.WidgetHost and addon.WidgetHost.Reflow then
                    addon.WidgetHost:Reflow()
                end
            end
            return
        end
    end
end

---------------------------------------------------------------------------
-- Per-widget options group (built dynamically per widget)
---------------------------------------------------------------------------

local function BuildWidgetGroup(widget, index, total)
    local id = widget.id
    local args = {
        moveUp = {
            order = 0.1,
            type = "execute",
            name = "Move Up",
            func = function()
                MoveWidgetInFullList(id, -1)
                BazCore:RefreshOptions("BazWidgetDrawers-Widgets")
            end,
            disabled = function() return index <= 1 end,
            width = "half",
        },
        moveDown = {
            order = 0.2,
            type = "execute",
            name = "Move Down",
            func = function()
                MoveWidgetInFullList(id, 1)
                BazCore:RefreshOptions("BazWidgetDrawers-Widgets")
            end,
            disabled = function() return index >= total end,
            width = "half",
        },
        displayHeader = { order = 1, type = "header", name = "Display" },
        floating = {
            order = 2,
            type = "toggle",
            name = "Floating",
            desc = "Detach this widget from the drawer and let it float freely. Use Edit Mode to drag the detached widget to wherever you want.",
            get = function() return addon:IsWidgetFloating(id) end,
            set = function(_, val)
                if addon.WidgetHost and addon.WidgetHost.SetWidgetFloating then
                    addon.WidgetHost:SetWidgetFloating(id, val)
                end
            end,
        },
        collapsed = {
            order = 3,
            type = "toggle",
            name = "Collapsed",
            desc = "Hide the widget's content, leaving only its title bar visible in the drawer.",
            get = function() return addon:IsWidgetCollapsed(id) end,
            set = function(_, val)
                addon:SetWidgetCollapsed(id, val)
                if addon.WidgetHost then addon.WidgetHost:Reflow() end
            end,
            disabled = function() return addon:IsWidgetFloating(id) end,
        },

        fadeHeader = { order = 5, type = "header", name = "Fading" },
        fadeTitleBar = {
            order = 6,
            type = "toggle",
            name = "Fade Title Bar",
            desc = "Fade this widget's title bar with the drawer chrome.",
            get = function()
                return addon:GetWidgetEffectiveSetting(id, "fadeTitleBar", true) ~= false
            end,
            set = function(_, val)
                addon:SetWidgetSetting(id, "fadeTitleBar", val)
                if addon.Drawer then addon.Drawer:EvaluateFade(true) end
            end,
            disabled = function()
                local o = addon:GetSetting("widgetGlobalOverrides")
                return o and o.fadeTitleBar and o.fadeTitleBar.enabled or false
            end,
        },
        fadeBackground = {
            order = 7,
            type = "toggle",
            name = "Fade Background",
            desc = "Fade this widget's background with the drawer chrome.",
            get = function()
                return addon:GetWidgetEffectiveSetting(id, "fadeBackground", true) ~= false
            end,
            set = function(_, val)
                addon:SetWidgetSetting(id, "fadeBackground", val)
                if addon.Drawer then addon.Drawer:EvaluateFade(true) end
            end,
            disabled = function()
                local o = addon:GetSetting("widgetGlobalOverrides")
                return o and o.fadeBackground and o.fadeBackground.enabled or false
            end,
        },

    }

    -- Widgets can supply their own options via widget:GetOptionsArgs()
    if widget.GetOptionsArgs then
        local ok, extra = pcall(widget.GetOptionsArgs, widget)
        if ok and type(extra) == "table" then
            local nextOrder = 20
            for key, opt in pairs(extra) do
                if type(opt) == "table" then
                    opt.order = opt.order or nextOrder
                    nextOrder = nextOrder + 1
                    args[key] = opt
                end
            end
        end
    end

    -- Dormant indicator: tag shows whether a dormant widget is
    -- currently active or sleeping (list panel overrides inline colors)
    local LBW = LibStub and LibStub("LibBazWidget-1.0", true)
    local isDormant = LBW and LBW.dormant and LBW.dormant[id]
    local displayName = widget.label or id
    if isDormant then
        local isActive = LBW:IsDormantWidgetActive(id)
        displayName = displayName .. (isActive and "" or "  [D]")
    end

    return {
        order = index,
        type = "group",
        name = displayName,
        desc = "Configure " .. (widget.label or id),
        args = args,
    }
end

local function GetWidgetsOptionsTable()
    local sorted = GetAllWidgetsSorted()

    local widgetArgs = {}
    for i, widget in ipairs(sorted) do
        widgetArgs["widget_" .. widget.id] = BuildWidgetGroup(widget, i, #sorted)
    end

    return {
        name = "Widgets",
        type = "group",
        args = {
            widgets = {
                order = 1,
                type = "group",
                name = "",
                args = widgetArgs,
            },
        },
    }
end

---------------------------------------------------------------------------
-- Global Options (applies to all widgets at once)
---------------------------------------------------------------------------

local function GetGlobalOptionsTable()
    return BazCore:CreateGlobalOptionsPage("BazWidgetDrawers", {
        getOverrides = function() return addon:GetGlobalOverrides() end,
        setOverride = function(key, field, value)
            addon:SetGlobalOverride(key, field, value)
        end,
        overrides = {
            { key = "fadeTitleBar",   label = "Fade Title Bar",   type = "toggle", default = true },
            { key = "fadeBackground", label = "Fade Background",  type = "toggle", default = true },
        },
    })
end

---------------------------------------------------------------------------
-- Modules subcategory (flat enable/disable toggles for each widget)
---------------------------------------------------------------------------

local function GetModulesOptionsTable()
    return BazCore:CreateModulesPage("BazWidgetDrawers", {
        title = "Enable/Disable",
        description = "Enable or disable widgets. Disabled widgets are hidden entirely - not docked in the drawer, not floating, not visible anywhere. Re-enable to restore.",
        getModules = function()
            local list = {}
            local widgets = BazCore.GetDockableWidgets and BazCore:GetDockableWidgets() or {}
            for _, w in ipairs(widgets) do
                table.insert(list, { id = w.id, name = w.label or w.id })
            end
            return list
        end,
        isEnabled = function(id) return addon:IsWidgetEnabled(id) end,
        setEnabled = function(id, val)
            if addon.WidgetHost and addon.WidgetHost.SetWidgetEnabled then
                addon.WidgetHost:SetWidgetEnabled(id, val)
            else
                addon:SetWidgetEnabled(id, val)
            end
        end,
    })
end

---------------------------------------------------------------------------
-- Drawers subcategory (create/manage/configure drawer tabs)
---------------------------------------------------------------------------

local AUTO_SWITCH_OPTIONS = {
    { value = "",              label = "None (manual only)" },
    { value = "openWorld",     label = "Open World / Questing" },
    { value = "dungeon",      label = "Dungeon (5-man)" },
    { value = "raid",         label = "Raid" },
    { value = "challengeMode", label = "Mythic+ (Challenge Mode)" },
    { value = "delve",        label = "Delve" },
    { value = "battleground",  label = "Battleground" },
    { value = "arena",        label = "Arena" },
}

local function BuildDrawerGroup(drawerDef, drawerId, index, total)
    local allWidgets = BazCore.GetDockableWidgets and BazCore:GetDockableWidgets() or {}

    -- Build auto-switch dropdown values
    local autoValues = {}
    for _, opt in ipairs(AUTO_SWITCH_OPTIONS) do
        autoValues[opt.value] = opt.label
    end

    local args = {
        labelInput = {
            order = 1,
            type = "input",
            name = "Label",
            desc = "Display name shown in the tab tooltip.",
            get = function()
                local def = addon:GetDrawer(drawerId)
                return def and def.label or ""
            end,
            set = function(_, val)
                addon:RenameDrawer(drawerId, val)
                BazCore:RefreshOptions("BazWidgetDrawers-Drawers")
            end,
        },
        chooseIcon = {
            order = 2,
            type = "execute",
            name = "Choose Icon",
            desc = "Pick an icon for this drawer's tab.",
            width = "half",
            func = function()
                BazCore:ShowIconPicker(function(iconId)
                    local drawers = addon:GetSetting("drawers") or {}
                    if drawers[drawerId] then
                        drawers[drawerId].icon = iconId
                        addon:SetSetting("drawers", drawers)
                        if addon.Drawer and addon.Drawer.RefreshTabs then
                            addon.Drawer:RefreshTabs()
                        end
                        BazCore:RefreshOptions("BazWidgetDrawers-Drawers")
                    end
                end, drawerDef.icon)
            end,
        },
        iconPreview = {
            order = 2.5,
            type = "description",
            name = "|T" .. (drawerDef.icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":32:32|t",
        },

        autoHeader = { order = 10, type = "header", name = "Auto-Switch" },
        autoSwitchEnabled = {
            order = 11,
            type = "toggle",
            name = "Enable Auto-Switch",
            desc = "Automatically switch to this drawer when entering the selected game context.",
            get = function()
                local def = addon:GetDrawer(drawerId)
                return def and def.autoSwitchEnabled or false
            end,
            set = function(_, val)
                local drawers = addon:GetSetting("drawers") or {}
                if drawers[drawerId] then
                    drawers[drawerId].autoSwitchEnabled = val
                    addon:SetSetting("drawers", drawers)
                end
            end,
        },
        autoSwitchTrigger = {
            order = 12,
            type = "select",
            name = "Trigger",
            desc = "Game context that activates this drawer.",
            values = autoValues,
            get = function()
                local def = addon:GetDrawer(drawerId)
                return def and def.autoSwitch or ""
            end,
            set = function(_, val)
                local drawers = addon:GetSetting("drawers") or {}
                if drawers[drawerId] then
                    drawers[drawerId].autoSwitch = (val ~= "") and val or nil
                    addon:SetSetting("drawers", drawers)
                end
            end,
            disabled = function()
                local def = addon:GetDrawer(drawerId)
                return not (def and def.autoSwitchEnabled)
            end,
        },

        widgetHeader = { order = 20, type = "header", name = "Widgets" },
        widgetDesc = {
            order = 21,
            type = "description",
            name = "Check which widgets appear in this drawer. A widget can be in multiple drawers.",
        },
    }

    -- Add a toggle for each available widget
    local widgetOrder = 22
    for _, w in ipairs(allWidgets) do
        local wid = w.id
        args["widget_" .. wid] = {
            order = widgetOrder,
            type = "toggle",
            name = w.label or wid,
            get = function()
                return addon:IsWidgetInDrawer(drawerId, wid)
            end,
            set = function(_, val)
                if val then
                    addon:AddWidgetToDrawer(drawerId, wid)
                else
                    addon:RemoveWidgetFromDrawer(drawerId, wid)
                end
                BazCore:RefreshOptions("BazWidgetDrawers-Drawers")
            end,
        }
        widgetOrder = widgetOrder + 1
    end

    -- Also include dormant widgets
    local LBW = LibStub and LibStub("LibBazWidget-1.0", true)
    if LBW and LBW.dormant then
        local seen = {}
        for _, w in ipairs(allWidgets) do seen[w.id] = true end
        for id, entry in pairs(LBW.dormant) do
            if not seen[id] then
                local wid = id
                local wLabel = entry.widget and entry.widget.label or id
                args["widget_" .. wid] = {
                    order = widgetOrder,
                    type = "toggle",
                    name = wLabel .. "  [D]",
                    get = function()
                        return addon:IsWidgetInDrawer(drawerId, wid)
                    end,
                    set = function(_, val)
                        if val then
                            addon:AddWidgetToDrawer(drawerId, wid)
                        else
                            addon:RemoveWidgetFromDrawer(drawerId, wid)
                        end
                    end,
                }
                widgetOrder = widgetOrder + 1
            end
        end
    end

    -- Delete button (can't delete last drawer)
    local drawerCount = 0
    local drawers = addon:GetSetting("drawers") or {}
    for _ in pairs(drawers) do drawerCount = drawerCount + 1 end

    args.deleteHeader = { order = 100, type = "header", name = "" }
    args.deleteDrawer = {
        order = 101,
        type = "execute",
        name = "Delete This Drawer",
        desc = "Permanently remove this drawer tab.",
        func = function()
            addon:DeleteDrawer(drawerId)
            BazCore:RefreshOptions("BazWidgetDrawers-Drawers")
        end,
        disabled = function() return drawerCount <= 1 end,
        confirm = true,
        confirmText = "Are you sure you want to delete the '" .. (drawerDef.label or drawerId) .. "' drawer?",
    }

    return {
        order = index,
        type = "group",
        name = drawerDef.label or drawerId,
        args = args,
    }
end

local function GetDrawersOptionsTable()
    local sorted = addon:GetSortedDrawers()
    local drawerArgs = {}

    for i, entry in ipairs(sorted) do
        drawerArgs["drawer_" .. entry.id] = BuildDrawerGroup(entry.def, entry.id, i, #sorted)
    end

    return {
        name = "Drawers",
        type = "group",
        args = {
            createDrawer = {
                order = 0,
                type = "execute",
                name = "Create New Drawer",
                func = function()
                    -- Generate a unique ID
                    local id = "drawer_" .. time()
                    addon:CreateDrawer(id, "New Drawer")
                    addon:SetActiveDrawer(id)
                    BazCore:RefreshOptions("BazWidgetDrawers-Drawers")
                end,
            },
            drawers = {
                order = 1,
                type = "group",
                name = "",
                args = drawerArgs,
            },
        },
    }
end

---------------------------------------------------------------------------
-- Register pages
---------------------------------------------------------------------------

BazCore:QueueForLogin(function()
    if not BazCore.RegisterOptionsTable then return end

    -- Landing page (user manual)
    BazCore:RegisterOptionsTable("BazWidgetDrawers", function()
        return BazCore:CreateLandingPage("BazWidgetDrawers", {
            subtitle = "Slide-out widget drawer for the Baz Suite",

            description =
                "BazWidgetDrawers is a full-height slide-out panel that docks " ..
                "to either edge of your screen and hosts a vertical stack " ..
                "of widgets. Built-in widgets include a Quest Tracker, " ..
                "Minimap, Minimap Buttons, Info Bar, Zone Text, and Micro " ..
                "Menu. Additional widgets (Dungeon Finder, Repair, and " ..
                "more) are available via the BazWidgets addon pack.\n\n" ..

                "The drawer is built around three concepts:\n" ..
                "* A persistent slide-out panel that fades to invisible " ..
                "when you're not interacting with it and pops back on " ..
                "hover.\n" ..
                "* A pull-tab handle on the active edge for one-click " ..
                "open/close, plus an invisible edge hot zone that re-" ..
                "reveals the tab when collapsed.\n" ..
                "* A widget host that uniformly scales each widget to " ..
                "the drawer's width and stacks them vertically with " ..
                "collapsible, draggable title bars.\n\n" ..

                "Any addon can publish widgets via LibBazWidget-1.0 " ..
                "(or through BazCore's DockableWidget shim) and they'll " ..
                "appear in the drawer automatically. Widgets can also " ..
                "be dormant - they register and unregister themselves " ..
                "based on game state (e.g. Dungeon Finder only appears " ..
                "when you're in a queue).",

            features =
                "DRAWER\n" ..
                "* Slide-out side panel with a metal pull-tab handle.\n" ..
                "* Switchable side (left or right) with automatic flip.\n" ..
                "* Configurable width with live re-scaling of all widgets.\n" ..
                "* Edge hot zone for easy tab re-reveal when collapsed.\n" ..
                "* Background and frame opacity sliders.\n\n" ..

                "FADE SYSTEM\n" ..
                "* Chrome fades as a single unit; widget content stays readable.\n" ..
                "* Configurable delay, duration, and faded opacity (default 0 = invisible).\n" ..
                "* Optional 'force full opacity in combat' mode.\n" ..
                "* Lock icon fades in sync with drawer chrome.\n\n" ..

                "LOCK SYSTEM\n" ..
                "* Padlock icon on the bottom bar (appears on hover, fades with chrome).\n" ..
                "* When locked: drawer stays open, all chrome is hidden, title bars collapse for a tight layout.\n\n" ..

                "WIDGET HOST\n" ..
                "* Per-widget title bars with collapse chevron and live status text.\n" ..
                "* Drag-to-reorder: hold a title bar to grab it (turns green), drag to swap positions.\n" ..
                "* Move Up / Move Down buttons in the settings panel (side by side at top).\n" ..
                "* Floating mode: detach any widget and position it via Edit Mode.\n" ..
                "* Per-widget enable/disable, per-widget settings, and global overrides.\n" ..
                "* Dormant widgets: appear and disappear based on game conditions.\n\n" ..

                "BUILT-IN WIDGETS\n" ..
                "* Zone Text - zone name colored by PVP status.\n" ..
                "* Minimap - reparents the real Blizzard minimap at a fixed scale.\n" ..
                "* Minimap Buttons - adopts LibDBIcon buttons into a tidy grid.\n" ..
                "* Quest Tracker - full tracker replica with Scenario/Campaign/Quest sections, progress bars, quest item buttons, auto-complete popups, and waypoint integration.\n" ..
                "* Micro Menu - reparents the Blizzard micro menu with fade-on-hover.\n" ..
                "* Info Bar - clock, calendar, and tracking button in one row.\n\n" ..

                "BAZWIDGETS ADDON PACK (separate addon)\n" ..
                "* Dungeon Finder - dormant queue status panel (auto-shows when queued).\n" ..
                "* Repair - three-column durability display with paper-doll modes.\n\n" ..

                "DEVELOPER\n" ..
                "* LibBazWidget-1.0 - standalone widget registry library via LibStub.\n" ..
                "* Dormant Widget API - register/unregister widgets based on events + conditions.\n" ..
                "* BazCore DockableWidget shim for backward compatibility.",

            guide = {
                {
                    "1. First Look",
                    "On first login the drawer appears on the right edge " ..
                    "with all built-in widgets stacked: Zone, Minimap, " ..
                    "Minimap Buttons, Quest Tracker, Micro Menu, and Info " ..
                    "Bar. Hover over the drawer to see it appear, move " ..
                    "away and it fades to invisible. The metal pull-tab " ..
                    "on the drawer edge is your primary control - click " ..
                    "to slide it off-screen, click again to bring it back.",
                },
                {
                    "2. Opening and Closing",
                    "Click the pull-tab to toggle the drawer. When " ..
                    "collapsed, move your cursor to the screen edge and " ..
                    "the tab fades back into view. Slash commands: " ..
                    "/bwd toggle, /bwd show, or /bwd hide.",
                },
                {
                    "3. Choosing a Side and Width",
                    "Settings > Layout > Side switches left/right. " ..
                    "Width scales all docked widgets proportionally - " ..
                    "wider drawer means bigger widgets, not empty space.",
                },
                {
                    "4. Fading",
                    "The drawer chrome (backdrop, border, tab, bottom bar) " ..
                    "fades as a unit. Widget content stays at full opacity. " ..
                    "Default faded opacity is 0 (invisible). Tune via " ..
                    "Settings > Fading: delay, duration, opacity target, " ..
                    "combat override, and tab-when-closed behavior.",
                },
                {
                    "5. The Lock",
                    "Hover the drawer to see the padlock icon on the " ..
                    "bottom bar. Click it to lock. When locked: the " ..
                    "drawer stays open permanently, all chrome is hidden, " ..
                    "title bars collapse for a tight layout, and the lock " ..
                    "icon fades in/out with the same timing as the chrome.",
                },
                {
                    "6. Reordering Widgets",
                    "Two ways to reorder: (1) Hold-and-drag a title bar " ..
                    "in the drawer - hold for half a second until it turns " ..
                    "green, then drag up/down. (2) Use the Move Up / Move " ..
                    "Down buttons at the top of each widget's settings " ..
                    "page. Both methods work for dormant widgets too.",
                },
                {
                    "7. Collapsing Widgets",
                    "Click any title bar to collapse that widget's " ..
                    "content, leaving only the title bar visible. Click " ..
                    "again to expand. State is saved per profile.",
                },
                {
                    "8. Floating a Widget",
                    "On a widget's settings page, check Floating to " ..
                    "detach it from the drawer. It becomes a free-floating " ..
                    "frame you can position via Blizzard's Edit Mode. " ..
                    "Uncheck to dock it back in its saved position.",
                },
                {
                    "9. Dormant Widgets",
                    "Some widgets are dormant - they only appear when " ..
                    "relevant. For example, Dungeon Finder only shows " ..
                    "when you're queued. Dormant widgets are marked with " ..
                    "[D] in the Widgets settings list and can still be " ..
                    "reordered and configured while dormant.",
                },
                {
                    "10. Modules",
                    "Modules lists every registered widget with an on/off " ..
                    "toggle. Disabling a widget removes its slot entirely " ..
                    "and stops its events. Re-enabling restores it.",
                },
                {
                    "11. Global Options",
                    "Global Options lets you set defaults that apply to " ..
                    "all widgets at once (e.g. Fade Title Bar, Fade " ..
                    "Background). Enabled globals override per-widget " ..
                    "settings of the same key.",
                },
                {
                    "12. Adding Your Own Widgets",
                    "Use LibBazWidget-1.0 (via LibStub) to register " ..
                    "widgets from any addon - no BazCore dependency " ..
                    "needed. For dormant widgets, use RegisterDormantWidget " ..
                    "with an events list and condition function. See the " ..
                    "BazWidgets addon for reference implementations.",
                },
                {
                    "13. Troubleshooting",
                    "Drawer gone? Type /bwd show. Widget stuck floating " ..
                    "off-screen? Toggle Floating off and on in its settings. " ..
                    "Fade looks wrong? Hover and unhover to refresh. " ..
                    "Setting won't change? Check if the drawer is locked.",
                },
            },

            commands = {
                { "/bwd toggle", "Open or close the drawer" },
                { "/bwd show",   "Open the drawer" },
                { "/bwd hide",   "Close the drawer" },
            },
        })
    end)
    BazCore:AddToSettings("BazWidgetDrawers", "BazWidgetDrawers")

    -- Settings subcategory
    BazCore:RegisterOptionsTable("BazWidgetDrawers-Settings", GetSettingsOptionsTable)
    BazCore:AddToSettings("BazWidgetDrawers-Settings", "Settings", "BazWidgetDrawers")

    -- Global Options subcategory (per-key overrides across all widgets)
    BazCore:RegisterOptionsTable("BazWidgetDrawers-GlobalOptions", GetGlobalOptionsTable)
    BazCore:AddToSettings("BazWidgetDrawers-GlobalOptions", "Global Options", "BazWidgetDrawers")

    -- Drawers subcategory (create/manage drawer tabs)
    BazCore:RegisterOptionsTable("BazWidgetDrawers-Drawers", GetDrawersOptionsTable)
    BazCore:AddToSettings("BazWidgetDrawers-Drawers", "Drawers", "BazWidgetDrawers")

    -- Widgets subcategory (list/detail - same shape as BazBars' Bar Options)
    BazCore:RegisterOptionsTable("BazWidgetDrawers-Widgets", GetWidgetsOptionsTable)
    BazCore:AddToSettings("BazWidgetDrawers-Widgets", "Widgets", "BazWidgetDrawers")

    -- Enable/Disable subcategory (flat enable/disable toggles)
    BazCore:RegisterOptionsTable("BazWidgetDrawers-Modules", GetModulesOptionsTable)
    BazCore:AddToSettings("BazWidgetDrawers-Modules", "Enable/Disable", "BazWidgetDrawers")
end)
