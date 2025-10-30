-- SlentLib.lua (v5) - stable, fixed, feature-complete
-- Load: local Slent = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourname/SlentLib/main/SlentLib.lua"))()

local Slent = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- ===== THEME =====
local Theme = {
    Background = Color3.fromRGB(18,18,18),
    Secondary  = Color3.fromRGB(28,28,28),
    Accent      = Color3.fromRGB(138,85,255),
    Accent2     = Color3.fromRGB(80,60,255),
    Text        = Color3.fromRGB(235,235,235),
    Muted       = Color3.fromRGB(150,150,150),
    Shadow      = Color3.fromRGB(0,0,0)
}

-- ===== UTIL =====
local function create(class, props)
    local obj = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    return obj
end

local function roundify(gui, rad)
    if not gui then return end
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, rad or 6)
    c.Parent = gui
end

local function add_shadow(parent)
    if not parent then return end
    local img = create("ImageLabel", {
        Parent = parent,
        Size = UDim2.new(1, 24, 1, 24),
        Position = UDim2.new(0, -12, 0, -12),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5554236805",
        ImageColor3 = Theme.Shadow,
        ImageTransparency = 0.75,
        ZIndex = 0
    })
    return img
end

local function tween(obj, props, t)
    t = t or 0.18
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- update canvas for tab
local function updateCanvas(tab)
    if not tab or not tab.Content then return end
    local layout = tab.Content:FindFirstChildOfClass("UIListLayout")
    if not layout then return end
    task.wait() -- allow UI to compute AbsoluteContentSize
    local y = layout.AbsoluteContentSize.Y + 12
    tab.Content.CanvasSize = UDim2.new(0,0,0, y)
end

-- ensure at least one tab exists and present current
local function ensure_current_tab()
    if not Slent._currentTab then
        if #Slent._tabs > 0 then
            Slent._currentTab = Slent._tabs[1]
            Slent._tabs[1].Content.Visible = true
            Slent._tabs[1].Button.BackgroundColor3 = Theme.Accent
        else
            Slent.add_tab("Main")
        end
    end
end

-- ===== KEYBIND REGISTRY (clean) =====
Slent._keybinds = {} -- { ["F"] = {callback = fn} }

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local name = input.KeyCode.Name
        local entry = Slent._keybinds[name]
        if entry and type(entry.callback) == "function" then
            -- call protected to avoid error spam
            pcall(entry.callback, name)
        end
    end
end)

-- ===== INIT =====
function Slent.init(title, opts)
    opts = opts or {}
    local guiName = opts.guiName or "SlentHub"
    local screen = create("ScreenGui", {Name = guiName, Parent = game:GetService("CoreGui"), ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
    Slent._gui = screen

    -- Main
    local main = create("Frame", {
        Parent = screen,
        Size = UDim2.new(0,520,0,640),
        Position = UDim2.new(0.25,0,0.12,0),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ZIndex = 50
    })
    roundify(main, 12); add_shadow(main)
    Slent._main = main

    -- Title bar (drag only here)
    local titleBar = create("Frame", {Parent = main, Size = UDim2.new(1,0,0,44), BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0})
    roundify(titleBar,12)
    Slent._titleBar = titleBar

    local titleLabel = create("TextLabel", {Parent = titleBar, BackgroundTransparency = 1, Text = title or "Slent Hub", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Theme.Text, Size = UDim2.new(1,-20,1,0), Position = UDim2.new(0,12,0,0), TextXAlignment = Enum.TextXAlignment.Left})

    -- small controls
    local controls = create("Frame", {Parent = titleBar, Size = UDim2.new(0,96,1,0), Position = UDim2.new(1,-110,0,0), BackgroundTransparency = 1})
    local cLayout = Instance.new("UIListLayout", controls); cLayout.FillDirection = Enum.FillDirection.Horizontal; cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; cLayout.Padding = UDim.new(0,8)
    local btnMin = create("TextButton", {Parent = controls, Size = UDim2.new(0,36,0,28), BackgroundColor3 = Theme.Background, Text = "-", Font = Enum.Font.SourceSansBold, TextSize = 20, TextColor3 = Theme.Text, AutoButtonColor = false})
    local btnClose = create("TextButton", {Parent = controls, Size = UDim2.new(0,36,0,28), BackgroundColor3 = Theme.Background, Text = "x", Font = Enum.Font.SourceSansBold, TextSize = 18, TextColor3 = Theme.Text, AutoButtonColor = false})
    roundify(btnMin,6); roundify(btnClose,6)

    -- left tab column + right content
    local tabHolder = create("Frame", {Parent = main, Size = UDim2.new(0,140,1,-44), Position = UDim2.new(0,0,0,44), BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0})
    roundify(tabHolder,10)
    local contentHolder = create("Frame", {Parent = main, Size = UDim2.new(1,-150,1,-54), Position = UDim2.new(0,150,0,52), BackgroundColor3 = Theme.Background, BorderSizePixel = 0})
    roundify(contentHolder,8)

    local tabList = Instance.new("UIListLayout", tabHolder); tabList.Padding = UDim.new(0,8); tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Slent._tabHolder = tabHolder; Slent._contentHolder = contentHolder; Slent._tabs = {}

    -- titlebar drag
    do
        local dragging, startPos, dragStart
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; dragStart = input.Position; startPos = main.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end

    -- minimize/close
    btnClose.MouseButton1Click:Connect(function() if Slent._gui then Slent._gui:Destroy(); Slent._gui = nil end end)
    btnMin.MouseButton1Click:Connect(function()
        local vis = not contentHolder.Visible
        contentHolder.Visible = vis
        tabHolder.Visible = vis
        if not vis then tween(main, {Size = UDim2.new(0,220,0,60)}, 0.18) else tween(main, {Size = UDim2.new(0,520,0,640)}, 0.18) end
    end)

    return Slent
end

-- ===== TABS =====
function Slent.add_tab(name)
    if not Slent._tabHolder or not Slent._contentHolder then
        warn("SlentLib: call Slent.init() before adding tabs")
        return
    end

    local b = create("TextButton", {Parent = Slent._tabHolder, Size = UDim2.new(1,-16,0,34), BackgroundColor3 = Theme.Background, Text = name or "Tab", TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 15, AutoButtonColor = false})
    roundify(b,6)

    local content = create("ScrollingFrame", {Parent = Slent._contentHolder, Size = UDim2.new(1,-12,1,-12), Position = UDim2.new(0,6,0,6), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 8, Visible = false})
    local layout = Instance.new("UIListLayout", content); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0,10)

    b.MouseButton1Click:Connect(function()
        for _, t in ipairs(Slent._tabs) do
            t.Content.Visible = false
            t.Button.BackgroundColor3 = Theme.Background
        end
        content.Visible = true
        tween(b, {BackgroundColor3 = Theme.Accent}, 0.12)
        b.BackgroundColor3 = Theme.Accent
        Slent._currentTab = {Button = b, Content = content}
        updateCanvas(Slent._currentTab)
    end)

    local tab = {Button = b, Content = content}
    table.insert(Slent._tabs, tab)
    if #Slent._tabs == 1 then
        content.Visible = true; b.BackgroundColor3 = Theme.Accent; Slent._currentTab = tab; updateCanvas(tab)
    end
    return tab
end

-- ===== ELEMENTS (all updateCanvas at end) =====
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        -- don't spam the console — warn once (developer can inspect)
        warn("SlentLib: callback error - " .. tostring(err))
    end
end

function Slent.text(txt)
    ensure_current_tab()
    local lbl = create("TextLabel", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,22), BackgroundTransparency = 1, Text = tostring(txt or ""), TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left})
    updateCanvas(Slent._currentTab); return lbl
end

function Slent.separator()
    ensure_current_tab()
    local f = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,2), BackgroundColor3 = Color3.fromRGB(50,50,50)})
    updateCanvas(Slent._currentTab); return f
end

function Slent.button(txt, callback)
    ensure_current_tab()
    local btn = create("TextButton", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,36), BackgroundColor3 = Theme.Secondary, Text = tostring(txt or "Button"), TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 15, AutoButtonColor = false})
    roundify(btn,6)
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = Theme.Accent}, 0.12) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = Theme.Secondary}, 0.12) end)
    btn.MouseButton1Click:Connect(function() safeCall(callback) end)
    updateCanvas(Slent._currentTab); return btn
end

function Slent.input_box(placeholder, callback)
    ensure_current_tab()
    local box = create("TextBox", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,34), BackgroundColor3 = Theme.Secondary, PlaceholderText = tostring(placeholder or ""), TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14})
    roundify(box,6)
    box.FocusLost:Connect(function(enter) if enter then safeCall(callback, box.Text) end end)
    updateCanvas(Slent._currentTab); return box
end

function Slent.toggle(text, default, callback)
    ensure_current_tab()
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,36), BackgroundTransparency = 1})
    local label = create("TextLabel", {Parent = frame, Text = tostring(text or "Toggle"), Size = UDim2.new(0.7,0,1,0), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left})
    local btn = create("TextButton", {Parent = frame, Size = UDim2.new(0,54,0,28), Position = UDim2.new(1,-64,0.5,-14), BackgroundColor3 = default and Theme.Accent or Theme.Secondary, AutoButtonColor = false, Text = ""})
    roundify(btn,8)
    local knob = create("Frame", {Parent = btn, Size = UDim2.new(0,22,0,22), Position = default and UDim2.new(1,-24,0,2) or UDim2.new(0,2,0,2), BackgroundColor3 = Color3.fromRGB(245,245,245)})
    roundify(knob,12)
    local state = not not default
    local function setState(v)
        state = v
        tween(knob, {Position = state and UDim2.new(1,-24,0,2) or UDim2.new(0,2,0,2)}, 0.12)
        tween(btn, {BackgroundColor3 = state and Theme.Accent or Theme.Secondary}, 0.12)
        safeCall(callback, state)
    end
    btn.MouseButton1Click:Connect(function() setState(not state) end)
    setState(state)
    updateCanvas(Slent._currentTab); return frame
end

function Slent.dropdown(text, options, callback)
    ensure_current_tab()
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,36), BackgroundColor3 = Theme.Secondary})
    roundify(frame,6)
    local label = create("TextButton", {Parent = frame, Size = UDim2.new(1,-8,1,0), Position = UDim2.new(0,6,0,0), BackgroundTransparency = 1, Text = tostring(text or "Select"), TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, AutoButtonColor = false})
    local list = create("Frame", {Parent = frame, Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,1,6), BackgroundColor3 = Theme.Secondary, ClipsDescendants = true})
    roundify(list,6)
    local layout = Instance.new("UIListLayout", list); layout.Padding = UDim.new(0,6)

    local open = false
    local function toggle()
        open = not open
        local size = open and (#options * 34) or 0
        tween(list, {Size = UDim2.new(1,0,0,size)}, 0.18)
    end
    label.MouseButton1Click:Connect(toggle)

    for _,opt in ipairs(options or {}) do
        local b = create("TextButton", {Parent = list, Size = UDim2.new(1,-12,0,30), Position = UDim2.new(0,6,0,0), BackgroundTransparency = 1, Text = tostring(opt), TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, AutoButtonColor = false})
        b.MouseButton1Click:Connect(function()
            label.Text = tostring(opt)
            toggle()
            safeCall(callback, opt)
        end)
    end

    updateCanvas(Slent._currentTab); return frame
end

function Slent.slider(min, max, default, callback)
    ensure_current_tab()
    min = tonumber(min) or 0; max = tonumber(max) or 100; default = tonumber(default) or min
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,52), BackgroundTransparency = 1})
    local lbl = create("TextLabel", {Parent = frame, Text = tostring(default), Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left})
    local bar = create("Frame", {Parent = frame, Size = UDim2.new(1,-12,0,10), Position = UDim2.new(0,6,0,28), BackgroundColor3 = Theme.Secondary})
    roundify(bar,6)
    local fill = create("Frame", {Parent = bar, Size = UDim2.new(0,0,1,0), BackgroundColor3 = Theme.Accent})
    roundify(fill,6)

    local dragging = false
    local function setByX(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        local value = math.floor(min + (max-min) * rel)
        lbl.Text = tostring(value)
        safeCall(callback, value)
    end
    bar.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; setByX(inp.Position.X) end end)
    UserInputService.InputChanged:Connect(function(inp) if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then setByX(inp.Position.X) end end)
    UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)

    -- init
    local rel = (default - min) / math.max(1, (max-min))
    fill.Size = UDim2.new(rel,0,1,0); lbl.Text = tostring(default)
    updateCanvas(Slent._currentTab)
    return frame
end

function Slent.keybind(labelText, defaultKey, callback)
    ensure_current_tab()
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,36), BackgroundTransparency = 1})
    local label = create("TextLabel", {Parent = frame, Text = tostring(labelText or "Keybind"), Size = UDim2.new(0.7,0,1,0), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left})
    local btn = create("TextButton", {Parent = frame, Size = UDim2.new(0,140,0,30), Position = UDim2.new(1,-150,0,3), BackgroundColor3 = Theme.Secondary, Text = tostring(defaultKey or "None"), Font = Enum.Font.GothamBold, TextColor3 = Theme.Text, TextSize = 14, AutoButtonColor = false})
    roundify(btn,6)

    local binding = tostring(defaultKey or "None")
    local listening = false
    local conn
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        local prev = btn.Text
        btn.Text = "Press key..."
        conn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                binding = input.KeyCode.Name
                btn.Text = binding
                listening = false
                if conn then conn:Disconnect(); conn=nil end
                -- register binding
                Slent._keybinds[binding] = {callback = callback}
            end
        end)
    end)

    -- register default if provided
    if defaultKey and defaultKey ~= "None" then
        Slent._keybinds[defaultKey] = {callback = callback}
    end

    updateCanvas(Slent._currentTab)
    return {
        get = function() return binding end,
        set = function(k) binding = tostring(k); btn.Text = binding; Slent._keybinds[binding] = {callback = callback} end
    }
end

function Slent.color_picker(name, defaultColor, callback)
    ensure_current_tab()
    defaultColor = defaultColor or Theme.Accent
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0,380,0,150), BackgroundTransparency = 1})
    local title = create("TextLabel", {Parent = frame, Text = tostring(name or "Color"), Size = UDim2.new(1,0,0,20), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left})
    local swatch = create("Frame", {Parent = frame, Size = UDim2.new(0,48,0,48), Position = UDim2.new(1,-58,0,24), BackgroundColor3 = defaultColor})
    roundify(swatch,6)

    local r,g,b = math.floor(defaultColor.R*255), math.floor(defaultColor.G*255), math.floor(defaultColor.B*255)
    local function slider(y, labelText, initial, onChange)
        local lbl = create("TextLabel", {Parent = frame, Text = labelText, Size = UDim2.new(0.45,0,0,18), Position = UDim2.new(0,8,0,y), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left})
        local bar = create("Frame", {Parent = frame, Size = UDim2.new(0.5,-12,0,10), Position = UDim2.new(0,8,0,y+20), BackgroundColor3 = Theme.Secondary})
        roundify(bar,6)
        local fill = create("Frame", {Parent = bar, Size = UDim2.new(initial/255,0,1,0), BackgroundColor3 = Theme.Accent})
        roundify(fill,6)
        local dragging = false
        bar.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; local rel=(inp.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X; fill.Size=UDim2.new(math.clamp(rel,0,1),0,1,0); onChange(math.floor(fill.Size.X.Scale*255)) end end)
        UserInputService.InputChanged:Connect(function(inp) if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then local rel=(inp.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X; fill.Size=UDim2.new(math.clamp(rel,0,1),0,1,0); onChange(math.floor(fill.Size.X.Scale*255)) end end)
        UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    end

    slider(0,"R", r, function(v) r=v; swatch.BackgroundColor3 = Color3.fromRGB(r,g,b); safeCall(callback, Color3.fromRGB(r,g,b)) end)
    slider(48,"G", g, function(v) g=v; swatch.BackgroundColor3 = Color3.fromRGB(r,g,b); safeCall(callback, Color3.fromRGB(r,g,b)) end)
    slider(96,"B", b, function(v) b=v; swatch.BackgroundColor3 = Color3.fromRGB(r,g,b); safeCall(callback, Color3.fromRGB(r,g,b)) end)

    updateCanvas(Slent._currentTab)
    return frame
end

-- Notification
function Slent.notify(title, text, duration)
    duration = duration or 3
    if not Slent._gui then return end
    local notif = create("Frame", {Parent = Slent._gui, Size = UDim2.new(0,320,0,80), Position = UDim2.new(1,-340,1,-120), BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0})
    roundify(notif,8)
    local t = create("TextLabel", {Parent = notif, Text = tostring(title or "Notice"), Size = UDim2.new(1,-20,0,24), Position = UDim2.new(0,10,0,8), BackgroundTransparency = 1, TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left})
    local m = create("TextLabel", {Parent = notif, Text = tostring(text or ""), Size = UDim2.new(1,-20,0,40), Position = UDim2.new(0,10,0,30), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left})
    tween(notif, {Position = UDim2.new(1,-340,1,-160)}, 0.28)
    task.delay(duration, function()
        if notif and notif.Parent then
            tween(notif, {Position = UDim2.new(1,400,1,-160)}, 0.28)
            task.wait(0.28)
            if notif and notif.Parent then notif:Destroy() end
        end
    end)
    return notif
end

-- refresh canvases
function Slent.refresh()
    for _,t in ipairs(Slent._tabs) do updateCanvas(t) end
end

function Slent.clear()
    for _,t in ipairs(Slent._tabs) do
        if t.Button then t.Button:Destroy() end
        if t.Content then t.Content:Destroy() end
    end
    Slent._tabs = {}
    Slent._currentTab = nil
end

-- return
return Slent
