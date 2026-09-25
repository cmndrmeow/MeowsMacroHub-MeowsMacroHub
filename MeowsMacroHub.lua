local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
if not Player then
    Player = Players.PlayerAdded:Wait()
end

local PlayerGui = Player:WaitForChild("PlayerGui")
local AbilityRemotes = ReplicatedStorage:FindFirstChild("AbilityRemotes") or ReplicatedStorage:WaitForChild("AbilityRemotes")

local SaveFileName = "MeowsMacroHub_Config.json"
local MoveKeys = {"Z", "X", "C", "V", "F"}
local WeaponOrder = {"Melee", "Fruit", "Sword", "Gun"}

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = DeepCopy(nestedValue)
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
        Gun   = {Z = false, X = false, C = false, V = false, F = false},
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

local function SafeReadFile(fileName)
    if type(readfile) ~= "function" then
        return nil
    end

    local success, result = pcall(function()
        return readfile(fileName)
    end)

    if not success then
        return nil
    end

    return result
end

local function SafeWriteFile(fileName, content)
    if type(writefile) ~= "function" then
        return false
    end

    local success = pcall(function()
        writefile(fileName, content)
    end)

    return success
end

local function ValidateMovesTable(source)
    if type(source) ~= "table" then
        return false
    end

    for _, weapon in ipairs(WeaponOrder) do
        if type(source[weapon]) ~= "table" then
            return false
        end

        for _, key in ipairs(MoveKeys) do
            if type(source[weapon][key]) ~= "boolean" then
                source[weapon][key] = false
            end
        end
    end

    return true
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

    if not success or type(encoded) ~= "string" then
        warn("Meows MacroHub: failed to encode config")
        return false
    end

    return SafeWriteFile(SaveFileName, encoded)
end

local function LoadConfig()
    local raw = SafeReadFile(SaveFileName)
    if not raw then
        return false
    end

    local success, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)

    if not success or type(decoded) ~= "table" then
        return false
    end

    if type(decoded.Moves) == "table" and ValidateMovesTable(decoded.Moves) then
        for weapon, moveSet in pairs(Config.Moves) do
            if type(decoded.Moves[weapon]) == "table" then
                for _, key in ipairs(MoveKeys) do
                    moveSet[key] = decoded.Moves[weapon][key] == true
                end
            end
        end
    end

    Config.AutoFarm = decoded.AutoFarm == true
    Config.FastAttack = decoded.FastAttack == true

    if type(decoded.SelectedWeapon) == "string" and Config.Moves[decoded.SelectedWeapon] then
        Config.SelectedWeapon = decoded.SelectedWeapon
    end

    if type(decoded.ComboDelay) == "number" and decoded.ComboDelay >= 0 then
        Config.ComboDelay = decoded.ComboDelay
    end

    if type(decoded.MoveDelay) == "number" and decoded.MoveDelay >= 0 then
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

local function CreateButton(Text, Callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 0, 28)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Button.BorderSizePixel = 0
    Button.Text = Text
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 12
    Button.Font = Enum.Font.Gotham
    Button.AutoButtonColor = false

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 5)
    Corner.Parent = Button

    Button.MouseButton1Click:Connect(function()
        if Callback then
            Callback()
        end
    end)

    return Button
end

local function CreateToggle(Text, Default, Callback)
    local State = Default == true
    local Button = CreateButton(Text .. ": " .. (State and "ON" or "OFF"), function()
        State = not State
        Button.Text = Text .. ": " .. (State and "ON" or "OFF")
        if Callback then
            Callback(State)
        end
    end)

    return {
        Label = Text,
        State = State,
        Button = Button,
    }
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
    return Label
end

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

    local success = pcall(function()
        Remote:FireServer()
    end)

    if success then
        task.wait(GetEffectiveMoveDelay())
    end
end

local function ExecuteComboOnce()
    local Moves = Config.Moves[Config.SelectedWeapon]
    if not Moves then
        return
    end

    for _, Key in ipairs(MoveKeys) do
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
            local Moves = Config.Moves[Config.SelectedWeapon]
            if Moves then
                for _, Key in ipairs(MoveKeys) do
                    if not MacroRunning then
                        break
                    end

                    if Moves[Key] then
                        ExecuteMove(Config.SelectedWeapon, Key)
                    end
                end
            end

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

local function ApplySavedState()
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MeowsMacroHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

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

local function AddButton(Text, Callback)
    local Button = CreateButton(Text, Callback)
    Button.Parent = Scroll
    return Button
end

local function AddSection(Text)
    local Label = CreateSection(Text)
    Label.Parent = Scroll
    return Label
end

AddSection("Combat")
ToggleButtons["Auto Farm"] = CreateToggle("Auto Farm", Config.AutoFarm, function(State)
    ToggleAutoFarm(State)
end)
ToggleButtons["Auto Farm"].Button.Parent = Scroll

ToggleButtons["Fast Attack"] = CreateToggle("Fast Attack", Config.FastAttack, function(State)
    Config.FastAttack = State
    SaveConfig()
end)
ToggleButtons["Fast Attack"].Button.Parent = Scroll

AddSection("Weapon")
for _, Weapon in ipairs(WeaponOrder) do
    local Button = AddButton("Weapon: " .. Weapon, function()
        SetWeapon(Weapon)
    end)
    WeaponButtons[Weapon] = Button
end
SetWeapon(Config.SelectedWeapon)

for _, Category in ipairs(WeaponOrder) do
    AddSection(Category .. " Moves")
    for _, Key in ipairs(MoveKeys) do
        local ToggleEntry = CreateToggle(Category .. " " .. Key, Config.Moves[Category][Key], function(State)
            ToggleMove(Category, Key, State)
        end)
        ToggleButtons[Category .. " " .. Key] = ToggleEntry
        ToggleEntry.Button.Parent = Scroll
    end
end

AddSection("Macro")
AddButton("Execute Combo", function()
    if MacroRunning then
        return
    end

    MacroRunning = true
    ExecuteComboOnce()
    task.wait(GetEffectiveComboDelay())
    MacroRunning = false
end)

AddButton("Start Macro", StartMacro)
AddButton("Stop Macro", StopMacro)
AddButton("Save Config", SaveConfig)
AddButton("Load Config", function()
    if LoadConfig() then
        ApplySavedState()
    else
        warn("Meows MacroHub: no saved config found")
    end
end)

if LoadConfig() then
    ApplySavedState()
end

if Config.AutoFarm then
    StartMacro()
end

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
