-- Tipo: ModuleScript
-- Ubicacion: ServerScriptService/Combat/CombatSettings
-- Contexto: Servidor. ConfigService opcional, snapshot por duelo y defaults de recuperacion.
local Settings = {}
local defaults = {NpcAttackInterval = 4, NpcHealthMultiplier = 3.5, NpcAttackMultiplier = 2.5,
	ChallengeDistance = 15, CountdownSeconds = 3, DuelTimeoutSeconds = 300, CapturePityBonus = 0.05,
	CommonBits = 50, RareBits = 120, EpicBits = 260, LegendaryBits = 500,
	CaptureEnergyEnabled = false, PvpEnabled = false}
local snapshot
if script:GetAttribute('UseExperienceConfigs') == true and game:GetService('RunService'):IsRunning() then
	task.spawn(function()
		local ok, result = pcall(function() return game:GetService('ConfigService'):GetConfigAsync() end)
		if ok then
			snapshot = result
			result.UpdateAvailable:Connect(function() pcall(function() result:Refresh() end) end)
		end
	end)
end
function Settings.forDuel()
	local values = table.clone(defaults)
	if snapshot then
		for key, default in pairs(defaults) do
			local value = snapshot:GetValue('Alpha' .. key)
			if type(value) == type(default) then
				if type(value) == 'boolean' or (value == value and value > 0 and value < 100000) then values[key] = value end
			end
		end
	end
	values.NpcAttackInterval = math.max(1, values.NpcAttackInterval)
	values.CountdownSeconds = math.clamp(math.floor(values.CountdownSeconds), 1, 10)
	values.DuelTimeoutSeconds = math.clamp(values.DuelTimeoutSeconds, 30, 900)
	values.CapturePityBonus = math.clamp(values.CapturePityBonus, 0, 1)
	return values
end
return Settings
