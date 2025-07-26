local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local DialogueEvent = ReplicatedStorage.BetweenSides.Remotes.Events.DialogueEvent
local CombatEvent = ReplicatedStorage.BetweenSides.Remotes.Events.CombatEvent
local ToolEvent = ReplicatedStorage.BetweenSides.Remotes.Events.ToolsEvent
local QuestsNpcs = workspace.IgnoreList.Int.NPCs.Quests
local EnemiesFolder = workspace.Playability.Enemys

local QuestDescriptions = require(ReplicatedStorage.MainModules.Essentials.QuestDescriptions)

local EnemyFolders = {}
local QuestDataCache = {
    questsList = {},
    currentQuest = nil,
    currentLevel = -1,
}

local Settings = {
    ClickV2 = false,
    TweenSpeed = 125,
    SelectedTool = "CombatType",
}

local EquippedTool = nil
local OnFarm = false

-- Atualiza lista de quests válidas e ordena por nível
local function UpdateQuestList()
    QuestDataCache.questsList = {}
    for _, quest in pairs(QuestDescriptions) do
        if quest.Goal > 1 then
            table.insert(QuestDataCache.questsList, {
                Level = quest.MinLevel,
                Target = quest.Target,
                NpcName = quest.Npc,
                Id = quest.Id,
            })
        end
    end
    table.sort(QuestDataCache.questsList, function(a, b) return a.Level > b.Level end)
end

-- Retorna quest atual de acordo com o nível do jogador
local function GetCurrentQuest()
    local levelText = Player.PlayerGui.MainUI.MainFrame.StastisticsFrame.LevelBackground.Level.Text
    local playerLevel = tonumber(levelText)
    if not playerLevel then return nil end

    if playerLevel == QuestDataCache.currentLevel then
        return QuestDataCache.currentQuest
    end

    for _, quest in ipairs(QuestDataCache.questsList) do
        if quest.Level <= playerLevel then
            QuestDataCache.currentLevel = playerLevel
            QuestDataCache.currentQuest = quest
            return quest
        end
    end
    return nil
end

-- Verifica se personagem está vivo
local function IsAlive(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- Equipar ferramenta de combate, ativar se necessário
local function EquipCombat(activate)
    if not IsAlive(Player.Character) then return end
    if EquippedTool and EquippedTool:GetAttribute(Settings.SelectedTool) then
        if activate then EquippedTool:Activate() end
        if EquippedTool.Parent == Player.Backpack then
            Player.Character.Humanoid:EquipTool(EquippedTool)
        elseif EquippedTool.Parent ~= Player.Character then
            EquippedTool = nil
        end
        return
    end

    local tool = Player.Character:FindFirstChildOfClass("Tool")
    if tool and tool:GetAttribute(Settings.SelectedTool) then
        EquippedTool = tool
        return
    end

    for _, tool in ipairs(Player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute(Settings.SelectedTool) then
            EquippedTool = tool
            return
        end
    end
end

-- Encontrar inimigo mais próximo
local function GetClosestEnemy(enemyName)
    if EnemyFolders[enemyName] then
        local folder = EnemyFolders[enemyName]
        for _, enemy in pairs(folder:GetChildren()) do
            if enemy:GetAttribute("Respawned") and enemy:GetAttribute("Ready") and enemy:GetAttribute("OriginalName") == enemyName then
                return enemy
            end
        end
    end

    for _, island in ipairs(EnemiesFolder:GetChildren()) do
        for _, enemy in ipairs(island:GetChildren()) do
            if enemy:GetAttribute("OriginalName") == enemyName then
                EnemyFolders[enemyName] = island
                return enemy
            end
        end
    end
    return nil
end

-- Teleporta o jogador suavemente até a posição
local function TweenToPosition(targetCFrame)
    if not IsAlive(Player.Character) or not Player.Character.PrimaryPart then return false end
    Player.Character.Humanoid.Sit = false
    local distance = (Player.Character.PrimaryPart.Position - targetCFrame.Position).Magnitude
    if distance < Settings.TweenSpeed then
        Player.Character.PrimaryPart.CFrame = targetCFrame
        return true
    else
        local tween = TweenService:Create(Player.Character.PrimaryPart, TweenInfo.new(distance / Settings.TweenSpeed, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
        tween:Play()
        return true
    end
end

-- Dar dano nos inimigos
local function DealDamage(enemies)
    CombatEvent:FireServer("DealDamage", {
        CallTime = workspace:GetServerTimeNow(),
        DelayTime = 0,
        Combo = 1,
        Results = enemies,
    })
end

-- Pega a quest se ainda não tiver
local function HasQuest(enemyName)
    local questFrame = Player.PlayerGui.MainUI.MainFrame.CurrentQuest
    return questFrame.Visible and questFrame.Goal.Text:find(enemyName) ~= nil
end

local function TakeQuest(questName, questId)
    local npc = QuestsNpcs:FindFirstChild(questName, true)
    if npc and npc.PrimaryPart then
        DialogueEvent:FireServer("Quests", {NpcName = questName, QuestName = questId})
        TweenToPosition(npc.PrimaryPart.CFrame)
    end
end

-- Loop de farm automático
local function AutoFarmLoop()
    while OnFarm do
        task.wait()
        local currentQuest = GetCurrentQuest()
        if not currentQuest then
            task.wait(2)
            continue
        end
        if not HasQuest(currentQuest.Target) then
            TakeQuest(currentQuest.NpcName, currentQuest.Id)
            task.wait(2)
            continue
        end
        local enemy = GetClosestEnemy(currentQuest.Target)
        if enemy and enemy:FindFirstChild("HumanoidRootPart") then
            local hrp = enemy.HumanoidRootPart
            hrp.Size = Vector3.new(35, 35, 35)
            hrp.CanCollide = false
            EquipCombat(true)
            DealDamage({enemy})
            TweenToPosition(hrp.CFrame * CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, 10, 0))
        end
    end
end

-- Interface (exemplo, usa sua lib)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/V5/Source.lua"))()
local Window = Library:MakeWindow({ "Anonymous", "by NightShadow", "rz-VoxSeas.json" })

local MainTab = Window:MakeTab({ "Farm", "Home" })
local ConfigTab = Window:MakeTab({ "Config", "Settings" })

MainTab:AddSection("Farming")
MainTab:AddToggle({
    "Auto Farm Level", false,
    function(value)
        OnFarm = value
        if value then
            task.spawn(AutoFarmLoop)
        end
    end,
})

ConfigTab:AddToggle({"Click V2", false, {Settings, "ClickV2"}})
ConfigTab:AddToggle({"Tween Speed", 50, 200, 10, 125, {Settings, "TweenSpeed"}})
ConfigTab:AddDropdown({"Select Tool", {"CombatType"}, "CombatType", {Settings, "SelectedTool"}})

-- Inicializar
UpdateQuestList()
