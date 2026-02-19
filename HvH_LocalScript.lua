--[[
    HvH Game Mode - LocalScript
    Port of open-source HvH features adapted for legitimate in-game use.
    Drop into StarterPlayerScripts — every player gets equal tools on join.

    Features ported:
    - Ragebot (auto-fire with wall check, hitbox selection, smart aim)
    - AI Prediction (track / strafe / peek detection)
    - Resolver (Safe / Aggressive, flip-on-miss)
    - Ghost Peek (finds cover position, shoots from it)
    - AI Peek v4 (radial point system, moves to best angle)
    - Fakeduck (crouch anti-aim animation)
    - Double Tap (quick teleport peek)
    - Bunnyhop (ground/air speed control)
    - Chams / ESP (Highlight instances)
    - Hitmarker (RESOLVED popup)
    - Kill Effect (neon particle burst)
    - Fortnite Damage numbers
    - Hit Logger (console-style log)
    - Anim Breaker
    - Aimview line
    - Visual FX (Bloom, Color Correction, Sun Rays, Fog)
    - Full UI (5 tabs: Rage / AA / Visuals / Exploits / Settings)

    NOTE: In Studio, CoreGui is blocked. The script auto-falls back to
    PlayerGui. This is expected. Works fully in a published game.
]]

-- ============================================================
-- INIT
-- ============================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")
local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")

local Player = Players.LocalPlayer
if not Player then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    Player = Players.LocalPlayer
end

local PlayerGui = Player:WaitForChild("PlayerGui", 10)
local Camera    = workspace.CurrentCamera

-- Safe CoreGui parent (Studio blocks direct CoreGui writes)
local guiParent
local ok = pcall(function()
    local t = Instance.new("ScreenGui")
    t.Parent = CoreGui
    t:Destroy()
    guiParent = CoreGui
end)
if not ok then
    guiParent = PlayerGui
    warn("[HvH] Studio mode: using PlayerGui instead of CoreGui")
end

-- ============================================================
-- MATH ALIASES
-- ============================================================
local FLOOR = math.floor
local CLAMP = math.clamp
local TICK  = tick
local ABS   = math.abs
local MAX   = math.max
local MIN   = math.min
local CEIL  = math.ceil
local HUGE  = math.huge
local SQRT  = math.sqrt
local COS   = math.cos
local SIN   = math.sin
local RAD   = math.rad
local V3    = Vector3.new
local V3_0  = Vector3.zero

-- ============================================================
-- SETTINGS
-- ============================================================
local S = {
    menuKey        = Enum.KeyCode.RightControl,

    -- Ragebot
    rbEnabled      = false,
    rbAutoFire     = true,
    rbTeamCheck    = true,
    rbHitbox       = "Head",
    rbMaxDist      = 500,
    rbWallCheck    = true,
    rbNoAir        = true,
    rbSmartAim     = true,
    rbAirShoot     = false,
    rbBodyAimHP    = 50,
    rbPredMode     = "Default",  -- "Default" | "Beta AI"

    -- Resolver
    rbResolver     = false,
    rbResolverMode = "Safe",     -- "Safe" | "Aggressive"

    -- AI Prediction
    aiHistorySize  = 30,
    aiConfThreshold = 60,
    aiPeekDetect   = true,
    aiStrafeDetect = true,
    aiVisualBox    = false,
    aiVisualTrace  = false,

    -- Ghost Peek
    gpEnabled      = false,
    gpKey          = Enum.KeyCode.Q,
    gpMode         = "Hold",
    gpRange        = 100,
    gpPeekDist     = 8,
    gpHeight       = 3,
    gpQuality      = 50,
    gpTeamCheck    = true,
    gpAutoshoot    = true,

    -- AI Peek v4
    apEnabled      = false,
    apKey          = Enum.KeyCode.LeftAlt,
    apMode         = "Hold",
    apShowPoints   = false,
    apESP          = false,
    apTeamCheck    = true,
    apCooldown     = 0.1,
    apRange        = 80,
    apPeekDist     = 8,
    apSpeed        = 200,
    apHeight       = 2.0,

    -- Fakeduck
    fdEnabled      = false,
    fdKey          = Enum.KeyCode.X,
    fdLockKey      = Enum.KeyCode.V,
    fdTeamCheck    = true,

    -- Double Tap
    dtEnabled      = false,
    dtKey          = Enum.KeyCode.E,
    dtDist         = 6,
    dtAuto         = false,
    dtAutoDelay    = 200,

    -- Bunnyhop
    bhEnabled      = false,
    bhKey          = Enum.KeyCode.F,
    bhGroundSpeed  = 35,
    bhAirSpeed     = 39,

    -- Chams
    Chams          = false,
    ChamsColor     = Color3.fromRGB(255, 50, 50),
    ChamsOpacity   = 0.5,

    -- Third Person
    ThirdPerson    = false,

    -- Visuals
    hmEnabled      = true,
    hmColor        = Color3.fromRGB(168, 247, 50),
    keEnabled      = true,
    keColor        = Color3.fromRGB(255, 255, 255),
    fdmgEnabled    = true,
    fdmgColor      = Color3.fromRGB(255, 255, 255),
    hlEnabled      = true,
    hlMaxLogs      = 8,
    avEnabled      = false,
    avColor        = Color3.fromRGB(255, 0, 0),
    avTransparency = 0.3,

    -- FX
    bloomEnabled   = false,
    bloomIntensity = 1.5,
    bloomSize      = 40,
    bloomThreshold = 0.7,
    colorEnabled   = false,
    ccBrightness   = 0,
    ccContrast     = 0.1,
    ccSaturation   = 0.2,
    sunRaysEnabled = false,
    fogEnabled     = false,
    fogEnd         = 500,

    -- Anim Breaker
    abEnabled      = false,
    abKey          = Enum.KeyCode.B,

    -- Anti-Aim (Yaw)
    aaEnabled      = false,
    aaKey          = Enum.KeyCode.Z,
    aaYawType      = "Spin",       -- "Spin" | "Jitter" | "Static" | "Sway" | "Random"
    aaYawAngle     = 180,          -- static offset degrees
    aaSpinSpeed    = 180,          -- degrees/sec for spin
    aaJitterRange  = 60,           -- degrees left/right for jitter
    aaSway         = false,        -- slow side-to-side
    aaSwaySpeed    = 0.6,
    aaSwayRange    = 30,

    -- Anti-Aim (Pitch)
    aaPitchType    = "None",       -- "None" | "Up" | "Down" | "LookUp" | "LookDown"

    -- Anti-Aim (Roll)
    aaRollEnabled  = false,
    aaRollType     = "Spin",       -- "Spin" | "Tilt" | "Static"
    aaRollAngle    = 90,
    aaRollSpeed    = 120,

    -- Desync (extend anti-aim further without breaking movement)
    aaDesyncEnabled = false,
    aaDesyncKey    = Enum.KeyCode.Z,  -- manual desync flip key
    aaDesyncAmount  = 58,             -- degrees (keep < 60 to avoid sv detection)

    -- Jitter AA
    aaJitterEnabled = false,
    aaJitterKey    = Enum.KeyCode.Z,

    -- Slow Walk (while AA active, slow to reduce hit chance)
    aaSlowWalkEnabled = false,
    aaSlowWalkSpeed   = 6,
}

-- ============================================================
-- RUNTIME STATE
-- ============================================================
local R = {
    running      = true,
    visible      = true,
    gui          = nil,
    conns        = {},
    fx           = {},
    hotkeys      = {},

    myChar = nil, myHRP = nil, myHead = nil, myHum = nil,
    cam    = nil,

    fireShot     = nil,
    fireShotTime = 0,

    playerData     = {},
    playerDataTime = 0,

    -- Ragebot
    rbLast = 0,

    -- Bunnyhop
    bhInAir      = false,
    bhLastReset  = 0,
    bhResetting  = false,
    bhOrigSpeed  = 16,
    bhLastPos    = nil,
    bhCircling   = false,
    bhPosCheckTime = 0,

    -- Fakeduck
    fdTarget     = nil,
    fdCrouch     = false,
    fdLock       = false,
    fdIdleAnim   = nil,
    fdWalkAnim   = nil,

    -- Double Tap
    dtLastPeek  = 0,
    dtAutoLast  = 0,

    -- Ghost Peek
    gpActive    = false,
    gpInPeek    = false,
    gpLastShot  = 0,

    -- AI Peek v4
    apActive        = false,
    apTeleporting   = false,
    apLastTP        = 0,
    apPoints        = {},
    apPointCount    = 0,

    -- Visuals
    hlFrame      = nil,
    hlLogIndex   = 0,
    avLine       = nil,
    bloomEffect  = nil,
    colorEffect  = nil,
    sunEffect    = nil,

    -- Anim Breaker
    abActive = false,
    abConn   = nil,

    -- Main loop conn
    mainConn = nil,

    -- Chams
    sliderDrag = nil,
}

-- Hit timing
local lastHitTime  = 0
local lastKillTime = 0
local lastMissTime = 0
local pendingShots = {}
local confirmedShots = {}
local lastShotByTarget = {}
local lastShotTarget = nil
local lastShotHitbox = nil
local lastShotTime_g = 0
local trackedEnemies = {}

-- Hitmarker / kill effect cooldowns
local lastHitmarkerTime = 0
local lastKillEffectTime = 0
local lastHitSoundTime   = 0
local EFFECT_CD = 1.5

-- RaycastParams
local RayP = RaycastParams.new()
RayP.FilterType = Enum.RaycastFilterType.Exclude
local APRayP = RaycastParams.new()
APRayP.FilterType = Enum.RaycastFilterType.Exclude

-- Highlights
local Highlights = {}

-- ============================================================
-- FORWARD DECLARATIONS
-- ============================================================
local UpdateHotkeyList, ApplySettings, AddHitLog, TrackShot, SetupKillTracking

-- ============================================================
-- UTILITY
-- ============================================================
local function CacheChar()
    local c = Player.Character
    if c then
        R.myChar = c
        R.myHRP  = c:FindFirstChild("HumanoidRootPart")
        R.myHead = c:FindFirstChild("Head")
        R.myHum  = c:FindFirstChildOfClass("Humanoid")
    else
        R.myChar, R.myHRP, R.myHead, R.myHum = nil,nil,nil,nil
    end
    R.cam = workspace.CurrentCamera
end

local PLAYER_CACHE_INTERVAL = 0.2
local function UpdatePlayerData()
    local now = TICK()
    if now - R.playerDataTime < PLAYER_CACHE_INTERVAL then return end
    R.playerDataTime = now
    if not R.myHRP then return end

    local myPos   = R.myHRP.Position
    local myTeam  = Player.Team
    local myColor = Player.TeamColor
    local count   = 0

    for i = 1, 16 do R.playerData[i] = nil end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            local c = p.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                local rp = c:FindFirstChild("HumanoidRootPart")
                if h and h.Health > 0 and rp then
                    local dist = (myPos - rp.Position).Magnitude
                    if dist < 600 then
                        count += 1
                        local isTeam = myTeam and (p.Team == myTeam or p.TeamColor == myColor)
                        R.playerData[count] = {
                            p    = p,
                            c    = c,
                            h    = h,
                            r    = rp,
                            head = c:FindFirstChild("Head"),
                            torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"),
                            dist = dist,
                            team = isTeam,
                            vel  = rp.AssemblyLinearVelocity,
                        }
                    end
                end
            end
        end
    end
    -- sort by distance
    for i = 2, count do
        local key = R.playerData[i]
        local j = i - 1
        while j >= 1 and R.playerData[j] and R.playerData[j].dist > key.dist do
            R.playerData[j+1] = R.playerData[j]
            j -= 1
        end
        R.playerData[j+1] = key
    end
end

local function GetFireShot()
    local now = TICK()
    if R.fireShot and R.fireShot.Parent and now - R.fireShotTime < 5 then return R.fireShot end
    if not R.myChar then CacheChar() end
    if not R.myChar then return nil end
    for _, child in ipairs(R.myChar:GetChildren()) do
        if child:IsA("Tool") then
            local remotes = child:FindFirstChild("Remotes")
            if remotes then
                local fs = remotes:FindFirstChild("FireShot") or remotes:FindFirstChild("fireShot")
                if fs then
                    R.fireShot, R.fireShotTime = fs, now
                    return fs
                end
            end
        end
    end
    return nil
end

-- ============================================================
-- CHAMS
-- ============================================================
local function UpdateChams()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            if S.Chams then
                if not Highlights[p] then
                    local h = Instance.new("Highlight")
                    h.Adornee        = p.Character
                    h.FillColor       = S.ChamsColor
                    h.OutlineColor    = S.ChamsColor
                    h.FillTransparency = S.ChamsOpacity
                    h.DepthMode       = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Parent          = p.Character
                    Highlights[p]     = h
                else
                    Highlights[p].FillColor        = S.ChamsColor
                    Highlights[p].OutlineColor     = S.ChamsColor
                    Highlights[p].FillTransparency = S.ChamsOpacity
                end
            else
                if Highlights[p] then
                    Highlights[p]:Destroy()
                    Highlights[p] = nil
                end
            end
        end
    end
end

Players.PlayerRemoving:Connect(function(p)
    if Highlights[p] then Highlights[p]:Destroy() end
    Highlights[p] = nil
end)

-- ============================================================
-- AI PREDICTION
-- ============================================================
local AI_PRED = {
    history          = {},
    patterns         = {},
    HISTORY_SIZE     = 30,
    PEEK_THRESHOLD   = 15,
    STRAFE_THRESHOLD = 8,
}

local function AI_AddHistory(name, pos, vel, t)
    if not AI_PRED.history[name] then AI_PRED.history[name] = {} end
    local h = AI_PRED.history[name]
    table.insert(h, {pos=pos, vel=vel, time=t})
    while #h > AI_PRED.HISTORY_SIZE do table.remove(h,1) end
end

local function AI_AnalyzePattern(name)
    local h = AI_PRED.history[name]
    if not h or #h < 10 then return nil end
    local pattern = {isPeeking=false,isStrafing=false,peekDirection=nil,strafeDirection=nil,avgSpeed=0,directionChanges=0,confidence=0}
    local totalSpeed, dirChanges, lastDir = 0, 0, nil
    for i = 2, #h do
        local prev,curr = h[i-1],h[i]
        local moveDir = (curr.pos - prev.pos).Unit
        local speed   = (curr.pos - prev.pos).Magnitude / MAX(0.001, curr.time - prev.time)
        totalSpeed += speed
        if lastDir then
            if moveDir:Dot(lastDir) < 0.5 then dirChanges += 1 end
        end
        lastDir = moveDir
    end
    pattern.avgSpeed = totalSpeed / (#h-1)
    pattern.directionChanges = dirChanges
    if #h >= 5 then
        local velChange = (h[#h].vel - h[#h-4].vel).Magnitude
        if velChange > AI_PRED.PEEK_THRESHOLD then
            pattern.isPeeking    = true
            pattern.peekDirection = h[#h].vel.Unit
            pattern.confidence   = MIN(1, velChange/30)
        end
    end
    if dirChanges >= 3 and pattern.avgSpeed > 5 then
        pattern.isStrafing     = true
        local lv = h[#h].vel
        pattern.strafeDirection = V3(-lv.X,0,-lv.Z).Unit
        pattern.confidence     = MIN(1, dirChanges/6)
    end
    AI_PRED.patterns[name] = pattern
    return pattern
end

local function AI_PredictPosition(name, curPos, curVel, predTime)
    local pattern = AI_PRED.patterns[name]
    local h       = AI_PRED.history[name]
    local predicted = curPos + curVel * predTime
    if not pattern or not h or #h < 5 then return predicted, 0.5 end
    if pattern.isPeeking and pattern.peekDirection then
        return curPos + pattern.peekDirection * (pattern.avgSpeed * predTime * 1.5), pattern.confidence
    end
    if pattern.isStrafing and pattern.strafeDirection then
        return curPos + pattern.strafeDirection * (pattern.avgSpeed * predTime * 0.5), pattern.confidence
    end
    if #h >= 10 then
        local sumVel = V3_0
        for i = #h-9, #h do sumVel += h[i].vel end
        local avgVel = sumVel/10
        return curPos + (curVel*0.7 + avgVel*0.3)*predTime, 0.7
    end
    return predicted, 0.5
end

local function AI_GetBestPrediction(name, headPos, vel, ping)
    AI_AddHistory(name, headPos, vel, TICK())
    AI_AnalyzePattern(name)
    local predicted, confidence = AI_PredictPosition(name, headPos, vel, ping * 1.2)
    local pattern = AI_PRED.patterns[name]
    local mode = "TRACK"
    if pattern then
        if pattern.isStrafing then mode = "STRAFE"
        elseif pattern.isPeeking then mode = "PEEK" end
    end
    return predicted, confidence, mode
end

-- ============================================================
-- RESOLVER
-- ============================================================
local ResolverData = {}
local MissHistory  = {}

local Resolver = {}
function Resolver.RegisterMiss(p) MissHistory[p] = (MissHistory[p] or 0) + 1 end
function Resolver.RegisterHit(p)  MissHistory[p] = 0 end

local function ResolveYaw(p, head)
    if not S.rbResolver then return head.Position end
    local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return head.Position end
    local data = ResolverData[p]
    if not data then
        ResolverData[p] = {
            lastYaw   = math.deg(select(2, hrp.CFrame:ToEulerAnglesYXZ())),
            flipState = false,
        }
        return head.Position
    end
    local curYaw = math.deg(select(2, hrp.CFrame:ToEulerAnglesYXZ()))
    local delta  = curYaw - data.lastYaw
    if delta >  180 then delta -= 360 end
    if delta < -180 then delta += 360 end
    data.lastYaw = curYaw

    local offset = 0
    local misses = MissHistory[p] or 0
    local abs = ABS(delta)

    if S.rbResolverMode == "Safe" then
        if abs > 40 then
            offset = 0             -- spinning, can't predict
        elseif abs > 8 then
            offset = -delta * 0.5  -- jitter, average
        else
            if misses > 2 then data.flipState = not data.flipState MissHistory[p] = 0 end
            offset = data.flipState and 180 or 0
        end
    else
        -- Aggressive: always flip
        offset = 180
    end

    local corrected = hrp.CFrame * CFrame.Angles(0, RAD(offset), 0)
    return corrected.Position + V3(0, 2.5, 0)
end

-- ============================================================
-- HIT LOGGER / HITMARKER / KILL EFFECT / DAMAGE NUMBERS
-- ============================================================
local function ShowHitmarker(position, text)
    if not S.hmEnabled then return end
    local now = TICK()
    if now - lastHitmarkerTime < EFFECT_CD then return end
    lastHitmarkerTime = now

    local part = Instance.new("Part")
    part.Anchored, part.CanCollide, part.Transparency = true, false, 1
    part.Size, part.Position = V3(0.1,0.1,0.1), position + V3(0,3,0)
    part.Parent = workspace

    local bb = Instance.new("BillboardGui", part)
    bb.Size, bb.StudsOffset, bb.AlwaysOnTop = UDim2.new(0,300,0,80), V3(0,5,0), true
    bb.Adornee = part

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size, lbl.BackgroundTransparency = UDim2.new(1,0,1,0), 1
    lbl.Text, lbl.TextColor3 = text or "RESOLVED", S.hmColor
    lbl.TextStrokeColor3, lbl.TextStrokeTransparency = Color3.new(0,0,0), 0
    lbl.Font, lbl.TextSize = Enum.Font.GothamBlack, 36

    task.spawn(function()
        for i = 1, 20 do
            task.wait(0.03)
            part.Position += V3(0, 0.12, 0)
            lbl.TextTransparency = i/20
            lbl.TextStrokeTransparency = i/20
        end
        part:Destroy()
    end)
end

local function ShowKillEffect(pos)
    if not S.keEnabled then return end
    local now = TICK()
    if now - lastKillEffectTime < EFFECT_CD then return end
    lastKillEffectTime = now

    local ball = Instance.new("Part", workspace)
    ball.Shape, ball.Anchored, ball.CanCollide = Enum.PartType.Ball, true, false
    ball.Material, ball.Color = Enum.Material.Neon, S.keColor
    ball.Size, ball.Position = V3(0.5,0.5,0.5), pos
    local light = Instance.new("PointLight", ball)
    light.Color, light.Brightness, light.Range = S.keColor, 10, 25

    local particles = {}
    for i = 1,6 do
        local p = Instance.new("Part", workspace)
        p.Shape, p.Anchored, p.CanCollide = Enum.PartType.Ball, true, false
        p.Material, p.Color = Enum.Material.Neon, S.keColor
        p.Size, p.Position = V3(0.2,0.2,0.2), pos
        local th = RAD(i*60)
        particles[i] = {part=p, dir=V3(COS(th),0.3,SIN(th)).Unit, speed=0.8+math.random()*0.6}
    end

    task.spawn(function()
        for i = 1, 18 do
            task.wait(0.025)
            local t = i/18
            local sz = 3.5 * (1-t*0.8)
            ball.Size = V3(sz,sz,sz)
            ball.Transparency = t*0.9
            light.Brightness = 25*(1-t)
            for _, d in ipairs(particles) do
                local dist = t*12*d.speed
                d.part.Position = pos + d.dir*dist
                local ps = 0.2*(1-t*0.7)
                d.part.Size = V3(ps,ps,ps)
                d.part.Transparency = t*0.9
            end
        end
        ball:Destroy()
        for _, d in ipairs(particles) do d.part:Destroy() end
    end)
end

local function ShowFortniteDamage(pos, damage)
    if not S.fdmgEnabled or not damage or damage <= 0 then return end
    local part = Instance.new("Part", workspace)
    part.Anchored, part.CanCollide, part.Transparency = true, false, 1
    part.Size, part.Position = V3(0.1,0.1,0.1), pos + V3(0,1.5,0)
    local bb = Instance.new("BillboardGui", part)
    bb.Size, bb.AlwaysOnTop = UDim2.new(0,100,0,40), true
    bb.Adornee = part
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size, lbl.BackgroundTransparency = UDim2.new(1,0,1,0), 1
    lbl.Text, lbl.TextColor3 = tostring(damage), S.fdmgColor
    lbl.TextStrokeColor3, lbl.TextStrokeTransparency = Color3.new(0,0,0), 0
    lbl.Font, lbl.TextSize = Enum.Font.GothamBlack, 28

    task.spawn(function()
        local startY = part.Position.Y
        for i = 1, 20 do
            task.wait(0.035)
            local t = i/20
            part.Position = V3(part.Position.X, startY + t*2.5, part.Position.Z)
            if t > 0.6 then
                local ft = (t-0.6)/0.4
                lbl.TextTransparency = ft
                lbl.TextStrokeTransparency = ft
            end
        end
        part:Destroy()
    end)
end

local function CreateHitLogger()
    if R.hlFrame then pcall(function() R.hlFrame:Destroy() end) end
    if not R.gui then return end
    local f = Instance.new("Frame", R.gui)
    f.Name, f.Size = "HitLogger", UDim2.new(0,550,0,200)
    f.Position = UDim2.new(0.5,-275,0.65,0)
    f.BackgroundTransparency, f.BorderSizePixel = 1, 0
    f.Visible = S.hlEnabled
    R.hlFrame = f
end

AddHitLog = function(logType, playerName, hitbox, damage)
    if not S.hlEnabled then return end
    if not R.hlFrame then CreateHitLogger() end
    if not R.hlFrame then return end

    -- Find position for effects
    local targetPos = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == playerName and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then targetPos = hrp.Position end
        end
    end

    if logType == "kill" and targetPos then
        ShowHitmarker(targetPos, "RESOLVED")
        ShowKillEffect(targetPos)
    end
    if logType == "hit" and targetPos then
        ShowFortniteDamage(targetPos, damage)
    end

    local dmg = logType == "kill" and 100 or (damage or 0)
    local rem = logType == "kill" and 0 or MAX(0, 100 - dmg)
    R.hlLogIndex = (R.hlLogIndex or 0) + 1
    local idx = R.hlLogIndex

    -- push existing logs down
    for _, child in ipairs(R.hlFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name:match("^Log_") then
            local y = child.Position.Y.Offset
            TweenService:Create(child, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                Position = UDim2.new(0.5,0,0, y+24)
            }):Play()
        end
    end

    local actionText = logType=="kill" and "Killed" or (logType=="miss" and "Missed" or "Hurt")
    local hitboxL = (hitbox or "head"):lower()
    local fullText
    if logType == "miss" then
        fullText = string.format("✕ Missed %s (shot at %s).", playerName or "?", hitboxL)
    else
        fullText = string.format("%s %s in the %s for %d hp (%d remaining).", actionText, playerName or "?", hitboxL, dmg, rem)
    end

    local bar = Instance.new("Frame", R.hlFrame)
    bar.Name = "Log_" .. idx
    bar.Size = UDim2.new(0,480,0,24)
    bar.Position = UDim2.new(0.5,0,0,-20)
    bar.AnchorPoint = Vector2.new(0.5,0)
    bar.BackgroundColor3 = Color3.fromRGB(10,10,10)
    bar.BackgroundTransparency = 0.5
    bar.BorderSizePixel, bar.ZIndex = 0, 100
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0,4)

    local iconLbl = Instance.new("TextLabel", bar)
    iconLbl.Size, iconLbl.Position = UDim2.new(0,24,1,0), UDim2.new(0,8,0,0)
    iconLbl.BackgroundTransparency, iconLbl.ZIndex = 1, 102
    iconLbl.Text = logType=="miss" and "X" or "+"
    iconLbl.Font, iconLbl.TextSize = Enum.Font.GothamBold, 14
    iconLbl.TextColor3 = logType=="miss" and Color3.fromRGB(255,80,80) or Color3.fromRGB(100,255,100)

    local txtLbl = Instance.new("TextLabel", bar)
    txtLbl.Size, txtLbl.Position = UDim2.new(1,-38,1,0), UDim2.new(0,30,0,0)
    txtLbl.BackgroundTransparency, txtLbl.ZIndex = 1, 101
    txtLbl.Text, txtLbl.Font, txtLbl.TextSize = fullText, Enum.Font.Code, 13
    txtLbl.TextColor3, txtLbl.TextXAlignment = Color3.fromRGB(255,255,255), Enum.TextXAlignment.Left
    txtLbl.TextTruncate = Enum.TextTruncate.AtEnd

    bar.BackgroundTransparency = 1
    txtLbl.TextTransparency, iconLbl.TextTransparency = 1, 1

    TweenService:Create(bar, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position=UDim2.new(0.5,0,0,0)}):Play()
    TweenService:Create(bar, TweenInfo.new(0.15), {BackgroundTransparency=0.5}):Play()
    TweenService:Create(txtLbl, TweenInfo.new(0.15), {TextTransparency=0}):Play()
    TweenService:Create(iconLbl, TweenInfo.new(0.15), {TextTransparency=0}):Play()

    -- trim old
    local logs = {}
    for _, child in ipairs(R.hlFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name:match("^Log_") then
            table.insert(logs, child)
        end
    end
    table.sort(logs, function(a,b)
        return (tonumber(a.Name:match("Log_(%d+)")) or 0) < (tonumber(b.Name:match("Log_(%d+)")) or 0)
    end)
    while #logs > S.hlMaxLogs do
        table.remove(logs,1):Destroy()
    end

    task.delay(5, function()
        if bar and bar.Parent then
            TweenService:Create(bar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency=1}):Play()
            TweenService:Create(txtLbl, TweenInfo.new(0.3), {TextTransparency=1}):Play()
            TweenService:Create(iconLbl, TweenInfo.new(0.3), {TextTransparency=1}):Play()
            task.delay(0.35, function() if bar and bar.Parent then bar:Destroy() end end)
        end
    end)
end

-- ============================================================
-- KILL TRACKING
-- ============================================================
local function resolveShots(playerName)
    for id, shot in pairs(pendingShots) do
        if shot.target == playerName then pendingShots[id] = nil end
    end
    lastShotByTarget[playerName] = nil
end

local function setupHumTracking(p, hum)
    if not p or not hum or p == Player then return end
    local lastHealth = hum.Health
    local lastDamageTime = 0

    hum.HealthChanged:Connect(function(newHealth)
        local now = TICK()
        local damage = FLOOR(lastHealth - newHealth)
        local myTeam, myColor = Player.Team, Player.TeamColor
        if myTeam and (p.Team == myTeam or p.TeamColor == myColor) then lastHealth = newHealth return end

        local isOurShot = false
        if confirmedShots[p.Name] and now - confirmedShots[p.Name] < 0.6 then isOurShot = true end
        if lastShotTarget == p.Name and now - lastShotTime_g < 0.5 then isOurShot = true end
        if not isOurShot then lastHealth = newHealth return end
        if now - lastDamageTime < 0.15 then lastHealth = newHealth return end
        lastDamageTime = now
        resolveShots(p.Name)

        if newHealth <= 0 and lastHealth > 0 then
            if now - lastKillTime > 0.5 and now - lastShotTime_g < 0.5 then
                lastKillTime = now
                confirmedShots[p.Name] = nil
                AddHitLog("kill", p.Name, lastShotHitbox or "Head", FLOOR(lastHealth))
            end
        elseif damage > 0 and damage < 150 then
            if now - lastHitTime > 0.2 then
                lastHitTime = now
                AddHitLog("hit", p.Name, lastShotHitbox or "Head", damage)
            end
        end
        lastHealth = newHealth
    end)
end

SetupKillTracking = function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and not trackedEnemies[p.UserId] then
            trackedEnemies[p.UserId] = true
            local function onChar(char)
                if not char then return end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then setupHumTracking(p, hum)
                else task.delay(0.5, function()
                    if char and char.Parent then
                        local h2 = char:FindFirstChildOfClass("Humanoid")
                        if h2 then setupHumTracking(p, h2) end
                    end
                end) end
            end
            if p.Character then onChar(p.Character) end
            p.CharacterAdded:Connect(onChar)
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= Player then task.delay(1, SetupKillTracking) end
end)

TrackShot = function(playerName, hitbox)
    if not playerName or playerName == "" then return end
    local targetPlayer = Players:FindFirstChild(playerName)
    if not targetPlayer or targetPlayer == Player then return end
    local c = targetPlayer.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return end

    local now = TICK()
    lastShotTarget, lastShotHitbox, lastShotTime_g = playerName, hitbox or "Head", now
    if lastShotByTarget[playerName] then pendingShots[lastShotByTarget[playerName]] = nil end

    local shotId = now .. "_" .. math.random(1000,9999)
    pendingShots[shotId] = {target=playerName, hitbox=hitbox or "Head", time=now}
    lastShotByTarget[playerName] = shotId
    confirmedShots[playerName] = now

    task.delay(1.2, function()
        if pendingShots[shotId] then
            local now2 = TICK()
            if now2-lastMissTime > 0.5 and now2-lastHitTime > 0.5 and now2-lastKillTime > 0.5 then
                local pp = Players:FindFirstChild(playerName)
                if pp and pp.Character then
                    local h2 = pp.Character:FindFirstChildOfClass("Humanoid")
                    if h2 and h2.Health > 0 then
                        lastMissTime = now2
                        AddHitLog("miss", playerName, hitbox or "Head", 0)
                        Resolver.RegisterMiss(pp)
                    end
                end
            end
            pendingShots[shotId] = nil
            if lastShotByTarget[playerName] == shotId then lastShotByTarget[playerName] = nil end
        end
    end)
    task.delay(1.5, function()
        if confirmedShots[playerName] == now then confirmedShots[playerName] = nil end
    end)
end

-- ============================================================
-- ANIM BREAKER
-- ============================================================
local function AB_Enable()
    if R.abActive or not R.myHum then return end
    R.abActive = true
    R.hotkeys["AnimBreak"] = {active=true, key=S.abKey.Name}
    UpdateHotkeyList()
    local function stopAnims()
        local anim = R.myHum and R.myHum:FindFirstChildOfClass("Animator")
        if anim then for _, t in ipairs(anim:GetPlayingAnimationTracks()) do pcall(function() t:Stop(0) end) end end
    end
    stopAnims()
    R.abConn = RunService.Heartbeat:Connect(stopAnims)
end

local function AB_Disable()
    if not R.abActive then return end
    if R.abConn then R.abConn:Disconnect() R.abConn = nil end
    R.abActive = false
    R.hotkeys["AnimBreak"] = nil
    UpdateHotkeyList()
end

-- ============================================================
-- AIMVIEW
-- ============================================================
local function AV_RemoveLine()
    if R.avLine then pcall(function() R.avLine:Destroy() end) R.avLine = nil end
end

local function AV_Update(targetPos, fromPos)
    if not S.avEnabled or not targetPos then AV_RemoveLine() return end
    if not R.avLine or not R.avLine.Parent then
        local line = Instance.new("Part", workspace)
        line.Name, line.Anchored, line.CanCollide = "AimViewLine", true, false
        line.Material, line.Color = Enum.Material.Neon, S.avColor
        line.Transparency = S.avTransparency
        R.avLine = line
    end
    R.avLine.Color = S.avColor
    local sp = fromPos or (R.myHRP and R.myHRP.Position + V3(0,1.5,0)) or targetPos
    local dist = (targetPos - sp).Magnitude
    local mid  = (sp + targetPos)/2
    R.avLine.Size = V3(0.08, 0.08, dist)
    R.avLine.CFrame = CFrame.lookAt(mid, targetPos)
end

-- ============================================================
-- VISUAL FX
-- ============================================================
local function ApplyBloom()
    if R.bloomEffect then R.bloomEffect:Destroy() R.bloomEffect = nil end
    if S.bloomEnabled then
        local b = Instance.new("BloomEffect", Lighting)
        b.Intensity, b.Size, b.Threshold = S.bloomIntensity, S.bloomSize, S.bloomThreshold
        R.bloomEffect = b
    end
end

local function ApplyColorCorrection()
    if R.colorEffect then R.colorEffect:Destroy() R.colorEffect = nil end
    if S.colorEnabled then
        local cc = Instance.new("ColorCorrectionEffect", Lighting)
        cc.Brightness, cc.Contrast, cc.Saturation = S.ccBrightness, S.ccContrast, S.ccSaturation
        R.colorEffect = cc
    end
end

local function ApplySunRays()
    if R.sunEffect then R.sunEffect:Destroy() R.sunEffect = nil end
    if S.sunRaysEnabled then
        local sr = Instance.new("SunRaysEffect", Lighting)
        sr.Intensity, sr.Spread = 0.15, 0.8
        R.sunEffect = sr
    end
end

local function ApplyFog()
    Lighting.FogStart = S.fogEnabled and 0 or 0
    Lighting.FogEnd   = S.fogEnabled and S.fogEnd or 100000
end

-- ============================================================
-- GHOST PEEK
-- ============================================================
local GP_COOLDOWN = 0.035
local gpPosCache  = {pos=nil, enemyPos=nil, time=0, enemyId=nil}
local gpLastGoodAngle = 0

local function GP_Params()
    local q = CLAMP(S.gpQuality/100, 0, 1)
    return {maxPoints=FLOOR(40+q*100), loopDelay=0.02-q*0.015, cacheTime=0.08-q*0.05}
end

local function GP_FindTarget(myChar, myRoot)
    local best, bestDist, bestChar, bestHead, bestData = nil, S.gpRange, nil, nil, nil
    local myTeam, myColor = Player.Team, Player.TeamColor
    for _, p in ipairs(Players:GetPlayers()) do
        if p == Player then continue end
        if S.gpTeamCheck and myTeam and (p.Team==myTeam or p.TeamColor==myColor) then continue end
        local c = p.Character
        if not c then continue end
        local rp = c:FindFirstChild("HumanoidRootPart")
        local h  = c:FindFirstChildOfClass("Humanoid")
        local hd = c:FindFirstChild("Head")
        if rp and h and hd and h.Health > 0 then
            local dist = (myRoot.Position - rp.Position).Magnitude
            if dist < bestDist then
                bestDist, best, bestChar, bestHead = dist, rp, c, hd
                bestData = {p=p, c=c, r=rp, head=hd}
            end
        end
    end
    return best, bestChar, bestHead, bestData
end

local function GP_FindPeekPosition(myRoot, myChar, enemyHead, enemyChar)
    if not myRoot or not enemyHead then return nil end
    local params = GP_Params()
    local now     = TICK()
    local enemyId = enemyChar and tostring(enemyChar) or nil
    local myPos   = myRoot.Position
    local enemyPos = enemyHead.Position

    if gpPosCache.pos and gpPosCache.enemyId == enemyId then
        if now - gpPosCache.time < params.cacheTime then
            local moved = gpPosCache.enemyPos and (enemyHead.Position - gpPosCache.enemyPos).Magnitude or HUGE
            if moved < 2 then return gpPosCache.pos end
        end
    end

    local dirToEnemy = (enemyPos - myPos)
    local flatDir    = V3(dirToEnemy.X, 0, dirToEnemy.Z)
    if flatDir.Magnitude < 0.1 then return nil end
    flatDir = flatDir.Unit

    local peekDist = S.gpPeekDist
    local maxHeight = S.gpHeight
    local best, bestScore = nil, -HUGE
    local tested = 0

    APRayP.FilterDescendantsInstances = {myChar, enemyChar}
    RayP.FilterDescendantsInstances   = {myChar}

    local numDist  = CLAMP(FLOOR(peekDist/2), 5, 20)
    local numAngle = CLAMP(FLOOR(peekDist), 12, 36)

    for di = 1, numDist do
        if tested >= params.maxPoints then break end
        local dist = 1.5 + (peekDist-1.5) * (di/numDist)
        for ai = 1, numAngle do
            if tested >= params.maxPoints then break end
            tested += 1
            local angle = -110 + (220*(ai-1)/(numAngle-1))
            local rad   = RAD(angle)
            local rotDir = V3(flatDir.X*COS(rad)-flatDir.Z*SIN(rad), 0, flatDir.X*SIN(rad)+flatDir.Z*COS(rad))
            local testPos = myPos + rotDir * dist
            local groundRay = workspace:Raycast(testPos+V3(0,5,0), V3(0,-10,0), APRayP)
            if not groundRay then continue end
            local finalY = CLAMP(groundRay.Position.Y+2.8, myPos.Y-maxHeight, myPos.Y+maxHeight)
            testPos = V3(testPos.X, finalY, testPos.Z)
            local pathRay = workspace:Raycast(myPos+V3(0,1.5,0), (testPos+V3(0,1.5,0))-(myPos+V3(0,1.5,0)), APRayP)
            if pathRay and pathRay.Instance.CanCollide then continue end
            local eyePos = testPos + V3(0,1.5,0)
            local res = workspace:Raycast(eyePos, enemyPos-eyePos, RayP)
            if res and not res.Instance:IsDescendantOf(enemyChar) then continue end
            local score = 350 - (testPos-myPos).Magnitude * 1.2
            if ABS(angle)>=20 and ABS(angle)<=90 then score += 55 end
            if score > bestScore then bestScore = score best = testPos gpLastGoodAngle = angle end
        end
    end

    gpPosCache.pos, gpPosCache.enemyPos, gpPosCache.time, gpPosCache.enemyId = best, enemyHead.Position, now, enemyId
    return best
end

local function GP_DoGhostShot(root, peekPos, enemyHead, myChar, enemyChar, enemyData)
    if TICK() - R.gpLastShot < GP_COOLDOWN then return false end
    local fs = GetFireShot()
    if not fs then return false end

    local shootOrigin = peekPos + V3(0,1.5,0)
    local targetPos   = enemyHead.Position
    if enemyData and enemyData.r then
        local vel  = enemyData.r.AssemblyLinearVelocity
        local ping = Player:GetNetworkPing()
        if vel.Magnitude > 0.5 then targetPos = enemyHead.Position + V3(vel.X*ping,0,vel.Z*ping) end
    end

    RayP.FilterDescendantsInstances = {myChar}
    local res = workspace:Raycast(shootOrigin, targetPos-shootOrigin, RayP)
    if res and not res.Instance:IsDescendantOf(enemyChar) then
        res = workspace:Raycast(shootOrigin, enemyHead.Position-shootOrigin, RayP)
        if res and not res.Instance:IsDescendantOf(enemyChar) then return false end
        targetPos = enemyHead.Position
    end

    local origCF  = root.CFrame
    local origVel = root.AssemblyLinearVelocity
    R.gpInPeek = true
    root.CFrame = CFrame.new(peekPos, V3(targetPos.X, peekPos.Y, targetPos.Z))
    root.AssemblyLinearVelocity = V3_0
    local dir = (targetPos - shootOrigin).Unit
    pcall(function() fs:FireServer(shootOrigin, dir, enemyHead) end)
    root.CFrame = origCF
    root.AssemblyLinearVelocity = origVel
    R.gpInPeek = false
    R.gpLastShot = TICK()
    if enemyData and enemyData.p then TrackShot(enemyData.p.Name, "Head") end
    return true
end

local function GP_Enable()
    if R.gpActive then return end
    CacheChar()
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    R.gpActive = true
    R.gpLastShot, R.gpInPeek = 0, false
    gpPosCache.pos, gpPosCache.time = nil, 0
    gpLastGoodAngle = 0
    R.hotkeys["Ghost Peek"] = {active=true, key=S.gpKey.Name}
    UpdateHotkeyList()

    task.spawn(function()
        local params = GP_Params()
        local frameSkip = 0
        local lastPeekPos, lastEnemyId = nil, nil

        while R.gpActive and R.running do
            params = GP_Params()
            task.wait(params.loopDelay)
            if R.gpInPeek then continue end
            CacheChar()
            local c    = Player.Character
            local root2 = c and c:FindFirstChild("HumanoidRootPart")
            local hum  = c and c:FindFirstChildOfClass("Humanoid")
            if not root2 or not hum or hum.Health <= 0 then lastPeekPos,lastEnemyId=nil,nil continue end

            local eRoot, eChar, eHead, eData = GP_FindTarget(c, root2)
            if not eRoot or not eHead then lastPeekPos,lastEnemyId=nil,nil continue end

            local cid = tostring(eChar)
            if cid ~= lastEnemyId then
                lastPeekPos,frameSkip,gpPosCache.pos,gpPosCache.time,gpLastGoodAngle = nil,0,nil,0,0
                lastEnemyId = cid
            end

            -- only run when not already in LOS
            RayP.FilterDescendantsInstances = {c}
            local eye = root2.Position + V3(0,1.5,0)
            local direct = workspace:Raycast(eye, eHead.Position-eye, RayP)
            if not direct or direct.Instance:IsDescendantOf(eChar) then
                lastPeekPos = nil continue
            end

            frameSkip += 1
            local peekPos = lastPeekPos
            if not lastPeekPos or frameSkip >= 2 then
                frameSkip = 0
                peekPos   = GP_FindPeekPosition(root2, c, eHead, eChar)
                lastPeekPos = peekPos
            end

            if peekPos and S.gpAutoshoot then
                GP_DoGhostShot(root2, peekPos, eHead, c, eChar, eData)
            end
        end
    end)
end

local function GP_Disable()
    R.gpActive, R.gpInPeek = false, false
    gpPosCache.pos, gpLastGoodAngle = nil, 0
    R.hotkeys["Ghost Peek"] = nil
    UpdateHotkeyList()
end

-- ============================================================
-- AI PEEK V4
-- ============================================================
local AP_RINGS         = 2
local AP_PER_RING      = 8
local AP_GROUND_OFFSET = 2.8
local apPoints         = {}
local apESPCache       = {}

local function AP_GetMoveParams(dist)
    local speed = S.apSpeed
    if speed <= 0 then return 0,0,true end
    local baseTime
    if speed <= 50       then baseTime = 0.02+(speed/50)*0.05
    elseif speed <= 200  then baseTime = 0.07+((speed-50)/150)*0.1
    elseif speed <= 500  then baseTime = 0.17+((speed-200)/300)*0.2
    else                      baseTime = 0.37+((speed-500)/300)*0.25 end
    local distFactor = CLAMP(dist/15, 0.5, 2.0)
    local totalTime  = baseTime * distFactor
    local steps      = CLAMP(CEIL(totalTime*60), 2, 50)
    return totalTime, steps, false
end

local function AP_SmoothStep(t) return t*t*(3-2*t) end

local function AP_ClearESP()
    for _, hl in pairs(apESPCache) do pcall(function() hl:Destroy() end) end
    apESPCache = {}
end

local function AP_GetGround(pos, char, baseY)
    APRayP.FilterDescendantsInstances = {char}
    local r = workspace:Raycast(pos+V3(0,6,0), V3(0,-18,0), APRayP)
    if r then
        local gy = r.Position.Y + 0.3
        local diff = gy - baseY
        if diff > S.apHeight then gy = baseY+S.apHeight end
        if diff < -S.apHeight then gy = baseY-S.apHeight end
        return gy, true
    end
    return baseY, false
end

local function AP_CanReach(from, to, char)
    APRayP.FilterDescendantsInstances = {char}
    for _, h in ipairs({1,2,3}) do
        local r = workspace:Raycast(from+V3(0,h,0), (to+V3(0,h,0))-(from+V3(0,h,0)), APRayP)
        if r and r.Instance.CanCollide then return false end
    end
    return true
end

local function AP_CanShootFrom(pointPos, enemyHead, myChar, enemyChar)
    if not enemyHead then return false end
    APRayP.FilterDescendantsInstances = {myChar, enemyChar}
    local r = workspace:Raycast(pointPos+V3(0,1.6,0), enemyHead.Position-(pointPos+V3(0,1.6,0)), APRayP)
    return not r or not r.Instance.CanCollide
end

local function AP_EnemySeesPoint(eRoot, ptPos, myChar, eChar)
    APRayP.FilterDescendantsInstances = {myChar, eChar}
    local eye = eRoot.Position + V3(0,1.5,0)
    for _, h in ipairs({1, 2.5}) do
        local t  = ptPos + V3(0,h,0)
        local r  = workspace:Raycast(eye, t-eye, APRayP)
        if not r or not r.Instance.CanCollide then return true end
    end
    return false
end

local function AP_CreatePoints()
    for i = 1, #apPoints do
        local p = apPoints[i]
        if p and p.part then p.part:Destroy() end
        apPoints[i] = nil
    end
    local spacing = S.apPeekDist / AP_RINGS
    local idx = 0
    for ring = 1, AP_RINGS do
        local dist = ring * spacing * 1
        for i = 1, AP_PER_RING do
            idx += 1
            local angle = (i-1)*(360/AP_PER_RING) + (ring*22.5)
            apPoints[idx] = {ring=ring,dist=dist,angle=angle,pos=V3_0,groundY=0,canReach=false,canShoot=false,enemySees=false,score=0,part=nil}
            if S.apShowPoints then
                local pt = Instance.new("Part", workspace)
                pt.Name, pt.Shape = "AP_P", Enum.PartType.Ball
                pt.Size, pt.Anchored, pt.CanCollide = V3(0.5,0.5,0.5), true, false
                pt.Material, pt.Transparency, pt.Color = Enum.Material.Neon, 0.3, Color3.new(1,1,1)
                apPoints[idx].part = pt
            end
        end
    end
    R.apPoints, R.apPointCount = apPoints, idx
end

local function AP_RemovePoints()
    for i = 1, #apPoints do
        local p = apPoints[i]
        if p and p.part then p.part:Destroy() end
        apPoints[i] = nil
    end
    R.apPoints, R.apPointCount = {}, 0
    AP_ClearESP()
end

local function AP_UpdatePoints(rootPos, char, baseY)
    for i = 1, #apPoints do
        local pt = apPoints[i]
        if not pt then continue end
        local ang = RAD(pt.angle)
        local base = rootPos + V3(COS(ang)*pt.dist, 0, SIN(ang)*pt.dist)
        pt.groundY, _ = AP_GetGround(base, char, baseY)
        pt.pos = V3(base.X, pt.groundY, base.Z)
        pt.canReach = AP_CanReach(rootPos, pt.pos, char)
        pt.canShoot, pt.enemySees, pt.score = false, false, 0
        if pt.part then pt.part.Position = pt.pos + V3(0,0.7,0) end
    end
end

local function AP_FindBest(myRoot, myChar, eRoot, eChar)
    local eHead = eChar:FindFirstChild("Head")
    if not eHead then return nil end
    local best, bestScore = nil, -999999
    local myPos, ePos = myRoot.Position, eRoot.Position
    for i = 1, #apPoints do
        local pt = apPoints[i]
        if not pt or not pt.canReach then continue end
        pt.canShoot  = AP_CanShootFrom(pt.pos, eHead, myChar, eChar)
        pt.enemySees = AP_EnemySeesPoint(eRoot, pt.pos, myChar, eChar)
        if pt.enemySees and pt.canShoot then
            local dist = (pt.pos - myPos).Magnitude
            pt.score = 1000 - dist*8 - (pt.pos-ePos).Magnitude*3
            if pt.score > bestScore then bestScore = pt.score best = pt end
        end
    end
    return best
end

local function AP_FindEnemy(myChar, myRoot)
    local best, bestDist, bestChar = nil, S.apRange, nil
    local myTeam, myColor = Player.Team, Player.TeamColor
    for _, p in ipairs(Players:GetPlayers()) do
        if p == Player then continue end
        if S.apTeamCheck and myTeam and (p.Team==myTeam or p.TeamColor==myColor) then continue end
        local c = p.Character
        if not c then continue end
        local rp = c:FindFirstChild("HumanoidRootPart")
        local h  = c:FindFirstChildOfClass("Humanoid")
        if rp and h and h.Health > 0 then
            local dist = (rp.Position - myRoot.Position).Magnitude
            if dist < bestDist then bestDist, best, bestChar = dist, rp, c end
        end
    end
    return best, bestChar, bestDist
end

local function AP_MoveTo(root, target, char, baseY)
    local start = root.Position
    local look  = root.CFrame.LookVector
    local dist  = (target - start).Magnitude
    local totalTime, steps, instant = AP_GetMoveParams(dist)
    if instant then
        root.CFrame = CFrame.new(V3(target.X, baseY, target.Z), V3(target.X,baseY,target.Z)+look)
        return true
    end
    local stepTime = totalTime / steps
    APRayP.FilterDescendantsInstances = {char}
    for i = 1, steps do
        if not R.apActive or not root.Parent then return false end
        local t   = i/steps
        local pos = start:Lerp(target, AP_SmoothStep(t))
        local gr  = workspace:Raycast(pos+V3(0,4,0), V3(0,-8,0), APRayP)
        if gr then
            local gy = gr.Position.Y + AP_GROUND_OFFSET
            local diff = gy - baseY
            if diff > S.apHeight then gy = baseY+S.apHeight end
            pos = V3(pos.X, gy, pos.Z)
        else
            pos = V3(pos.X, baseY, pos.Z)
        end
        root.CFrame = CFrame.new(pos, pos+look)
        task.wait(stepTime)
    end
    return true
end

local function AP_DoPeek(root, point, char, eRoot, eChar)
    if R.apTeleporting then return end
    if S.apCooldown > 0 and TICK() - R.apLastTP < S.apCooldown then return end
    local eHead = eChar:FindFirstChild("Head")
    if not AP_CanShootFrom(point.pos, eHead, char, eChar) then return end
    local eHum = eChar:FindFirstChildOfClass("Humanoid")
    if not eHum or eHum.Health <= 0 then return end

    R.apTeleporting, R.apLastTP = true, TICK()
    local baseY   = root.Position.Y
    local origin  = root.CFrame
    local targetY = CLAMP(point.groundY+AP_GROUND_OFFSET, baseY-S.apHeight, baseY+S.apHeight)
    local tPos    = V3(point.pos.X, targetY, point.pos.Z)

    if not AP_MoveTo(root, tPos, char, baseY) then R.apTeleporting = false return end
    if root.Parent and eRoot.Parent then
        root.CFrame = CFrame.new(root.Position, V3(eRoot.Position.X, root.Position.Y, eRoot.Position.Z))
        local fs = GetFireShot()
        if fs then
            local shootO = root.Position + V3(0,1.5,0)
            local dir    = (eHead.Position - shootO).Unit
            pcall(function() fs:FireServer(shootO, dir, eHead) end)
            local enemyData = nil
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == eChar then enemyData = {p=p} break end
            end
            if enemyData and enemyData.p then TrackShot(enemyData.p.Name, "Head") end
        end
        task.wait(0.05)
    end
    if root.Parent then AP_MoveTo(root, origin.Position, char, baseY) root.CFrame = origin end
    R.apTeleporting = false
end

local function AP_Enable()
    if R.apActive then return end
    CacheChar()
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    R.apActive = true
    R.apTeleporting = false
    R.apLastTP, R.apPointCount = 0, 0
    AP_CreatePoints()
    R.hotkeys["AI Peek v4"] = {active=true, key=S.apKey.Name}
    UpdateHotkeyList()

    task.spawn(function()
        local loopCount = 0
        while R.apActive and R.running do
            task.wait(0.05)
            loopCount += 1
            if R.apTeleporting then continue end
            local c    = Player.Character
            local root2 = c and c:FindFirstChild("HumanoidRootPart")
            local hum  = c and c:FindFirstChildOfClass("Humanoid")
            if not root2 or not hum or hum.Health <= 0 then continue end
            local baseY = root2.Position.Y
            if loopCount % 2 == 0 then AP_UpdatePoints(root2.Position, c, baseY) end
            local eRoot, eChar = AP_FindEnemy(c, root2)
            if not eRoot or not eChar then continue end
            local best = AP_FindBest(root2, c, eRoot, eChar)
            if best and best.canShoot then AP_DoPeek(root2, best, c, eRoot, eChar) end
        end
        AP_ClearESP()
    end)
end

local function AP_Disable()
    R.apActive, R.apTeleporting = false, false
    AP_RemovePoints()
    AP_ClearESP()
    R.hotkeys["AI Peek v4"] = nil
    UpdateHotkeyList()
end

-- ============================================================
-- FAKEDUCK
-- ============================================================
local function ToggleFakeduck()
    S.fdEnabled = not S.fdEnabled
    if S.fdEnabled then
        local hum = R.myHum
        if hum then
            local anim = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
            pcall(function()
                local a1 = Instance.new("Animation") a1.AnimationId = "rbxassetid://102226306945117"
                R.fdIdleAnim = anim:LoadAnimation(a1)
                R.fdIdleAnim.Priority, R.fdIdleAnim.Looped = Enum.AnimationPriority.Action4, true
                local a2 = Instance.new("Animation") a2.AnimationId = "rbxassetid://124458965304788"
                R.fdWalkAnim = anim:LoadAnimation(a2)
                R.fdWalkAnim.Priority, R.fdWalkAnim.Looped = Enum.AnimationPriority.Action4, true
            end)
        end
    else
        pcall(function()
            if R.fdIdleAnim and R.fdIdleAnim.IsPlaying then R.fdIdleAnim:Stop() end
            if R.fdWalkAnim and R.fdWalkAnim.IsPlaying then R.fdWalkAnim:Stop() end
        end)
        R.fdCrouch, R.fdTarget = false, nil
    end
    ApplySettings()
end

-- ============================================================
-- DOUBLE TAP
-- ============================================================
local function DT_Peek()
    if not R.myHRP or not R.myHum then return end
    local now = TICK()
    if now - R.dtLastPeek < 0.3 then return end
    R.dtLastPeek = now
    local cam = workspace.CurrentCamera
    local camLook = cam and cam.CFrame.LookVector or R.myHRP.CFrame.LookVector
    camLook = V3(camLook.X,0,camLook.Z).Unit
    local origCF = R.myHRP.CFrame
    local peekPos = origCF.Position + camLook * S.dtDist
    RayP.FilterDescendantsInstances = {R.myChar}
    if workspace:Raycast(origCF.Position, camLook*S.dtDist, RayP) then return end
    R.myHRP.CFrame = CFrame.new(peekPos) * CFrame.Angles(0, math.atan2(-camLook.X,-camLook.Z), 0)
    task.delay(0.15, function()
        if R.myHRP and R.myHRP.Parent then R.myHRP.CFrame = origCF end
    end)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local frame = 0
local FD_DIST = 200

local function MainLoop(dt)
    if not R.running then return end
    frame += 1
    if frame % 15 == 0 then CacheChar() end
    if not R.myChar or not R.myHRP then return end

    UpdatePlayerData()
    UpdateChams()

    local now  = TICK()
    local hrp  = R.myHRP
    local head = R.myHead
    local cam  = R.cam

    -- Third person
    Player.CameraMaxZoomDistance = S.ThirdPerson and 25 or 8

    -- Ragebot
    if S.rbEnabled and S.rbAutoFire and head then
        local isGrounded = true
        if R.myHum then
            if R.myHum.FloorMaterial == Enum.Material.Air then isGrounded = false end
            local vel = hrp.AssemblyLinearVelocity
            if ABS(vel.Y) > 2 then isGrounded = false end
        end

        if isGrounded and now - R.rbLast >= 2.5 then
            RayP.FilterDescendantsInstances = {R.myChar}
            local best, bestScore = nil, -9999
            local bulletOrigin = hrp.Position + V3(0,1.5,0)

            for i = 1, 8 do
                local d = R.playerData[i]
                if not d or d.team or d.dist >= S.rbMaxDist then continue end

                if S.rbNoAir then
                    local gR = workspace:Raycast(d.r.Position, V3(0,-4,0), RayP)
                    local velY = d.vel and d.vel.Y or 0
                    if not gR or ABS(velY) > 8 then continue end
                end

                local targets = {}
                if S.rbSmartAim then
                    if d.head  then table.insert(targets, {part=d.head,  priority=3}) end
                    if d.torso then table.insert(targets, {part=d.torso, priority=2}) end
                else
                    local tgt = S.rbHitbox == "Head" and d.head or d.torso or d.r
                    if tgt then table.insert(targets, {part=tgt, priority=1}) end
                end

                for _, td in ipairs(targets) do
                    local tgt = td.part
                    if not tgt then continue end
                    local vel  = d.vel or d.r.AssemblyLinearVelocity
                    local ping = Player:GetNetworkPing()
                    local realPos = tgt.Position
                    local targetPos

                    local params2 = RaycastParams.new()
                    params2.FilterType = Enum.RaycastFilterType.Exclude
                    params2.FilterDescendantsInstances = {R.myChar, d.c}
                    local res = workspace:Raycast(bulletOrigin, realPos-bulletOrigin, params2)
                    local canSee = (res == nil)
                    if S.rbWallCheck and not canSee then continue end

                    if canSee then
                        if S.rbPredMode == "Beta AI" then
                            local aiPos, aiConf, aiMode = AI_GetBestPrediction(d.p.Name, realPos, vel, ping)
                            local confThreshold = S.aiConfThreshold / 100
                            local predRes = workspace:Raycast(bulletOrigin, aiPos-bulletOrigin, params2)
                            if not predRes and aiConf >= confThreshold then
                                targetPos = aiPos
                            else
                                targetPos = realPos + vel * ping
                            end
                        else
                            targetPos = realPos + vel * ping
                        end

                        -- Resolver correction
                        if S.rbResolver and d.head then
                            targetPos = ResolveYaw(d.p, d.head)
                        end

                        local score = (S.rbMaxDist - d.dist) + td.priority * 100
                        if score > bestScore then
                            bestScore = score
                            best = {d=d, tgt=tgt, predictedPos=targetPos}
                        end
                        break
                    end
                end
            end

            if S.avEnabled and best and best.d and best.d.head then
                AV_Update(best.d.head.Position, bulletOrigin)
            elseif S.avEnabled then
                AV_RemoveLine()
            end

            if best then
                local fs = GetFireShot()
                if fs then
                    local pos    = best.predictedPos or best.tgt.Position
                    local dir    = (pos - bulletOrigin).Unit
                    local name   = best.d.p and best.d.p.Name or "Unknown"
                    local hitbox = best.tgt.Name or "Head"
                    pcall(function() fs:FireServer(bulletOrigin, dir, best.tgt) end)
                    R.rbLast = now
                    TrackShot(name, hitbox)
                end
            end

            -- Auto Double Tap
            if S.dtAuto and S.dtEnabled and now - R.dtAutoLast > (S.dtAutoDelay/1000) then
                local visCount = 0
                for i = 1, 8 do
                    local d = R.playerData[i]
                    if d and not d.team and d.dist < S.rbMaxDist then
                        local tgt = d.head or d.torso or d.r
                        if tgt then
                            RayP.FilterDescendantsInstances = {R.myChar}
                            local res = workspace:Raycast(bulletOrigin, tgt.Position-bulletOrigin, RayP)
                            if not res or res.Instance:IsDescendantOf(d.c) then visCount += 1 end
                        end
                    end
                end
                if visCount == 1 then R.dtAutoLast = now DT_Peek() end
            end
        end
    end

    -- Bunnyhop
    if S.bhEnabled and frame % 3 == 0 and R.myHum then
        if now - R.bhPosCheckTime >= 1.5 then
            local curPos = hrp.Position
            if R.bhLastPos then
                local dist = V3(curPos.X,0,curPos.Z) - V3(R.bhLastPos.X,0,R.bhLastPos.Z)
                R.bhCircling = dist.Magnitude < 15
            end
            R.bhLastPos, R.bhPosCheckTime = curPos, now
        end
        if not R.bhCircling then
            RayP.FilterDescendantsInstances = {R.myChar}
            local rayRes   = workspace:Raycast(hrp.Position, V3(0,-3.5,0), RayP)
            local onGround = rayRes ~= nil
            if not onGround and not R.bhInAir then
                R.bhInAir = true
                if not R.bhResetting then R.myHum.WalkSpeed = S.bhAirSpeed end
            elseif onGround and R.bhInAir then
                R.bhInAir = false
                if not R.bhResetting then R.myHum.WalkSpeed = S.bhGroundSpeed end
            end
            if R.bhInAir and not R.bhResetting then
                local vel     = hrp.AssemblyLinearVelocity
                local moveDir = R.myHum.MoveDirection
                if moveDir.Magnitude > 0 then
                    hrp.AssemblyLinearVelocity = V3(moveDir.X*S.bhAirSpeed*0.95, vel.Y, moveDir.Z*S.bhAirSpeed*0.95)
                end
            end
        else
            R.myHum.WalkSpeed = R.bhOrigSpeed
        end
    end

    -- Fakeduck
    if S.fdEnabled and frame % 4 == 0 and head then
        local function playAnim()
            local moving = V3(hrp.AssemblyLinearVelocity.X,0,hrp.AssemblyLinearVelocity.Z).Magnitude > 0.5
            if moving then
                if R.fdIdleAnim and R.fdIdleAnim.IsPlaying then R.fdIdleAnim:Stop() end
                if R.fdWalkAnim and not R.fdWalkAnim.IsPlaying then R.fdWalkAnim:Play() end
            else
                if R.fdWalkAnim and R.fdWalkAnim.IsPlaying then R.fdWalkAnim:Stop() end
                if R.fdIdleAnim and not R.fdIdleAnim.IsPlaying then R.fdIdleAnim:Play() end
            end
        end
        if R.fdLock then
            R.fdCrouch = true playAnim()
        else
            RayP.FilterDescendantsInstances = {R.myChar}
            local enemy = nil
            for i = 1, 4 do
                local d = R.playerData[i]
                if d and not d.team and d.dist <= FD_DIST and d.head and cam then
                    local _, on = cam:WorldToScreenPoint(d.head.Position)
                    if on then
                        local res = workspace:Raycast(head.Position, d.head.Position-head.Position, RayP)
                        if not res or res.Instance:IsDescendantOf(d.c) then enemy = d.p break end
                    end
                end
            end
            if enemy then
                R.fdTarget, R.fdCrouch = enemy, false
                if R.fdIdleAnim and R.fdIdleAnim.IsPlaying then R.fdIdleAnim:Stop() end
                if R.fdWalkAnim and R.fdWalkAnim.IsPlaying then R.fdWalkAnim:Stop() end
            else
                if R.fdTarget then
                    local c = R.fdTarget.Character
                    if not c or not c:FindFirstChildOfClass("Humanoid") or c.Humanoid.Health <= 0 then R.fdTarget = nil end
                end
                if not R.fdTarget then R.fdCrouch = true playAnim() end
            end
        end
    end

    if frame > 1000 then frame = 0 end
end

local function StartMainLoop()
    if R.mainConn then return end
    CacheChar()
    R.mainConn = RunService.Heartbeat:Connect(MainLoop)
end

local function StopMainLoop()
    if R.mainConn then R.mainConn:Disconnect() R.mainConn = nil end
end

ApplySettings = function()
    R.hotkeys = {}
    local needLoop = S.rbEnabled or S.fdEnabled or S.bhEnabled or S.gpEnabled or S.apEnabled
    if needLoop then StartMainLoop() else StopMainLoop() end
    if S.rbEnabled  then R.hotkeys["Ragebot"]    = {active=true, key="ON"} end
    if S.fdEnabled  then R.hotkeys["Fakeduck"]   = {active=true, key=S.fdKey.Name} end
    if S.bhEnabled  then R.hotkeys["BunnyHop"]   = {active=true, key=S.bhKey.Name} end
    if S.dtEnabled  then R.hotkeys["DoubleTap"]  = {active=true, key=S.dtKey.Name} end
    if R.apActive   then R.hotkeys["AI Peek v4"] = {active=true, key=S.apKey.Name} end
    if R.gpActive   then R.hotkeys["Ghost Peek"] = {active=true, key=S.gpKey.Name} end
    if R.abActive   then R.hotkeys["AnimBreak"]  = {active=true, key=S.abKey.Name} end
    UpdateHotkeyList()
end

-- ============================================================
-- ANTI-AIM SYSTEM
-- ============================================================
local AA = {}
AA.active       = false
AA.conn         = nil
AA.desyncFlip   = false
AA.origCamConn  = nil
AA.fakeAngles   = {yaw=0, pitch=0, roll=0}
AA.realAngles   = {yaw=0, pitch=0, roll=0}
AA.jitterFlip   = true
AA.jitterTimer  = 0
AA.spinAngle    = 0
AA.rollAngle    = 0
AA.origCamSens  = nil
AA.fakeBodyConn = nil
AA.slowWalkOrig = 16

-- Neck / Waist joint names for R6 and R15
local NECK_PARTS = {Neck=true, Waist=true}
-- We rotate the root CFrame each frame to apply yaw AA
-- Pitch is done via head/neck joint C0 manipulation

local function AA_GetRootJoint(char)
    -- HumanoidRootPart -> Torso weld (R6)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not torso then return nil end
    for _, j in ipairs(hrp:GetChildren()) do
        if j:IsA("Motor6D") and (j.Part1 == torso or j.Part0 == torso) then return j end
    end
    -- R15: RootRigAttachment
    for _, j in ipairs((char:FindFirstChild("UpperTorso") or {{}}).Parent and char:GetDescendants() or {}) do
        if j:IsA("Motor6D") and j.Name == "Root" then return j end
    end
    return nil
end

local function AA_GetNeckJoint(char)
    local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
    if not torso then return nil end
    for _, j in ipairs(torso:GetChildren()) do
        if j:IsA("Motor6D") and NECK_PARTS[j.Name] then return j end
    end
    return nil
end

-- Stores original C0 of neck to restore it
local AA_neckOrigC0 = nil
local AA_rootOrigC0 = nil

local function AA_SaveOriginals(char)
    local neck = AA_GetNeckJoint(char)
    if neck and not AA_neckOrigC0 then AA_neckOrigC0 = neck.C0 end
    local rj = AA_GetRootJoint(char)
    if rj and not AA_rootOrigC0 then AA_rootOrigC0 = rj.C0 end
end

local function AA_Restore(char)
    local neck = AA_GetNeckJoint(char)
    if neck and AA_neckOrigC0 then pcall(function() neck.C0 = AA_neckOrigC0 end) end
    local rj = AA_GetRootJoint(char)
    if rj and AA_rootOrigC0 then pcall(function() rj.C0 = AA_rootOrigC0 end) end
    AA_neckOrigC0, AA_rootOrigC0 = nil, nil
end

-- Apply yaw to root joint C0 (rotates the visual model, not the actual HRP)
local function AA_ApplyYaw(char, yawDeg)
    local rj = AA_GetRootJoint(char)
    if not rj then return end
    local base = AA_rootOrigC0 or rj.C0
    if not AA_rootOrigC0 then AA_rootOrigC0 = base end
    -- We rotate the C0 by yawDeg around Y axis
    rj.C0 = base * CFrame.Angles(0, RAD(yawDeg), 0)
end

-- Apply pitch to neck C0
local function AA_ApplyPitch(char, pitchDeg)
    local neck = AA_GetNeckJoint(char)
    if not neck then return end
    local base = AA_neckOrigC0 or neck.C0
    if not AA_neckOrigC0 then AA_neckOrigC0 = base end
    neck.C0 = base * CFrame.Angles(RAD(pitchDeg), 0, 0)
end

-- Compute the yaw offset this frame based on mode
local function AA_CalcYaw(dt)
    local t = TICK()
    local mode = S.aaYawType
    if mode == "Spin" then
        AA.spinAngle = (AA.spinAngle + S.aaSpinSpeed * dt) % 360
        return AA.spinAngle
    elseif mode == "Jitter" then
        AA.jitterTimer = AA.jitterTimer + dt
        if AA.jitterTimer >= 0.06 then AA.jitterTimer = 0 AA.jitterFlip = not AA.jitterFlip end
        return AA.jitterFlip and S.aaJitterRange or -S.aaJitterRange
    elseif mode == "Static" then
        local base = S.aaYawAngle
        if S.aaDesyncEnabled then
            base = base + (AA.desyncFlip and S.aaDesyncAmount or -S.aaDesyncAmount)
        end
        return base
    elseif mode == "Sway" then
        return SIN(t * S.aaSwaySpeed) * S.aaSwayRange
    elseif mode == "Random" then
        -- update every 3 frames (~50ms)
        if not AA.randomTimer or t - AA.randomTimer > 0.05 then
            AA.randomTimer = t
            AA.randomVal = math.random(-180, 180)
        end
        return AA.randomVal or 0
    end
    return 0
end

-- Compute pitch offset
local function AA_CalcPitch()
    local mode = S.aaPitchType
    if mode == "Up"       then return -89 end
    if mode == "Down"     then return  89 end
    if mode == "LookUp"   then return -45 end
    if mode == "LookDown" then return  45 end
    return 0
end

-- Compute roll (applied via root joint roll axis)
local function AA_CalcRoll(dt)
    if not S.aaRollEnabled then return 0 end
    local mode = S.aaRollType
    if mode == "Spin" then
        AA.rollAngle = (AA.rollAngle + S.aaRollSpeed * dt) % 360
        return AA.rollAngle
    elseif mode == "Tilt" then
        return SIN(TICK() * 2) * 45
    elseif mode == "Static" then
        return S.aaRollAngle
    end
    return 0
end

function AA.Enable()
    if AA.active then return end
    local char = R.myChar
    if not char then return end
    AA.active = true
    AA_SaveOriginals(char)

    -- slow walk
    if S.aaSlowWalkEnabled and R.myHum then
        AA.slowWalkOrig = R.myHum.WalkSpeed
        R.myHum.WalkSpeed = S.aaSlowWalkSpeed
    end

    local lastT = TICK()
    AA.conn = RunService.Heartbeat:Connect(function()
        if not AA.active then return end
        local now = TICK()
        local dt = math.min(now - lastT, 0.1)
        lastT = now

        local c = R.myChar
        if not c then return end

        local yawOff   = AA_CalcYaw(dt)
        local pitchOff = AA_CalcPitch()
        local rollOff  = AA_CalcRoll(dt)

        -- Apply desync: real angle is normal aim, fake (visual) angle is offset
        -- We can only rotate the C0 joints, not HRP itself (would break movement)
        pcall(function() AA_ApplyYaw(c, yawOff + rollOff) end)
        if S.aaPitchType ~= "None" then
            pcall(function() AA_ApplyPitch(c, pitchOff) end)
        end

        AA.fakeAngles = {yaw=yawOff, pitch=pitchOff, roll=rollOff}
    end)

    R.hotkeys["Anti-Aim"] = {active=true, key=S.aaKey.Name}
    UpdateHotkeyList()
    Notify("Anti-Aim", "Enabled — "..S.aaYawType, 2)
end

function AA.Disable()
    if not AA.active then return end
    AA.active = false
    if AA.conn then AA.conn:Disconnect() AA.conn = nil end

    local char = R.myChar
    if char then pcall(function() AA_Restore(char) end) end

    -- restore slow walk
    if S.aaSlowWalkEnabled and R.myHum then
        R.myHum.WalkSpeed = AA.slowWalkOrig
    end

    R.hotkeys["Anti-Aim"] = nil
    UpdateHotkeyList()
    Notify("Anti-Aim", "Disabled", 1.5)
end

function AA.Toggle()
    if AA.active then AA.Disable() else AA.Enable() end
end

function AA.FlipDesync()
    AA.desyncFlip = not AA.desyncFlip
    Notify("Desync", AA.desyncFlip and "Flipped" or "Normal", 1)
end

-- Re-enable on respawn if was active
local AA_wasActive = false
Player.CharacterAdded:Connect(function(char)
    AA_neckOrigC0, AA_rootOrigC0 = nil, nil
    if AA_wasActive then task.wait(0.5) AA.Enable() end
end)

-- ============================================================
-- UI LIBRARY (self-contained, no filesystem)
-- ============================================================
local T = {
    Main   = Color3.fromRGB(12, 12, 12),
    Group  = Color3.fromRGB(19, 19, 19),
    Stroke = Color3.fromRGB(45, 45, 45),
    Accent = Color3.fromRGB(168, 247, 50),
    Text   = Color3.fromRGB(220, 220, 220),
    Dim    = Color3.fromRGB(140, 140, 140),
    Font   = Enum.Font.Code,
    Dark   = Color3.fromRGB(25, 25, 25),
    Darker = Color3.fromRGB(20, 20, 20),
    Border = Color3.fromRGB(60, 60, 60),
}

local function Crt(cls, props, children)
    local obj = Instance.new(cls)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, c in pairs(children or {}) do c.Parent = obj end
    return obj
end

local function Tween(inst, props, dur)
    TweenService:Create(inst, TweenInfo.new(dur or 0.2, Enum.EasingStyle.Sine), props):Play()
end

-- Notification
local function Notify(title, text, dur)
    task.spawn(function()
        local ng = PlayerGui:FindFirstChild("HvH_Notifs")
        if not ng then
            ng = Crt("ScreenGui", {Name="HvH_Notifs", Parent=PlayerGui, ResetOnSpawn=false})
            Crt("Frame", {Name="List", Parent=ng, BackgroundTransparency=1,
                AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-10,1,-10),
                Size=UDim2.new(0,300,1,-20)}, {
                Crt("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder,
                    VerticalAlignment=Enum.VerticalAlignment.Bottom, Padding=UDim.new(0,4)})
            })
        end
        local list = ng.List
        local ts   = TextService:GetTextSize(text, 14, Enum.Font.Gotham, Vector2.new(280, math.huge))
        local h    = ts.Y + 38
        local f    = Crt("Frame", {Parent=list, BackgroundColor3=T.Main, BorderSizePixel=0,
            Size=UDim2.new(0,300,0,h), BackgroundTransparency=1}, {
            Crt("UICorner", {CornerRadius=UDim.new(0,5)}),
            Crt("UIStroke", {Color=T.Stroke, Thickness=1}),
            Crt("TextLabel", {Name="T", BackgroundTransparency=1,
                Position=UDim2.new(0,8,0,5), Size=UDim2.new(1,-16,0,18),
                Font=Enum.Font.GothamBold, Text=title, TextColor3=T.Text,
                TextTransparency=1, TextSize=14, TextXAlignment=Enum.TextXAlignment.Left}),
            Crt("TextLabel", {Name="B", BackgroundTransparency=1,
                Position=UDim2.new(0,8,0,22), Size=UDim2.new(1,-16,0,ts.Y),
                Font=Enum.Font.Gotham, Text=text, TextColor3=T.Dim,
                TextTransparency=1, TextSize=13, TextWrapped=true,
                TextXAlignment=Enum.TextXAlignment.Left}),
        })
        Tween(f, {BackgroundTransparency=0}, 0.25)
        Tween(f.T, {TextTransparency=0}, 0.25)
        Tween(f.B, {TextTransparency=0}, 0.25)
        task.wait(dur or 3)
        Tween(f, {BackgroundTransparency=1}, 0.25)
        Tween(f.T, {TextTransparency=1}, 0.25)
        Tween(f.B, {TextTransparency=1}, 0.25)
        task.wait(0.3)
        f:Destroy()
    end)
end

-- Hotkey list frame
UpdateHotkeyList = function()
    if not R.hkFrame then return end
    local cont = R.hkFrame:FindFirstChild("C")
    if not cont then return end
    for _, c in ipairs(cont:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for name, data in pairs(R.hotkeys) do
        if data.active then
            local e = Crt("Frame", {Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, Parent=cont})
            Crt("TextLabel", {Text=name, Size=UDim2.new(0.65,0,1,0), BackgroundTransparency=1,
                TextXAlignment=Enum.TextXAlignment.Left, Font=T.Font, TextSize=11, TextColor3=T.Text, Parent=e})
            Crt("TextLabel", {Text="["..data.key.."]", Size=UDim2.new(0.35,0,1,0), Position=UDim2.new(0.65,0,0,0),
                BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Right, Font=T.Font, TextSize=10, TextColor3=T.Dim, Parent=e})
        end
    end
end

-- ============================================================
-- BUILD THE WINDOW
-- ============================================================
local old = guiParent:FindFirstChild("HvH_UI")
if old then old:Destroy() end

local ScreenGui = Crt("ScreenGui", {
    Name=          "HvH_UI",
    Parent=        guiParent,
    ZIndexBehavior= Enum.ZIndexBehavior.Sibling,
    ResetOnSpawn=  false,
})
R.gui = ScreenGui

CreateHitLogger()
task.spawn(SetupKillTracking)

-- Hotkey frame
do
    local hkf = Crt("Frame", {Name="HK", Parent=ScreenGui,
        Size=UDim2.new(0,165,0,28), Position=UDim2.new(1,-175,0,200),
        BackgroundColor3=T.Main, BackgroundTransparency=0.1, BorderSizePixel=0, Active=true})
    Instance.new("UIStroke", hkf).Color = T.Stroke
    Crt("TextLabel", {Text="hotkeys", Parent=hkf,
        Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,3),
        BackgroundTransparency=1, Font=T.Font, TextSize=11, TextColor3=T.Dim})
    local cont = Crt("Frame", {Name="C", Parent=hkf, Size=UDim2.new(1,-8,1,-24),
        Position=UDim2.new(0,4,0,22), BackgroundTransparency=1})
    local list = Instance.new("UIListLayout", cont)
    list.Padding = UDim.new(0,2)
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        hkf.Size = UDim2.new(0,165,0, MAX(28, list.AbsoluteContentSize.Y+26))
    end)
    R.hkFrame = hkf
    local drag, ds, dp = false, nil, nil
    hkf.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag,ds,dp=true,i.Position,hkf.Position end
    end)
    hkf.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement and drag then
            local d = i.Position-ds
            hkf.Position = UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
        end
    end)
    table.insert(R.conns, UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
    end))
end

-- Watermark
do
    local wm = Crt("Frame", {Parent=ScreenGui,
        Size=UDim2.new(0,180,0,22), Position=UDim2.new(0,10,0,10),
        BackgroundColor3=T.Main, BackgroundTransparency=0.1, BorderSizePixel=0})
    Instance.new("UIStroke", wm).Color = T.Stroke
    local gl = Crt("Frame", {Parent=wm, Size=UDim2.new(1,0,0,2), BorderSizePixel=0})
    local ug = Instance.new("UIGradient", gl)
    ug.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,T.Accent), ColorSequenceKeypoint.new(1,Color3.fromRGB(100,200,50))})
    local lbl = Crt("TextLabel", {Name="T", Parent=wm,
        Size=UDim2.new(1,-10,1,-2), Position=UDim2.new(0,5,0,2),
        BackgroundTransparency=1, Font=T.Font, TextSize=11, TextColor3=T.Text,
        TextXAlignment=Enum.TextXAlignment.Left, Text="HvH Mode | loading..."})
    task.spawn(function()
        local lastT, fc, fps = tick(), 0, 60
        RunService.Heartbeat:Connect(function() fc+=1 end)
        while R.running and wm and wm.Parent do
            local now2 = tick()
            if now2-lastT >= 1 then fps=FLOOR(fc/(now2-lastT)) fc=0 lastT=now2 end
            local ping = FLOOR(Player:GetNetworkPing()*1000)
            lbl.Text = "HvH | fps:"..fps.." ping:"..ping.."ms"
            wm.Size = UDim2.new(0, TextService:GetTextSize(lbl.Text,11,T.Font,Vector2.new(1000,22)).X+20, 0, 22)
            task.wait(1)
        end
    end)
end

-- Main window
local Main = Crt("Frame", {Name="Main", Parent=ScreenGui,
    Size=UDim2.new(0,620,0,450), Position=UDim2.new(0.5,-310,0.5,-225),
    BackgroundColor3=T.Main, BorderSizePixel=0})
Instance.new("UIStroke", Main).Color = T.Border

-- drag
local isDragging, dragStart, startPos = false, nil, nil
Main.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and i.Position.Y < Main.AbsolutePosition.Y+30 then
        isDragging,dragStart,startPos = true,i.Position,Main.Position
    end
end)
Main.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
        local d = i.Position-dragStart
        Main.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
table.insert(R.conns, UserInputService.InputChanged:Connect(function(i)
    if R.sliderDrag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = R.sliderDrag
        local rel = CLAMP((i.Position.X - d.bg.AbsolutePosition.X)/d.bg.AbsoluteSize.X, 0, 1)
        d.val = FLOOR(d.min + (d.max-d.min)*rel)
        d.fill.Size = UDim2.new(rel,0,1,0)
        d.lbl.Text  = d.text..": "..d.val
        if d.cb then d.cb(d.val) end
    end
end))
table.insert(R.conns, UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then isDragging,R.sliderDrag=false,nil end
end))

-- Title
Crt("TextLabel", {Parent=Main, Text="HvH Mode — Equal tools for everyone",
    Size=UDim2.new(1,0,0,22), Position=UDim2.new(0,0,0,4),
    BackgroundTransparency=1, Font=T.Font, TextSize=13, TextColor3=T.Text})

-- Tab bar
local TabBar = Crt("Frame", {Parent=Main, Size=UDim2.new(1,-20,0,38),
    Position=UDim2.new(0,10,0,28), BackgroundColor3=T.Group, BorderColor3=T.Stroke})
Instance.new("UIListLayout", TabBar).FillDirection = Enum.FillDirection.Horizontal
local TabPages = Crt("Frame", {Parent=Main, Size=UDim2.new(1,-20,1,-85),
    Position=UDim2.new(0,10,0,72), BackgroundTransparency=1})

local tabButtons = {}
local function NewTab(name)
    local btn = Crt("TextButton", {Parent=TabBar,
        Text=name, Size=UDim2.new(0,80,1,0),
        BackgroundTransparency=1, Font=T.Font, TextSize=13, TextColor3=T.Dim, BorderSizePixel=0})
    table.insert(tabButtons, btn)
    local page = Crt("ScrollingFrame", {Parent=TabPages, Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, Visible=false, BorderSizePixel=0,
        ScrollBarThickness=4, ScrollBarImageColor3=T.Accent,
        ScrollingDirection=Enum.ScrollingDirection.Y,
        AutomaticCanvasSize=Enum.AutomaticSize.Y})
    local lc = Crt("Frame", {Parent=page, Size=UDim2.new(0.47,0,0,0),
        BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y})
    Instance.new("UIListLayout", lc).Padding = UDim.new(0,10)
    local rc = Crt("Frame", {Parent=page, Size=UDim2.new(0.47,0,0,0),
        Position=UDim2.new(0.52,0,0,0), BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y})
    Instance.new("UIListLayout", rc).Padding = UDim.new(0,10)

    btn.MouseButton1Click:Connect(function()
        for _, p in ipairs(TabPages:GetChildren()) do if p:IsA("ScrollingFrame") then p.Visible=false end end
        for _, b in ipairs(tabButtons) do b.TextColor3=T.Dim end
        page.Visible, btn.TextColor3 = true, T.Accent
    end)
    if #tabButtons == 1 then page.Visible, btn.TextColor3 = true, T.Accent end

    local TL = {}
    function TL:NewGroupbox(side, title)
        local col = side == "Right" and rc or lc
        local grp = Crt("Frame", {Parent=col, Size=UDim2.new(1,0,0,0),
            BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y})
        local brd = Crt("Frame", {Parent=grp, Size=UDim2.new(1,0,0,0),
            Position=UDim2.new(0,0,0,10), BackgroundColor3=T.Main, BorderColor3=T.Stroke,
            AutomaticSize=Enum.AutomaticSize.Y})
        Crt("TextLabel", {Parent=grp, Text=title, Position=UDim2.new(0,10,0,14),
            Size=UDim2.new(1,-20,0,16), BackgroundColor3=T.Main, BorderSizePixel=0,
            Font=T.Font, TextSize=12, TextColor3=T.Text, ZIndex=2,
            TextXAlignment=Enum.TextXAlignment.Left, AutomaticSize=Enum.AutomaticSize.X})
        local cnt = Crt("Frame", {Parent=brd, Size=UDim2.new(1,-16,0,0),
            Position=UDim2.new(0,8,0,22), BackgroundTransparency=1,
            AutomaticSize=Enum.AutomaticSize.Y})
        Instance.new("UIListLayout", cnt).Padding = UDim.new(0,6)
        Crt("UIPadding", {Parent=brd, PaddingBottom=UDim.new(0,8)})

        local G = {}
        function G:Toggle(text, def, cb)
            local f = Crt("Frame", {Parent=cnt, Size=UDim2.new(1,0,0,20), BackgroundTransparency=1})
            local box = Crt("Frame", {Parent=f, Size=UDim2.new(0,16,0,16), Position=UDim2.new(0,0,0,2),
                BackgroundColor3=T.Dark})
            Instance.new("UIStroke", box).Color = T.Stroke
            Crt("TextLabel", {Parent=f, Text=text, Size=UDim2.new(1,-25,1,0), Position=UDim2.new(0,25,0,0),
                BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left,
                TextColor3=T.Dim, Font=T.Font, TextSize=13})
            local b = Crt("TextButton", {Parent=f, Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text=""})
            local en = def
            local function upd()
                box.BackgroundColor3 = en and T.Accent or T.Dark
                if cb then cb(en) end
            end
            b.MouseButton1Click:Connect(function() en=not en upd() end)
            upd()
            return G
        end
        function G:Slider(text, min, max, def, cb)
            local f = Crt("Frame", {Parent=cnt, Size=UDim2.new(1,0,0,34), BackgroundTransparency=1})
            local lbl = Crt("TextLabel", {Parent=f, Text=text..": "..def, Size=UDim2.new(1,0,0,15),
                BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left,
                TextColor3=T.Dim, Font=T.Font, TextSize=13})
            local bg = Crt("Frame", {Parent=f, Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,0,18),
                BackgroundColor3=T.Dark, BorderColor3=T.Stroke})
            local fill = Crt("Frame", {Parent=bg, BackgroundColor3=T.Accent, BorderSizePixel=0,
                Size=UDim2.new((def-min)/MAX(max-min,1),0,1,0)})
            local data = {bg=bg, fill=fill, lbl=lbl, text=text, min=min, max=max, val=def, cb=cb}
            bg.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then R.sliderDrag=data end
            end)
            return G
        end
        function G:Dropdown(text, opts, def, cb)
            local f = Crt("Frame", {Parent=cnt, Size=UDim2.new(1,0,0,40),
                BackgroundTransparency=1, ClipsDescendants=false, ZIndex=10})
            Crt("TextLabel", {Parent=f, Text=text, Size=UDim2.new(1,0,0,15),
                BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left,
                TextColor3=T.Dim, Font=T.Font, TextSize=13})
            local box = Crt("TextButton", {Parent=f, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,18),
                BackgroundColor3=T.Dark, BorderColor3=T.Stroke, Font=T.Font, TextSize=13,
                TextColor3=T.Text, Text=def.." ▼"})
            local ol = Crt("Frame", {Parent=f, Size=UDim2.new(1,0,0,#opts*20),
                Position=UDim2.new(0,0,0,40), BackgroundColor3=T.Darker, BorderColor3=T.Stroke,
                Visible=false, ZIndex=100})
            Instance.new("UIListLayout", ol)
            local cur, open = def, false
            for _, opt in ipairs(opts) do
                local ob = Crt("TextButton", {Parent=ol, Size=UDim2.new(1,0,0,20),
                    BackgroundColor3=T.Dark, BorderSizePixel=0, Font=T.Font, TextSize=12, ZIndex=101,
                    TextColor3=opt==cur and T.Accent or T.Dim, Text=opt})
                ob.MouseButton1Click:Connect(function()
                    cur, box.Text, ol.Visible, open = opt, opt.." ▼", false, false
                    f.Size = UDim2.new(1,0,0,40)
                    for _, b2 in ipairs(ol:GetChildren()) do
                        if b2:IsA("TextButton") then b2.TextColor3 = b2.Text==cur and T.Accent or T.Dim end
                    end
                    if cb then cb(cur) end
                end)
            end
            box.MouseButton1Click:Connect(function()
                open = not open
                ol.Visible = open
                f.Size = open and UDim2.new(1,0,0,40+#opts*20) or UDim2.new(1,0,0,40)
            end)
            return G
        end
        function G:Button(text, cb)
            local b = Crt("TextButton", {Parent=cnt, Size=UDim2.new(1,0,0,22),
                BackgroundColor3=T.Dark, BorderColor3=T.Stroke, Font=T.Font, TextSize=13,
                TextColor3=T.Text, Text=text})
            b.MouseButton1Click:Connect(cb)
            return G
        end
        function G:Keybind(text, def, cb)
            local f = Crt("Frame", {Parent=cnt, Size=UDim2.new(1,0,0,20), BackgroundTransparency=1})
            Crt("TextLabel", {Parent=f, Text=text, Size=UDim2.new(0.6,0,1,0),
                BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left,
                TextColor3=T.Dim, Font=T.Font, TextSize=13})
            local b = Crt("TextButton", {Parent=f, Size=UDim2.new(0.38,0,1,0), Position=UDim2.new(0.62,0,0,0),
                BackgroundColor3=Color3.fromRGB(22,22,22), BorderColor3=T.Stroke, Font=T.Font, TextSize=11,
                TextColor3=T.Dim, Text="["..def.Name.."]"})
            local waiting = false
            b.MouseButton1Click:Connect(function() waiting=true b.Text="[...]" b.TextColor3=T.Accent end)
            table.insert(R.conns, UserInputService.InputBegan:Connect(function(i)
                if waiting and i.UserInputType == Enum.UserInputType.Keyboard then
                    waiting,b.Text,b.TextColor3 = false,"["..i.KeyCode.Name.."]",T.Dim
                    if cb then cb(i.KeyCode) end
                end
            end))
            return G
        end
        return G
    end
    return TL
end

-- ============================================================
-- BUILD TABS
-- ============================================================

-- RAGE TAB
do
    local Tab = NewTab("Rage")
    local rb = Tab:NewGroupbox("Left", "Ragebot")
    rb:Toggle("Enable", false, function(v) S.rbEnabled=v ApplySettings() end)
    rb:Toggle("Auto Fire", true, function(v) S.rbAutoFire=v end)
    rb:Toggle("Team Check", true, function(v) S.rbTeamCheck=v end)
    rb:Toggle("Wall Check", true, function(v) S.rbWallCheck=v end)
    rb:Toggle("No Air Shot", true, function(v) S.rbNoAir=v end)
    rb:Toggle("Smart Aim", true, function(v) S.rbSmartAim=v end)
    rb:Dropdown("Hitbox", {"Head","Torso"}, "Head", function(v) S.rbHitbox=v end)
    rb:Dropdown("Prediction", {"Default","Beta AI"}, "Default", function(v) S.rbPredMode=v end)
    rb:Slider("Max Distance", 50, 1000, 500, function(v) S.rbMaxDist=v end)
    rb:Slider("Body Aim HP", 10, 100, 50, function(v) S.rbBodyAimHP=v end)

    local res = Tab:NewGroupbox("Left", "Resolver")
    res:Toggle("Enable Resolver", false, function(v) S.rbResolver=v end)
    res:Dropdown("Mode", {"Safe","Aggressive"}, "Safe", function(v) S.rbResolverMode=v end)

    local ai = Tab:NewGroupbox("Right", "Beta AI Settings")
    ai:Slider("Confidence %", 30, 100, 60, function(v) S.aiConfThreshold=v end)
    ai:Slider("History Size", 10, 50, 30, function(v) S.aiHistorySize=v AI_PRED.HISTORY_SIZE=v end)
    ai:Toggle("Peek Detect", true, function(v) S.aiPeekDetect=v AI_PRED.peekDetect=v end)
    ai:Toggle("Strafe Detect", true, function(v) S.aiStrafeDetect=v end)

    local dt = Tab:NewGroupbox("Right", "Double Tap")
    dt:Toggle("Enable", false, function(v) S.dtEnabled=v ApplySettings() end)
    dt:Keybind("Key", Enum.KeyCode.E, function(k) S.dtKey=k end)
    dt:Slider("TP Distance", 3, 15, 6, function(v) S.dtDist=v end)
    dt:Toggle("Auto DT", false, function(v) S.dtAuto=v end)
    dt:Slider("Auto Delay (ms)", 100, 1000, 200, function(v) S.dtAutoDelay=v end)

    local ap = Tab:NewGroupbox("Left", "AI Peek v4")
    ap:Toggle("Enable", false, function(v)
        S.apEnabled=v
        if not v and R.apActive then AP_Disable() end
        ApplySettings()
    end)
    ap:Keybind("Key", Enum.KeyCode.LeftAlt, function(k) S.apKey=k end)
    ap:Dropdown("Mode", {"Hold","Toggle"}, "Hold", function(v) S.apMode=v end)
    ap:Toggle("Team Check", true, function(v) S.apTeamCheck=v end)
    ap:Toggle("Show Points", false, function(v)
        S.apShowPoints=v
        if R.apActive then AP_RemovePoints() AP_CreatePoints() end
    end)
    ap:Slider("Range", 20, 200, 80, function(v) S.apRange=v end)
    ap:Slider("Peek Distance", 2, 20, 8, function(v) S.apPeekDist=v end)
    ap:Slider("Speed", 0, 1000, 200, function(v) S.apSpeed=v end)
    ap:Slider("Max Height", 1, 10, 2, function(v) S.apHeight=v end)
    ap:Slider("Cooldown (ms)", 0, 3000, 100, function(v) S.apCooldown=v/1000 end)

    local gp = Tab:NewGroupbox("Right", "Ghost Peek")
    gp:Toggle("Enable", false, function(v)
        S.gpEnabled=v
        if not v and R.gpActive then GP_Disable() end
        ApplySettings()
    end)
    gp:Keybind("Key", Enum.KeyCode.Q, function(k) S.gpKey=k end)
    gp:Dropdown("Mode", {"Hold","Toggle"}, "Hold", function(v) S.gpMode=v end)
    gp:Toggle("Auto Shoot", true, function(v) S.gpAutoshoot=v end)
    gp:Toggle("Team Check", true, function(v) S.gpTeamCheck=v end)
    gp:Slider("Range", 20, 300, 100, function(v) S.gpRange=v end)
    gp:Slider("Peek Distance", 3, 40, 8, function(v) S.gpPeekDist=v end)
    gp:Slider("Max Height", 1, 15, 3, function(v) S.gpHeight=v end)
    gp:Slider("Quality", 0, 100, 50, function(v) S.gpQuality=v end)
end

-- AA TAB
do
    local Tab = NewTab("AA")

    -- YAW ANTI-AIM
    local yaw = Tab:NewGroupbox("Left", "Yaw Anti-Aim")
    yaw:Toggle("Enable", false, function(v)
        S.aaEnabled = v
        if v then AA.Enable() else AA.Disable() end
        ApplySettings()
    end)
    yaw:Keybind("Toggle Key", Enum.KeyCode.Z, function(k) S.aaKey=k end)
    yaw:Dropdown("Yaw Type", {"Spin","Jitter","Static","Sway","Random"}, "Spin", function(v)
        S.aaYawType = v
        if AA.active then AA.Disable() AA.Enable() end
    end)
    yaw:Slider("Static Angle", 0, 360, 180, function(v) S.aaYawAngle=v end)
    yaw:Slider("Spin Speed (°/s)", 20, 720, 180, function(v) S.aaSpinSpeed=v end)
    yaw:Slider("Jitter Range (°)", 5, 90, 60, function(v) S.aaJitterRange=v end)
    yaw:Slider("Sway Range (°)", 5, 90, 30, function(v) S.aaSwayRange=v end)
    yaw:Slider("Sway Speed", 1, 20, 6, function(v) S.aaSwaySpeed=v/10 end)

    -- PITCH ANTI-AIM
    local pitch = Tab:NewGroupbox("Left", "Pitch Anti-Aim")
    pitch:Dropdown("Pitch Type", {"None","Up","Down","LookUp","LookDown"}, "None", function(v)
        S.aaPitchType = v
    end)

    -- ROLL / TWIST
    local roll = Tab:NewGroupbox("Left", "Roll / Twist")
    roll:Toggle("Enable Roll", false, function(v) S.aaRollEnabled=v end)
    roll:Dropdown("Roll Type", {"Spin","Tilt","Static"}, "Spin", function(v) S.aaRollType=v end)
    roll:Slider("Roll Speed (°/s)", 20, 360, 120, function(v) S.aaRollSpeed=v end)
    roll:Slider("Static Roll (°)", 0, 180, 90, function(v) S.aaRollAngle=v end)

    -- DESYNC
    local dsync = Tab:NewGroupbox("Right", "Desync")
    dsync:Toggle("Enable Desync", false, function(v) S.aaDesyncEnabled=v end)
    dsync:Slider("Desync Amount (°)", 1, 58, 58, function(v) S.aaDesyncAmount=v end)
    dsync:Button("Flip Desync Now", function() AA.FlipDesync() end)
    dsync:Keybind("Flip Key", Enum.KeyCode.Mouse4, function(k) S.aaDesyncKey=k end)

    -- SLOW WALK
    local sw = Tab:NewGroupbox("Right", "Slow Walk")
    sw:Toggle("Enable", false, function(v)
        S.aaSlowWalkEnabled = v
        if AA.active then
            if v and R.myHum then R.myHum.WalkSpeed = S.aaSlowWalkSpeed
            elseif not v and R.myHum then R.myHum.WalkSpeed = AA.slowWalkOrig end
        end
    end)
    sw:Slider("Slow Walk Speed", 1, 16, 6, function(v)
        S.aaSlowWalkSpeed = v
        if AA.active and S.aaSlowWalkEnabled and R.myHum then R.myHum.WalkSpeed = v end
    end)

    -- FAKEDUCK
    local fd = Tab:NewGroupbox("Right", "Fakeduck")
    fd:Toggle("Enable", false, function(v) if v~=S.fdEnabled then ToggleFakeduck() end end)
    fd:Keybind("Key", Enum.KeyCode.X, function(k) S.fdKey=k end)
    fd:Keybind("Lock Key", Enum.KeyCode.V, function(k) S.fdLockKey=k end)
    fd:Toggle("Team Check", true, function(v) S.fdTeamCheck=v end)

    -- BUNNYHOP
    local bh = Tab:NewGroupbox("Right", "BunnyHop")
    bh:Toggle("Enable", false, function(v)
        S.bhEnabled=v
        if v then
            R.bhOrigSpeed = R.myHum and R.myHum.WalkSpeed or 16
            R.bhInAir,R.bhLastReset,R.bhResetting = false,0,false
            if R.myHum then R.myHum.WalkSpeed = S.bhGroundSpeed end
        else
            if R.myHum then R.myHum.WalkSpeed = R.bhOrigSpeed end
        end
        ApplySettings()
    end)
    bh:Keybind("Key", Enum.KeyCode.F, function(k) S.bhKey=k end)
    bh:Slider("Ground Speed", 16, 60, 35, function(v) S.bhGroundSpeed=v end)
    bh:Slider("Air Speed", 16, 60, 39, function(v) S.bhAirSpeed=v end)

    -- ANIM BREAKER
    local ab2 = Tab:NewGroupbox("Right", "Anim Breaker")
    ab2:Toggle("Enable", false, function(v)
        S.abEnabled=v
        if not v and R.abActive then AB_Disable() end
    end)
    ab2:Keybind("Key", Enum.KeyCode.B, function(k) S.abKey=k end)
end

-- VISUALS TAB
do
    local Tab = NewTab("Visuals")
    local ch = Tab:NewGroupbox("Left", "ESP / Chams")
    ch:Toggle("Enable Chams", false, function(v) S.Chams=v end)
    ch:Slider("Opacity (0=solid)", 0, 10, 5, function(v) S.ChamsOpacity=v/10 end)
    ch:Toggle("Third Person", false, function(v) S.ThirdPerson=v end)

    local hl2 = Tab:NewGroupbox("Left", "Hit Logger")
    hl2:Toggle("Enable", true, function(v) S.hlEnabled=v if R.hlFrame then R.hlFrame.Visible=v end end)
    hl2:Slider("Max Logs", 4, 15, 8, function(v) S.hlMaxLogs=v end)

    local wv = Tab:NewGroupbox("Left", "World FX")
    wv:Toggle("Hitmarker", true, function(v) S.hmEnabled=v end)
    wv:Dropdown("HM Color", {"Green","Red","Blue","White","Yellow"}, "Green", function(v)
        local c = {Green=Color3.fromRGB(168,247,50),Red=Color3.fromRGB(255,50,50),Blue=Color3.fromRGB(50,100,255),White=Color3.fromRGB(255,255,255),Yellow=Color3.fromRGB(255,255,0)}
        S.hmColor = c[v] or S.hmColor
    end)
    wv:Toggle("Kill Effect", true, function(v) S.keEnabled=v end)
    wv:Toggle("Fortnite Damage", true, function(v) S.fdmgEnabled=v end)

    local av2 = Tab:NewGroupbox("Right", "AimView")
    av2:Toggle("Enable", false, function(v) S.avEnabled=v if not v then AV_RemoveLine() end end)
    av2:Slider("Transparency", 0, 10, 3, function(v)
        S.avTransparency=v/10
        if R.avLine then R.avLine.Transparency=S.avTransparency end
    end)

    local vfx = Tab:NewGroupbox("Right", "Post FX")
    vfx:Toggle("Bloom", false, function(v) S.bloomEnabled=v ApplyBloom() end)
    vfx:Slider("Bloom Intensity", 0, 30, 15, function(v) S.bloomIntensity=v/10 ApplyBloom() end)
    vfx:Slider("Bloom Size", 0, 100, 40, function(v) S.bloomSize=v ApplyBloom() end)
    vfx:Toggle("Color Correction", false, function(v) S.colorEnabled=v ApplyColorCorrection() end)
    vfx:Slider("Brightness", -10, 10, 0, function(v) S.ccBrightness=v/10 ApplyColorCorrection() end)
    vfx:Slider("Contrast", 0, 20, 1, function(v) S.ccContrast=v/10 ApplyColorCorrection() end)
    vfx:Slider("Saturation", 0, 20, 2, function(v) S.ccSaturation=v/10 ApplyColorCorrection() end)
    vfx:Toggle("Sun Rays", false, function(v) S.sunRaysEnabled=v ApplySunRays() end)
    vfx:Toggle("Fog", false, function(v) S.fogEnabled=v ApplyFog() end)
    vfx:Slider("Fog Distance", 100, 5000, 500, function(v) S.fogEnd=v ApplyFog() end)
end

-- SETTINGS TAB
do
    local Tab = NewTab("Settings")
    local mn = Tab:NewGroupbox("Left", "Menu")
    mn:Keybind("Menu Key", Enum.KeyCode.RightControl, function(k) S.menuKey=k end)
    mn:Dropdown("Accent Color", {"Green","Red","Blue","Purple","Cyan","Yellow","White"}, "Green", function(v)
        local colors = {Green=Color3.fromRGB(168,247,50),Red=Color3.fromRGB(255,80,80),Blue=Color3.fromRGB(80,150,255),
            Purple=Color3.fromRGB(180,100,255),Cyan=Color3.fromRGB(80,255,255),Yellow=Color3.fromRGB(255,255,80),
            White=Color3.fromRGB(255,255,255)}
        T.Accent = colors[v] or T.Accent
    end)
    mn:Button("Unload Script", function()
        R.running = false
        StopMainLoop()
        AP_Disable()
        GP_Disable()
        AB_Disable()
        AA.Disable()
        AV_RemoveLine()
        if S.bhEnabled and R.myHum then R.myHum.WalkSpeed = R.bhOrigSpeed end
        if R.bloomEffect then R.bloomEffect:Destroy() end
        if R.colorEffect then R.colorEffect:Destroy() end
        if R.sunEffect   then R.sunEffect:Destroy() end
        Lighting.FogEnd = 100000
        for _, c in ipairs(R.conns) do pcall(function() c:Disconnect() end) end
        if ScreenGui then ScreenGui:Destroy() end
        local ng = PlayerGui:FindFirstChild("HvH_Notifs")
        if ng then ng:Destroy() end
    end)
end

-- ============================================================
-- INPUT
-- ============================================================
table.insert(R.conns, UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end

    -- menuKey handled separately below

    if S.aaEnabled and i.KeyCode == S.aaKey then AA.Toggle() end
    if S.aaDesyncEnabled and i.KeyCode == S.aaDesyncKey then AA.FlipDesync() end

    if S.dtEnabled and i.KeyCode == S.dtKey then DT_Peek() end

    if S.abEnabled and i.KeyCode == S.abKey then
        if R.abActive then AB_Disable() else AB_Enable() end
    end

    if S.apEnabled and i.KeyCode == S.apKey then
        if S.apMode == "Hold" then
            if not R.apActive then AP_Enable() end
        else
            if R.apActive then AP_Disable() else AP_Enable() end
        end
    end

    if S.gpEnabled and i.KeyCode == S.gpKey then
        if S.gpMode == "Hold" then
            if not R.gpActive then GP_Enable() end
        else
            if R.gpActive then GP_Disable() else GP_Enable() end
        end
    end

    if i.KeyCode == S.fdKey then ToggleFakeduck() end
    if i.KeyCode == S.fdLockKey then R.fdLock = true end

    if i.KeyCode == S.bhKey then
        S.bhEnabled = not S.bhEnabled
        if S.bhEnabled then
            R.bhOrigSpeed = R.myHum and R.myHum.WalkSpeed or 16
            R.bhInAir,R.bhLastReset,R.bhResetting = false,0,false
            if R.myHum then R.myHum.WalkSpeed = S.bhGroundSpeed end
        else
            if R.myHum then R.myHum.WalkSpeed = R.bhOrigSpeed end
        end
        ApplySettings()
    end
end))

table.insert(R.conns, UserInputService.InputEnded:Connect(function(i, gpe)
    if gpe then return end
    if S.apEnabled and i.KeyCode == S.apKey and S.apMode == "Hold" then AP_Disable() end
    if S.gpEnabled and i.KeyCode == S.gpKey and S.gpMode == "Hold" then GP_Disable() end
    if i.KeyCode == S.fdLockKey then R.fdLock = false end
end))

-- Character respawn
Player.CharacterAdded:Connect(function()
    R.myChar,R.myHRP,R.myHead,R.myHum = nil,nil,nil,nil
    R.fireShot, R.playerData = nil, {}
    R.playerDataTime, R.fireShotTime = 0, 0
    R.bhInAir,R.bhLastReset,R.bhResetting = false,0,false
    if R.apActive then AP_Disable() end
    if R.gpActive then GP_Disable() end
    R.gpInPeek = false
    AB_Disable()
    AA_wasActive = AA.active
    AA.active = false
    if AA.conn then AA.conn:Disconnect() AA.conn = nil end
    AA_neckOrigC0, AA_rootOrigC0 = nil, nil
    task.wait(0.5)
    CacheChar()
    if S.bhEnabled and R.myHum then
        R.bhOrigSpeed = R.myHum.WalkSpeed
        R.myHum.WalkSpeed = S.bhGroundSpeed
    end
    if S.fdEnabled then
        S.fdEnabled = false
        R.fdIdleAnim, R.fdWalkAnim = nil, nil
        task.wait(0.5)
        ToggleFakeduck()
    end
    if AA_wasActive then
        task.wait(0.3)
        AA.Enable()
    end
end)

-- ============================================================
-- INIT
-- ============================================================
task.defer(function()
    CacheChar()
    task.spawn(SetupKillTracking)
    ApplySettings()
    task.wait(1)
    Notify("HvH Mode Active", "Right Ctrl toggles UI. All players have equal tools.", 5)
end)

print("[HvH] Loaded. Right Ctrl = toggle UI.")

-- ============================================================
-- HIT AIR SYSTEM
-- ============================================================
local function HitAir_Create()
    if R.hitAirPart or not R.myHRP then return end
    local p = Instance.new("Part", workspace)
    p.Name, p.Size = "HvH_HitAir", V3(4, 0.5, 4)
    p.Anchored, p.CanCollide, p.Transparency = true, true, 1
    p.CFrame = R.myHRP.CFrame * CFrame.new(0,-3,0)
    R.hitAirPart, R.hitAirActive = p, true
end

local function HitAir_Remove()
    if R.hitAirPart then pcall(function() R.hitAirPart:Destroy() end) R.hitAirPart = nil end
    R.hitAirActive = false
end

local function HitAir_Update()
    if not R.hitAirActive or not R.hitAirPart or not R.myHRP then return end
    R.hitAirPart.CFrame = CFrame.new(R.myHRP.Position - V3(0,3,0))
end

-- ============================================================
-- INFINITY JUMP
-- ============================================================
local function IJ_CreatePart()
    if R.ijPart or not R.myHRP then return end
    local p = Instance.new("Part", workspace)
    p.Name, p.Size = "HvH_IJ", V3(4,0.5,4)
    p.Anchored, p.CanCollide, p.Transparency = true, true, 1
    p.CFrame = R.myHRP.CFrame * CFrame.new(0,-3,0)
    R.ijPart = p
end

local function IJ_RemovePart()
    if R.ijPart then pcall(function() R.ijPart:Destroy() end) R.ijPart = nil end
end

local function IJ_Update()
    if not S.ijEnabled then IJ_RemovePart() return end
    if not R.myHRP or not R.myHum then return end
    local state = R.myHum:GetState()
    local inAir = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
    if inAir then
        IJ_CreatePart()
        if R.ijPart then R.ijPart.CFrame = R.myHRP.CFrame * CFrame.new(0,-3,0) end
    else
        IJ_RemovePart()
    end
end

local function IJ_Jump()
    if not S.ijEnabled or not R.myHum or not R.myHRP then return end
    local state = R.myHum:GetState()
    local inAir = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
    if inAir then
        IJ_CreatePart()
        if R.ijPart then R.ijPart.CanCollide = true end
        task.wait(0.02)
        R.myHum:ChangeState(Enum.HumanoidStateType.Jumping)
        task.delay(0.1, function() if R.ijPart then R.ijPart.CanCollide = false end end)
    end
end

-- ============================================================
-- WALLBANG HELPER (makes specific map parts transparent)
-- ============================================================
local wbCache = {}
local function WB_Enable()
    wbCache = {}
    local function makeTransparent(name, targetPos)
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == name then
                local d = (obj.Position - targetPos).Magnitude
                if d < 5 then
                    table.insert(wbCache, {obj=obj, orig=obj.Transparency})
                    obj.Transparency = 0.8
                end
            end
        end
    end
    -- Common wallbang-able parts (generic; adapt names for your map)
    local wallParts = {
        {"hamik"}, {"paletka"}, {"nowallbang1"}
    }
    task.spawn(function()
        for _, ws_obj in pairs(workspace:GetDescendants()) do
            if ws_obj:IsA("BasePart") then
                for _, entry in ipairs(wallParts) do
                    if ws_obj.Name == entry[1] then
                        table.insert(wbCache, {obj=ws_obj, orig=ws_obj.Transparency})
                        ws_obj.Transparency = 0.8
                    end
                end
            end
        end
    end)
end

local function WB_Disable()
    for _, c in pairs(wbCache) do
        pcall(function() if c.obj and c.obj.Parent then c.obj.Transparency = c.orig end end)
    end
    wbCache = {}
end

-- ============================================================
-- REMOVE COLLISION (map clips/doors)
-- ============================================================
local rcCache = {}
local function RC_Enable()
    rcCache = {}
    local map = workspace:FindFirstChild("Map")
    if not map then return end
    task.spawn(function()
        local count = 0
        for _, folder in pairs({map:FindFirstChild("Clips"), map:FindFirstChild("Doors"), map:FindFirstChild("Ignore")}) do
            if folder then
                for _, obj in pairs(folder:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        table.insert(rcCache, {obj=obj, cc=obj.CanCollide, t=obj.Transparency})
                        obj.CanCollide, obj.Transparency = false, 1
                        count += 1
                        if count % 15 == 0 then task.wait() end
                    end
                end
            end
        end
    end)
end

local function RC_Disable()
    for _, c in pairs(rcCache) do
        pcall(function() if c.obj and c.obj.Parent then c.obj.CanCollide = c.cc c.obj.Transparency = c.t end end)
    end
    rcCache = {}
end

-- ============================================================
-- WALLBANG MAP (makes map geometry transparent)
-- ============================================================
local wbMapCache = {}
local function WBMap_Enable()
    wbMapCache = {}
    local map = workspace:FindFirstChild("Map")
    if not map then return end
    local geo = map:FindFirstChild("Geometry")
    if not geo then return end
    task.spawn(function()
        local count = 0
        for _, obj in pairs(geo:GetDescendants()) do
            if obj:IsA("BasePart") then
                table.insert(wbMapCache, {obj=obj, orig=obj.Transparency})
                obj.Transparency = 0.5
                count += 1
                if count % 20 == 0 then task.wait() end
            end
        end
    end)
end

local function WBMap_Disable()
    for _, c in pairs(wbMapCache) do
        pcall(function() if c.obj and c.obj.Parent then c.obj.Transparency = c.orig end end)
    end
    wbMapCache = {}
end

-- ============================================================
-- BARREL EXTEND (move shoot origin to gun barrel Hole part)
-- ============================================================
local R_beActive = false
local R_beDecoy  = nil
local R_beUpdateConn = nil

local function BE_GetHole()
    if not Player.Character then return nil end
    local pf = workspace:FindFirstChild(Player.Name)
    if pf then
        local ssg = pf:FindFirstChild("SSG-08")
        if ssg then
            local h = ssg:FindFirstChild("Hole")
            if h and h:IsA("BasePart") then return h end
        end
    end
    return nil
end

local function BE_Enable()
    if R_beActive or not R.myChar or not R.myHRP then return end
    local hole = BE_GetHole()
    if not hole then return end
    if R_beDecoy then pcall(function() R_beDecoy:Destroy() end) R_beDecoy = nil end
    local decoy = Instance.new("Model", workspace)
    decoy.Name = "HvH_BarrelDecoy"
    R_beDecoy = decoy
    local hrpClone = Instance.new("Part", decoy)
    hrpClone.Name = "HumanoidRootPart"
    hrpClone.Size, hrpClone.Transparency, hrpClone.CanCollide, hrpClone.Anchored = V3(2,2,1), 0.3, false, true
    hrpClone.Color = Color3.fromRGB(20,20,20)
    hrpClone.CFrame = CFrame.new(hole.Position)
    local hum = Instance.new("Humanoid", decoy)
    hum.MaxHealth, hum.Health, hum.DisplayDistanceType = 0, 0, Enum.HumanoidDisplayDistanceType.None
    R_beActive = true
    R.hotkeys["Barrel Ext"] = {active=true, key=S.beKey.Name}
    UpdateHotkeyList()
    if R_beUpdateConn then R_beUpdateConn:Disconnect() end
    R_beUpdateConn = RunService.Heartbeat:Connect(function()
        if not R_beActive or not R_beDecoy then return end
        local h2 = BE_GetHole()
        if h2 then
            local hrp2 = R_beDecoy:FindFirstChild("HumanoidRootPart")
            if hrp2 then hrp2.CFrame = CFrame.new(h2.Position) end
        end
    end)
end

local function BE_Disable()
    if not R_beActive then return end
    if R_beUpdateConn then R_beUpdateConn:Disconnect() R_beUpdateConn = nil end
    if R_beDecoy then pcall(function() R_beDecoy:Destroy() end) R_beDecoy = nil end
    R_beActive = false
    R.hotkeys["Barrel Ext"] = nil
    UpdateHotkeyList()
end

local function BE_GetShootOrigin(def)
    if not R_beActive then return def end
    local h = BE_GetHole()
    return h and h.Position or def
end

-- ============================================================
-- EXPLOIT POSITION (teleport + decoy shadow)
-- ============================================================
local epActive = false
local epDecoy  = nil
local epOriginalPos = nil
local epOriginalNeckC0 = nil
local epHealthConn = nil

local function EP_SpawnDecoy()
    if epActive then return end
    if not R.myChar or not R.myHRP or not R.myHum then return end
    epActive = true
    epOriginalPos = R.myHRP.CFrame
    if epDecoy then pcall(function() epDecoy:Destroy() end) end
    local cam = workspace.CurrentCamera
    local camLook = cam and cam.CFrame.LookVector or R.myHRP.CFrame.LookVector
    camLook = V3(camLook.X,0,camLook.Z).Unit
    local newPos = epOriginalPos.Position + camLook * S.epDist
    R.myHRP.CFrame = CFrame.new(newPos) * CFrame.Angles(0, math.atan2(-camLook.X,-camLook.Z), 0)
    local m = Instance.new("Model", workspace) m.Name = "HvH_Decoy" epDecoy = m
    for _, obj in pairs(R.myChar:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
            local c = obj:Clone() c.Parent = m
            c.Transparency, c.Color, c.CanCollide, c.Material = 0.3, Color3.fromRGB(20,20,20), false, Enum.Material.ForceField
        end
    end
    local hrpClone = R.myHRP:Clone()
    hrpClone.Name = "HumanoidRootPart"
    hrpClone.Anchored, hrpClone.CFrame, hrpClone.Transparency = true, epOriginalPos, 0.3
    hrpClone.Color, hrpClone.CanCollide, hrpClone.Parent = Color3.fromRGB(20,20,20), false, m
    local dh = Instance.new("Humanoid", m)
    dh.MaxHealth, dh.Health, dh.DisplayDistanceType = 0, 0, Enum.HumanoidDisplayDistanceType.None
    for _, part in pairs(m:GetChildren()) do
        if part:IsA("BasePart") and part ~= hrpClone then
            local w = Instance.new("WeldConstraint", hrpClone) w.Part0, w.Part1 = hrpClone, part
        end
    end
    local torso = R.myChar:FindFirstChild("Torso") or R.myChar:FindFirstChild("UpperTorso")
    if torso then local neck = torso:FindFirstChild("Neck") if neck and neck:IsA("Motor6D") then epOriginalNeckC0 = neck.C0 neck.C0 = neck.C0 * CFrame.new(0,-2,0) end end
    epHealthConn = R.myHum.HealthChanged:Connect(function(h) if epActive then pcall(function() R.myHum.Health = R.myHum.MaxHealth end) end end)
    R.hotkeys["Exploit Pos"] = {active=true, key=S.epKey.Name}
    UpdateHotkeyList()
end

local function EP_DestroyDecoy()
    if not epActive then return end
    if epDecoy then pcall(function() epDecoy:Destroy() end) epDecoy = nil end
    if epOriginalPos and R.myHRP then R.myHRP.CFrame = epOriginalPos end
    local torso = R.myChar and (R.myChar:FindFirstChild("Torso") or R.myChar:FindFirstChild("UpperTorso"))
    if torso then local neck = torso:FindFirstChild("Neck") if neck and neck:IsA("Motor6D") and epOriginalNeckC0 then neck.C0 = epOriginalNeckC0 end end
    epOriginalNeckC0 = nil
    if epHealthConn then epHealthConn:Disconnect() epHealthConn = nil end
    epOriginalPos, epActive = nil, false
    R.hotkeys["Exploit Pos"] = nil
    UpdateHotkeyList()
end

local function EP_Free()
    EP_DestroyDecoy()
    if R.myHum then pcall(function() R.myHum.WalkSpeed = 16 end) end
    if R.myHRP then pcall(function() R.myHRP.Anchored = false end) end
end

-- ============================================================
-- CUSTOM HIT SOUND
-- ============================================================
local HitSounds = {
    ["Default"] = "139894735376184",
    ["Clash Royale Laugh"] = "8406005582",
    ["Satisfying Bell"] = "82635963679205",
    ["Sonic Rings"] = "1053865439",
    ["Metal Pipe"] = "6729922069",
    ["Discord"] = "5453349528",
    ["Minecraft Hit"] = "8766809464",
    ["Dark Souls"] = "8132494511",
    ["Scream"] = "7660049822",
    ["Custom"] = ""
}
local HitSoundsList = {"Default","Clash Royale Laugh","Satisfying Bell","Sonic Rings","Metal Pipe","Discord","Minecraft Hit","Dark Souls","Scream","Custom"}

local lastHitSoundTime2 = 0
local function PlayHitSound()
    if not S.hsEnabled then return end
    local now = TICK()
    if now - lastHitSoundTime2 < 1.5 then return end
    lastHitSoundTime2 = now
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://" .. S.hsSoundId
    snd.Volume = (S.hsVolume or 100) / 100 * 3
    snd.Parent = game:GetService("SoundService")
    snd:Play()
    task.delay(4, function() pcall(function() snd:Destroy() end) end)
end

-- ============================================================
-- CUSTOM MODEL
-- ============================================================
local Models = {
    ["Mike Wazowski"]    = {{}, {108792046953186}, 1, 1},
    ["Fat Chicken"]      = {{}, {97309274164914},  1, 1},
    ["Ghostface Scream"] = {{}, {109275113218599}, 1, 1},
    ["Mini Pigeon"]      = {{}, {134936622364544}, 1, 1},
    ["Patrick Suit"]     = {{}, {114561781784509}, 1, 1},
    ["Buff Doge"]        = {{}, {135861229178903}, 1, 1},
    ["Monkey Suit"]      = {{}, {133241040400728}, 1, 1},
}
local ModelList = {"None"}
for k in pairs(Models) do table.insert(ModelList, k) end
table.sort(ModelList, function(a,b) if a=="None" then return true end if b=="None" then return false end return a<b end)

local modelConn = nil
local function ApplyModel(name)
    if name == "None" or not Models[name] then return end
    local d = Models[name]
    local headIds, torsoIds, headT, bodyT = d[1], d[2], d[3], d[4]
    local function onChar(char)
        task.wait(0.5)
        if not char or not char.Parent then return end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Accessory") then child:Destroy() end
        end
        for _, desc in ipairs(char:GetChildren()) do
            if desc:IsA("BasePart") and desc.Name ~= "HumanoidRootPart" then
                desc.Transparency = desc.Name == "Head" and headT or bodyT
            end
        end
        local head = char:FindFirstChild("Head")
        local torsoPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        for _, id in ipairs(headIds) do
            task.spawn(function()
                local ok, acc = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
                if ok and acc and head then
                    acc.Parent = char
                    local handle = acc:FindFirstChild("Handle")
                    if handle then
                        handle.CanCollide = false
                        local w = Instance.new("Weld", head) w.Part0, w.Part1 = head, handle
                        w.C0 = CFrame.new(0, head.Size.Y/2, 0)
                    end
                end
            end)
        end
        if torsoPart then
            for _, id in ipairs(torsoIds) do
                task.spawn(function()
                    local ok, acc = pcall(function() return game:GetObjects("rbxassetid://"..id)[1] end)
                    if ok and acc then
                        acc.Parent = char
                        local handle = acc:FindFirstChild("Handle")
                        if handle then
                            handle.CanCollide = false
                            local w = Instance.new("Weld", torsoPart) w.Part0, w.Part1 = torsoPart, handle w.C0 = CFrame.new()
                        end
                    end
                end)
            end
        end
    end
    if modelConn then modelConn:Disconnect() end
    modelConn = Player.CharacterAdded:Connect(onChar)
    if Player.Character then onChar(Player.Character) end
end

-- ============================================================
-- CUSTOM SKYBOX
-- ============================================================
local SkyboxList = {"None","Galaxy","Sunset","Night Stars","Nebula","Space","Aurora","Clouds","Custom ID"}
local skyboxOriginal = nil
local skyboxStars = {}
local skyboxStarConn = nil
local skyboxIDs = {
    ["Galaxy"]="1534951524",["Sunset"]="12064107",["Night Stars"]="6444884337",
    ["Nebula"]="159052995",["Space"]="6071827843",["Aurora"]="6139674221",["Clouds"]="6060938146"
}

local function ApplySkybox(v)
    -- save original
    if not skyboxOriginal then
        for _, x in pairs(Lighting:GetChildren()) do
            if x:IsA("Sky") then
                skyboxOriginal = {Bk=x.SkyboxBk,Ft=x.SkyboxFt,Lf=x.SkyboxLf,Rt=x.SkyboxRt,Up=x.SkyboxUp,Dn=x.SkyboxDn}
                break
            end
        end
    end
    -- clear stars
    for _, s in pairs(skyboxStars) do pcall(function() s:Destroy() end) end
    skyboxStars = {}
    if skyboxStarConn then skyboxStarConn:Disconnect() skyboxStarConn = nil end
    if v == "None" then
        if skyboxOriginal then
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky then sky.SkyboxBk=skyboxOriginal.Bk sky.SkyboxFt=skyboxOriginal.Ft sky.SkyboxLf=skyboxOriginal.Lf sky.SkyboxRt=skyboxOriginal.Rt sky.SkyboxUp=skyboxOriginal.Up sky.SkyboxDn=skyboxOriginal.Dn end
        end
        S.skyboxEnabled = false return
    end
    for _, x in pairs(Lighting:GetChildren()) do if x:IsA("Sky") or x:IsA("Atmosphere") then x:Destroy() end end
    local id = "http://www.roblox.com/asset/?id=" .. (v == "Custom ID" and (S.skyboxId or "139989099041467") or (skyboxIDs[v] or "139989099041467"))
    local sky = Instance.new("Sky", Lighting)
    sky.SkyboxBk,sky.SkyboxFt,sky.SkyboxLf,sky.SkyboxRt,sky.SkyboxUp,sky.SkyboxDn = id,id,id,id,id,id
    Lighting.ClockTime = 18
    S.skyboxEnabled = true
    -- optional sparkle stars
    if S.skyboxStarsEnabled then
        local starColors = {Color3.fromRGB(50,100,255),Color3.fromRGB(255,255,50),Color3.fromRGB(255,150,50),Color3.fromRGB(100,200,255),Color3.fromRGB(255,100,200)}
        local basePos = R.myHRP and R.myHRP.Position or V3(0,50,0)
        for i = 1, (S.skyboxStarsCount or 20) do
            local star = Instance.new("Part", workspace)
            star.Name, star.Shape = "HvH_Star_"..i, Enum.PartType.Ball
            star.Size, star.Anchored, star.CanCollide = V3(3,3,3), true, false
            star.Material, star.Color, star.Transparency = Enum.Material.Neon, starColors[math.random(1,#starColors)], 0.3
            local a1, a2, dist = RAD(math.random(0,360)), RAD(math.random(20,80)), math.random(800,1500)
            star.Position = basePos + V3(COS(a1)*COS(a2)*dist, SIN(a2)*dist, SIN(a1)*COS(a2)*dist)
            local light = Instance.new("PointLight", star) light.Color = star.Color light.Brightness, light.Range = 2, 30
            table.insert(skyboxStars, star)
        end
        local idx = 1
        skyboxStarConn = RunService.Heartbeat:Connect(function()
            if not S.skyboxEnabled then return end
            for _ = 1, 2 do
                local s = skyboxStars[idx]
                if s and s.Parent then
                    local l = s:FindFirstChildOfClass("PointLight")
                    if l then l.Brightness = 1.5 + math.random()*1.5 end
                    s.Transparency = 0.2 + math.random()*0.3
                end
                idx = (idx % #skyboxStars) + 1
            end
        end)
    end
end

-- ============================================================
-- BLUR EFFECT (on menu open)
-- ============================================================
local blurEffect = nil
local function ApplyMenuBlur(on)
    if on then
        if not blurEffect then
            blurEffect = Instance.new("DepthOfFieldEffect", Lighting)
            blurEffect.FarIntensity, blurEffect.FocusDistance = 0.6, 50
            blurEffect.InFocusRadius, blurEffect.NearIntensity = 50, 0.6
        end
    else
        if blurEffect then blurEffect:Destroy() blurEffect = nil end
    end
end

-- ============================================================
-- GP AURA ORBS (visual)
-- ============================================================
local gpAuraOrbs = {}
local gpVisualSphere, gpVisualRing = nil, nil

local function GP_CreateVisuals2()
    if not gpVisualSphere then
        gpVisualSphere = Instance.new("Part", workspace)
        gpVisualSphere.Name, gpVisualSphere.Shape = "HvH_GPSphere", Enum.PartType.Ball
        gpVisualSphere.Size, gpVisualSphere.Anchored, gpVisualSphere.CanCollide = V3(2,2,2), true, false
        gpVisualSphere.Material, gpVisualSphere.Color, gpVisualSphere.Transparency = Enum.Material.ForceField, Color3.fromRGB(0,255,100), 1
    end
    if not gpVisualRing then
        gpVisualRing = Instance.new("Part", workspace)
        gpVisualRing.Name, gpVisualRing.Shape = "HvH_GPRing", Enum.PartType.Cylinder
        gpVisualRing.Size, gpVisualRing.Anchored, gpVisualRing.CanCollide = V3(0.2,4,4), true, false
        gpVisualRing.Material, gpVisualRing.Color, gpVisualRing.Transparency = Enum.Material.Neon, Color3.fromRGB(0,255,100), 1
        gpVisualRing.Orientation = V3(0,0,90)
    end
    if #gpAuraOrbs == 0 then
        for i = 1, 3 do
            local orb = Instance.new("Part", workspace)
            orb.Name, orb.Shape = "HvH_AuraOrb_"..i, Enum.PartType.Ball
            orb.Size, orb.Anchored, orb.CanCollide = V3(0.8,0.8,0.8), true, false
            orb.Material, orb.Color, orb.Transparency = Enum.Material.ForceField, Color3.fromRGB(0,255,100), 1
            table.insert(gpAuraOrbs, orb)
        end
    end
end

local function GP_RemoveVisuals2()
    if gpVisualSphere then pcall(function() gpVisualSphere:Destroy() end) gpVisualSphere = nil end
    if gpVisualRing then pcall(function() gpVisualRing:Destroy() end) gpVisualRing = nil end
    for _, o in ipairs(gpAuraOrbs) do pcall(function() o:Destroy() end) end
    gpAuraOrbs = {}
end

local function GP_UpdateVisuals2(peekPos, isShooting, myPos)
    if not gpVisualSphere then GP_CreateVisuals2() end
    if myPos and #gpAuraOrbs > 0 then
        local auraColor = peekPos and (isShooting and Color3.fromRGB(255,255,0) or Color3.fromRGB(0,255,100)) or Color3.fromRGB(255,165,0)
        for i, orb in ipairs(gpAuraOrbs) do
            local angle = RAD((TICK()*90 + (i-1)*120) % 360)
            local wave = SIN(TICK()*3+i)*0.3
            orb.Position = V3(myPos.X + COS(angle)*2.5, myPos.Y + 1 + wave, myPos.Z + SIN(angle)*2.5)
            orb.Transparency = 0.35
            orb.Color = auraColor
            local pulse = 1 + SIN(TICK()*5+i*2)*0.25
            orb.Size = V3(pulse,pulse,pulse)
        end
    else
        for _, o in ipairs(gpAuraOrbs) do o.Transparency = 1 end
    end
    if peekPos then
        gpVisualSphere.Position = peekPos + V3(0,1.5,0)
        gpVisualSphere.Transparency = isShooting and 0.2 or 0.5
        gpVisualSphere.Color = isShooting and Color3.fromRGB(255,255,0) or Color3.fromRGB(0,255,100)
        local pulse = 1 + SIN(TICK()*8)*0.1
        gpVisualSphere.Size = V3(2*pulse,2*pulse,2*pulse)
        gpVisualRing.Position = V3(peekPos.X, peekPos.Y+0.1, peekPos.Z)
        gpVisualRing.Transparency = 0.4
        gpVisualRing.Color = Color3.fromRGB(255,100,0)
        gpVisualRing.Orientation = V3(0,(TICK()*60)%360, 90)
    else
        gpVisualSphere.Transparency = 1
        gpVisualRing.Transparency = 1
    end
end

-- ============================================================
-- DEBUG CONSOLE
-- ============================================================
local dcFrame = nil
local dcLogs = {}
local dcNotifies = {}

local function DC_CreateUI2()
    if dcFrame then pcall(function() dcFrame:Destroy() end) end
    if not ScreenGui then return end
    local f = Instance.new("Frame", ScreenGui)
    f.Name, f.Size, f.Position = "HvH_DC", UDim2.new(0,300,0,200), UDim2.new(0,10,0.5,-100)
    f.BackgroundColor3, f.BackgroundTransparency, f.BorderSizePixel, f.Active = Color3.fromRGB(10,10,10), 0.05, 0, true
    f.Visible = S.dcVisible
    Instance.new("UIStroke",f).Color = Color3.fromRGB(40,40,40)
    local tb = Instance.new("Frame",f) tb.Size, tb.BackgroundColor3, tb.BorderSizePixel = UDim2.new(1,0,0,18), Color3.fromRGB(15,15,15), 0
    local ttl = Instance.new("TextLabel",tb) ttl.Text, ttl.Size, ttl.Position, ttl.BackgroundTransparency = "console", UDim2.new(1,-5,1,0), UDim2.new(0,5,0,0), 1
    ttl.Font, ttl.TextSize, ttl.TextColor3, ttl.TextXAlignment = Enum.Font.Code, 10, Color3.fromRGB(100,100,100), Enum.TextXAlignment.Left
    local scroll = Instance.new("ScrollingFrame",f)
    scroll.Name, scroll.Size, scroll.Position = "Logs", UDim2.new(1,-6,1,-22), UDim2.new(0,3,0,20)
    scroll.BackgroundTransparency, scroll.BorderSizePixel, scroll.ScrollBarThickness = 1, 0, 3
    scroll.ScrollBarImageColor3, scroll.ScrollingDirection = Color3.fromRGB(60,60,60), Enum.ScrollingDirection.Y
    scroll.CanvasSize, scroll.AutomaticCanvasSize = UDim2.new(0,0,0,0), Enum.AutomaticSize.Y
    local lc = Instance.new("UIListLayout", scroll) lc.Padding = UDim.new(0,1)
    -- drag
    local drag2, ds2, dp2 = false, nil, nil
    tb.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag2,ds2,dp2 = true,i.Position,f.Position end end)
    tb.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement and drag2 then local d=i.Position-ds2 f.Position=UDim2.new(dp2.X.Scale,dp2.X.Offset+d.X,dp2.Y.Scale,dp2.Y.Offset+d.Y) end end)
    table.insert(R.conns, UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag2=false end end))
    dcFrame = f
end

local function DC_Log(text, logType)
    if not S.dcEnabled then return end
    if not dcFrame then DC_CreateUI2() end
    if not dcFrame then return end
    local scroll = dcFrame:FindFirstChild("Logs") if not scroll then return end
    local colors = {kill=Color3.fromRGB(255,80,80),damage=Color3.fromRGB(255,200,100),miss=Color3.fromRGB(120,120,120),info=Color3.fromRGB(150,200,255)}
    local e = Instance.new("TextLabel",scroll)
    e.Size, e.BackgroundTransparency = UDim2.new(1,-5,0,12), 1
    e.Font, e.TextSize, e.TextColor3 = Enum.Font.Code, 10, colors[logType] or Color3.fromRGB(180,180,180)
    e.TextXAlignment, e.Text = Enum.TextXAlignment.Left, os.date("%H:%M:%S").." "..text
    e.LayoutOrder = #dcLogs+1
    table.insert(dcLogs, e)
    if #dcLogs > 50 then table.remove(dcLogs,1):Destroy() end
    scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
end

local function DC_Toggle2()
    S.dcVisible = not S.dcVisible
    if not dcFrame then DC_CreateUI2() end
    if dcFrame then dcFrame.Visible = S.dcVisible end
    R.hotkeys["Console"] = S.dcVisible and {active=true, key=S.dcKey.Name} or nil
    UpdateHotkeyList()
end

-- ============================================================
-- TELEPORT (to map spawns)
-- ============================================================
local function TP_ToCT()
    if not S.tpEnabled or not R.myHRP then return end
    pcall(function()
        local ct = workspace:FindFirstChild("CTSpawn")
        if ct then
            local kids = ct:GetChildren()
            if kids[1] then
                local t = kids[1]
                R.myHRP.CFrame = (t:IsA("BasePart") and t.CFrame or t.PrimaryPart and t.PrimaryPart.CFrame or R.myHRP.CFrame) + V3(0,3,0)
            end
        end
    end)
end

local function TP_ToT()
    if not S.tpEnabled or not R.myHRP then return end
    pcall(function()
        local ts = workspace:FindFirstChild("TSpawn")
        if ts then
            local kids = ts:GetChildren()
            if kids[1] then
                local t = kids[1]
                R.myHRP.CFrame = (t:IsA("BasePart") and t.CFrame or t.PrimaryPart and t.PrimaryPart.CFrame or R.myHRP.CFrame) + V3(0,3,0)
            end
        end
    end)
end

-- ============================================================
-- HOOK NEW SYSTEMS INTO MAIN LOOP
-- ============================================================
-- Extend MainLoop via second Heartbeat connection
table.insert(R.conns, RunService.Heartbeat:Connect(function()
    if not R.running then return end
    -- IJ + HitAir update
    if S.ijEnabled then IJ_Update() end
    if R.hitAirActive then HitAir_Update() end
    -- GP aura orbs
    if R.gpActive and R.myHRP then GP_UpdateVisuals2(nil, false, R.myHRP.Position) end
end))

-- ============================================================
-- PATCH AddHitLog TO ALSO PLAY HIT SOUND
-- ============================================================
local _origAddHitLog = AddHitLog
AddHitLog = function(logType, playerName, hitbox, damage)
    _origAddHitLog(logType, playerName, hitbox, damage)
    if logType == "kill" or logType == "hit" then PlayHitSound() end
    DC_Log((logType == "kill" and "Killed" or (logType == "miss" and "Missed" or "Hit")).." "..playerName.." ["..hitbox.."]", logType)
end

-- ============================================================
-- PATCH GP_Enable TO USE VISUALS
-- ============================================================
-- Override GP internal to use new visual calls
-- (The GP loop already calls GP_UpdateVisuals; we wire the v2 to run alongside)
local _origGPEnable = GP_Enable
GP_Enable = function()
    _origGPEnable()
    GP_CreateVisuals2()
end

local _origGPDisable = GP_Disable
GP_Disable = function()
    _origGPDisable()
    GP_RemoveVisuals2()
end

-- ============================================================
-- EXTEND INPUT HANDLER for new systems
-- ============================================================
table.insert(R.conns, UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end

    if i.KeyCode == S.epKey and S.epEnabled then
        if epActive then EP_DestroyDecoy() else EP_SpawnDecoy() end
    end

    if i.KeyCode == S.ijKey and S.ijEnabled then IJ_Jump() end

    if i.KeyCode == S.beKey and S.beEnabled then
        if S.beMode == "Hold" then
            if not R_beActive then BE_Enable() end
        else
            if R_beActive then BE_Disable() else BE_Enable() end
        end
    end

    if S.dcEnabled and i.KeyCode == S.dcKey then DC_Toggle2() end

    if S.tpEnabled then
        if i.KeyCode == S.tpCTKey then TP_ToCT() end
        if i.KeyCode == S.tpTKey  then TP_ToT() end
    end

    if S.hitAirEnabled and i.KeyCode == S.hitAirKey then
        if R.hitAirActive then HitAir_Remove() else HitAir_Create() end
    end

    if S.ijEnabled and i.KeyCode == S.ijKey then IJ_Jump() end
end))

table.insert(R.conns, UserInputService.InputEnded:Connect(function(i, gpe)
    if gpe then return end
    if S.beEnabled and i.KeyCode == S.beKey and S.beMode == "Hold" then BE_Disable() end
end))

-- ============================================================
-- EXTEND SETTINGS TABLE for new systems
-- ============================================================
S.epEnabled   = false
S.epKey       = Enum.KeyCode.C
S.epDist      = 3
S.ijEnabled   = false
S.ijKey       = Enum.KeyCode.Space
S.beEnabled   = false
S.beKey       = Enum.KeyCode.G
S.beMode      = "Hold"
S.beDist      = 5
S.hitAirEnabled = false
S.hitAirKey  = Enum.KeyCode.H
S.tpEnabled   = false
S.tpCTKey     = Enum.KeyCode.One
S.tpTKey      = Enum.KeyCode.Two
S.hsEnabled   = false
S.hsSoundId   = "139894735376184"
S.hsVolume    = 100
S.hsSelected  = "Default"
S.dcEnabled   = false
S.dcVisible   = false
S.dcKey       = Enum.KeyCode.P
S.skyboxEnabled = false
S.skyboxId    = "139989099041467"
S.skyboxStarsEnabled = true
S.skyboxStarsCount   = 20
S.selectedModel  = "None"
S.selectedSkybox = "None"
S.wmEnabled   = false  -- wallbang map
S.wbEnabled   = false  -- wallbang helper
S.rcEnabled   = false  -- remove collision
S.blurEnabled = false
S.blurSize    = 10

-- ============================================================
-- EXTRA TABS (Exploits + More)
-- ============================================================
-- We'll add these by attaching to the existing TabBar/TabPages
-- Since Lib is already built, we directly create new tab pages

local function AddNewTabs()
    local tabBar  = Main:FindFirstChild("M") and Main.M or Main
    -- find actual tab bar (tc) and page container (pc)
    local tc, pc
    for _, child in ipairs(Main:GetChildren()) do
        if child:IsA("Frame") and child.Size.Y.Offset == 40 then tc = child end
        if child:IsA("Frame") and child.BackgroundTransparency == 1 and child.Size.Y.Scale > 0.5 then pc = child end
    end
    if not tc or not pc then return end

    local function MakeTab(name)
        local btn = Instance.new("TextButton", tc)
        btn.Text, btn.Size, btn.BackgroundTransparency = name, UDim2.new(0,70,1,0), 1
        btn.Font, btn.TextSize, btn.TextColor3 = Enum.Font.Code, 13, Color3.fromRGB(140,140,140)

        local page = Instance.new("ScrollingFrame", pc)
        page.Size, page.BackgroundTransparency, page.Visible, page.BorderSizePixel = UDim2.new(1,0,1,0), 1, false, 0
        page.ScrollBarThickness, page.ScrollingDirection = 4, Enum.ScrollingDirection.Y
        page.CanvasSize, page.AutomaticCanvasSize = UDim2.new(0,0,0,0), Enum.AutomaticSize.Y

        local lc = Instance.new("Frame", page) lc.Size, lc.BackgroundTransparency, lc.AutomaticSize = UDim2.new(0.48,0,0,0), 1, Enum.AutomaticSize.Y
        Instance.new("UIListLayout", lc).Padding = UDim.new(0,12)
        local rc = Instance.new("Frame", page) rc.Size, rc.Position, rc.BackgroundTransparency, rc.AutomaticSize = UDim2.new(0.48,0,0,0), UDim2.new(0.52,0,0,0), 1, Enum.AutomaticSize.Y
        Instance.new("UIListLayout", rc).Padding = UDim.new(0,12)

        btn.MouseButton1Click:Connect(function()
            for _, p in ipairs(pc:GetChildren()) do if p:IsA("ScrollingFrame") then p.Visible = false end end
            for _, b in ipairs(tc:GetChildren()) do if b:IsA("TextButton") then b.TextColor3 = Color3.fromRGB(140,140,140) end end
            page.Visible, btn.TextColor3 = true, Color3.fromRGB(168,247,50)
        end)

        local T2 = {}
        function T2:NewGroupbox(side, title)
            local col = side == "Right" and rc or lc
            local grp = Instance.new("Frame", col) grp.Size, grp.BackgroundTransparency, grp.AutomaticSize = UDim2.new(1,0,0,0), 1, Enum.AutomaticSize.Y
            local brd = Instance.new("Frame", grp) brd.Size, brd.Position, brd.BackgroundColor3, brd.AutomaticSize = UDim2.new(1,0,0,0), UDim2.new(0,0,0,8), Color3.fromRGB(12,12,12), Enum.AutomaticSize.Y
            brd.BorderColor3 = Color3.fromRGB(45,45,45)
            local ttl = Instance.new("TextLabel", grp) ttl.Text, ttl.Position, ttl.AutomaticSize, ttl.BackgroundColor3, ttl.BorderSizePixel = title, UDim2.new(0,12,0,14), Enum.AutomaticSize.X, Color3.fromRGB(12,12,12), 0
            ttl.TextColor3, ttl.Font, ttl.TextSize, ttl.ZIndex = Color3.fromRGB(220,220,220), Enum.Font.Code, 12, 2
            local cnt = Instance.new("Frame", brd) cnt.Size, cnt.Position, cnt.BackgroundTransparency, cnt.AutomaticSize = UDim2.new(1,-16,0,0), UDim2.new(0,8,0,22), 1, Enum.AutomaticSize.Y
            Instance.new("UIListLayout", cnt).Padding = UDim.new(0,8)
            Instance.new("UIPadding", brd).PaddingBottom = UDim.new(0,8)

            local G = {}
            local function Tog(text, def, cb)
                local f = Instance.new("Frame", cnt) f.Size, f.BackgroundTransparency = UDim2.new(1,0,0,20), 1
                local box = Instance.new("Frame", f) box.Size, box.Position, box.BackgroundColor3 = UDim2.new(0,16,0,16), UDim2.new(0,0,0,2), Color3.fromRGB(25,25,25)
                Instance.new("UIStroke", box).Color = Color3.fromRGB(45,45,45)
                local lbl = Instance.new("TextLabel", f) lbl.Text, lbl.Size, lbl.Position, lbl.BackgroundTransparency = text, UDim2.new(1,-25,1,0), UDim2.new(0,25,0,0), 1
                lbl.TextXAlignment, lbl.TextColor3, lbl.Font, lbl.TextSize = Enum.TextXAlignment.Left, Color3.fromRGB(140,140,140), Enum.Font.Code, 13
                local b = Instance.new("TextButton", f) b.Size, b.BackgroundTransparency, b.Text = UDim2.new(1,0,1,0), 1, ""
                local en = def
                local function upd() box.BackgroundColor3 = en and Color3.fromRGB(168,247,50) or Color3.fromRGB(25,25,25) if cb then cb(en) end end
                b.MouseButton1Click:Connect(function() en = not en upd() end)
                upd()
            end
            function G:Toggle(text, def, cb) Tog(text,def,cb) return G end
            local function Sld(text, min, max, def, cb)
                local f = Instance.new("Frame", cnt) f.Size, f.BackgroundTransparency = UDim2.new(1,0,0,35), 1
                local lbl = Instance.new("TextLabel", f) lbl.Text, lbl.Size, lbl.BackgroundTransparency = text..": "..def, UDim2.new(1,0,0,15), 1
                lbl.TextXAlignment, lbl.TextColor3, lbl.Font, lbl.TextSize = Enum.TextXAlignment.Left, Color3.fromRGB(140,140,140), Enum.Font.Code, 13
                local bg = Instance.new("Frame", f) bg.Size, bg.Position, bg.BackgroundColor3 = UDim2.new(1,0,0,12), UDim2.new(0,0,0,18), Color3.fromRGB(25,25,25)
                bg.BorderColor3 = Color3.fromRGB(45,45,45)
                local fill = Instance.new("Frame", bg) fill.Size, fill.BackgroundColor3, fill.BorderSizePixel = UDim2.new((def-min)/MAX(max-min,1),0,1,0), Color3.fromRGB(168,247,50), 0
                local data = {bg=bg,fill=fill,lbl=lbl,text=text,min=min,max=max,val=def,cb=cb}
                bg.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then R.sliderDrag = data end end)
            end
            function G:Slider(text, min, max, def, cb) Sld(text,min,max,def,cb) return G end
            local function Btn(text, cb)
                local b = Instance.new("TextButton", cnt) b.Size, b.BackgroundColor3, b.BorderColor3 = UDim2.new(1,0,0,22), Color3.fromRGB(25,25,25), Color3.fromRGB(45,45,45)
                b.Text, b.TextColor3, b.Font, b.TextSize = text, Color3.fromRGB(220,220,220), Enum.Font.Code, 13
                b.MouseButton1Click:Connect(cb)
            end
            function G:Button(text, cb) Btn(text,cb) return G end
            local function Kb(text, def, cb)
                local f = Instance.new("Frame", cnt) f.Size, f.BackgroundTransparency = UDim2.new(1,0,0,20), 1
                local lbl = Instance.new("TextLabel", f) lbl.Text, lbl.Size, lbl.BackgroundTransparency = text, UDim2.new(0.6,0,1,0), 1
                lbl.TextXAlignment, lbl.TextColor3, lbl.Font, lbl.TextSize = Enum.TextXAlignment.Left, Color3.fromRGB(140,140,140), Enum.Font.Code, 13
                local btn2 = Instance.new("TextButton", f) btn2.Size, btn2.Position, btn2.BackgroundColor3 = UDim2.new(0.3,0,1,0), UDim2.new(0.7,0,0,0), Color3.fromRGB(22,22,22)
                btn2.BorderColor3, btn2.Font, btn2.TextSize, btn2.TextColor3 = Color3.fromRGB(45,45,45), Enum.Font.Code, 11, Color3.fromRGB(140,140,140)
                btn2.Text = "["..def.Name.."]"
                local waiting = false
                btn2.MouseButton1Click:Connect(function() waiting,btn2.Text,btn2.TextColor3 = true,"[...]",Color3.fromRGB(168,247,50) end)
                table.insert(R.conns, UserInputService.InputBegan:Connect(function(i)
                    if waiting and i.UserInputType == Enum.UserInputType.Keyboard then
                        waiting,btn2.Text,btn2.TextColor3 = false,"["..i.KeyCode.Name.."]",Color3.fromRGB(140,140,140)
                        if cb then cb(i.KeyCode) end
                    end
                end))
            end
            function G:Keybind(text, def, cb) Kb(text,def,cb) return G end
            local function Ddwn(text, opts, def, cb)
                local f = Instance.new("Frame", cnt) f.Size, f.BackgroundTransparency, f.ClipsDescendants, f.ZIndex = UDim2.new(1,0,0,40), 1, false, 10
                local lbl = Instance.new("TextLabel", f) lbl.Text, lbl.Size, lbl.BackgroundTransparency = text, UDim2.new(1,0,0,15), 1
                lbl.TextXAlignment, lbl.TextColor3, lbl.Font, lbl.TextSize = Enum.TextXAlignment.Left, Color3.fromRGB(140,140,140), Enum.Font.Code, 13
                local box = Instance.new("TextButton", f) box.Size, box.Position, box.BackgroundColor3 = UDim2.new(1,0,0,20), UDim2.new(0,0,0,18), Color3.fromRGB(25,25,25)
                box.BorderColor3, box.Text, box.TextColor3, box.Font, box.TextSize = Color3.fromRGB(45,45,45), def.." ▼", Color3.fromRGB(220,220,220), Enum.Font.Code, 13
                local ol = Instance.new("Frame", f) ol.Size, ol.Position, ol.BackgroundColor3, ol.BorderColor3, ol.Visible, ol.ZIndex = UDim2.new(1,0,0,#opts*20), UDim2.new(0,0,0,38), Color3.fromRGB(20,20,20), Color3.fromRGB(45,45,45), false, 100
                Instance.new("UIListLayout", ol)
                local cur, open = def, false
                for _, opt in ipairs(opts) do
                    local ob = Instance.new("TextButton", ol) ob.Size, ob.BackgroundColor3, ob.BorderSizePixel = UDim2.new(1,0,0,20), Color3.fromRGB(25,25,25), 0
                    ob.Text, ob.Font, ob.TextSize, ob.ZIndex = opt, Enum.Font.Code, 12, 101
                    ob.TextColor3 = opt==cur and Color3.fromRGB(168,247,50) or Color3.fromRGB(140,140,140)
                    ob.MouseButton1Click:Connect(function()
                        cur, box.Text, ol.Visible, open = opt, opt.." ▼", false, false
                        f.Size = UDim2.new(1,0,0,40)
                        for _, b2 in ipairs(ol:GetChildren()) do if b2:IsA("TextButton") then b2.TextColor3 = b2.Text==cur and Color3.fromRGB(168,247,50) or Color3.fromRGB(140,140,140) end end
                        if cb then cb(cur) end
                    end)
                end
                box.MouseButton1Click:Connect(function() open=not open ol.Visible=open f.Size=open and UDim2.new(1,0,0,40+#opts*20) or UDim2.new(1,0,0,40) end)
            end
            function G:Dropdown(text, opts, def, cb) Ddwn(text,opts,def,cb) return G end
            local function TB(text, def, cb)
                local f = Instance.new("Frame", cnt) f.Size, f.BackgroundTransparency = UDim2.new(1,0,0,40), 1
                local lbl = Instance.new("TextLabel", f) lbl.Text, lbl.Size, lbl.BackgroundTransparency = text, UDim2.new(1,0,0,15), 1
                lbl.TextXAlignment, lbl.TextColor3, lbl.Font, lbl.TextSize = Enum.TextXAlignment.Left, Color3.fromRGB(140,140,140), Enum.Font.Code, 13
                local tb2 = Instance.new("TextBox", f) tb2.Size, tb2.Position, tb2.BackgroundColor3, tb2.BorderColor3 = UDim2.new(1,0,0,20), UDim2.new(0,0,0,18), Color3.fromRGB(25,25,25), Color3.fromRGB(45,45,45)
                tb2.Text, tb2.PlaceholderText, tb2.TextColor3, tb2.Font, tb2.TextSize, tb2.ClearTextOnFocus = def or "", "Enter...", Color3.fromRGB(220,220,220), Enum.Font.Code, 12, false
                tb2.FocusLost:Connect(function() if cb then cb(tb2.Text) end end)
            end
            function G:TextBox(text, def, cb) TB(text,def,cb) return G end
            return G
        end
        return T2
    end

    -- EXPLOITS TAB
    do
        local Tab = MakeTab("Exploits")

        local ep = Tab:NewGroupbox("Left", "Exploit Position")
        ep:Toggle("Enable", false, function(v) S.epEnabled=v end)
        ep:Keybind("Key", Enum.KeyCode.C, function(k) S.epKey=k end)
        ep:Slider("Distance", 1, 10, 3, function(v) S.epDist=v end)

        local ij = Tab:NewGroupbox("Left", "Infinity Jump")
        ij:Toggle("Enable", false, function(v)
            S.ijEnabled = v
            if not v then IJ_RemovePart() end
        end)
        ij:Keybind("Key", Enum.KeyCode.Space, function(k) S.ijKey=k end)

        local ha = Tab:NewGroupbox("Left", "Hit Air")
        ha:Toggle("Enable", false, function(v)
            S.hitAirEnabled = v
            if not v then HitAir_Remove() end
        end)
        ha:Keybind("Key", Enum.KeyCode.H, function(k) S.hitAirKey=k end)

        local be = Tab:NewGroupbox("Right", "Barrel Extend")
        be:Toggle("Enable", false, function(v)
            S.beEnabled = v
            if not v and R_beActive then BE_Disable() end
        end)
        be:Keybind("Key", Enum.KeyCode.G, function(k) S.beKey=k end)
        be:Dropdown("Mode", {"Hold","Toggle"}, "Hold", function(v) S.beMode=v end)

        local tp2 = Tab:NewGroupbox("Right", "Teleport")
        tp2:Toggle("Enable", false, function(v) S.tpEnabled=v end)
        tp2:Keybind("CT Spawn", Enum.KeyCode.One, function(k) S.tpCTKey=k end)
        tp2:Keybind("T Spawn", Enum.KeyCode.Two, function(k) S.tpTKey=k end)

        local dc2 = Tab:NewGroupbox("Right", "Debug Console")
        dc2:Toggle("Enable", false, function(v)
            S.dcEnabled = v
            if v and not dcFrame then DC_CreateUI2() end
        end)
        dc2:Keybind("Key", Enum.KeyCode.P, function(k) S.dcKey=k end)
        dc2:Button("Show/Hide", function() DC_Toggle2() end)
        dc2:Button("Clear", function()
            if dcFrame then
                local scroll = dcFrame:FindFirstChild("Logs")
                if scroll then for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end end
                dcLogs = {}
            end
        end)

        local wb2 = Tab:NewGroupbox("Left", "Wallbang Helper")
        wb2:Toggle("Enable", false, function(v)
            S.wbEnabled = v
            if v then WB_Enable() R.hotkeys["Wallbang"]={active=true,key="ON"}
            else WB_Disable() R.hotkeys["Wallbang"]=nil end
            UpdateHotkeyList()
        end)

        local wbm = Tab:NewGroupbox("Left", "Wallbang Map")
        wbm:Toggle("Enable", false, function(v)
            S.wmEnabled = v
            if v then WBMap_Enable() R.hotkeys["WB Map"]={active=true,key="ON"}
            else WBMap_Disable() R.hotkeys["WB Map"]=nil end
            UpdateHotkeyList()
        end)

        local rc2 = Tab:NewGroupbox("Right", "Remove Collision")
        rc2:Toggle("Enable", false, function(v)
            S.rcEnabled = v
            if v then RC_Enable() R.hotkeys["NoCollision"]={active=true,key="ON"}
            else RC_Disable() R.hotkeys["NoCollision"]=nil end
            UpdateHotkeyList()
        end)
    end

    -- MORE TAB
    do
        local Tab = MakeTab("More")

        local hs2 = Tab:NewGroupbox("Left", "Hit Sound")
        hs2:Toggle("Enable", false, function(v) S.hsEnabled=v end)
        hs2:Dropdown("Sound", HitSoundsList, "Default", function(v)
            S.hsSelected = v
            if v ~= "Custom" then S.hsSoundId = HitSounds[v] or HitSounds["Default"] end
        end)
        hs2:TextBox("Custom Sound ID", "", function(v) if S.hsSelected=="Custom" and v~="" then S.hsSoundId=v end end)
        hs2:Slider("Volume", 0, 200, 100, function(v) S.hsVolume=v end)
        hs2:Button("Test Sound", function() PlayHitSound() end)

        local mdl2 = Tab:NewGroupbox("Left", "Custom Model")
        mdl2:Dropdown("Select", ModelList, "None", function(v) S.selectedModel=v end)
        mdl2:Button("Apply Model", function() if S.selectedModel~="None" then ApplyModel(S.selectedModel) end end)
        mdl2:Button("Remove Model", function() if modelConn then modelConn:Disconnect() modelConn=nil end end)

        local sky2 = Tab:NewGroupbox("Right", "Custom Skybox")
        sky2:Dropdown("Select", SkyboxList, "None", function(v) S.selectedSkybox=v end)
        sky2:Toggle("Stars Effect", true, function(v) S.skyboxStarsEnabled=v end)
        sky2:Slider("Stars Count", 5, 50, 20, function(v) S.skyboxStarsCount=v end)
        sky2:TextBox("Custom ID", "", function(v) if v~="" then S.skyboxId=v end end)
        sky2:Button("Apply Skybox", function() if S.selectedSkybox and S.selectedSkybox~="None" then ApplySkybox(S.selectedSkybox) end end)
        sky2:Button("Remove Skybox", function() ApplySkybox("None") end)

        local ab2 = Tab:NewGroupbox("Right", "Anim Breaker")
        ab2:Toggle("Enable", false, function(v)
            S.abEnabled = v
            if not v and R.abActive then AB_Disable() end
        end)
        ab2:Keybind("Key", Enum.KeyCode.B, function(k) S.abKey=k end)

        local adt2 = Tab:NewGroupbox("Right", "Auto Double Tap")
        adt2:Toggle("Enable", false, function(v) S.dtAuto=v end)
        adt2:Slider("Delay (ms)", 100, 1000, 200, function(v) S.dtAutoDelay=v end)
    end
end

-- Run tab builder after GUI is ready
task.defer(function()
    task.wait(0.1)
    pcall(AddNewTabs)
end)

-- Menu key: single dedicated connection (not stored in R.conns so it's never double-fired)
UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == S.menuKey then
        R.visible = not R.visible
        Main.Visible = R.visible
        ApplyMenuBlur(R.visible)
    end
end)

-- Patch CharacterAdded to also clean up new systems
Player.CharacterAdded:Connect(function()
    EP_Free()
    if R_beActive then BE_Disable() end
    IJ_RemovePart()
    HitAir_Remove()
    GP_RemoveVisuals2()
    for _, s in pairs(skyboxStars) do pcall(function() s:Destroy() end) end
    skyboxStars = {}
end)

print("[HvH] Full feature set loaded — all systems active.")
