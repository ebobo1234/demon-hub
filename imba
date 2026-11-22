--[[ demob hub ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

-- ================= CONFIG =================
local CFG = {
    ESP = {
        Enabled = true,
        InnocentColor = Color3.fromRGB(0, 255, 0),
        SheriffColor = Color3.fromRGB(0, 100, 255),
        MurdererColor = Color3.fromRGB(255, 0, 0),
        FillTransparency = 0.5,
        ShowLabels = true,
        ShowDistance = false,
    },
    Aim = {
        Enabled = true,
        FOV = 40,
        Smoothness = 0.25,
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 255, 255),
        FOVTransparency = 0.7,
        MaxDistance = 500,
        Silent = false,
        Prediction = 0.0,
        PredictionMax = 1.5,
        TriggerBot = false,
        TriggerDelay = 0.05,
    },
    Speed = { Enabled = false, AirSpeed = 50 },
    Teleport = { Offset = Vector3.new(0, 0, -3) },
    Jump = { Enabled = false },
    Move = {
        WalkSpeed = 16,
        JumpValue = 50,
        JumpEnabled = false,
        WalkEnabled = false,
        FlyEnabled = false,
        FlySpeed = 50,
    },
    Visuals = {
        Night = false, Fog = false, GlossyFloor = false,
        ColorCorrection = false, Blur = false, Bloom = false,
        WeaponSkins = false,
    },
    Fling = {
        AntiFling = false,
    },
    Cursor = { Mode = "None" },
    Theme = { Mode = "Default" },
    Weapons = {
        Murderer = {"Knife", "Blade", "Battleaxe", "Dagger"},
        Sheriff = {"Gun", "Revolver", "Pistol"},
    }
}

local ESP = {}
local FOVGui = nil
local JumpConn = nil
local Visuals = {
    ColorCorrection = nil, Blur = nil, Bloom = nil, GlossyParts = {},
    WeaponOriginalHandles = {},
    WeaponSkinConns = {},
}

-- Movement state
local FlyBodyVelocity = nil
local FlyBodyGyro = nil
local FlyActive = false
local FlyConn = nil
local FlyGui = nil
local WalkSpeedConn = nil
local TriggerLastShot = 0

-- Fling state
local AntiFlingConns = {}
local AntiFlingConn = nil

-- Theme state
local ThemeState = {
    Gui = nil, Root = nil, TabBar = nil, Content = nil,
    Tabs = {}, Sections = {}, Toggles = {}, Sliders = {}, Buttons = {}, ColorRows = {},
    Title = nil, MinBtn = nil, CloseBtn = nil, CornerFrames = {}, Conn = nil,
}

-- ================= UTILS =================
local function hasWeapon(plr, kind)
    local names = CFG.Weapons[kind]
    if not names then return false end
    local function scan(c)
        if not c then return false end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and table.find(names, t.Name) then return true end
        end
        return false
    end
    return scan(plr.Character) or scan(plr:FindFirstChild("Backpack"))
end

local function roleOf(plr)
    if hasWeapon(plr, "Murderer") then return "Murderer", CFG.ESP.MurdererColor end
    if hasWeapon(plr, "Sheriff") then return "Sheriff", CFG.ESP.SheriffColor end
    return "Innocent", CFG.ESP.InnocentColor
end

local function distTo(plr)
    local a = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local b = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not a or not b then return 0 end
    return math.floor((a.Position - b.Position).Magnitude)
end

-- ================= ESP =================
local function clearESP(plr)
    local e = ESP[plr]
    if e then
        if e.hl then e.hl:Destroy() end
        if e.bb then e.bb:Destroy() end
        ESP[plr] = nil
    end
end

local function clearAllESP()
    for p in pairs(ESP) do clearESP(p) end
end

local function buildESP(plr)
    if plr == LP then return end
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    clearESP(plr)
    local role, color = roleOf(plr)

    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = CFG.ESP.FillTransparency
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 36)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = char:FindFirstChild("Head") or char
    bb.Enabled = CFG.ESP.ShowLabels
    bb.Parent = char

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0.6, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = role
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bb

    local dst = Instance.new("TextLabel")
    dst.Size = UDim2.new(1, 0, 0.4, 0)
    dst.Position = UDim2.new(0, 0, 0.6, 0)
    dst.BackgroundTransparency = 1
    dst.Text = "0m"
    dst.TextColor3 = color
    dst.TextStrokeTransparency = 0
    dst.TextScaled = true
    dst.Font = Enum.Font.Gotham
    dst.Visible = CFG.ESP.ShowDistance
    dst.Parent = bb

    ESP[plr] = { hl = hl, bb = bb, lbl = lbl, dst = dst, role = role }
end

local function refreshESP()
    if not CFG.ESP.Enabled then clearAllESP(); return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then buildESP(p) end
    end
    for p, e in pairs(ESP) do
        if e.bb then e.bb.Enabled = CFG.ESP.ShowLabels end
        if e.dst then
            e.dst.Visible = CFG.ESP.ShowDistance
            if CFG.ESP.ShowDistance then e.dst.Text = distTo(p) .. "m" end
        end
    end
end

-- ================= AIMBOT =================
local function getTarget()
    local best, bestDist = nil, math.huge
    local char = LP.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and hasWeapon(p, "Murderer") then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < bestDist and d <= CFG.Aim.MaxDistance then
                    bestDist = d
                    best = p
                end
            end
        end
    end
    if best then
        return best, best.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function getPredictedPos(hrp)
    if not hrp then return nil end
    local vel = hrp.AssemblyLinearVelocity
    return hrp.Position + vel * CFG.Aim.Prediction
end

local function inFOV(worldPos)
    if CFG.Aim.FOV >= 180 then return true end
    local sp, on = Camera:WorldToViewportPoint(worldPos)
    if not on then return false end
    local c = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local r = (Camera.ViewportSize.Y / 2) * math.tan(math.rad(CFG.Aim.FOV / 2))
    return (Vector2.new(sp.X, sp.Y) - c).Magnitude <= r
end

local function silentAimShot(hrp)
    if not hrp then return end
    local char = LP.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local targetPos = getPredictedPos(hrp)
    if not targetPos then return end
    local camPos = Camera.CFrame.Position
    Camera.CFrame = CFrame.new(camPos, targetPos)
end

-- ================= FOV CIRCLE =================
local function clearFOVGui()
    for _, g in ipairs(LP.PlayerGui:GetChildren()) do
        if g:IsA("ScreenGui") and g.Name == "MMV_FOV" then g:Destroy() end
    end
    FOVGui = nil
end

local function buildFOV()
    clearFOVGui()
    local sg = Instance.new("ScreenGui")
    sg.Name = "MMV_FOV"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.Parent = LP:WaitForChild("PlayerGui")
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.BackgroundTransparency = 1
    f.Parent = sg
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = f
    local s = Instance.new("UIStroke")
    s.Thickness = 2
    s.Parent = f
    FOVGui = { gui = sg, frame = f, stroke = s }
end

local function tickFOV()
    if not FOVGui then return end
    FOVGui.frame.Visible = CFG.Aim.ShowFOV
    if not CFG.Aim.ShowFOV then return end
    local r = (Camera.ViewportSize.Y / 2) * math.tan(math.rad(CFG.Aim.FOV / 2))
    FOVGui.frame.Size = UDim2.new(0, r * 2, 0, r * 2)
    FOVGui.stroke.Color = CFG.Aim.FOVColor
    FOVGui.stroke.Transparency = CFG.Aim.FOVTransparency
end

-- ================= AIR SPEED =================
local function tickSpeed()
    if not CFG.Speed.Enabled then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
        hum.WalkSpeed = CFG.Speed.AirSpeed
    else
        hum.WalkSpeed = 16
    end
end

-- ================= MOVEMENT =================
local function applyWalkSpeed()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = CFG.Move.WalkSpeed end
end

local function applyJump()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.UseJumpPower then
        hum.JumpPower = CFG.Move.JumpValue
    else
        hum.JumpHeight = CFG.Move.JumpValue * 0.5
    end
end

local function startMovementLoops()
    if WalkSpeedConn then return end
    WalkSpeedConn = RunService.Heartbeat:Connect(function()
        if CFG.Move.WalkEnabled and not CFG.Speed.Enabled then
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = CFG.Move.WalkSpeed end
        end
        if CFG.Move.JumpEnabled then
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                if hum.UseJumpPower then
                    hum.JumpPower = CFG.Move.JumpValue
                else
                    hum.JumpHeight = CFG.Move.JumpValue * 0.5
                end
            end
        end
    end)
end

local function stopMovementLoops()
    if WalkSpeedConn then WalkSpeedConn:Disconnect(); WalkSpeedConn = nil end
end

-- ===== FLY GUI =====
local function buildFlyGui()
    if FlyGui then FlyGui:Destroy(); FlyGui = nil end
    local sg = Instance.new("ScreenGui")
    sg.Name = "MMV_FlyGui"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 50
    sg.Parent = LP:WaitForChild("PlayerGui")
    FlyGui = sg

    local box = Instance.new("Frame")
    box.Size = UDim2.new(0, 240, 0, 60)
    box.Position = UDim2.new(0.5, -120, 1, -80)
    box.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    box.BackgroundTransparency = 0.15
    box.BorderSizePixel = 0
    box.Parent = sg
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = box
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(90, 140, 255)
    s.Thickness = 1.5
    s.Parent = box

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "FLY (camera dir)  —  ON"
    title.TextColor3 = Color3.fromRGB(90, 200, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.Parent = box

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 16)
    info.Position = UDim2.new(0, 0, 0, 22)
    info.BackgroundTransparency = 1
    info.Text = "W/S — по камере  |  A/D — вбок  |  Space/Shift — вверх/вниз"
    info.TextColor3 = Color3.fromRGB(200, 200, 210)
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.Parent = box

    local speed = Instance.new("TextLabel")
    speed.Size = UDim2.new(1, 0, 0, 16)
    speed.Position = UDim2.new(0, 0, 0, 38)
    speed.BackgroundTransparency = 1
    speed.Text = "Speed: " .. tostring(CFG.Move.FlySpeed)
    speed.TextColor3 = Color3.fromRGB(255, 255, 255)
    speed.Font = Enum.Font.GothamBold
    speed.TextSize = 10
    speed.Name = "SpeedLabel"
    speed.Parent = box
end

local function startFly()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    if FlyActive then return end

    FlyActive = true
    hum.PlatformStand = true
    hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.Name = "MMV_FlyVel"
    FlyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    FlyBodyVelocity.Velocity = Vector3.zero
    FlyBodyVelocity.Parent = hrp

    FlyBodyGyro = Instance.new("BodyGyro")
    FlyBodyGyro.Name = "MMV_FlyGyro"
    FlyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    FlyBodyGyro.D = 50
    FlyBodyGyro.P = 3000
    FlyBodyGyro.CFrame = hrp.CFrame
    FlyBodyGyro.Parent = hrp

    buildFlyGui()

    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not FlyActive then conn:Disconnect(); return end
        local c = LP.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if not h or not FlyBodyVelocity then return end

        local camLook = Camera.CFrame.LookVector
        local camRight = Camera.CFrame.RightVector

        local move = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + camLook end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - camLook end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + camRight end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - camRight end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            move = move - Vector3.new(0, 1, 0)
        end

        if move.Magnitude > 0 then move = move.Unit * CFG.Move.FlySpeed end
        FlyBodyVelocity.Velocity = move
        FlyBodyGyro.CFrame = Camera.CFrame

        if FlyGui then
            local lbl = FlyGui:FindFirstChild("SpeedLabel", true)
            if lbl then lbl.Text = "Speed: " .. tostring(CFG.Move.FlySpeed) end
        end
    end)
    FlyConn = conn
end

local function stopFly()
    FlyActive = false
    if FlyConn then FlyConn:Disconnect(); FlyConn = nil end
    if FlyBodyVelocity then FlyBodyVelocity:Destroy(); FlyBodyVelocity = nil end
    if FlyBodyGyro then FlyBodyGyro:Destroy(); FlyBodyGyro = nil end
    if FlyGui then FlyGui:Destroy(); FlyGui = nil end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end
end

local function toggleFly(enabled)
    CFG.Move.FlyEnabled = enabled
    if enabled then startFly() else stopFly() end
end

-- ================= INFINITE JUMP =================
local function startInfiniteJump()
    if JumpConn then return end
    JumpConn = UIS.JumpRequest:Connect(function()
        if not CFG.Jump.Enabled then return end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function stopInfiniteJump()
    if JumpConn then JumpConn:Disconnect(); JumpConn = nil end
end

-- ================= TELEPORT =================
local function teleportToMurderer()
    local plr, hrp = getTarget()
    if not plr or not hrp then return end
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    myHRP.CFrame = hrp.CFrame * CFrame.new(CFG.Teleport.Offset)
    myHRP.Velocity = Vector3.zero
end

local function teleportToSpawn()
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local spawnPos = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            spawnPos = obj.Position + Vector3.new(0, 3, 0)
            break
        end
    end
    if not spawnPos then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "spawn", 1, true) then
                spawnPos = obj.Position + Vector3.new(0, 3, 0)
                break
            end
        end
    end
    if not spawnPos and LP.RespawnLocation then
        spawnPos = LP.RespawnLocation.Position + Vector3.new(0, 3, 0)
    end
    if not spawnPos then spawnPos = Vector3.new(0, 10, 0) end
    myHRP.CFrame = CFrame.new(spawnPos)
    myHRP.Velocity = Vector3.zero
end

-- ================= VISUALS =================
local function applyNight(enabled)
    if enabled then
        Lighting.ClockTime = 0
        Lighting.Brightness = 0.5
        Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 40)
        Lighting.Ambient = Color3.fromRGB(10, 10, 20)
    else
        Lighting.ClockTime = 14
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
    end
end

local function applyFog(enabled)
    if enabled then
        Lighting.FogEnd = 80
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.fromRGB(150, 150, 160)
    else
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.fromRGB(192, 192, 192)
    end
end

local FLOOR_NAME_HINTS = { "floor", "baseplate", "ground", "platform", "tile", "pavement", "road", "path" }
local NOT_FLOOR_NAME_HINTS = { "wall", "door", "window", "ceiling", "roof", "shelf", "table", "desk",
    "character", "humanoid", "tool", "weapon", "gun", "knife", "arm", "leg", "head" }

local function nameMatches(name, hints)
    local n = string.lower(name)
    for _, h in ipairs(hints) do
        if string.find(n, h, 1, true) then return true end
    end
    return false
end

local function isFloorPart(obj)
    if not obj:IsA("BasePart") then return false end
    if obj.Material == Enum.Material.Glass then return false end
    local model = obj:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then return false end
    if obj.Parent and (obj.Parent:IsA("Tool") or obj.Parent:IsA("Accessory")) then return false end
    if nameMatches(obj.Name, NOT_FLOOR_NAME_HINTS) then return false end
    if nameMatches(obj.Name, FLOOR_NAME_HINTS) then return true end
    local s = obj.Size
    if s.Y > math.min(s.X, s.Z) * 0.5 then return false end
    if obj.CFrame.UpVector.Y < 0.5 then return false end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and obj.Position.Y > hrp.Position.Y + 2 then return false end
    return true
end

local function collectFloorParts()
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isFloorPart(obj) then table.insert(list, obj) end
    end
    return list
end

local function applyGlossyFloor(enabled)
    if enabled then
        local function paint()
            for _, obj in ipairs(collectFloorParts()) do
                local already = false
                for _, d in ipairs(Visuals.GlossyParts) do
                    if d.part == obj then already = true break end
                end
                if not already then
                    table.insert(Visuals.GlossyParts, {
                        part = obj, material = obj.Material,
                        reflectance = obj.Reflectance, transparency = obj.Transparency,
                    })
                    obj.Material = Enum.Material.Glass
                    obj.Reflectance = 0.8
                    obj.Transparency = 0.2
                end
            end
        end
        paint()
        task.spawn(function()
            while CFG.Visuals.GlossyFloor do
                task.wait(2)
                if CFG.Visuals.GlossyFloor then paint() end
            end
        end)
    else
        for _, data in ipairs(Visuals.GlossyParts) do
            if data.part and data.part.Parent then
                data.part.Material = data.material
                data.part.Reflectance = data.reflectance
                data.part.Transparency = data.transparency
            end
        end
        Visuals.GlossyParts = {}
    end
end

local function applyColorCorrection(enabled)
    if enabled then
        if not Visuals.ColorCorrection then
            local cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "MMV_CC"
            cc.Brightness = 0.1; cc.Contrast = 0.2; cc.Saturation = 0.3
            cc.TintColor = Color3.fromRGB(255, 240, 220)
            cc.Parent = Lighting
            Visuals.ColorCorrection = cc
        end
    else
        if Visuals.ColorCorrection then Visuals.ColorCorrection:Destroy(); Visuals.ColorCorrection = nil end
    end
end

local function applyBlur(enabled)
    if enabled then
        if not Visuals.Blur then
            local b = Instance.new("BlurEffect")
            b.Name = "MMV_Blur"; b.Size = 8; b.Parent = Lighting
            Visuals.Blur = b
        end
    else
        if Visuals.Blur then Visuals.Blur:Destroy(); Visuals.Blur = nil end
    end
end

local function applyBloom(enabled)
    if enabled then
        if not Visuals.Bloom then
            local bl = Instance.new("BloomEffect")
            bl.Name = "MMV_Bloom"; bl.Intensity = 0.5; bl.Size = 24; bl.Threshold = 0.8
            bl.Parent = Lighting
            Visuals.Bloom = bl
        end
    else
        if Visuals.Bloom then Visuals.Bloom:Destroy(); Visuals.Bloom = nil end
    end
end

-- ================= WEAPON SKINS =================
local WEAPON_SKIN_ASSETS = {
    Knife = { MeshId = "rbxassetid://1279013", TextureId = "rbxassetid://1279012", Size = Vector3.new(0.5, 5, 0.5) },
    Blade = { MeshId = "rbxassetid://1279013", TextureId = "rbxassetid://1279012", Size = Vector3.new(0.5, 5, 0.5) },
    Gun = { MeshId = "rbxassetid://1279012", TextureId = "rbxassetid://1279012", Size = Vector3.new(1, 1.5, 2.5) },
    Revolver = { MeshId = "rbxassetid://1279012", TextureId = "rbxassetid://1279012", Size = Vector3.new(1, 1.5, 2.5) },
    Pistol = { MeshId = "rbxassetid://1279012", TextureId = "rbxassetid://1279012", Size = Vector3.new(1, 1.5, 2.5) },
}

local function findWeaponTools()
    local tools = {}
    local char = LP.Character
    local backpack = LP:FindFirstChild("Backpack")
    for _, container in ipairs({ char, backpack }) do
        if container then
            for _, obj in ipairs(container:GetChildren()) do
                if obj:IsA("Tool") and WEAPON_SKIN_ASSETS[obj.Name] then
                    table.insert(tools, obj)
                end
            end
        end
    end
    return tools
end

local function applySkinToTool(tool)
    local asset = WEAPON_SKIN_ASSETS[tool.Name]
    if not asset then return end
    local oldHandle = tool:FindFirstChild("Handle")
    if not oldHandle then return end
    if not Visuals.WeaponOriginalHandles[tool] then
        Visuals.WeaponOriginalHandles[tool] = oldHandle:Clone()
    end
    local newHandle = Instance.new("MeshPart")
    newHandle.Name = "Handle"
    newHandle.MeshId = asset.MeshId
    newHandle.TextureID = asset.TextureId
    newHandle.Size = asset.Size
    newHandle.Anchored = false
    newHandle.CanCollide = false
    newHandle.Massless = true
    newHandle.CFrame = oldHandle.CFrame
    oldHandle:Destroy()
    newHandle.Parent = tool
end

local function restoreToolHandle(tool)
    local original = Visuals.WeaponOriginalHandles[tool]
    if not original then return end
    local current = tool:FindFirstChild("Handle")
    if current then current:Destroy() end
    local restored = original:Clone()
    restored.Parent = tool
    Visuals.WeaponOriginalHandles[tool] = nil
end

local function applyWeaponSkins(enabled)
    if enabled then
        for _, tool in ipairs(findWeaponTools()) do applySkinToTool(tool) end
        if #Visuals.WeaponSkinConns == 0 then
            table.insert(Visuals.WeaponSkinConns, LP.CharacterAdded:Connect(function()
                task.wait(1)
                if CFG.Visuals.WeaponSkins then
                    for _, tool in ipairs(findWeaponTools()) do applySkinToTool(tool) end
                end
            end))
            table.insert(Visuals.WeaponSkinConns, LP.Backpack.ChildAdded:Connect(function(child)
                if CFG.Visuals.WeaponSkins and child:IsA("Tool") and WEAPON_SKIN_ASSETS[child.Name] then
                    task.wait(0.1)
                    applySkinToTool(child)
                end
            end))
        end
    else
        for _, conn in ipairs(Visuals.WeaponSkinConns) do conn:Disconnect() end
        Visuals.WeaponSkinConns = {}
        for tool in pairs(Visuals.WeaponOriginalHandles) do
            if tool and tool.Parent then restoreToolHandle(tool) end
        end
        Visuals.WeaponOriginalHandles = {}
    end
end

local function resetAllVisuals()
    applyNight(false); applyFog(false); applyGlossyFloor(false)
    applyColorCorrection(false); applyBlur(false); applyBloom(false)
    applyWeaponSkins(false)
    CFG.Visuals.Night = false; CFG.Visuals.Fog = false; CFG.Visuals.GlossyFloor = false
    CFG.Visuals.ColorCorrection = false; CFG.Visuals.Blur = false; CFG.Visuals.Bloom = false
    CFG.Visuals.WeaponSkins = false
end

-- ================= ANTI-FLING =================
-- Тела видимы как обычно, но CanTouch = false и CanCollide = false — ты проходишь сквозь них
local function processCharAntiFling(char)
    if not char or char == LP.Character then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanTouch = false
            part.CanCollide = false
        end
    end
end

local function startAntiFling()
    if AntiFlingConn then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then processCharAntiFling(p.Character) end
    end
    table.insert(AntiFlingConns, LP.CharacterAdded:Connect(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then processCharAntiFling(p.Character) end
        end
    end))
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            table.insert(AntiFlingConns, p.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                processCharAntiFling(char)
                char.DescendantAdded:Connect(function(d)
                    if d:IsA("BasePart") then
                        d.CanTouch = false
                        d.CanCollide = false
                    end
                end)
            end))
        end
    end
    table.insert(AntiFlingConns, Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            processCharAntiFling(char)
        end)
    end))
    AntiFlingConn = true
end

local function stopAntiFling()
    for _, c in ipairs(AntiFlingConns) do
        if c then c:Disconnect() end
    end
    AntiFlingConns = {}
    AntiFlingConn = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            for _, part in ipairs(p.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanTouch = true
                    part.CanCollide = true
                end
            end
        end
    end
end

-- ================= CUSTOM CURSOR =================
local CursorGui = nil
local CursorImage = nil
local CursorShadow = nil
local CursorGlow = nil
local CursorConn = nil

local CURSOR_ASSETS = {
    Dot = "rbxassetid://6031094667",
    Pentagram = "rbxassetid://51838212",
}

local function clearCursor()
    if CursorConn then CursorConn:Disconnect(); CursorConn = nil end
    if CursorGui then CursorGui:Destroy(); CursorGui = nil end
    CursorImage = nil
    CursorShadow = nil
    CursorGlow = nil
    UIS.MouseIconEnabled = true
end

local function applyCursor(mode)
    clearCursor()
    CFG.Cursor.Mode = mode
    if mode == "None" or mode == "" then return end
    local asset = CURSOR_ASSETS[mode]
    if not asset then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "MMV_Cursor"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 1000
    sg.Parent = LP:WaitForChild("PlayerGui")
    CursorGui = sg

    local glowColor = (mode == "Dot") and Color3.fromRGB(60, 140, 255) or Color3.fromRGB(255, 30, 30)
    local glow2Color = (mode == "Dot") and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(255, 60, 60)
    local mainColor = (mode == "Dot") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 30, 30)

    local glow = Instance.new("ImageLabel")
    glow.Name = "Glow"
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Size = UDim2.new(0, 40, 0, 40)
    glow.BackgroundTransparency = 1
    glow.Image = asset
    glow.ImageColor3 = glowColor
    glow.ImageTransparency = 0.75
    glow.ZIndex = 1000
    glow.Parent = sg
    CursorGlow = glow

    local glow2 = Instance.new("ImageLabel")
    glow2.Name = "Glow2"
    glow2.AnchorPoint = Vector2.new(0.5, 0.5)
    glow2.Size = UDim2.new(0, 24, 0, 24)
    glow2.BackgroundTransparency = 1
    glow2.Image = asset
    glow2.ImageColor3 = glow2Color
    glow2.ImageTransparency = 0.5
    glow2.ZIndex = 1001
    glow2.Parent = sg
    CursorShadow = glow2

    local img = Instance.new("ImageLabel")
    img.Name = "Cursor"
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Size = UDim2.new(0, 22, 0, 22)
    img.BackgroundTransparency = 1
    img.Image = asset
    img.ImageColor3 = mainColor
    img.ZIndex = 1002
    img.Parent = sg
    CursorImage = img

    UIS.MouseIconEnabled = false

    CursorConn = RunService.RenderStepped:Connect(function()
        if not CursorImage or not CursorImage.Parent then return end
        local pos = UIS:GetMouseLocation()
        CursorImage.Position = UDim2.fromOffset(pos.X, pos.Y)
        if CursorShadow then CursorShadow.Position = UDim2.fromOffset(pos.X, pos.Y) end
        if CursorGlow then
            local t = os.clock()
            local pulse = 1 + math.sin(t * 6) * 0.15
            CursorGlow.Size = UDim2.new(0, 40 * pulse, 0, 40 * pulse)
            CursorGlow.Position = UDim2.fromOffset(pos.X, pos.Y)
        end
    end)
end

-- ================= THEMES =================
local function clearThemeConn()
    if ThemeState.Conn then ThemeState.Conn:Disconnect(); ThemeState.Conn = nil end
end

local function applyDefaultTheme()
    if not ThemeState.Root then return end
    ThemeState.Root.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    for _, tb in pairs(ThemeState.Tabs) do
        if tb.Active then
            tb.Button.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
            tb.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            tb.Button.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
            tb.Button.TextColor3 = Color3.fromRGB(180, 180, 195)
        end
    end
    for _, s in ipairs(ThemeState.Sections) do s.TextLabel.TextColor3 = Color3.fromRGB(120, 160, 255) end
    for _, t in ipairs(ThemeState.Toggles) do
        if t.IsOn() then t.Button.BackgroundColor3 = Color3.fromRGB(70, 170, 90)
        else t.Button.BackgroundColor3 = Color3.fromRGB(55, 55, 65) end
        t.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    for _, b in ipairs(ThemeState.Buttons) do
        b.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    if ThemeState.Root:FindFirstChild("UIStroke") then ThemeState.Root.UIStroke.Color = Color3.fromRGB(60, 60, 75) end
    if ThemeState.Title then ThemeState.Title.TextColor3 = Color3.fromRGB(240, 240, 245) end
    for _, cf in ipairs(ThemeState.CornerFrames) do cf.Visible = false end
end

local function applyNeonRGBTheme()
    if not ThemeState.Root then return end
    clearThemeConn()
    ThemeState.Conn = RunService.Heartbeat:Connect(function()
        local t = tick()
        local r = math.floor((math.sin(t) * 0.5 + 0.5) * 200 + 55)
        local g = math.floor((math.sin(t + 2.094) * 0.5 + 0.5) * 200 + 55)
        local b = math.floor((math.sin(t + 4.188) * 0.5 + 0.5) * 200 + 55)
        local col = Color3.fromRGB(r, g, b)
        if ThemeState.Root then ThemeState.Root.BackgroundColor3 = Color3.fromRGB(r // 3, g // 3, b // 3) end
        for _, tb in pairs(ThemeState.Tabs) do
            if tb.Active then
                tb.Button.BackgroundColor3 = col
                tb.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                tb.Button.BackgroundColor3 = Color3.fromRGB(r // 3, g // 3, b // 3)
                tb.Button.TextColor3 = col
            end
        end
        for _, s in ipairs(ThemeState.Sections) do s.TextLabel.TextColor3 = col end
        for _, t in ipairs(ThemeState.Toggles) do
            if t.IsOn() then t.Button.BackgroundColor3 = col
            else t.Button.BackgroundColor3 = Color3.fromRGB(r // 2, g // 2, b // 2) end
            t.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        for _, b in ipairs(ThemeState.Buttons) do
            b.BackgroundColor3 = col
            b.TextColor3 = Color3.fromRGB(0, 0, 0)
        end
        if ThemeState.Root:FindFirstChild("UIStroke") then ThemeState.Root.UIStroke.Color = col end
        if ThemeState.Title then ThemeState.Title.TextColor3 = col end
    end)
end

local function applyDemonTheme()
    if not ThemeState.Root then return end
    clearThemeConn()
    ThemeState.Root.BackgroundColor3 = Color3.fromRGB(10, 5, 8)
    for _, tb in pairs(ThemeState.Tabs) do
        if tb.Active then
            tb.Button.BackgroundColor3 = Color3.fromRGB(140, 20, 25)
            tb.Button.TextColor3 = Color3.fromRGB(255, 200, 200)
        else
            tb.Button.BackgroundColor3 = Color3.fromRGB(30, 8, 12)
            tb.Button.TextColor3 = Color3.fromRGB(200, 100, 100)
        end
    end
    for _, s in ipairs(ThemeState.Sections) do s.TextLabel.TextColor3 = Color3.fromRGB(255, 80, 80) end
    for _, t in ipairs(ThemeState.Toggles) do
        if t.IsOn() then t.Button.BackgroundColor3 = Color3.fromRGB(140, 20, 25)
        else t.Button.BackgroundColor3 = Color3.fromRGB(40, 10, 15) end
        t.Button.TextColor3 = Color3.fromRGB(255, 220, 220)
    end
    for _, b in ipairs(ThemeState.Buttons) do
        b.BackgroundColor3 = Color3.fromRGB(160, 20, 25)
        b.TextColor3 = Color3.fromRGB(255, 240, 240)
    end
    if ThemeState.Root:FindFirstChild("UIStroke") then ThemeState.Root.UIStroke.Color = Color3.fromRGB(200, 30, 40) end
    if ThemeState.Title then ThemeState.Title.TextColor3 = Color3.fromRGB(255, 60, 60) end
    for _, cf in ipairs(ThemeState.CornerFrames) do cf.Visible = true end
    ThemeState.Conn = RunService.Heartbeat:Connect(function()
        local t = tick()
        local alpha = 0.5 + math.sin(t * 4) * 0.5
        for _, cf in ipairs(ThemeState.CornerFrames) do
            if cf.Parent then
                cf.BackgroundColor3 = Color3.fromRGB(200, 20, 30)
                cf.BackgroundTransparency = 1 - alpha
            end
        end
        if ThemeState.Root then
            ThemeState.Root.BackgroundColor3 = Color3.fromRGB(10 + math.floor(alpha * 10), 5, 8)
        end
    end)
end

local function applyTheme(mode)
    CFG.Theme.Mode = mode
    clearThemeConn()
    if mode == "Default" then applyDefaultTheme() end
    if mode == "NeonRGB" then applyNeonRGBTheme() end
    if mode == "Demon" then applyDemonTheme() end
end

-- ================= MAIN AIM LOOP =================
RunService.RenderStepped:Connect(function()
    pcall(tickFOV)
    pcall(tickSpeed)
    if not CFG.Aim.Enabled then return end
    local targetPlr, hrp = getTarget()
    if not hrp then return end
    local pos = getPredictedPos(hrp) or hrp.Position
    if not inFOV(pos) then return end
    local camPos = Camera.CFrame.Position
    if (pos - camPos).Magnitude > CFG.Aim.MaxDistance then return end

    if CFG.Aim.Silent then
        -- no-op
    else
        local desired = CFrame.new(camPos, pos)
        Camera.CFrame = Camera.CFrame:Lerp(desired, CFG.Aim.Smoothness)
    end

    if CFG.Aim.TriggerBot then
        local now = tick()
        if now - TriggerLastShot >= CFG.Aim.TriggerDelay then
            TriggerLastShot = now
            local char = LP.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if not tool then
                local backpack = LP:FindFirstChild("Backpack")
                if backpack then
                    for _, t in ipairs(backpack:GetChildren()) do
                        if t:IsA("Tool") and table.find(CFG.Weapons.Sheriff, t.Name) then
                            tool = t
                            break
                        end
                    end
                end
            end
            if tool and tool:IsA("Tool") then
                if CFG.Aim.Silent then silentAimShot(hrp) end
                pcall(function() tool:Activate() end)
            end
        end
    end
end)

-- ================= LOOPS =================
task.spawn(function()
    while task.wait(0.5) do pcall(refreshESP) end
end)

-- ================= MENU =================
local function buildMenu()
    local gui = Instance.new("ScreenGui")
    gui.Name = "demob_hub"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LP:WaitForChild("PlayerGui")
    ThemeState.Gui = gui

    local root = Instance.new("Frame")
    root.Size = UDim2.new(0, 1140, 0, 460)
    root.Position = UDim2.new(0.5, -570, 0.5, -230)
    root.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    root.BorderSizePixel = 0
    root.Active = true
    root.Parent = gui
    ThemeState.Root = root
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 10)
    rc.Parent = root
    local rs = Instance.new("UIStroke")
    rs.Name = "UIStroke"
    rs.Color = Color3.fromRGB(60, 60, 75)
    rs.Thickness = 1
    rs.Parent = root

    -- ==== BACKGROUND DEMON IMAGE ====
    local bgImage = Instance.new("ImageLabel")
    bgImage.Name = "BackgroundImage"
    bgImage.Size = UDim2.new(1, 0, 1, 0)
    bgImage.Position = UDim2.new(0, 0, 0, 0)
    bgImage.BackgroundTransparency = 1
    bgImage.Image = "rbxassetid://51838212"
    bgImage.ScaleType = Enum.ScaleType.Crop
    bgImage.ImageTransparency = 0.55
    bgImage.ZIndex = 1
    bgImage.Parent = root
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgImage

    local bgOverlay = Instance.new("Frame")
    bgOverlay.Name = "BackgroundOverlay"
    bgOverlay.Size = UDim2.new(1, 0, 1, 0)
    bgOverlay.Position = UDim2.new(0, 0, 0, 0)
    bgOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bgOverlay.BackgroundTransparency = 0.45
    bgOverlay.BorderSizePixel = 0
    bgOverlay.ZIndex = 2
    bgOverlay.Parent = root
    local bgCorner2 = Instance.new("UICorner")
    bgCorner2.CornerRadius = UDim.new(0, 10)
    bgCorner2.Parent = bgOverlay

    local function makeCorner(parent, ap, pos)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 20, 0, 20)
        f.Position = pos
        f.AnchorPoint = ap
        f.BackgroundColor3 = Color3.fromRGB(200, 20, 30)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.Visible = false
        f.ZIndex = 7
        f.Parent = parent
        table.insert(ThemeState.CornerFrames, f)
        return f
    end
    makeCorner(root, Vector2.new(0, 0), UDim2.new(0, 0, 0, 0))
    makeCorner(root, Vector2.new(1, 0), UDim2.new(1, 0, 0, 0))
    makeCorner(root, Vector2.new(0, 1), UDim2.new(0, 0, 1, 0))
    makeCorner(root, Vector2.new(1, 1), UDim2.new(1, 0, 1, 0))

    local dragging, dragStart, startPos
    root.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = root.Position
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -90, 0, 36)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "demob hub"
    title.TextColor3 = Color3.fromRGB(240, 240, 245)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.ZIndex = 6
    title.Parent = root
    ThemeState.Title = title

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.Position = UDim2.new(1, -60, 0, 5)
    minBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    minBtn.BorderSizePixel = 0
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.ZIndex = 6
    minBtn.Parent = root
    ThemeState.MinBtn = minBtn
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 6)
    mc.Parent = minBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -30, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.ZIndex = 6
    closeBtn.Parent = root
    ThemeState.CloseBtn = closeBtn
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 6)
    cc.Parent = closeBtn

    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -16, 0, 32)
    tabBar.Position = UDim2.new(0, 8, 0, 40)
    tabBar.BackgroundTransparency = 1
    tabBar.ZIndex = 5
    tabBar.Parent = root
    ThemeState.TabBar = tabBar
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 3)
    tabLayout.Parent = tabBar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -84)
    content.Position = UDim2.new(0, 8, 0, 78)
    content.BackgroundTransparency = 1
    content.ZIndex = 5
    content.Parent = root
    ThemeState.Content = content

    task.defer(function()
        for _, obj in ipairs(content:GetDescendants()) do
            if obj:IsA("GuiObject") then
                obj.ZIndex = (obj.ZIndex or 1) + 5
            end
        end
        for _, obj in ipairs(tabBar:GetChildren()) do
            if obj:IsA("GuiObject") then
                obj.ZIndex = 5
            end
        end
    end)

    local function section(parent, text)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 26)
        f.BackgroundTransparency = 1
        f.Parent = parent
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 1, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(120, 160, 255)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.GothamBold
        l.TextSize = 13
        l.Parent = f
        table.insert(ThemeState.Sections, { TextLabel = l })
    end

    local function toggle(parent, text, get, set)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 32)
        f.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        f.BackgroundTransparency = 0.15
        f.BorderSizePixel = 0
        f.Parent = parent
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -70, 1, 0)
        l.Position = UDim2.new(0, 12, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(225, 225, 235)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.Gotham
        l.TextSize = 13
        l.Parent = f
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 44, 0, 22)
        b.Position = UDim2.new(1, -56, 0.5, 0)
        b.AnchorPoint = Vector2.new(0, 0.5)
        b.BackgroundColor3 = get() and Color3.fromRGB(70, 170, 90) or Color3.fromRGB(55, 55, 65)
        b.BorderSizePixel = 0
        b.Text = get() and "ON" or "OFF"
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Parent = f
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = b
        local entry = { Button = b, Frame = f, IsOn = get }
        table.insert(ThemeState.Toggles, entry)
        b.MouseButton1Click:Connect(function()
            set(not get())
            b.Text = get() and "ON" or "OFF"
            if CFG.Theme.Mode == "Default" then
                b.BackgroundColor3 = get() and Color3.fromRGB(70, 170, 90) or Color3.fromRGB(55, 55, 65)
            end
        end)
    end

    local function slider(parent, text, min, max, get, set, suffix)
        suffix = suffix or ""
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 46)
        f.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        f.BackgroundTransparency = 0.15
        f.BorderSizePixel = 0
        f.Parent = parent
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 20)
        l.Position = UDim2.new(0, 12, 0, 2)
        l.BackgroundTransparency = 1
        l.Text = text .. ": " .. tostring(get()) .. suffix
        l.TextColor3 = Color3.fromRGB(225, 225, 235)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.Gotham
        l.TextSize = 12
        l.Parent = f
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -24, 0, 8)
        bar.Position = UDim2.new(0, 12, 0, 28)
        bar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        bar.BorderSizePixel = 0
        bar.Parent = f
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(1, 0)
        bc.Parent = bar
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((get() - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(90, 140, 255)
        fill.BorderSizePixel = 0
        fill.Parent = bar
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(1, 0)
        fc.Parent = fill
        local drag = false
        local function update(x)
            local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = math.floor(min + (max - min) * rel + 0.5)
            set(v)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            l.Text = text .. ": " .. v .. suffix
        end
        bar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; update(inp.Position.X) end
        end)
        bar.InputChanged:Connect(function(inp)
            if drag and inp.UserInputType == Enum.UserInputType.MouseMovement then update(inp.Position.X) end
        end)
        UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
        end)
    end

    local function colorRow(parent, text, get, set)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 32)
        f.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        f.BackgroundTransparency = 0.15
        f.BorderSizePixel = 0
        f.Parent = parent
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -70, 1, 0)
        l.Position = UDim2.new(0, 12, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(225, 225, 235)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = Enum.Font.Gotham
        l.TextSize = 13
        l.Parent = f
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 44, 0, 22)
        b.Position = UDim2.new(1, -56, 0.5, 0)
        b.AnchorPoint = Vector2.new(0, 0.5)
        b.BackgroundColor3 = get()
        b.BorderSizePixel = 0
        b.Text = ""
        b.Parent = f
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = b
        local palette = {
            Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 100, 255),
            Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(0, 255, 255),
            Color3.fromRGB(255, 165, 0), Color3.fromRGB(255, 255, 255),
        }
        local idx = 1
        for i, col in ipairs(palette) do
            if col == get() then idx = i break end
        end
        b.MouseButton1Click:Connect(function()
            idx = idx % #palette + 1
            local col = palette[idx]
            set(col)
            b.BackgroundColor3 = col
        end)
    end

    local function button(parent, text, cb)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, 34)
        f.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        f.BackgroundTransparency = 0.15
        f.BorderSizePixel = 0
        f.Parent = parent
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = f
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 26)
        b.Position = UDim2.new(0, 6, 0.5, 0)
        b.AnchorPoint = Vector2.new(0, 0.5)
        b.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.Parent = f
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = b
        table.insert(ThemeState.Buttons, b)
        b.MouseButton1Click:Connect(cb)
    end

    local pages, tabs = {}, {}

    local function makePage(name)
        local page = Instance.new("ScrollingFrame")
        page.Name = name
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = false
        page.Parent = content
        local pl = Instance.new("UIListLayout")
        pl.Padding = UDim.new(0, 6)
        pl.Parent = page
        pages[name] = page
        return page
    end

    local function makeTab(name)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 60, 1, 0)
        b.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        b.BorderSizePixel = 0
        b.Text = name
        b.TextColor3 = Color3.fromRGB(180, 180, 195)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.ZIndex = 5
        b.Parent = tabBar
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 5)
        bc.Parent = b
        local entry = { Button = b, Active = false }
        ThemeState.Tabs[name] = entry
        b.MouseButton1Click:Connect(function()
            for n, pg in pairs(pages) do pg.Visible = (n == name) end
            for n, tb in pairs(ThemeState.Tabs) do tb.Active = (n == name) end
            if CFG.Theme.Mode == "Default" then applyDefaultTheme() end
            if CFG.Theme.Mode == "NeonRGB" then applyNeonRGBTheme() end
            if CFG.Theme.Mode == "Demon" then applyDemonTheme() end
        end)
        tabs[name] = b
        return b
    end

    makeTab("ESP"); makeTab("Aimbot"); makeTab("Speed"); makeTab("Teleport"); makeTab("Visuals"); makeTab("Fling"); makeTab("Other")

    -- ESP PAGE
    local espPage = makePage("ESP")
    section(espPage, "ESP")
    toggle(espPage, "ESP Enabled", function() return CFG.ESP.Enabled end,
        function(v) CFG.ESP.Enabled = v; if not v then clearAllESP() end end)
    toggle(espPage, "Show Labels", function() return CFG.ESP.ShowLabels end,
        function(v) CFG.ESP.ShowLabels = v end)
    toggle(espPage, "Show Distance", function() return CFG.ESP.ShowDistance end,
        function(v) CFG.ESP.ShowDistance = v end)
    slider(espPage, "Fill Transparency", 0, 100,
        function() return math.floor(CFG.ESP.FillTransparency * 100) end,
        function(v) CFG.ESP.FillTransparency = v / 100 end, "%")
    colorRow(espPage, "Innocent Color", function() return CFG.ESP.InnocentColor end,
        function(v) CFG.ESP.InnocentColor = v end)
    colorRow(espPage, "Sheriff Color", function() return CFG.ESP.SheriffColor end,
        function(v) CFG.ESP.SheriffColor = v end)
    colorRow(espPage, "Murderer Color", function() return CFG.ESP.MurdererColor end,
        function(v) CFG.ESP.MurdererColor = v end)

    -- AIMBOT PAGE
    local aimPage = makePage("Aimbot")
    section(aimPage, "Aimbot")
    toggle(aimPage, "Aimbot Enabled", function() return CFG.Aim.Enabled end,
        function(v) CFG.Aim.Enabled = v end)
    toggle(aimPage, "Show FOV", function() return CFG.Aim.ShowFOV end,
        function(v) CFG.Aim.ShowFOV = v end)
    slider(aimPage, "FOV", 10, 360, function() return CFG.Aim.FOV end,
        function(v) CFG.Aim.FOV = v end, "°")
    slider(aimPage, "Smoothness", 1, 100,
        function() return math.floor(CFG.Aim.Smoothness * 100) end,
        function(v) CFG.Aim.Smoothness = v / 100 end, "%")
    slider(aimPage, "Max Distance", 50, 2000, function() return CFG.Aim.MaxDistance end,
        function(v) CFG.Aim.MaxDistance = v end, "m")
    colorRow(aimPage, "FOV Color", function() return CFG.Aim.FOVColor end,
        function(v) CFG.Aim.FOVColor = v end)

    section(aimPage, "Silent Aim")
    toggle(aimPage, "Silent Aim (no camera move)", function() return CFG.Aim.Silent end,
        function(v) CFG.Aim.Silent = v end)

    section(aimPage, "Prediction")
    slider(aimPage, "Prediction Time", 0, 150,
        function() return math.floor(CFG.Aim.Prediction * 100) end,
        function(v) CFG.Aim.Prediction = v / 100 end, " ×0.01s")

    section(aimPage, "Trigger Bot")
    toggle(aimPage, "Trigger Bot", function() return CFG.Aim.TriggerBot end,
        function(v) CFG.Aim.TriggerBot = v end)
    slider(aimPage, "Trigger Delay", 1, 100,
        function() return math.floor(CFG.Aim.TriggerDelay * 100) end,
        function(v) CFG.Aim.TriggerDelay = v / 100 end, " ×0.01s")

    -- SPEED PAGE
    local speedPage = makePage("Speed")
    section(speedPage, "Speed Glitch")
    toggle(speedPage, "Air Speed Enabled", function() return CFG.Speed.Enabled end,
        function(v)
            CFG.Speed.Enabled = v
            if not v then
                local char = LP.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16 end
            end
        end)
    slider(speedPage, "Air Speed", 16, 200, function() return CFG.Speed.AirSpeed end,
        function(v) CFG.Speed.AirSpeed = v end, " sps")

    -- TELEPORT PAGE
    local tpPage = makePage("Teleport")
    section(tpPage, "Teleport")
    button(tpPage, "Teleport to Murderer", function() teleportToMurderer() end)
    button(tpPage, "Teleport to Spawn", function() teleportToSpawn() end)

    -- VISUALS PAGE
    local visualPage = makePage("Visuals")
    section(visualPage, "Visual Effects")
    toggle(visualPage, "Night Mode", function() return CFG.Visuals.Night end,
        function(v) CFG.Visuals.Night = v; applyNight(v) end)
    toggle(visualPage, "Fog", function() return CFG.Visuals.Fog end,
        function(v) CFG.Visuals.Fog = v; applyFog(v) end)
    toggle(visualPage, "Glossy Floor", function() return CFG.Visuals.GlossyFloor end,
        function(v) CFG.Visuals.GlossyFloor = v; applyGlossyFloor(v) end)
    toggle(visualPage, "Color Correction", function() return CFG.Visuals.ColorCorrection end,
        function(v) CFG.Visuals.ColorCorrection = v; applyColorCorrection(v) end)
    toggle(visualPage, "Blur", function() return CFG.Visuals.Blur end,
        function(v) CFG.Visuals.Blur = v; applyBlur(v) end)
    toggle(visualPage, "Bloom", function() return CFG.Visuals.Bloom end,
        function(v) CFG.Visuals.Bloom = v; applyBloom(v) end)

    section(visualPage, "Weapon Skins")
    toggle(visualPage, "Knife → Sword / Gun → Revolver", function() return CFG.Visuals.WeaponSkins end,
        function(v) CFG.Visuals.WeaponSkins = v; applyWeaponSkins(v) end)

    section(visualPage, "Reset")
    button(visualPage, "Reset All Visuals", function() resetAllVisuals() end)

    -- FLING PAGE (Anti-Fling + кнопка запуска внешнего fling-скрипта)
    local flingPage = makePage("Fling")
    section(flingPage, "Anti-Fling")
    toggle(flingPage, "Anti-Fling (pass through bodies, still visible)", function() return CFG.Fling.AntiFling end,
        function(v)
            CFG.Fling.AntiFling = v
            if v then startAntiFling() else stopAntiFling() end
        end)
    button(flingPage, "Reset Anti-Fling", function()
        stopAntiFling()
        CFG.Fling.AntiFling = false
    end)

    section(flingPage, "Fling Script")
    button(flingPage, "Open Fling GUI (loadstring)", function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/K1LAS1K/Ultimate-Fling-GUI/main/flingscript.lua"))()
        end)
        if not ok then
            warn("[demob hub] fling load failed: " .. tostring(err))
        end
    end)

    -- OTHER PAGE
    local otherPage = makePage("Other")

    section(otherPage, "Movement")
    toggle(otherPage, "WalkSpeed Enable", function() return CFG.Move.WalkEnabled end,
        function(v)
            CFG.Move.WalkEnabled = v
            if v then applyWalkSpeed()
            else
                local char = LP.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16 end
            end
        end)
    slider(otherPage, "WalkSpeed", 1, 70,
        function() return CFG.Move.WalkSpeed end,
        function(v) CFG.Move.WalkSpeed = v; if CFG.Move.WalkEnabled then applyWalkSpeed() end end, " sps")

    toggle(otherPage, "JumpPower Enable", function() return CFG.Move.JumpEnabled end,
        function(v) CFG.Move.JumpEnabled = v; if v then applyJump() end end)
    slider(otherPage, "JumpPower", 1, 100,
        function() return CFG.Move.JumpValue end,
        function(v) CFG.Move.JumpValue = v; if CFG.Move.JumpEnabled then applyJump() end end, "")

    toggle(otherPage, "Fly Enable (camera dir)", function() return CFG.Move.FlyEnabled end,
        function(v) toggleFly(v) end)
    slider(otherPage, "Fly Speed", 1, 70,
        function() return CFG.Move.FlySpeed end,
        function(v) CFG.Move.FlySpeed = v end, " sps")

    section(otherPage, "Infinite Jump")
    toggle(otherPage, "Infinite Jump", function() return CFG.Jump.Enabled end,
        function(v) CFG.Jump.Enabled = v; if v then startInfiniteJump() else stopInfiniteJump() end end)

    section(otherPage, "Cursor")
    local cursorRow = Instance.new("Frame")
    cursorRow.Size = UDim2.new(1, 0, 0, 32)
    cursorRow.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    cursorRow.BackgroundTransparency = 0.15
    cursorRow.BorderSizePixel = 0
    cursorRow.Parent = otherPage
    local crc = Instance.new("UICorner")
    crc.CornerRadius = UDim.new(0, 6)
    crc.Parent = cursorRow
    local cl = Instance.new("TextLabel")
    cl.Size = UDim2.new(1, -70, 1, 0)
    cl.Position = UDim2.new(0, 12, 0, 0)
    cl.BackgroundTransparency = 1
    cl.Text = "Cursor: " .. CFG.Cursor.Mode
    cl.TextColor3 = Color3.fromRGB(225, 225, 235)
    cl.TextXAlignment = Enum.TextXAlignment.Left
    cl.Font = Enum.Font.Gotham
    cl.TextSize = 13
    cl.Parent = cursorRow
    local cursorBtn = Instance.new("TextButton")
    cursorBtn.Size = UDim2.new(0, 90, 0, 22)
    cursorBtn.Position = UDim2.new(1, -100, 0.5, 0)
    cursorBtn.AnchorPoint = Vector2.new(0, 0.5)
    cursorBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    cursorBtn.BorderSizePixel = 0
    cursorBtn.Text = "Change"
    cursorBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cursorBtn.Font = Enum.Font.GothamBold
    cursorBtn.TextSize = 11
    cursorBtn.Parent = cursorRow
    local cbc = Instance.new("UICorner")
    cbc.CornerRadius = UDim.new(0, 5)
    cbc.Parent = cursorBtn
    table.insert(ThemeState.Buttons, cursorBtn)

    local cursorOrder = { "None", "Dot", "Pentagram" }
    local cursorLabelText = { None = "None", Dot = "Glowing Dot", Pentagram = "Red Demon Star" }
    local cursorIdx = 1
    for i, m in ipairs(cursorOrder) do
        if m == CFG.Cursor.Mode then cursorIdx = i break end
    end
    cl.Text = "Cursor: " .. cursorLabelText[cursorOrder[cursorIdx]]
    cursorBtn.MouseButton1Click:Connect(function()
        cursorIdx = cursorIdx % #cursorOrder + 1
        local m = cursorOrder[cursorIdx]
        applyCursor(m)
        cl.Text = "Cursor: " .. cursorLabelText[m]
    end)

    button(otherPage, "Reset Cursor", function()
        applyCursor("None")
        cursorIdx = 1
        cl.Text = "Cursor: None"
    end)

    -- THEME
    section(otherPage, "Menu Theme")
    local themeRow = Instance.new("Frame")
    themeRow.Size = UDim2.new(1, 0, 0, 32)
    themeRow.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    themeRow.BackgroundTransparency = 0.15
    themeRow.BorderSizePixel = 0
    themeRow.Parent = otherPage
    local trc = Instance.new("UICorner")
    trc.CornerRadius = UDim.new(0, 6)
    trc.Parent = themeRow
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -70, 1, 0)
    tl.Position = UDim2.new(0, 12, 0, 0)
    tl.BackgroundTransparency = 1
    tl.Text = "Theme: " .. CFG.Theme.Mode
    tl.TextColor3 = Color3.fromRGB(225, 225, 235)
    tl.TextXAlignment = Enum.TextXAlignment.Left
Содержание документа слишком длинное для полного отображения
