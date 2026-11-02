-- Tipo: ModuleScript
-- Ubicacion: ServerScriptService/Combat/GridResolver
-- Contexto: Servidor. Un solo turno activo, revision de tablero y tareas ligadas al duelo.
local GridResolver={}
local C=require(script.Parent.CombatContext)
local MAX_PATH=128
local function sync(player,state,data)
	if player.Parent~=C.Players then return end
	data.grid=state.grid;data.duelId=state.duelId;data.revision=state.revision or 0
	C.CombatSync:FireClient(player,data)
end
function GridResolver.createStableGrid()
	local grid={}
	local elements=C.CombatGrid.getElementTypes()
	for col=1,C.COLS do
		grid[col]={}
		for row=1,C.ROWS do
			local choices={}
			for _,element in ipairs(elements) do
				local horizontal=col>2 and grid[col-1][row].elementType==element and grid[col-2][row].elementType==element
				local vertical=row>2 and grid[col][row-1].elementType==element and grid[col][row-2].elementType==element
				if not horizontal and not vertical then table.insert(choices,element) end
			end
			grid[col][row]={elementType=choices[math.random(#choices)]}
		end
	end
	return grid
end
local function validate(payload)
	if type(payload)~='table' or type(payload.path)~='table' or #payload.path<2 or #payload.path>MAX_PATH then return false end
	local count=0
	for key,cell in pairs(payload.path) do
		count+=1
		if count>MAX_PATH or type(key)~='number' or key~=math.floor(key) or key<1 or key>#payload.path or type(cell)~='table' then return false end
		for _,keyName in ipairs({'col','row'}) do
			local v=cell[keyName]
			if type(v)~='number' or v~=v or v~=math.floor(v) then return false end
		end
		if cell.col<1 or cell.col>C.COLS or cell.row<1 or cell.row>C.ROWS then return false end
	end
	return count==#payload.path and C.CombatGrid.validateSwapPath(payload.path).valid
end
local function duration(cascades)
	local time=0
	for _,cascade in ipairs(cascades) do
		time+=#cascade.combos*(C.COMBO_SCALE_OUT_TIME+C.COMBO_STAGGER_TIME+0.01)
		time+=C.FALL_TWEEN_TIME+C.BOUNCE_DURATION+C.CASCADE_GAP_TIME+0.05
	end
	return time
end
function GridResolver.onCombatSubmit(player,payload)
	local state=C.playerStates[player]
	if not state then return end
	local now=os.clock()
	if now-(state.lastSubmit or 0)<0.15 then return end
	state.lastSubmit=now
	local npc=C.activeMonsterDuels[player]
	local opponent,pvp=C.DuelManager.getDuelOpponent(player)
	local duel=npc or pvp
	local function reject(reason)
		sync(player,state,{rejected=true,reason=reason,duelActive=duel~=nil,duelStarted=duel and duel.started or false})
	end
	if not duel or not duel.started or duel.ended then return reject('duel-not-started') end
	if state.resolving then return end
	if not validate(payload) then return reject('invalid-path') end
	if payload.duelId~=state.duelId or payload.revision~=(state.revision or 0) then return reject('stale-board') end
	local team=C.TeamManager.getOrCreateTeam(player)
	if not C.TeamManager.validateTeam(team) then return reject('team-invalid') end
	local grid=C.CombatGrid.cloneGrid(state.grid)
	C.CombatGrid.applySwapPath(grid,payload.path)
	local summary={totalCombos=0,activatedElements={}}
	local resolution=C.CombatGrid.resolveBoard(grid,function(combos,current)
		for _,combo in ipairs(combos) do
			summary.totalCombos+=1
			local cell=combo[1]
			if cell and current[cell.col][cell.row] then summary.activatedElements[current[cell.col][cell.row].elementType]=true end
		end
	end)
	if C.CombatGrid.findMatches(grid).hasMatches then return reject('cascade-limit') end
	local damage=C.MonsterCombat.calculateTeamDamage(team,summary)
	state.grid=grid;state.revision=(state.revision or 0)+1
	local token={};state.resolving=token
	local function current()
		return C.playerStates[player]==state and state.resolving==token and not duel.ended and
			(npc and C.activeMonsterDuels[player]==duel or not npc and C.activeDuels[player]==duel and C.activeDuels[opponent]==duel)
	end
	sync(player,state,{cascades=resolution.cascades,path=payload.path,duelActive=true,duelStarted=true,
		selfHP=npc and duel.playerHP or duel.hpByUserId[player.UserId],
		enemyHP=npc and duel.monsterHP or duel.hpByUserId[opponent.UserId],
		opponentKind=npc and 'monster' or 'player',opponentName=npc and duel.monsterName or opponent.Name,
		damage=damage.totalDamage,comboSummary={totalCombos=summary.totalCombos},resolving=true})
	task.spawn(function()
		task.wait(duration(resolution.cascades))
		if not current() then return end
		if damage.totalDamage>0 then
			C.DuelManager.playPlayerAttackVfxSequence(player,damage.damageByPet,function()
				if not current() then return nil end
				return npc and duel.monsterRoot.Position or C.DuelManager.getPlayerTargetPosition(opponent)
			end)
			local shots=0;for _,entry in ipairs(damage.damageByPet) do if entry.damage>0 then shots+=1 end end
			task.wait(math.max(0,shots-1)*C.VFX_SEQUENCE_STEP_TIME+C.VFX_PROJECTILE_TRAVEL_TIME)
			if not current() then return end
			if npc then duel.monsterHP=math.max(0,duel.monsterHP-damage.totalDamage)
			else duel.hpByUserId[opponent.UserId]=math.max(0,duel.hpByUserId[opponent.UserId]-damage.totalDamage) end
		end
		if not current() then return end
		local selfHP=npc and duel.playerHP or duel.hpByUserId[player.UserId]
		local enemyHP=npc and duel.monsterHP or duel.hpByUserId[opponent.UserId]
		C.CombatDuelState:FireClient(player,{type='duel-update',duelId=state.duelId,selfHP=selfHP,enemyHP=enemyHP,opponentKind=npc and 'monster' or 'player'})
		if enemyHP<=0 then
			if npc then C.MonsterDuel.endMonsterDuel(player,'hp-depleted','player') else C.DuelManager.endDuel(duel,player,'hp-depleted') end
			return
		end
		state.resolving=nil
		sync(player,state,{duelActive=true,duelStarted=true,selfHP=selfHP,enemyHP=enemyHP,resolving=false})
		if opponent and C.playerStates[opponent] then
			C.CombatDuelState:FireClient(opponent,{type='duel-update',selfHP=enemyHP,enemyHP=selfHP,opponentKind='player'})
		end
	end)
end
return GridResolver
