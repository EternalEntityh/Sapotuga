local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local running = false
local autoRollEnabled = true
local autoBuyEnabled = true
local autoTpEnabled = true
local antiAfkEnabled = true
local targetRarity = "Boundless"
local spinDelay = 5
local lastSecretTime = 0
local SECRET_COOLDOWN = 5
local statusLocked = false
local statusLockUntil = 0

-- ═══════════════ SELECTOR DE TANQUES ═══════════════
-- id = valor del atributo RobotId (en minúsculas)
local TANKS = {
    {id = "boundless_abductor", name = "Abductor"},
    {id = "boundless_tuskbreaker", name = "Tuskbreaker"},
    {id = "boundless_kernel_panic", name = "Kernel Panic"},
    {id = "boundless_desync", name = "Desync"},
    {id = "boundless_sky_pirate", name = "Sky Pirate"},
}

local selectedTanks = {}
for _, t in ipairs(TANKS) do
    selectedTanks[t.id] = true -- por defecto todos activados
end

local function selectedCount()
    local n = 0
    for _, t in ipairs(TANKS) do
        if selectedTanks[t.id] then n += 1 end
    end
    return n
end

local function setAllTanks(value)
    for _, t in ipairs(TANKS) do
        selectedTanks[t.id] = value
    end
end
-- ═══════════════════════════════════════════════════

LocalPlayer.Idled:Connect(function()
    if antiAfkEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end
end)

task.spawn(function()
    while true do
        task.wait(30)
        if antiAfkEnabled then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local hrp = char.HumanoidRootPart
                local pos = hrp.CFrame
                hrp.CFrame = pos * CFrame.new(0, 0, 0.5)
                task.wait(0.1)
                hrp.CFrame = pos
            end
        end
    end
end)

-- paleta
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(226, 186, 64)
local GOLD_LIGHT = Color3.fromRGB(246, 221, 133)
local GOLD_DARK = Color3.fromRGB(150, 106, 12)
local GOLD_SOFT = Color3.fromRGB(252, 244, 214)
local SILVER = Color3.fromRGB(192, 196, 204)
local SILVER_LIGHT = Color3.fromRGB(236, 238, 243)
local SILVER_DARK = Color3.fromRGB(120, 126, 138)
local STOP_COLOR = Color3.fromRGB(150, 156, 168)
local INK = Color3.fromRGB(52, 54, 62)
local PANEL_SOFT = Color3.fromRGB(248, 249, 251)

local SINE = Enum.EasingStyle.Sine
local INOUT = Enum.EasingDirection.InOut

local function tween(obj, time, props, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function make(class, props, parent)
    local obj = Instance.new(class)
    obj.BorderSizePixel = 0
    for k, v in pairs(props) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function round(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end

local function stroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Color = color
    s.Thickness = thickness
    s.Parent = obj
    return s
end

local function textStroke(label, thickness)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(110, 78, 10)
    s.Thickness = thickness
    s.Transparency = 0.45
    s.Parent = label
    return s
end

local function gradient(obj, c0, c1, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c0, c1)
    g.Rotation = rotation
    g.Parent = obj
    return g
end

local function shimmer(obj, pause)
    local base = Color3.fromRGB(205, 205, 205)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, base),
        ColorSequenceKeypoint.new(0.42, base),
        ColorSequenceKeypoint.new(0.5, WHITE),
        ColorSequenceKeypoint.new(0.58, base),
        ColorSequenceKeypoint.new(1, base),
    })
    g.Rotation = 20
    g.Parent = obj
    task.spawn(function()
        while g.Parent do
            g.Offset = Vector2.new(-1, 0)
            tween(g, 1.3, {Offset = Vector2.new(1, 0)}, SINE, INOUT)
            task.wait(pause)
        end
    end)
end

local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function hoverFx(btn, base, big, small, onEnter, onLeave)
    btn.MouseEnter:Connect(function()
        tween(btn, 0.15, {Size = big})
        onEnter()
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.15, {Size = base})
        onLeave()
    end)
    btn.MouseButton1Down:Connect(function()
        tween(btn, 0.08, {Size = small})
    end)
    btn.MouseButton1Up:Connect(function()
        tween(btn, 0.14, {Size = touchOnly and base or big}, Enum.EasingStyle.Back)
    end)
end

local function newButton(y, height)
    return make("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, y),
        Size = UDim2.new(1, -32, 0, height),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    }, nil)
end

-- ventana
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SapotugaRoll"
screenGui.ResetOnSpawn = false

local frame = make("Frame", {
    Size = UDim2.new(0, 290, 0, 552), -- antes 424: crece para el selector
    Position = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = WHITE,
    Active = true,
}, screenGui)
round(frame, 14)
gradient(frame, WHITE, SILVER_LIGHT, 90)

local frameStroke = stroke(frame, WHITE, 2.5)
local border = Instance.new("UIGradient")
border.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, GOLD),
    ColorSequenceKeypoint.new(0.3, WHITE),
    ColorSequenceKeypoint.new(0.55, SILVER),
    ColorSequenceKeypoint.new(0.8, GOLD_LIGHT),
    ColorSequenceKeypoint.new(1, GOLD),
})
border.Parent = frameStroke
TweenService:Create(border, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {Rotation = 360}):Play()

-- cabecera
local titleBar = make("Frame", {
    Position = UDim2.new(0, 10, 0, 10),
    Size = UDim2.new(1, -20, 0, 42),
    BackgroundColor3 = GOLD,
    Active = true,
}, frame)
round(titleBar, 10)
stroke(titleBar, GOLD_LIGHT, 1.2)
shimmer(titleBar, 3)

local title = make("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "By Sapotuga777",
    TextColor3 = WHITE,
    Font = Enum.Font.GothamBlack,
    TextSize = 18,
}, titleBar)
textStroke(title, 1.5)

for side = 0, 1 do
    local gem = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(side, side == 0 and 18 or -18, 0.5, 0),
        Size = UDim2.new(0, 8, 0, 8),
        Rotation = 45,
        BackgroundColor3 = WHITE,
    }, titleBar)
    TweenService:Create(gem, TweenInfo.new(1.1, SINE, INOUT, -1, true, side * 0.5), {BackgroundTransparency = 0.65}):Play()
end

local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- segundos
make("TextLabel", {
    Position = UDim2.new(0, 18, 0, 66),
    Size = UDim2.new(0, 100, 0, 32),
    BackgroundTransparency = 1,
    Text = "Segundos:",
    TextColor3 = INK,
    Font = Enum.Font.GothamMedium,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
}, frame)

local delayBox = make("TextBox", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 66),
    Size = UDim2.new(0, 110, 0, 32),
    BackgroundColor3 = PANEL_SOFT,
    Text = "5",
    TextColor3 = INK,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
}, frame)
round(delayBox, 8)
local delayStroke = stroke(delayBox, SILVER, 1.2)

delayBox.Focused:Connect(function()
    tween(delayStroke, 0.2, {Color = GOLD, Thickness = 1.8})
end)
delayBox.FocusLost:Connect(function()
    tween(delayStroke, 0.2, {Color = SILVER, Thickness = 1.2})
end)

-- toggles
local rows = {}

local function newToggle(text, y, getState, flip)
    local btn = newButton(y, 36)
    btn.Parent = frame

    local face = make("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = WHITE,
    }, btn)
    round(face, 10)
    gradient(face, WHITE, SILVER_LIGHT, 90)
    local faceStroke = stroke(face, SILVER, 1.2)

    local label = make("TextLabel", {
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -64, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    }, btn)

    local track = make("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 38, 0, 20),
    }, btn)
    round(track, 10)

    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = WHITE,
    }, track)
    round(knob, 8)
    stroke(knob, SILVER_DARK, 1).Transparency = 0.6

    local function paint(time)
        local on = getState()
        label.Text = text .. (on and ": SÍ" or ": NO")
        tween(label, time, {TextColor3 = on and GOLD_DARK or SILVER_DARK})
        tween(track, time, {BackgroundColor3 = on and GOLD or SILVER})
        tween(knob, time, {Position = on and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)}, Enum.EasingStyle.Back)
        tween(faceStroke, time, {Color = on and GOLD or SILVER})
    end
    paint(0)

    hoverFx(btn, UDim2.new(1, -32, 0, 36), UDim2.new(1, -26, 0, 38), UDim2.new(1, -38, 0, 33), function()
        tween(faceStroke, 0.15, {Color = GOLD_LIGHT, Thickness = 1.8})
    end, function()
        tween(faceStroke, 0.15, {Color = getState() and GOLD or SILVER, Thickness = 1.2})
    end)

    btn.MouseButton1Click:Connect(function()
        flip()
        paint(0.22)
    end)

    table.insert(rows, btn)
    return btn
end

newToggle("Auto-Roll", 124, function() return autoRollEnabled end, function() autoRollEnabled = not autoRollEnabled end)
newToggle("Auto-Compra", 166, function() return autoBuyEnabled end, function() autoBuyEnabled = not autoBuyEnabled end)
newToggle("Auto-TP", 208, function() return autoTpEnabled end, function() autoTpEnabled = not autoTpEnabled end)
newToggle("Anti-AFK", 250, function() return antiAfkEnabled end, function() antiAfkEnabled = not antiAfkEnabled end)

-- ═══════════════ SELECTOR DE TANQUES (UI) ═══════════════
local selector = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0, 339),
    Size = UDim2.new(1, -32, 0, 118),
    BackgroundTransparency = 1,
}, frame)

make("TextLabel", {
    Position = UDim2.new(0, 2, 0, 0),
    Size = UDim2.new(0.7, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "Tanque a comprar",
    TextColor3 = INK,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
}, selector)

local countLabel = make("TextLabel", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -2, 0, 0),
    Size = UDim2.new(0.3, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = GOLD_DARK,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Right,
}, selector)

local chipPainters = {}

local function refreshChips(time)
    countLabel.Text = selectedCount() .. "/" .. #TANKS
    for _, paint in ipairs(chipPainters) do
        paint(time)
    end
end

local CHIP_BASE = UDim2.new(0.5, -3, 0, 28)
local CHIP_BIG = UDim2.new(0.5, 0, 0, 30)
local CHIP_SMALL = UDim2.new(0.5, -8, 0, 26)

local function newChip(text, col, row, getState, flip)
    local chip = make("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(col == 0 and 0.25 or 0.75, 0, 0, 36 + row * 34),
        Size = CHIP_BASE,
        BackgroundColor3 = PANEL_SOFT,
        AutoButtonColor = false,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = SILVER_DARK,
        Text = text,
    }, selector)
    round(chip, 8)
    local chipStroke = stroke(chip, SILVER, 1.2)

    local function paint(time)
        local on = getState()
        chip.Text = (on and "✓ " or "") .. text
        tween(chip, time, {
            BackgroundColor3 = on and GOLD_SOFT or PANEL_SOFT,
            TextColor3 = on and GOLD_DARK or SILVER_DARK,
        })
        tween(chipStroke, time, {Color = on and GOLD or SILVER})
    end
    table.insert(chipPainters, paint)

    hoverFx(chip, CHIP_BASE, CHIP_BIG, CHIP_SMALL, function()
        tween(chipStroke, 0.15, {Color = GOLD_LIGHT, Thickness = 1.8})
    end, function()
        tween(chipStroke, 0.15, {Color = getState() and GOLD or SILVER, Thickness = 1.2})
    end)

    chip.MouseButton1Click:Connect(function()
        flip()
        refreshChips(0.2)
    end)
    return chip
end

for i, tank in ipairs(TANKS) do
    local idx = i - 1
    newChip(tank.name, idx % 2, math.floor(idx / 2), function()
        return selectedTanks[tank.id]
    end, function()
        selectedTanks[tank.id] = not selectedTanks[tank.id]
    end)
end

-- botón "Todos": si ya están todos marcados, los desmarca; si no, marca todos
newChip("Todos", 1, 2, function()
    return selectedCount() == #TANKS
end, function()
    setAllTanks(selectedCount() ~= #TANKS)
end)

refreshChips(0)
table.insert(rows, selector)
-- ═════════════════════════════════════════════════════════

-- boton iniciar
local startBtn = newButton(437, 50)
startBtn.Parent = frame

local startFace = make("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = GOLD,
}, startBtn)
round(startFace, 12)
local startStroke = stroke(startFace, GOLD_LIGHT, 1.5)
shimmer(startFace, 2.5)

local startLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "▶ INICIAR",
    TextColor3 = WHITE,
    Font = Enum.Font.GothamBlack,
    TextSize = 18,
}, startBtn)
local startTextStroke = textStroke(startLabel, 1.5)

hoverFx(startBtn, UDim2.new(1, -32, 0, 50), UDim2.new(1, -24, 0, 53), UDim2.new(1, -40, 0, 46), function()
    tween(startStroke, 0.15, {Color = WHITE})
end, function()
    tween(startStroke, 0.15, {Color = GOLD_LIGHT})
end)
table.insert(rows, startBtn)

-- estado
local statusCard = make("Frame", {
    Position = UDim2.new(0, 16, 0, 476),
    Size = UDim2.new(1, -32, 0, 62),
    BackgroundColor3 = PANEL_SOFT,
}, frame)
round(statusCard, 10)
stroke(statusCard, SILVER, 1.2)

local dot = make("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 14, 0.5, 0),
    Size = UDim2.new(0, 10, 0, 10),
    BackgroundColor3 = SILVER,
}, statusCard)
round(dot, 5)
local pulse = TweenService:Create(dot, TweenInfo.new(0.7, SINE, INOUT, -1, true), {BackgroundTransparency = 0.75})

local status = make("TextLabel", {
    Position = UDim2.new(0, 34, 0, 0),
    Size = UDim2.new(1, -42, 1, 0),
    BackgroundTransparency = 1,
    Text = "Estado: Detenido",
    TextColor3 = INK,
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, statusCard)

status:GetPropertyChangedSignal("Text"):Connect(function()
    status.TextTransparency = 0.7
    tween(status, 0.35, {TextTransparency = 0})
end)

screenGui.Parent = PlayerGui

-- entrada
local cover = make("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = WHITE,
    ZIndex = 50,
}, frame)
round(cover, 14)

local finalPos = frame.Position
frame.Position = finalPos - UDim2.new(0, 0, 0, 30)
frameStroke.Transparency = 1
tween(frame, 0.55, {Position = finalPos}, Enum.EasingStyle.Back)
tween(frameStroke, 0.55, {Transparency = 0})
tween(cover, 0.7, {BackgroundTransparency = 1}).Completed:Connect(function()
    cover:Destroy()
end)

for i, row in ipairs(rows) do
    local goal = row.Position
    row.Position = goal + UDim2.new(0, -24, 0, 0)
    task.delay(0.06 * i, function()
        tween(row, 0.45, {Position = goal}, Enum.EasingStyle.Back)
    end)
end

local function pressE()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

-- Busca el tanque que salió en los pedestales: modelos dentro de una carpeta
-- "RollPresentationModels" (Plot_X.Machinery.RollPedestalN...), cerca de ti.
-- IGNORA a propósito:
--   * Workspace.RollCandidateCache (caché con copias de TODOS los tanques, bajo el mapa)
--   * Machinery.FuseMachine.FuseVisuals (decoración de la fusionadora)
--   * Plot_X.RuntimeRobots (tus robots ya comprados)
-- Devuelve: (modelo_deseado, nombre) o (nil, nombre_ignorado) o (nil, nil)
local MAX_PLOT_DISTANCE = 250

local function findWantedTank()
    local playable = workspace:FindFirstChild("playable")
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not playable or not hrp then return nil, nil end

    local ignoredName = nil
    for _, plot in ipairs(playable:GetChildren()) do
        local machinery = plot:FindFirstChild("Machinery")
        if machinery then
            for _, obj in ipairs(machinery:GetDescendants()) do
                if obj:IsA("Model")
                    and obj.Parent and obj.Parent.Name == "RollPresentationModels"
                    and obj:GetAttribute("Rarity") == targetRarity then
                    local okPos, cf = pcall(function() return obj:GetPivot() end)
                    -- solo los de TU plot (los pedestales cercanos a ti)
                    if okPos and (cf.Position - hrp.Position).Magnitude <= MAX_PLOT_DISTANCE then
                        local id = string.lower(tostring(obj:GetAttribute("RobotId") or ""))
                        local name = obj:GetAttribute("DisplayName") or id
                        if selectedTanks[id] then
                            return obj, name
                        else
                            ignoredName = name
                        end
                    end
                end
            end
        end
    end
    return nil, ignoredName
end

-- TP seguro: solo teletransporta si el destino tiene suelo debajo y no está en el vacío
local function teleportTo(position)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end

    -- 1) por debajo de la altura donde Roblox destruye partes = vacío seguro
    if position.Y < workspace.FallenPartsDestroyHeight + 50 then
        return false
    end

    -- 2) debe haber suelo bajo el destino
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    local ground = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), params)
    if not ground then
        return false
    end

    char.HumanoidRootPart.CFrame = CFrame.new(ground.Position + Vector3.new(0, 4, 0))
    return true
end

local function fireProximityPrompt(tankModel)
    if not tankModel then return false end

    local prompt = tankModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then
        -- el prompt probablemente está en el pedestal (RollPedestalN), no en el modelo
        local ped = tankModel.Parent
        while ped and ped ~= workspace and not string.match(ped.Name, "^RollPedestal") do
            ped = ped.Parent
        end
        if ped and ped ~= workspace then
            prompt = ped:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
    end

    if prompt then
        pcall(function()
            fireproximityprompt(prompt)
        end)
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration)
            prompt:InputHoldEnd()
        end)
        return true
    end
    return false
end

task.spawn(function()
    while true do
        if running then
            local parsedDelay = tonumber(delayBox.Text)
            if parsedDelay and parsedDelay >= 1 then spinDelay = parsedDelay end

            local char = LocalPlayer.Character
            local originalCFrame = nil
            if char and char:FindFirstChild("HumanoidRootPart") then
                originalCFrame = char.HumanoidRootPart.CFrame
            end

            local canUpdateStatus = not statusLocked or tick() > statusLockUntil

            if autoRollEnabled then
                if canUpdateStatus then
                    status.Text = "Estado: Presionando 'E' para girar..."
                end
                pressE()
            end
            task.wait(spinDelay)

            if autoBuyEnabled then
                if selectedCount() == 0 then
                    if canUpdateStatus then
                        status.Text = "Estado: Elige al menos un tanque."
                    end
                elseif tick() - lastSecretTime > SECRET_COOLDOWN then
                    if canUpdateStatus then
                        status.Text = "Estado: Buscando tanque seleccionado..."
                    end
                    local tankModel, tankName = findWantedTank()

                    if tankModel then
                        lastSecretTime = tick()

                        statusLocked = true
                        statusLockUntil = tick() + 5

                        status.Text = "Estado: ¡" .. tostring(tankName) .. "! Procesando..."

                        local targetPos = nil
                        if tankModel:IsA("Model") then
                            if tankModel.PrimaryPart then targetPos = tankModel.PrimaryPart.Position
                            else
                                local hrp = tankModel:FindFirstChildWhichIsA("BasePart")
                                if hrp then targetPos = hrp.Position end
                            end
                        elseif tankModel:IsA("BasePart") then
                            targetPos = tankModel.Position
                        elseif tankModel:IsA("Attachment") then
                            targetPos = tankModel.WorldPosition
                        end

                        local tpOk = false
                        if targetPos and autoTpEnabled then
                            status.Text = "Estado: Teletransportando..."
                            tpOk = teleportTo(targetPos)
                            if not tpOk then
                                status.Text = "Estado: TP cancelado (destino sin suelo)"
                            end
                            task.wait(0.8)
                        end

                        status.Text = "Estado: Comprando " .. tostring(tankName) .. "..."
                        local bought = fireProximityPrompt(tankModel)
                        if not bought then
                            pressE()
                            task.wait(0.5)
                            pressE()
                        end

                        task.wait(0.5)

                        if tpOk and originalCFrame and char and char:FindFirstChild("HumanoidRootPart") then
                            status.Text = "Estado: Volviendo..."
                            char.HumanoidRootPart.CFrame = originalCFrame
                        end

                        status.Text = "Estado: ¡Compra completada!"
                        task.wait(SECRET_COOLDOWN)

                        statusLocked = false
                    else
                        if canUpdateStatus then
                            if tankName then
                                status.Text = "Estado: " .. tostring(tankName) .. " ignorado (no seleccionado)."
                            else
                                status.Text = "Estado: No salió un " .. targetRarity .. "."
                            end
                        end
                    end
                else
                    if canUpdateStatus then
                        status.Text = "Estado: Cooldown..."
                    end
                end
            end

            task.wait(1.5)
        else
            task.wait(0.5)
        end
    end
end)

startBtn.MouseButton1Click:Connect(function()
    running = not running
    if running then
        startLabel.Text = "■ DETENER"
        tween(startFace, 0.3, {BackgroundColor3 = STOP_COLOR})
        tween(startTextStroke, 0.3, {Color = Color3.fromRGB(62, 66, 76)})
        tween(dot, 0.3, {BackgroundColor3 = GOLD})
        pulse:Play()
        status.Text = "Estado: Iniciando..."
    else
        startLabel.Text = "▶ INICIAR"
        tween(startFace, 0.3, {BackgroundColor3 = GOLD})
        tween(startTextStroke, 0.3, {Color = Color3.fromRGB(110, 78, 10)})
        pulse:Cancel()
        dot.BackgroundTransparency = 0
        tween(dot, 0.3, {BackgroundColor3 = SILVER})
        status.Text = "Estado: Detenido"
    end
end)

print("Script cargado - rareza: " .. targetRarity)
