--!nocheck
-- BarcodeUI — self-contained WindUI-style library
-- ESP + Aim Lock + Mobile Fly + PC Fly + Spin Bot
-- + TP + FOV (Frame-based) + Health Bars + Keybind + Mobile Aim Button

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- THEME + UTILITY
-- ============================================================
local Theme = {
    Background = Color3.fromRGB(16, 16, 16),
    Panel      = Color3.fromRGB(26, 26, 26),
    PanelAlt   = Color3.fromRGB(40, 40, 45),
    Accent     = Color3.fromRGB(0, 145, 255),
    Text       = Color3.fromRGB(255, 255, 255),
    SubText    = Color3.fromRGB(161, 161, 170),
    Border     = Color3.fromRGB(60, 60, 60),
    ToggleOn   = Color3.fromRGB(51, 199, 89),
    ToggleOff  = Color3.fromRGB(60, 60, 60),
}

local function new(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do if k ~= "Parent" then inst[k] = v end end
    for _, child in ipairs(children or {}) do child.Parent = inst end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end

local function tween(inst, t, goal, style)
    local ti = TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(inst, ti, goal):Play()
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================================
-- ROOT GUIS
-- ============================================================
local uiGui = new("ScreenGui", {
    Name = "BarcodeUI", Parent = PlayerGui,
    IgnoreGuiInset = true, ResetOnSpawn = false,
    DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local popupGui = new("ScreenGui", {
    Name = "BarcodeUI_Popups", Parent = PlayerGui,
    IgnoreGuiInset = true, ResetOnSpawn = false,
    DisplayOrder = 101, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local fovGui = new("ScreenGui", {
    Name = "BarcodeFOV", Parent = PlayerGui,
    IgnoreGuiInset = true, ResetOnSpawn = false,
    DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local fovFrame = new("Frame", {
    Parent = fovGui,
    Name = "FOVCircle",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    Size = UDim2.fromOffset(500, 500),
    Position = UDim2.fromOffset(0, 0),
}, {
    new("UICorner", { CornerRadius = UDim.new(1, 0) }),
    new("UIStroke", {
        Color = Theme.Accent, Thickness = 1.5, Transparency = 0.35,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }),
})

local function computeScale()
    local cam = workspace.CurrentCamera
    if not cam then return 1 end
    local vp = cam.ViewportSize
    return math.clamp(math.min((vp.X - 40) / 580, (vp.Y - 40) / 460, 1), 0.55, 1)
end

-- ============================================================
-- WINDOW CLASS
-- ============================================================
local Window = {}
Window.__index = Window

function Window.new(config)
    local self = setmetatable({}, Window)
    self.Tabs, self.OpenDropdowns, self.Minimized = {}, {}, false
    self.Width, self.Height, self.SidebarWidth = config.Width or 580, config.Height or 460, config.SidebarWidth or 160

    local main = new("Frame", {
        Name = "Main", Parent = uiGui,
        Size = UDim2.fromOffset(self.Width, self.Height),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0, ClipsDescendants = true,
    }, {
        corner(12),
        new("UIStroke", { Color = Theme.Border, Thickness = 1, Transparency = 0.5 }),
    })
    self.Main = main
    self.Scale = new("UIScale", { Scale = computeScale(), Parent = main })
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        tween(self.Scale, 0.2, { Scale = computeScale() })
    end)

    local titleBar = new("Frame", {
        Name = "TitleBar", Parent = main,
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Theme.Panel, BorderSizePixel = 0,
    })
    new("TextLabel", {
        Parent = titleBar, Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1,
        Text = config.Title or "Barcode UI", TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local function makeButton(offset, symbol, hoverColor, onClick)
        local btn = new("TextButton", {
            Parent = titleBar, Size = UDim2.fromOffset(28, 28),
            Position = UDim2.new(1, offset, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.PanelAlt, BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false,
        }, {
            corner(6),
            new("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = symbol, TextColor3 = Theme.SubText,
                Font = Enum.Font.GothamBold, TextSize = 18,
            }),
        })
        btn.MouseEnter:Connect(function()
            tween(btn, 0.1, { BackgroundTransparency = 0.3 })
            btn.TextLabel.TextColor3 = hoverColor or Theme.Text
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, 0.1, { BackgroundTransparency = 1 })
            btn.TextLabel.TextColor3 = Theme.SubText
        end)
        btn.MouseButton1Click:Connect(onClick)
    end
    makeButton(-36, "×", Color3.fromRGB(255, 100, 100), function() self:Destroy() end)
    makeButton(-70, "−", nil, function() self:ToggleMinimize() end)

    self.Sidebar = new("Frame", {
        Parent = main, Size = UDim2.new(0, self.SidebarWidth, 1, -42),
        Position = UDim2.fromOffset(0, 42),
        BackgroundColor3 = Theme.Background, BackgroundTransparency = 1, BorderSizePixel = 0,
    }, {
        new("UIListLayout", { Padding = UDim.new(0, 2) }),
        new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
    })
    self.Content = new("Frame", {
        Parent = main, Size = UDim2.new(1, -self.SidebarWidth, 1, -42),
        Position = UDim2.fromOffset(self.SidebarWidth, 42),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    })
    self:_setupDrag(titleBar)
    return self
end

function Window:_setupDrag(handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, self.Main.Position
            self:_closeAllDropdowns()
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            self.Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

function Window:_closeAllDropdowns() for d in pairs(self.OpenDropdowns) do if d.Close then d:Close() end end end

function Window:ToggleMinimize()
    self.Minimized = not self.Minimized
    if self.Minimized then
        tween(self.Main, 0.25, { Size = UDim2.fromOffset(self.Width, 42) }, Enum.EasingStyle.Quart)
        self.Sidebar.Visible, self.Content.Visible = false, false
    else
        tween(self.Main, 0.25, { Size = UDim2.fromOffset(self.Width, self.Height) }, Enum.EasingStyle.Quart)
        self.Sidebar.Visible, self.Content.Visible = true, true
    end
    self:_closeAllDropdowns()
end

function Window:Destroy() uiGui:Destroy(); popupGui:Destroy() end

function Window:CreateTab(title)
    local tab = { Title = title, Window = self }
    local idx = #self.Tabs + 1
    self.Tabs[idx] = tab

    local tabButton = new("TextButton", {
        Parent = self.Sidebar, Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    }, {
        corner(6),
        new("TextLabel", {
            Name = "Label", Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0),
            BackgroundTransparency = 1, Text = title, TextColor3 = Theme.SubText,
            Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        }),
    })

    local tabContent = new("ScrollingFrame", {
        Parent = self.Content, Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.SubText, ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
    }, {
        new("UIListLayout", { Padding = UDim.new(0, 6) }),
        new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 12) }),
    })
    tab.Content = tabContent

    tabButton.MouseButton1Click:Connect(function() self:SelectTab(idx) end)
    tabButton.MouseEnter:Connect(function()
        if self.ActiveTab ~= idx then tween(tabButton, 0.1, { BackgroundTransparency = 0.85 }); tabButton.Label.TextColor3 = Theme.Text end
    end)
    tabButton.MouseLeave:Connect(function()
        if self.ActiveTab ~= idx then tween(tabButton, 0.1, { BackgroundTransparency = 1 }); tabButton.Label.TextColor3 = Theme.SubText end
    end)

    tab.Button   = tabButton
    tab.Toggle   = function(_, c) return self:_createToggle(tabContent, c) end
    tab.Dropdown = function(_, c) return self:_createDropdown(tabContent, c) end
    tab.Slider   = function(_, c) return self:_createSlider(tabContent, c) end
    tab.Button_  = function(_, c) return self:_createButton(tabContent, c) end
    tab.Keybind  = function(_, c) return self:_createKeybind(tabContent, c) end

    if idx == 1 then self:SelectTab(1) end
    return tab
end

function Window:SelectTab(index)
    local tab = self.Tabs[index]
    if not tab then return end
    if self.ActiveTab and self.Tabs[self.ActiveTab] then
        local prev = self.Tabs[self.ActiveTab]
        tween(prev.Button, 0.15, { BackgroundTransparency = 1 })
        prev.Button.Label.TextColor3 = Theme.SubText
        prev.Content.Visible = false
    end
    tween(tab.Button, 0.15, { BackgroundTransparency = 0 })
    tab.Button.Label.TextColor3 = Theme.Text
    tab.Content.Visible = true
    self.ActiveTab = index
    self:_closeAllDropdowns()
end

function Window:_createToggle(parent, config)
    local state = { Value = config.Default or false }
    local callback = config.Callback or function() end
    local hasDesc = config.Description and config.Description ~= ""
    local row = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, hasDesc and 52 or 40),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.4, BorderSizePixel = 0,
    }, { corner(6) })
    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, -70, 0, hasDesc and 20 or 40),
        Position = UDim2.fromOffset(12, hasDesc and 8 or 0),
        BackgroundTransparency = 1, Text = config.Title or "Toggle",
        TextColor3 = Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    if hasDesc then
        new("TextLabel", {
            Parent = row, Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(12, 26),
            BackgroundTransparency = 1, Text = config.Description,
            TextColor3 = Theme.SubText, Font = Enum.Font.Gotham, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
    end
    local track = new("Frame", {
        Parent = row, Size = UDim2.fromOffset(36, 20),
        Position = UDim2.new(1, -48, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = state.Value and Theme.ToggleOn or Theme.ToggleOff, BorderSizePixel = 0,
    }, { corner(10) })
    local knob = new("Frame", {
        Parent = track, Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(state.Value and 20 or 3, 3),
        BackgroundColor3 = Theme.Text, BorderSizePixel = 0,
    }, { corner(7) })
    local function setValue(v, skipCb)
        state.Value = v
        tween(knob, 0.15, { Position = UDim2.fromOffset(v and 20 or 3, 3) }, Enum.EasingStyle.Quart)
        tween(track, 0.15, { BackgroundColor3 = v and Theme.ToggleOn or Theme.ToggleOff }, Enum.EasingStyle.Quart)
        if not skipCb then pcall(callback, v) end
    end
    new("TextButton", {
        Parent = row, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    }).MouseButton1Click:Connect(function() setValue(not state.Value) end)
    row.MouseEnter:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.2 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.4 }) end)
    pcall(callback, state.Value)
    return { Set = function(_, v) setValue(v, true) end, Get = function() return state.Value end }
end

function Window:_createDropdown(parent, config)
    local state = { Value = config.Default }
    local callback = config.Callback or function() end
    local options = config.Options or {}
    local hasDesc = config.Description and config.Description ~= ""
    local popup, isOpen = nil, false
    local dropdownObj = {}
    local row = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, hasDesc and 52 or 40),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.4, BorderSizePixel = 0,
    }, { corner(6) })
    new("TextLabel", {
        Parent = row, Size = UDim2.new(0.5, -20, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = config.Title or "Dropdown",
        TextColor3 = Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    local btn = new("TextButton", {
        Parent = row, Size = UDim2.fromOffset(140, 28),
        Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Background, Text = "", AutoButtonColor = false,
    }, {
        corner(5),
        new("UIStroke", { Color = Theme.Border, Transparency = 0.5 }),
        new("TextLabel", {
            Name = "ValueLabel", Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(8, 0),
            BackgroundTransparency = 1, Text = tostring(state.Value or "--"),
            TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }),
        new("TextLabel", {
            Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -22, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1,
            Text = "▾", TextColor3 = Theme.SubText, Font = Enum.Font.GothamBold, TextSize = 12,
        }),
    })
    local valueLabel = btn:FindFirstChild("ValueLabel")
    function dropdownObj.Close()
        if not isOpen then return end
        isOpen = false
        if popup then popup:Destroy(); popup = nil end
        self.OpenDropdowns[dropdownObj] = nil
    end
    local function open()
        if isOpen then return end
        self:_closeAllDropdowns()
        isOpen = true
        self.OpenDropdowns[dropdownObj] = true
        local bp, bs = btn.AbsolutePosition, btn.AbsoluteSize
        local maxH = math.min(#options * 30 + 8, 260)
        local screenY = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 1080
        local y = bp.Y + bs.Y + 4
        if y + maxH > screenY - 10 then y = bp.Y - maxH - 4 end
        local catcher = new("TextButton", {
            Parent = popupGui, Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Text = "", ZIndex = 1,
        })
        catcher.MouseButton1Click:Connect(function() dropdownObj:Close() end)
        popup = new("Frame", {
            Parent = popupGui, Size = UDim2.fromOffset(bs.X, maxH),
            Position = UDim2.fromOffset(bp.X, y),
            BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = 2,
        }, {
            corner(6),
            new("UIStroke", { Color = Theme.Border, Transparency = 0.3 }),
            new("ScrollingFrame", {
                Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4),
                BackgroundTransparency = 1, ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.SubText, ScrollBarImageTransparency = 0.5,
                CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            }, { new("UIListLayout", { Padding = UDim.new(0, 2) }) }),
        })
        popup.Destroying:Connect(function() if catcher then catcher:Destroy() end end)
        local list = popup:FindFirstChildOfClass("ScrollingFrame")
        for i, opt in ipairs(options) do
            local isSelected = state.Value == opt
            local optBtn = new("TextButton", {
                Parent = list, Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = Theme.PanelAlt, BackgroundTransparency = isSelected and 0 or 1,
                Text = "", AutoButtonColor = false, LayoutOrder = i,
            }, {
                corner(4),
                new("TextLabel", {
                    Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0),
                    BackgroundTransparency = 1, Text = tostring(opt),
                    TextColor3 = isSelected and Theme.Accent or Theme.Text,
                    Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
                }),
            })
            optBtn.MouseEnter:Connect(function() if not isSelected then tween(optBtn, 0.08, { BackgroundTransparency = 0.8 }) end end)
            optBtn.MouseLeave:Connect(function() if not isSelected then tween(optBtn, 0.08, { BackgroundTransparency = 1 }) end end)
            optBtn.MouseButton1Click:Connect(function()
                state.Value = opt
                valueLabel.Text = tostring(opt)
                dropdownObj:Close()
                pcall(callback, opt)
            end)
        end
    end
    btn.MouseButton1Click:Connect(function() if isOpen then dropdownObj:Close() else open() end end)
    row.MouseEnter:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.2 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.4 }) end)
    if state.Value ~= nil then pcall(callback, state.Value) end
    dropdownObj.Set = function(_, v) state.Value = v; valueLabel.Text = tostring(v or "--") end
    dropdownObj.Get = function() return state.Value end
    dropdownObj.SetOptions = function(_, newOptions)
        options = newOptions
        if isOpen then dropdownObj:Close() end
        if state.Value and not table.find(options, state.Value) then
            state.Value = nil; valueLabel.Text = "--"; pcall(callback, nil)
        end
    end
    return dropdownObj
end

function Window:_createSlider(parent, config)
    local state = { Value = config.Default or config.Min or 0 }
    local callback = config.Callback or function() end
    local hasDesc = config.Description and config.Description ~= ""
    local minV, maxV, rounding = config.Min or 0, config.Max or 100, config.Rounding or 0
    local row = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, hasDesc and 62 or 48),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.4, BorderSizePixel = 0,
    }, { corner(6) })
    new("TextLabel", {
        Parent = row, Size = UDim2.new(1, -120, 0, hasDesc and 20 or 24),
        Position = UDim2.fromOffset(12, hasDesc and 6 or 4),
        BackgroundTransparency = 1, Text = config.Title or "Slider",
        TextColor3 = Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local valueLabel = new("TextLabel", {
        Parent = row, Size = UDim2.fromOffset(90, 20),
        Position = UDim2.new(1, -100, 0, hasDesc and 6 or 4),
        BackgroundTransparency = 1, Text = tostring(state.Value),
        TextColor3 = Theme.Accent, Font = Enum.Font.GothamBold, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    if hasDesc then
        new("TextLabel", {
            Parent = row, Size = UDim2.new(1, -24, 0, 14), Position = UDim2.fromOffset(12, 26),
            BackgroundTransparency = 1, Text = config.Description,
            TextColor3 = Theme.SubText, Font = Enum.Font.Gotham, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end
    local trackY = hasDesc and 44 or 34
    local trackBg = new("Frame", {
        Parent = row, Size = UDim2.new(1, -24, 0, 4), Position = UDim2.fromOffset(12, trackY),
        BackgroundColor3 = Theme.ToggleOff, BorderSizePixel = 0,
    }, { corner(2) })
    local fill = new("Frame", {
        Parent = trackBg, Size = UDim2.new((state.Value - minV) / (maxV - minV), 0, 1, 0),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
    }, { corner(2) })
    local knob = new("Frame", {
        Parent = trackBg, Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new((state.Value - minV) / (maxV - minV), -6, 0.5, -6),
        BackgroundColor3 = Theme.Text, BorderSizePixel = 0,
    }, { corner(6) })
    local dragging = false
    local function setValue(v, skipCb)
        v = math.clamp(v, minV, maxV)
        if rounding > 0 then
            local mult = 10 ^ rounding
            v = math.floor(v * mult + 0.5) / mult
        end
        state.Value = v
        local ratio = (v - minV) / (maxV - minV)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, -6, 0.5, -6)
        valueLabel.Text = tostring(v)
        if not skipCb then pcall(callback, v) end
    end
    local hitbox = new("TextButton", {
        Parent = row, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, trackY - 8),
        BackgroundTransparency = 1, Text = "",
    })
    hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local relX = input.Position.X - trackBg.AbsolutePosition.X
            local ratio = math.clamp(relX / math.max(trackBg.AbsoluteSize.X, 1), 0, 1)
            setValue(minV + ratio * (maxV - minV))
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    pcall(callback, state.Value)
    return { Set = function(_, v) setValue(v, true) end, Get = function() return state.Value end }
end

function Window:_createButton(parent, config)
    local callback = config.Callback or function() end
    local hasDesc = config.Description and config.Description ~= ""
    local row = new("TextButton", {
        Parent = parent, Size = UDim2.new(1, 0, 0, hasDesc and 52 or 40),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.4, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false,
    }, {
        corner(6),
        new("UIStroke", { Color = Theme.Accent, Transparency = 0.6 }),
        new("TextLabel", {
            Size = UDim2.new(1, -24, 0, hasDesc and 20 or 40),
            Position = UDim2.fromOffset(12, hasDesc and 8 or 0),
            BackgroundTransparency = 1, Text = config.Title or "Button",
            TextColor3 = Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }),
    })
    if hasDesc then
        new("TextLabel", {
            Parent = row, Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 26),
            BackgroundTransparency = 1, Text = config.Description,
            TextColor3 = Theme.SubText, Font = Enum.Font.Gotham, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end
    row.MouseEnter:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.2 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.4 }) end)
    row.MouseButton1Click:Connect(function() pcall(callback) end)
    return row
end

function Window:_createKeybind(parent, config)
    local currentKey = config.Default or "Q"
    local callback = config.Callback or function() end
    local hasDesc = config.Description and config.Description ~= ""
    local listening = false
    local listenConn

    local row = new("Frame", {
        Parent = parent, Size = UDim2.new(1, 0, 0, hasDesc and 52 or 40),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.4, BorderSizePixel = 0,
    }, { corner(6) })
    new("TextLabel", {
        Parent = row, Size = UDim2.new(0.5, -20, 1, 0), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = config.Title or "Keybind",
        TextColor3 = Theme.Text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    })
    if hasDesc then
        new("TextLabel", {
            Parent = row, Size = UDim2.new(0.5, -20, 0, 16), Position = UDim2.fromOffset(12, 30),
            BackgroundTransparency = 1, Text = config.Description,
            TextColor3 = Theme.SubText, Font = Enum.Font.Gotham, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end

    local btn = new("TextButton", {
        Parent = row, Size = UDim2.fromOffset(140, 28),
        Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.Background, Text = "", AutoButtonColor = false,
    }, {
        corner(5),
        new("UIStroke", { Color = Theme.Border, Transparency = 0.5 }),
        new("TextLabel", {
            Name = "KeyLabel", Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1, Text = currentKey,
            TextColor3 = Theme.Text, Font = Enum.Font.GothamBold, TextSize = 12,
        }),
    })
    local keyLabel = btn:FindFirstChild("KeyLabel")

    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keyLabel.Text = "Press a key..."
        keyLabel.TextColor3 = Theme.Accent
        if listenConn then listenConn:Disconnect() end
        listenConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                currentKey = input.KeyCode.Name
                keyLabel.Text = currentKey
                keyLabel.TextColor3 = Theme.Text
                listening = false
                listenConn:Disconnect()
                listenConn = nil
                pcall(callback, currentKey)
            end
        end)
    end)

    row.MouseEnter:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.2 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.1, { BackgroundTransparency = 0.4 }) end)

    pcall(callback, currentKey)
    return {
        Get = function() return currentKey end,
        Set = function(_, k)
            currentKey = k
            keyLabel.Text = k
            pcall(callback, k)
        end,
    }
end

-- ============================================================
-- WINDOW + TABS
-- ============================================================
local win = Window.new({ Title = "Barcode's Universal Menu", Width = 580, Height = 460, SidebarWidth = 160 })
local mainTab     = win:CreateTab("Main")
local espTab      = win:CreateTab("ESP Settings")
local movementTab = win:CreateTab("Movement")

-- ============================================================
-- STATE
-- ============================================================
local AimLock = {
    Enabled = false, FOV = 250, Smoothness = 0.4,
    TargetPart = "Head", Method = "Camera",
    HitChance = 100, WallCheck = false, DrawFOV = false,
    TriggerMode = "Toggle", ActivationMode = "Toggle", Key = "Q",
    Target = nil,
}
-- Mouse method hangs Delta's mobile render thread. Force Camera if somehow set.
if isMobile and AimLock.Method == "Mouse" then
    AimLock.Method = "Camera"
end

local Movement = {
    Fly = false, MobileFly = false, FlySpeed = 50,
    SpinBot = false, SpinSpeed = 1,
}

local aimToggleRef, mobileAimBtn, mobileAimGui
local MobileAimButton = true

local function setAimEnabled(v)
    AimLock.Enabled = v
    if aimToggleRef then aimToggleRef:Set(v) end
    if mobileAimBtn then
        if v then
            tween(mobileAimBtn, 0.1, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.1 })
        else
            tween(mobileAimBtn, 0.1, { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3 })
        end
    end
end

local function setMobileAimVisible(v)
    MobileAimButton = v
    if mobileAimBtn then mobileAimBtn.Visible = v end
end

-- ============================================================
-- MAIN TAB
-- ============================================================
aimToggleRef = mainTab:Toggle({
    Title = "Aim Lock",
    Description = isMobile and "Or use the AIM button on screen" or "Lock onto nearest player in FOV",
    Default = false,
    Callback = function(v) setAimEnabled(v) end,
})

mainTab:Toggle({
    Title = "Show Mobile Aim Button",
    Description = isMobile and "Show the AIM button overlay" or "Only visible on mobile",
    Default = true,
    Callback = function(v) setMobileAimVisible(v) end,
})

mainTab:Toggle({
    Title = "Draw FOV",
    Description = "Show the aim FOV circle",
    Default = false,
    Callback = function(v) AimLock.DrawFOV = v end,
})

mainTab:Toggle({
    Title = "Wall Check",
    Description = "Only lock onto players with clear line of sight",
    Default = false,
    Callback = function(v) AimLock.WallCheck = v end,
})

-- Mobile users don't get Mouse — mousemoverel isn't safe on mobile.
local aimMethodOptions = isMobile
    and { "Silent Aim", "Camera" }
    or  { "Silent Aim", "Camera", "Mouse" }

mainTab:Dropdown({
    Title = "Aim Method",
    Description = isMobile and "Mouse method is PC only" or "How aim lock acquires targets",
    Options = aimMethodOptions,
    Default = "Camera",
    Callback = function(v) if v then AimLock.Method = v end end,
})

mainTab:Dropdown({
    Title = "Trigger Mode",
    Description = "'Toggle' = only UI toggle, 'Keybind' = also use key/button",
    Options = { "Toggle", "Keybind" },
    Default = "Toggle",
    Callback = function(v) if v then AimLock.TriggerMode = v end end,
})

mainTab:Dropdown({
    Title = "Activation Mode",
    Description = "'Toggle' = press to flip, 'Hold' = hold to aim",
    Options = { "Toggle", "Hold" },
    Default = "Toggle",
    Callback = function(v) if v then AimLock.ActivationMode = v end end,
})

mainTab:Keybind({
    Title = "Aim Key",
    Description = "Key to activate aim lock (Keybind mode)",
    Default = "Q",
    Callback = function(k) if k then AimLock.Key = k end end,
})

mainTab:Slider({ Title = "Aim FOV", Description = "Radius in pixels from screen center",
    Min = 50, Max = 800, Default = 250, Rounding = 0,
    Callback = function(v) AimLock.FOV = v end })
mainTab:Slider({ Title = "Smoothness", Description = "Higher = faster snap",
    Min = 0.05, Max = 1, Default = 0.4, Rounding = 2,
    Callback = function(v) AimLock.Smoothness = v end })
mainTab:Slider({ Title = "Hit Chance", Description = "Silent aim hit probability",
    Min = 0, Max = 100, Default = 100, Rounding = 0,
    Callback = function(v) AimLock.HitChance = v end })
mainTab:Dropdown({ Title = "Aim Target", Description = "Which body part to aim at",
    Options = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }, Default = "Head",
    Callback = function(v) if v then AimLock.TargetPart = v end end })

-- ============================================================
-- KEYBIND MONITOR
-- ============================================================
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if AimLock.TriggerMode ~= "Keybind" then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode.Name ~= AimLock.Key then return end
    if AimLock.ActivationMode == "Toggle" then
        setAimEnabled(not AimLock.Enabled)
    else
        setAimEnabled(true)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if AimLock.TriggerMode ~= "Keybind" then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if AimLock.ActivationMode == "Hold" and input.KeyCode.Name == AimLock.Key then
        setAimEnabled(false)
    end
end)

-- ============================================================
-- MOBILE AIM BUTTON (created only on mobile, hidden/shown via toggle)
-- ============================================================
local function createMobileAimButton()
    if not isMobile or mobileAimGui then return end
    mobileAimGui = new("ScreenGui", {
        Parent = PlayerGui, Name = "BarcodeAimMobile",
        IgnoreGuiInset = true, ResetOnSpawn = false,
        DisplayOrder = 200, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    mobileAimBtn = new("TextButton", {
        Parent = mobileAimGui, Size = UDim2.fromOffset(80, 80),
        Position = UDim2.new(1, -100, 0.5, 40),
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3,
        Text = "AIM", TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold, TextSize = 18, AutoButtonColor = false,
        Visible = MobileAimButton,
    }, {
        new("UICorner", { CornerRadius = UDim.new(1, 0) }),
        new("UIStroke", { Color = Theme.Accent, Thickness = 2, Transparency = 0.3 }),
    })
    mobileAimBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if AimLock.ActivationMode == "Toggle" then
                setAimEnabled(not AimLock.Enabled)
            else
                setAimEnabled(true)
            end
        end
    end)
    mobileAimBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if AimLock.ActivationMode == "Hold" then
                setAimEnabled(false)
            end
        end
    end)
end
createMobileAimButton()

-- ============================================================
-- SILENT AIM HOOK
-- ============================================================
local hitCache = { time = 0, hit = true }
pcall(function()
    if not getrawmetatable or not setreadonly then return end
    local mouse = LocalPlayer:GetMouse()
    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    setreadonly(mt, false)
    local function hook(self, key)
        if self == mouse and AimLock.Enabled and AimLock.Method == "Silent Aim" and AimLock.Target then
            if key == "Hit" or key == "Target" then
                if AimLock.HitChance < 100 then
                    if tick() - hitCache.time > 0.05 then
                        hitCache.hit = math.random(1, 100) <= AimLock.HitChance
                        hitCache.time = tick()
                    end
                    if not hitCache.hit then return oldIndex(self, key) end
                end
                if key == "Hit" then return CFrame.new(AimLock.Target.Position) end
                return AimLock.Target
            end
        end
        return oldIndex(self, key)
    end
    if newcclosure then hook = newcclosure(hook) end
    mt.__index = hook
    setreadonly(mt, true)
end)

-- ============================================================
-- ESP CONFIG
-- ============================================================
local Config = {
    Boxes = false, Tracers = false, Chams = false, RainbowChams = false,
    Skeletons = false, HealthBar = false,
    DefaultColor = Color3.fromRGB(255, 255, 255), TracerOrigin = "Bottom",
}
_G.ESP_Config = Config

espTab:Toggle({ Title = "Boxes", Description = "2D boxes around players", Default = false,
    Callback = function(v) Config.Boxes = v end })
espTab:Toggle({ Title = "Health Bar", Description = "Color-coded health bar left of boxes", Default = false,
    Callback = function(v) Config.HealthBar = v end })
espTab:Toggle({ Title = "Tracers", Description = "Lines from screen edge to players", Default = false,
    Callback = function(v) Config.Tracers = v end })
espTab:Toggle({ Title = "Chams", Description = "Highlight through walls", Default = false,
    Callback = function(v) Config.Chams = v end })
espTab:Toggle({ Title = "Rainbow Chams", Description = "HSV cycling chams", Default = false,
    Callback = function(v) Config.RainbowChams = v end })
espTab:Toggle({ Title = "Skeletons", Description = "Connecting joint lines", Default = false,
    Callback = function(v) Config.Skeletons = v end })
espTab:Dropdown({ Title = "Tracer Origin", Options = { "Top", "Middle", "Bottom" }, Default = "Bottom",
    Callback = function(v) if v == "Top" or v == "Middle" or v == "Bottom" then Config.TracerOrigin = v end end })

-- ============================================================
-- MOBILE FLY CONTROLS
-- ============================================================
local mobileFlyGui, mobileInput

local function makeMobileButton(parent, symbol, pos, key)
    local btn = new("TextButton", {
        Parent = parent, Size = UDim2.fromOffset(60, 60), Position = pos,
        BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3,
        BorderSizePixel = 0, Text = symbol, TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold, TextSize = 24, AutoButtonColor = false,
    }, {
        corner(30),
        new("UIStroke", { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.3 }),
    })
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if mobileInput then mobileInput[key] = true end
            tween(btn, 0.05, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.1 })
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if mobileInput then mobileInput[key] = false end
            tween(btn, 0.1, { BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.3 })
        end
    end)
    return btn
end

local function createMobileFlyControls()
    if not isMobile or mobileFlyGui then return end
    mobileInput = { forward = false, back = false, left = false, right = false, up = false, down = false }
    mobileFlyGui = new("ScreenGui", {
        Name = "BarcodeFlyControls", Parent = PlayerGui,
        IgnoreGuiInset = true, ResetOnSpawn = false,
        DisplayOrder = 200, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    local dpad = new("Frame", {
        Parent = mobileFlyGui, Size = UDim2.fromOffset(132, 132),
        Position = UDim2.new(0, 20, 1, -152), BackgroundTransparency = 1,
    })
    makeMobileButton(dpad, "↑", UDim2.fromOffset(36, 0),   "forward")
    makeMobileButton(dpad, "↓", UDim2.fromOffset(36, 72),  "back")
    makeMobileButton(dpad, "←", UDim2.fromOffset(0, 36),   "left")
    makeMobileButton(dpad, "→", UDim2.fromOffset(72, 36),  "right")
    local vpad = new("Frame", {
        Parent = mobileFlyGui, Size = UDim2.fromOffset(60, 132),
        Position = UDim2.new(1, -80, 1, -152), BackgroundTransparency = 1,
    })
    makeMobileButton(vpad, "▲", UDim2.fromOffset(0, 0),  "up")
    makeMobileButton(vpad, "▼", UDim2.fromOffset(0, 72), "down")
end

local function destroyMobileFlyControls()
    if mobileFlyGui then mobileFlyGui:Destroy(); mobileFlyGui = nil end
    mobileInput = nil
end

-- ============================================================
-- MOVEMENT TAB
-- ============================================================
movementTab:Toggle({ Title = "Fly", Description = "Fly with keyboard (WASD + Space/Shift)", Default = false,
    Callback = function(v) Movement.Fly = v end })
movementTab:Toggle({ Title = "Mobile Fly", Description = "Fly with on-screen D-pad buttons", Default = false,
    Callback = function(v)
        Movement.MobileFly = v
        if v and isMobile then createMobileFlyControls()
        elseif not v then destroyMobileFlyControls() end
    end })
movementTab:Slider({ Title = "Fly Speed", Description = "Studs per second",
    Min = 10, Max = 500, Default = 50, Rounding = 0,
    Callback = function(v) Movement.FlySpeed = v end })
movementTab:Toggle({ Title = "Spin Bot", Description = "Character spins, camera stays fixed", Default = false,
    Callback = function(v) Movement.SpinBot = v end })
movementTab:Slider({ Title = "Spin Speed", Description = "Rotations per second",
    Min = 0.1, Max = 20, Default = 1, Rounding = 1,
    Callback = function(v) Movement.SpinSpeed = v end })

local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return names
end
local tpTargetDropdown = movementTab:Dropdown({
    Title = "Target Player", Description = "Auto-refreshes as players join/leave",
    Options = getPlayerNames(), Default = nil,
})
movementTab:Button_({
    Title = "Teleport to Player", Description = "Client-side only — server may snap you back",
    Callback = function()
        local name = tpTargetDropdown:Get()
        if not name then return end
        local target = Players:FindFirstChild(name)
        if not target or not target.Character then return end
        local char = LocalPlayer.Character
        if not char then return end
        local targetHrp = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetHrp then return end
        local myHrp = char:FindFirstChild("HumanoidRootPart")
        if myHrp then
            myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3)
        else
            char:PivotTo(targetHrp.CFrame * CFrame.new(0, 0, 3))
        end
    end,
})
local function refreshPlayerDropdown() tpTargetDropdown:SetOptions(getPlayerNames()) end
Players.PlayerAdded:Connect(refreshPlayerDropdown)
Players.PlayerRemoving:Connect(refreshPlayerDropdown)

-- ============================================================
-- FLY LOOP
-- ============================================================
local flyBV
local flySaved = { walk = 16, jump = 50, saved = false }

local function startFly()
    if flySaved.saved then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        flySaved.walk = hum.WalkSpeed
        flySaved.jump = hum.JumpPower
        hum.WalkSpeed, hum.JumpPower = 0, 0
        flySaved.saved = true
    end
end

local function stopFly()
    if not flySaved.saved then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed, hum.JumpPower = flySaved.walk, flySaved.jump end
    flySaved.saved = false
end

RunService.RenderStepped:Connect(function()
    local flyActive = Movement.Fly or Movement.MobileFly
    if not flyActive then
        if flyBV then flyBV:Destroy(); flyBV = nil end
        stopFly()
        return
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not flyBV or flyBV.Parent ~= hrp then
        if flyBV then flyBV:Destroy() end
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        flyBV.Parent = hrp
        startFly()
    end

    local cam = workspace.CurrentCamera
    local dir = Vector3.zero

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end

    if mobileInput then
        if mobileInput.forward then dir += cam.CFrame.LookVector end
        if mobileInput.back then dir -= cam.CFrame.LookVector end
        if mobileInput.left then dir -= cam.CFrame.RightVector end
        if mobileInput.right then dir += cam.CFrame.RightVector end
        if mobileInput.up then dir += Vector3.yAxis end
        if mobileInput.down then dir -= Vector3.yAxis end
    end

    if dir.Magnitude > 0 then dir = dir.Unit * Movement.FlySpeed end
    flyBV.Velocity = dir
end)

-- ============================================================
-- SPIN BOT
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    if not Movement.SpinBot then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, Movement.SpinSpeed * math.rad(360) * dt, 0)
end)

-- ============================================================
-- WALL CHECK + TARGET FINDER
-- ============================================================
local function isVisible(targetPart)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local delta = targetPart.Position - origin
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { LocalPlayer.Character }
    local result = workspace:Raycast(origin, delta, rp)
    if not result then return true end
    return result.Instance:IsDescendantOf(targetPart.Parent)
end

local function findTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local closest, closestDist = nil, AimLock.FOV
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild(AimLock.TargetPart)
        if not part then continue end
        if AimLock.WallCheck and not isVisible(part) then continue end
        local sp, onScreen = cam:WorldToViewportPoint(part.Position)
        if onScreen then
            local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
            if dist < closestDist then closestDist = dist; closest = part end
        end
    end
    return closest
end

-- ============================================================
-- AIM LOCK LOOP + FOV CIRCLE
-- ============================================================
local lastMouseMove = 0

RunService:BindToRenderStep("BarcodeAimLock", Enum.RenderPriority.Camera.Value + 1, function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize

    if AimLock.DrawFOV then
        local d = AimLock.FOV * 2
        fovFrame.Size = UDim2.fromOffset(d, d)
        fovFrame.Position = UDim2.fromOffset(vp.X / 2 - AimLock.FOV, vp.Y / 2 - AimLock.FOV)
        fovFrame.Visible = true
    else
        fovFrame.Visible = false
    end

    if not AimLock.Enabled then AimLock.Target = nil; return end
    AimLock.Target = findTarget()
    if not AimLock.Target then return end

    if AimLock.Method == "Camera" then
        local desired = CFrame.new(cam.CFrame.Position, AimLock.Target.Position)
        cam.CFrame = cam.CFrame:Lerp(desired, math.clamp(AimLock.Smoothness, 0.01, 1))
    elseif AimLock.Method == "Mouse" and not isMobile then
        -- mousemoverel on Delta mobile hangs the render thread.
        -- Guarded by isMobile, and throttled to ~60Hz on PC.
        local now = tick()
        if now - lastMouseMove >= 0.016 then
            lastMouseMove = now
            local sp = cam:WorldToViewportPoint(AimLock.Target.Position)
            local delta = Vector2.new(sp.X - vp.X / 2, sp.Y - vp.Y / 2)
            if mousemoverel then
                pcall(mousemoverel, delta.X * AimLock.Smoothness, delta.Y * AimLock.Smoothness)
            end
        end
    end
end)

-- ============================================================
-- ESP RENDERING
-- ============================================================
local espGui = new("ScreenGui", {
    Name = "BarcodesUniversalESP", Parent = PlayerGui,
    IgnoreGuiInset = true, ResetOnSpawn = false,
    DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function newLine(z)
    return new("Frame", {
        Parent = espGui, BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
        Visible = false, ZIndex = z,
    })
end
local function updateLine(frame, from, to, thickness, color)
    local delta = to - from
    local len = delta.Magnitude
    if len < 1 then frame.Visible = false; return end
    local mid = (from + to) * 0.5
    frame.Position = UDim2.fromOffset(mid.X, mid.Y)
    frame.Size = UDim2.fromOffset(len, thickness)
    frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    frame.BackgroundColor3 = color
    frame.Visible = true
end
local function newBox()
    local f = new("Frame", {
        Parent = espGui, BackgroundTransparency = 1,
        BorderSizePixel = 0, Visible = false, ZIndex = 1,
    })
    local stroke = new("UIStroke", { Parent = f, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    return f, stroke
end

local ESPState, watched = {}, {}
local function clearState(player)
    local s = ESPState[player]
    if not s then return end
    if s.Box then s.Box:Destroy() end
    if s.HealthBar then s.HealthBar:Destroy() end
    if s.Tracer then s.Tracer:Destroy() end
    for _, f in ipairs(s.Skeleton) do f:Destroy() end
    if s.Highlight and s.Highlight.Parent then s.Highlight:Destroy() end
    ESPState[player] = nil
end
local function ensureState(player)
    local s = ESPState[player]
    if s then return s end
    local box, stroke = newBox()
    local healthBar = new("Frame", {
        Parent = espGui, BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false, ZIndex = 1,
    }, { new("UICorner", { CornerRadius = UDim.new(0, 1) }) })
    local healthFill = new("Frame", {
        Parent = healthBar, BackgroundColor3 = Color3.fromRGB(51, 199, 89),
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
    }, { new("UICorner", { CornerRadius = UDim.new(0, 1) }) })
    s = {
        Box = box, BoxStroke = stroke,
        HealthBar = healthBar, HealthFill = healthFill,
        Tracer = newLine(3), Skeleton = {},
        Highlight = nil, Joints = {}, Character = nil,
    }
    ESPState[player] = s
    return s
end

local R15_JOINTS = {
    "Head","UpperTorso","LowerTorso",
    "LeftUpperArm","LeftLowerArm","LeftHand",
    "RightUpperArm","RightLowerArm","RightHand",
    "LeftUpperLeg","LeftLowerLeg","LeftFoot",
    "RightUpperLeg","RightLowerLeg","RightFoot",
}
local R6_JOINTS = { "Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg" }
local R15_PAIRS = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"UpperTorso","RightUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LowerTorso","RightUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_PAIRS = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

local function cacheJoints(char, s)
    s.Joints = {}
    local isR15 = char:FindFirstChild("UpperTorso") ~= nil
    for _, name in ipairs(isR15 and R15_JOINTS or R6_JOINTS) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("BasePart") then s.Joints[name] = part end
    end
end
local function jointsReady(s, char)
    local isR15 = char:FindFirstChild("UpperTorso") ~= nil
    for _, name in ipairs(isR15 and R15_JOINTS or R6_JOINTS) do
        local p = s.Joints[name]
        if not p or not p.Parent then return false end
    end
    return true
end
local function ensureSkeletonFrames(s, count)
    while #s.Skeleton < count do table.insert(s.Skeleton, newLine(2)) end
    for i = count + 1, #s.Skeleton do s.Skeleton[i].Visible = false end
end
local function updateHighlight(s, char)
    if not Config.Chams then
        if s.Highlight then s.Highlight.Enabled = false end
        return
    end
    if not s.Highlight or not s.Highlight.Parent then
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_Chams"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.Parent = char
        s.Highlight = hl
    end
    local hl = s.Highlight
    hl.Enabled = true
    if Config.RainbowChams then
        local c = Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
        hl.FillColor, hl.OutlineColor = c, c
    else
        hl.FillColor = Config.DefaultColor
        hl.OutlineColor = Config.DefaultColor
    end
end
local function computeTracerOrigin(vp)
    local y
    if Config.TracerOrigin == "Top" then y = 0
    elseif Config.TracerOrigin == "Middle" then y = vp.Y * 0.5
    else y = vp.Y end
    return Vector2.new(vp.X * 0.5, y)
end
local function healthColor(ratio)
    if ratio > 0.75 then return Color3.fromRGB(51, 199, 89)
    elseif ratio > 0.5 then return Color3.fromRGB(255, 220, 0)
    elseif ratio > 0.25 then return Color3.fromRGB(255, 140, 0)
    else return Color3.fromRGB(220, 50, 50) end
end

local function updateESP()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local origin = computeTracerOrigin(vp)
    local color = Config.DefaultColor
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local s = ESPState[player]
        if not char or not hum or hum.Health <= 0 or not root then
            if s then
                if s.Box then s.Box.Visible = false end
                if s.HealthBar then s.HealthBar.Visible = false end
                if s.Tracer then s.Tracer.Visible = false end
                for _, f in ipairs(s.Skeleton) do f.Visible = false end
                if s.Highlight then s.Highlight.Enabled = false end
            end
            continue
        end
        s = ensureState(player)
        if s.Character ~= char or not jointsReady(s, char) then
            s.Character = char
            cacheJoints(char, s)
        end
        local head = s.Joints["Head"]
        if head and head.Parent then
            local hs = cam:WorldToViewportPoint(head.Position)
            local rs = cam:WorldToViewportPoint(root.Position)
            if hs.Z > 0 and rs.Z > 0 then
                local torsoH = math.abs(rs.Y - hs.Y)
                local h = torsoH * 3.2
                local w = h * 0.5
                local boxX, boxY = hs.X - w * 0.5, hs.Y - torsoH * 0.4
                if Config.Boxes and s.Box and s.BoxStroke then
                    s.Box.Position = UDim2.fromOffset(boxX, boxY)
                    s.Box.Size = UDim2.fromOffset(w, h)
                    s.BoxStroke.Color = color
                    s.Box.Visible = true
                elseif s.Box then s.Box.Visible = false end
                if Config.HealthBar and s.HealthBar and s.HealthFill then
                    local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    s.HealthBar.Position = UDim2.fromOffset(boxX - 6, boxY)
                    s.HealthBar.Size = UDim2.fromOffset(3, h)
                    s.HealthFill.Size = UDim2.new(1, 0, ratio, 0)
                    s.HealthFill.Position = UDim2.new(0, 0, 1 - ratio, 0)
                    s.HealthFill.BackgroundColor3 = healthColor(ratio)
                    s.HealthBar.Visible = true
                elseif s.HealthBar then s.HealthBar.Visible = false end
            else
                if s.Box then s.Box.Visible = false end
                if s.HealthBar then s.HealthBar.Visible = false end
            end
        else
            if s.Box then s.Box.Visible = false end
            if s.HealthBar then s.HealthBar.Visible = false end
        end
        if Config.Tracers and s.Tracer then
            local sc = cam:WorldToViewportPoint(root.Position)
            updateLine(s.Tracer, origin, Vector2.new(sc.X, sc.Y), 1, color)
        elseif s.Tracer then s.Tracer.Visible = false end
        if Config.Skeletons then
            local isR15 = char:FindFirstChild("UpperTorso") ~= nil
            local pairs = isR15 and R15_PAIRS or R6_PAIRS
            ensureSkeletonFrames(s, #pairs)
            for i, pair in ipairs(pairs) do
                local a = s.Joints[pair[1]]
                local b = s.Joints[pair[2]]
                local frame = s.Skeleton[i]
                if a and a.Parent and b and b.Parent then
                    local sa = cam:WorldToViewportPoint(a.Position)
                    local sb = cam:WorldToViewportPoint(b.Position)
                    updateLine(frame, Vector2.new(sa.X, sa.Y), Vector2.new(sb.X, sb.Y), 1, color)
                else frame.Visible = false end
            end
        else
            for _, f in ipairs(s.Skeleton) do f.Visible = false end
        end
        updateHighlight(s, char)
    end
end

local lastErr = 0
RunService.RenderStepped:Connect(function()
    local ok, err = pcall(updateESP)
    if not ok and tick() - lastErr > 2 then
        lastErr = tick()
        warn("[Barcode ESP]", err)
    end
end)

local function watchPlayer(player)
    if player == LocalPlayer or watched[player] then return end
    watched[player] = true
    ensureState(player)
    player.CharacterAdded:Connect(function()
        local s = ESPState[player]
        if not s then return end
        s.Character = nil
        for _, f in ipairs(s.Skeleton) do f.Visible = false end
    end)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
Players.PlayerRemoving:Connect(function(p) watched[p] = nil; clearState(p) end)
LocalPlayer.OnTeleport:Connect(function()
    for p in pairs(ESPState) do clearState(p) end
    espGui:Destroy()
    fovGui:Destroy()
    if mobileAimGui then mobileAimGui:Destroy() end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    stopFly()
    destroyMobileFlyControls()
end)

LocalPlayer.CharacterAdded:Connect(function()
    if Movement.MobileFly and isMobile and not mobileFlyGui then
        task.wait(0.5)
        if Movement.MobileFly then createMobileFlyControls() end
    end
end)
