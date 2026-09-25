local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local AbilityRemotes = ReplicatedStorage:FindFirstChild("AbilityRemotes")
if not AbilityRemotes then
    AbilityRemotes = ReplicatedStorage:WaitForChild("AbilityRemotes")
end

local SaveFileName = "MeowsMacroHub_Config.json"

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, item in pairs(value) do
        copy[key] = DeepCopy(item)
    end
    return copy
end

local DefaultConfig = {
    AutoFarm = false,
    FastAttack = false,
    SelectedWeapon = "Melee",
    ComboDelay = 0.25,
    MoveDelay = 0.10,
    Moves = {
        Melee = {Z = false, X = false, C = false, V = false, F = false},
        Fruit = {Z = false, X = false, C = false, V = false, F = false},
        Sword = {Z = false, X = false, C = false, V = false, F = false},
        Gun = {Z = false, X = false, C = false, V = false, F = false}
    }
}

local Config = DeepCopy(DefaultConfig)
local MacroRunning = false
local WeaponButtons = {}
local ToggleButtons = {}

local function GetEffectiveMoveDelay()
    return Config.FastAttack and 0.04 or Config.MoveDelay
end

local function GetEffectiveComboDelay()
    return Config.FastAttack and 0.08 or Config.ComboDelay
end

local function SaveConfig()
    local payload = {
        AutoFarm = Config.AutoFarm,
        FastAttack = Config.FastAttack,
        SelectedWeapon = Config.SelectedWeapon,
        ComboDelay = Config.ComboDelay,
        MoveDelay = Config.MoveDelay,
        Moves = Config.Moves,
    }

    local success, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)

    if not success then
        warn("Meows MacroHub: Failed to encode config")
        return
    end

    pcall(function()
        writefile(SaveFileName, encoded)
    end)
end

local function LoadConfig()
    local success, raw = pcall(function()
        return readfile(SaveFileName)
    end)

    if not success or not raw then
        return false
    end

    local parsedOk, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not parsedOk or type(decoded) ~= "table" then
        return false
    end

    if type(decoded.Moves) == "table" then
        for Category, MoveSet in pairs(Config.Moves) do
            if type(decoded.Moves[Category]) == "table" then
                for Key, _ in pairs(MoveSet) do
                    MoveSet[Key] = decoded.Moves[Category][Key] == true
                end
            end
        end
    end

    Config.AutoFarm = decoded.AutoFarm == true
    Config.FastAttack = decoded.FastAttack == true

    if type(decoded.SelectedWeapon) == "string" and Config.Moves[decoded.SelectedWeapon] then
        Config.SelectedWeapon = decoded.SelectedWeapon
    end

    if type(decoded.ComboDelay) == "number" then
        Config.ComboDelay = decoded.ComboDelay
    end

    if type(decoded.MoveDelay) == "number" then
        Config.MoveDelay = decoded.MoveDelay
    end

    return true
end

local function UpdateToggleButton(ToggleEntry, Value)
    if not ToggleEntry then
        return
    end

    ToggleEntry.State = Value
    ToggleEntry.Button.Text = ToggleEntry.Label .. ": " .. (Value and "ON" or "OFF")
end

-- GUI

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MeowsMacroHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(300, 260)
Main.Position = UDim2.new(0.5, -150, 0.5, -130)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundTransparency = 1
Title.Text = "🐱 Meows MacroHub"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.Active = true
Title.Parent = Main

local Scroll = Instance.new("ScrollingFrame")
Scroll.Name = "Scroll"
Scroll.Position = UDim2.fromOffset(8, 40)
Scroll.Size = UDim2.new(1, -16, 1, -48)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.CanvasSize = UDim2.fromOffset(0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
Scroll.Parent = Main

local Padding = Instance.new("UIPadding")
Padding.PaddingLeft = UDim.new(0, 2)
Padding.PaddingRight = UDim.new(0, 6)
Padding.PaddingBottom = UDim.new(0, 6)
Padding.Parent = Scroll

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 4)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Scroll

local function CreateButton(Text, Callback)
    local Button = Instance.new("TextButton")

    Button.Size = UDim2.new(1, 0, 0, 28)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Button.BorderSizePixel = 0
    Button.Text = Text
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 12
    Button.Font = Enum.Font.Gotham
    Button.Parent = Scroll

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 5)
    ButtonCorner.Parent = Button

    Button.MouseButton1Click:Connect(Callback)

    return Button
end

local function CreateToggle(Text, Default, Callback)
    local State = Default
    local Button = CreateButton(Text .. ": " .. (State and "ON" or "OFF"), function()
        State = not State
        Button.Text = Text .. ": " .. (State and "ON" or "OFF")
        Callback(State)
    end)

    local ToggleEntry = {
        Label = Text,
        State = State,
        Button = Button,
    }

    return ToggleEntry
end

local function CreateSection(Text)
    local Label = Instance.new("TextLabel")

    Label.Size = UDim2.new(1, 0, 0, 22)
    Label.BackgroundTransparency = 1
    Label.Text = Text
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 12
    Label.Font = Enum.Font.GothamBold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Scroll
end

-- REMOTE MOVE EXECUTION

local function ExecuteMove(Category, Key)
    local CategoryMoves = Config.Moves[Category]

    if not CategoryMoves or not CategoryMoves[Key] then
        return
    end

    local CategoryFolder = AbilityRemotes:FindFirstChild(Category)

    if not CategoryFolder then
        warn("Meows MacroHub: Missing category:", Category)
        return
    end

    local Remote = CategoryFolder:FindFirstChild(Key)

    if not Remote or not Remote:IsA("RemoteEvent") then
        warn("Meows MacroHub: Missing RemoteEvent:", Category, Key)
        return
    end

    Remote:FireServer()
    task.wait(GetEffectiveMoveDelay())
end

local function ExecuteSequence(IsLoopMode)
    local Moves = Config.Moves[Config.SelectedWeapon]
    if not Moves then
        return
    end

    for _, Key in ipairs({"Z", "X", "C", "V", "F"}) do
        if IsLoopMode and not MacroRunning then
            break
        end

        if Moves[Key] then
            ExecuteMove(Config.SelectedWeapon, Key)
        end
    end
end

local function StartMacro()
    if MacroRunning then
        return
    end

    MacroRunning = true

    task.spawn(function()
        while MacroRunning do
            ExecuteSequence(true)

            if MacroRunning then
                task.wait(GetEffectiveComboDelay())
            end
        end
    end)
end

local function StopMacro()
    MacroRunning = false
end

local function SetWeapon(Weapon)
    if not Config.Moves[Weapon] then
        return
    end

    Config.SelectedWeapon = Weapon
    SaveConfig()

    for Name, Button in pairs(WeaponButtons) do
        if Name == Weapon then
            Button.BackgroundColor3 = Color3.fromRGB(82, 128, 255)
        else
            Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        end
    end
end

local function ToggleMove(Category, Key, State)
    if Config.Moves[Category] then
        Config.Moves[Category][Key] = State
        SaveConfig()
    end
end

local function ToggleAutoFarm(State)
    Config.AutoFarm = State

    if State then
        StartMacro()
    else
        StopMacro()
    end

    SaveConfig()
end

local function ApplyLoadedState()
    if ToggleButtons["Auto Farm"] then
        UpdateToggleButton(ToggleButtons["Auto Farm"], Config.AutoFarm)
    end

    if ToggleButtons["Fast Attack"] then
        UpdateToggleButton(ToggleButtons["Fast Attack"], Config.FastAttack)
    end

    for Category, MoveSet in pairs(Config.Moves) do
        for Key, Enabled in pairs(MoveSet) do
            local ToggleName = Category .. " " .. Key
            if ToggleButtons[ToggleName] then
                UpdateToggleButton(ToggleButtons[ToggleName], Enabled)
            end
        end
    end

    if WeaponButtons[Config.SelectedWeapon] then
        SetWeapon(Config.SelectedWeapon)
    end
end

-- Combat

CreateSection("Combat")

ToggleButtons["Auto Farm"] = CreateToggle("Auto Farm", Config.AutoFarm, function(State)
    ToggleAutoFarm(State)
end)

ToggleButtons["Fast Attack"] = CreateToggle("Fast Attack", Config.FastAttack, function(State)
    Config.FastAttack = State
    SaveConfig()
end)

-- Weapon

CreateSection("Weapon")

for _, Weapon in ipairs({"Melee", "Fruit", "Sword", "Gun"}) do
    local Button = CreateButton("Weapon: " .. Weapon, function()
        SetWeapon(Weapon)
    end)
    WeaponButtons[Weapon] = Button
end

SetWeapon(Config.SelectedWeapon)

-- Moves

local Categories = {"Melee", "Fruit", "Sword", "Gun"}

for _, Category in ipairs(Categories) do
    CreateSection(Category .. " Moves")

    for _, Key in ipairs({"Z", "X", "C", "V", "F"}) do
        local ToggleEntry = CreateToggle(Category .. " " .. Key, Config.Moves[Category][Key], function(State)
            ToggleMove(Category, Key, State)
        end)

        ToggleButtons[Category .. " " .. Key] = ToggleEntry
    end
end

-- Macro

CreateSection("Macro")

CreateButton("Execute Combo", function()
    if MacroRunning then
        return
    end

    MacroRunning = true
    ExecuteSequence(false)
    task.wait(GetEffectiveComboDelay())
    MacroRunning = false
end)

CreateButton("Start Macro", StartMacro)
CreateButton("Stop Macro", StopMacro)
CreateButton("Save Config", SaveConfig)
CreateButton("Load Config", function()
    if LoadConfig() then
        ApplyLoadedState()
    else
        warn("Meows MacroHub: No saved config found")
    end
end)

-- Load saved config

if LoadConfig() then
    ApplyLoadedState()
end

-- Dragging

local Dragging = false
local DragStart = nil
local StartPosition = nil

Title.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
        DragStart = Input.Position
        StartPosition = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(Input)
    if not Dragging then
        return
    end

    if Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local Delta = Input.Position - DragStart

    Main.Position = UDim2.new(
        StartPosition.X.Scale,
        StartPosition.X.Offset + Delta.X,
        StartPosition.Y.Scale,
        StartPosition.Y.Offset + Delta.Y
    )
end)

UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
        Dragging = false
        DragStart = nil
        StartPosition = nil
    end
end)

print("🐱 Meows MacroHub loaded successfully")
