local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local Config = {
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

local MacroRunning = false

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MeowsMacroHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(420, 330)
Main.Position = UDim2.new(0.5, -210, 0.5, -165)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "🐱 Meows MacroHub"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.Active = true
Title.Parent = Main

local Content = Instance.new("Frame")
Content.Position = UDim2.fromOffset(10, 50)
Content.Size = UDim2.new(1, -20, 1, -60)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 6)
Layout.Parent = Content

local function CreateButton(Text, Callback)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, 0, 0, 32)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Button.BorderSizePixel = 0
    Button.Text = Text
    Button.TextColor3 = Color3.new(1, 1, 1)
    Button.TextSize = 14
    Button.Font = Enum.Font.Gotham
    Button.Parent = Content

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 5)
    ButtonCorner.Parent = Button

    Button.MouseButton1Click:Connect(Callback)

    return Button
end

local function CreateToggle(Text, Default, Callback)
    local State = Default
    local Button

    Button = CreateButton(Text .. ": " .. (State and "ON" or "OFF"), function()
        State = not State
        Button.Text = Text .. ": " .. (State and "ON" or "OFF")
        Callback(State)
    end)

    return Button
end

local function CreateSection(Text)
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 25)
    Label.BackgroundTransparency = 1
    Label.Text = Text
    Label.TextColor3 = Color3.fromRGB(200, 200, 200)
    Label.TextSize = 14
    Label.Font = Enum.Font.GothamBold
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Content
end

local function ExecuteMove(Category, Key)
    if not Config.Moves[Category][Key] then
        return
    end

    print("Meows MacroHub:", Category, Key)
    task.wait(Config.MoveDelay)
end

local function ExecuteCombo()
    if MacroRunning then
        return
    end

    MacroRunning = true

    local Moves = Config.Moves[Config.SelectedWeapon]

    for _, Key in ipairs({"Z", "X", "C", "V", "F"}) do
        if Moves[Key] then
            ExecuteMove(Config.SelectedWeapon, Key)
        end
    end

    task.wait(Config.ComboDelay)
    MacroRunning = false
end

local function StartMacro()
    if MacroRunning then
        return
    end

    MacroRunning = true

    task.spawn(function()
        while MacroRunning do
            local Moves = Config.Moves[Config.SelectedWeapon]

            for _, Key in ipairs({"Z", "X", "C", "V", "F"}) do
                if not MacroRunning then
                    break
                end

                if Moves[Key] then
                    ExecuteMove(Config.SelectedWeapon, Key)
                end
            end

            task.wait(Config.ComboDelay)
        end
    end)
end

local function StopMacro()
    MacroRunning = false
end

local function SetWeapon(Weapon)
    if Config.Moves[Weapon] then
        Config.SelectedWeapon = Weapon
    end
end

local function ToggleMove(Category, Key, State)
    if Config.Moves[Category] then
        Config.Moves[Category][Key] = State
    end
end

CreateSection("Combat")

CreateToggle("Auto Farm", false, function(State)
    Config.AutoFarm = State
end)

CreateToggle("Fast Attack", false, function(State)
    Config.FastAttack = State
end)

CreateSection("Weapon")

CreateButton("Weapon: Melee", function()
    SetWeapon("Melee")
end)

CreateButton("Weapon: Fruit", function()
    SetWeapon("Fruit")
end)

CreateButton("Weapon: Sword", function()
    SetWeapon("Sword")
end)

CreateButton("Weapon: Gun", function()
    SetWeapon("Gun")
end)

CreateSection("Moves")

for _, Key in ipairs({"Z", "X", "C", "V", "F"}) do
    CreateToggle("Melee " .. Key, false, function(State)
        ToggleMove("Melee", Key, State)
    end)
end

CreateSection("Macro")

CreateButton("Execute Combo", ExecuteCombo)
CreateButton("Start Macro", StartMacro)
CreateButton("Stop Macro", StopMacro)

local Dragging = false
local DragStart = nil
local StartPosition = nil

Title.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then

        Dragging = true
        DragStart = Input.Position
        StartPosition = Main.Position
    end
end)

Title.InputChanged:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseMovement
        or Input.UserInputType == Enum.UserInputType.Touch then

        DragStart = DragStart or Input.Position
    end
end)

UserInputService.InputChanged:Connect(function(Input)
    if not Dragging then
        return
    end

    if Input.UserInputType ~= Enum.UserInputType.MouseMovement
        and Input.UserInputType ~= Enum.UserInputType.Touch then
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
    if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then

        Dragging = false
        DragStart = nil
        StartPosition = nil
    end
end)

print("🐱 Meows MacroHub loaded successfully")
