local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Teams = game:GetService("Teams")

-- Локальный игрок
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Состояние
local isAiming = false
local targetHead = nil
local renderConnection = nil
local wallPassEnabled = false
local flightEnabled = false
local activeMovements = {}

-- Настройки
local AIM_OFFSET = Vector3.new(0, 0.3, 0)
local CAMERA_DISTANCE = 4.5
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 50, 50)
local highlightEffects = {}
local MOVEMENT_SPEED = 5

-- Консоль
local console = Instance.new("ScreenGui")
console.Name = "Console"
console.Parent = localPlayer:WaitForChild("PlayerGui")

local consoleFrame = Instance.new("Frame")
consoleFrame.Size = UDim2.new(0.3, 0, 0.2, 0)
consoleFrame.Position = UDim2.new(0.65, 0, 0.05, 0)
consoleFrame.BackgroundColor3 = Color3.new(0, 0, 0)
consoleFrame.BackgroundTransparency = 0.5
consoleFrame.BorderSizePixel = 0
consoleFrame.Parent = console

local consoleText = Instance.new("TextLabel")
consoleText.Size = UDim2.new(1, 0, 1, 0)
consoleText.Position = UDim2.new(0, 0, 0, 0)
consoleText.BackgroundTransparency = 1
consoleText.TextColor3 = Color3.new(1, 1, 1)
consoleText.TextSize = 14
consoleText.TextXAlignment = Enum.TextXAlignment.Left
consoleText.TextYAlignment = Enum.TextYAlignment.Top
consoleText.TextWrapped = true
consoleText.Text = "Консоль:"
consoleText.Parent = consoleFrame

-- Функция для добавления сообщений в консоль
local function logToConsole(message)
    consoleText.Text = consoleText.Text .. "\n" .. message
    
    -- Ограничиваем количество строк в консоле (например, 10 строк)
    local lines = {}
    for line in consoleText.Text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    if #lines > 10 then
        table.remove(lines, 1)
        consoleText.Text = table.concat(lines, "\n")
    end
end

-- Общие функции проверки
local function getCharacterParts(player)
    local character = player.Character
    if not character then return nil end
    
    return {
        humanoid = character:FindFirstChildOfClass("Humanoid"),
        rootPart = character:FindFirstChild("HumanoidRootPart"),
        head = character:FindFirstChild("Head")
    }
end

local function isEnemy(player)
    return player ~= localPlayer and player.Team ~= localPlayer.Team
end

-- Универсальная функция для изменения состояния
local function setMovementState(enabled, params)
    local parts = getCharacterParts(localPlayer)
    if not parts or not parts.humanoid or not parts.rootPart then return end

    parts.humanoid.WalkSpeed = enabled and 0 or 16
    parts.rootPart.CanCollide = not enabled
    parts.rootPart.Massless = enabled
    
    if params then
        for k, v in pairs(params) do
            if parts[k] then
                parts[k][v[1]] = v[2]
            end
        end
    end
end

-- Режим полета
local function enableFlight(enabled)
    flightEnabled = enabled
    setMovementState(enabled, {
        humanoid = {"JumpPower", enabled and 0 or 50}
    })
    logToConsole(enabled and "Режим полета включен" or "Режим полета выключен")
end

-- Прохождение стен
local function enableWallPass(enabled)
    wallPassEnabled = enabled
    setMovementState(enabled)
    logToConsole(enabled and "✅ Прохождение через стены включено" or "✅ Прохождение через стены выключено")
end

-- Обработчики ввода
local movementKeys = {
    [Enum.KeyCode.W] = Vector3.new(0, 0, -1),
    [Enum.KeyCode.S] = Vector3.new(0, 0, 1),
    [Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
    [Enum.KeyCode.D] = Vector3.new(1, 0, 0)
}

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Переключение режимов
    if input.KeyCode == Enum.KeyCode.LeftShift then
        enableFlight(true)
    elseif input.KeyCode == Enum.KeyCode.P then
        enableWallPass(not wallPassEnabled)
    end

    -- Движение в полете
    if flightEnabled and movementKeys[input.KeyCode] then
        activeMovements[input.KeyCode] = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        enableFlight(false)
    end
    activeMovements[input.KeyCode] = nil
end)

-- Система движения
RS.Heartbeat:Connect(function()
    if flightEnabled and localPlayer.Character then
        local rootPart = getCharacterParts(localPlayer).rootPart
        if not rootPart then return end
        
        local moveVector = Vector3.new()
        for key in pairs(activeMovements) do
            moveVector += movementKeys[key] * MOVEMENT_SPEED
        end
        
        rootPart.CFrame = rootPart.CFrame + rootPart.CFrame:VectorToWorldSpace(moveVector)
    end
end)

-- Система прицеливания
local function findNearestEnemy()
    local localHead = getCharacterParts(localPlayer).head
    if not localHead then return end

    local nearestDistance, nearestHead = math.huge, nil

    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) then
            local parts = getCharacterParts(player)
            if parts and parts.humanoid and parts.humanoid.Health > 0 and parts.head then
                local distance = (localHead.Position - parts.head.Position).Magnitude
                nearestDistance, nearestHead = distance < nearestDistance and distance or nearestDistance, 
                    distance < nearestDistance and parts.head or nearestHead
            end
        end
    end
    return nearestHead
end

-- Подсветка игроков
local function updateHighlight(player)
    if player == localPlayer then return end
    
    if highlightEffects[player] then
        highlightEffects[player]:Destroy()
        highlightEffects[player] = nil
    end

    if isEnemy(player) then
        local character = player.Character
        if not character then
            player.CharacterAdded:Wait()
            character = player.Character
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            local highlight = Instance.new("Highlight")
            highlight.FillColor = HIGHLIGHT_COLOR
            highlight.OutlineTransparency = 1
            highlight.FillTransparency = 0.3
            highlight.Parent = character
            highlightEffects[player] = highlight

            humanoid.HealthChanged:Connect(function(newHealth)
                if newHealth <= 0 and highlightEffects[player] then
                    highlightEffects[player]:Destroy()
                    highlightEffects[player] = nil
                end
            end)
        end
    end
end

-- Основные обработчики
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        targetHead = findNearestEnemy()
        if targetHead then
            isAiming = true
            camera.CameraType = Enum.CameraType.Scriptable
            renderConnection = RS.RenderStepped:Connect(function()
                local headPos = targetHead.Position + AIM_OFFSET
                local camPos = headPos - (headPos - camera.CFrame.Position).Unit * CAMERA_DISTANCE
                camera.CFrame = CFrame.new(camPos, headPos)
            end)
        end

    elseif input.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
        local ray = workspace:Raycast(localPlayer:GetMouse().UnitRay.Origin, 
            localPlayer:GetMouse().UnitRay.Direction * 1000)
        if ray then
            local root = getCharacterParts(localPlayer).rootPart
            if root then 
                root.CFrame = CFrame.new(ray.Position + Vector3.new(0, 3, 0)) 
            end
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isAiming = false
        if renderConnection then 
            renderConnection:Disconnect()
            renderConnection = nil
        end
        camera.CameraType = Enum.CameraType.Custom
    end
end)

-- Инициализация
Players.PlayerTeamChanged:Connect(function(p)
    updateHighlight(p)
end)
Players.PlayerRemoving:Connect(function(p)
    if highlightEffects[p] then 
        highlightEffects[p]:Destroy()
        highlightEffects[p] = nil
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    updateHighlight(player)
end

logToConsole("✔️ Система активирована")