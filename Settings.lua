-- BazDrawer Settings
-- Landing page + Settings subcategory + Widgets subcategory.
-- The Widgets subcategory uses BazCore's list/detail options pattern
-- (same shape BazBars uses for per-bar options).

local addon = BazCore:GetAddon("BazDrawer")

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

---------------------------------------------------------------------------
-- Per-widget options group (built dynamically per widget)
---------------------------------------------------------------------------

local function BuildWidgetGroup(widget, index, total)
    local id = widget.id
    local args = {
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

        orderHeader = { order = 10, type = "header", name = "Order" },
        moveUp = {
            order = 11,
            type = "execute",
            name = "Move Up",
            desc = "Move this widget one position up in the drawer's slot stack.",
            func = function() addon:MoveWidgetUp(id) end,
            disabled = function() return index <= 1 end,
        },
        moveDown = {
            order = 12,
            type = "execute",
            name = "Move Down",
            desc = "Move this widget one position down in the drawer's slot stack.",
            func = function() addon:MoveWidgetDown(id) end,
            disabled = function() return index >= total end,
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

    return {
        order = index,
        type = "group",
        name = widget.label or id,
        desc = "Configure " .. (widget.label or id),
        args = args,
    }
end

local function GetWidgetsOptionsTable()
    local sorted = addon:GetSortedWidgets() or {}
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
                name = "Widgets",
                args = widgetArgs,
            },
        },
    }
end

---------------------------------------------------------------------------
-- Global Options (applies to all widgets at once)
---------------------------------------------------------------------------

local function GetGlobalOptionsTable()
    return BazCore:CreateGlobalOptionsPage("BazDrawer", {
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
    return BazCore:CreateModulesPage("BazDrawer", {
        description = "Enable or disable widgets. Disabled widgets are hidden entirely — not docked in the drawer, not floating, not visible anywhere. Re-enable to restore.",
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
-- Register pages
---------------------------------------------------------------------------

BazCore:QueueForLogin(function()
    if not BazCore.RegisterOptionsTable then return end

    -- Landing page (user manual)
    BazCore:RegisterOptionsTable("BazDrawer", function()
        return BazCore:CreateLandingPage("BazDrawer", {
            subtitle = "Slide-out side drawer for Baz Suite widgets",

            description =
                "BazDrawer is a full-height slide-out panel that docks " ..
                "to either the left or right edge of your screen and " ..
                "hosts a vertical stack of widgets. Out of the box it " ..
                "ships with a Quest Tracker (replaces Blizzard's default " ..
                "objective tracker), a Repair widget, a Minimap widget " ..
                "that reparents the real Blizzard minimap, a Minimap " ..
                "Info Bar (zone text, clock, calendar, and tracking), " ..
                "and a Minimap Buttons collector that adopts LibDBIcon " ..
                "buttons from other addons.\n\n" ..

                "The drawer is built around three concepts:\n" ..
                "• A persistent slide-out panel that fades down to a " ..
                "discreet outline when you're not interacting with it " ..
                "and pops back to full opacity on hover.\n" ..
                "• A pull-tab handle on the active edge for one-click " ..
                "open/close, plus an invisible edge hot zone that re-" ..
                "reveals the tab when the drawer is collapsed.\n" ..
                "• A widget host that uniformly scales each widget to " ..
                "the drawer's chosen width and stacks them vertically " ..
                "with collapsible per-widget title bars.\n\n" ..

                "Other Baz Suite addons (and your own addons) can " ..
                "register their own widgets via the BazCore Dockable " ..
                "Widget API and they'll appear inside BazDrawer " ..
                "automatically with no further wiring.",

            features =
                "DRAWER\n" ..
                "• Slide-out side panel with a metal pull-tab handle on the active edge.\n" ..
                "• Switchable side (left or right) — the tab and slide direction flip automatically.\n" ..
                "• Configurable width with live re-scaling of every docked widget.\n" ..
                "• Edge hot zone — a full-screen-height invisible strip on the active edge re-reveals the tab when the drawer is collapsed, even if the cursor is nowhere near the tab itself.\n" ..
                "• Background and frame opacity sliders for fine control over the drawer's at-rest look.\n\n" ..

                "FADE SYSTEM\n" ..
                "• Backdrop, border, tab, and chrome (label / count / info button) fade as a single unit, while docked widget content stays at full opacity so it remains readable.\n" ..
                "• Configurable fade delay, fade duration, and faded opacity target.\n" ..
                "• Optional 'force full opacity in combat' mode.\n" ..
                "• Optional 'fade tab when closed' so the tab is always visible.\n\n" ..

                "LOCK SYSTEM\n" ..
                "• Padlock icon in the drawer's bottom title bar (visible on hover).\n" ..
                "• When locked: drawer cannot collapse, edge hot zone is disabled, all chrome (label / count / info button) is hidden, widget title bar space is collapsed for a tighter layout, and fade-related settings are greyed out.\n\n" ..

                "WIDGET HOST\n" ..
                "• Per-widget title bars with a click-to-collapse chevron and live status text (e.g. quest count, durability %, mail count).\n" ..
                "• Drag-to-reorder via Move Up / Move Down on each widget's page.\n" ..
                "• Floating mode — detach any widget into its own draggable frame and place it anywhere via Blizzard's Edit Mode.\n" ..
                "• Per-widget enable/disable via the Modules subcategory.\n" ..
                "• Per-widget settings + global overrides via Global Options.\n\n" ..

                "BUILT-IN WIDGETS\n" ..
                "• Quest Tracker — full Blizzard tracker replica with Dungeon/Scenario, Campaign, Quests, and Achievement sections; collapsible group headers; native POI buttons; TomTom integration; and an option to hide Blizzard's default tracker.\n" ..
                "• Repair — three-column layout (paper doll / slot name / durability percent) with three paper-doll modes (custom icon grid, native DurabilityFrame reparented, or none) and an option to permanently hide Blizzard's durability figure.\n" ..
                "• Minimap — reparents the real Blizzard minimap into the drawer at a fixed scale.\n" ..
                "• Minimap Buttons — adopts LibDBIcon and other minimap-attached addon buttons into a tidy grid.\n" ..
                "• Minimap Info Bar — zone text, scaled clock, day-of-month calendar (proxy for GameTimeFrame), and the native tracking dropdown in one bar.\n\n" ..

                "DEVELOPER\n" ..
                "• BazCore DockableWidget API — register a widget from any Baz Suite addon and it appears in BazDrawer automatically.\n" ..
                "• Standard BazCore landing page, settings, modules, global options, widgets, and profiles subcategories.",

            guide = {
                ----------------------------------------------------------------
                -- GETTING STARTED
                ----------------------------------------------------------------
                {
                    "1. First Look",
                    "On first login the drawer appears on the right side " ..
                    "of your screen at the default width with all built-in " ..
                    "widgets enabled and stacked: Info Bar, Minimap, " ..
                    "Minimap Buttons, Quest Tracker, and Repair. Move your " ..
                    "cursor over the drawer to see it pop to full opacity, " ..
                    "then move away and watch it fade back down to its " ..
                    "discreet at-rest state. The metal pull-tab on the " ..
                    "drawer's left edge (when on the right side) is your " ..
                    "primary control — click it to slide the drawer off-" ..
                    "screen, click again to bring it back.",
                },
                {
                    "2. Opening and Closing",
                    "Click the pull-tab to toggle the drawer. When the " ..
                    "drawer is collapsed (slid off-screen), the tab fades " ..
                    "down too — to find it again, just move your cursor " ..
                    "anywhere along the screen edge and it will fade back " ..
                    "into view. You can also use the slash commands /bd " ..
                    "toggle, /bd show, or /bd hide.",
                },
                {
                    "3. Choosing a Side",
                    "BazDrawer → Settings → Layout → Side switches the " ..
                    "drawer between the left and right edge of your screen. " ..
                    "The pull-tab atlas, the slide direction, and the edge " ..
                    "hot zone all flip together automatically. If you " ..
                    "have floating widgets they keep their absolute screen " ..
                    "positions when you flip sides — only the drawer itself " ..
                    "moves.",
                },
                {
                    "4. Choosing a Width",
                    "BazDrawer → Settings → Layout → Width is a slider " ..
                    "between 120 and 400 pixels. Every docked widget " ..
                    "declares a 'design width' it was built for, and the " ..
                    "host computes a uniform scale factor (drawer width " ..
                    "÷ design width) and applies it. So a wider drawer " ..
                    "doesn't add empty space — it makes every widget bigger. " ..
                    "Title bars are NOT scaled so they stay legible.",
                },

                ----------------------------------------------------------------
                -- FADE
                ----------------------------------------------------------------
                {
                    "5. How Fading Works",
                    "BazDrawer fades the drawer chrome — backdrop, border, " ..
                    "tab, and the bottom title bar elements (label, " ..
                    "count, info button) — as a single unit. Docked widget " ..
                    "content always stays at full opacity so quest text, " ..
                    "minimap pings, and repair percentages remain readable " ..
                    "even when the drawer's frame has faded down to its " ..
                    "minimum. The system polls hover state on a tight loop " ..
                    "and tweens between two computed targets via UIFrameFade.",
                },
                {
                    "6. Tuning the Fade",
                    "BazDrawer → Settings → Fading exposes the controls. " ..
                    "Enable Fade is the master switch. Faded Opacity is the " ..
                    "alpha the chrome fades down to (0 = invisible, 1 = no " ..
                    "fade). Fade Delay is the seconds between losing hover " ..
                    "and starting the fade-out. Fade Duration is how long " ..
                    "the fade animation takes. Edge Reveal Distance sets " ..
                    "the width of the invisible edge hot zone — a wider " ..
                    "strip is more forgiving when finding the tab.",
                },
                {
                    "7. Combat Fade Behavior",
                    "Disable Fade In Combat forces the chrome back to full " ..
                    "opacity for the duration of any combat encounter. " ..
                    "Useful if you want the drawer to be unmissable while " ..
                    "you're being attacked. When unchecked the drawer just " ..
                    "keeps fading normally regardless of combat state.",
                },
                {
                    "8. Tab-When-Closed",
                    "Fade Tab When Closed (default on) lets the pull-tab " ..
                    "fade alongside the rest of the chrome when the drawer " ..
                    "is collapsed. Turn it off if you want the tab to stay " ..
                    "permanently visible at full opacity (you'll lose the " ..
                    "edge-reveal magic but you'll never lose the tab).",
                },

                ----------------------------------------------------------------
                -- LOCK
                ----------------------------------------------------------------
                {
                    "9. The Lock System",
                    "The padlock icon at the bottom-right of the drawer's " ..
                    "title bar (only visible while you're hovering the " ..
                    "drawer) toggles 'locked' mode. The lock is the " ..
                    "minimalist preset for users who have everything dialed " ..
                    "in and just want the widgets to sit there quietly.",
                },
                {
                    "10. What Locking Does",
                    "When locked: the drawer cannot collapse via clicking " ..
                    "the tab or hovering the edge; the chrome's label, " ..
                    "widget count, and info button are hidden; the widget " ..
                    "title bar space is collapsed so widgets pack tightly " ..
                    "against each other instead of leaving a gap where the " ..
                    "title bar used to be; and every fade / opacity setting " ..
                    "is greyed out in the options panel. Hovering the " ..
                    "drawer still shows the lock icon (and only the lock " ..
                    "icon) so you can unlock again.",
                },
                {
                    "11. Lock vs Hide vs Collapse",
                    "These three concepts are distinct: COLLAPSE slides " ..
                    "the entire drawer off-screen leaving just the tab. " ..
                    "LOCK keeps the drawer open but freezes layout and " ..
                    "removes chrome. HIDE (per-widget collapse via the " ..
                    "title bar chevron) shrinks one widget down to just " ..
                    "its title bar without affecting any other widgets.",
                },

                ----------------------------------------------------------------
                -- MODULES & WIDGETS
                ----------------------------------------------------------------
                {
                    "12. Enabling and Disabling Widgets",
                    "BazDrawer → Modules lists every registered widget " ..
                    "with an on/off toggle. Disabling a widget unregisters " ..
                    "its docking slot entirely (the slot disappears, the " ..
                    "drawer reflows to fill the gap, and any per-widget " ..
                    "events are stopped). Enabling re-creates the slot in " ..
                    "the widget's saved position. Some widgets — like the " ..
                    "Repair widget — keep doing background work while " ..
                    "disabled (e.g. hiding Blizzard's durability figure).",
                },
                {
                    "13. Reordering Widgets",
                    "BazDrawer → Widgets opens a list of every widget with " ..
                    "Move Up and Move Down buttons on each. Reordering is " ..
                    "instant: the drawer reflows the slot stack as soon " ..
                    "as you click. The order is persisted per-character " ..
                    "(or per-profile if you switch profiles).",
                },
                {
                    "14. Per-Widget Settings",
                    "Each widget has its own page under BazDrawer → " ..
                    "Widgets → [Widget Name]. The page includes the " ..
                    "Floating toggle, Move Up/Down, and any options the " ..
                    "widget exposes via its GetOptionsArgs hook. Examples: " ..
                    "Repair has paper-doll mode and 'hide default frame'; " ..
                    "Quest Tracker has max height, hide default tracker, " ..
                    "and TomTom integration toggles; Minimap has scale " ..
                    "and decoration padding.",
                },
                {
                    "15. Global Options",
                    "BazDrawer → Global Options is the place to set " ..
                    "defaults that apply to all widgets at once. Each " ..
                    "global override has an enable toggle plus a value " ..
                    "widget — when enabled, that key's global value " ..
                    "overrides the local per-widget value of the same " ..
                    "name. Examples: Fade Title Bar (default on for all " ..
                    "widgets), Fade Background. Per-widget settings " ..
                    "always lose to an enabled global override.",
                },
                {
                    "16. Per-Widget Collapse",
                    "Every docked widget has a clickable title bar with " ..
                    "a chevron on the right. Clicking the chevron (or the " ..
                    "title bar itself) collapses just that widget's " ..
                    "content area, leaving only the title bar visible. " ..
                    "The drawer reflows to close the gap. Click again to " ..
                    "expand. Per-widget collapse state is persisted.",
                },
                {
                    "17. Floating a Widget",
                    "On a widget's settings page, check Floating. The " ..
                    "widget detaches from the drawer slot, parents itself " ..
                    "to UIParent, and registers with BazCore's Edit Mode " ..
                    "system. Open Blizzard's Edit Mode to grab the widget " ..
                    "and drag it to wherever you want. Uncheck Floating to " ..
                    "dock it back into the drawer at its previous slot " ..
                    "position. Floating widgets keep their per-widget " ..
                    "settings (collapsed state, options, etc.) intact.",
                },

                ----------------------------------------------------------------
                -- WIDGETS
                ----------------------------------------------------------------
                {
                    "18. Quest Tracker",
                    "Quest Tracker replicates Blizzard's default objective " ..
                    "tracker as a BazDrawer widget. It's pure read-only " ..
                    "polling of the C_QuestLog API, so it's taint-safe " ..
                    "even when reparented or floated. Tracked quests are " ..
                    "binned into sections (Dungeon/Scenario, Campaign, " ..
                    "Questlines, Legendary, Callings, Quests, Achievements) " ..
                    "with collapsible group headers using Blizzard's own " ..
                    "ornamental atlases.",
                },
                {
                    "19. Quest Tracker — Dungeon/Scenario Section",
                    "When you enter a dungeon, raid, M+, delve, scenario, " ..
                    "or pet battle, a 'Dungeon' (or scenario name) section " ..
                    "appears at the very top of the tracker with a " ..
                    "decorative stage block (using Blizzard's trackerheader " ..
                    "atlas) showing the encounter list. Each criterion " ..
                    "shows as a graphical orb that turns into a green " ..
                    "checkmark when complete. The section auto-disappears " ..
                    "when you leave the instance.",
                },
                {
                    "20. Quest Tracker — Pagination",
                    "When the tracker has more quests than fit in the " ..
                    "configured Max Height, scroll up/down with the mouse " ..
                    "wheel — entire quests appear and disappear atomically " ..
                    "(no half-cut quests). Each quest is its own 'mini " ..
                    "widget' that the tracker pages through one at a time.",
                },
                {
                    "21. Quest Tracker — TomTom Integration",
                    "If TomTom is installed, the tracker can automatically " ..
                    "set a TomTom waypoint to your super-tracked quest's " ..
                    "next objective whenever you change super-track. The " ..
                    "previous waypoint is removed before each new one is " ..
                    "placed so you never accumulate orphan arrows. Toggle " ..
                    "via Quest Tracker → Integrations → TomTom Waypoint.",
                },
                {
                    "22. Quest Tracker — Hide Default Tracker",
                    "Quest Tracker → Behavior → Hide Default Tracker " ..
                    "(default on) hides Blizzard's native objective " ..
                    "tracker so only this widget is visible. Disable to " ..
                    "show both side by side (useful for debugging or for " ..
                    "users who want both).",
                },
                {
                    "23. Repair Widget",
                    "Repair shows a three-column layout: paper doll / " ..
                    "damaged-slot list / durability percent. Worst-damaged " ..
                    "slots are listed first, color-graded from green " ..
                    "(100%) through yellow (50%) to red (0%). The bottom-" ..
                    "right title bar status text shows your average " ..
                    "durability percent across all gear.",
                },
                {
                    "24. Repair — Paper Doll Modes",
                    "Repair → Appearance → Paper Doll has three modes: " ..
                    "'Custom (slot icons)' draws a 2×5 grid of slot icons " ..
                    "tinted by their individual durability; 'Blizzard " ..
                    "(native DurabilityFrame)' reparents the real Blizzard " ..
                    "armored figure into the widget at a slight upscale; " ..
                    "'None' hides the paper-doll column entirely so only " ..
                    "the damaged list shows.",
                },
                {
                    "25. Repair — Hide Default Durability Frame",
                    "Repair → Behavior → Hide Default Durability Frame " ..
                    "(default on) prevents Blizzard's native armored " ..
                    "figure from popping up in the middle of your screen " ..
                    "when gear drops below 50%. The hide is robust: the " ..
                    "frame's Show method is locked to Hide so Blizzard's " ..
                    "auto-show on durability events is suppressed. The " ..
                    "option works even when the Repair widget itself is " ..
                    "disabled.",
                },
                {
                    "26. Minimap Widget",
                    "Minimap reparents the real Blizzard minimap into a " ..
                    "BazDrawer widget at a fixed scale. The widget " ..
                    "computes its design width based on the minimap's " ..
                    "native size plus a visual padding for the cardinal " ..
                    "decoration arrows that extend past the raw GetWidth.",
                },
                {
                    "27. Minimap Buttons Widget",
                    "Minimap Buttons adopts LibDBIcon and other addon-" ..
                    "registered minimap buttons into a tidy grid inside " ..
                    "the drawer. A blacklist excludes Blizzard's own " ..
                    "minimap children (zoom, mail icon, etc.). The widget " ..
                    "scans for buttons 1.5 seconds after login to give " ..
                    "LibDBIcon-using addons time to register theirs.",
                },
                {
                    "28. Minimap Info Bar",
                    "Info Bar shows zone name (left), then a tightly " ..
                    "grouped right cluster of: scaled clock (1.25x to " ..
                    "match icon weight), day-of-month calendar button " ..
                    "(custom proxy that shares the tracking button's " ..
                    "bevel atlas), and the native minimap tracking " ..
                    "dropdown. The calendar button is a custom Button — " ..
                    "we don't reparent the real GameTimeFrame because " ..
                    "doing so taints Blizzard's secure code paths.",
                },

                ----------------------------------------------------------------
                -- ADVANCED
                ----------------------------------------------------------------
                {
                    "29. Edit Mode Integration",
                    "Floating widgets register themselves as Edit Mode " ..
                    "frames via BazCore's RegisterEditModeFrame helper. " ..
                    "Open Blizzard's Edit Mode and you'll see the floating " ..
                    "widgets selectable alongside Blizzard's own frames, " ..
                    "with a settings popup that translates each widget's " ..
                    "GetOptionsArgs into Edit Mode controls. Reset Position " ..
                    "and Nudge actions are included. Docked widgets are " ..
                    "NOT individually selectable in Edit Mode — only the " ..
                    "whole drawer is.",
                },
                {
                    "30. Profiles",
                    "BazDrawer → Profiles is the standard BazCore profile " ..
                    "subcategory. Use it to copy/share/reset settings, " ..
                    "make a per-character or per-spec profile, and export/" ..
                    "import via the BazCore profile manager. All BazDrawer " ..
                    "settings (including widget order, collapsed states, " ..
                    "per-widget options, and global overrides) live inside " ..
                    "the active profile.",
                },
                {
                    "31. Adding Your Own Widgets",
                    "Any addon can call BazCore:RegisterDockableWidget({ " ..
                    "id, label, designWidth, designHeight, frame, " ..
                    "GetDesiredHeight, GetStatusText, GetOptionsArgs, " ..
                    "OnDock, OnUndock }) and the widget will appear inside " ..
                    "BazDrawer automatically. The widget contract is " ..
                    "documented in BazCore's developer reference. Make " ..
                    "sure your widget polls game state read-only — never " ..
                    "reparent secure (protected) frames into the drawer " ..
                    "or you'll taint downstream Blizzard code.",
                },
                {
                    "32. Troubleshooting",
                    "If the drawer disappears and you can't get it back: " ..
                    "type /bd show. If a widget gets stuck floating off-" ..
                    "screen: open its widget page and toggle Floating off " ..
                    "and on. If the fade looks wrong after changing combat " ..
                    "state: force a refresh by hovering and unhovering the " ..
                    "drawer. If a setting won't change: check that the " ..
                    "drawer isn't locked (the padlock icon will tell you).",
                },
            },

            commands = {
                { "/bd toggle", "Open or close the drawer" },
                { "/bd show",   "Open the drawer" },
                { "/bd hide",   "Close the drawer" },
                { "/bdrawer",   "Same as /bd (full alias for all subcommands)" },
            },
        })
    end)
    BazCore:AddToSettings("BazDrawer", "BazDrawer")

    -- Settings subcategory
    BazCore:RegisterOptionsTable("BazDrawer-Settings", GetSettingsOptionsTable)
    BazCore:AddToSettings("BazDrawer-Settings", "Settings", "BazDrawer")

    -- Global Options subcategory (per-key overrides across all widgets)
    BazCore:RegisterOptionsTable("BazDrawer-GlobalOptions", GetGlobalOptionsTable)
    BazCore:AddToSettings("BazDrawer-GlobalOptions", "Global Options", "BazDrawer")

    -- Modules subcategory (flat enable/disable toggles, built by BazCore)
    BazCore:RegisterOptionsTable("BazDrawer-Modules", GetModulesOptionsTable)
    BazCore:AddToSettings("BazDrawer-Modules", "Modules", "BazDrawer")

    -- Widgets subcategory (list/detail — same shape as BazBars' Bar Options)
    BazCore:RegisterOptionsTable("BazDrawer-Widgets", GetWidgetsOptionsTable)
    BazCore:AddToSettings("BazDrawer-Widgets", "Widgets", "BazDrawer")
end)
