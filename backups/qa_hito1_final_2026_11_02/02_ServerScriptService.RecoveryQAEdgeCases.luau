local C=require(game.ServerScriptService.Combat.CombatContext)
local p=game.Players:GetPlayers()[1]
local value=Instance.new('StringValue');value.Name='RecoveryQAEdges';value.Parent=game.ServerStorage
local results={};local function record(k,v) results[k]=v;value.Value=game.HttpService:JSONEncode(results) end
local function start()
 p.Character.HumanoidRootPart.CFrame=workspace.FireBaby:GetPivot()+Vector3.new(0,3,0)
 assert(C.MonsterDuel.onMonsterChallenged(p,workspace.FireBaby));local d=C.activeMonsterDuels[p]
 repeat task.wait(0.1) until d.started
 return d
end
local ok,err=pcall(function()
 local d=start();local state=C.playerStates[p];local path
 for i=1,100 do
  local candidate={{col=math.random(5),row=math.random(5)}}
  for j=1,16 do local prev=candidate[#candidate];local x=math.clamp(prev.col+math.random(-1,1),1,5);local y=prev.row
   if x==prev.col then y=prev.row==5 and 4 or prev.row+1 end
   table.insert(candidate,{col=x,row=y}) end
  local grid=C.CombatGrid.cloneGrid(state.grid);C.CombatGrid.applySwapPath(grid,candidate)
  if C.CombatGrid.findMatches(grid).hasMatches then path=candidate;break end
 end
 assert(path,'No legal route found')
 local bits=p:GetAttribute('Bits');local revision=state.revision
 C.GridResolver.onCombatSubmit(p,{path=path,duelId=state.duelId,revision=revision})
 assert(state.resolving and state.revision==revision+1)
 C.GridResolver.onCombatSubmit(p,{path=path,duelId=state.duelId,revision=revision})
 assert(state.revision==revision+1,'duplicate submit accepted')
 C.MonsterDuel.endMonsterDuel(p,'cancelled')
 task.wait(5)
 assert(not C.activeMonsterDuels[p] and p:GetAttribute('Bits')==bits and not state.resolving)
 assert(#workspace.CombatReturnFoci:GetChildren()==0)
 record('cancelDuringResolution',true);record('duplicateSubmitRejected',true)
 d=start();p.Character.Humanoid.Health=0;task.wait(7)
 assert(not C.activeMonsterDuels[p] and not p:GetAttribute('CombatArenaActive'))
 assert(p.Character and p.Character.Humanoid.Health>0 and workspace.PlayerPetCubes:FindFirstChild(p.Name))
 record('deathAndAutomaticRespawn',true)
end)
record('completed',ok);if not ok then record('error',tostring(err)) end
