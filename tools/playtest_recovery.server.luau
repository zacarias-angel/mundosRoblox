-- QA de gameplay, solo Studio. Insertar temporalmente como Script en ServerScriptService.
-- No instala remotes, no persiste datos ni agrega comandos a la build de edicion.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local C = require(game.ServerScriptService.Combat.CombatContext)
local Arena = require(game.ServerScriptService.Combat.ArenaService)
local player = game.Players:GetPlayers()[1]
local bridge = Instance.new("BindableFunction")
bridge.Name = "RecoveryQA"
bridge.Parent = game.ServerStorage
local report = Instance.new("StringValue")
report.Name = "RecoveryQAResults"
report.Parent = game.ServerStorage
local results = {}
local function record(key, value)
	results[key] = value
	report.Value = game.HttpService:JSONEncode(results)
end
local function start(name)
	local model = workspace[name]
	player.Character.HumanoidRootPart.CFrame = model:GetPivot() + Vector3.new(0, 3, 0)
	assert(C.MonsterDuel.onMonsterChallenged(player, model))
	local duel = C.activeMonsterDuels[player]
	repeat task.wait(0.1) until duel.started or duel.ended
	return duel
end
local function bestPath(grid)
	local best, bestScore
	for _ = 1, 150 do
		local path = {{col = math.random(1, 5), row = math.random(1, 5)}}
		for _ = 1, 16 do
			local previous = path[#path]
			local choices = {}
			for _, delta in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local x, y = previous.col + delta[1], previous.row + delta[2]
				if x >= 1 and x <= 5 and y >= 1 and y <= 5 then table.insert(choices, {col = x, row = y}) end
			end
			table.insert(path, choices[math.random(#choices)])
		end
		local copy = C.CombatGrid.cloneGrid(grid)
		C.CombatGrid.applySwapPath(copy, path)
		local score = #C.CombatGrid.findMatches(copy).combos
		if not bestScore or score > bestScore then best, bestScore = path, score end
	end
	return best
end
local function run()
	local duel = C.activeMonsterDuels[player]
	if duel then C.MonsterDuel.endMonsterDuel(player, "cancelled") end
	local d = start("Demonslime1")
	local state = C.playerStates[player]
	local revision = state.revision
	local invalid = {
		{path = {{col = 0, row = 1}, {col = 1, row = 1}}},
		{path = {{col = 1, row = 1}, {col = 4, row = 4}}},
		{path = {{col = 0/0, row = 1}, {col = 1, row = 1}}},
		{path = {{col = 1}, {col = 1, row = 1}}},
		{path = {{col = 1, row = 1}, {col = 2, row = 1}}, duelId = "old-duel", revision = 0},
	}
	for _, payload in ipairs(invalid) do
		task.wait(0.2)
		C.GridResolver.onCombatSubmit(player, payload)
		assert(state.revision == revision, "Invalid payload changed board")
	end
	local tooLong = {}
	for i = 1, 129 do tooLong[i] = {col = 1, row = 1} end
	task.wait(0.2)
	C.GridResolver.onCombatSubmit(player, {path = tooLong, duelId = state.duelId, revision = state.revision})
	assert(state.revision == revision)
	record("invalidPayloadsRejected", 6)
	local leases = {}
	for i = 1, 7 do table.insert(leases, assert(Arena.acquire("qa-" .. i))) end
	assert(Arena.acquire("overflow") == nil)
	for _, lease in ipairs(leases) do Arena.release(lease) end
	record("arenaCapacity", 8)
	local before = player:GetAttribute("Bits")
	local returnCF = d.arena.participants[player].cframe
	C.MonsterDuel.endMonsterDuel(player, "cancelled")
	assert((player.Character.HumanoidRootPart.Position - returnCF.Position).Magnitude < 0.01)
	assert(player:GetAttribute("Bits") == before)
	assert(#workspace.CombatReturnFoci:GetChildren() == 0)
	record("cancelExactReturn", true)
	d = start("FireBaby")
	for turn = 1, 35 do
		if d.ended then break end
		local path = bestPath(state.grid)
		C.GridResolver.onCombatSubmit(player, {path = path, duelId = state.duelId, revision = state.revision})
		repeat task.wait(0.1) until not state.resolving or d.ended
		record("progress", {turn = turn, enemyHP = d.monsterHP, selfHP = d.playerHP})
		task.wait(0.3)
	end
	assert(d.ended and d.monsterHP == 0, "Full-health victory failed")
	assert(player:GetAttribute("Bits") - before == 50, "Incorrect victory reward")
	local total = player:GetAttribute("Bits")
	assert(not C.MonsterDuel.endMonsterDuel(player, "hp-depleted", "player"))
	assert(player:GetAttribute("Bits") == total, "Duplicate reward")
	record("fullHealthVictory", {species = "FireBaby", bits = 50, once = true, playerTookDamage = d.playerHP < d.playerMaxHP})
	d = start("FireBaby")
	C.MonsterDuel.endMonsterDuel(player, "cancelled")
	record("consecutiveCombat", true)
	d = start("Demonslime1")
	player:LoadCharacterAsync()
	task.wait(4)
	assert(not C.activeMonsterDuels[player] and not player:GetAttribute("CombatArenaActive"))
	assert(workspace.PlayerPetCubes:FindFirstChild(player.Name), "Follower missing after respawn")
	record("respawnCleanup", true)
	d = start("FireBaby")
	C.MonsterDuel.endMonsterDuel(player, "cancelled")
	record("combatAfterRespawn", true)
	assert(#workspace.CombatReturnFoci:GetChildren() == 0)
	record("returnFocusCleanup", true)
end
bridge.OnInvoke = function(action, argument)
	if action == "run" then
		task.spawn(function()
			local ok, err = pcall(run)
			record("completed", ok)
			if not ok then record("error", tostring(err)) end
		end)
		return "running"
	elseif action == "start" then
		local d = start(argument or "Demonslime1")
		return {id = d.id, hp = d.monsterHP}
	elseif action == "cancel" then
		return C.MonsterDuel.endMonsterDuel(player, "cancelled")
	elseif action == "status" then
		local d = C.activeMonsterDuels[player]
		local state = C.playerStates[player]
		return {active = d ~= nil, enemyHP = d and d.monsterHP, selfHP = d and d.playerHP,
			revision = state.revision, resolving = state.resolving ~= nil, bits = player:GetAttribute("Bits"),
			anchored = player.Character.HumanoidRootPart.Anchored, position = tostring(player.Character.HumanoidRootPart.Position)}
	elseif action == "defeat" then
		local d = C.activeMonsterDuels[player]
		if d then d.playerHP = 1 end
		return true
	elseif action == "death" then
		player.Character.Humanoid.Health = 0
		return true
	end
end
record("ready", true)
