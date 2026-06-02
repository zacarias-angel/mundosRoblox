-- Tipo: Script
-- Ubicación: ServerScriptService/CombatRemoteSetup
-- Contexto: Servidor

--[[
    Crea los RemoteEvents necesarios para el sistema de combate
    en ReplicatedStorage/RemoteEvents si no existen todavía.

    Se ejecuta una sola vez al iniciar el servidor.
    Este script debe correr ANTES de CombatServer (orden de carga en Studio:
    ambos en ServerScriptService; Roblox los carga en orden de lista).

    EVENTOS CREADOS:
    - CombatSubmit : Cliente → Servidor  (envío de cadena de celdas)
    - CombatSync   : Servidor → Cliente  (estado del tablero / resultado del turno)
    - CombatChallengeRequest  : Cliente → Servidor  (desafiar jugador cercano)
    - CombatChallengeResponse : Cliente → Servidor  (aceptar/rechazar desafío)
    - CombatDuelState         : Servidor → Cliente  (estado de countdown, inicio y fin)
    - CombatRosterAction      : Cliente → Servidor  (mochila, seguidor, formación)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--[[
Función: ensureFolder

Propósito:
Crea una carpeta en un padre dado si todavía no existe.

Precondiciones:
1. parent debe ser una instancia válida.
2. name debe ser string no vacío.

Ubicación: ServerScriptService/CombatRemoteSetup
Retorna: Folder
]]
local function ensureFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if folder and folder:IsA("Folder") then
        return folder
    end
    folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

--[[
Función: ensureRemoteEvent

Propósito:
Crea un RemoteEvent con el nombre dado dentro del padre si no existe.

Precondiciones:
1. parent debe ser una instancia válida.
2. name debe ser string no vacío.

Ubicación: ServerScriptService/CombatRemoteSetup
Retorna: RemoteEvent
]]
local function ensureRemoteEvent(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then
        return existing
    end
    local re = Instance.new("RemoteEvent")
    re.Name = name
    re.Parent = parent
    return re
end

local remoteEventsFolder = ensureFolder(ReplicatedStorage, "RemoteEvents")

ensureRemoteEvent(remoteEventsFolder, "CombatSubmit")
ensureRemoteEvent(remoteEventsFolder, "CombatSync")
ensureRemoteEvent(remoteEventsFolder, "CombatChallengeRequest")
ensureRemoteEvent(remoteEventsFolder, "CombatChallengeResponse")
ensureRemoteEvent(remoteEventsFolder, "CombatDuelState")
ensureRemoteEvent(remoteEventsFolder, "CombatRosterAction")