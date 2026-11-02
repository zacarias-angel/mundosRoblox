-- Tipo: ModuleScript
-- Ubicacion: ServerScriptService/Combat/ArenaService
-- Contexto: Servidor
-- Arenas aisladas y acotadas; nunca mover el salvaje original.
local ArenaService = {}
local leases = {}
local SLOT_COUNT = 8
local ORIGIN = Vector3.new(5000, 1000, 0)
local SPACING = 240

local function part(parent, name, size, cf, color, material)
	local p = Instance.new('Part')
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth; p.Parent = parent
	return p
end

function ArenaService.ensureArenas()
	local folder = workspace:FindFirstChild('CombatArenas')
	if not folder then folder = Instance.new('Folder'); folder.Name = 'CombatArenas'; folder.Parent = workspace end
	for i = 1, SLOT_COUNT do
		if not folder:FindFirstChild('Arena_' .. i) then
			local arena = Instance.new('Model'); arena.Name = 'Arena_' .. i
			arena.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			local base = CFrame.new(ORIGIN + Vector3.new((i - 1) * SPACING, 0, 0))
			part(arena, 'Platform', Vector3.new(100, 3, 90), base * CFrame.new(0, -1.5, 0), Color3.fromRGB(25, 35, 55), Enum.Material.Slate)
			for _,x in ipairs({-49, 49}) do part(arena, 'Edge', Vector3.new(1, 1, 90), base * CFrame.new(x, 0.5, 0), Color3.fromRGB(45, 180, 205), Enum.Material.Neon) end
			for _,z in ipairs({-44, 44}) do part(arena, 'Edge', Vector3.new(98, 1, 1), base * CFrame.new(0, 0.5, z), Color3.fromRGB(45, 180, 205), Enum.Material.Neon) end
			for _,z in ipairs({-12, 12}) do part(arena, 'FormationPad', Vector3.new(24, 0.15, 8), base * CFrame.new(0, 0.1, z), Color3.fromRGB(42, 73, 97)) end
			arena:SetAttribute('PlayerCFrame', base * CFrame.lookAt(Vector3.new(0, 3, 16), Vector3.new(0, 3, -12)))
			arena:SetAttribute('OpponentCFrame', base * CFrame.lookAt(Vector3.new(0, 3, -16), Vector3.new(0, 3, 12)))
			arena:SetAttribute('CameraCFrame', base * CFrame.lookAt(Vector3.new(36, 29, 43), Vector3.new(0, 2, -3)) * CFrame.new(14, 0, 0))
			arena:SetAttribute('Slot', i)
			arena.Parent = folder
		end
	end
	return folder
end

function ArenaService.acquire(owner)
	local folder = ArenaService.ensureArenas()
	for i = 1, SLOT_COUNT do
		if not leases[i] then
			local lease = {slot = i, arena = folder:FindFirstChild('Arena_' .. i), owner = owner, participants = {}}
			leases[i] = lease
			return lease
		end
	end
	return nil, 'arena-full'
end

function ArenaService.enter(lease, player, side)
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	if not root or not humanoid or humanoid.Health <= 0 then return false, 'character-unavailable' end
	lease.participants[player] = {character = character, root = root, humanoid = humanoid,
		cframe = root.CFrame, anchored = root.Anchored, walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower, autoRotate = humanoid.AutoRotate, platformStand = humanoid.PlatformStand}
	-- Mantener cargado el punto original mientras el personaje esta lejos en arena.
	local foci = workspace:FindFirstChild('CombatReturnFoci')
	if not foci then foci = Instance.new('Folder'); foci.Name = 'CombatReturnFoci'; foci.Parent = workspace end
	local focus = part(foci, tostring(player.UserId), Vector3.one, root.CFrame, Color3.new())
	focus.Transparency = 1; focus.CanCollide = false; focus.CanTouch = false; focus.CanQuery = false
	lease.participants[player].focus = focus
	player:AddReplicationFocus(focus)
	character:SetAttribute('CombatArenaCamera', lease.arena:GetAttribute('CameraCFrame'))
	character:SetAttribute('CombatArenaActive', true)
	player:SetAttribute('CombatArenaActive', true)
	root.Anchored = true; root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = lease.arena:GetAttribute(side == 'opponent' and 'OpponentCFrame' or 'PlayerCFrame')
	humanoid.WalkSpeed = 0; humanoid.JumpPower = 0; humanoid.AutoRotate = false; humanoid.PlatformStand = true
	return true
end

function ArenaService.release(lease)
	if not lease or lease.released then return end
	lease.released = true
	for player, previous in pairs(lease.participants) do
		local character = previous.character
		if character.Parent and player.Character == character then
			local root, humanoid = previous.root, previous.humanoid
			if root.Parent then
				root.CFrame = previous.cframe; root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
				root.Anchored = previous.anchored
			end
			if humanoid.Parent then
				humanoid.WalkSpeed = previous.walkSpeed; humanoid.JumpPower = previous.jumpPower
				humanoid.AutoRotate = previous.autoRotate; humanoid.PlatformStand = previous.platformStand
			end
		end
		character:SetAttribute('CombatArenaActive', nil); character:SetAttribute('CombatArenaCamera', nil)
		player:SetAttribute('CombatArenaActive', nil)
		if previous.focus then
			pcall(function() player:RemoveReplicationFocus(previous.focus) end)
			previous.focus:Destroy()
		end
	end
	if lease.visual then lease.visual:Destroy() end
	if leases[lease.slot] == lease then leases[lease.slot] = nil end
end

function ArenaService.spawnOpponent(lease, source)
	local clone = source:Clone(); clone.Name = 'OpponentVisual'
	clone:SetAttribute('IsMonster', false); clone:SetAttribute('IsCompanion', true)
	for _,obj in ipairs(clone:GetDescendants()) do
		if obj:IsA('BaseScript') or obj:IsA('ProximityPrompt') then obj:Destroy()
		elseif obj:IsA('BasePart') then obj.Anchored = true; obj.CanCollide = false; obj.CanTouch = false; obj.CanQuery = false end
	end
	local target = lease.arena:GetAttribute('OpponentCFrame')
	clone:PivotTo(target)
	local box, size = clone:GetBoundingBox()
	clone:PivotTo(clone:GetPivot() + Vector3.new(0, target.Position.Y - 3 - (box.Position.Y - size.Y * 0.5), 0))
	clone.Parent = lease.arena; lease.visual = clone
	return clone, clone.PrimaryPart or clone:FindFirstChildWhichIsA('BasePart', true)
end

return ArenaService
