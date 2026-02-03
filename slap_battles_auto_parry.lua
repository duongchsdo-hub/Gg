-- ============================================
-- SLAP BATTLES AUTO PARRY SCRIPT
-- Đọc màu đỏ/trắng và tự động bấm nút né
-- Version: 4.0
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- CẤU HÌNH
-- ============================================
local Config = {
    AutoParry = false,
    AntiRagdoll = false,
    ShowNotifications = true,
    VisualWarning = true,
    ParryDistance = 25,
    ParryDelay = 0.1,
    ParryKey = Enum.KeyCode.Space -- Phím né mặc định của game
}

-- Bảng lưu trạng thái
local LastDetectedColors = {}
local LastParryTime = 0
local ParryCooldown = 0.5 -- Cooldown giữa các lần né

-- ============================================
-- TẠO GUI
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local AutoParryToggle = Instance.new("TextButton")
local AntiRagdollToggle = Instance.new("TextButton")
local NotificationToggle = Instance.new("TextButton")
local VisualToggle = Instance.new("TextButton")
local StatusLabel = Instance.new("TextLabel")
local KeybindLabel = Instance.new("TextLabel")
local WarningFrame = Instance.new("Frame")
local WarningText = Instance.new("TextLabel")
local CloseButton = Instance.new("TextButton")
local MinimizeButton = Instance.new("TextButton")

ScreenGui.Name = "SlapBattlesGUI"
ScreenGui.Parent = game.CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- Main Frame
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.02, 0, 0.25, 0)
MainFrame.Size = UDim2.new(0, 340, 0, 420)
MainFrame.Active = true
MainFrame.Draggable = true

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

-- Gradient Background
local Gradient = Instance.new("UIGradient")
Gradient.Parent = MainFrame
Gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 40))
}
Gradient.Rotation = 45

-- Title
Title.Name = "Title"
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 50)
Title.Font = Enum.Font.GothamBold
Title.Text = "🥊 SLAP BATTLES AUTO PARRY"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 15

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = Title

local TitleGradient = Instance.new("UIGradient")
TitleGradient.Parent = Title
TitleGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 60, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 40, 40))
}

-- Minimize Button
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = Title
MinimizeButton.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
MinimizeButton.Position = UDim2.new(1, -80, 0, 10)
MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "_"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 20

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinimizeButton

-- Close Button
CloseButton.Name = "CloseButton"
CloseButton.Parent = Title
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
CloseButton.Position = UDim2.new(1, -40, 0, 10)
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 14

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

-- Auto Parry Toggle
AutoParryToggle.Name = "AutoParryToggle"
AutoParryToggle.Parent = MainFrame
AutoParryToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
AutoParryToggle.BorderColor3 = Color3.fromRGB(200, 50, 50)
AutoParryToggle.BorderSizePixel = 3
AutoParryToggle.Position = UDim2.new(0, 15, 0, 65)
AutoParryToggle.Size = UDim2.new(0, 310, 0, 55)
AutoParryToggle.Font = Enum.Font.GothamBold
AutoParryToggle.Text = "❌ TỰ ĐỘNG BẤM NÉ"
AutoParryToggle.TextColor3 = Color3.fromRGB(255, 100, 100)
AutoParryToggle.TextSize = 15

local Toggle1Corner = Instance.new("UICorner")
Toggle1Corner.CornerRadius = UDim.new(0, 10)
Toggle1Corner.Parent = AutoParryToggle

-- Anti Ragdoll Toggle
AntiRagdollToggle.Name = "AntiRagdollToggle"
AntiRagdollToggle.Parent = MainFrame
AntiRagdollToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
AntiRagdollToggle.BorderColor3 = Color3.fromRGB(200, 50, 50)
AntiRagdollToggle.BorderSizePixel = 3
AntiRagdollToggle.Position = UDim2.new(0, 15, 0, 130)
AntiRagdollToggle.Size = UDim2.new(0, 310, 0, 55)
AntiRagdollToggle.Font = Enum.Font.GothamBold
AntiRagdollToggle.Text = "❌ CHỐNG NGÃ"
AntiRagdollToggle.TextColor3 = Color3.fromRGB(255, 100, 100)
AntiRagdollToggle.TextSize = 15

local Toggle2Corner = Instance.new("UICorner")
Toggle2Corner.CornerRadius = UDim.new(0, 10)
Toggle2Corner.Parent = AntiRagdollToggle

-- Visual Warning Toggle
VisualToggle.Name = "VisualToggle"
VisualToggle.Parent = MainFrame
VisualToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
VisualToggle.BorderColor3 = Color3.fromRGB(50, 200, 50)
VisualToggle.BorderSizePixel = 3
VisualToggle.Position = UDim2.new(0, 15, 0, 195)
VisualToggle.Size = UDim2.new(0, 310, 0, 55)
VisualToggle.Font = Enum.Font.GothamBold
VisualToggle.Text = "✅ CẢNH BÁO MÀN HÌNH"
VisualToggle.TextColor3 = Color3.fromRGB(100, 255, 100)
VisualToggle.TextSize = 15

local Toggle3Corner = Instance.new("UICorner")
Toggle3Corner.CornerRadius = UDim.new(0, 10)
Toggle3Corner.Parent = VisualToggle

-- Notification Toggle
NotificationToggle.Name = "NotificationToggle"
NotificationToggle.Parent = MainFrame
NotificationToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
NotificationToggle.BorderColor3 = Color3.fromRGB(50, 200, 50)
NotificationToggle.BorderSizePixel = 3
NotificationToggle.Position = UDim2.new(0, 15, 0, 260)
NotificationToggle.Size = UDim2.new(0, 310, 0, 55)
NotificationToggle.Font = Enum.Font.GothamBold
NotificationToggle.Text = "✅ THÔNG BÁO"
NotificationToggle.TextColor3 = Color3.fromRGB(100, 255, 100)
NotificationToggle.TextSize = 15

local Toggle4Corner = Instance.new("UICorner")
Toggle4Corner.CornerRadius = UDim.new(0, 10)
Toggle4Corner.Parent = NotificationToggle

-- Keybind Label
KeybindLabel.Name = "KeybindLabel"
KeybindLabel.Parent = MainFrame
KeybindLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
KeybindLabel.BorderSizePixel = 0
KeybindLabel.Position = UDim2.new(0, 15, 0, 325)
KeybindLabel.Size = UDim2.new(0, 310, 0, 25)
KeybindLabel.Font = Enum.Font.GothamMedium
KeybindLabel.Text = "⌨️ Phím né game: SPACE"
KeybindLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
KeybindLabel.TextSize = 11

local KeybindCorner = Instance.new("UICorner")
KeybindCorner.CornerRadius = UDim.new(0, 6)
KeybindCorner.Parent = KeybindLabel

-- Status Label
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
StatusLabel.BorderColor3 = Color3.fromRGB(80, 80, 100)
StatusLabel.BorderSizePixel = 2
StatusLabel.Position = UDim2.new(0, 15, 0, 355)
StatusLabel.Size = UDim2.new(0, 310, 0, 50)
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.Text = "⏳ Đang quét bàn đấu...\n🎯 Đối thủ: 0 | 🔴 Nguy hiểm: 0"
StatusLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
StatusLabel.TextSize = 11
StatusLabel.TextYAlignment = Enum.TextYAlignment.Center

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 10)
StatusCorner.Parent = StatusLabel

-- Warning Frame (Cảnh báo toàn màn hình)
WarningFrame.Name = "WarningFrame"
WarningFrame.Parent = ScreenGui
WarningFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
WarningFrame.BackgroundTransparency = 1
WarningFrame.BorderSizePixel = 0
WarningFrame.Size = UDim2.new(1, 0, 1, 0)
WarningFrame.ZIndex = 10
WarningFrame.Visible = false

WarningText.Name = "WarningText"
WarningText.Parent = WarningFrame
WarningText.BackgroundTransparency = 1
WarningText.Position = UDim2.new(0.5, 0, 0.5, 0)
WarningText.AnchorPoint = Vector2.new(0.5, 0.5)
WarningText.Size = UDim2.new(0, 700, 0, 200)
WarningText.Font = Enum.Font.GothamBold
WarningText.Text = "⚠️ NGUY HIỂM ⚠️\n🔴 TÁT THẬT!"
WarningText.TextColor3 = Color3.fromRGB(255, 255, 255)
WarningText.TextSize = 70
WarningText.TextStrokeTransparency = 0
WarningText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
WarningText.ZIndex = 11

-- ============================================
-- HÀM TIỆN ÍCH
-- ============================================

-- Thông báo
local function Notify(text, duration)
    if not Config.ShowNotifications then return end
    
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "🥊 Slap Arena";
            Text = text;
            Duration = duration or 2;
        })
    end)
end

-- Cập nhật nút
local function UpdateButton(button, enabled, feature)
    if enabled then
        button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        button.BorderColor3 = Color3.fromRGB(50, 200, 50)
        button.TextColor3 = Color3.fromRGB(100, 255, 100)
        button.Text = "✅ " .. feature
    else
        button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        button.BorderColor3 = Color3.fromRGB(200, 50, 50)
        button.TextColor3 = Color3.fromRGB(255, 100, 100)
        button.Text = "❌ " .. feature
    end
end

-- Hiển thị cảnh báo
local function ShowWarning(playerName)
    if not Config.VisualWarning then return end
    
    WarningFrame.Visible = true
    WarningText.Text = string.format("⚠️ NGUY HIỂM ⚠️\n🔴 %s TÁT THẬT!", playerName:upper())
    
    task.spawn(function()
        for i = 1, 4 do
            WarningFrame.BackgroundTransparency = 0.2
            task.wait(0.08)
            WarningFrame.BackgroundTransparency = 0.7
            task.wait(0.08)
        end
        WarningFrame.BackgroundTransparency = 1
        task.wait(0.3)
        WarningFrame.Visible = false
    end)
end

-- ============================================
-- PHÁT HIỆN MÀU NHÁY
-- ============================================

local function DetectSlapByColor(character)
    if not character then return "none" end
    
    -- Tìm các part chính
    local parts = {
        character:FindFirstChild("Torso"),
        character:FindFirstChild("UpperTorso"),
        character:FindFirstChild("Head"),
        character:FindFirstChild("Right Arm"),
        character:FindFirstChild("RightHand"),
        character:FindFirstChild("Left Arm"),
        character:FindFirstChild("LeftHand"),
        character:FindFirstChild("HumanoidRootPart")
    }
    
    -- Kiểm tra màu của parts
    for _, part in ipairs(parts) do
        if part and part:IsA("BasePart") then
            local color = part.Color
            local h, s, v = color:ToHSV()
            
            -- PHÁT HIỆN MÀU ĐỎ (Tát thật)
            -- Hue: 0-0.05 hoặc 0.95-1 (đỏ), Saturation > 0.5, Value > 0.5
            if (h < 0.08 or h > 0.92) and s > 0.4 and v > 0.4 then
                return "red_real"
            end
            
            -- PHÁT HIỆN MÀU TRẮNG (Hù dọa)
            -- Saturation thấp (< 0.2), Value cao (> 0.8)
            if s < 0.25 and v > 0.75 then
                return "white_fake"
            end
        end
    end
    
    -- Kiểm tra Light effects
    for _, descendant in ipairs(character:GetDescendants()) do
        if (descendant:IsA("PointLight") or descendant:IsA("SurfaceLight") or descendant:IsA("SpotLight")) and descendant.Enabled then
            local lightColor = descendant.Color
            local h, s, v = lightColor:ToHSV()
            
            if (h < 0.08 or h > 0.92) and s > 0.4 then
                return "red_real"
            end
            
            if s < 0.25 and v > 0.75 and descendant.Brightness > 1 then
                return "white_fake"
            end
        end
    end
    
    -- Kiểm tra ParticleEmitter
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") and descendant.Enabled then
            local particleColor = descendant.Color
            if typeof(particleColor) == "ColorSequence" then
                local firstColor = particleColor.Keypoints[1].Value
                local h, s, v = firstColor:ToHSV()
                
                if (h < 0.08 or h > 0.92) and s > 0.4 then
                    return "red_real"
                end
                
                if s < 0.25 and v > 0.75 then
                    return "white_fake"
                end
            end
        end
    end
    
    -- Kiểm tra BillboardGui với màu đỏ/trắng
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BillboardGui") and descendant.Enabled then
            for _, child in ipairs(descendant:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("Frame") then
                    if child.BackgroundColor3 then
                        local h, s, v = child.BackgroundColor3:ToHSV()
                        if (h < 0.08 or h > 0.92) and s > 0.4 then
                            return "red_real"
                        end
                    end
                end
            end
        end
    end
    
    return "none"
end

-- ============================================
-- BẤM NÚT NÉ CỦA GAME
-- ============================================

local function PressParryButton()
    local currentTime = tick()
    
    -- Kiểm tra cooldown
    if currentTime - LastParryTime < ParryCooldown then
        return false
    end
    
    LastParryTime = currentTime
    
    -- Tìm nút né trong GUI của game
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local parryButton = nil
    
    -- Tìm nút né (có thể có tên khác nhau tùy game)
    for _, gui in pairs(playerGui:GetChildren()) do
        parryButton = gui:FindFirstChild("Parry", true) or
                     gui:FindFirstChild("Block", true) or
                     gui:FindFirstChild("Dodge", true) or
                     gui:FindFirstChild("Evade", true)
        
        if parryButton and parryButton:IsA("GuiButton") then
            break
        end
    end
    
    -- Nếu tìm thấy nút, bấm nó
    if parryButton and parryButton:IsA("GuiButton") then
        local success = pcall(function()
            -- Giả lập click chuột
            for _, connection in pairs(getconnections(parryButton.MouseButton1Click)) do
                connection:Fire()
            end
        end)
        
        if success then
            return true
        end
    end
    
    -- Nếu không tìm thấy nút, bấm phím Space (phím né mặc định)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Config.ParryKey, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Config.ParryKey, false, game)
    end)
    
    return true
end

-- ============================================
-- TOGGLE BUTTONS
-- ============================================

AutoParryToggle.MouseButton1Click:Connect(function()
    Config.AutoParry = not Config.AutoParry
    UpdateButton(AutoParryToggle, Config.AutoParry, "TỰ ĐỘNG BẤM NÉ")
    Notify(Config.AutoParry and "✅ Bật tự động bấm nút né khi thấy màu đỏ!" or "❌ Tắt tự động né!", 2)
end)

AntiRagdollToggle.MouseButton1Click:Connect(function()
    Config.AntiRagdoll = not Config.AntiRagdoll
    UpdateButton(AntiRagdollToggle, Config.AntiRagdoll, "CHỐNG NGÃ")
    Notify(Config.AntiRagdoll and "✅ Bật chống ngã!" or "❌ Tắt chống ngã!", 2)
end)

VisualToggle.MouseButton1Click:Connect(function()
    Config.VisualWarning = not Config.VisualWarning
    UpdateButton(VisualToggle, Config.VisualWarning, "CẢNH BÁO MÀN HÌNH")
    Notify(Config.VisualWarning and "✅ Bật cảnh báo màn hình!" or "❌ Tắt cảnh báo!", 2)
end)

NotificationToggle.MouseButton1Click:Connect(function()
    Config.ShowNotifications = not Config.ShowNotifications
    UpdateButton(NotificationToggle, Config.ShowNotifications, "THÔNG BÁO")
end)

CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Minimize
local minimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        MainFrame:TweenSize(UDim2.new(0, 340, 0, 50), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        MinimizeButton.Text = "□"
    else
        MainFrame:TweenSize(UDim2.new(0, 340, 0, 420), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
        MinimizeButton.Text = "_"
    end
end)

-- ============================================
-- LOOP CHÍNH - QUÉT VÀ PHÁT HIỆN
-- ============================================

local totalEnemies = 0
local realSlapCount = 0

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    
    local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    totalEnemies = 0
    realSlapCount = 0
    local nearestThreat = nil
    local nearestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local enemyRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if enemyRoot then
                local distance = (humanoidRootPart.Position - enemyRoot.Position).Magnitude
                
                if distance < Config.ParryDistance then
                    totalEnemies = totalEnemies + 1
                    
                    -- Đọc màu
                    local colorState = DetectSlapByColor(player.Character)
                    local lastState = LastDetectedColors[player.UserId]
                    
                    if colorState == "red_real" then
                        realSlapCount = realSlapCount + 1
                        
                        -- Phát hiện MỚI màu đỏ
                        if lastState ~= "red_real" then
                            LastDetectedColors[player.UserId] = "red_real"
                            
                            -- Cảnh báo
                            ShowWarning(player.Name)
                            Notify("🔴 " .. player.Name .. " đang TÁT THẬT!", 1.5)
                            
                            -- TỰ ĐỘNG BẤM NÚT NÉ
                            if Config.AutoParry then
                                task.spawn(function()
                                    task.wait(Config.ParryDelay)
                                    local success = PressParryButton()
                                    if success then
                                        Notify("🛡️ Đã bấm nút né!", 1)
                                    end
                                end)
                            end
                        end
                        
                        if distance < nearestDistance then
                            nearestDistance = distance
                            nearestThreat = player
                        end
                        
                    elseif colorState == "white_fake" then
                        if lastState ~= "white_fake" then
                            LastDetectedColors[player.UserId] = "white_fake"
                            Notify("⚪ " .. player.Name .. " chỉ hù dọa!", 1)
                        end
                        
                    else
                        if lastState then
                            LastDetectedColors[player.UserId] = nil
                        end
                    end
                else
                    -- Quá xa - reset
                    if LastDetectedColors[player.UserId] then
                        LastDetectedColors[player.UserId] = nil
                    end
                end
            end
        end
    end
    
    -- Cập nhật status
    if totalEnemies == 0 then
        StatusLabel.Text = "⏳ Chờ vào bàn đấu...\n🎯 Không có đối thủ gần"
    else
        local threatInfo = ""
        if nearestThreat then
            threatInfo = string.format("\n⚠️ GẦN NHẤT: %s (%.1fm)", nearestThreat.Name, nearestDistance)
        end
        
        StatusLabel.Text = string.format("👥 Trong arena\n🎯 Đối thủ: %d | 🔴 Nguy hiểm: %d%s", 
            totalEnemies, realSlapCount, threatInfo)
    end
end)

-- ============================================
-- ANTI RAGDOLL
-- ============================================

RunService.Heartbeat:Connect(function()
    if not Config.AntiRagdoll then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        
        if humanoid:GetState() == Enum.HumanoidStateType.FallingDown then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        
        if humanoid:GetState() == Enum.HumanoidStateType.Ragdoll then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
    
    -- Xóa Ragdoll constraints
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or v:IsA("NoCollisionConstraint") then
            v:Destroy()
        end
    end
end)

-- ============================================
-- DỌN DẸP
-- ============================================

Players.PlayerRemoving:Connect(function(player)
    LastDetectedColors[player.UserId] = nil
end)

-- ============================================
-- KHỞI ĐỘNG
-- ============================================

Notify("✅ Script đã tải thành công!", 3)
Notify("🔴 Đỏ = Tát thật | ⚪ Trắng = Hù dọa", 3)
print("============================================")
print("🥊 SLAP BATTLES AUTO PARRY LOADED")
print("🔴 Script sẽ tự động BẤM NÚT NÉ khi thấy màu đỏ!")
print("⚪ Bỏ qua khi thấy màu trắng (hù dọa)")
print("============================================")
