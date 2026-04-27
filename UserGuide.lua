---------------------------------------------------------------------------
-- BazWidgetDrawers User Guide
---------------------------------------------------------------------------

if not BazCore or not BazCore.RegisterUserGuide then return end

BazCore:RegisterUserGuide("BazWidgetDrawers", {
    title = "BazWidgetDrawers",
    intro = "A full-height slide-out drawer that hosts a vertical stack of dockable widgets and fades out of the way when you're not using it.",
    pages = {
        {
            title = "Welcome",
            blocks = {
                { type = "lead", text = "BazWidgetDrawers (BWD) docks to either edge of your screen and holds a stack of widgets. Instead of scattering a dozen small frames around your UI, it gathers everything into one tidy column flush against the edge." },
                { type = "h2", text = "What can dock here?" },
                { type = "list", items = {
                    "Quest Tracker",
                    "Minimap",
                    "Zone Text",
                    "Micro Menu",
                    "Info Bar (server time, latency, FPS, gold)",
                    "Anything from BazWidgets (gold, coords, currencies, stats, ...)",
                    "Any addon's widgets registered through LibBazWidget-1.0",
                }},
                { type = "note", style = "tip", text = "Widget content stays at full opacity even when the drawer chrome is faded - quest text and minimap remain readable at all times." },
            },
        },
        {
            title = "The Drawer",
            blocks = {
                { type = "paragraph", text = "The drawer is a slide-out side panel with chrome that fades when you're not interacting with it." },
                { type = "h3", text = "Pull tab" },
                { type = "paragraph", text = "A metal pull-tab handle (Blizzard atlas art) sits on the screen edge. Click to slide the drawer on or off screen." },
                { type = "h3", text = "Side & width" },
                { type = "list", items = {
                    "|cffffd700Side|r - Left or Right; tab, slide direction, and edge hot zone all flip automatically",
                    "|cffffd700Width|r - 120-400 px; every docked widget rescales uniformly when you change this",
                    "|cffffd700Edge hot zone|r - invisible strip along the screen edge re-reveals the tab when collapsed",
                }},
            },
        },
        {
            title = "Multiple Drawers",
            blocks = {
                { type = "lead", text = "You can run more than one drawer at a time, each with its own preset of widgets, side, width, and visuals." },
                { type = "h3", text = "Tabs" },
                { type = "paragraph", text = "Active drawers appear as tabs along the top. Click a tab to switch which drawer is currently visible." },
                { type = "h3", text = "Common patterns" },
                { type = "table",
                  columns = { "Use case", "Suggested widgets" },
                  rows = {
                      { "Questing",  "Quest Tracker, Minimap, Coordinates" },
                      { "M+",        "Group Frames, Cooldowns, Affixes" },
                      { "PvP",       "Score, Objectives, Speed Monitor" },
                      { "Crafting",  "Currency Bar, Note Pad, Calculator" },
                  },
                },
                { type = "note", style = "info", text = "Switch between presets with a single click - no need to drag widgets in and out." },
            },
        },
        {
            title = "Smart Fade",
            blocks = {
                { type = "paragraph", text = "Chrome (backdrop, border, pull-tab, bottom bar) fades together as a unit using UIFrameFade." },
                { type = "table",
                  columns = { "Setting", "Range", "Default" },
                  rows = {
                      { "Fade Delay",     "0-5 s",       "1 s" },
                      { "Fade Duration",  "0.05-2 s",    "0.4 s" },
                      { "Faded Opacity",  "0-1",         "0 (invisible)" },
                      { "Combat Lock",    "on / off",    "off" },
                  },
                },
                { type = "note", style = "tip", text = "Set Faded Opacity to 0 for a truly invisible drawer. Set it to 0.3 if you'd rather have a hint of where the drawer lives." },
            },
        },
        {
            title = "Lock Mode",
            blocks = {
                { type = "lead", text = "Click the padlock icon on the bottom bar (visible on hover) to lock the drawer for a perfectly clean column with no chrome." },
                { type = "h3", text = "What locking does" },
                { type = "list", items = {
                    "Drawer cannot collapse",
                    "All chrome is hidden (label, widget count, info button)",
                    "Widget title-bar space collapses so widgets pack flush",
                    "Fade settings are greyed out in the options panel",
                }},
                { type = "h3", text = "Unlocking" },
                { type = "paragraph", text = "Hover anywhere on the drawer - the lock icon reappears. Click it to unlock and restore chrome." },
                { type = "note", style = "tip", text = "Lock mode is ideal for screenshots or minimalist UIs." },
            },
        },
        {
            title = "Widgets",
            blocks = {
                { type = "paragraph", text = "Each widget docks with its own title bar, collapse chevron, label, and live status text (quest count, durability %, server time, etc.)." },
                { type = "collapsible", title = "Reordering", style = "h3", collapsed = false, blocks = {
                    { type = "paragraph", text = "Hold a widget's title bar for half a second - it turns green - then drag up or down to swap positions." },
                    { type = "note", style = "info", text = "You can also use the Move Up / Move Down buttons in the widget's settings page." },
                }},
                { type = "collapsible", title = "Collapse", style = "h3", blocks = {
                    { type = "paragraph", text = "Click the chevron on a widget's title bar to collapse it down to just the title row. Click again to expand." },
                }},
                { type = "collapsible", title = "Floating mode", style = "h3", blocks = {
                    { type = "paragraph", text = "Detach any widget and position it anywhere via Blizzard's Edit Mode. The widget keeps its own slot in the drawer or hides - your choice." },
                }},
                { type = "collapsible", title = "Per-widget settings", style = "h3", blocks = {
                    { type = "paragraph", text = "Each widget exposes its own settings via |cffffd700GetOptionsArgs|r - fade overrides, content options, etc. Settings appear under |cffffd700Widgets > [Widget Name]|r." },
                }},
            },
        },
        {
            title = "Dormant Widgets",
            blocks = {
                { type = "lead", text = "Some widgets are dormant - they only appear in the drawer when a condition is met." },
                { type = "paragraph", text = "Example: the Dungeon Finder widget (from BazWidgets) only registers when you're queued. When you leave the queue, it unregisters entirely - no slot, no title bar, no wasted space." },
                { type = "note", style = "info", text = "Dormant widgets still appear in the Widgets sub-category marked with |cffffd700[D]|r so you can configure them while they're not visible." },
            },
        },
        {
            title = "Global Options",
            blocks = {
                { type = "paragraph", text = "The Global Options sub-category lets you set a value once and have it cascade to every widget." },
                { type = "note", style = "tip", text = "Enable the |cffffd700Title Bar|r override to hide every widget's title bar at once, regardless of per-widget settings." },
            },
        },
        {
            title = "Slash Commands",
            blocks = {
                { type = "table",
                  columns = { "Command", "Effect" },
                  rows = {
                      { "/bwd", "Open the BazWidgetDrawers settings page" },
                  },
                },
            },
        },
    },
})
