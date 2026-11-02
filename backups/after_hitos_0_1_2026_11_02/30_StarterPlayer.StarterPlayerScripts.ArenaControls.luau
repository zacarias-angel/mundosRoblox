-- Tipo: LocalScript
-- Ubicacion: StarterPlayer/StarterPlayerScripts/ArenaControls
-- Contexto: Cliente. Salida explicita; servidor decide y no concede premio al cancelar.
local player=game:GetService('Players').LocalPlayer
local remote=game:GetService('ReplicatedStorage'):WaitForChild('RemoteEvents'):WaitForChild('CombatRosterAction')
local gui=Instance.new('ScreenGui');gui.Name='ArenaControls';gui.ResetOnSpawn=false;gui.DisplayOrder=20;gui.IgnoreGuiInset=true;gui.Parent=player:WaitForChild('PlayerGui')
local button=Instance.new('TextButton');button.Name='LeaveArena';button.AnchorPoint=Vector2.new(0,0)
button.Position=UDim2.new(0,16,0,132);button.Size=UDim2.fromOffset(144,44)
button.BackgroundColor3=Color3.fromRGB(70,40,55);button.TextColor3=Color3.new(1,1,1)
button.Font=Enum.Font.GothamBold;button.TextSize=14;button.Text='Salir del combate';button.Parent=gui
Instance.new('UICorner',button).CornerRadius=UDim.new(0,8)
local pending=false
local function refresh() button.Visible=player:GetAttribute('CombatArenaActive')==true;pending=false end
button.Activated:Connect(function() if not pending then pending=true;remote:FireServer({action='cancel-duel'});task.delay(1,function() pending=false end) end end)
player:GetAttributeChangedSignal('CombatArenaActive'):Connect(refresh);refresh()
