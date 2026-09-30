local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

------------------------------------------------
-- CLEANUP (re-execute safe)
------------------------------------------------
if getgenv().AntiAFKConn then getgenv().AntiAFKConn:Disconnect(); getgenv().AntiAFKConn = nil end
getgenv().AntiAFKLoop = false
getgenv().CateringFarm = false
getgenv().AutoDishesLoop = false
getgenv().AutoDeliveryLoop = false
getgenv().ParticleHookActive = false
task.wait()

local oldGui = pg:FindFirstChild("CateringMonitor")
if oldGui then oldGui:Destroy() end

-- Session counters
local sessionAccepted = 0
local sessionClaimed = 0
local selectedCategory = 3
local antiAfkEnabled = false
local cateringEnabled = false
local autoDishesEnabled = false
local autoDeliveryEnabled = false
local hideParticlesEnabled = false

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
-- FUNGSI: Baca total playtime dari DataService
------------------------------------------------
local function getPlaytime()
    local ok, result = pcall(function()
        local DataService = require(RS.Code.packages.DataService)
        local data = DataService.client._data._data
        if data and data.stats then
            return data.stats["Time Played"] or 0
        end
        return 0
    end)
    return ok and result or 0
end

local function formatPlaytime(totalSeconds)
    totalSeconds = math.floor(totalSeconds)
    local days = math.floor(totalSeconds / 86400)
    local hours = math.floor((totalSeconds % 86400) / 3600)
    local mins = math.floor((totalSeconds % 3600) / 60)
    local secs = totalSeconds % 60
    if days > 0 then
        return string.format("%dd %dh %dm", days, hours, mins)
    elseif hours > 0 then
        return string.format("%dh %dm %ds", hours, mins, secs)
    else
        return string.format("%dm %ds", mins, secs)
    end
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
frame.Size = UDim2.new(0, 260, 0, 520)
frame.Position = UDim2.new(0, 10, 0.5, -260)
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
local orderIdx = 0
local function nextOrder()
    orderIdx = orderIdx + 1
    return orderIdx
end

makeLabel("🍽️ My Cafe Tools", nextOrder(), 20, Color3.fromRGB(80, 170, 255), Enum.Font.GothamBold)
makeDivider(nextOrder())

-- Toggles
makeToggle("Anti AFK", nextOrder(), false, function(on) antiAfkEnabled = on end)
makeToggle("Auto Catering", nextOrder(), false, function(on) cateringEnabled = on end)
makeToggle("Auto Dishes", nextOrder(), false, function(on) autoDishesEnabled = on end)
makeToggle("Auto Delivery", nextOrder(), false, function(on) autoDeliveryEnabled = on end)
makeToggle("Hide FX Particles", nextOrder(), false, function(on)
    hideParticlesEnabled = on
end)

makeDivider(nextOrder())

-- Kategori Catering
makeDropdown("Catering", nextOrder(), {
    { label = "1", value = 1 },
    { label = "2", value = 2 },
    { label = "3", value = 3 },
}, 3, function(val) selectedCategory = val end)

makeDivider(nextOrder())

-- Statistik sesi
makeLabel("📊 Sesi", nextOrder(), 16, Color3.fromRGB(180, 180, 200), Enum.Font.GothamBold)
local valSessAcc = makeStatRow("Accepted", nextOrder(), Color3.fromRGB(255, 255, 255))
local valSessClm = makeStatRow("Claimed", nextOrder(), Color3.fromRGB(255, 255, 255))

makeDivider(nextOrder())

-- Statistik total dari akun
makeLabel("🏆 Total", nextOrder(), 16, Color3.fromRGB(255, 200, 80), Enum.Font.GothamBold)
local valMilestoneTier = makeStatRow("Milestone", nextOrder(), Color3.fromRGB(255, 170, 50))
local valMilestoneProgress = makeStatRow("Progress", nextOrder(), Color3.fromRGB(120, 255, 120))

makeDivider(nextOrder())

-- Playtime
makeLabel("⏱️ Playtime", nextOrder(), 16, Color3.fromRGB(100, 200, 255), Enum.Font.GothamBold)
local valPlaytime = makeStatRow("Total", nextOrder(), Color3.fromRGB(180, 230, 255))
local valSessionTime = makeStatRow("Session", nextOrder(), Color3.fromRGB(140, 200, 230))
local sessionStart = os.clock()

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

    -- Playtime
    local totalSec = getPlaytime()
    valPlaytime.Text = formatPlaytime(totalSec)
    local sessionSec = math.floor(os.clock() - sessionStart)
    valSessionTime.Text = formatPlaytime(sessionSec)
end
updateGui()

-- Auto-refresh setiap 5 detik
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
-- AUTO CATERING LOOP (FIXED: cek reward pending)
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

-- Check apakah ada reward yang bisa di-claim (tombol claim visible)
local function hasClaimableReward()
    local content = findContent()
    if not content then return false end
    for _, entry in ipairs(content:GetChildren()) do
        if entry.Name:match("^Entry") and entry.Visible then
            -- Cari tombol claim (biasanya TextButton atau ImageButton dengan text "Claim")
            for _, child in ipairs(entry:GetDescendants()) do
                if (child:IsA("TextButton") or child:IsA("ImageButton")) then
                    if child.Visible then
                        local txt = ""
                        pcall(function() txt = child.Text end)
                        if txt:lower():find("claim") then
                            return true
                        end
                    end
                end
                -- Cek apakah ada label yang menunjukkan "Completed" atau progress full
                if child:IsA("TextLabel") and child.Visible then
                    local t = child.Text:lower()
                    if t:find("completed") or t:find("complete") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Cek apakah ada active catering order (Entry visible dengan progress)
local function hasActiveCatering()
    local cur, max = getProgress()
    return cur ~= nil
end

getgenv().CateringFarm = true
task.spawn(function()
    while getgenv().CateringFarm do
        if cateringEnabled then
            local cur, max = getProgress()

            if not cur then
                -- FIX: Sebelum accept, cek apakah ada reward pending yang belum di-claim
                -- Jika ada, coba claim dulu, JANGAN accept baru
                if hasClaimableReward() then
                    Catering:FireServer("claim")
                    sessionClaimed += 1
                    updateGui()
                    print("[Catering] Claimed pending reward")
                    task.wait(0.5)
                else
                    Catering:FireServer("accept", selectedCategory)
                    sessionAccepted += 1
                    updateGui()
                    task.wait(0.3)
                end

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

------------------------------------------------
-- AUTO WASH DISHES (1-5 plates scrub)
-- Menggunakan ProximityPrompt trigger + JobEvent
------------------------------------------------
local JobEvent = RS:WaitForChild("Network"):WaitForChild("JobEvent")

local function findMyStation()
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant.Name == "CafeJobs" and descendant:GetAttribute("JobOwnerId") == lp.UserId then
            return descendant
        end
    end
    return nil
end

local function findDishesPrompt()
    local station = findMyStation()
    if not station then return nil end
    local dishes = station:FindFirstChild("Dishes")
    if dishes then
        return dishes:FindFirstChild("Prompt")
    end
    return nil
end

local function findDeliveryPrompt()
    local station = findMyStation()
    if not station then return nil end
    local delivery = station:FindFirstChild("Delivery")
    if delivery then
        return delivery:FindFirstChild("Prompt")
    end
    return nil
end

-- Check apakah sedang dalam job aktif
local function isJobActive()
    local cafeJobsGui = pg:FindFirstChild("CafeJobs")
    if not cafeJobsGui then return false end
    if not cafeJobsGui.Enabled then return false end
    local banner = cafeJobsGui:FindFirstChild("Banner")
    return banner and banner.Visible
end

-- Listen for job events dari server
local activeJobId = nil
local activeJobType = nil
local dishRound = 1
local dishClean = false
local deliveryTarget = nil

JobEvent.OnClientEvent:Connect(function(action, data)
    if action == "start" then
        activeJobId = data.id
        activeJobType = data.job
        dishRound = 1
        dishClean = false
        deliveryTarget = nil
    elseif action == "plate" then
        if data.id == activeJobId then
            dishRound = data.round
            dishClean = false
        end
    elseif action == "delivery" then
        if data.id == activeJobId then
            deliveryTarget = data.target
        end
    elseif action == "complete" or action == "cancel" then
        activeJobId = nil
        activeJobType = nil
        deliveryTarget = nil
        dishClean = false
    elseif action == "scrub" then
        if data and data.id == activeJobId then
            if data.progress and data.progress >= 0.95 then
                dishClean = true
            end
        end
    end
end)

-- Auto Dishes: trigger prompt, lalu spam scrub events
getgenv().AutoDishesLoop = true
task.spawn(function()
    while getgenv().AutoDishesLoop do
        if autoDishesEnabled then
            -- Jika tidak ada job aktif, trigger dishes prompt
            if not activeJobId then
                local prompt = findDishesPrompt()
                if prompt and prompt.Enabled then
                    -- Fire proximity prompt
                    fireproximityprompt(prompt)
                    task.wait(0.8) -- Tunggu server respond
                end
            elseif activeJobType == "Dishes" and activeJobId then
                -- Spam scrub events di posisi yang tepat untuk membersihkan plate
                -- Scrub di berbagai posisi dalam radius dirt (0.39)
                -- GridSize = 24, CompletionThreshold = 0.95
                local scrubPositions = {
                    Vector2.new(0.5, 0.5),
                    Vector2.new(0.35, 0.35),
                    Vector2.new(0.65, 0.35),
                    Vector2.new(0.35, 0.65),
                    Vector2.new(0.65, 0.65),
                    Vector2.new(0.5, 0.35),
                    Vector2.new(0.5, 0.65),
                    Vector2.new(0.35, 0.5),
                    Vector2.new(0.65, 0.5),
                    Vector2.new(0.42, 0.42),
                    Vector2.new(0.58, 0.42),
                    Vector2.new(0.42, 0.58),
                    Vector2.new(0.58, 0.58),
                    Vector2.new(0.3, 0.5),
                    Vector2.new(0.7, 0.5),
                    Vector2.new(0.5, 0.3),
                    Vector2.new(0.5, 0.7),
                    Vector2.new(0.38, 0.3),
                    Vector2.new(0.62, 0.3),
                    Vector2.new(0.38, 0.7),
                    Vector2.new(0.62, 0.7),
                }

                local seq = 0
                for _, pos in ipairs(scrubPositions) do
                    if not autoDishesEnabled or not activeJobId or activeJobType ~= "Dishes" then break end
                    seq += 1
                    -- FireServer("scrub", id, position, round, seq, hasPrevious)
                    JobEvent:FireServer("scrub", activeJobId, pos, dishRound, seq, seq > 1)
                    task.wait(0.09) -- Interval sesuai SendInterval (0.083)
                end

                -- Tunggu server respon plate completion
                task.wait(0.5)
            else
                task.wait(0.3)
            end
        else
            task.wait(0.5)
        end
    end
end)

------------------------------------------------
-- AUTO TAKEAWAY DELIVERY
-- Trigger prompt, teleport ke target, deliver
------------------------------------------------
getgenv().AutoDeliveryLoop = true
task.spawn(function()
    while getgenv().AutoDeliveryLoop do
        if autoDeliveryEnabled then
            if not activeJobId then
                -- Trigger delivery prompt
                local prompt = findDeliveryPrompt()
                if prompt and prompt.Enabled then
                    fireproximityprompt(prompt)
                    task.wait(1.0) -- Tunggu server respond dan delivery event
                end
            elseif activeJobType == "Delivery" and activeJobId then
                -- Tunggu sampai deliveryTarget di-set oleh server
                if deliveryTarget then
                    -- Teleport karakter ke target
                    local char = lp.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        -- Teleport ke dekat doorstep (target posisi)
                        hrp.CFrame = CFrame.new(deliveryTarget + Vector3.new(0, 3, 0))
                        task.wait(0.5)

                        -- Fire deliver event
                        JobEvent:FireServer("deliver", activeJobId)
                        task.wait(1.0)

                        -- Teleport balik ke station
                        local station = findMyStation()
                        if station then
                            local delivery = station:FindFirstChild("Delivery")
                            if delivery and hrp.Parent then
                                hrp.CFrame = CFrame.new(delivery.Position + Vector3.new(0, 3, 0))
                            end
                        end
                        task.wait(0.5)
                    end
                else
                    task.wait(0.3)
                end
            else
                task.wait(0.3)
            end
        else
            task.wait(0.5)
        end
    end
end)

------------------------------------------------
-- HIDE REWARD PARTICLES (money/token burst effect)
-- Hook ke BottomLeft (HUD) untuk intercept CurrencyGain clones
------------------------------------------------
task.spawn(function()
    local hud = pg:WaitForChild("Hud", 10)
    if not hud then return end
    local bottomLeft = hud:WaitForChild("BottomLeft", 10)
    if not bottomLeft then return end

    -- Monitor BottomLeft untuk ChildAdded, hapus CurrencyGain
    bottomLeft.ChildAdded:Connect(function(child)
        if hideParticlesEnabled and child.Name == "CurrencyGain" then
            child:Destroy()
        end
    end)

    -- Juga hapus dari parent Hud (bisa juga muncul di parent lain)
    local hudParent = bottomLeft.Parent
    if hudParent then
        hudParent.ChildAdded:Connect(function(child)
            if hideParticlesEnabled and child.Name == "CurrencyGain" then
                child:Destroy()
            end
        end)
    end
end)

-- Juga hook ke template "Add" frames yang muncul saat mendapat reward
task.spawn(function()
    local hud = pg:WaitForChild("Hud", 10)
    if not hud then return end
    local bottomLeft = hud:WaitForChild("BottomLeft", 10)
    if not bottomLeft then return end

    -- Monitor untuk Add frames (the +$X popup)
    bottomLeft.DescendantAdded:Connect(function(desc)
        if hideParticlesEnabled then
            if desc.Name == "CurrencyGain" then
                desc:Destroy()
            end
        end
    end)
end)

print("[My Cafe Tools] Loaded! Features:")
print("  - Anti AFK")
print("  - Auto Catering (fixed accept bug)")
print("  - Auto Dishes (scrub 1-5 plates)")
print("  - Auto Delivery (teleport)")
print("  - Hide FX Particles")
print("  - Playtime tracker")
