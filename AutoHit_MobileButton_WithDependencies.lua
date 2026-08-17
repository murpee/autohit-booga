-- AutoHit dependency bundle extracted from the original Aster script.
-- Core AutoHit code is preserved verbatim where included below.
-- No webhook/reporting code is included.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer
Settings = Settings or {}
Settings.AutoHitStartEnabled = Settings.AutoHitStartEnabled == true
Settings.MobileAutoHitButton = true
Settings.AutoHitCooldown = tonumber(Settings.AutoHitCooldown) or 0.05
Settings.PlayerReachRange = tonumber(Settings.PlayerReachRange) or 8
Settings.PlayerTargetCount = tonumber(Settings.PlayerTargetCount) or 1
Settings.PlayerSwingPackedMultiHit = Settings.PlayerSwingPackedMultiHit == true
autoHitSelection = autoHitSelection or "NoSwingHit"
autoHitLoopActive = false
autoHitRunning = false
reachReachExcluded = {"Bow", "Potion", "Sling", "Saddle", "Fishing Rod", "Horn", "Shovel"}
ByteNetReliable = ByteNetReliable or ReplicatedStorage:FindFirstChild("ByteNetReliable")
PACKET_IDS = PACKET_IDS or {}
trackConnection = trackConnection or function(_, conn) return conn end
trackWebhookResourceBreaks = function(_) end
shouldHealSwingControl = shouldHealSwingControl or function() return false end

function getPacketId(packetName)
    if not packetName or packetName == "" then return nil end
    return PACKET_IDS[packetName]
end

-- Original CFrame serializer.
function write18ByteCFrame(b, offset, cf)
    local pos = cf.Position
    
    local _, _, _, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:GetComponents()
    local qx, qy, qz, qw
    local tr = R00 + R11 + R22
    if tr > 0 then
        local S = math.sqrt(tr + 1.0) * 2
        qw = 0.25 * S
        qx = (R21 - R12) / S
        qy = (R02 - R20) / S
        qz = (R10 - R01) / S
    elseif (R00 > R11) and (R00 > R22) then
        local S = math.sqrt(1.0 + R00 - R11 - R22) * 2
        qw = (R21 - R12) / S
        qx = 0.25 * S
        qy = (R01 + R10) / S
        qz = (R02 + R20) / S
    elseif R11 > R22 then
        local S = math.sqrt(1.0 + R11 - R00 - R22) * 2
        qw = (R02 - R20) / S
        qx = (R01 + R10) / S
        qy = 0.25 * S
        qz = (R12 + R21) / S
    else
        local S = math.sqrt(1.0 + R22 - R00 - R11) * 2
        qw = (R10 - R01) / S
        qx = (R02 + R20) / S
        qy = (R12 + R21) / S
        qz = 0.25 * S
    end
    
    local len = math.sqrt(qx*qx + qy*qy + qz*qz + qw*qw)
    qx, qy, qz, qw = qx/len, qy/len, qz/len, qw/len
    
    if qw < 0 then
        qx, qy, qz, qw = -qx, -qy, -qz, -qw
    end
    
    buffer.writef32(b, offset, pos.X)

-- Original tool/ally helpers.
function isAnyToolEquipped()
    local playersFolder = workspace:FindFirstChild("Players")
    if playersFolder then
        local plrFolder = playersFolder:FindFirstChild(plr.Name)
        if plrFolder then
            local toolsFolder = plrFolder:FindFirstChild("Tools")
            if toolsFolder and #toolsFolder:GetChildren() > 0 then
                return true
            end
        end
    end
    if plr.Character and plr.Character:FindFirstChildOfClass("Tool") then
        return true

function isAlly(player)
    if not player or not player.Team then return false end
    
    local theirTeam = player.Team.Name
    if not theirTeam then return false end
    
    -- EXCEPTION: NoTribe members are never allies (always targetable)
    if theirTeam == "NoTribe" then return false end

    local plr = game:GetService("Players").LocalPlayer
    if not plr or not plr.Team then return false end
    local myTeam = plr.Team.Name
    
    -- If same team, they are teammates (handled by default team check, but good to have)
    if myTeam == theirTeam then 
        -- EXCEPTION: NoTribe members are never allies (always targetable)
        if myTeam == "NoTribe" then return false end
        return true 
    end
    
    -- Check cached tribe data
    if TribeDataCache then
        -- Check if my tribe has them as ally
        local myTribeData = TribeDataCache[myTeam]
        if myTribeData and myTribeData.allies then
            if table.find(myTribeData.allies, theirTeam) then
                return true
            end
        end
        
        -- Check if their tribe has me as ally (Symmetric check)
        local theirTribeData = TribeDataCache[theirTeam]
        if theirTribeData and theirTribeData.allies then
             if table.find(theirTribeData.allies, myTeam) then
                return true
            end

-- Original SwingTool packet writers.
function fireByteNetSwingTool(targetEntries, hrp, opts)
    opts = opts or {}
    if not targetEntries or #targetEntries == 0 or not ByteNetReliable or not hrp then return end

    local clean = {}
    for _, t in ipairs(targetEntries) do
        local id = math.floor(tonumber(t and t.eid) or 0)
        if id > 0 then
            table.insert(clean, { eid = id, pos = t.pos, resourceName = t.resourceName })
        end
    end
    if #clean == 0 then return end
    targetEntries = clean

    local swingId = getPacketId("SwingTool")
    if not swingId then return end

    local function computeFromPos()
        local fromPos = hrp.Position
        if opts.fromPos then
            fromPos = opts.fromPos
        end
        if not opts.skipLead then
            local vel = hrp.AssemblyLinearVelocity or Vector3.zero
            local horizontalVel = Vector3.new(vel.X, 0, vel.Z)
            local tweening = opts.tweening
            if tweening == nil then
                tweening = (isTweening == true) or (horizontalVel.Magnitude > 18)
            end
            local leadTime = tweening and (opts.leadTime ~= nil and opts.leadTime or 0.12) or (opts.leadTime or 0)
            fromPos = fromPos + (horizontalVel * leadTime)
        end
        return fromPos
    end

    local function cframeForBatch(batch, fromPos)
        if #batch == 1 then
            local tp = batch[1].pos
            if typeof(tp) == "Vector3" and (tp - fromPos).Magnitude > 0.01 then
                return CFrame.lookAt(fromPos, tp)
            end
            return hrp.CFrame
        end
        local sum = Vector3.zero
        local n = 0
        for _, t in ipairs(batch) do
            if typeof(t.pos) == "Vector3" then
                sum = sum + t.pos
                n = n + 1
            end
        end
        if n > 0 then
            local center = sum / n
            if (center - fromPos).Magnitude > 0.01 then
                return CFrame.lookAt(fromPos, center)
            end
        end
        return hrp.CFrame
    end

    local maxPerPacket = math.clamp(opts.maxPerPacket or 32, 1, 64)
    local timeStep = opts.timeStep or 0.01
    local baseTime = opts.baseTime or (time() - timeStep)
    local run = game:GetService("RunService")
    local pktIdx = 0

    for startIdx = 1, #targetEntries, maxPerPacket do
        if pktIdx > 0 then
            run.Heartbeat:Wait()
        end
        pktIdx = pktIdx + 1

        local batch = {}
        for i = startIdx, math.min(startIdx + maxPerPacket - 1, #targetEntries) do
            table.insert(batch, targetEntries[i])
        end
        local n = #batch
        local fromPos = computeFromPos()
        local cf = opts.cframe or cframeForBatch(batch, fromPos)
        -- 2 header + 18 cframe + 2 count + 5*n hits + 8 time
        local b = buffer.create(30 + 5 * n)
        buffer.writeu8(b, 0, 0)
        buffer.writeu8(b, 1, swingId)
        write18ByteCFrame(b, 2, cf)
        buffer.writeu16(b, 20, n)
        local o = 22
        for _, t in ipairs(batch) do
            buffer.writeu8(b, o, 0)
            buffer.writeu32(b, o + 1, math.floor(tonumber(t.eid) or 0))
            o = o + 5
        end
        buffer.writef64(b, o, baseTime + (pktIdx * timeStep))
        trackWebhookResourceBreaks(batch)
        ByteNetReliable:FireServer(b)
    end
end

local _auraLegitSwingAnimTrack = nil
local _auraLegitSwingLastChar = nil
local _auraLegitSwingLastPlay = 0

-- Same local swing feel as Combat SwingHit: ClientSwing + slash anim (+ tool Activate).
function playAuraLegitSwing()
    if not ByteNetReliable then return end
    pcall(function()
        local swingId = getPacketId("ClientSwing")
        if swingId then
            local swingBuf = buffer.create(2)
            buffer.writeu8(swingBuf, 0, 0)
            buffer.writeu8(swingBuf, 1, swingId)
            ByteNetReliable:FireServer(swingBuf)
        end
    end)
    pcall(function()
        if os.clock() - _auraLegitSwingLastPlay < 0.4 then return end
        _auraLegitSwingLastPlay = os.clock()
        local char = plr.Character
        if not char then return end
        if char ~= _auraLegitSwingLastChar then
            _auraLegitSwingLastChar = char
            _auraLegitSwingAnimTrack = nil
        end
        if not _auraLegitSwingAnimTrack then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:FindFirstChild("Animator"))
            if animator then
                local anim = Instance.new("Animation")
                anim.AnimationId = "rbxassetid://10761451679"
                _auraLegitSwingAnimTrack = animator:LoadAnimation(anim)
            end
        end
        if _auraLegitSwingAnimTrack then
            _auraLegitSwingAnimTrack:Play()
        end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                pcall(function() child:Activate() end)
                break
            end
        end
    end)
end

-- Same current SwingTool wire as fireByteNetSwingTool (kept for older call sites).
function fireByteNetSwingToolPackedMultiHit(targetEntries, hrp, opts)
    opts = opts or {}
    if not targetEntries or #targetEntries == 0 or not hrp then return end

    local seen = {}
    local clean = {}
    local maxN = math.clamp(opts.maxTargets or 9, 1, 9)
    for _, t in ipairs(targetEntries) do
        local id = math.floor(tonumber(t and t.eid) or 0)
        if id > 0 and not seen[id] then
            seen[id] = true
            table.insert(clean, t)
            if #clean >= maxN then break end
        end
    end
    if #clean == 0 then return end

    fireByteNetSwingTool(clean, hrp, {
        maxPerPacket = maxN,
        fromPos = opts.fromPos,
        cframe = opts.cframe,

-- Original AutoHit core.
local function startAutoHitLoop(useSwing)
    if autoHitLoopActive then return end
    autoHitLoopActive = true

    task.spawn(function()
        local targetAnimId = "rbxassetid://10761451679"
        local animTrack, lastAnimPlay, lastHitPlay, lastChar = nil, 0, 0, nil
        local manualAttackLock = false

        if useSwing then
            trackConnection("AutoHitManualLock", UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                manualAttackLock = true
                task.delay(0.2, function() manualAttackLock = false end)
            end))
        end

        local function findNetworkID(object)
            for _, value in pairs(object:GetAttributes()) do
                if typeof(value) == "number" and value > 1000 then return value end
            end
            local val = object:FindFirstChildWhichIsA("IntValue", true) or object:FindFirstChildWhichIsA("NumberValue", true)
            if val and val.Value > 1000 then return val.Value end
            return nil
        end

        local function queueTargets(targetRows)
            if #targetRows == 0 or not ByteNetReliable then return end
            if useSwing then
                local toolsFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild(plr.Name) and workspace.Players[plr.Name]:FindFirstChild("Tools")
                if not toolsFolder or #toolsFolder:GetChildren() == 0 then return end
                local toolName = toolsFolder:GetChildren()[1].Name:lower()
                for _, kw in ipairs(reachReachExcluded) do
                    if string.find(toolName, kw:lower(), 1, true) then return end
                end
            end

            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local entries = {}
            for _, r in ipairs(targetRows) do
                if type(r) == "table" and r.eid then
                    table.insert(entries, { eid = r.eid, pos = r.pos })
                else
                    table.insert(entries, { eid = r })
                end
            end
            if #entries == 0 then return end

            local maxPick = math.clamp(tonumber(Settings.PlayerTargetCount) or 1, 1, 5)
            if Settings.PlayerSwingPackedMultiHit then
                fireByteNetSwingToolPackedMultiHit(entries, hrp, { maxTargets = maxPick })
            else
                fireByteNetSwingTool(entries, hrp, { maxPerPacket = maxPick })
            end

            if useSwing then
                pcall(function()
                    local swingId = getPacketId("ClientSwing")
                    if swingId then
                        local swingBuf = buffer.create(2)
                        buffer.writeu8(swingBuf, 0, 0)
                        buffer.writeu8(swingBuf, 1, swingId)
                        ByteNetReliable:FireServer(swingBuf)
                    end
                end)
                pcall(function()
                    if os.clock() - lastAnimPlay < 0.4 then return end
                    lastAnimPlay = os.clock()
                    local char = plr.Character
                    if char and char ~= lastChar then
                        lastChar = char
                        animTrack = nil
                    end
                    if char and not animTrack then
                        local animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
                        if animator then
                            local anim = Instance.new("Animation")
                            anim.AnimationId = targetAnimId
                            animTrack = animator:LoadAnimation(anim)
                        end
                    end
                    if animTrack then animTrack:Play() end
                end)
            end
        end

        while Settings.AutoHitStartEnabled do
            pcall(function()
                local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local range = Settings.PlayerReachRange or 8
                local targets = {}
                local noTribe = game:GetService("Teams"):FindFirstChild("NoTribe")
                local myTeam = plr.Team
                local hrpPos = hrp.Position
                local detectionRange = range + 10
                local rangeSq = range * range
                local detectionRangeSq = detectionRange * detectionRange

                for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
                    if other ~= plr and other.Character then
                        local char = other.Character
                        local eid = findNetworkID(char) or char:GetAttribute("EntityID")
                        local ppart = char:FindFirstChild("HumanoidRootPart")
                        local isTargetable = true
                        if myTeam and myTeam ~= noTribe and other.Team == myTeam then
                            isTargetable = false
                        end
                        if isTargetable and isAlly(other) then
                            isTargetable = false
                        end
                        if isTargetable and eid and ppart then
                            local diff = ppart.Position - hrpPos
                            local distSq = diff:Dot(diff)
                            if distSq <= detectionRangeSq then
                                local flatDiff = Vector3.new(diff.X, 0, diff.Z)
                                local flatDistSq = flatDiff:Dot(flatDiff)
                                if flatDistSq <= detectionRangeSq and math.abs(diff.Y) <= 20 then
                                    table.insert(targets, { eid = eid, distSq = flatDistSq, rangeSq = rangeSq, pos = ppart.Position })
                                end
                            end
                        end
                    end
                end

                if #targets == 0 then return end
                table.sort(targets, function(a, b) return a.distSq < b.distSq end)
                local maxPick = math.clamp(tonumber(Settings.PlayerTargetCount) or 1, 1, 5)
                local selectedRows = {}
                for i = 1, #targets do
                    if #selectedRows >= maxPick then break end
                    if targets[i].distSq <= targets[i].rangeSq then
                        table.insert(selectedRows, { eid = targets[i].eid, pos = targets[i].pos })
                    end
                end
                if #selectedRows == 0 then return end

                if useSwing then
                    if shouldHealSwingControl and shouldHealSwingControl() then return end
                    if isAnyToolEquipped() and not manualAttackLock and os.clock() - lastHitPlay > 0.12 then
                        lastHitPlay = os.clock()
                        queueTargets(selectedRows)
                    end
                else
                    queueTargets(selectedRows)
                end
            end)
            task.wait(Settings.AutoHitCooldown or 0.05)
        end

        autoHitLoopActive = false
    end)
end

startNoSwingAutoHit = function()
    startAutoHitLoop(false)
end

startSwingAutoHit = function()
    startAutoHitLoop(true)
end

stopAutoHit = function()
    autoHitLoopActive = false

-- Standalone draggable mobile AutoHit button.
do
    local gui = Instance.new("ScreenGui")
    gui.Name = "AsterAutoHitGui"
    gui.ResetOnSpawn = false
    gui.Parent = plr:WaitForChild("PlayerGui")

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(120, 42)
    button.Position = UDim2.new(1, -140, 0.55, 0)
    button.BackgroundTransparency = 0.12
    button.TextSize = 15
    button.Font = Enum.Font.GothamBold
    button.Text = "AutoHit: OFF"
    button.Parent = gui
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)

    local dragging, dragStart, startPos
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, dragStart, startPos = true, input.Position, button.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - dragStart
        button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end)

    local function refresh()
        button.Text = Settings.AutoHitStartEnabled and "AutoHit: ON" or "AutoHit: OFF"
    end
    button.Activated:Connect(function()
        Settings.AutoHitStartEnabled = not Settings.AutoHitStartEnabled
        autoHitRunning = Settings.AutoHitStartEnabled
        if Settings.AutoHitStartEnabled then
            if autoHitSelection == "NoSwingHit" then startNoSwingAutoHit() else startSwingAutoHit() end
        else
            stopAutoHit()
        end
        refresh()
    end)
    refresh()
end
