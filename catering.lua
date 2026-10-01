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
getgenv().AutoRejoinRun = nil
if getgenv().RejoinFailConn then getgenv().RejoinFailConn:Disconnect(); getgenv().RejoinFailConn = nil end
if getgenv().HatHideCleanup then pcall(getgenv().HatHideCleanup); getgenv().HatHideCleanup = nil end
task.wait()

local oldGui = pg:FindFirstChild("CateringMonitor")
if oldGui then oldGui:Destroy() end

-- Session counters
local sessionAccepted = 0
local sessionClaimed = 0
local selectedCategory = 3
local antiAfkEnabled = false
local cateringEnabled = false
local cateringMenuSync = false -- true = loop wajib buka Menu > Catering & claim dulu sebelum accept order baru
local autoDeliveryEnabled = false
local hideParticlesEnabled = false
local autoRejoinEnabled = false

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
frame.Size = UDim2.new(0, 260, 0, 0)
frame.AutomaticSize = Enum.AutomaticSize.Y
frame.Position = UDim2.new(0, 10, 0, 40)
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
pad.PaddingBottom = UDim.new(0, 10)

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

    local function set(v, silent)
        isOn = v and true or false
        refresh()
        if not silent then callback(isOn) end
    end

    return function() return isOn end, set
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

    local function set(v)
        for _, opt in ipairs(options) do
            if opt.value == v then
                selectedCategory = v
                refreshAll()
                callback(v)
                return
            end
        end
    end
    return set
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

------------------------------------------------
-- HIDE GREEN HATS (topi hijau di game + topi di stand hanger samping pintu)
-- Client-side saja (LocalTransparencyModifier), bisa di-restore saat toggle OFF
------------------------------------------------
local HatHider = {}
do
    local Workspace = game:GetService("Workspace")
    local active = false
    local hidden = {}      -- [Instance] = nilai asli (untuk Decal/Texture) atau true (BasePart)
    local conns = {}
    local checked = setmetatable({}, { __mode = "k" })

    local HAT_WORDS    = { "hat", "topi", "cap", "beanie", "fedora", "beret" }
    local HANGER_WORDS = { "hanger", "hook", "coatrack", "coat_rack", "rack", "stand" }

    local function nameHas(inst, words)
        local n = inst.Name:lower()
        for _, w in ipairs(words) do
            if n:find(w, 1, true) then return true end
        end
        return false
    end

    local function isGreen(c)
        -- hijau dominan: G jelas lebih besar dari R dan B
        return c.G > 0.30 and c.G > c.R * 1.25 and c.G > c.B * 1.25
    end

    local function partIsGreen(part)
        if part:IsA("BasePart") then
            if isGreen(part.Color) then return true end
            if part:IsA("MeshPart") and part.TextureID ~= "" and part.Name:lower():find("green", 1, true) then return true end
        end
        return false
    end

    -- Apakah instance ini "topi"? (Accessory/Hat, atau nama mengandung hat/topi/cap)
    local function isHatLike(inst)
        if inst:IsA("Accessory") or inst:IsA("Hat") then return true end
        if (inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Folder")) and nameHas(inst, HAT_WORDS) then
            return true
        end
        return false
    end

    local function underHanger(inst)
        local p = inst.Parent
        while p and p ~= Workspace do
            if nameHas(p, HANGER_WORDS) then return true end
            p = p.Parent
        end
        return false
    end

    local function containsGreen(inst)
        if nameHas(inst, { "green", "hijau" }) then return true end
        if partIsGreen(inst) then return true end
        for _, d in ipairs(inst:GetDescendants()) do
            if partIsGreen(d) then return true end
            -- Accessory/Mesh dengan VertexColor hijau
            if d:IsA("SpecialMesh") and isGreen(d.VertexColor and Color3.new(d.VertexColor.X, d.VertexColor.Y, d.VertexColor.Z) or Color3.new(1,1,1)) then
                return true
            end
        end
        return false
    end

    local function hideOne(d)
        if hidden[d] ~= nil then return end
        if d:IsA("BasePart") then
            hidden[d] = true
            d.LocalTransparencyModifier = 1
        elseif d:IsA("Decal") or d:IsA("Texture") then
            hidden[d] = d.Transparency
            d.Transparency = 1
        elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Highlight") then
            hidden[d] = d.Enabled
            d.Enabled = false
        end
    end

    local function hideHat(root)
        hideOne(root)
        for _, d in ipairs(root:GetDescendants()) do hideOne(d) end
    end

    -- Cek satu instance; kalau topi hijau (atau topi di hanger) -> sembunyikan
    local function consider(inst)
        if not active or checked[inst] then return end
        if not isHatLike(inst) then return end
        checked[inst] = true
        if containsGreen(inst) or underHanger(inst) then
            hideHat(inst)
        end
    end

    local function scanAll()
        for _, d in ipairs(Workspace:GetDescendants()) do
            consider(d)
        end
    end

    ------------------------------------------------
    -- TOPHAT REMOVER (hapus semua "TopHat" yang bikin karakter stuck saat auto farm)
    -- Template di ReplicatedStorage di-backup dulu (clone) supaya bisa di-restore saat OFF
    ------------------------------------------------
    local TOPHAT_NAME = "TopHat"
    local tophatBackups = {}

    local function killTopHat(inst)
        if inst.Name ~= TOPHAT_NAME then return end
        if inst:IsDescendantOf(RS) and inst.Parent then
            local ok, c = pcall(function() return inst:Clone() end)
            if ok and c then
                table.insert(tophatBackups, { clone = c, parent = inst.Parent })
            end
        end
        pcall(function() inst:Destroy() end)
    end

    local function purgeTopHats()
        -- path utama: ReplicatedStorage.Assets.Cafes.T1.Main.Cosmetic.TopHat
        local ok, t = pcall(function()
            return RS.Assets.Cafes.T1.Main.Cosmetic:FindFirstChild(TOPHAT_NAME)
        end)
        if ok and t then killTopHat(t) end

        -- TopHat di tier/cafe lain di dalam Assets
        local assets = RS:FindFirstChild("Assets")
        if assets then
            for _, d in ipairs(assets:GetDescendants()) do
                if d.Name == TOPHAT_NAME then killTopHat(d) end
            end
        end

        -- TopHat yang sudah ter-clone ke Workspace (cafe, NPC, karakter)
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d.Name == TOPHAT_NAME then killTopHat(d) end
        end
    end

    local function restoreTopHats()
        for _, b in ipairs(tophatBackups) do
            pcall(function()
                if b.parent and b.parent.Parent and not b.parent:FindFirstChild(TOPHAT_NAME) then
                    b.clone.Parent = b.parent
                end
            end)
        end
        table.clear(tophatBackups)
    end

    function HatHider.restore()
        for d, orig in pairs(hidden) do
            pcall(function()
                if not d.Parent then return end
                if d:IsA("BasePart") then
                    d.LocalTransparencyModifier = 0
                elseif d:IsA("Decal") or d:IsA("Texture") then
                    d.Transparency = orig
                else
                    d.Enabled = orig
                end
            end)
        end
        table.clear(hidden)
        table.clear(checked)
        restoreTopHats()
    end

    function HatHider.set(on)
        if on == active then return end
        active = on
        for _, c in ipairs(conns) do c:Disconnect() end
        table.clear(conns)

        if not on then
            HatHider.restore()
            return
        end

        task.spawn(scanAll)
        task.spawn(purgeTopHats)

        -- TopHat baru yang muncul/ter-clone -> langsung hapus
        table.insert(conns, Workspace.DescendantAdded:Connect(function(d)
            if d.Name == TOPHAT_NAME then
                task.defer(function() if active then killTopHat(d) end end)
            end
        end))
        local assetsFolder = RS:FindFirstChild("Assets")
        if assetsFolder then
            table.insert(conns, assetsFolder.DescendantAdded:Connect(function(d)
                if d.Name == TOPHAT_NAME then
                    task.defer(function() if active then killTopHat(d) end end)
                end
            end))
        end

        -- Topi baru yang muncul (spawn NPC/player, dekorasi baru, dll)
        table.insert(conns, Workspace.DescendantAdded:Connect(function(d)
            task.defer(function()
                if not active then return end
                consider(d)
                -- part/mesh anak dari topi yang sudah disembunyikan
                local p = d.Parent
                while p and p ~= Workspace do
                    if hidden[p] ~= nil or checked[p] then
                        if checked[p] and (containsGreen(p) or underHanger(p)) then hideOne(d) end
                        break
                    end
                    p = p.Parent
                end
            end)
        end))

        -- Jaga-jaga kalau game me-reset transparansi
        task.spawn(function()
            while active do
                for d, v in pairs(hidden) do
                    if d.Parent and d:IsA("BasePart") and d.LocalTransparencyModifier ~= 1 then
                        d.LocalTransparencyModifier = 1
                    end
                end
                task.wait(1)
            end
        end)
    end

    getgenv().HatHideCleanup = function() HatHider.set(false) end
end

-- Toggles
local _, setAntiAfk = makeToggle("Anti AFK", nextOrder(), false, function(on) antiAfkEnabled = on end)
local _, setCatering = makeToggle("Auto Catering", nextOrder(), false, function(on)
    cateringEnabled = on
    if on then cateringMenuSync = true end -- prioritas: buka Menu > Catering & claim yang tertunda
end)
local _, setAutoDelivery = makeToggle("Auto Delivery", nextOrder(), false, function(on) autoDeliveryEnabled = on end)
local _, setHideParticles = makeToggle("Hide FX Particles", nextOrder(), false, function(on)
    hideParticlesEnabled = on
    HatHider.set(on)   -- sembunyikan topi hijau + topi di stand hanger + HAPUS semua TopHat
end)
local _, setAutoRejoin = makeToggle("Auto Rejoin (10m)", nextOrder(), false, function(on) autoRejoinEnabled = on end)

makeDivider(nextOrder())

-- Kategori Catering
local setCategory = makeDropdown("Catering", nextOrder(), {
    { label = "1", value = 1 },
    { label = "2", value = 2 },
    { label = "3", value = 3 },
}, 3, function(val) selectedCategory = val end)

makeDivider(nextOrder())

------------------------------------------------
-- CONFIG SYSTEM (save / load / delete / auto load / nama custom)
-- File config : <workspace>/MyCafeTools/configs/<nama>.json
-- Auto load   : nama config disimpan di <workspace>/MyCafeTools/meta.json
-- Yang disimpan: Anti AFK, Auto Catering, Auto Delivery, Hide FX,
--                kategori catering, posisi GUI
------------------------------------------------
local ConfigSystem = {}
do
    local HttpService = game:GetService("HttpService")

    local CFG_ROOT = "MyCafeTools"
    local CFG_DIR = CFG_ROOT .. "/configs"
    local META_PATH = CFG_ROOT .. "/meta.json"
    local FS_OK = (writefile and readfile and isfile and isfolder and makefolder) and true or false

    ----------------------------------------
    -- File helpers
    ----------------------------------------
    local function sanitizeName(s)
        s = tostring(s or "")
        s = s:gsub("[^%w%-_ ]", "")
        s = s:gsub("^%s+", "")
        s = s:gsub("%s+$", "")
        return s:sub(1, 30)
    end

    local function pathOf(name)
        return CFG_DIR .. "/" .. name .. ".json"
    end

    local function ensureFolders()
        if not isfolder(CFG_ROOT) then makefolder(CFG_ROOT) end
        if not isfolder(CFG_DIR) then makefolder(CFG_DIR) end
    end

    local function readJson(path)
        if not FS_OK then return nil end
        local ok, data = pcall(function()
            if not isfile(path) then return nil end
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok and type(data) == "table" then return data end
        return nil
    end

    local function writeJson(path, tbl)
        if not FS_OK then return false end
        local ok = pcall(function()
            ensureFolders()
            writefile(path, HttpService:JSONEncode(tbl))
        end)
        return ok
    end

    local function listConfigs()
        local names = {}
        if FS_OK and listfiles and isfolder(CFG_DIR) then
            local ok, files = pcall(listfiles, CFG_DIR)
            if ok and type(files) == "table" then
                for _, f in ipairs(files) do
                    local n = tostring(f):match("([^/\\]+)%.json$")
                    if n then table.insert(names, n) end
                end
            end
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        return names
    end

    ----------------------------------------
    -- Meta (nama config auto load)
    ----------------------------------------
    local meta = readJson(META_PATH) or {}
    if type(meta.autoload) ~= "string" then meta.autoload = nil end

    local function saveMeta()
        writeJson(META_PATH, meta)
    end

    local currentName = meta.autoload or "default"

    ----------------------------------------
    -- Kumpulkan & terapkan setting
    ----------------------------------------
    local function collectConfig()
        local p = frame.Position
        return {
            version = 1,
            antiAfk = antiAfkEnabled,
            catering = cateringEnabled,
            autoDelivery = autoDeliveryEnabled,
            hideParticles = hideParticlesEnabled,
            autoRejoin = autoRejoinEnabled,
            category = selectedCategory,
            guiPos = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset },
        }
    end

    local function applyGuiPos(t)
        if type(t) ~= "table" then return end
        local xs, xo, ys, yo = t[1], t[2], t[3], t[4]
        if type(xs) ~= "number" or type(xo) ~= "number" or type(ys) ~= "number" or type(yo) ~= "number" then
            return
        end
        -- clamp supaya GUI tidak keluar layar (mis. config dari layar yang beda ukuran)
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local x = math.clamp(xs * vp.X + xo, 0, math.max(vp.X - 80, 0))
        local y = math.clamp(ys * vp.Y + yo, 0, math.max(vp.Y - 60, 0))
        frame.Position = UDim2.fromOffset(x, y)
    end

    local function applyConfig(cfg)
        if type(cfg.antiAfk) == "boolean" then setAntiAfk(cfg.antiAfk) end
        if type(cfg.catering) == "boolean" then setCatering(cfg.catering) end
        if type(cfg.autoDelivery) == "boolean" then setAutoDelivery(cfg.autoDelivery) end
        if type(cfg.hideParticles) == "boolean" then setHideParticles(cfg.hideParticles) end
        if type(cfg.autoRejoin) == "boolean" then setAutoRejoin(cfg.autoRejoin) end
        if type(cfg.category) == "number" then setCategory(cfg.category) end
        applyGuiPos(cfg.guiPos)
    end

    ----------------------------------------
    -- State UI (di-assign saat UI dibuat di bawah)
    ----------------------------------------
    local nameBox, listFrame, statusLbl, setAutoLoadToggle

    local function getName()
        local n = sanitizeName(nameBox and nameBox.Text or currentName)
        if n == "" then n = "default" end
        return n
    end

    local function setStatus(msg, good)
        if not statusLbl then return end
        statusLbl.Text = msg
        statusLbl.TextColor3 = good and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 120, 120)
    end

    local function refreshAutoloadToggle()
        if setAutoLoadToggle then
            setAutoLoadToggle(meta.autoload == currentName, true)
        end
    end

    local function refreshList()
        if not listFrame then return end
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end

        local names = listConfigs()

        if #names == 0 then
            local e = Instance.new("TextLabel")
            e.Size = UDim2.new(1, -6, 0, 20)
            e.BackgroundTransparency = 1
            e.Font = Enum.Font.Gotham
            e.TextSize = 11
            e.TextColor3 = Color3.fromRGB(110, 110, 120)
            e.Text = FS_OK and "(belum ada config)" or "(file API tidak didukung)"
            e.Parent = listFrame
            return
        end

        for i, n in ipairs(names) do
            local selected = (n == currentName)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -6, 0, 20)
            b.LayoutOrder = i
            b.BorderSizePixel = 0
            b.Font = Enum.Font.Gotham
            b.TextSize = 11
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.Text = (meta.autoload == n and "  ★ " or "  ") .. n
            b.BackgroundColor3 = selected and Color3.fromRGB(60, 130, 255) or Color3.fromRGB(40, 40, 52)
            b.TextColor3 = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170)
            b.Parent = listFrame
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)

            b.MouseButton1Click:Connect(function()
                currentName = n
                nameBox.Text = n
                refreshAutoloadToggle()
                refreshList()
            end)
        end
    end

    ----------------------------------------
    -- Aksi: save / load / delete / toggle auto load
    ----------------------------------------
    local function doSave()
        local name = getName()
        if writeJson(pathOf(name), collectConfig()) then
            currentName = name
            nameBox.Text = name
            setStatus("Tersimpan: " .. name, true)
        else
            setStatus(FS_OK and "Gagal menyimpan" or "Executor tidak support file", false)
        end
        refreshList()
        refreshAutoloadToggle()
    end

    local function loadByName(name, prefix)
        local cfg = readJson(pathOf(name))
        if not cfg then
            setStatus("Tidak ketemu: " .. name, false)
            return false
        end
        applyConfig(cfg)
        currentName = name
        nameBox.Text = name
        setStatus((prefix or "Dimuat: ") .. name, true)
        refreshList()
        refreshAutoloadToggle()
        return true
    end

    local deleteArmedName, deleteArmedAt = nil, 0
    local function doDelete(btn)
        local name = getName()
        if not (FS_OK and isfile(pathOf(name))) then
            setStatus("Tidak ketemu: " .. name, false)
            return
        end

        -- konfirmasi: klik 2x dalam 3 detik
        if deleteArmedName ~= name or os.clock() - deleteArmedAt > 3 then
            deleteArmedName = name
            deleteArmedAt = os.clock()
            btn.Text = "Yakin?"
            task.delay(3, function()
                if btn.Parent then btn.Text = "Delete" end
            end)
            return
        end

        deleteArmedName = nil
        btn.Text = "Delete"
        local ok = delfile and pcall(delfile, pathOf(name))
        if ok then
            if meta.autoload == name then
                meta.autoload = nil
                saveMeta()
            end
            setStatus("Dihapus: " .. name, true)
        else
            setStatus("Gagal hapus", false)
        end
        refreshList()
        refreshAutoloadToggle()
    end

    local function onAutoLoadToggled(on)
        if on then
            if not FS_OK then
                setStatus("Executor tidak support file", false)
                setAutoLoadToggle(false, true)
                return
            end
            local name = getName()
            currentName = name
            meta.autoload = name
            saveMeta()
            if not isfile(pathOf(name)) then doSave() end -- belum ada -> simpan dulu
            setStatus("Auto load: " .. name, true)
        else
            meta.autoload = nil
            saveMeta()
            setStatus("Auto load dimatikan", true)
        end
        refreshList()
        refreshAutoloadToggle()
    end

    ----------------------------------------
    -- Bangun UI
    ----------------------------------------
    makeLabel("⚙️ Config", nextOrder(), 16, Color3.fromRGB(190, 160, 255), Enum.Font.GothamBold)

    -- Input nama config
    nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, 0, 0, 24)
    nameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    nameBox.BorderSizePixel = 0
    nameBox.Text = currentName
    nameBox.PlaceholderText = "nama config..."
    nameBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 120)
    nameBox.TextColor3 = Color3.fromRGB(230, 230, 230)
    nameBox.ClearTextOnFocus = false
    nameBox.TextSize = 12
    nameBox.Font = Enum.Font.Gotham
    nameBox.TextXAlignment = Enum.TextXAlignment.Left
    nameBox.LayoutOrder = nextOrder()
    nameBox.Parent = frame
    Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)
    local nbPad = Instance.new("UIPadding", nameBox)
    nbPad.PaddingLeft = UDim.new(0, 8)

    nameBox.FocusLost:Connect(function()
        currentName = getName()
        nameBox.Text = currentName
        refreshAutoloadToggle()
        refreshList()
    end)

    -- Daftar config (klik untuk memilih)
    listFrame = Instance.new("ScrollingFrame")
    listFrame.Size = UDim2.new(1, 0, 0, 54)
    listFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 3
    listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listFrame.CanvasSize = UDim2.new()
    listFrame.LayoutOrder = nextOrder()
    listFrame.Parent = frame
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 6)
    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)

    -- Tombol Save / Load / Delete
    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1, 0, 0, 24)
    btnRow.BackgroundTransparency = 1
    btnRow.LayoutOrder = nextOrder()
    btnRow.Parent = frame
    local btnRowLayout = Instance.new("UIListLayout", btnRow)
    btnRowLayout.FillDirection = Enum.FillDirection.Horizontal
    btnRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    btnRowLayout.Padding = UDim.new(0, 4)

    local function makeSmallBtn(text, order, color, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1 / 3, -3, 1, 0)
        b.LayoutOrder = order
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 11
        b.Font = Enum.Font.GothamBold
        b.Parent = btnRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function() cb(b) end)
        return b
    end

    makeSmallBtn("Save", 1, Color3.fromRGB(40, 160, 80), function() doSave() end)
    makeSmallBtn("Load", 2, Color3.fromRGB(60, 130, 255), function() loadByName(getName()) end)
    makeSmallBtn("Delete", 3, Color3.fromRGB(170, 60, 60), function(b) doDelete(b) end)

    -- Toggle auto load
    local _, setter = makeToggle("Auto Load", nextOrder(), meta.autoload == currentName, onAutoLoadToggled)
    setAutoLoadToggle = setter

    -- Status
    statusLbl = makeLabel(FS_OK and "Siap" or "File API tidak tersedia", nextOrder(), 16, Color3.fromRGB(150, 150, 160), Enum.Font.Gotham)
    statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
    if not FS_OK then statusLbl.TextColor3 = Color3.fromRGB(255, 120, 120) end

    refreshList()

    ----------------------------------------
    -- API: dipanggil sekali di akhir script
    ----------------------------------------
    function ConfigSystem.autoLoad()
        if meta.autoload then
            loadByName(meta.autoload, "Auto load: ")
        end
    end
end

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

------------------------------------------------
-- PRIORITAS SAAT AUTO CATERING DINYALAKAN:
-- buka HUD "Menu" -> tab "Catering" -> claim catering sebelumnya -> tutup Menu
-- Path (dicek langsung di game):
--   Hud.TopMiddle.Items.Menu.Activator                    (tombol Menu)
--   Menu.Menu.Content.Background.List.Catering.Activator  (tab Catering)
--   Menu.Menu.Content.List.Catering                       (halaman Catering)
--   Menu.Menu.Content.Header.close                        (tombol tutup)
------------------------------------------------
local function clickGui(btn)
    if not btn then return false end
    local fired = false
    if getconnections then
        for _, sig in ipairs({ btn.Activated, btn.MouseButton1Click }) do
            local okC, conns = pcall(getconnections, sig)
            if okC and conns then
                for _, c in ipairs(conns) do
                    pcall(function() c:Fire() end)
                    fired = true
                end
            end
        end
    end
    if not fired and firesignal then
        fired = pcall(firesignal, btn.Activated)
    end
    return fired
end

local function menuFrame()
    local m = pg:FindFirstChild("Menu")
    return m and m:FindFirstChild("Menu")
end

local function waitFor(cond, timeout)
    local t = 0
    while t < timeout do
        local ok, r = pcall(cond)
        if ok and r then return true end
        task.wait(0.1)
        t += 0.1
    end
    return false
end

local function openCateringMenu()
    local mf = menuFrame()
    if not mf then return false end

    -- 1) buka Menu (kalau belum terbuka)
    if not mf.Visible then
        local ok, btn = pcall(function() return pg.Hud.TopMiddle.Items.Menu.Activator end)
        if ok and btn then clickGui(btn) end
        if not waitFor(function() return mf.Visible end, 3) then return false end
    end

    -- 2) pindah ke tab Catering
    local okTab, tab = pcall(function()
        return mf.Content.Background.List.Catering.Activator
    end)
    if okTab and tab then clickGui(tab) end
    local page = mf.Content.List:FindFirstChild("Catering")
    return page ~= nil and waitFor(function() return page.Visible end, 3)
end

local function closeMenu()
    local mf = menuFrame()
    if mf and mf.Visible then
        local ok, btn = pcall(function() return mf.Content.Header.close end)
        if ok and btn then clickGui(btn) end
    end
end

-- tombol Action di Entry (label "Claim"/"Give" tergantung state)
local function clickEntryAction()
    local content = findContent()
    if not content then return false end
    for _, entry in ipairs(content:GetChildren()) do
        if entry.Name:match("^Entry") and entry.Visible then
            local act = entry:FindFirstChild("Action")
            local btn = act and act:FindFirstChild("Activator")
            if btn then
                local lbl = act:FindFirstChildWhichIsA("TextLabel")
                local txt = lbl and lbl.Text:lower() or ""
                if txt:find("claim") or txt:find("collect") then
                    return clickGui(btn)
                end
            end
        end
    end
    return false
end

local function syncCateringMenu()
    print("[Catering] buka Menu > Catering untuk claim yang tertunda...")
    if not openCateringMenu() then
        warn("[Catering] gagal membuka Menu > Catering, lanjut tanpa claim lewat UI")
        closeMenu()
        return
    end
    task.wait(0.4)

    -- claim sampai tidak ada yang tertunda (maks 5x)
    for _ = 1, 5 do
        local cur, max = getProgress()
        local pending = (cur and max and cur >= max) or hasClaimableReward()
        if not pending then break end
        clickEntryAction()
        Catering:FireServer("claim")
        sessionClaimed += 1
        updateGui()
        print("[Catering] Claimed catering sebelumnya")
        task.wait(0.6)
    end

    closeMenu()
    task.wait(0.3)
end

getgenv().CateringFarm = true
task.spawn(function()
    while getgenv().CateringFarm do
        if cateringEnabled then
            -- PRIORITAS: baru dinyalakan -> buka Menu > Catering & claim dulu
            if cateringMenuSync then
                cateringMenuSync = false
                pcall(syncCateringMenu)
            end

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

local DELIVERY_ACCEPT_WAIT = 0.1  -- detik setelah accept sebelum tween ke NPC
local DELIVERY_FRONT_DIST = 3.5   -- jarak berdiri di depan NPC (studs)
local DELIVERY_REPEAT_WAIT = 0.1  -- jeda sebelum order berikutnya
local DELIVERY_HAND_TIMEOUT = 1.2 -- tunggu respon server per metode hand over (detik)
local DELIVERY_TWEEN_SPEED = 70  -- kecepatan tween (studs/detik); kecilkan kalau kena cancel

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

-- Watchdog idle: kalau 10 detik tidak ada respon dari auto delivery -> reset karakter
local IDLE_RESET_SECONDS = 10       -- batas idle sebelum reset karakter
local MAX_IDLE_RESETS = 5           -- reset beruntun tanpa hasil -> Auto Delivery dimatikan (cegah loop reset)
local lastActivity = os.clock()     -- waktu terakhir ada "respon" (event server / sedang tween)
local idleResets = 0                -- jumlah reset beruntun tanpa order selesai
local resettingChar = false         -- true selama proses reset (delivery loop di-pause)

if getgenv().DeliveryEventConn then
    getgenv().DeliveryEventConn:Disconnect()
    getgenv().DeliveryEventConn = nil
end
getgenv().DeliveryEventConn = JobEvent.OnClientEvent:Connect(function(action, data)
    lastActivity = os.clock() -- ada respon dari server (start/delivery/complete/cancel)
    if action == "complete" then idleResets = 0 end
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
        lastActivity = os.clock() -- sedang tween = masih aktif, bukan idle
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
        if autoDeliveryEnabled and not resettingChar then
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
-- WATCHDOG AUTO DELIVERY: idle / tidak ada respon 10 detik -> reset karakter
-- (mis. order tidak ke-accept, prompt tidak merespon, karakter nyangkut)
------------------------------------------------
local function resetCharacter()
    resettingChar = true
    local oldChar = lp.Character
    job = nil
    dlog(string.format("idle >= %ds tanpa respon, reset karakter...", IDLE_RESET_SECONDS))

    pcall(function()
        local hum = getHumanoid()
        if hum then hum.Health = 0 end
    end)
    -- cadangan kalau Health = 0 tidak mempan
    task.wait(1)
    if lp.Character == oldChar and oldChar then
        pcall(function() oldChar:BreakJoints() end)
    end

    -- tunggu karakter baru muncul
    local t = 0
    while lp.Character == oldChar and t < 20 do
        task.wait(0.2)
        t += 0.2
    end

    local newChar = lp.Character
    if newChar and newChar ~= oldChar then
        newChar:WaitForChild("HumanoidRootPart", 10)
        task.wait(1)
        dwaitUntil(settled, 3)
        dlog("karakter berhasil di-reset, lanjut auto delivery")
    else
        dlog("karakter tidak ter-reset (timeout), lanjut saja")
    end

    job = nil
    lastActivity = os.clock()
    resettingChar = false
end

task.spawn(function()
    local wasEnabled = false
    while getgenv().AutoDeliveryRun == deliveryRunId do
        task.wait(0.5)

        if not autoDeliveryEnabled then
            wasEnabled = false
        else
            if not wasEnabled then
                wasEnabled = true
                lastActivity = os.clock()
            end

            local hum = getHumanoid()
            local dead = (not hum) or hum.Health <= 0
            local otherJobBusy = job ~= nil and job.kind ~= "Delivery"

            if resettingChar or dead or otherJobBusy then
                -- bukan idle: lagi respawn / lagi job lain
                lastActivity = os.clock()
            elseif os.clock() - lastActivity >= IDLE_RESET_SECONDS then
                idleResets += 1
                if idleResets > MAX_IDLE_RESETS then
                    warn(string.format("[AutoDelivery] %dx reset beruntun tanpa hasil, Auto Delivery dimatikan. Cek apakah station/prompt Delivery tersedia.", MAX_IDLE_RESETS))
                    idleResets = 0
                    lastActivity = os.clock()
                    setAutoDelivery(false)
                else
                    pcall(resetCharacter)
                    resettingChar = false
                end
            end
        end
    end
end)

------------------------------------------------
-- AUTO REJOIN tiap 10 menit (sama seperti perintah "rejoin" di Infinite Yield)
-- Setelah rejoin, script dijalankan ulang lewat queue_on_teleport:
--   1) simpan script di  <workspace>/MyCafeTools/catering_3.lua   (disarankan), atau
--   2) set getgenv().CateringScriptURL = "https://.../catering_3.lua" sebelum execute, atau
--   3) taruh script di folder autoexec executor (kalau begitu tidak perlu 1 & 2)
-- Config "Auto Load" menyalakan lagi semua toggle setelah rejoin.
------------------------------------------------
local REJOIN_INTERVAL = 600                          -- detik (10 menit)
local REJOIN_WAIT_JOB = 20                           -- tunggu order selesai maks segini lama sebelum rejoin
local REJOIN_SCRIPT_FILE = "MyCafeTools/catering_3.lua"
local REJOIN_SAME_SERVER_ONLY = false                -- true = paksa selalu balik ke JobId yang SAMA. false = pakai logika rejoin Infinite Yield (private server tetap otomatis pakai JobId yang sama)
local REJOIN_RESTORE_POS = false                     -- true = sama seperti "rejoin true" di IY: balik ke posisi terakhir setelah rejoin
local REJOIN_RETRIES = 3                             -- percobaan ulang kalau teleport ke server yang sama gagal
local TeleportService = game:GetService("TeleportService")
local queueTeleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

local function rejoinLoaderSource()
    if type(getgenv().CateringScriptURL) == "string" and getgenv().CateringScriptURL ~= "" then
        return string.format("loadstring(game:HttpGet(%q))()", getgenv().CateringScriptURL)
    end
    if isfile and isfile(REJOIN_SCRIPT_FILE) then
        return string.format("loadstring(readfile(%q))()", REJOIN_SCRIPT_FILE)
    end
    return nil
end

-- Setara teleportRespawnHandler IY: setelah rejoin, pindahkan karakter ke posisi sebelum rejoin
local RESPAWN_HANDLER = [[
local Players = game:GetService("Players")
local TS = game:GetService("TeleportService")
if not game:IsLoaded() then game.Loaded:Wait() end
local data = TS:GetLocalPlayerTeleportData()
if type(data) == "table" and type(data.pivot) == "table" then
    local lp = Players.LocalPlayer
    local char = lp.Character or lp.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(1)
    pcall(function() char:PivotTo(CFrame.new(table.unpack(data.pivot))) end)
end
]]

local reloadQueued = false -- cukup di-queue sekali (kalau teleport gagal, queue tetap ada -> jangan dobel)
local function queueReload()
    if reloadQueued then return true end
    if not queueTeleport then return false, "executor tidak punya queue_on_teleport" end
    local src = rejoinLoaderSource()
    if not src then return false, "file " .. REJOIN_SCRIPT_FILE .. " / CateringScriptURL tidak ada" end
    local handler = REJOIN_RESTORE_POS and (RESPAWN_HANDLER .. "\n") or ""
    queueTeleport(handler .. "if not game:IsLoaded() then game.Loaded:Wait() end task.wait(2) " .. src)
    reloadQueued = true
    return true
end

local rejoinFailed = false
getgenv().RejoinFailConn = TeleportService.TeleportInitFailed:Connect(function(_, result, msg)
    rejoinFailed = true
    warn("[AutoRejoin] teleport gagal: " .. tostring(result) .. " " .. tostring(msg))
end)

local function doRejoin()
    -- sama seperti addcmd("rejoin") IY: data = pivot karakter (hanya kalau restore posisi aktif)
    local data = nil
    if REJOIN_RESTORE_POS and lp.Character then
        data = { pivot = { lp.Character:GetPivot():GetComponents() } } -- CFrame diserialisasi ke angka
    end

    local ok, why = queueReload()
    if not ok then
        warn("[AutoRejoin] script TIDAK akan jalan otomatis setelah rejoin (" .. tostring(why) .. "). Abaikan jika pakai autoexec.")
    end

    local sameServerOnly = REJOIN_SAME_SERVER_ONLY or game.PrivateServerId ~= ""
    if sameServerOnly then
        -- PRIVATE SERVER: teleport langsung ke JobId server ini. TIDAK kick, TIDAK Teleport(PlaceId)
        -- (dua cara itu bisa melempar ke server publik). Kalau gagal, tetap di server ini & coba lagi.
        for attempt = 1, REJOIN_RETRIES do
            rejoinFailed = false
            print(string.format("[AutoRejoin] rejoin server yang sama (percobaan %d/%d)...", attempt, REJOIN_RETRIES))
            local okTp, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp, nil, data)
            end)
            if not okTp then
                warn("[AutoRejoin] error: " .. tostring(err))
                rejoinFailed = true
            end
            -- kalau teleport berjalan, client keluar dari server ini (script ikut berhenti)
            local t = 0
            while t < 12 and not rejoinFailed do
                task.wait(0.5)
                t += 0.5
            end
            if not rejoinFailed then return end -- masih nunggu teleport selesai
            task.wait(3)
        end
        warn("[AutoRejoin] gagal rejoin ke server yang sama, tetap di sini & lanjut farming (coba lagi nanti).")
        return
    end

    -- server publik: persis logika rejoin Infinite Yield
    print("[AutoRejoin] rejoin server...")
    if #Players:GetPlayers() <= 1 then
        lp:Kick("\nRejoining...")
        task.wait(0.3)
        TeleportService:Teleport(game.PlaceId, lp, data)
    else
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp, nil, data)
    end
end

local rejoinRunId = os.clock()
getgenv().AutoRejoinRun = rejoinRunId
task.spawn(function()
    local nextRejoin = nil
    while getgenv().AutoRejoinRun == rejoinRunId do
        task.wait(1)
        if not autoRejoinEnabled then
            nextRejoin = nil
        else
            if not nextRejoin then
                nextRejoin = os.clock() + REJOIN_INTERVAL
                local ok, why = pcall(rejoinLoaderSource)
                if not (ok and why and queueTeleport) then
                    warn("[AutoRejoin] aktif, tapi script tidak bisa auto-reload setelah rejoin. Simpan script ke workspace/" .. REJOIN_SCRIPT_FILE .. " atau set getgenv().CateringScriptURL.")
                end
                print(string.format("[AutoRejoin] aktif, rejoin tiap %d menit", REJOIN_INTERVAL / 60))
            end

            if os.clock() >= nextRejoin then
                -- jangan potong order yang sedang jalan (maks REJOIN_WAIT_JOB detik)
                local t = 0
                while job ~= nil and t < REJOIN_WAIT_JOB and autoRejoinEnabled do
                    task.wait(0.5)
                    t += 0.5
                end
                if autoRejoinEnabled then
                    nextRejoin = os.clock() + 60 -- kalau teleport gagal, coba lagi 1 menit kemudian
                    pcall(doRejoin)
                end
            end
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

-- Auto load config (kalau diaktifkan)
ConfigSystem.autoLoad()

print("[My Cafe Tools] Loaded! Features:")
print("  - Anti AFK")
print("  - Auto Catering (fixed accept bug + buka Menu > Catering & claim dulu saat dinyalakan)")
print("  - Auto Delivery (tween ke depan NPC + hand over)")
print("  - Hide FX Particles (+ hide green hats / topi di stand hanger + hapus TopHat)")
print("  - Playtime tracker")
print("  - Config (save / load / auto load)")
