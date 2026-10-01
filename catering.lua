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
getgenv().AutoDeliveryRun = nil
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
-- AUTO DELIVERY (takeaway)
-- Alur: accept order -> tunggu 1 detik -> tween DI DEPAN NPC (berdiri di tanah)
--       -> hand over via remote (cadangan: tahan E / klik tombol) -> order ke-claim -> ulang
------------------------------------------------
local JobEvent = RS:WaitForChild("Network"):WaitForChild("JobEvent")

local DELIVERY_ACCEPT_WAIT = 0.5  -- detik setelah accept sebelum tween ke NPC
local DELIVERY_FRONT_DIST = 3.5   -- jarak berdiri di depan NPC (studs)
local DELIVERY_REPEAT_WAIT = 0.3  -- jeda sebelum order berikutnya
local DELIVERY_HAND_TIMEOUT = 1.2 -- tunggu respon server per metode hand over (detik)
local DELIVERY_TWEEN_SPEED = 80  -- kecepatan tween (studs/detik); kecilkan kalau kena cancel

local function dlog(...)
    print("[AutoDelivery]", ...)
end

local function dwaitUntil(cond, timeout)
    local t = 0
    while t < timeout do
        if cond() then return true end
        task.wait(0.05)
        t += 0.05
    end
    return cond() and true or false
end

local function getHRP()
    local char = lp.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = lp.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

------------------------------------------------
-- State job dari event server
-- "cancel" mengirim STRING alasan (bukan table)
------------------------------------------------
local job = nil       -- { id, kind, at, ready, doorstep, target }
local lastEnd = nil   -- { action, reason }

if getgenv().DeliveryEventConn then
    getgenv().DeliveryEventConn:Disconnect()
    getgenv().DeliveryEventConn = nil
end
getgenv().DeliveryEventConn = JobEvent.OnClientEvent:Connect(function(action, data)
    if action == "start" and type(data) == "table" then
        job = { id = data.id, kind = tostring(data.job), at = os.clock(), ready = false }
    elseif action == "delivery" and type(data) == "table" then
        if job and job.id == data.id then
            job.doorstep = data.doorstep -- CFrame pintu/NPC
            job.target = data.target     -- Vector3 tujuan
            job.ready = true
        elseif not job then
            job = { id = data.id, kind = "Delivery", at = os.clock(), doorstep = data.doorstep, target = data.target, ready = true }
        end
    elseif action == "complete" then
        lastEnd = { action = "complete" }
        job = nil
    elseif action == "cancel" then
        lastEnd = { action = "cancel", reason = tostring(data) }
        job = nil
        dlog("order di-cancel server:", tostring(data))
    end
end)

------------------------------------------------
-- Station & prompt "Delivery" (tempat accept order)
------------------------------------------------
local cachedStation = nil
local function findMyStation()
    if cachedStation and cachedStation.Parent then return cachedStation end
    cachedStation = nil
    for _, d in ipairs(workspace:GetDescendants()) do
        if d.Name == "CafeJobs" and d:GetAttribute("JobOwnerId") == lp.UserId then
            cachedStation = d
            return d
        end
    end
    return nil
end

local function findDeliveryPrompt()
    local station = findMyStation()
    if not station then return nil end
    local part = station:FindFirstChild("Delivery")
    if not part then return nil end
    return part:FindFirstChild("Prompt") or part:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function promptPosition(prompt)
    local p = prompt.Parent
    if not p then return nil end
    if p:IsA("Attachment") then return p.WorldPosition end
    if p:IsA("PVInstance") then return p:GetPivot().Position end
    return nil
end

-- Karakter sudah mendarat & berhenti
local function settled()
    local hrp = getHRP()
    if not hrp then return true end
    local hum = getHumanoid()
    local grounded = (not hum) or hum.FloorMaterial ~= Enum.Material.Air
    return grounded and hrp.AssemblyLinearVelocity.Magnitude < 1
end

------------------------------------------------
-- TWEEN: gerakkan karakter mulus ke tujuan (bukan teleport instan)
-- Collision dimatikan selama jalan supaya tidak nyangkut bangunan,
-- velocity di-nol-kan supaya tidak jatuh. abort() -> berhenti kalau job batal.
------------------------------------------------
local TweenService = game:GetService("TweenService")

local function tweenTo(cf, abort)
    local hrp = getHRP()
    if not hrp then return false end

    local dist = (hrp.Position - cf.Position).Magnitude
    local duration = math.max(dist / DELIVERY_TWEEN_SPEED, 0.15)

    local finished = false
    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = cf })
    tween.Completed:Connect(function() finished = true end)

    local noclip = RunService.Stepped:Connect(function()
        local char = lp.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then d.CanCollide = false end
        end
    end)
    local still = RunService.Heartbeat:Connect(function()
        local h = getHRP()
        if h then
            h.AssemblyLinearVelocity = Vector3.zero
            h.AssemblyAngularVelocity = Vector3.zero
        end
    end)

    tween:Play()
    dwaitUntil(function()
        return finished or (abort ~= nil and abort())
    end, duration + 3)

    if not finished then tween:Cancel() end
    noclip:Disconnect()
    still:Disconnect()

    local h = getHRP()
    if h then h.AssemblyLinearVelocity = Vector3.zero end
    return finished
end

------------------------------------------------
-- LANGKAH 1: accept order di station
------------------------------------------------
local function acceptOrder()
    local prompt = findDeliveryPrompt()
    if not prompt then
        dlog("prompt Delivery di station tidak ketemu")
        return false
    end
    if not prompt.Enabled then return false end

    -- balik ke station (tween) kalau masih jauh, mis. habis dari rumah NPC
    local hrp, pos = getHRP(), promptPosition(prompt)
    if hrp and pos and (hrp.Position - pos).Magnitude > math.max(prompt.MaxActivationDistance - 3, 4) then
        pcall(function() lp:RequestStreamAroundAsync(pos, 1) end)
        if not tweenTo(CFrame.new(pos + Vector3.new(0, 3, 0))) then return false end
        dwaitUntil(settled, 2)
    end

    job = nil
    fireproximityprompt(prompt)
    -- tunggu server kirim "start" lalu "delivery" (berisi posisi NPC)
    local ok = dwaitUntil(function() return job ~= nil and job.ready end, 5)
    if not ok and job and not job.ready then
        dlog("delivery data timeout, reset job")
        job = nil
    end
    return ok
end

------------------------------------------------
-- LANGKAH 3: hitung koordinat tujuan & tween ke DEPAN NPC
------------------------------------------------
local function getDeliveryGoal(j)
    local basePos, lookAtPos
    if j.doorstep then
        local cf = j.doorstep
        local front = (cf.LookVector * Vector3.new(1, 0, 1))
        if front.Magnitude < 0.05 and j.target then
            front = (j.target - cf.Position) * Vector3.new(1, 0, 1)
        end
        if front.Magnitude < 0.05 then
            front = Vector3.new(0, 0, 1)
        end
        front = front.Unit
        basePos = cf.Position + front * DELIVERY_FRONT_DIST
        lookAtPos = cf.Position
    elseif j.target then
        basePos = j.target + Vector3.new(0, 0, DELIVERY_FRONT_DIST)
        lookAtPos = j.target
    else
        return nil
    end

    local hrp, hum = getHRP(), getHumanoid()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    if lp.Character then
        params.FilterDescendantsInstances = { lp.Character }
    end
    local hit = workspace:Raycast(basePos + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
    local hip = (hum and hum.HipHeight or 2) + (hrp and hrp.Size.Y / 2 or 1.5)
    local y = hit and (hit.Position.Y + hip + 0.1) or (basePos.Y + 0.3)
    local stand = Vector3.new(basePos.X, y, basePos.Z)

    return CFrame.lookAt(stand, Vector3.new(lookAtPos.X, stand.Y, lookAtPos.Z))
end

local function findNpc(doorstep)
    local want = doorstep and doorstep.Position
    for _, m in ipairs(workspace:GetChildren()) do
        if m.Name == "TakeawayCustomer" then
            local root = m:FindFirstChild("HumanoidRootPart")
            if root and (not want or (root.Position - want).Magnitude < 15) then
                return m, root
            end
        end
    end
    return nil
end

local function moveInFront(j, npc, npcRoot)
    local goal = getDeliveryGoal(j)
    if not goal then return false end
    pcall(function() lp:RequestStreamAroundAsync(goal.Position, 1) end)
    return tweenTo(goal, function() return job ~= j end)
end

------------------------------------------------
-- LANGKAH 4: hand over via REMOTE (cadangan: tahan E / klik tombol)
------------------------------------------------
local function holdE(prompt)
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(math.max(prompt.HoldDuration, 0) + 0.05)
        prompt:InputHoldEnd()
    end)
end

local function clickHandOverButton()
    local gui = pg:FindFirstChild("CafeJobs")
    local dock = gui and gui:FindFirstChild("Dock")
    local buttons = dock and dock:FindFirstChild("Buttons")
    local primary = buttons and buttons:FindFirstChild("Primary")
    if not primary then return false end
    local activator = primary:FindFirstChild("Activator", true) or primary

    local fired = false
    if getconnections then
        for _, c in ipairs(getconnections(activator.Activated)) do
            pcall(function() c:Fire() end)
            fired = true
        end
    end
    if not fired and firesignal then
        fired = pcall(firesignal, activator.Activated)
    end
    return fired
end

local function handOver(j, prompt)
    local function ended()
        return job == nil or job.id ~= j.id
    end

    -- 1) REMOTE: kirim "deliver" langsung (sama persis dengan tombol Hand over), tanpa hold
    JobEvent:FireServer("deliver", j.id)
    if dwaitUntil(ended, DELIVERY_HAND_TIMEOUT) then return true end

    -- cadangan kalau remote tidak direspon server:
    -- 2) tahan E
    if prompt and prompt.Enabled then
        holdE(prompt)
        if dwaitUntil(ended, DELIVERY_HAND_TIMEOUT) then return true end
    end

    -- 3) klik tombol "Hand over" di HUD
    if clickHandOverButton() then
        if dwaitUntil(ended, DELIVERY_HAND_TIMEOUT) then return true end
    end

    -- 4) fire prompt langsung
    if prompt and prompt.Enabled then
        pcall(fireproximityprompt, prompt)
        return dwaitUntil(ended, DELIVERY_HAND_TIMEOUT)
    end
    return ended()
end

------------------------------------------------
-- SATU SIKLUS: accept -> 1 detik -> tween depan NPC -> hand over
------------------------------------------------
local function deliveryCycle()
    -- order nyangkut? (batas delivery 90 detik)
    if job and os.clock() - job.at > 90 then
        dlog("order nyangkut / timeout, force cancel")
        pcall(function() JobEvent:FireServer("cancel", job.id) end)
        job = nil
        task.wait(0.5)
        return
    end

    -- job lain sedang aktif: jangan ganggu
    if job and job.kind ~= "Delivery" then
        task.wait(1)
        return
    end

    -- 1. accept
    if not job or not job.ready then
        if not acceptOrder() then
            task.wait(1)
            return
        end
    end

    local j = job
    if not j or not j.ready then
        task.wait(0.5)
        return
    end

    -- 2. tunggu sebentar setelah accept
    task.wait(DELIVERY_ACCEPT_WAIT)
    if job ~= j then return end

    -- 3. langsung tween ke koordinat target / doorstep NPC (tanpa blokir nunggu NPC spawn)
    local goal = getDeliveryGoal(j)
    if not goal then
        dlog("koordinat tujuan tidak valid, reset")
        job = nil
        return
    end

    pcall(function() lp:RequestStreamAroundAsync(goal.Position, 1) end)
    local tweenOk = tweenTo(goal, function() return job ~= j end)
    if not tweenOk then
        if job == j then
            dlog("tween gagal/batal, reset")
            job = nil
        end
        return
    end

    if job ~= j then return end
    dwaitUntil(function() return job ~= j or settled() end, 1)
    if job ~= j then return end

    -- 4. cari prompt / NPC customer setelah sampai
    local npc, npcRoot
    dwaitUntil(function()
        npc, npcRoot = findNpc(j.doorstep)
        return npc ~= nil or job ~= j
    end, 2)
    if job ~= j then return end

    local prompt = npcRoot and (npcRoot:FindFirstChildOfClass("ProximityPrompt") or npcRoot:FindFirstChildWhichIsA("ProximityPrompt", true))

    local hrp = getHRP()
    dlog(string.format("di lokasi tujuan (jarak %.1f studs), hand over...", hrp and npcRoot and (hrp.Position - npcRoot.Position).Magnitude or -1))

    -- 5. hand over via remote / prompt / HUD button
    lastEnd = nil
    local ok = handOver(j, prompt)
    if ok and lastEnd and lastEnd.action == "complete" then
        dlog("order ter-claim")
    elseif lastEnd and lastEnd.action == "cancel" then
        dlog("gagal, server cancel:", lastEnd.reason or "?")
    else
        dlog("hand over belum respon, cancel & reset")
        pcall(function() JobEvent:FireServer("cancel", j.id) end)
        job = nil
    end

    -- 6. ulang
    task.wait(DELIVERY_REPEAT_WAIT)
end

local deliveryRunId = os.clock()
getgenv().AutoDeliveryRun = deliveryRunId
task.spawn(function()
    while getgenv().AutoDeliveryRun == deliveryRunId do
        if autoDeliveryEnabled then
            local ok, err = pcall(deliveryCycle)
            if not ok then
                warn("[AutoDelivery] error: " .. tostring(err))
                task.wait(2)
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
print("  - Auto Delivery (tween ke depan NPC + hand over)")
print("  - Hide FX Particles")
print("  - Playtime tracker")
