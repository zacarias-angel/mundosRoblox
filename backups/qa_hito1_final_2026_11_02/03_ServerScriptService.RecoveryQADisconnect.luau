local C=require(game.ServerScriptService.Combat.CombatContext)
local Arena=require(game.ServerScriptService.Combat.ArenaService)
local p=game.Players:GetPlayers()[1]
local output=Instance.new('StringValue');output.Name='RecoveryQADisconnect';output.Parent=game.ServerStorage
assert(C.activeMonsterDuels[p],'Disconnect must happen in active duel')
game.Players.PlayerRemoving:Connect(function(leaving)
 if leaving~=p then return end
 task.delay(0.5,function()
  local leases={};for i=1,8 do local lease=Arena.acquire('disconnect-qa-'..i);if lease then table.insert(leases,lease) end end
  local results={playerGone=p.Parent==nil,duelCleared=C.activeMonsterDuels[p]==nil,stateCleared=C.playerStates[p]==nil,
   allSlotsAvailable=#leases==8,returnFoci=#workspace.CombatReturnFoci:GetChildren(),
   petFolderRemoved=workspace.PlayerPetCubes:FindFirstChild(p.Name)==nil,
   reservationReleased=workspace.Demonslime1:GetAttribute('CombatReservedBy')==nil}
  for _,lease in ipairs(leases) do Arena.release(lease) end
  output.Value=game.HttpService:JSONEncode(results)
  local scripts={};for _,obj in ipairs(game.ServerScriptService:GetChildren()) do if obj:IsA('Script') and obj.Name:find('RecoveryQA') then table.insert(scripts,{path=obj:GetFullName(),source=obj.Source,class=obj.ClassName}) end end
  local http=game.HttpService;local previous=http.HttpEnabled
  local ok,response=pcall(function() http.HttpEnabled=true;return http:RequestAsync({Url='http://127.0.0.1:8766/snapshot/qa_hito1_final_2026_11_02',Method='POST',Headers={['Content-Type']='application/json',['X-Recovery-Token']='recovery-hitos-01-local-20261102'},Body=http:JSONEncode({scripts=scripts,
   main=http:JSONDecode(game.ServerStorage.RecoveryQAResults.Value),edges=http:JSONDecode(game.ServerStorage.RecoveryQAEdges.Value),disconnect=results,
   manual={mouseDrag=true,proximityPromptE=true,cancelButton=true},
   mobile={device='iPhone 17 Pro',orientation='LandscapeSensor',viewport='750x381',cellPixels=45.64,cancelButton='144x44',screenInsets='DeviceSafeInsets',ignoreGuiInset=true},
   note='Studio local gameplay QA. No production datastore, physical phone or 8-client load test.'})}) end)
  http.HttpEnabled=previous
  output:SetAttribute('Exported',ok and response.Success or false)
 end)
end)
p:Kick('QA de desconexion completada; volveremos a modo edicion.')
