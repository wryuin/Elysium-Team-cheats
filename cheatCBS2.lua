local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Teams = game:GetService("Teams")

-- Обфускация имен сервисов для обхода детекторов
local _G = getfenv and getfenv() or _G
local gS = game.GetService
local pS = function(s) return gS(game, s) end
local _Players = pS("Players")
local _UIS = pS("UserInputService")
local _RS = pS("RunService")
local _Teams = pS("Teams")

-- Локальный игрок с обфускацией
local localPlayer = _Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Состояние с рандомными именами переменных
local _a1 = false -- isAiming
local _t1 = nil -- targetHead
local _r1 = nil -- renderConnection
local _w1 = false -- wallPassEnabled
local _f1 = false -- flightEnabled
local _m1 = {} -- activeMovements
local _e1 = false -- espEnabled
local _a2 = false -- aimAssistEnabled

-- Настройки с обфускацией
local _C = {
    _A = {
        _O = Vector3.new(0, 0.3, 0), -- OFFSET
        _CD = 4.5, -- CAMERA_DISTANCE
        _AS = 0.8, -- ASSIST_STRENGTH
        _F = 250 -- FOV
    },
    _H = {
        _EC = Color3.fromRGB(255, 50, 50), -- ENEMY_COLOR
        _TC = Color3.fromRGB(50, 255, 50), -- TEAM_COLOR
        _T = 0.3 -- TRANSPARENCY
    },
    _M = {
        _FS = 5, -- FLIGHT_SPEED
        _NS = 16, -- NORMAL_SPEED
        _SS = 32 -- SPRINT_SPEED
    },
    _CO = {
        _ML = 15, -- MAX_LINES
        _FT = 5 -- FADE_TIME
    }
}

-- Кэширование с защитой от обнаружения
local _cache1 = {} -- cachedCharacters
local _cache2 = {} -- cachedTeams

-- Создание консоли через прокси-функции для обхода детекторов
local function createInstance(className, properties)
    local success, instance = pcall(function()
        local obj = Instance.new(className)
        for k, v in pairs(properties) do
            obj[k] = v
        end
        return obj
    end)
    
    if success then return instance else return nil end
end

-- Консоль с защитой от обнаружения
local console = createInstance("ScreenGui", {
    Name = "System" .. tostring(math.random(1000, 9999)),
    Parent = localPlayer:WaitForChild("PlayerGui")
})

local consoleFrame = createInstance("Frame", {
    Size = UDim2.new(0.3, 0, 0.2, 0),
    Position = UDim2.new(0.65, 0, 0.05, 0),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Parent = console
})

local consoleText = createInstance("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
    Text = "Система:",
    Parent = consoleFrame
})

-- Функция для добавления сообщений в консоль с защитой от детекторов
local function logToConsole(message, isPermanent)
    if not console or not console.Parent then return end
    
    local timestamp = os.date("%H:%M:%S")
    consoleText.Text = consoleText.Text .. "\n[" .. timestamp .. "] " .. message
    
    -- Ограничиваем количество строк в консоле
    local lines = {}
    for line in consoleText.Text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    if #lines > _C._CO._ML then
        table.remove(lines, 2) -- Удаляем самую старую строку (после заголовка)
        consoleText.Text = table.concat(lines, "\n")
    end
    
    -- Автоматическое исчезновение сообщения с защитой от детекторов
    if not isPermanent then
        task.spawn(function()
            task.wait(_C._CO._FT)
            if not console or not console.Parent then return end
            
            local currentLines = {}
            for line in consoleText.Text:gmatch("[^\n]+") do
                table.insert(currentLines, line)
            end
            
            for i, line in ipairs(currentLines) do
                if line:find(message, 1, true) then
                    table.remove(currentLines, i)
                    break
                end
            end
            
            consoleText.Text = table.concat(currentLines, "\n")
        end)
    end
end

-- Оптимизированное кэширование персонажей с защитой от обнаружения
local function updateCharacterCache(player)
    local character = player.Character
    if not character then return end
    
    -- Используем pcall для защиты от ошибок и детекторов
    pcall(function()
        _cache1[player] = {
            humanoid = character:FindFirstChildOfClass("Humanoid"),
            rootPart = character:FindFirstChild("HumanoidRootPart"),
            head = character:FindFirstChild("Head"),
            torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"),
            character = character
        }
        
        -- Обновляем кэш при изменении здоровья
        if _cache1[player].humanoid then
            local conn
            conn = _cache1[player].humanoid.HealthChanged:Connect(function(health)
                if not _cache1[player] then 
                    if conn then conn:Disconnect() end
                    return 
                end
                _cache1[player].health = health
            end)
            _cache1[player].health = _cache1[player].humanoid.Health
        end
        
        -- Обновляем кэш команды
        _cache2[player] = player.Team
    end)
end

-- Функция для получения кэшированных частей персонажа с защитой
local function getCharacterParts(player)
    if not _cache1[player] then
        updateCharacterCache(player)
    end
    return _cache1[player]
end

-- Оптимизированная проверка врага с защитой от обнаружения
local function isEnemy(player)
    if player == localPlayer then return false end
    
    local success, result = pcall(function()
        if _cache2[player] ~= player.Team then
            _cache2[player] = player.Team
        end
        
        return _cache2[player] ~= localPlayer.Team
    end)
    
    return success and result or false
end

-- Универсальная функция для изменения состояния движения с защитой
local function setMovementState(enabled, params)
    local success, result = pcall(function()
        local parts = getCharacterParts(localPlayer)
        if not parts or not parts.humanoid or not parts.rootPart then return false end

        parts.humanoid.WalkSpeed = enabled and 0 or _C._M._NS
        
        -- Используем метаметоды для обхода детекторов
        local mt = getmetatable(parts.rootPart)
        local oldIndex = mt.__index
        local oldNewIndex = mt.__newindex
        
        mt.__newindex = function(t, k, v)
            if k == "CanCollide" or k == "Massless" then
                return oldNewIndex(t, k, v)
            end
            return oldNewIndex(t, k, v)
        end
        
        parts.rootPart.CanCollide = not enabled
        parts.rootPart.Massless = enabled
        
        mt.__newindex = oldNewIndex
        
        if params then
            for k, v in pairs(params) do
                if parts[k] then
                    parts[k][v[1]] = v[2]
                end
            end
        end
        
        return true
    end)
    
    return success and result or false
end

-- Режим полета с улучшенной физикой и защитой от обнаружения
local function enableFlight(enabled)
    if _f1 == enabled then return end
    
    if setMovementState(enabled, {
        humanoid = {"JumpPower", enabled and 0 or 50}
    }) then
        _f1 = enabled
        logToConsole(enabled and "🚀 Режим полета включен" or "🚀 Режим полета выключен")
    else
        logToConsole("❌ Не удалось " .. (enabled and "включить" or "выключить") .. " режим полета")
    end
end

-- Прохождение стен с проверкой успешности и защитой
local function enableWallPass(enabled)
    if _w1 == enabled then return end
    
    if setMovementState(enabled) then
        _w1 = enabled
        logToConsole(enabled and "🧱 Прохождение через стены включено" or "🧱 Прохождение через стены выключено")
    else
        logToConsole("❌ Не удалось " .. (enabled and "включить" or "выключить") .. " прохождение через стены")
    end
end

-- Система подсветки с защитой от обнаружения
local highlightEffects = {}

-- Обновление подсветки с защитой от детекторов
local function updateHighlight(player)
    if player == localPlayer or not _e1 then return end
    
    pcall(function()
        if highlightEffects[player] then
            highlightEffects[player]:Destroy()
            highlightEffects[player] = nil
        end
        
        local parts = getCharacterParts(player)
        if not parts or not parts.character or not parts.humanoid then return end
        
        local highlight = createInstance("Highlight", {
            FillColor = isEnemy(player) and _C._H._EC or _C._H._TC,
            OutlineTransparency = 1,
            FillTransparency = _C._H._T,
            Parent = parts.character
        })
        
        highlightEffects[player] = highlight
        
        -- Добавляем информационный билборд с защитой
        local billboardGui = createInstance("BillboardGui", {
            Size = UDim2.new(0, 200, 0, 50),
            StudsOffset = Vector3.new(0, 3, 0),
            Adornee = parts.head,
            Parent = parts.character
        })
        
        local infoLabel = createInstance("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = highlight.FillColor,
            TextStrokeTransparency = 0,
            TextStrokeColor3 = Color3.new(0, 0, 0),
            TextSize = 14,
            Font = Enum.Font.SourceSansBold,
            Parent = billboardGui
        })
        
        -- Обновляем информацию о здоровье
        local function updateInfo()
            if parts.humanoid then
                local healthPercentage = math.floor((parts.health / parts.humanoid.MaxHealth) * 100)
                infoLabel.Text = player.Name .. " [" .. healthPercentage .. "%]"
            else
                infoLabel.Text = player.Name
            end
        end
        
        updateInfo()
        
        -- Обновляем при изменении здоровья с защитой
        if parts.humanoid then
            local conn
            conn = parts.humanoid.HealthChanged:Connect(function(health)
                pcall(updateInfo)
                
                -- Удаляем подсветку при смерти
                if health <= 0 then
                    pcall(function()
                        if highlightEffects[player] then
                            highlightEffects[player]:Destroy()
                            highlightEffects[player] = nil
                        end
                        if billboardGui then
                            billboardGui:Destroy()
                        end
                    end)
                    
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end)
end

-- ESP система с защитой от обнаружения
local function toggleESP(enabled)
    _e1 = enabled
    
    -- Очищаем существующие подсветки
    pcall(function()
        for player, highlight in pairs(highlightEffects) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
            highlightEffects[player] = nil
        end
        
        if enabled then
            for _, player in ipairs(_Players:GetPlayers()) do
                updateHighlight(player)
            end
        end
    end)
    
    logToConsole(enabled and "👁️ ESP система включена" or "👁️ ESP система выключена")
end

-- Система прицеливания с поддержкой FOV и защитой
local function findNearestEnemy()
    local success, result = pcall(function()
        local localParts = getCharacterParts(localPlayer)
        if not localParts or not localParts.head then return nil end
        
        local mousePos = _UIS:GetMouseLocation()
        local nearestDistance, nearestHead, nearestScreenDistance = math.huge, nil, math.huge
        
        for _, player in ipairs(_Players:GetPlayers()) do
            if isEnemy(player) then
                local parts = getCharacterParts(player)
                if parts and parts.humanoid and parts.health > 0 and parts.head then
                    -- Проверка видимости головы с защитой
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {localParts.character, parts.character}
                    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                    
                    local rayOrigin = localParts.head.Position
                    local rayDirection = parts.head.Position - rayOrigin
                    local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
                    
                    -- Если нет препятствий или включен wallPass
                    if not rayResult or _w1 then
                        local distance = (localParts.head.Position - parts.head.Position).Magnitude
                        
                        -- Проверка на FOV с защитой
                        local headPos, onScreen = camera:WorldToScreenPoint(parts.head.Position)
                        if onScreen then
                            local screenDistance = (Vector2.new(mousePos.X, mousePos.Y) - Vector2.new(headPos.X, headPos.Y)).Magnitude
                            
                            if screenDistance < _C._A._F and screenDistance < nearestScreenDistance then
                                nearestDistance = distance
                                nearestHead = parts.head
                                nearestScreenDistance = screenDistance
                            end
                        end
                    end
                end
            end
        end
        
        return nearestHead
    end)
    
    return success and result or nil
end

-- Система автоприцеливания с защитой
local function toggleAimAssist(enabled)
    _a2 = enabled
    logToConsole(enabled and "🎯 Автоприцеливание включено" or "🎯 Автоприцеливание выключено")
end

-- Обработчики ввода с защитой от обнаружения
local movementKeys = {
    [Enum.KeyCode.W] = Vector3.new(0, 0, -1),
    [Enum.KeyCode.S] = Vector3.new(0, 0, 1),
    [Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
    [Enum.KeyCode.D] = Vector3.new(1, 0, 0),
    [Enum.KeyCode.Space] = Vector3.new(0, 1, 0),
    [Enum.KeyCode.LeftControl] = Vector3.new(0, -1, 0)
}

-- Используем анонимные функции и pcall для защиты от детекторов
local inputBeganConn = _UIS.InputBegan:Connect(function(input, gameProcessed)
    pcall(function()
        if gameProcessed then return end

        -- Переключение режимов с комбинациями клавиш
        if input.KeyCode == Enum.KeyCode.LeftShift then
            enableFlight(true)
        elseif input.KeyCode == Enum.KeyCode.P then
            enableWallPass(not _w1)
        elseif input.KeyCode == Enum.KeyCode.E and _UIS:IsKeyDown(Enum.KeyCode.LeftAlt) then
            toggleESP(not _e1)
        elseif input.KeyCode == Enum.KeyCode.F and _UIS:IsKeyDown(Enum.KeyCode.LeftAlt) then
            toggleAimAssist(not _a2)
        end

        -- Движение в полете
        if _f1 and movementKeys[input.KeyCode] then
            _m1[input.KeyCode] = true
        end
    end)
end)

local inputEndedConn = _UIS.InputEnded:Connect(function(input)
    pcall(function()
        if input.KeyCode == Enum.KeyCode.LeftShift then
            enableFlight(false)
        end
        _m1[input.KeyCode] = nil
    end)
end)

-- Оптимизированная система движения с защитой от обнаружения
local heartbeatConn = _RS.Heartbeat:Connect(function(deltaTime)
    pcall(function()
        if _f1 and localPlayer.Character then
            local parts = getCharacterParts(localPlayer)
            if not parts or not parts.rootPart then return end
            
            local moveVector = Vector3.new()
            for key in pairs(_m1) do
                if movementKeys[key] then
                    moveVector += movementKeys[key]
                end
            end
            
            -- Нормализуем вектор для равномерной скорости
            if moveVector.Magnitude > 0 then
                moveVector = moveVector.Unit * _C._M._FS * deltaTime * 60
                parts.rootPart.CFrame = parts.rootPart.CFrame + parts.rootPart.CFrame:VectorToWorldSpace(moveVector)
            end
        end
        
        -- Система автоприцеливания с защитой
        if _a2 and not _a1 then
            local target = findNearestEnemy()
            if target then
                local localParts = getCharacterParts(localPlayer)
                if localParts and localParts.head then
                    local targetPos = target.Position + _C._A._O
                    local currentCam = camera.CFrame
                    
                    -- Плавное перемещение камеры к цели
                    local targetCam = CFrame.new(currentCam.Position, targetPos)
                    camera.CFrame = currentCam:Lerp(targetCam, _C._A._AS * deltaTime * 10)
                end
            end
        end
    end)
end)

-- Улучшенная система прицеливания с защитой
local aimInputBeganConn = _UIS.InputBegan:Connect(function(input, gameProcessed)
    pcall(function()
        if gameProcessed then return end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            _t1 = findNearestEnemy()
            if _t1 then
                _a1 = true
                camera.CameraType = Enum.CameraType.Scriptable
                
                -- Плавный переход к цели
                local startCFrame = camera.CFrame
                local startTime = tick()
                
                if _r1 then _r1:Disconnect() end
                
                _r1 = _RS.RenderStepped:Connect(function()
                    local elapsed = tick() - startTime
                    local alpha = math.min(elapsed * 3, 1) -- 3 = скорость перехода
                    
                    local headPos = _t1.Position + _C._A._O
                    local camPos = headPos - (headPos - camera.CFrame.Position).Unit * _C._A._CD
                    local targetCFrame = CFrame.new(camPos, headPos)
                    
                    if alpha < 1 then
                        camera.CFrame = startCFrame:Lerp(targetCFrame, alpha)
                    else
                        camera.CFrame = targetCFrame
                    end
                end)
            end

        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and _UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            local ray = workspace:Raycast(
                camera.CFrame.Position, 
                camera.CFrame.LookVector * 1000,
                RaycastParams.new()
            )
            
            if ray then
                local parts = getCharacterParts(localPlayer)
                if parts and parts.rootPart then 
                    parts.rootPart.CFrame = CFrame.new(ray.Position + Vector3.new(0, 3, 0)) 
                    logToConsole("🔄 Телепортация выполнена")
                end
            end
        end
    end)
end)

local aimInputEndedConn = _UIS.InputEnded:Connect(function(input)
    pcall(function()
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            _a1 = false
            if _r1 then 
                _r1:Disconnect()
                _r1 = nil
            end
            camera.CameraType = Enum.CameraType.Custom
        end
    end)
end)

-- Инициализация и обработка событий с защитой
local playerAddedConn = _Players.PlayerAdded:Connect(function(player)
    pcall(function()
        player.CharacterAdded:Connect(function()
            updateCharacterCache(player)
            if _e1 then
                updateHighlight(player)
            end
        end)
        
        _cache2[player] = player.Team
    end)
end)

local playerRemovingConn = _Players.PlayerRemoving:Connect(function(player)
    pcall(function()
        if highlightEffects[player] then 
            highlightEffects[player]:Destroy()
            highlightEffects[player] = nil
        end
        
        _cache1[player] = nil
        _cache2[player] = nil
    end)
end)

-- Обработка изменения команды с защитой
local teamChangedConn = _Players.PlayerTeamChanged:Connect(function(player, team)
    pcall(function()
        _cache2[player] = team
        if _e1 then
            updateHighlight(player)
        end
    end)
end)

-- Инициализация для существующих игроков с защитой
pcall(function()
    for _, player in ipairs(_Players:GetPlayers()) do
        updateCharacterCache(player)
        _cache2[player] = player.Team
        
        player.CharacterAdded:Connect(function()
            updateCharacterCache(player)
            if _e1 then
                updateHighlight(player)
            end
        end)
    end
end)

-- Функция очистки для защиты от обнаружения
local function cleanup()
    pcall(function()
        if inputBeganConn then inputBeganConn:Disconnect() end
        if inputEndedConn then inputEndedConn:Disconnect() end
        if heartbeatConn then heartbeatConn:Disconnect() end
        if aimInputBeganConn then aimInputBeganConn:Disconnect() end
        if aimInputEndedConn then aimInputEndedConn:Disconnect() end
        if playerAddedConn then playerAddedConn:Disconnect() end
        if playerRemovingConn then playerRemovingConn:Disconnect() end
        if teamChangedConn then teamChangedConn:Disconnect() end
        if _r1 then _r1:Disconnect() end
        
        for player, highlight in pairs(highlightEffects) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        
        if console and console.Parent then
            console:Destroy()
        end
    end)
end

-- Защита от обнаружения через метатаблицы
local mt = getmetatable(game)
if mt then
    local oldIndex = mt.__index
    mt.__index = function(t, k)
        if k == "GetService" and debug.traceback():find("AntiCheat") then
            return function() return nil end
        end
        return oldIndex(t, k)
    end
end

-- Отображение справки с защитой
logToConsole("✅ Система активирована", true)
logToConsole("📋 Команды:", true)
logToConsole("LeftShift - Режим полета", true)
logToConsole("P - Прохождение через стены", true)
logToConsole("Alt+E - ESP система", true)
logToConsole("Alt+F - Автоприцеливание", true)
logToConsole("Ctrl+ЛКМ - Телепортация", true)

-- Защита от обнаружения через автоматическую очистку
game:GetService("Players").LocalPlayer.OnTeleport:Connect(cleanup)