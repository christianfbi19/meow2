--[[
    UtilityManager.lua
    ==================
    Companion module to Library.lua.
    Manages optional UI features: SearchBar, Undo/Redo, Changes Log,
    Active Toggles Widget, and Status Bar.

    Usage (same pattern as ThemeManager / SaveManager):

        local UtilityManager = loadstring(game:HttpGet('...UtilityManager.lua'))()
        UtilityManager:SetLibrary(Library)
        UtilityManager:BuildPage(Tab)

    The settings are persisted via writefile/readfile as
    "LinoriaUtilityManager.json" in the executor's workspace.
--]]

local UtilityManager = {
    Library = nil;
    -- Default states (may be overridden by saved file)
    Settings = {
        SearchBar           = true;
        UndoRedo            = true;
        ChangesLog          = true;
        ActiveTogglesWidget = true;
        StatusBar           = false;
    };
    _SettingsFile = 'LinoriaUtilityManager.json';
};

-- ============================================================
-- Internal helpers
-- ============================================================
local function safeJSON(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then return nil end
    return result
end

function UtilityManager:Save()
    if not (writefile and game:GetService('HttpService')) then return end
    pcall(function()
        local data = game:GetService('HttpService'):JSONEncode(self.Settings)
        writefile(self._SettingsFile, data)
    end)
end

function UtilityManager:Load()
    pcall(function()
        if not (isfile and readfile and game:GetService('HttpService')) then return end
        if not isfile(self._SettingsFile) then return end
        local raw = readfile(self._SettingsFile)
        local data = game:GetService('HttpService'):JSONDecode(raw)
        for k, v in next, data do
            if self.Settings[k] ~= nil then
                self.Settings[k] = v
            end
        end
    end)
end

function UtilityManager:ApplyToLibrary()
    local L = self.Library
    if not L then return end
    -- Sync Library.UtilitySettings from our Settings table
    for k, v in next, self.Settings do
        L.UtilitySettings[k] = v
    end
    -- Apply widget visibility states
    if L.SetStatusBarVisibility then
        L:SetStatusBarVisibility(self.Settings.StatusBar)
    end
    if L.SetActiveTogglesWidgetVisibility then
        L:SetActiveTogglesWidgetVisibility(self.Settings.ActiveTogglesWidget)
    end
end

-- ============================================================
-- SetLibrary
-- ============================================================
function UtilityManager:SetLibrary(Library)
    self.Library = Library
    self:Load()
    self:ApplyToLibrary()
end

-- ============================================================
-- BuildPage
-- ============================================================
--[[
    Builds the utility settings UI into a provided groupbox or tab.
    Recommended usage:

        local UtilTab = Window:AddTab('UI Settings')
        local UtilBox = UtilTab:AddLeftGroupbox('Utility')
        UtilityManager:BuildPage(UtilBox)
--]]
function UtilityManager:BuildPage(Groupbox)
    local L = self.Library
    assert(L, 'UtilityManager: Call :SetLibrary(Library) before :BuildPage()')
    assert(Groupbox, 'UtilityManager: BuildPage requires a Groupbox argument.')

    local idPrefix = '__UtilMgr_'

    -- ---- Search Bar ----
    Groupbox:AddToggle(idPrefix .. 'SearchBar', {
        Text = 'Search Bar';
        Default = self.Settings.SearchBar;
        Tooltip = 'Enable the per-tab search bar (filter elements by name)';
        Callback = function(v)
            self.Settings.SearchBar = v
            L.UtilitySettings.SearchBar = v
            self:Save()
        end;
    })

    -- ---- Undo / Redo ----
    Groupbox:AddToggle(idPrefix .. 'UndoRedo', {
        Text = 'Undo / Redo  (Ctrl+Z / Ctrl+Y)';
        Default = self.Settings.UndoRedo;
        Tooltip = 'Enable Ctrl+Z / Ctrl+Y undo and redo while the menu is open. Applies to toggles and sliders.';
        Callback = function(v)
            self.Settings.UndoRedo = v
            L.UtilitySettings.UndoRedo = v
            if not v then
                L.UndoStack = {}
                L.RedoStack = {}
            end
            self:Save()
        end;
    })

    -- ---- Recent Changes Log ----
    Groupbox:AddToggle(idPrefix .. 'ChangesLog', {
        Text = 'Recent Changes Log';
        Default = self.Settings.ChangesLog;
        Tooltip = 'Enable the slide-out log panel (click "Log" in the title bar to open it).';
        Callback = function(v)
            self.Settings.ChangesLog = v
            L.UtilitySettings.ChangesLog = v
            self:Save()
        end;
    })

    -- ---- Active Toggles Widget ----
    Groupbox:AddToggle(idPrefix .. 'ATWidget', {
        Text = 'Active Toggles Widget';
        Default = self.Settings.ActiveTogglesWidget;
        Tooltip = 'Show a floating list of currently enabled toggles.';
        Callback = function(v)
            self.Settings.ActiveTogglesWidget = v
            L.UtilitySettings.ActiveTogglesWidget = v
            if L.SetActiveTogglesWidgetVisibility then
                L:SetActiveTogglesWidgetVisibility(v)
            end
            self:Save()
        end;
    })

    -- ---- Status Bar ----
    Groupbox:AddToggle(idPrefix .. 'StatusBar', {
        Text = 'Status Bar  (FPS / Ping / Uptime)';
        Default = self.Settings.StatusBar;
        Tooltip = 'Show the floating status bar at the bottom of the screen.';
        Callback = function(v)
            self.Settings.StatusBar = v
            L.UtilitySettings.StatusBar = v
            if L.SetStatusBarVisibility then
                L:SetStatusBarVisibility(v)
            end
            self:Save()
        end;
    })

    Groupbox:AddDivider()

    -- ---- Undo stack max size ----
    Groupbox:AddSlider(idPrefix .. 'UndoMax', {
        Text = 'Undo Stack Limit';
        Default = L._UndoMax or 50;
        Min = 5; Max = 100; Rounding = 0;
        Tooltip = 'Maximum number of undo entries to keep.';
        Callback = function(v)
            L._UndoMax = v
            -- trim if needed
            while #L.UndoStack > v do table.remove(L.UndoStack, 1) end
            while #L.RedoStack > v do table.remove(L.RedoStack, 1) end
        end;
    })

    Groupbox:AddDivider()

    -- ---- Undo/Redo clear button ----
    Groupbox:AddButton({
        Text = 'Clear Undo / Redo History';
        Func = function()
            L.UndoStack = {}
            L.RedoStack = {}
            L:Notify('Undo/Redo history cleared.', 2)
        end;
        Tooltip = 'Wipe the current undo and redo stacks.';
    })

    -- ---- Clear Change Log button ----
    Groupbox:AddButton({
        Text = 'Clear Changes Log';
        Func = function()
            L._ChangeLog = {}
            if L._ChangeLogUI then L._ChangeLogUI.Refresh() end
            L:Notify('Changes log cleared.', 2)
        end;
        Tooltip = 'Clear all entries from the recent changes log.';
    })

    return self
end

return UtilityManager
