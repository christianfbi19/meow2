local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

-- ============================================================
-- Premade Icons table (Roblox asset IDs)
-- ============================================================
local Icons = {
    Gear        = 4812479;
    Star        = 4898081632;
    Eye         = 6026568256;
    EyeOff      = 6031068421;
    Lock        = 6031116680;
    Unlock      = 6031116682;
    Warning     = 6031071374;
    Trash       = 6035047377;
    Search      = 6031071501;
    Check       = 5002666817;
    Cross       = 5002666819;
    Arrow       = 6282522798;
    Info        = 7733960981;
    Plus        = 6026568147;
    Minus       = 6026568255;
    Refresh     = 6022668888;
    Pin         = 6031116537;
    Clock       = 6031071205;
    Pencil      = 6022668998;
    List        = 6031071300;
    Grid        = 6031071235;
    Person      = 6031068359;
    Settings    = 4812479;
    Heart       = 6022668942;
    Thunder     = 6031071572;
    Shield      = 6031071542;
    Fire        = 6031071218;
    Map         = 6031071314;
    Chart       = 6031071177;
    Tag         = 6031071562;
};

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(137, 207, 240);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),

    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Gotham,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;

    Icons = Icons;

    -- Utility settings (toggled via UtilityManager:BuildPage)
    UtilitySettings = {
        SearchBar           = true;
        UndoRedo            = true;
        ChangesLog          = true;
        ActiveTogglesWidget = true;
        StatusBar           = true;
    };

    -- Undo/Redo stacks
    UndoStack = {};
    RedoStack = {};
    _UndoMax  = 50;
    _RecordingUndo = true; -- set false while applying undo/redo

    -- Internal registries for features
    _StatLabels         = {};
    _AllGroupboxes      = {}; -- flat list of every Groupbox object for search/collapse/detach
    _DetachedGroupboxes = {}; -- groupboxes currently floating
    _ChangeLog          = {}; -- session-only recent-changes log
    _ActiveToggles      = {}; -- { idx = Toggle } for enabled toggles widget

    -- Version history (set before CreateWindow)
    VersionHistory = {};
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

-- ============================================================
-- Version History API
-- ============================================================
function Library:SetVersionHistory(History)
    Library.VersionHistory = History or {};
end

-- ============================================================
-- Player utility helpers
-- ============================================================
local function GetPlayersString()
    local PlayerList = Players:GetPlayers();
    for i = 1, #PlayerList do PlayerList[i] = PlayerList[i].Name; end;
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);
    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();
    for i = 1, #TeamList do TeamList[i] = TeamList[i].Name; end;
    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    return TeamList;
end;

-- ============================================================
-- Core helpers
-- ============================================================
function Library:SafeCallback(f, ...)
    if (not f) then return; end;
    if not Library.NotifyOnError then return f(...); end;
    local success, event = pcall(f, ...);
    if not success then
        local _, i = event:find(":%d+: ");
        if not i then return Library:Notify(event); end;
        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then Library.SaveManager:Save(); end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;
    if type(Class) == 'string' then _Instance = Instance.new(Class); end;
    for Property, Value in next, Properties do _Instance[Property] = Value; end;
    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });
    Library:ApplyTextStroke(_Instance);
    Library:AddToRegistry(_Instance, { TextColor3 = 'FontColor'; }, IsHud);
    return Library:Create(_Instance, Properties);
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

-- ============================================================
-- Registry
-- ============================================================
function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = { Instance = Instance; Properties = Properties; Idx = Idx; };
    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;
    if IsHud then table.insert(Library.HudRegistry, Data); end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then table.remove(Library.Registry, Idx); end;
        end;
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then table.remove(Library.HudRegistry, Idx); end;
        end;
        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry(TweenDuration)
    local Duration = TweenDuration or 0;
    for _, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            local targetVal;
            if type(ColorIdx) == 'string' then
                targetVal = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                targetVal = ColorIdx();
            end
            if targetVal ~= nil then
                if Duration > 0 and typeof(targetVal) == 'Color3' then
                    TweenService:Create(Object.Instance, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [Property] = targetVal }):Play();
                else
                    Object.Instance[Property] = targetVal;
                end
            end;
        end;
    end;
end;

-- Animated accent color transition
function Library:AnimateAccentChange(Duration)
    Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);
    Library:UpdateColorsUsingRegistry(Duration or 0.3);
end;

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then Library:RemoveFromRegistry(Instance); end;
end))

-- ============================================================
-- Tooltip + Hover helpers
-- ============================================================
function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        Size = UDim2.fromOffset(X + 5, Y + 4);
        ZIndex = 100;
        Parent = Library.ScreenGui;
        Visible = false;
    })
    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1);
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr;
        TextColor3 = Library.FontColor;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1;
        Parent = Tooltip;
    });
    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor'; });

    local IsHovering = false
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true
        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)
    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx; end;
        end;
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx; end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do Depbox:Update(); end;
end;

-- ============================================================
-- Undo / Redo
-- ============================================================
local function PushUndo(entry)
    if not Library._RecordingUndo then return end
    if not Library.UtilitySettings.UndoRedo then return end
    table.insert(Library.UndoStack, entry)
    if #Library.UndoStack > Library._UndoMax then table.remove(Library.UndoStack, 1) end
    Library.RedoStack = {} -- clear redo on new action
end

local function ApplyUndoEntry(entry, pushTarget)
    Library._RecordingUndo = false
    local obj = entry.obj
    local val = entry.prev
    if obj and obj.SetValue then
        table.insert(pushTarget, { obj = obj, prev = entry.next })
        obj:SetValue(val)
    end
    Library._RecordingUndo = true
end

-- ============================================================
-- Recent Changes Log
-- ============================================================
local function PushChangeLog(text)
    if not Library.UtilitySettings.ChangesLog then return end
    local timestamp = os.date and os.date('%H:%M:%S') or '??:??:??'
    table.insert(Library._ChangeLog, { time = timestamp; text = text; })
    if Library._ChangeLogUI then
        Library._ChangeLogUI.Refresh()
    end
end

-- ============================================================
-- Active Toggles Widget refresh
-- ============================================================
local function RefreshActiveTogglesWidget()
    if Library._ActiveTogglesWidgetRefresh then
        Library._ActiveTogglesWidgetRefresh()
    end
end

-- ============================================================
-- Icon helper: resolve icon value to asset ID string
-- ============================================================
local function ResolveIcon(Icon)
    if type(Icon) == 'number' then
        return 'rbxassetid://' .. tostring(Icon)
    elseif type(Icon) == 'string' then
        local id = Library.Icons[Icon]
        if id then return 'rbxassetid://' .. tostring(id) end
    end
    return nil
end

-- ============================================================
-- MakeDraggable (enhanced: drag callback support)
-- ============================================================
function Library:MakeDraggable(Instance, Cutoff, OnDragStart, OnDragEnd)
    Instance.Active = true;
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );
            if ObjPos.Y > (Cutoff or 40) then return; end;

            if OnDragStart then OnDragStart() end

            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0,
                    Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0,
                    Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                );
                RenderStepped:Wait();
            end;

            if OnDragEnd then OnDragEnd() end
        end;
    end)
end;

-- ============================================================
-- Stat Label system
-- ============================================================
local StatLabelAutoY = 10
local StatLabelSpacing = 28
local StatLabelColumn = {} -- tracks stacked labels

local function RecalcStatLabelPositions()
    local y = 10
    for _, sl in next, StatLabelColumn do
        if sl._autoStack and sl._frame and sl._frame.Parent then
            sl._frame.Position = UDim2.new(1, -(sl._frame.Size.X.Offset + 10), 0, y)
            y = y + sl._frame.Size.Y.Offset + 4
        end
    end
end

function Library:CreateStatLabel(Info)
    assert(Info and Info.Text, 'CreateStatLabel: Missing `Text` field.')

    local labelColor = Info.Color or Library.AccentColor
    local labelSize  = Info.Size or 14
    local displayW   = 160

    local Frame = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.fromOffset(displayW, 22);
        Position = UDim2.new(1, -(displayW + 10), 0, StatLabelAutoY);
        ZIndex = 200;
        Parent = ScreenGui;
    })

    Library:AddToRegistry(Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'AccentColor'; })

    local AccentTop = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 201;
        Parent = Frame;
    })
    Library:AddToRegistry(AccentTop, { BackgroundColor3 = 'AccentColor'; })

    local NameLabel = Library:CreateLabel({
        Position = UDim2.fromOffset(6, 3);
        Size = UDim2.new(0.55, 0, 1, -3);
        TextSize = labelSize;
        Text = Info.Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 202;
        Parent = Frame;
    })

    local ValueLabel = Library:Create('TextLabel', {
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundTransparency = 1;
        Font = Library.Font;
        Position = UDim2.new(1, -6, 0.5, 0);
        Size = UDim2.new(0.4, 0, 0, 16);
        TextColor3 = labelColor;
        TextSize = labelSize;
        TextXAlignment = Enum.TextXAlignment.Right;
        Text = '—';
        TextStrokeTransparency = 0;
        ZIndex = 202;
        Parent = Frame;
    })
    Library:ApplyTextStroke(ValueLabel)

    local StatLabel = {
        _frame = Frame;
        _autoStack = true;
        _stackTimer = nil;
    }

    table.insert(StatLabelColumn, StatLabel)
    RecalcStatLabelPositions()

    -- Draggable: after drag, 30s before auto-resync
    local isDragging = false
    Frame.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(Mouse.X - Frame.AbsolutePosition.X, Mouse.Y - Frame.AbsolutePosition.Y)
            isDragging = true
            StatLabel._autoStack = false
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Frame.Position = UDim2.fromOffset(Mouse.X - ObjPos.X, Mouse.Y - ObjPos.Y)
                RenderStepped:Wait()
            end
            isDragging = false

            -- 30s timer before returning to auto-stack
            if StatLabel._stackTimer then StatLabel._stackTimer:Disconnect() end
            local elapsed = 0
            StatLabel._stackTimer = RunService.Heartbeat:Connect(function(dt)
                elapsed = elapsed + dt
                if elapsed >= 30 then
                    StatLabel._stackTimer:Disconnect()
                    StatLabel._stackTimer = nil
                    StatLabel._autoStack = true
                    RecalcStatLabelPositions()
                end
            end)
        end
    end)

    -- Poll on Heartbeat
    local pollConn
    if Info.GetValue then
        pollConn = RunService.Heartbeat:Connect(function()
            local ok, val = pcall(Info.GetValue)
            if ok then
                ValueLabel.Text = tostring(val)
            end
        end)
        Library:GiveSignal(pollConn)
    end

    function StatLabel:SetText(t)
        NameLabel.Text = t
    end

    function StatLabel:SetValue(v)
        ValueLabel.Text = tostring(v)
    end

    function StatLabel:SetColor(c)
        ValueLabel.TextColor3 = c
    end

    function StatLabel:Destroy()
        if pollConn then pcall(function() pollConn:Disconnect() end) end
        if StatLabel._stackTimer then StatLabel._stackTimer:Disconnect() end
        -- remove from column
        for i = #StatLabelColumn, 1, -1 do
            if StatLabelColumn[i] == StatLabel then table.remove(StatLabelColumn, i) end
        end
        Frame:Destroy()
        RecalcStatLabelPositions()
    end

    return StatLabel
end

-- ============================================================
-- Base Addons (ColorPicker, KeyPicker)
-- ============================================================
local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);
            ColorPicker.Hue = H; ColorPicker.Sat = S; ColorPicker.Vib = V;
        end;
        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });
        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });
        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        if Info.Transparency then
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });
            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });
            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });
            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });
            TransparencyCursor = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });

        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new();
                ZIndex = 14;
                Visible = false;
                Parent = ScreenGui
            })
            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });
            Library:Create('UIListLayout', {
                Name = 'Layout';
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });
            Library:Create('UIPadding', {
                Name = 'Padding';
                PaddingLeft = UDim.new(0, 4);
                Parent = ContextMenu.Inner;
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1)
            end
            local function updateMenuSize()
                local menuWidth = 60
                for _, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then menuWidth = math.max(menuWidth, label.TextBounds.X) end
                end
                ContextMenu.Container.Size = UDim2.fromOffset(menuWidth + 8, ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4)
            end
            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)
            task.spawn(updateMenuPosition); task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

            function ContextMenu:Show() self.Container.Visible = true end
            function ContextMenu:Hide() self.Container.Visible = false end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then Callback = function() end end
                local Button = Library:CreateLabel({
                    Active = false; Size = UDim2.new(1, 0, 0, 15); TextSize = 13; Text = Str; ZIndex = 16;
                    Parent = self.Inner; TextXAlignment = Enum.TextXAlignment.Left;
                });
                Library:OnHighlight(Button, Button, { TextColor3 = 'AccentColor' }, { TextColor3 = 'FontColor' });
                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)
            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then return Library:Notify('You have not copied a color!', 2) end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)
            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)
            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)
        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor'; });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor'; });

        local SequenceTable = {};
        for h = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(h, Color3.fromHSV(h, 1, 1)));
        end;
        Library:Create('UIGradient', { Color = ColorSequence.new(SequenceTable); Rotation = 90; Parent = HueSelectorInner; });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end
            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end
            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);
            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });
            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;
            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);
            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')
            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func) ColorPicker.Changed = Func; Func(ColorPicker.Value) end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then Frame.Visible = false; Library.OpenedFrames[Frame] = nil; end;
            end;
            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color); ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color); ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X; local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);
                    local MinY = SatVibMap.AbsolutePosition.Y; local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);
                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display(); RenderStepped:Wait();
                end;
                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y; local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);
                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display(); RenderStepped:Wait();
                end;
                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then ColorPicker:Hide()
                else ContextMenu:Hide(); ColorPicker:Show(); end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show(); ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X; local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);
                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));
                        ColorPicker:Display(); RenderStepped:Wait();
                    end;
                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    ColorPicker:Hide();
                end;
                if not Library:IsMouseOverFrame(ContextMenu.Container) then ContextMenu:Hide() end
            end;
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then ContextMenu:Hide() end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame;
        Options[Idx] = ColorPicker;
        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then Info.Modes = { 'Toggle' }; Info.Mode = 'Toggle' end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15); ZIndex = 6; Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 7; Parent = PickOuter;
        });
        Library:AddToRegistry(PickInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0); TextSize = 13; Text = Info.Default; TextWrapped = true; ZIndex = 8; Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2); Visible = false; ZIndex = 14; Parent = ScreenGui;
        });
        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 15; Parent = ModeSelectOuter;
        });
        Library:AddToRegistry(ModeSelectInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ModeSelectInner; });

        local ContainerRow = Library:Create('Frame', {
            BackgroundTransparency = 1; Size = UDim2.new(1, 0, 0, 18); Visible = false; ZIndex = 110; Parent = Library.KeybindContainer;
        });
        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left; Size = UDim2.new(1, -20, 1, 0);
            Position = UDim2.new(0, 0, 0, 0); TextSize = 13; ClipsDescendants = true; ZIndex = 110; Parent = ContainerRow;
        }, true);

        local TapToggleBtn = Library:Create('TextButton', {
            AnchorPoint = Vector2.new(1, 0.5); BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
            Position = UDim2.new(1, -2, 0.5, 0); Size = UDim2.new(0, 14, 0, 14); Text = '';
            AutoButtonColor = false; ZIndex = 111; Parent = ContainerRow;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 7); Parent = TapToggleBtn; });
        Library:AddToRegistry(TapToggleBtn, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; }, true);

        local TapToggleIndicator = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5); BackgroundColor3 = Library.AccentColor; BackgroundTransparency = 1;
            BorderSizePixel = 0; Position = UDim2.new(0.5, 0, 0.5, 0); Size = UDim2.new(0, 8, 0, 8); ZIndex = 112; Parent = TapToggleBtn;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = TapToggleIndicator; });
        Library:AddToRegistry(TapToggleIndicator, { BackgroundColor3 = 'AccentColor'; }, true);

        TapToggleBtn.MouseButton1Click:Connect(function()
            if KeyPicker.Mode == 'Toggle' then
                KeyPicker.Toggled = not KeyPicker.Toggled; KeyPicker:DoClick();
            elseif KeyPicker.Mode == 'Hold' then
                KeyPicker.TapHoldActive = not KeyPicker.TapHoldActive;
                KeyPicker.Toggled = KeyPicker.TapHoldActive; KeyPicker:DoClick();
            end
            KeyPicker:Update();
        end)

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for _, Mode in next, Modes do
            local ModeButton = {};
            local Label = Library:CreateLabel({
                Active = false; Size = UDim2.new(1, 0, 0, 15); TextSize = 13; Text = Mode; ZIndex = 16; Parent = ModeSelectInner;
            });
            function ModeButton:Select()
                for _, Button in next, ModeButtons do Button:Deselect(); end;
                KeyPicker.Mode = Mode;
                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';
                ModeSelectOuter.Visible = false;
            end;
            function ModeButton:Deselect()
                KeyPicker.Mode = nil;
                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;
            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select(); Library:AttemptSave();
                end;
            end);
            if Mode == KeyPicker.Mode then ModeButton:Select(); end;
            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then return; end;
            local State = KeyPicker:GetState();
            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);
            if KeyPicker.Value == 'None' then ContainerRow.Visible = false;
            else ContainerRow.Visible = true; end
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;
            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';
            TapToggleIndicator.BackgroundTransparency = State and 0 or 1;

            local YSize = 0; local XSize = 0;
            for _, Child in next, Library.KeybindContainer:GetChildren() do
                if Child:IsA('Frame') and Child.Visible then
                    YSize = YSize + 18;
                    for _, Sub in next, Child:GetChildren() do
                        if Sub:IsA('TextLabel') and Sub.TextBounds then
                            local w = Sub.TextBounds.X
                            if w > XSize then XSize = w end
                        end
                    end
                end;
            end;
            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 40, 210), 0, YSize + 34)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false end
                local Key = KeyPicker.Value;
                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]); end;
            else return KeyPicker.Toggled; end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key; KeyPicker.Value = Key;
            ModeButtons[Mode]:Select(); KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback) KeyPicker.Clicked = Callback end
        function KeyPicker:OnChanged(Callback) KeyPicker.Changed = Callback; Callback(KeyPicker.Value) end

        if ParentObj.Addons then table.insert(ParentObj.Addons, KeyPicker) end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;
        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true; DisplayLabel.Text = '';
                local Break; local Text = '';
                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then Text = ''; end;
                        Text = Text .. '.'; DisplayLabel.Text = Text; wait(0.4);
                    end;
                end);
                wait(0.2);
                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;
                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                        if Key == 'Backspace' then Key = 'None' end
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then Key = 'MB2'; end;
                    Break = true; Picking = false;
                    DisplayLabel.Text = Key; KeyPicker.Value = Key;
                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)
                    Library:AttemptSave();
                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;
                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled; KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then KeyPicker.Toggled = not KeyPicker.Toggled; KeyPicker:DoClick() end;
                    end;
                end;
                KeyPicker:Update();
            end;
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then KeyPicker:Update(); end;
        end))

        KeyPicker:Update();
        Options[Idx] = KeyPicker;
        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...) return Funcs[Key](...); end;
end;

-- ============================================================
-- Base Groupbox functions
-- ============================================================
local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Container = self.Container;
        Library:Create('Frame', {
            BackgroundTransparency = 1; Size = UDim2.new(1, 0, 0, Size); ZIndex = 1; Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};
        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end
            Groupbox:Resize();
        end

        if (not DoesWrap) then setmetatable(Label, BaseAddons); end

        Groupbox:AddBlank(5);
        Groupbox:Resize();
        return Label;
    end;

    function Funcs:AddButton(...)
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text; Obj.Func = Props.Func;
                Obj.DoubleClick = Props.DoubleClick; Obj.Tooltip = Props.Tooltip;
                Obj.Icon = Props.Icon;
            else
                Obj.Text = select(1, ...); Obj.Func = select(2, ...);
            end
            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end
        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;
        local resolvedIcon = ResolveIcon(Button.Icon)

        local function CreateBaseButton(Btn)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -4, 0, 20); ZIndex = 5;
            });
            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = Outer;
            });

            -- Icon support
            local labelOffset = 0
            if resolvedIcon then
                local IconImg = Library:Create('ImageLabel', {
                    BackgroundTransparency = 1; Size = UDim2.fromOffset(14, 14);
                    Position = UDim2.fromOffset(4, 3); Image = resolvedIcon;
                    ZIndex = 7; Parent = Inner;
                })
                labelOffset = 18
            end

            local Label = Library:CreateLabel({
                Position = UDim2.fromOffset(labelOffset, 0);
                Size = UDim2.new(1, -labelOffset, 1, 0);
                TextSize = 14; Text = Btn.Text; ZIndex = 6; Parent = Inner;
            });
            Library:Create('UIGradient', {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
                }); Rotation = 90; Parent = Inner;
            });
            Library:AddToRegistry(Outer, { BorderColor3 = 'Black'; });
            Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
            Library:OnHighlight(Outer, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });
            return Outer, Inner, Label
        end

        local function InitEvents(Btn)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)
                    if type(validator) == 'function' and validator(...) then bindable:Fire(true)
                    else bindable:Fire(false) end
                end)
                task.delay(timeout, function() connection:disconnect(); bindable:Fire(false) end)
                return bindable.Event:Wait()
            end
            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then return false end
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return false end
                return true
            end
            Btn.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Btn.Locked then return end
                if Btn.DoubleClick then
                    Library:RemoveFromRegistry(Btn.Label)
                    Library:AddToRegistry(Btn.Label, { TextColor3 = 'AccentColor' })
                    Btn.Label.TextColor3 = Library.AccentColor
                    Btn.Label.Text = 'Are you sure?'
                    Btn.Locked = true
                    local clicked = WaitForEvent(Btn.Outer.InputBegan, 0.5, ValidateClick)
                    Library:RemoveFromRegistry(Btn.Label)
                    Library:AddToRegistry(Btn.Label, { TextColor3 = 'FontColor' })
                    Btn.Label.TextColor3 = Library.FontColor
                    Btn.Label.Text = Btn.Text
                    task.defer(rawset, Btn, 'Locked', false)
                    if clicked then Library:SafeCallback(Btn.Func) end
                    return
                end
                Library:SafeCallback(Btn.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container
        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then Library:AddToolTip(tooltip, self.Outer) end
            return self
        end

        function Button:AddButton(...)
            local SubButton = {}
            ProcessButtonParams('SubButton', SubButton, ...)
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)
            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)
            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer
            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then Library:AddToolTip(tooltip, self.Outer) end
                return SubButton
            end
            if type(SubButton.Tooltip) == 'string' then SubButton:AddTooltip(SubButton.Tooltip) end
            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then Button:AddTooltip(Button.Tooltip) end
        Groupbox:AddBlank(5); Groupbox:Resize();
        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container;
        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 5); ZIndex = 5; Parent = Container;
        });
        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = DividerOuter;
        });
        Library:AddToRegistry(DividerOuter, { BorderColor3 = 'Black'; });
        Library:AddToRegistry(DividerInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Groupbox:AddBlank(9); Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };
        local Groupbox = self; local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15); TextSize = 14; Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 5; Parent = Container;
        });
        Groupbox:AddBlank(1);
        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20); ZIndex = 5; Parent = Container;
        });
        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = TextBoxOuter;
        });
        Library:AddToRegistry(TextBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:OnHighlight(TextBoxOuter, TextBoxOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, TextBoxOuter) end
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            }); Rotation = 90; Parent = TextBoxInner;
        });
        local BoxContainer = Library:Create('Frame', {
            BackgroundTransparency = 1; ClipsDescendants = true;
            Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -5, 1, 0); ZIndex = 7; Parent = TextBoxInner;
        })
        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1; Position = UDim2.fromOffset(0, 0); Size = UDim2.fromScale(5, 1);
            Font = Library.Font; PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or ''; Text = Info.Default or '';
            TextColor3 = Library.FontColor; TextSize = 14; TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 7; Parent = BoxContainer;
        });
        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength); end;
            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then Text = Textbox.Value end
            end
            Textbox.Value = Text; Box.Text = Text;
            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end
                Textbox:SetValue(Box.Text); Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text); Library:AttemptSave();
            end);
        end

        local function Update()
            local PADDING = 2; local reveal = BoxContainer.AbsoluteSize.X;
            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
                    local currentCursorPos = Box.Position.X.Offset + width
                    if currentCursorPos < PADDING then Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0) end
                end
            end
        end
        task.spawn(Update)
        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update); Box.Focused:Connect(Update)
        Library:AddToRegistry(Box, { TextColor3 = 'FontColor'; });

        function Textbox:OnChanged(Func) Textbox.Changed = Func; Func(Textbox.Value); end;

        Groupbox:AddBlank(5); Groupbox:Resize();
        Options[Idx] = Textbox;
        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text` string.')
        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';
            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };
        local Groupbox = self; local Container = Groupbox.Container;

        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 13, 0, 13); ZIndex = 5; Parent = Container;
        });
        Library:AddToRegistry(ToggleOuter, { BorderColor3 = 'Black'; });

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = ToggleOuter;
        });
        Library:AddToRegistry(ToggleInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        -- Label with icon support
        local resolvedIcon = ResolveIcon(Info.Icon)
        local labelXOffset = resolvedIcon and 22 or 6
        local labelWidth = resolvedIcon and 194 or 216

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, labelWidth, 1, 0);
            Position = UDim2.new(1, labelXOffset, 0, 0);
            TextSize = 14; Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6; Parent = ToggleInner;
        });

        -- Render icon
        if resolvedIcon then
            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Position = UDim2.new(1, 6, 0, -1);
                Size = UDim2.fromOffset(14, 14);
                Image = resolvedIcon;
                ZIndex = 7;
                Parent = ToggleInner;
            })
        end

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4); FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right; SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1; Size = UDim2.new(0, 170, 1, 0); ZIndex = 8; Parent = ToggleOuter;
        });

        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });

        function Toggle:UpdateColors() Toggle:Display(); end;

        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, ToggleRegion) end

        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor;
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor;
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func) Toggle.Changed = Func; Func(Toggle.Value); end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);
            local prev = Toggle.Value;
            -- push undo before change
            if prev ~= Bool then
                PushUndo({ obj = Toggle, prev = prev, next = Bool })
                -- log change
                local logStr = string.format('%s → %s', Info.Text, tostring(Bool))
                PushChangeLog(logStr)
            end
            Toggle.Value = Bool;
            Toggle:Display();
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool; Addon:Update()
                end
            end
            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
            -- refresh active toggles widget
            if Bool then
                Library._ActiveToggles[Idx] = Toggle
            else
                Library._ActiveToggles[Idx] = nil
            end
            RefreshActiveTogglesWidget()
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value);
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 5 + 2);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;
        Library:UpdateDependencyBoxes();
        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default ~= nil, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min ~= nil, 'AddSlider: Missing minimum value.');
        assert(Info.Max ~= nil, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding ~= nil, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min; Max = Info.Max; Rounding = Info.Rounding;
            MaxSize = 232; Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };
        local Groupbox = self; local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10); TextSize = 14; Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5; Parent = Container;
            });
            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 13); ZIndex = 5; Parent = Container;
        });
        Library:AddToRegistry(SliderOuter, { BorderColor3 = 'Black'; });

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = SliderOuter;
        });
        Library:AddToRegistry(SliderInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor; BorderColor3 = Library.AccentColorDark;
            Size = UDim2.new(0, 0, 1, 0); ZIndex = 7; Parent = SliderInner;
        });
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor'; BorderColor3 = 'AccentColorDark'; });

        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0); Size = UDim2.new(0, 1, 1, 0); ZIndex = 8; Parent = Fill;
        });
        Library:AddToRegistry(HideBorderRight, { BackgroundColor3 = 'AccentColor'; });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0); TextSize = 14; Text = 'Infinite'; ZIndex = 9; Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, SliderOuter) end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';
            if Info.Compact then DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix); end
            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);
            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func) Slider.Changed = Func; Func(Slider.Value); end;

        local function Round(Value)
            if Slider.Rounding == 0 then return math.floor(Value); end;
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);
            if (not Num) then return; end;
            Num = math.clamp(Num, Slider.Min, Slider.Max);
            Slider.Value = Num;
            Slider:Display();
            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X; local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);
                local prevVal = Slider.Value
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);
                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;
                    Slider:Display();
                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;
                    RenderStepped:Wait();
                end;
                -- Push undo on release (final value)
                if prevVal ~= Slider.Value then
                    PushUndo({ obj = Slider, prev = prevVal, next = Slider.Value })
                    PushChangeLog(string.format('%s → %s', Info.Text, tostring(Slider.Value)))
                end
                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();
        Options[Idx] = Slider;
        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then Info.Values = GetPlayersString(); Info.AllowNull = true;
        elseif Info.SpecialType == 'Priority' then Info.Values = GetTeamsString(); Info.AllowNull = true; end;
        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value.')
        if (not Info.Text) then Info.Compact = true; end;

        local Dropdown = {
            Values = Info.Values; Value = Info.Multi and {};
            Multi = Info.Multi; Type = 'Dropdown';
            SpecialType = Info.SpecialType;
            Callback = Info.Callback or function(Value) end;
        };
        local Groupbox = self; local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10); TextSize = 14; Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5; Parent = Container;
            });
            Groupbox:AddBlank(3);
        end

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, -4, 0, 20); ZIndex = 5; Parent = Container;
        });
        Library:AddToRegistry(DropdownOuter, { BorderColor3 = 'Black'; });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = DropdownOuter;
        });
        Library:AddToRegistry(DropdownInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            }); Rotation = 90; Parent = DropdownInner;
        });

        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5); BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0); Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798'; ZIndex = 8; Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -5, 1, 0); TextSize = 14; Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left; TextWrapped = true; ZIndex = 7; Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'Black' });
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, DropdownOuter) end

        local MAX_DROPDOWN_ITEMS = 8;
        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
            ZIndex = 20; Visible = false; Parent = ScreenGui;
        });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;
        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;
        RecalculateListPosition(); RecalculateListSize();
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset; BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0); ZIndex = 21; Parent = ListOuter;
        });
        Library:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1; BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, 0); ZIndex = 21; Parent = ListInner;
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            ScrollBarThickness = 3, ScrollBarImageColor3 = Library.AccentColor,
        });
        Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0); FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder; Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values; local Str = '';
            if Info.Multi then
                for _, Value in next, Values do
                    if Dropdown.Value[Value] then Str = Str .. Value .. ', '; end;
                end;
                Str = Str:sub(1, #Str - 2);
            else Str = Dropdown.Value or ''; end;
            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};
                for Value, Bool in next, Dropdown.Value do table.insert(T, Value); end;
                return T;
            else return Dropdown.Value and 1 or 0; end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values; local Buttons = {};
            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then Element:Destroy(); end;
            end;
            local Count = 0;
            for _, Value in next, Values do
                local Table = {};
                Count = Count + 1;
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle; Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23; Active = true, Parent = Scrolling;
                });
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
                local ButtonLabel = Library:CreateLabel({
                    Active = false; Size = UDim2.new(1, -6, 1, 0); Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14; Text = Value; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 25; Parent = Button;
                });
                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 });
                local Selected;
                if Info.Multi then Selected = Dropdown.Value[Value];
                else Selected = Dropdown.Value == Value; end;

                function Table:UpdateButton()
                    if Info.Multi then Selected = Dropdown.Value[Value];
                    else Selected = Dropdown.Value == Value; end;
                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not Selected;
                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;
                                if Selected then Dropdown.Value[Value] = true;
                                else Dropdown.Value[Value] = nil; end;
                            else
                                Selected = Try;
                                if Selected then Dropdown.Value = Value;
                                else Dropdown.Value = nil; end;
                                for _, OtherButton in next, Buttons do OtherButton:UpdateButton(); end;
                            end;
                            Table:UpdateButton(); Dropdown:Display();
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
                            Library:AttemptSave();
                        end;
                    end;
                end);
                Table:UpdateButton(); Dropdown:Display();
                Buttons[Button] = Table;
            end;
            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);
            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then Dropdown.Values = NewValues; end;
            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true; Library.OpenedFrames[ListOuter] = true; DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false; Library.OpenedFrames[ListOuter] = nil; DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func) Dropdown.Changed = Func; Func(Dropdown.Value); end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};
                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then nTable[Value] = true end;
                end;
                Dropdown.Value = nTable;
            else
                if (not Val) then Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then Dropdown.Value = Val; end;
            end;
            Dropdown:BuildDropdownList();
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:CloseDropdown();
                else Dropdown:OpenDropdown(); end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList(); Dropdown:Display();

        local Defaults = {}
        if type(Info.Default) == 'string' then
            local idx = table.find(Dropdown.Values, Info.Default)
            if idx then table.insert(Defaults, idx) end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local idx = table.find(Dropdown.Values, Value)
                if idx then table.insert(Defaults, idx) end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end
        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then Dropdown.Value[Dropdown.Values[Index]] = true;
                else Dropdown.Value = Dropdown.Values[Index]; end
                if (not Info.Multi) then break end
            end
            Dropdown:BuildDropdownList(); Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5); Groupbox:Resize();
        Options[Idx] = Dropdown;
        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {}; };
        local Groupbox = self; local Container = Groupbox.Container;
        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1; Size = UDim2.new(1, 0, 0, 0); Visible = false; Parent = Container;
        });
        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1; Size = UDim2.new(1, 0, 1, 0); Visible = true; Parent = Holder;
        });
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y); Groupbox:Resize();
        end;
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize(); end);
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize(); end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1]; local Value = Dependency[2];
                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false; Depbox:Resize(); return;
                end;
            end;
            Holder.Visible = true; Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;
            Depbox.Dependencies = Dependencies; Depbox:Update();
        end;

        Depbox.Container = Frame;
        setmetatable(Depbox, BaseGroupbox);
        table.insert(Library.DependencyBoxes, Depbox);
        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...) return Funcs[Key](...); end;
end;

-- ============================================================
-- < Create other UI elements >
-- ============================================================
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        AnchorPoint = Vector2.new(0.5, 1);
        Position = UDim2.new(0.5, 0, 1, -20);
        Size = UDim2.new(0, 350, 0, 400);
        ZIndex = 100;
        Parent = ScreenGui;
    });
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4); FillDirection = Enum.FillDirection.Vertical;
        VerticalAlignment = Enum.VerticalAlignment.Bottom;
        HorizontalAlignment = Enum.HorizontalAlignment.Center;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    -- Watermark
    local WatermarkOuter = Library:Create('Frame', {
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 100, 0, -25);
        Size = UDim2.new(0, 213, 0, 20);
        ZIndex = 200; Visible = false; Parent = ScreenGui;
    });
    local WatermarkInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201; Parent = WatermarkOuter;
    });
    Library:AddToRegistry(WatermarkInner, { BorderColor3 = 'AccentColor'; });
    local WMInnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1); Size = UDim2.new(1, -2, 1, -2); ZIndex = 202; Parent = WatermarkInner;
    });
    local WMGradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        }); Rotation = -90; Parent = WMInnerFrame;
    });
    Library:AddToRegistry(WMGradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });
    local WatermarkLabel = Library:CreateLabel({
        Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -4, 1, 0);
        TextSize = 14; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 203; Parent = WMInnerFrame;
    });
    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    -- Keybind HUD
    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5); BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0.5, 0); Size = UDim2.new(0, 210, 0, 20);
        Visible = false; ZIndex = 100; Parent = ScreenGui;
    });
    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 101; Parent = KeybindOuter;
    });
    Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
    Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
        }); Rotation = 90; Parent = KeybindInner;
    });
    local KeybindAccentBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(0, 2, 1, 0); ZIndex = 105; Parent = KeybindInner;
    });
    Library:AddToRegistry(KeybindAccentBar, { BackgroundColor3 = 'AccentColor'; }, true);
    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2); ZIndex = 102; Parent = KeybindInner;
    });
    Library:AddToRegistry(ColorFrame, { BackgroundColor3 = 'AccentColor'; }, true);
    local KeybindLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 22); Position = UDim2.fromOffset(8, 2);
        TextXAlignment = Enum.TextXAlignment.Left, Text = 'Keybinds'; TextSize = 15; ZIndex = 104; Parent = KeybindInner;
    });
    local KeybindSeparator = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor; BorderSizePixel = 0;
        Position = UDim2.new(0, 4, 0, 22); Size = UDim2.new(1, -8, 0, 1); ZIndex = 103; Parent = KeybindInner;
    });
    Library:AddToRegistry(KeybindSeparator, { BackgroundColor3 = 'OutlineColor'; }, true);
    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1; Size = UDim2.new(1, 0, 1, -24);
        Position = UDim2.new(0, 0, 0, 24); ZIndex = 1; Parent = KeybindInner;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 1); Parent = KeybindContainer;
    });
    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 8); PaddingRight = UDim.new(0, 5); PaddingTop = UDim.new(0, 2);
        Parent = KeybindContainer;
    })
    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);

    -- ========================
    -- Mobile Toggle Button (draggable)
    -- ========================
    local MobileToggleBtn = Library:Create('TextButton', {
        AnchorPoint = Vector2.new(1, 1); BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        Position = UDim2.new(1, -15, 1, -15); Size = UDim2.new(0, 36, 0, 36);
        Text = ''; AutoButtonColor = false; ZIndex = 150; Parent = ScreenGui;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 18); Parent = MobileToggleBtn; });
    Library:AddToRegistry(MobileToggleBtn, { BackgroundColor3 = 'AccentColor'; });
    for i = 0, 2 do
        Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5); BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0;
            Position = UDim2.new(0.5, 0, 0.5, (i - 1) * 7); Size = UDim2.new(0, 16, 0, 2);
            ZIndex = 151; Parent = MobileToggleBtn;
        });
    end
    local MobileShadow = Library:Create('ImageLabel', {
        AnchorPoint = Vector2.new(0.5, 0.5); BackgroundTransparency = 1;
        Position = UDim2.new(0.5, 0, 0.5, 2); Size = UDim2.new(1, 12, 1, 12);
        Image = 'rbxassetid://5554236805'; ImageColor3 = Color3.new(0, 0, 0); ImageTransparency = 0.6;
        ScaleType = Enum.ScaleType.Slice; SliceCenter = Rect.new(23, 23, 277, 277); ZIndex = 149; Parent = MobileToggleBtn;
    });

    -- Draggable mobile button: distinguish tap vs drag
    do
        local mDragStartPos = nil
        local mHasDragged = false
        MobileToggleBtn.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                mDragStartPos = Vector2.new(Mouse.X, Mouse.Y)
                mHasDragged = false
                local ObjPos = Vector2.new(Mouse.X - MobileToggleBtn.AbsolutePosition.X, Mouse.Y - MobileToggleBtn.AbsolutePosition.Y)
                task.spawn(function()
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local delta = Vector2.new(Mouse.X, Mouse.Y) - mDragStartPos
                        if delta.Magnitude > 5 then
                            mHasDragged = true
                            MobileToggleBtn.Position = UDim2.fromOffset(
                                Mouse.X - ObjPos.X,
                                Mouse.Y - ObjPos.Y
                            )
                            MobileToggleBtn.AnchorPoint = Vector2.new(0, 0)
                        end
                        RenderStepped:Wait()
                    end
                end)
            end
        end)
        MobileToggleBtn.MouseButton1Click:Connect(function()
            if not mHasDragged then
                task.spawn(Library.Toggle)
            end
        end)
    end

    Library.MobileToggleButton = MobileToggleBtn;

    -- ========================
    -- Leaderboard Widget
    -- ========================
    Library.PlayerPriorities = {};

    function Library:SetPlayerPriority(Player, Level, Label, PriorityColor)
        local UserId = type(Player) == 'number' and Player or Player.UserId;
        Library.PlayerPriorities[UserId] = {
            Level = Level or 0; Label = Label or ''; Color = PriorityColor or Library.AccentColor;
        };
        if Library.UpdateLeaderboard then Library:UpdateLeaderboard(); end
    end

    function Library:GetPlayerPriority(Player)
        local UserId = type(Player) == 'number' and Player or Player.UserId;
        return Library.PlayerPriorities[UserId];
    end

    local LeaderboardOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(1, 0.5); BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(1, -10, 0.5, 0); Size = UDim2.new(0, 250, 0, 300);
        Visible = false; ZIndex = 100; Parent = ScreenGui;
    });
    local LeaderboardInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 101; Parent = LeaderboardOuter;
    });
    Library:AddToRegistry(LeaderboardInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
    Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
        }); Rotation = 90; Parent = LeaderboardInner;
    });
    local LBAccentBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2); ZIndex = 102; Parent = LeaderboardInner;
    });
    Library:AddToRegistry(LBAccentBar, { BackgroundColor3 = 'AccentColor'; }, true);
    local LBLabel = Library:CreateLabel({
        Size = UDim2.new(1, 0, 0, 22); Position = UDim2.fromOffset(8, 2);
        TextXAlignment = Enum.TextXAlignment.Left, Text = 'Leaderboard'; TextSize = 15; ZIndex = 104; Parent = LeaderboardInner;
    });
    Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor; BorderSizePixel = 0;
        Position = UDim2.new(0, 4, 0, 24); Size = UDim2.new(1, -8, 0, 1); ZIndex = 103; Parent = LeaderboardInner;
    });
    local LBHeaderRow = Library:Create('Frame', {
        BackgroundTransparency = 1; Position = UDim2.new(0, 0, 0, 26); Size = UDim2.new(1, 0, 0, 16); ZIndex = 103; Parent = LeaderboardInner;
    });
    Library:CreateLabel({ Position = UDim2.fromOffset(8, 0); Size = UDim2.new(0, 14, 1, 0); Text = ''; TextSize = 12; ZIndex = 104; Parent = LBHeaderRow; });
    Library:CreateLabel({ Position = UDim2.fromOffset(24, 0); Size = UDim2.new(0, 100, 1, 0); Text = 'Name'; TextSize = 12; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 104; Parent = LBHeaderRow; });
    Library:CreateLabel({ Position = UDim2.new(1, -60, 0, 0); Size = UDim2.new(0, 50, 1, 0); Text = 'Team'; TextSize = 12; TextXAlignment = Enum.TextXAlignment.Right; ZIndex = 104; Parent = LBHeaderRow; });

    local LBScrolling = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.new(0, 0, 0, 44); Size = UDim2.new(1, 0, 1, -44);
        CanvasSize = UDim2.new(0, 0, 0, 0); TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png'; ScrollBarThickness = 3;
        ScrollBarImageColor3 = Library.AccentColor; ZIndex = 103; Parent = LeaderboardInner;
    });
    Library:AddToRegistry(LBScrolling, { ScrollBarImageColor3 = 'AccentColor'; }, true);
    Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Padding = UDim.new(0, 0); Parent = LBScrolling; });

    local LBTooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
        Size = UDim2.fromOffset(200, 140); Visible = false; ZIndex = 200; Parent = ScreenGui;
    });
    Library:AddToRegistry(LBTooltip, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
    Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(210,210,210)) }); Rotation = 90; Parent = LBTooltip; });
    Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1,0,0,2); ZIndex = 201; Parent = LBTooltip; });

    local TooltipAvatar = Library:Create('ImageLabel', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(8, 8); Size = UDim2.fromOffset(48, 48); ZIndex = 201; Parent = LBTooltip; });
    Library:AddToRegistry(TooltipAvatar, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
    local TooltipDisplay = Library:CreateLabel({ Position = UDim2.fromOffset(64, 8); Size = UDim2.new(1, -72, 0, 16); Text = ''; TextSize = 14; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 202; Parent = LBTooltip; });
    local TooltipUsername = Library:CreateLabel({ Position = UDim2.fromOffset(64, 24); Size = UDim2.new(1, -72, 0, 14); Text = ''; TextSize = 12; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 202; Parent = LBTooltip; });
    local TooltipUserId = Library:CreateLabel({ Position = UDim2.fromOffset(64, 38); Size = UDim2.new(1, -72, 0, 14); Text = ''; TextSize = 12; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 202; Parent = LBTooltip; });
    local TooltipTeam = Library:CreateLabel({ Position = UDim2.fromOffset(8, 64); Size = UDim2.new(1, -16, 0, 14); Text = ''; TextSize = 12; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 202; Parent = LBTooltip; });
    local TooltipAge = Library:CreateLabel({ Position = UDim2.fromOffset(8, 80); Size = UDim2.new(1, -16, 0, 14); Text = ''; TextSize = 12; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 202; Parent = LBTooltip; });
    local TooltipPriority = Library:CreateLabel({ Position = UDim2.fromOffset(8, 96); Size = UDim2.new(1, -16, 0, 14); Text = ''; TextSize = 12; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 202; Parent = LBTooltip; });

    local function ShowPlayerTooltip(Player)
        if not Player or not Player.Parent then LBTooltip.Visible = false; return; end
        TooltipDisplay.Text = Player.DisplayName;
        TooltipUsername.Text = '@' .. Player.Name;
        TooltipUserId.Text = 'ID: ' .. tostring(Player.UserId);
        TooltipTeam.Text = 'Team: ' .. (Player.Team and Player.Team.Name or 'None');
        TooltipAge.Text = 'Account Age: ' .. tostring(Player.AccountAge) .. ' days';
        local Priority = Library:GetPlayerPriority(Player);
        if Priority and Priority.Label ~= '' then
            TooltipPriority.Text = 'Priority: ' .. Priority.Label;
            TooltipPriority.TextColor3 = Priority.Color; TooltipPriority.Visible = true;
        else TooltipPriority.Text = ''; TooltipPriority.Visible = false; end
        pcall(function()
            local content, isReady = Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48);
            TooltipAvatar.Image = content;
        end)
        LBTooltip.Visible = true;
    end
    local function HidePlayerTooltip() LBTooltip.Visible = false; end

    Library.PriorityCycle = {
        { Level = 0, Label = '', Color = Color3.fromRGB(128, 128, 128) },
        { Level = 1, Label = 'Friend', Color = Color3.fromRGB(100, 255, 100) }
    };

    function Library:GetPriorityCycleIndex(UserId)
        local p = Library.PlayerPriorities[UserId];
        if not p or p.Level == 0 then return 1 end
        for i, entry in next, Library.PriorityCycle do
            if entry.Level == p.Level then return i end
        end
        return 1
    end

    function Library:CyclePlayerPriority(Player)
        local UserId = type(Player) == 'number' and Player or Player.UserId;
        local idx = Library:GetPriorityCycleIndex(UserId);
        idx = idx + 1;
        if idx > #Library.PriorityCycle then idx = 1 end
        local entry = Library.PriorityCycle[idx];
        Library:SetPlayerPriority(UserId, entry.Level, entry.Label, entry.Color);
        Library:SavePriorities();
    end

    function Library:SavePriorities()
        pcall(function()
            local httpService = game:GetService('HttpService');
            local data = {};
            for uid, p in next, Library.PlayerPriorities do
                if p.Level > 0 then
                    data[tostring(uid)] = { Level = p.Level, Label = p.Label, R = math.floor(p.Color.R * 255), G = math.floor(p.Color.G * 255), B = math.floor(p.Color.B * 255) };
                end
            end
            if writefile then writefile('LinoriaPriorities.json', httpService:JSONEncode(data)); end
        end)
    end

    function Library:LoadPriorities()
        pcall(function()
            local httpService = game:GetService('HttpService');
            if isfile and isfile('LinoriaPriorities.json') then
                local raw = readfile('LinoriaPriorities.json');
                local data = httpService:JSONDecode(raw);
                for uid, p in next, data do
                    Library.PlayerPriorities[tonumber(uid)] = {
                        Level = p.Level or 0; Label = p.Label or '';
                        Color = Color3.fromRGB(p.R or 128, p.G or 128, p.B or 128);
                    };
                end
            end
        end)
    end
    Library:LoadPriorities();

    function Library:UpdateLeaderboard()
        for _, child in next, LBScrolling:GetChildren() do
            if not child:IsA('UIListLayout') then child:Destroy(); end
        end
        local playerList = Players:GetPlayers();
        table.sort(playerList, function(a, b)
            local pa = Library.PlayerPriorities[a.UserId]; local pb = Library.PlayerPriorities[b.UserId];
            local la = pa and pa.Level or 0; local lb = pb and pb.Level or 0;
            if la ~= lb then return la > lb end
            return a.Name < b.Name;
        end);
        local count = 0;
        for _, player in next, playerList do
            count = count + 1;
            local Row = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor; BackgroundTransparency = count % 2 == 0 and 0.5 or 0.8;
                BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 22); Active = true; ZIndex = 104; Parent = LBScrolling;
            });
            Library:AddToRegistry(Row, { BackgroundColor3 = 'BackgroundColor'; });
            local priority = Library:GetPlayerPriority(player);
            local dotColor = (priority and priority.Level > 0) and priority.Color
                or (player.Team and player.Team.TeamColor and player.Team.TeamColor.Color) or Color3.fromRGB(128, 128, 128);
            local PriorityDot = Library:Create('TextButton', {
                AnchorPoint = Vector2.new(0, 0.5); BackgroundColor3 = dotColor; BorderSizePixel = 0;
                Position = UDim2.new(0, 6, 0.5, 0); Size = UDim2.new(0, 10, 0, 10); Text = '';
                AutoButtonColor = false; ZIndex = 106; Parent = Row;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = PriorityDot; });
            PriorityDot.MouseButton1Click:Connect(function() Library:CyclePlayerPriority(player); end)
            Library:CreateLabel({ Position = UDim2.fromOffset(22, 0); Size = UDim2.new(1, -80, 1, 0); Text = player.DisplayName; TextSize = 13; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 105; Parent = Row; });
            if priority and priority.Label ~= '' then
                Library:CreateLabel({ AnchorPoint = Vector2.new(1, 0.5); Position = UDim2.new(1, -6, 0.5, 0); Size = UDim2.new(0, 45, 0, 14); Text = priority.Label; TextSize = 11; TextColor3 = priority.Color; TextXAlignment = Enum.TextXAlignment.Right; ZIndex = 105; Parent = Row; });
            else
                local teamName = player.Team and player.Team.Name or '';
                Library:CreateLabel({ AnchorPoint = Vector2.new(1, 0.5); Position = UDim2.new(1, -6, 0.5, 0); Size = UDim2.new(0, 50, 0, 14); Text = teamName; TextSize = 11; TextXAlignment = Enum.TextXAlignment.Right; ZIndex = 105; Parent = Row; });
            end
            local hovering = false;
            Row.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseMovement then
                    hovering = true;
                    task.spawn(function()
                        ShowPlayerTooltip(player);
                        while hovering and LBTooltip.Visible do
                            LBTooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 10);
                            RunService.Heartbeat:Wait();
                        end
                    end)
                end
            end)
            Row.InputEnded:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseMovement then
                    hovering = false; HidePlayerTooltip();
                end
            end)
        end
        LBScrolling.CanvasSize = UDim2.fromOffset(0, count * 22);
    end

    Library.LeaderboardFrame = LeaderboardOuter;
    Library:MakeDraggable(LeaderboardOuter);

    function Library:SetLeaderboardVisibility(Bool)
        LeaderboardOuter.Visible = Bool;
        if Bool then Library:UpdateLeaderboard(); end
    end

    Library:GiveSignal(Players.PlayerAdded:Connect(function()
        if LeaderboardOuter.Visible then task.defer(Library.UpdateLeaderboard, Library); end
    end))
    Library:GiveSignal(Players.PlayerRemoving:Connect(function()
        if LeaderboardOuter.Visible then task.defer(Library.UpdateLeaderboard, Library); end
    end))

    -- ========================
    -- Viewmodel Widget
    -- ========================
    local ViewmodelOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 1); BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 1, -60); Size = UDim2.new(0, 180, 0, 220);
        Visible = false; ZIndex = 100; Parent = ScreenGui;
    });
    local ViewmodelInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 101; Parent = ViewmodelOuter;
    });
    Library:AddToRegistry(ViewmodelInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
    Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200)) }); Rotation = 90; Parent = ViewmodelInner; });
    local VMAccent = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1,0,0,2); ZIndex = 102; Parent = ViewmodelInner; });
    Library:AddToRegistry(VMAccent, { BackgroundColor3 = 'AccentColor'; }, true);
    Library:CreateLabel({ Size = UDim2.new(1,-45,0,22); Position = UDim2.fromOffset(8,2); TextXAlignment = Enum.TextXAlignment.Left, Text = 'Viewmodel'; TextSize = 15; ZIndex = 104; Parent = ViewmodelInner; });
    local VMRefreshBtn = Library:Create('TextButton', {
        AnchorPoint = Vector2.new(1,0); BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(1,-6,0,5); Size = UDim2.new(0,16,0,14); Text = '+'; Font = Enum.Font.Gotham;
        TextSize = 12; TextColor3 = Library.FontColor; AutoButtonColor = false; ZIndex = 105; Parent = ViewmodelInner;
    });
    Library:AddToRegistry(VMRefreshBtn, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; TextColor3 = 'FontColor'; }, true);
    Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderSizePixel = 0; Position = UDim2.new(0,4,0,24); Size = UDim2.new(1,-8,0,1); ZIndex = 103; Parent = ViewmodelInner; });
    local VMViewport = Library:Create('ViewportFrame', {
        BackgroundColor3 = Library.BackgroundColor; BorderSizePixel = 0;
        Position = UDim2.new(0,4,0,28); Size = UDim2.new(1,-8,1,-32);
        Ambient = Color3.fromRGB(200,200,200); LightColor = Color3.fromRGB(255,255,255);
        LightDirection = Vector3.new(-1,-1,-1); ZIndex = 103; Parent = ViewmodelInner;
    });
    Library:AddToRegistry(VMViewport, { BackgroundColor3 = 'BackgroundColor'; }, true);
    local VMWorldModel = Instance.new('WorldModel'); VMWorldModel.Parent = VMViewport;
    local VMCamera = Instance.new('Camera'); VMCamera.FieldOfView = 50; VMCamera.Parent = VMViewport;
    VMViewport.CurrentCamera = VMCamera;
    Library.ViewmodelModel = nil;

    function Library:RefreshViewmodel()
        for _, child in next, VMWorldModel:GetChildren() do child:Destroy(); end
        for _, child in next, VMViewport:GetChildren() do if child:IsA('Highlight') then child:Destroy(); end end
        Library.ViewmodelModel = nil;
        local player = Players.LocalPlayer; local character = player and player.Character;
        if not character then return end
        pcall(function()
            local wasArchivable = character.Archivable; character.Archivable = true;
            local clone = character:Clone(); character.Archivable = wasArchivable;
            for _, desc in next, clone:GetDescendants() do
                if desc:IsA('BaseScript') or desc:IsA('LocalScript') or desc:IsA('Sound') or desc:IsA('ParticleEmitter')
                    or desc:IsA('Trail') or desc:IsA('Beam') or desc:IsA('BillboardGui') or desc:IsA('ForceField') then
                    pcall(function() desc:Destroy() end);
                end
            end
            for _, part in next, clone:GetDescendants() do if part:IsA('BasePart') then part.Anchored = true; end end
            clone.Parent = VMWorldModel; Library.ViewmodelModel = clone;
            local hrp = clone:FindFirstChild('HumanoidRootPart'); local head = clone:FindFirstChild('Head');
            local pivot = hrp or head;
            if pivot then
                local pos = pivot.Position;
                VMCamera.CFrame = CFrame.new(pos + Vector3.new(3,2,5), pos + Vector3.new(0,0,0));
            end
        end)
    end
    VMRefreshBtn.MouseButton1Click:Connect(function() Library:RefreshViewmodel(); end)

    local vmDragging = false; local vmLastMouse = Vector2.new(0,0);
    local vmAngleX = 0.4; local vmAngleY = 0.3; local vmDistance = 7; local vmFocusOffset = Vector3.new(0,0,0);
    local function UpdateVMCamera()
        if not Library.ViewmodelModel then return end
        local hrp = Library.ViewmodelModel:FindFirstChild('HumanoidRootPart'); local head = Library.ViewmodelModel:FindFirstChild('Head');
        local pivot = hrp or head; if not pivot then return end
        local target = pivot.Position + vmFocusOffset;
        local camPos = target + Vector3.new(math.sin(vmAngleX)*math.cos(vmAngleY)*vmDistance, math.sin(vmAngleY)*vmDistance, math.cos(vmAngleX)*math.cos(vmAngleY)*vmDistance);
        VMCamera.CFrame = CFrame.new(camPos, target);
    end
    VMViewport.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            vmDragging = true; vmLastMouse = Vector2.new(input.Position.X, input.Position.Y);
        end
    end)
    VMViewport.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            vmDragging = false;
        end
    end)
    VMViewport.InputChanged:Connect(function(input)
        if vmDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local currentMouse = Vector2.new(input.Position.X, input.Position.Y);
            local delta = currentMouse - vmLastMouse;
            vmAngleX = vmAngleX - delta.X * 0.01;
            vmAngleY = math.clamp(vmAngleY + delta.Y * 0.01, -1.2, 1.2);
            vmLastMouse = currentMouse; UpdateVMCamera();
        end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            vmDistance = math.clamp(vmDistance - input.Position.Z * 0.8, 2, 20); UpdateVMCamera();
        end
    end)
    local _origRefresh = Library.RefreshViewmodel;
    function Library:RefreshViewmodel()
        _origRefresh(Library); vmAngleX = 0.4; vmAngleY = 0.3; vmDistance = 7; UpdateVMCamera();
    end

    function Library:AddViewmodelHighlight(Props)
        if not Library.ViewmodelModel then return nil end
        local highlight = Instance.new('Highlight');
        highlight.Adornee = Library.ViewmodelModel;
        highlight.FillColor = Props and Props.FillColor or Library.AccentColor;
        highlight.FillTransparency = Props and Props.FillTransparency or 0.5;
        highlight.OutlineColor = Props and Props.OutlineColor or Color3.new(1,1,1);
        highlight.OutlineTransparency = Props and Props.OutlineTransparency or 0;
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop;
        highlight.Parent = VMViewport;
        return highlight;
    end

    function Library:ClearViewmodelHighlights()
        for _, child in next, VMViewport:GetChildren() do
            if child:IsA('Highlight') then child:Destroy(); end
        end
    end

    Library.ViewmodelFrame = ViewmodelOuter;
    Library:MakeDraggable(ViewmodelOuter);

    function Library:SetViewmodelVisibility(Bool)
        ViewmodelOuter.Visible = Bool;
        if Bool then Library:RefreshViewmodel(); end
    end

    -- ========================
    -- Chat Logger Widget
    -- ========================
    local ChatLogOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 1); BackgroundColor3 = Color3.new(0,0,0); BorderColor3 = Color3.new(0,0,0);
        Position = UDim2.new(0.5,0,1,-60); Size = UDim2.new(0,320,0,200);
        Visible = false; ZIndex = 100; Parent = ScreenGui;
    });
    local ChatLogInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1,0,1,0); ZIndex = 101; Parent = ChatLogOuter;
    });
    Library:AddToRegistry(ChatLogInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
    Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200)) }); Rotation = 90; Parent = ChatLogInner; });
    Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0,2,1,0); ZIndex = 105; Parent = ChatLogInner; });
    local ChatAccentTop = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1,0,0,2); ZIndex = 102; Parent = ChatLogInner; });
    Library:AddToRegistry(ChatAccentTop, { BackgroundColor3 = 'AccentColor'; }, true);
    local ChatLogLabel = Library:CreateLabel({ Size = UDim2.new(1,-50,0,22); Position = UDim2.fromOffset(8,2); TextXAlignment = Enum.TextXAlignment.Left, Text = 'Chat Log'; TextSize = 15; ZIndex = 104; Parent = ChatLogInner; });
    local ChatClearBtn = Library:Create('TextButton', {
        AnchorPoint = Vector2.new(1,0); BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(1,-6,0,5); Size = UDim2.new(0,40,0,14); Text = 'Clear'; Font = Library.Font;
        TextSize = 11; TextColor3 = Library.FontColor; AutoButtonColor = false; ZIndex = 105; Parent = ChatLogInner;
    });
    Library:AddToRegistry(ChatClearBtn, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; TextColor3 = 'FontColor'; }, true);
    Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderSizePixel = 0; Position = UDim2.new(0,4,0,24); Size = UDim2.new(1,-8,0,1); ZIndex = 103; Parent = ChatLogInner; });
    local ChatScrolling = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.new(0,4,0,28); Size = UDim2.new(1,-8,1,-32);
        CanvasSize = UDim2.new(0,0,0,0); AutomaticCanvasSize = Enum.AutomaticSize.Y;
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png'; BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        ScrollBarThickness = 3; ScrollBarImageColor3 = Library.AccentColor; ZIndex = 103; Parent = ChatLogInner;
    });
    Library:AddToRegistry(ChatScrolling, { ScrollBarImageColor3 = 'AccentColor'; }, true);
    Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Padding = UDim.new(0,1); Parent = ChatScrolling; });
    Library:Create('UIPadding', { PaddingLeft = UDim.new(0,4); PaddingRight = UDim.new(0,2); PaddingTop = UDim.new(0,2); Parent = ChatScrolling; });

    local ChatLogMessages = {}; local ChatLogMaxMessages = 200; local ChatLogOrder = 0;

    local function AddChatMessage(playerObj, playerName, message, teamColor)
        ChatLogOrder = ChatLogOrder + 1;
        local timestamp = os.date('%H:%M:%S');
        local displayColor = teamColor or Library.FontColor;
        if playerObj then
            local priority = Library:GetPlayerPriority(playerObj);
            if priority and priority.Level > 0 and priority.Color then displayColor = priority.Color; end
        end
        local msgWidth = 300 - 126;
        local _, textH = Library:GetTextBounds(message, Library.Font, 12, Vector2.new(msgWidth, 9999));
        local rowHeight = math.max(16, textH + 4);
        local MsgFrame = Library:Create('Frame', {
            BackgroundTransparency = 1; Size = UDim2.new(1,0,0,rowHeight); LayoutOrder = ChatLogOrder; ZIndex = 104; Parent = ChatScrolling;
        });
        Library:CreateLabel({ Size = UDim2.new(0,50,0,16); Position = UDim2.new(0,0,0,0); Text = timestamp; TextSize = 11; TextColor3 = Color3.fromRGB(150,150,150); TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 105; Parent = MsgFrame; });
        Library:Create('TextLabel', { Size = UDim2.new(0,70,0,16); Position = UDim2.new(0,52,0,0); Text = playerName .. ':'; Font = Library.Font; TextSize = 12; TextColor3 = displayColor; TextXAlignment = Enum.TextXAlignment.Left; ClipsDescendants = true; BackgroundTransparency = 1; ZIndex = 105; Parent = MsgFrame; });
        Library:CreateLabel({ Size = UDim2.new(1,-126,0,rowHeight); Position = UDim2.new(0,124,0,0); Text = message; TextSize = 12; TextWrapped = true; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Top; ZIndex = 105; Parent = MsgFrame; });
        table.insert(ChatLogMessages, MsgFrame);
        if #ChatLogMessages > ChatLogMaxMessages then
            local old = table.remove(ChatLogMessages, 1);
            if old and old.Parent then old:Destroy() end
        end
        task.defer(function() ChatScrolling.CanvasPosition = Vector2.new(0, ChatScrolling.AbsoluteCanvasSize.Y); end)
    end

    ChatClearBtn.MouseButton1Click:Connect(function()
        for _, msg in next, ChatLogMessages do if msg and msg.Parent then msg:Destroy() end end
        ChatLogMessages = {}; ChatLogOrder = 0;
    end)
    local function ConnectPlayerChat(player)
        Library:GiveSignal(player.Chatted:Connect(function(message)
            if not ChatLogOuter.Visible then return end
            local teamColor = (player.Team and player.Team.TeamColor and player.Team.TeamColor.Color) or nil;
            AddChatMessage(player, player.DisplayName, message, teamColor);
        end))
    end
    for _, player in next, Players:GetPlayers() do ConnectPlayerChat(player); end
    Library:GiveSignal(Players.PlayerAdded:Connect(function(player) ConnectPlayerChat(player); end))
    Library.ChatLogFrame = ChatLogOuter;
    Library:MakeDraggable(ChatLogOuter);
    function Library:SetChatLogVisibility(Bool) ChatLogOuter.Visible = Bool; end
    function Library:AddChatMessage(playerName, message, teamColor) AddChatMessage(nil, playerName, message, teamColor); end

    -- ========================
    -- Status Bar Widget
    -- ========================
    local StatusBarOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 1);
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0.5, 0, 1, -5);
        Size = UDim2.new(0, 260, 0, 20);
        Visible = false;
        ZIndex = 200;
        Parent = ScreenGui;
    });
    local StatusBarInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 201;
        Parent = StatusBarOuter;
    });
    Library:AddToRegistry(StatusBarInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'AccentColor'; }, true);

    local StatusAccentTop = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2); ZIndex = 202; Parent = StatusBarInner;
    });
    Library:AddToRegistry(StatusAccentTop, { BackgroundColor3 = 'AccentColor'; }, true);

    local StatusLabel = Library:CreateLabel({
        Position = UDim2.fromOffset(8, 2);
        Size = UDim2.new(1, -10, 1, -2);
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 203;
        Parent = StatusBarInner;
    });

    Library.StatusBarFrame = StatusBarOuter;
    Library:MakeDraggable(StatusBarOuter);

    function Library:SetStatusBarVisibility(Bool)
        StatusBarOuter.Visible = Bool;
    end

    -- Poll status bar every second
    local statusStartTime = tick();
    local statusFrameCount = 0;
    local statusFPS = 60;
    local statusPrevTick = tick();

    Library:GiveSignal(RunService.Heartbeat:Connect(function(dt)
        statusFrameCount = statusFrameCount + 1;
        local now = tick();
        if (now - statusPrevTick) >= 1 then
            statusFPS = statusFrameCount;
            statusFrameCount = 0;
            statusPrevTick = now;

            if StatusBarOuter.Visible then
                local ping = 0;
                pcall(function()
                    ping = math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
                end)
                local uptime = math.floor(now - statusStartTime);
                local h = math.floor(uptime / 3600);
                local m = math.floor((uptime % 3600) / 60);
                local s = uptime % 60;
                local uptimeStr = string.format('%02d:%02d:%02d', h, m, s);
                StatusLabel.Text = string.format('FPS: %d  |  Ping: %dms  |  Uptime: %s', statusFPS, ping, uptimeStr);
                local W = Library:GetTextBounds(StatusLabel.Text, Library.Font, 13) + 20;
                StatusBarOuter.Size = UDim2.fromOffset(math.max(W, 200), 20);
            end
        end
    end))

    -- ========================
    -- Active Toggles Widget
    -- ========================
    local ATOuter = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0, 10, 0, 90);
        Size = UDim2.new(0, 180, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });
    local ATInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = ATOuter;
    });
    Library:AddToRegistry(ATInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
    Library:Create('UIGradient', {
        Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200)) });
        Rotation = 90; Parent = ATInner;
    });
    local ATAccentBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        Size = UDim2.new(0, 2, 1, 0); ZIndex = 105; Parent = ATInner;
    });
    Library:AddToRegistry(ATAccentBar, { BackgroundColor3 = 'AccentColor'; }, true);
    local ATTopBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2); ZIndex = 102; Parent = ATInner;
    });
    Library:AddToRegistry(ATTopBar, { BackgroundColor3 = 'AccentColor'; }, true);
    local ATHeader = Library:CreateLabel({
        Size = UDim2.new(1, -20, 0, 20); Position = UDim2.fromOffset(6, 0);
        TextXAlignment = Enum.TextXAlignment.Left; Text = 'Active Toggles'; TextSize = 13; ZIndex = 104; Parent = ATInner;
    });
    local ATCloseBtn = Library:Create('TextButton', {
        AnchorPoint = Vector2.new(1, 0.5); BackgroundTransparency = 1;
        Position = UDim2.new(1, -4, 0, 10); Size = UDim2.new(0, 12, 0, 12);
        Text = 'x'; Font = Library.Font; TextSize = 12; TextColor3 = Library.FontColor;
        AutoButtonColor = false; ZIndex = 106; Parent = ATInner;
    });
    Library:AddToRegistry(ATCloseBtn, { TextColor3 = 'FontColor'; }, true);
    ATCloseBtn.MouseButton1Click:Connect(function() ATOuter.Visible = false; end)

    local ATSeparator = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor; BorderSizePixel = 0;
        Position = UDim2.new(0, 4, 0, 20); Size = UDim2.new(1, -8, 0, 1); ZIndex = 103; Parent = ATInner;
    });
    Library:AddToRegistry(ATSeparator, { BackgroundColor3 = 'OutlineColor'; }, true);

    local ATContentFrame = Library:Create('Frame', {
        BackgroundTransparency = 1; Position = UDim2.new(0, 6, 0, 22);
        Size = UDim2.new(1, -6, 0, 0); ZIndex = 103; Parent = ATInner;
        ClipsDescendants = false;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 1); Parent = ATContentFrame;
    });

    Library.ActiveTogglesFrame = ATOuter;
    Library:MakeDraggable(ATOuter);

    Library._ActiveTogglesWidgetRefresh = function()
        for _, child in next, ATContentFrame:GetChildren() do
            if not child:IsA('UIListLayout') then child:Destroy(); end
        end
        local count = 0;
        for idx, toggle in next, Library._ActiveToggles do
            if toggle.Value then
                count = count + 1;
                local row = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 0, 14);
                    TextSize = 12;
                    Text = '• ' .. (toggle.TextLabel and toggle.TextLabel.Text or tostring(idx));
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 104;
                    Parent = ATContentFrame;
                });
            end
        end
        local totalH = math.max(22, 22 + count * 15);
        ATOuter.Size = UDim2.fromOffset(180, totalH);
        ATContentFrame.Size = UDim2.new(1, -6, 0, count * 15);
    end

    function Library:SetActiveTogglesWidgetVisibility(Bool)
        ATOuter.Visible = Bool;
    end

end; -- end create UI elements block

-- ============================================================
-- Watermark / Notify APIs
-- ============================================================
function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14);
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3);
    Library:SetWatermarkVisibility(true)
    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 14);
    YSize = YSize + 7

    local NotifyOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0); BorderColor3 = Color3.new(0, 0, 0);
        Position = UDim2.new(0.5, 0, 0, 0); Size = UDim2.new(0, XSize + 16, 0, YSize);
        BackgroundTransparency = 1; ZIndex = 100; Parent = Library.NotificationArea;
    });
    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
        BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0);
        BackgroundTransparency = 1; ZIndex = 101; Parent = NotifyOuter;
    });
    Library:AddToRegistry(NotifyInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0;
        Position = UDim2.new(0, 1, 0, 1); Size = UDim2.new(1, -2, 1, -2);
        BackgroundTransparency = 1; ZIndex = 102; Parent = NotifyInner;
    });
    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        }); Rotation = -90; Parent = InnerFrame;
    });
    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            });
        end
    });
    local NotifyLabel = Library:CreateLabel({
        Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, 0);
        Text = Text; TextXAlignment = Enum.TextXAlignment.Center;
        TextTransparency = 1; TextSize = 14; ZIndex = 103; Parent = InnerFrame;
    });
    local BottomColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        AnchorPoint = Vector2.new(0, 1); Position = UDim2.new(0, -1, 1, 1);
        Size = UDim2.new(1, 2, 0, 2); BackgroundTransparency = 1; ZIndex = 104; Parent = NotifyOuter;
    });
    Library:AddToRegistry(BottomColor, { BackgroundColor3 = 'AccentColor'; }, true);

    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out);
    TweenService:Create(NotifyInner, tweenInfo, { BackgroundTransparency = 0 }):Play();
    TweenService:Create(InnerFrame, tweenInfo, { BackgroundTransparency = 0 }):Play();
    TweenService:Create(NotifyLabel, tweenInfo, { TextTransparency = 0 }):Play();
    TweenService:Create(BottomColor, tweenInfo, { BackgroundTransparency = 0 }):Play();
    for _, child in next, NotifyLabel:GetChildren() do
        if child:IsA('UIStroke') then
            child.Transparency = 1; TweenService:Create(child, tweenInfo, { Transparency = 0 }):Play();
        end
    end

    task.spawn(function()
        wait(Time or 5);
        local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In);
        TweenService:Create(NotifyInner, fadeInfo, { BackgroundTransparency = 1 }):Play();
        TweenService:Create(InnerFrame, fadeInfo, { BackgroundTransparency = 1 }):Play();
        TweenService:Create(NotifyLabel, fadeInfo, { TextTransparency = 1 }):Play();
        TweenService:Create(BottomColor, fadeInfo, { BackgroundTransparency = 1 }):Play();
        for _, child in next, NotifyLabel:GetChildren() do
            if child:IsA('UIStroke') then TweenService:Create(child, fadeInfo, { Transparency = 1 }):Play(); end
        end
        wait(0.4);
        NotifyOuter:Destroy();
    end);
end;

-- ============================================================
-- CreateWindow
-- ============================================================
function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' and type(Config.Title) ~= 'table' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    -- Merge version history if specified inline (Config.VersionHistory)
    if type(Config.VersionHistory) == 'table' then
        Library.VersionHistory = Config.VersionHistory
    end

    local Window = { Tabs = {}; };

    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint;
        BackgroundColor3 = Color3.new(0, 0, 0);
        BorderSizePixel = 0;
        Position = Config.Position;
        Size = Config.Size;
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    -- ========================
    -- Drag: hide contents + 0.6 transparency
    -- ========================
    local function OnWindowDragStart()
        -- set transparency
        Outer.BackgroundTransparency = 0;
        TweenService:Create(Outer, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
        -- hide all groupbox contents
        for _, gb in next, Library._AllGroupboxes do
            if gb._container then gb._container.Visible = false end
        end
        -- fade window to 0.6
        for _, desc in next, Outer:GetDescendants() do
            if desc:IsA('Frame') or desc:IsA('ScrollingFrame') or desc:IsA('TextLabel') or desc:IsA('TextButton') or desc:IsA('ImageLabel') then
                pcall(function()
                    if desc.BackgroundTransparency < 1 then
                        desc.BackgroundTransparency = math.min(1, desc.BackgroundTransparency + 0.4)
                    end
                    if desc:IsA('TextLabel') or desc:IsA('TextButton') then
                        if rawget(desc, 'TextTransparency') ~= nil then
                            desc.TextTransparency = math.min(1, (desc.TextTransparency or 0) + 0.4)
                        end
                    end
                end)
            end
        end
    end

    local function OnWindowDragEnd()
        -- restore all groupbox contents
        for _, gb in next, Library._AllGroupboxes do
            if gb._container then gb._container.Visible = true end
        end
        -- restore full opacity by recalling UpdateColors
        Library:UpdateColorsUsingRegistry()
    end

    Library:MakeDraggable(Outer, 25, OnWindowDragStart, OnWindowDragEnd);

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset;
        Position = UDim2.new(0, 1, 0, 1);
        Size = UDim2.new(1, -2, 1, -2);
        ZIndex = 1;
        Parent = Outer;
    });
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'AccentColor'; });

    -- Title bar
    local TitleAccentText = ''
    local TitleRestText = ''
    if type(Config.Title) == 'table' then
        TitleAccentText = Config.Title.Accent or ''
        TitleRestText = Config.Title.Rest or ''
    elseif type(Config.Title) == 'string' then
        TitleRestText = Config.Title
    end

    local TitleContainer = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0); BackgroundTransparency = 1;
        Position = UDim2.new(0.5, 0, 0, 0); Size = UDim2.new(1, 0, 0, 25); ZIndex = 1; Parent = Inner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal;
        HorizontalAlignment = Enum.HorizontalAlignment.Center;
        VerticalAlignment = Enum.VerticalAlignment.Center;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TitleContainer;
    });

    local WindowLabelAccent = Library:CreateLabel({
        AutomaticSize = Enum.AutomaticSize.X; Size = UDim2.new(0, 0, 0, 25);
        Text = TitleAccentText; TextColor3 = Library.AccentColor;
        TextXAlignment = Enum.TextXAlignment.Center; LayoutOrder = 1; ZIndex = 1; Parent = TitleContainer;
    });
    Library:RemoveFromRegistry(WindowLabelAccent);
    Library:AddToRegistry(WindowLabelAccent, { TextColor3 = 'AccentColor'; });

    local WindowLabelRest = Library:CreateLabel({
        AutomaticSize = Enum.AutomaticSize.X; Size = UDim2.new(0, 0, 0, 25);
        Text = TitleRestText; TextXAlignment = Enum.TextXAlignment.Center; LayoutOrder = 2; ZIndex = 1; Parent = TitleContainer;
    });

    -- ========================
    -- Title bar extras: Log button + Version ID + Search button
    -- ========================
    local TitleBarBtns = Library:Create('Frame', {
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundTransparency = 1;
        Position = UDim2.new(1, -6, 0.5, 0);
        Size = UDim2.new(0, 0, 0, 25);
        AutomaticSize = Enum.AutomaticSize.X;
        ZIndex = 2;
        Parent = TitleContainer.Parent; -- parent to Inner directly so it doesn't participate in center layout
    });

    -- Log button
    local LogBtn = Library:Create('TextButton', {
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(1, -6, 0.5, 0);
        Size = UDim2.new(0, 32, 0, 16);
        Text = 'Log';
        Font = Library.Font;
        TextSize = 11;
        TextColor3 = Library.FontColor;
        AutoButtonColor = false;
        ZIndex = 3;
        Parent = Inner;
    });
    Library:AddToRegistry(LogBtn, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; TextColor3 = 'FontColor'; });

    -- Search button
    local SearchBtn = Library:Create('TextButton', {
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(1, -42, 0.5, 0);
        Size = UDim2.new(0, 32, 0, 16);
        Text = '🔍';
        Font = Library.Font;
        TextSize = 11;
        TextColor3 = Library.FontColor;
        AutoButtonColor = false;
        ZIndex = 3;
        Parent = Inner;
    });
    Library:AddToRegistry(SearchBtn, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; TextColor3 = 'FontColor'; });

    -- Version label (top-right of title bar)
    local versionStr = type(Config.Version) == 'string' and Config.Version or ''
    local VersionBtn = Library:Create('TextButton', {
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundTransparency = 1;
        Position = UDim2.new(1, -80, 0.5, 0);
        AutomaticSize = Enum.AutomaticSize.X;
        Size = UDim2.new(0, 0, 0, 20);
        Text = versionStr ~= '' and ('v' .. versionStr) or '';
        Font = Library.Font;
        TextSize = 12;
        TextColor3 = Library.AccentColor;
        AutoButtonColor = false;
        ZIndex = 3;
        Parent = Inner;
    });
    Library:RemoveFromRegistry(VersionBtn);
    Library:AddToRegistry(VersionBtn, { TextColor3 = 'AccentColor'; });

    -- Version history popup (grows upward from VersionBtn)
    local VersionHistPanel = Library:Create('Frame', {
        AnchorPoint = Vector2.new(1, 1);
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.AccentColor;
        ZIndex = 50;
        Visible = false;
        Parent = ScreenGui;
    });
    Library:AddToRegistry(VersionHistPanel, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'AccentColor'; });

    local VHAccentTop = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2); ZIndex = 51; Parent = VersionHistPanel;
    });
    Library:AddToRegistry(VHAccentTop, { BackgroundColor3 = 'AccentColor'; });

    local VHTitle = Library:CreateLabel({
        Position = UDim2.fromOffset(6, 4);
        Size = UDim2.new(1, -10, 0, 16);
        TextSize = 13;
        Text = 'Version History';
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 52;
        Parent = VersionHistPanel;
    });

    local VHSep = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor; BorderSizePixel = 0;
        Position = UDim2.new(0, 4, 0, 22); Size = UDim2.new(1, -8, 0, 1); ZIndex = 51; Parent = VersionHistPanel;
    });
    Library:AddToRegistry(VHSep, { BackgroundColor3 = 'OutlineColor'; });

    local VHContent = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(4, 26);
        Size = UDim2.new(1, -8, 0, 0);
        ZIndex = 52;
        Parent = VersionHistPanel;
    });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 2); Parent = VHContent;
    });

    local function BuildVersionHistoryPanel()
        for _, child in next, VHContent:GetChildren() do
            if not child:IsA('UIListLayout') then child:Destroy() end
        end
        local history = Library.VersionHistory or {}
        local contentH = 0
        for i = #history, 1, -1 do -- newest first
            local entry = history[i]
            local row = Library:Create('Frame', {
                BackgroundTransparency = 1; Size = UDim2.new(1, 0, 0, 30); ZIndex = 53; Parent = VHContent;
            })
            Library:CreateLabel({
                Position = UDim2.fromOffset(0, 0); Size = UDim2.new(1, 0, 0, 16);
                TextSize = 12;
                Text = string.format('[%s] v%s — %s', entry.date or '?', entry.version or '?', entry.text or '');
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 53;
                Parent = row;
            });
            contentH = contentH + 32
        end
        local totalH = contentH + 28 + 8
        local panelW = 280
        -- Position above VersionBtn
        local vAbsPos = VersionBtn.AbsolutePosition
        VersionHistPanel.Size = UDim2.fromOffset(panelW, totalH)
        VersionHistPanel.Position = UDim2.fromOffset(vAbsPos.X + VersionBtn.AbsoluteSize.X, vAbsPos.Y - totalH)
        VHContent.Size = UDim2.new(1, -8, 0, contentH)
    end

    local vhOpen = false
    VersionBtn.MouseButton1Click:Connect(function()
        if #Library.VersionHistory == 0 then return end
        vhOpen = not vhOpen
        if vhOpen then
            BuildVersionHistoryPanel()
            VersionHistPanel.Visible = true
        else
            VersionHistPanel.Visible = false
        end
    end)

    -- Close version history on outside click
    Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            if VersionHistPanel.Visible and not Library:IsMouseOverFrame(VersionHistPanel) and not Library:IsMouseOverFrame(VersionBtn) then
                VersionHistPanel.Visible = false
                vhOpen = false
            end
        end
    end))

    -- ========================
    -- Recent Changes Log panel (slides out from top)
    -- ========================
    local LogPanel = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderColor3 = Library.AccentColor;
        Size = UDim2.new(1, -2, 0, 0);
        Position = UDim2.new(0, 1, 0, -1);
        AnchorPoint = Vector2.new(0, 1);
        ClipsDescendants = true;
        Visible = false;
        ZIndex = 10;
        Parent = Outer;
    });
    Library:AddToRegistry(LogPanel, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'AccentColor'; });

    local LogPanelHeader = Library:CreateLabel({
        Position = UDim2.fromOffset(6, 4); Size = UDim2.new(1, -10, 0, 16);
        TextSize = 13; Text = 'Recent Changes'; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 11; Parent = LogPanel;
    });
    Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor; BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 22); Size = UDim2.new(1, 0, 0, 1); ZIndex = 11; Parent = LogPanel;
    });

    local LogScrolling = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1; BorderSizePixel = 0;
        Position = UDim2.fromOffset(4, 26); Size = UDim2.new(1, -8, 1, -30);
        CanvasSize = UDim2.new(0, 0, 0, 0); AutomaticCanvasSize = Enum.AutomaticSize.Y;
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png';
        ScrollBarThickness = 3; ScrollBarImageColor3 = Library.AccentColor; ZIndex = 12; Parent = LogPanel;
    });
    Library:AddToRegistry(LogScrolling, { ScrollBarImageColor3 = 'AccentColor'; });
    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder;
        Padding = UDim.new(0, 1); Parent = LogScrolling;
    });

    local logOpen = false

    local function RefreshLogPanel()
        for _, child in next, LogScrolling:GetChildren() do
            if not child:IsA('UIListLayout') then child:Destroy() end
        end
        for i = #Library._ChangeLog, 1, -1 do
            local entry = Library._ChangeLog[i]
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 14);
                TextSize = 12;
                Text = string.format('[%s] %s', entry.time, entry.text);
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 13;
                Parent = LogScrolling;
            });
        end
        task.defer(function() LogScrolling.CanvasPosition = Vector2.new(0, LogScrolling.AbsoluteCanvasSize.Y) end)
    end

    Library._ChangeLogUI = { Refresh = RefreshLogPanel }

    local LOG_PANEL_HEIGHT = 160;

    LogBtn.MouseButton1Click:Connect(function()
        if not Library.UtilitySettings.ChangesLog then return end
        logOpen = not logOpen
        if logOpen then
            RefreshLogPanel()
            LogPanel.Visible = true
            TweenService:Create(LogPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.new(1, -2, 0, LOG_PANEL_HEIGHT) }):Play()
        else
            TweenService:Create(LogPanel, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In), { Size = UDim2.new(1, -2, 0, 0) }):Play()
            task.delay(0.15, function() LogPanel.Visible = false end)
        end
    end)

    -- ========================
    -- Search bar
    -- ========================
    local SearchBarOuter = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0);
        Size = UDim2.new(1, -16, 0, 0); Position = UDim2.new(0, 8, 0, 30);
        ZIndex = 5; Visible = false; Parent = Inner;
    });
    Library:AddToRegistry(SearchBarOuter, { BorderColor3 = 'Black'; });
    local SearchBarInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.AccentColor;
        BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = SearchBarOuter;
    });
    Library:AddToRegistry(SearchBarInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'AccentColor'; });
    local SearchBox = Library:Create('TextBox', {
        BackgroundTransparency = 1; Position = UDim2.fromOffset(5, 0); Size = UDim2.new(1, -5, 1, 0);
        Font = Library.Font; PlaceholderText = 'Search...'; PlaceholderColor3 = Color3.fromRGB(120, 120, 120);
        Text = ''; TextColor3 = Library.FontColor; TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 7; Parent = SearchBarInner;
    });
    Library:AddToRegistry(SearchBox, { TextColor3 = 'FontColor'; });

    local searchOpen = false
    local SEARCH_BAR_H = 22

    SearchBtn.MouseButton1Click:Connect(function()
        if not Library.UtilitySettings.SearchBar then return end
        searchOpen = not searchOpen
        if searchOpen then
            SearchBarOuter.Visible = true
            SearchBarOuter.Size = UDim2.new(1, -16, 0, SEARCH_BAR_H)
            SearchBox:CaptureFocus()
        else
            SearchBarOuter.Visible = false
            SearchBox.Text = ''
        end
    end)

    -- Search filtering logic
    local function ApplySearch(query)
        local q = query:lower()
        for _, gb in next, Library._AllGroupboxes do
            if not gb._boxOuter then continue end
            local gbVisible = gb._tabFrame and gb._tabFrame.Visible or true
            if not gbVisible then continue end

            local anyMatch = false
            if q == '' then
                -- restore all
                if gb._container then
                    for _, child in next, gb._container:GetChildren() do
                        if not child:IsA('UIListLayout') then
                            child.BackgroundTransparency = child.BackgroundTransparency -- no-op, just don't hide
                            for _, desc in next, child:GetDescendants() do
                                if desc:IsA('TextLabel') or desc:IsA('TextButton') then
                                    desc.TextTransparency = 0
                                end
                            end
                        end
                    end
                end
                -- restore groupbox header
                if gb._headerLabel then gb._headerLabel.TextTransparency = 0; gb._headerLabel.TextColor3 = Library.FontColor end
                anyMatch = true
            else
                -- check children
                if gb._container then
                    for _, child in next, gb._container:GetChildren() do
                        if child:IsA('UIListLayout') then continue end
                        local childMatch = false
                        for _, desc in next, child:GetDescendants() do
                            if (desc:IsA('TextLabel') or desc:IsA('TextButton')) and desc.Text ~= '' then
                                if desc.Text:lower():find(q, 1, true) then
                                    childMatch = true
                                    break
                                end
                            end
                        end
                        for _, desc in next, child:GetDescendants() do
                            if desc:IsA('TextLabel') or desc:IsA('TextButton') then
                                desc.TextTransparency = childMatch and 0 or 0.6
                            end
                        end
                        if childMatch then anyMatch = true end
                    end
                end
                -- grey groupbox header if no children match
                if gb._headerLabel then
                    gb._headerLabel.TextTransparency = anyMatch and 0 or 0.6
                    gb._headerLabel.TextColor3 = anyMatch and Library.FontColor or Library.OutlineColor
                end
            end
        end
    end

    SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
        if Library.UtilitySettings.SearchBar then
            ApplySearch(SearchBox.Text)
        end
    end)

    -- Main section
    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, 25); Size = UDim2.new(1, -16, 1, -33); ZIndex = 1; Parent = Inner;
    });
    Library:AddToRegistry(MainSectionOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Color3.new(0, 0, 0);
        BorderMode = Enum.BorderMode.Inset; Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 1; Parent = MainSectionOuter;
    });
    Library:AddToRegistry(MainSectionInner, { BackgroundColor3 = 'BackgroundColor'; });

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1; Position = UDim2.new(0, 8, 0, 8); Size = UDim2.new(1, -16, 0, 21);
        ZIndex = 1; Parent = MainSectionInner;
    });
    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding); FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder; Parent = TabArea;
    });

    -- Search bar shifts tab content down when visible
    local TAB_CONTAINER_Y_DEFAULT = 30
    local TAB_CONTAINER_Y_SEARCH  = 30 + SEARCH_BAR_H + 2

    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor;
        Position = UDim2.new(0, 8, 0, TAB_CONTAINER_Y_DEFAULT); Size = UDim2.new(1, -16, 1, -(TAB_CONTAINER_Y_DEFAULT + 8));
        ZIndex = 2; Parent = MainSectionInner;
    });
    Library:AddToRegistry(TabContainer, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

    SearchBarOuter:GetPropertyChangedSignal('Visible'):Connect(function()
        if SearchBarOuter.Visible then
            TabContainer.Position = UDim2.new(0, 8, 0, TAB_CONTAINER_Y_SEARCH)
            TabContainer.Size = UDim2.new(1, -16, 1, -(TAB_CONTAINER_Y_SEARCH + 8))
        else
            TabContainer.Position = UDim2.new(0, 8, 0, TAB_CONTAINER_Y_DEFAULT)
            TabContainer.Size = UDim2.new(1, -16, 1, -(TAB_CONTAINER_Y_DEFAULT + 8))
            ApplySearch('')
        end
    end)

    function Window:SetWindowTitle(Title)
        if type(Title) == 'table' then
            WindowLabelAccent.Text = Title.Accent or ''
            WindowLabelRest.Text = Title.Rest or ''
        elseif type(Title) == 'string' then
            WindowLabelAccent.Text = ''
            WindowLabelRest.Text = Title
        end
    end;

    function Window:AddTab(Name)
        local Tab = { Groupboxes = {}; Tabboxes = {}; };
        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);

        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0); ZIndex = 1; Parent = TabArea;
        });
        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, -1); Text = Name; ZIndex = 1; Parent = TabButton;
        });

        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor; BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 1, 0); Size = UDim2.new(1, 0, 0, 1);
            BackgroundTransparency = 1; ZIndex = 3; Parent = TabButton;
        });
        Library:AddToRegistry(Blocker, { BackgroundColor3 = 'MainColor'; });

        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame'; BackgroundTransparency = 1; Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0); Visible = false; ZIndex = 2; Parent = TabContainer;
        });

        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1; BorderSizePixel = 0;
            Position = UDim2.new(0, 8-1, 0, 8-1); Size = UDim2.new(0.5, -12+2, 0, 507+2);
            CanvasSize = UDim2.new(0, 0, 0, 0); BottomImage = ''; TopImage = '';
            ScrollBarThickness = 0; ZIndex = 2; Parent = TabFrame;
        });
        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1; BorderSizePixel = 0;
            Position = UDim2.new(0.5, 4+1, 0, 8-1); Size = UDim2.new(0.5, -12+2, 0, 507+2);
            CanvasSize = UDim2.new(0, 0, 0, 0); BottomImage = ''; TopImage = '';
            ScrollBarThickness = 0; ZIndex = 2; Parent = TabFrame;
        });

        Library:Create('UIListLayout', { Padding = UDim.new(0, 8); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; HorizontalAlignment = Enum.HorizontalAlignment.Center; Parent = LeftSide; });
        Library:Create('UIListLayout', { Padding = UDim.new(0, 8); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; HorizontalAlignment = Enum.HorizontalAlignment.Center; Parent = RightSide; });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y);
            end);
        end;

        function Tab:ShowTab()
            for _, T in next, Window.Tabs do T:HideTab(); end;
            Blocker.BackgroundTransparency = 0;
            TabButton.BackgroundColor3 = Library.MainColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1;
            TabButton.BackgroundColor3 = Library.BackgroundColor;
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor';
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
            TabListLayout:ApplyLayout();
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 0, 507+2);
                ZIndex = 2; Parent = Info.Side == 1 and LeftSide or RightSide;
            });
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2); Position = UDim2.new(0, 1, 0, 1);
                ZIndex = 4; Parent = BoxOuter;
            });
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor'; });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2); ZIndex = 5; Parent = BoxInner;
            });
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });

            -- Groupbox header (icon support)
            local resolvedGBIcon = ResolveIcon(Info.Icon)
            local headerLabelX = resolvedGBIcon and 22 or 4
            local headerLabelW = resolvedGBIcon and (1 - 0) or 1

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, -(headerLabelX + 4), 0, 18);
                Position = UDim2.fromOffset(headerLabelX, 2);
                TextSize = 14;
                Text = Info.Name;
                TextXAlignment = Enum.TextXAlignment.Left;
                ClipsDescendants = true; -- FIX: prevent text overflow
                ZIndex = 5;
                Parent = BoxInner;
            });

            if resolvedGBIcon then
                Library:Create('ImageLabel', {
                    BackgroundTransparency = 1;
                    Position = UDim2.fromOffset(4, 3);
                    Size = UDim2.fromOffset(14, 14);
                    Image = resolvedGBIcon;
                    ZIndex = 6;
                    Parent = BoxInner;
                })
            end

            -- Double-click to collapse
            local collapsed = false
            local collapsedH = 24 -- header only height

            local function UpdateCollapsed()
                Container.Visible = not collapsed
                if collapsed then
                    BoxOuter.Size = UDim2.new(1, 0, 0, collapsedH)
                else
                    Groupbox:Resize()
                end
            end

            local lastClickTime = 0
            GroupboxLabel.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local now = tick()
                    if (now - lastClickTime) < 0.35 then
                        collapsed = not collapsed
                        UpdateCollapsed()
                    end
                    lastClickTime = now
                end
            end)

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1; Position = UDim2.new(0, 4, 0, 20);
                Size = UDim2.new(1, -4, 1, -20); ZIndex = 1; Parent = BoxInner;
            });
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Container;
            });

            function Groupbox:Resize()
                if collapsed then return end
                local Size = 0;
                for _, Element in next, Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;
                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
            end;

            Groupbox.Container = Container;
            Groupbox._container = Container;
            Groupbox._boxOuter = BoxOuter;
            Groupbox._headerLabel = GroupboxLabel;
            Groupbox._tabFrame = TabFrame;

            setmetatable(Groupbox, BaseGroupbox);
            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;
            table.insert(Library._AllGroupboxes, Groupbox);

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name, Icon)
            return Tab:AddGroupbox({ Side = 1; Name = Name; Icon = Icon; });
        end;

        function Tab:AddRightGroupbox(Name, Icon)
            return Tab:AddGroupbox({ Side = 2; Name = Name; Icon = Icon; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {}; };

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 0, 0); ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(1, -2, 1, -2); Position = UDim2.new(0, 1, 0, 1); ZIndex = 4; Parent = BoxOuter;
            });
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor'; });

            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 2); ZIndex = 10; Parent = BoxInner;
            });
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1; Position = UDim2.new(0, 0, 0, 1); Size = UDim2.new(1, 0, 0, 18); ZIndex = 5; Parent = BoxInner;
            });
            Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Left; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TabboxButtons; });

            function Tabbox:AddTab(Name)
                local InnerTab = {};
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor; BorderColor3 = Color3.new(0, 0, 0);
                    Size = UDim2.new(0.5, 0, 1, 0); ZIndex = 6; Parent = TabboxButtons;
                });
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; });
                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0); TextSize = 14; Text = Name; TextXAlignment = Enum.TextXAlignment.Center; ZIndex = 7; Parent = Button;
                });
                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor; BorderSizePixel = 0;
                    Position = UDim2.new(0, 0, 1, 0); Size = UDim2.new(1, 0, 0, 1); Visible = false; ZIndex = 9; Parent = Button;
                });
                Library:AddToRegistry(Block, { BackgroundColor3 = 'BackgroundColor'; });
                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1; Position = UDim2.new(0, 4, 0, 20); Size = UDim2.new(1, -4, 1, -20);
                    ZIndex = 1; Visible = false; Parent = BoxInner;
                });
                Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Container; });

                function InnerTab:Show()
                    for _, T in next, Tabbox.Tabs do T:Hide(); end;
                    Container.Visible = true; Block.Visible = true;
                    Button.BackgroundColor3 = Library.BackgroundColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor';
                    InnerTab:Resize();
                end;

                function InnerTab:Hide()
                    Container.Visible = false; Block.Visible = false;
                    Button.BackgroundColor3 = Library.MainColor;
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor';
                end;

                function InnerTab:Resize()
                    local TabCount = 0;
                    for _ in next, Tabbox.Tabs do TabCount = TabCount + 1; end;
                    for _, Btn in next, TabboxButtons:GetChildren() do
                        if not Btn:IsA('UIListLayout') then Btn.Size = UDim2.new(1 / TabCount, 0, 1, 0); end;
                    end;
                    if (not Container.Visible) then return; end;
                    local Size = 0;
                    for _, Element in next, InnerTab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then Size = Size + Element.Size.Y.Offset; end;
                    end;
                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        InnerTab:Show(); InnerTab:Resize();
                    end;
                end);

                InnerTab.Container = Container;
                Tabbox.Tabs[Name] = InnerTab;
                setmetatable(InnerTab, BaseGroupbox);
                InnerTab:AddBlank(3); InnerTab:Resize();

                if #TabboxButtons:GetChildren() == 2 then InnerTab:Show(); end;
                return InnerTab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;
            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end);

        if #TabContainer:GetChildren() == 1 then Tab:ShowTab(); end;
        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1; Size = UDim2.new(0, 0, 0, 0);
        Visible = true; Text = ''; Modal = false; Parent = ScreenGui;
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;

    function Library:Toggle()
        if Fading then return; end;
        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;

        if Toggled then
            Outer.Visible = true;
            task.spawn(function()
                local State = InputService.MouseIconEnabled;
                local Cursor = Drawing.new('Triangle');
                Cursor.Thickness = 1; Cursor.Filled = true; Cursor.Visible = true;
                local CursorOutline = Drawing.new('Triangle');
                CursorOutline.Thickness = 1; CursorOutline.Filled = false;
                CursorOutline.Color = Color3.new(0, 0, 0); CursorOutline.Visible = true;
                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;
                    local mPos = InputService:GetMouseLocation();
                    Cursor.Color = Library.AccentColor;
                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);
                    CursorOutline.PointA = Cursor.PointA;
                    CursorOutline.PointB = Cursor.PointB;
                    CursorOutline.PointC = Cursor.PointC;
                    RenderStepped:Wait();
                end;
                InputService.MouseIconEnabled = State;
                Cursor:Remove(); CursorOutline:Remove();
            end);
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};
            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency');
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency');
            end;
            local Cache = TransparencyCache[Desc];
            if (not Cache) then Cache = {}; TransparencyCache[Desc] = Cache; end;
            for _, Prop in next, Properties do
                if not Cache[Prop] then Cache[Prop] = Desc[Prop]; end;
                if Cache[Prop] == 1 then continue; end;
                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);
        Outer.Visible = Toggled;
        Fading = false;
    end

    -- Undo / Redo keybinds (active only when menu is open)
    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if not Toggled then return end
        if Processed then return end
        if Input.UserInputType == Enum.UserInputType.Keyboard then
            local isCtrl = InputService:IsKeyDown(Enum.KeyCode.LeftControl) or InputService:IsKeyDown(Enum.KeyCode.RightControl)
            if isCtrl then
                if Input.KeyCode == Enum.KeyCode.Z and Library.UtilitySettings.UndoRedo then
                    local entry = table.remove(Library.UndoStack)
                    if entry then ApplyUndoEntry(entry, Library.RedoStack) end
                elseif Input.KeyCode == Enum.KeyCode.Y and Library.UtilitySettings.UndoRedo then
                    local entry = table.remove(Library.RedoStack)
                    if entry then ApplyUndoEntry(entry, Library.UndoStack) end
                end
            end
        end
    end))

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;
    return Window;
end;

-- ============================================================
-- Player dropdown update
-- ============================================================
local function OnPlayerChange()
    local PlayerList = GetPlayersString();
    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then Value:SetValues(PlayerList); end;
    end;
end;
Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library
return Library
