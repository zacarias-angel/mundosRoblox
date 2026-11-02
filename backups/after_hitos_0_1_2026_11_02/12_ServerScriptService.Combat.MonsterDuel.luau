-- Tipo: ModuleScript
-- Ubicacion: ServerScriptService/Combat/MonsterDuel
-- Contexto: Servidor
-- PvE recuperado del backup monolitico y adaptado a arenas/reservas/cleanup idempotente.
local MonsterDuel = {}
local C = require(script.Parent.CombatContext)
local Arena = require(script.Parent.ArenaService)
local Settings = require(script.Parent.CombatSettings)
local reservations = {}
local allowed = {SlimeFuego=true,LoboAgua=true,TortugaPlanta=true,HalconElectrico=true,GolemRoca=true,FireBaby=true,Demonslime1=true,Bloompup=true}
local function send(player, data)
	if player.Parent == C.Players then C.CombatDuelState:FireClient(player, data) end
end
local function meta(duel, kind)
	return {type=kind,duelId=duel.id,opponentKind='monster',opponentName=duel.monsterName,
		opponentMonsterId=duel.monsterId,selfHP=duel.playerHP,enemyHP=duel.monsterHP,
		selfMaxHP=duel.playerMaxHP,enemyMaxHP=duel.monsterMaxHP,selfStars=0,opponentStars=0}
end
local function reward(player, duel)
	local data = C.MonstersData[duel.monsterId]
	local rarity = string.lower(data.Rarity or 'common')
	local bits = duel.bitsRewardOnWin
	player:SetAttribute('Bits', math.max(0, tonumber(player:GetAttribute('Bits')) or 0) + bits)
	local pityAttr = 'CapturePity_' .. rarity
	local pity = tonumber(player:GetAttribute(pityAttr)) or 0
	local base = C.FragmentsData.getCaptureChance(rarity)
	local chance = base > 0 and math.min(1, base + pity * duel.settings.CapturePityBonus) or 0
	local result = {monsterId=duel.monsterId,captured=math.random() < chance}
	local fragments = 0
	if result.captured then
		result.wasNew = C.TeamManager.unlockMonster(player,duel.monsterId)
		player:SetAttribute(pityAttr,0)
	else
		fragments = C.FragmentsData.getFragmentDrop(rarity)
		if fragments > 0 then C.TeamManager.addFragments(player,duel.monsterId,fragments) end
		result.fragmentsDropped = fragments
		player:SetAttribute(pityAttr,pity+1)
	end
	return bits,result,fragments
end

function MonsterDuel.endMonsterDuel(player, reason, winner)
	local duel = C.activeMonsterDuels[player]
	if not duel or duel.ended then return false end
	duel.ended=true;duel.started=false
	C.activeMonsterDuels[player]=nil
	for _,connection in ipairs(duel.connections) do connection:Disconnect() end
	if reservations[duel.monsterModel] == duel then reservations[duel.monsterModel]=nil end
	if duel.monsterModel.Parent then
		duel.monsterModel:SetAttribute('CombatReservedBy',nil)
		for prompt,enabled in pairs(duel.prompts) do if prompt.Parent then prompt.Enabled=enabled end end
	end
	local state = C.playerStates[player]
	if state then state.duelActive=false;state.duelStarted=false;state.duelId=nil;state.resolving=nil end
	Arena.release(duel.arena)
	C.PetCubeService.clearPlayerCubes(player)
	if reason ~= 'player-left' and reason ~= 'character-removing' and reason ~= 'character-died' and player.Character == duel.character then
		C.PetCubeService.spawnPlayerTeamCubes(player, C.TeamManager.getOrCreateTeam(player), C.TeamManager.getSelectedFollowerMonsterId(player))
	end
	local payload=meta(duel,'duel-ended');payload.reason=reason
	payload.winnerUserId=winner=='player' and player.UserId or (winner=='monster' and 0 or nil)
	payload.bitsDelta=0
	if winner=='player' and reason=='hp-depleted' and not duel.rewarded then
		duel.rewarded=true
		local ok,bits,capture,fragments=pcall(reward,player,duel)
		if ok then payload.bitsDelta=bits;payload.captureResult=capture;payload.fragmentsAwarded=fragments
		else warn('[MonsterDuel] Reward failed: '..tostring(bits));payload.reason='reward-error' end
	end
	send(player,payload)
	if player.Parent==C.Players then
		C.CombatSync:FireClient(player,{grid=state and state.grid or {},duelActive=false,duelStarted=false,duelId=duel.id})
		C.sendRosterState(player,'duel-ended')
	end
	return true
end

local function startAI(player,duel)
	task.spawn(function()
		local turn=0
		while C.activeMonsterDuels[player]==duel and duel.started do
			task.wait(duel.settings.NpcAttackInterval)
			if C.activeMonsterDuels[player]~=duel or duel.ended then return end
			local state=C.playerStates[player]
			while state and state.resolving and C.activeMonsterDuels[player]==duel do task.wait(0.05) end
			if C.activeMonsterDuels[player]~=duel or duel.ended then return end
			turn+=1
			local hpRatio=duel.monsterHP/duel.monsterMaxHP
			local combo=math.random(2,hpRatio < 0.35 and 6 or 4)
			if duel.playerHP/duel.playerMaxHP < 0.3 then combo=math.min(combo,3) end
			local special=turn%4==0
			if special then combo=math.min(7,combo+2) end
			local data=C.MonstersData[duel.monsterId]
			local element=data.Element
			local matched=math.random()<0.8
			local damage=matched and math.floor(data.BaseStats.Attack*combo*duel.settings.NpcAttackMultiplier) or 0
			local target=C.DuelManager.getPlayerTargetPosition(player)
			if damage>0 and target and duel.monsterRoot.Parent then
				C.CombatProjectileVfx:FireClient(player,{startPos=duel.monsterRoot.Position,targetPos=target,element=element,
					size=C.VFX_PROJECTILE_SIZE,travelTime=C.VFX_PROJECTILE_TRAVEL_TIME,color=C.ELEMENT_PROJECTILE_COLORS[element]})
			end
			duel.playerHP=math.max(0,duel.playerHP-damage)
			local payload=meta(duel,'monster-attack');payload.damage=damage;payload.element=element;payload.comboCount=combo
			payload.attackTag=damage==0 and 'miss' or (special and 'special' or 'basic')
			send(player,payload)
			if duel.playerHP<=0 then MonsterDuel.endMonsterDuel(player,'hp-depleted','monster');return end
		end
	end)
end

function MonsterDuel.onMonsterChallenged(player,model)
	local function reject(reason) send(player,{type='challenge-failed',reason=reason});return false,reason end
	if C.activeDuels[player] or C.activeMonsterDuels[player] then return reject('duel-busy') end
	if typeof(model)~='Instance' or not model:IsA('Model') or not model:IsDescendantOf(workspace) or model:GetAttribute('IsMonster')~=true or model:GetAttribute('IsCompanion')==true then return reject('target-invalid') end
	if reservations[model] then return reject('monster-busy') end
	local id=model:GetAttribute('MonsterId')
	if not allowed[id] or not C.MonstersData[id] then return reject('monster-data-missing') end
	local state=C.playerStates[player]
	local character=player.Character
	local root=character and character:FindFirstChild('HumanoidRootPart')
	local humanoid=character and character:FindFirstChildOfClass('Humanoid')
	local monsterRoot=model.PrimaryPart or model:FindFirstChildWhichIsA('BasePart',true)
	if not state or not root or not humanoid or humanoid.Health<=0 or not monsterRoot then return reject('character-unavailable') end
	local settings=Settings.forDuel()
	if (root.Position-monsterRoot.Position).Magnitude>settings.ChallengeDistance then return reject('target-too-far') end
	local team=C.TeamManager.getOrCreateTeam(player)
	if not C.TeamManager.validateTeam(team) then return reject('team-invalid') end
	local arena,arenaError=Arena.acquire(player)
	if not arena then return reject(arenaError) end
	C.duelSequence+=1
	local data=C.MonstersData[id]
	local hp=C.TeamManager.calculateTeamHP(team)
	local monsterHP=math.floor(data.BaseStats.HP*settings.NpcHealthMultiplier)
	local rarity=string.lower(data.Rarity or 'common')
	local bits=({common=settings.CommonBits,rare=settings.RareBits,epic=settings.EpicBits,legendary=settings.LegendaryBits})[rarity] or settings.CommonBits
	local duel={id='npc-'..C.duelSequence,player=player,character=character,monsterModel=model,monsterId=id,
		monsterName=data.Name or id,playerHP=hp,playerMaxHP=hp,monsterHP=monsterHP,monsterMaxHP=monsterHP,
		settings=settings,bitsRewardOnWin=bits,arena=arena,connections={},prompts={},started=false}
	reservations[model]=duel;C.activeMonsterDuels[player]=duel
	state.team=team;state.grid=C.GridResolver.createStableGrid();state.revision=0;state.resolving=nil
	state.duelId=duel.id;state.duelActive=true;state.duelStarted=false
	model:SetAttribute('CombatReservedBy',player.UserId)
	for _,v in ipairs(model:GetDescendants()) do if v:IsA('ProximityPrompt') then duel.prompts[v]=v.Enabled;v.Enabled=false end end
	local ok,err=pcall(function()
		assert(Arena.enter(arena,player),'Cannot enter arena')
		local visual,visualRoot=Arena.spawnOpponent(arena,model)
		assert(visualRoot,'Opponent has no root');duel.monsterRoot=visualRoot
		C.PetCubeService.spawnPlayerTeamDuelLine(player,team,visualRoot.Position)
	end)
	if not ok then warn('[MonsterDuel] Setup: '..tostring(err));MonsterDuel.endMonsterDuel(player,'setup-failed');return false,'setup-failed' end
	table.insert(duel.connections,humanoid.Died:Connect(function() MonsterDuel.endMonsterDuel(player,'character-died','monster') end))
	table.insert(duel.connections,player.CharacterRemoving:Connect(function(old) if old==character then MonsterDuel.endMonsterDuel(player,'character-removing') end end))
	table.insert(duel.connections,model.AncestryChanged:Connect(function() if not model:IsDescendantOf(workspace) then MonsterDuel.endMonsterDuel(player,'target-removed') end end))
	send(player,meta(duel,'duel-intro'))
	C.CombatSync:FireClient(player,{grid=state.grid,revision=state.revision,duelId=duel.id,duelActive=true,duelStarted=false})
	task.spawn(function()
		for n=settings.CountdownSeconds,1,-1 do
			if C.activeMonsterDuels[player]~=duel then return end
			local payload=meta(duel,'countdown');payload.value=n;send(player,payload);task.wait(1)
		end
		if C.activeMonsterDuels[player]~=duel then return end
		duel.started=true;state.duelStarted=true
		send(player,meta(duel,'duel-started'))
		C.CombatSync:FireClient(player,{grid=state.grid,revision=state.revision,duelId=duel.id,duelActive=true,duelStarted=true})
		startAI(player,duel)
	end)
	task.delay(settings.DuelTimeoutSeconds,function() if C.activeMonsterDuels[player]==duel then MonsterDuel.endMonsterDuel(player,'timeout') end end)
	return true,duel.id
end
return MonsterDuel
