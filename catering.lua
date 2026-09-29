local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

------------------------------------------------
-- CLEANUP (re-execute safe)
------------------------------------------------
if getgenv().AntiAFKConn then getgenv().AntiAFKConn:Disconnect(); getgenv().AntiAFKConn = nil end
getgenv().AntiAFKLoop = false
getgenv().CateringFarm = false
task.wait()

local oldGui = pg:FindFirstChild("CateringMonitor")
if oldGui then oldGui:Destroy() end

-- Session counters (reset tiap execute)
local sessionAccepted = 0
local sessionClaimed = 0
local selectedCategory = 3
local antiAfkEnabled = false
local cateringEnabled = false

------------------------------------------------
-- FUNGSI: Baca milestone catering dari akun
------------------------------------------------
local function getCateringMilestone()
    local ok, milestones = pcall(function()
        return pg.Menu.Menu.Content.List.Milestones.Content
    end)
    if not ok or not milestones then return nil, nil, nil end

    for _, entry in ipairs(milestones:GetChildren()) do
        if entry:IsA("GuiObject") and entry.Name:lower():find("catering") then
            local cur = entry:FindFirstChild("currentAmount")
            local tier = entry:FindFirstChild("Tier")
            if cur and cur:IsA("TextLabel") then
                local now, max = cur.Text:match("(%d[%d,K]*)%s*/%s*(%d[%d,K]*)")
                local tierText = tier and tier:IsA("TextLabel") and tier.Text or "?"
                return cur.Text, tierText, entry
            end
        end
    end
    return nil, nil, nil
end

------------------------------------------------
-- GUI
------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CateringMonitor"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = pg

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 250, 0, 310)
frame.Position = UDim2.new(0, 10, 0.5, -155)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
frame.BackgroundTransparency = 0.08
frame.BorderSizePixel = 0
frame.Parent = screenGui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local stk = Instance.new("UIStroke", frame)
stk.Color = Color3.fromRGB(80, 140, 255)
stk.Thickness = 1.5
stk.Transparency = 0.2

local pad = Instance.new("UIPadding", frame)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingTop = UDim.new(0, 10)

local layout = Instance.new("UIListLayout", frame)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 5)

------------------------------------------------
-- UI HELPERS
------------------------------------------------
local function makeLabel(text, order, size, color, font)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, size or 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    lbl.TextSize = (size or 18) - 4
    lbl.Font = font or Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order
    lbl.Parent = frame
    return lbl
end

local function makeDivider(order)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    d.BorderSizePixel = 0
    d.LayoutOrder = order
    d.Parent = frame
    return d
end

local function makeToggle(labelText, order, defaultOn, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(190, 190, 190)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 56, 0, 22)
    btn.Position = UDim2.new(1, -56, 0.5, -11)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local isOn = defaultOn

    local function refresh()
        if isOn then
            btn.Text = "ON"
            btn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.Text = "OFF"
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            btn.TextColor3 = Color3.fromRGB(140, 140, 140)
        end
    end
    refresh()

    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        refresh()
        callback(isOn)
    end)

    return function() return isOn end
end

local function makeDropdown(labelText, order, options, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(190, 190, 190)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btnFrame = Instance.new("Frame")
    btnFrame.Size = UDim2.new(0.5, 0, 1, 0)
    btnFrame.Position = UDim2.new(0.5, 0, 0, 0)
    btnFrame.BackgroundTransparency = 1
    btnFrame.Parent = row

    local btnLayout = Instance.new("UIListLayout", btnFrame)
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
    btnLayout.Padding = UDim.new(0, 4)

    local buttons = {}

    local function refreshAll()
        for i, b in ipairs(buttons) do
            if options[i].value == selectedCategory then
                b.BackgroundColor3 = Color3.fromRGB(60, 130, 255)
                b.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
                b.TextColor3 = Color3.fromRGB(130, 130, 130)
            end
        end
    end

    for i, opt in ipairs(options) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 36, 0, 22)
        b.Text = opt.label
        b.TextSize = 11
        b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        b.LayoutOrder = i
        b.Parent = btnFrame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        buttons[i] = b

        b.MouseButton1Click:Connect(function()
            selectedCategory = opt.value
            refreshAll()
            callback(opt.value)
        end)
    end

    refreshAll()
end

local function makeStatRow(labelText, order, valueColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 18)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local val = Instance.new("TextLabel")
    val.Name = "Value"
    val.Size = UDim2.new(0.4, 0, 1, 0)
    val.Position = UDim2.new(0.6, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "0"
    val.TextColor3 = valueColor or Color3.fromRGB(255, 255, 255)
    val.TextSize = 11
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = row

    return val
end

------------------------------------------------
-- BUILD GUI
------------------------------------------------
makeLabel("🍽️ Catering Monitor", 1, 20, Color3.fromRGB(80, 170, 255), Enum.Font.GothamBold)
makeDivider(2)

-- Toggles
makeToggle("Anti AFK", 3, false, function(on) antiAfkEnabled = on end)
makeToggle("Auto Catering", 4, false, function(on) cateringEnabled = on end)

makeDivider(5)

-- Kategori
makeDropdown("Kategori", 6, {
    { label = "1", value = 1 },
    { label = "2", value = 2 },
    { label = "3", value = 3 },
}, 3, function(val) selectedCategory = val end)

makeDivider(7)

-- Statistik sesi
makeLabel("📊 Sesi", 8, 16, Color3.fromRGB(180, 180, 200), Enum.Font.GothamBold)
local valSessAcc = makeStatRow("Accepted", 9, Color3.fromRGB(255, 255, 255))
local valSessClm = makeStatRow("Claimed", 10, Color3.fromRGB(255, 255, 255))

makeDivider(11)

-- Statistik total dari akun
makeLabel("🏆 Total", 12, 16, Color3.fromRGB(255, 200, 80), Enum.Font.GothamBold)
local valMilestoneTier = makeStatRow("Milestone", 13, Color3.fromRGB(255, 170, 50))
local valMilestoneProgress = makeStatRow("Progress", 14, Color3.fromRGB(120, 255, 120))

-- Update GUI
local function updateGui()
    valSessAcc.Text = tostring(sessionAccepted)
    valSessClm.Text = tostring(sessionClaimed)

    local progress, tierName = getCateringMilestone()
    if progress then
        valMilestoneProgress.Text = progress
        valMilestoneTier.Text = tierName or "?"
    else
        valMilestoneProgress.Text = "..."
        valMilestoneTier.Text = "Loading"
    end
end
updateGui()

-- Auto-refresh milestone setiap 5 detik
task.spawn(function()
    while screenGui.Parent do
        task.wait(5)
        pcall(updateGui)
    end
end)

------------------------------------------------
-- DRAGGABLE
------------------------------------------------
local dragging, dragInput, dragStart, startPos

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or
       input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

------------------------------------------------
-- ANTI AFK LOOP
------------------------------------------------
getgenv().AntiAFKLoop = true
task.spawn(function()
    while getgenv().AntiAFKLoop do
        task.wait(1)
        if antiAfkEnabled then
            if not getgenv().AntiAFKConn then
                getgenv().AntiAFKConn = lp.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
            for i = 1, 60 do
                task.wait(1)
                if not antiAfkEnabled or not getgenv().AntiAFKLoop then break end
            end
            if antiAfkEnabled and getgenv().AntiAFKLoop then
                VirtualUser:CaptureController()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(0.1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end
        else
            if getgenv().AntiAFKConn then
                getgenv().AntiAFKConn:Disconnect()
                getgenv().AntiAFKConn = nil
            end
        end
    end
end)

------------------------------------------------
-- AUTO CATERING LOOP
------------------------------------------------
local Catering = RS:WaitForChild("Network"):WaitForChild("Catering")

local function findContent()
    for _, v in ipairs(pg:GetDescendants()) do
        if v.Name == "Catering" and v:FindFirstChild("Content") then
            return v.Content
        end
    end
end

local function getProgress()
    local content = findContent()
    if not content then return end
    for _, entry in ipairs(content:GetChildren()) do
        if entry.Name:match("^Entry") and entry.Visible then
            local d = entry:FindFirstChild("Detail")
            if d and d:IsA("TextLabel") and d.Visible then
                local cur, max = d.Text:match("(%d+)%s*/%s*(%d+)")
                if cur then
                    return tonumber(cur), tonumber(max)
                end
            end
        end
    end
end

getgenv().CateringFarm = true
task.spawn(function()
    while getgenv().CateringFarm do
        if cateringEnabled then
            local cur, max = getProgress()

            if not cur then
                Catering:FireServer("accept", selectedCategory)
                sessionAccepted += 1
                updateGui()
                task.wait(0.3)

            elseif cur >= max then
                Catering:FireServer("claim")
                sessionClaimed += 1
                updateGui()
                print("Claimed!")

                local t = 0
                while t < 3 do
                    local c, m = getProgress()
                    if not c or c < m then break end
                    task.wait(0.05)
                    t += 0.05
                end

            else
                task.wait(0.2)
            end
        else
            task.wait(0.5)
        end
    end
end)
