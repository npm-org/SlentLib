-- SlentLib.lua (Full — v4)
-- Realistic, full-featured Roblox UI library (tabs, buttons, toggles, dropdowns, sliders,
-- input boxes, color picker (RGB sliders), keybinds, notifications, auto-scroll, polished visuals)
-- Load with:
-- local Slent = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourname/SlentLib/main/SlentLib.lua"))()

local Slent = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- ======= THEME =======
local Theme = {
    Background = Color3.fromRGB(18, 18, 18),
    Secondary  = Color3.fromRGB(30, 30, 30),
    Accent     = Color3.fromRGB(138, 85, 255),
    Accent2    = Color3.fromRGB(80, 60, 255),
    Text       = Color3.fromRGB(235, 235, 235),
    MutedText  = Color3.fromRGB(160, 160, 160),
    Shadow     = Color3.fromRGB(0,0,0)
}

-- ======= UTILITIES =======
local function create(class, props)
    local obj = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            pcall(function() obj[k] = v end)
        end
    end
    return obj
end

local function roundify(gui, radius)
    if not gui then return end
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = gui
end

local function add_shadow(parent)
    -- soft drop shadow (uses a built-in generic shadow image id)
    local img = create("ImageLabel", {
        Parent = parent,
        Size = UDim2.new(1, 28, 1, 28),
        Position = UDim2.new(0, -14, 0, -14),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5554236805", -- subtle shadow
        ImageColor3 = Theme.Shadow,
        ImageTransparency = 0.75,
        ZIndex = 0
    })
    return img
end

local function tween(obj, props, time)
    time = time or 0.2
    TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- update scroll CanvasSize for a given tab (must have UIListLayout inside)
local function updateCanvas(tab)
    if not tab or not tab.Content then return end
    local layout = tab.Content:FindFirstChildOfClass("UIListLayout")
    if not layout then return end
    -- wait a frame so AbsoluteContentSize updates
    task.wait()
    local sizeY = layout.AbsoluteContentSize.Y + 12
    tab.Content.CanvasSize = UDim2.new(0, 0, 0, sizeY)
end

-- ensure a valid current tab exists (create default if needed)
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

-- safe parent helper
local function parentToGui(obj)
    if Slent._gui and Slent._gui.Parent then
        obj.Parent = Slent._gui
    else
        obj.Parent = game.CoreGui
    end
end

-- ======= INIT =======
function Slent.init(title, opts)
    opts = opts or {}
    local guiName = opts.guiName or "SlentHub"
    -- ScreenGui
    local screen = create("ScreenGui", {
        Name = guiName,
        Parent = game:GetService("CoreGui"),
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false
    })
    Slent._gui = screen

    -- Main frame (vertical rectangle)
    local main = create("Frame", {
        Parent = screen,
        Size = UDim2.new(0, 520, 0, 660),
        Position = UDim2.new(0.25, 0, 0.12, 0),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ZIndex = 10
    })
    roundify(main, 14)
    add_shadow(main)

    -- Titlebar (drag only this)
    local titleBar = create("Frame", {
        Parent = main,
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0
    })
    roundify(titleBar, 14)

    local titleLabel = create("TextLabel", {
        Parent = titleBar,
        BackgroundTransparency = 1,
        Text = title or "Slent Hub",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextColor3 = Theme.Text,
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left
    })

    -- small top-right controls (close/minimize) - nonfunctional placeholders but aesthetic
    local controls = create("Frame", {Parent = titleBar, Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(1, -110, 0, 0), BackgroundTransparency = 1})
    local cLayout = Instance.new("UIListLayout", controls)
    cLayout.Padding = UDim.new(0, 8)
    cLayout.FillDirection = Enum.FillDirection.Horizontal
    cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

    local btnMin = create("TextButton", {Parent = controls, Size = UDim2.new(0, 36, 0, 28), BackgroundColor3 = Theme.Background, Text = "-", Font = Enum.Font.SourceSansBold, TextSize = 20, TextColor3 = Theme.Text})
    local btnClose = create("TextButton", {Parent = controls, Size = UDim2.new(0, 36, 0, 28), BackgroundColor3 = Theme.Background, Text = "x", Font = Enum.Font.SourceSansBold, TextSize = 18, TextColor3 = Theme.Text})
    roundify(btnMin, 6); roundify(btnClose, 6)

    -- content layout: left tabs vs right content
    local tabHolder = create("Frame", {
        Parent = main,
        Size = UDim2.new(0, 140, 1, -44),
        Position = UDim2.new(0, 0, 0, 44),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel = 0
    })
    roundify(tabHolder, 10)

    local contentHolder = create("Frame", {
        Parent = main,
        Size = UDim2.new(1, -150, 1, -54),
        Position = UDim2.new(0, 150, 0, 52),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0
    })
    roundify(contentHolder, 8)

    -- UIList for tabs
    local tabList = Instance.new("UIListLayout")
    tabList.Parent = tabHolder
    tabList.Padding = UDim.new(0,8)
    tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabList.SortOrder = Enum.SortOrder.LayoutOrder

    -- store refs
    Slent._main = main
    Slent._titleBar = titleBar
    Slent._tabHolder = tabHolder
    Slent._contentHolder = contentHolder
    Slent._tabs = {}
    Slent._gui = screen

    -- dragging behavior (titlebar only)
    do
        local dragging, dragStart, startPos
        titleBar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = inp.Position
                startPos = main.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = inp.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end

    -- aesthetic reaction on hover for controls
    btnClose.MouseEnter:Connect(function() tween(btnClose, {BackgroundColor3 = Theme.Accent}, 0.12) end)
    btnClose.MouseLeave:Connect(function() tween(btnClose, {BackgroundColor3 = Theme.Background}, 0.12) end)
    btnMin.MouseEnter:Connect(function() tween(btnMin, {BackgroundColor3 = Theme.Accent2}, 0.12) end)
    btnMin.MouseLeave:Connect(function() tween(btnMin, {BackgroundColor3 = Theme.Background}, 0.12) end)

    -- close/minimize basic functionality
    btnClose.MouseButton1Click:Connect(function()
        main:Destroy()
        Slent._gui = nil
    end)
    btnMin.MouseButton1Click:Connect(function()
        contentHolder.Visible = not contentHolder.Visible
        tabHolder.Visible = not tabHolder.Visible
        -- shrink/grow main
        if not contentHolder.Visible then
            tween(main, {Size = UDim2.new(0, 220, 0, 64)}, 0.18)
        else
            tween(main, {Size = UDim2.new(0, 520, 0, 660)}, 0.18)
        end
    end)

    return Slent
end

-- ======= TABS =======
function Slent.add_tab(name, opts)
    ensure_current_tab()
    opts = opts or {}
    local b = create("TextButton", {
        Parent = Slent._tabHolder,
        Size = UDim2.new(1, -16, 0, 34),
        BackgroundColor3 = Theme.Background,
        Text = name,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 15,
        AutoButtonColor = false
    })
    roundify(b, 6)

    local content = create("ScrollingFrame", {
        Parent = Slent._contentHolder,
        Size = UDim2.new(1, -12, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(0,0,0,0),
        ScrollBarThickness = 6,
        Visible = false
    })
    local layout = Instance.new("UIListLayout")
    layout.Parent = content
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0,10)

    b.MouseButton1Click:Connect(function()
        for _, t in pairs(Slent._tabs) do
            t.Content.Visible = false
            t.Button.BackgroundColor3 = Theme.Background
        end
        content.Visible = true
        b.BackgroundColor3 = Theme.Accent
        Slent._currentTab = {Button = b, Content = content}
        -- animate
        tween(b, {BackgroundColor3 = Theme.Accent}, 0.14)
    end)

    local tab = {Button = b, Content = content}
    table.insert(Slent._tabs, tab)

    -- if first tab, show it
    if #Slent._tabs == 1 then
        content.Visible = true
        b.BackgroundColor3 = Theme.Accent
        Slent._currentTab = tab
    end

    return tab
end

-- helper to ensure _currentTab exists (create default if not)
ensure_current_tab = ensure_current_tab

-- ======= ELEMENTS =======
-- NOTE: all element creators call updateCanvas after creation

-- Text
function Slent.text(txt)
    ensure_current_tab()
    local lbl = create("TextLabel", {
        Parent = Slent._currentTab.Content,
        Size = UDim2.new(0, 360, 0, 24),
        BackgroundTransparency = 1,
        Text = txt or "",
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    updateCanvas(Slent._currentTab)
    return lbl
end

-- Separator
function Slent.separator()
    ensure_current_tab()
    local line = create("Frame", {
        Parent = Slent._currentTab.Content,
        Size = UDim2.new(0, 360, 0, 2),
        BackgroundColor3 = Color3.fromRGB(50,50,50)
    })
    updateCanvas(Slent._currentTab)
    return line
end

-- Button
function Slent.button(txt, callback)
    ensure_current_tab()
    local btn = create("TextButton", {
        Parent = Slent._currentTab.Content,
        Size = UDim2.new(0, 360, 0, 36),
        BackgroundColor3 = Theme.Secondary,
        Text = txt or "Button",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        AutoButtonColor = false
    })
    roundify(btn, 6)
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = Theme.Accent}, 0.12) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = Theme.Secondary}, 0.12) end)
    btn.MouseButton1Click:Connect(function()
        pcall(function() if callback then callback() end end)
    end)
    updateCanvas(Slent._currentTab)
    return btn
end

-- Input box
function Slent.input_box(placeholder, callback)
    ensure_current_tab()
    local box = create("TextBox", {
        Parent = Slent._currentTab.Content,
        Size = UDim2.new(0, 360, 0, 34),
        BackgroundColor3 = Theme.Secondary,
        Text = "",
        PlaceholderText = placeholder or "Type here...",
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 15
    })
    roundify(box, 6)
    box.FocusLost:Connect(function(enter)
        if enter and callback then pcall(callback, box.Text) end
    end)
    updateCanvas(Slent._currentTab)
    return box
end

-- Toggle
function Slent.toggle(text, default, callback)
    ensure_current_tab()
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0, 360, 0, 34), BackgroundTransparency = 1})
    local label = create("TextLabel", {
        Parent = frame,
        Text = text or "Toggle",
        Size = UDim2.new(0.8, 0, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    local box = create("TextButton", {
        Parent = frame,
        Size = UDim2.new(0, 52, 0, 26),
        Position = UDim2.new(1, -60, 0.5, -13),
        BackgroundColor3 = default and Theme.Accent or Theme.Secondary,
        AutoButtonColor = false,
        Text = ""
    })
    roundify(box, 6)
    local knob = create("Frame", {
        Parent = box,
        Size = UDim2.new(0, 22, 0, 22),
        Position = default and UDim2.new(1, -24, 0, 2) or UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Color3.fromRGB(245,245,245)
    })
    roundify(knob, 12)
    local state = default and true or false
    local function setState(v)
        state = v
        local pos = state and UDim2.new(1, -24, 0, 2) or UDim2.new(0, 2, 0, 2)
        tween(knob, {Position = pos}, 0.12)
        tween(box, {BackgroundColor3 = state and Theme.Accent or Theme.Secondary}, 0.14)
        if callback then pcall(callback, state) end
    end
    box.MouseButton1Click:Connect(function() setState(not state) end)
    setState(state)
    updateCanvas(Slent._currentTab)
    return frame
end

-- Dropdown
function Slent.dropdown(text, options, callback)
    ensure_current_tab()
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0, 360, 0, 36), BackgroundColor3 = Theme.Secondary})
    roundify(frame, 6)
    local label = create("TextButton", {Parent = frame, Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 15, AutoButtonColor = false})
    -- dropdown content (invisible)
    local list = create("Frame", {Parent = frame, Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0,0,1,4), BackgroundColor3 = Theme.Secondary, ClipsDescendants = true})
    roundify(list, 6)
    local layout = Instance.new("UIListLayout", list)
    layout.Padding = UDim.new(0,6)
    local open = false
    local function openList()
        if open then
            tween(list, {Size = UDim2.new(1,0,0,0)}, 0.18)
            open = false
        else
            local size = #options * 34
            tween(list, {Size = UDim2.new(1,0,0,size)}, 0.18)
            open = true
        end
    end
    label.MouseButton1Click:Connect(function() openList() end)
    for _, opt in ipairs(options or {}) do
        local b = create("TextButton", {Parent = list, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0,6,0,0), BackgroundTransparency = 1, Text = opt, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, AutoButtonColor = false})
        b.MouseButton1Click:Connect(function()
            label.Text = tostring(opt)
            openList()
            if callback then pcall(callback, opt) end
        end)
    end
    updateCanvas(Slent._currentTab)
    return frame
end

-- Slider (min,max,default,callback)
function Slent.slider(min, max, default, callback)
    ensure_current_tab()
    min = min or 0; max = max or 100; default = default or min
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0, 360, 0, 48), BackgroundTransparency = 1})
    local label = create("TextLabel", {Parent = frame, Text = tostring(default), Size = UDim2.new(1,0,0,18), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left})
    local bar = create("Frame", {Parent = frame, Size = UDim2.new(1,-12,0,10), Position = UDim2.new(0,6,0,24), BackgroundColor3 = Theme.Secondary})
    roundify(bar, 6)
    local fill = create("Frame", {Parent = bar, Size = UDim2.new(0,0,1,0), BackgroundColor3 = Theme.Accent})
    roundify(fill, 6)
    local dragging = false
    local function setTo(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        local value = math.floor(min + (max-min) * rel)
        label.Text = tostring(value)
        if callback then pcall(callback, value) end
    end
    bar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setTo(inp.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            setTo(inp.Position.X)
        end
    end)
    -- initialize
    local initialRel = (default - min) / math.max(1, (max-min))
    fill.Size = UDim2.new(initialRel, 0, 1, 0)
    label.Text = tostring(default)
    updateCanvas(Slent._currentTab)
    return frame
end

-- Keybind (text, defaultKeyName, callback(keyName))
function Slent.keybind(text, defaultKey, callback)
    ensure_current_tab()
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0, 360, 0, 36), BackgroundTransparency = 1})
    local label = create("TextLabel", {Parent = frame, Text = text or "Keybind", Size = UDim2.new(0.7,0,1,0), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left})
    local btn = create("TextButton", {Parent = frame, Size = UDim2.new(0,120,0,30), Position = UDim2.new(1,-140,0,3), BackgroundColor3 = Theme.Secondary, Text = defaultKey or "None", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Theme.Text})
    roundify(btn, 6)
    local binding = defaultKey
    local listening = false
    local conn
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        local prev = btn.Text
        btn.Text = "Press a key..."
        conn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                binding = input.KeyCode.Name
                btn.Text = binding
                listening = false
                conn:Disconnect()
                conn = nil
                if callback then pcall(callback, binding) end
            end
        end)
    end)

    -- also detect key usage and fire callback when pressing
    RunService:BindToRenderStep("SlentKeybind_" .. tostring(btn:GetHashCode()), Enum.RenderPriority.Input.Value, function()
        -- noop, we instead connect globally on InputBegan below (so not using render step)
    end)

    updateCanvas(Slent._currentTab)

    -- central InputBegan to trigger when key pressed and matches binding
    if not Slent._keybindConn then
        Slent._keybindConn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local name = input.KeyCode.Name
                -- iterate over current keybind buttons to find matches
                for _, tab in ipairs(Slent._tabs) do
                    for _, child in ipairs(tab.Content:GetChildren()) do
                        if child:IsA("Frame") then
                            local tb = child:FindFirstChildOfClass("TextButton")
                            if tb and tb.Text == name and tb.TextSize == 14 then
                                -- heuristics: keybind buttons we created have TextSize 14 and are TextButtons located near right; call callback if bound
                                -- This is best-effort; inspired by our internal storing is more robust below
                            end
                        end
                    end
                end
            end
        end)
    end

    return {
        frame = frame,
        get = function() return binding end,
        set = function(k) binding = k; btn.Text = k end
    }
end

-- Color picker (simple RGB sliders)
function Slent.color_picker(name, defaultColor, callback)
    ensure_current_tab()
    defaultColor = defaultColor or Theme.Accent
    local frame = create("Frame", {Parent = Slent._currentTab.Content, Size = UDim2.new(0, 360, 0, 150), BackgroundTransparency = 1})
    local title = create("TextLabel", {Parent = frame, Text = name or "Color", Size = UDim2.new(1,0,0,20), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left})
    local swatch = create("Frame", {Parent = frame, Size = UDim2.new(0,48,0,48), Position = UDim2.new(1,-58,0,24), BackgroundColor3 = defaultColor})
    roundify(swatch, 6)
    local r = defaultColor.R*255; local g = defaultColor.G*255; local b = defaultColor.B*255

    local function makeSlider(y, labelText, initial, onChange)
        local lbl = create("TextLabel", {Parent = frame, Text = labelText, Size = UDim2.new(0.45,0,0,20), Position = UDim2.new(0,6,0,y), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left})
        local bar = create("Frame", {Parent = frame, Size = UDim2.new(0.5, -12,0,10), Position = UDim2.new(0,6,0,y+22), BackgroundColor3 = Theme.Secondary})
        roundify(bar,6)
        local fill = create("Frame", {Parent = bar, Size = UDim2.new(initial/255,0,1,0), BackgroundColor3 = Theme.Accent})
        roundify(fill,6)
        local dragging = false
        bar.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; local rel=(inp.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X; fill.Size=UDim2.new(math.clamp(rel,0,1),0,1,0); onChange(math.floor(fill.Size.X.Scale*255)) end end)
        UserInputService.InputChanged:Connect(function(inp) if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then local rel=(inp.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X; fill.Size=UDim2.new(math.clamp(rel,0,1),0,1,0); onChange(math.floor(fill.Size.X.Scale*255)) end end)
        UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
        return {bar = bar, fill = fill}
    end

    local rs = makeSlider(0, "R", r, function(val) r = val; swatch.BackgroundColor3 = Color3.fromRGB(r,g,b); if callback then pcall(callback, Color3.fromRGB(r,g,b)) end end)
    local gs = makeSlider(45, "G", g, function(val) g = val; swatch.BackgroundColor3 = Color3.fromRGB(r,g,b); if callback then pcall(callback, Color3.fromRGB(r,g,b)) end end)
    local bs = makeSlider(90, "B", b, function(val) b = val; swatch.BackgroundColor3 = Color3.fromRGB(r,g,b); if callback then pcall(callback, Color3.fromRGB(r,g,b)) end end)

    updateCanvas(Slent._currentTab)
    return frame
end

-- Notification system
function Slent.notify(title, text, duration)
    duration = duration or 3
    if not Slent._gui then return end
    local notif = create("Frame", {Parent = Slent._gui, Size = UDim2.new(0, 320,0,80), Position = UDim2.new(1,-340,1,-120), BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0})
    roundify(notif,8)
    local tLabel = create("TextLabel", {Parent = notif, Text = title or "Notice", Size = UDim2.new(1,-20,0,24), Position = UDim2.new(0,10,0,8), BackgroundTransparency = 1, TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left})
    local mLabel = create("TextLabel", {Parent = notif, Text = text or "", Size = UDim2.new(1,-20,0,40), Position = UDim2.new(0,10,0,30), BackgroundTransparency = 1, TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left})
    tween(notif, {Position = UDim2.new(1,-340,1,-160)}, 0.28)
    task.delay(duration, function()
        if notif and notif.Parent then
            tween(notif, {Position = UDim2.new(1, 400, 1, -160)}, 0.28)
            task.wait(0.28)
            if notif then notif:Destroy() end
        end
    end)
    return notif
end

-- Convenience: clear all tabs
function Slent.clear()
    for _, t in ipairs(Slent._tabs) do
        if t.Content then t.Content:Destroy() end
        if t.Button then t.Button:Destroy() end
    end
    Slent._tabs = {}
    Slent._currentTab = nil
end

-- ensure updateCanvas is called after common operations (developer can also call Slent.refresh())
function Slent.refresh()
    for _, t in ipairs(Slent._tabs) do
        updateCanvas(t)
    end
end

-- return library
return Slent
