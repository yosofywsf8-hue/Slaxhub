-- Dеоbfuѕcаteԁ Вy jerryroblox (discord)
local findTrackedRemote, encodeTimePayload, buildHookXorTables, capturedArgs, fallbackTimeString, lastFallbackTime
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local Debris = game:GetService("Debris")
local LocalPlayer = Players.LocalPlayer
local Name = LocalPlayer.Name
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CurrentCamera = workspace.CurrentCamera
local pingStat = Stats.Network.ServerStatsItem["Data Ping"]
local GetServerTimeNow = workspace.GetServerTimeNow
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	CurrentCamera = workspace.CurrentCamera
end)

local initialServerTime = GetServerTimeNow(workspace)
local clockOffset = initialServerTime - os.clock()
local lastResyncTime = os.clock()

local function getServerTime()
	local now = os.clock()

	if now - lastResyncTime > 1 then
		lastResyncTime = now
		clockOffset = GetServerTimeNow(workspace) - now
	end

	return now + clockOffset
end

local module

pcall(function()
	local Shared = ReplicatedStorage:FindFirstChild("Shared")
	if Shared then
		local DebugFlags = Shared:FindFirstChild("DebugFlags")
		if DebugFlags then
			module = require(DebugFlags)
		end
	end
end)

local uai = loadstring(game:HttpGet("https://raw.githubusercontent.com/delivery-2347/script/refs/heads/main/soliris%20uai"))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/Oxwoey/Main/refs/heads/main/ScriptHub/Protect/ProtectArgsAntiSkids.luau"))()
_G.Library = uai
local curveTypes = {"straight", "dot", "backwards", "up", "down", "left", "right", "random"}

local state = {
	cfg = {acc = 85, am = "auto", animfix = false},
	kb = {sp = "X", tg = "C", orb = "O", ap = "R"},
	orb = {on = false, a = 0, r = 12, sp = 6, lt = os.clock()},
	ro = {on = false, cd = 0, studs = 23},
	ss = {on = false, rate = 500},
}

local noRenderState = {on = false}
noRenderState.con = nil
state.noRender = noRenderState
state.alive = true
state.screenPositions = {}
state.screenCenter = {0, 0}
state.aimCFrame = nil
state.viewportSize = Vector2.new(0, 0)
state.lastScreenRefresh = 0
state.targetPosition = nil
state.lastTargetRefresh = 0
state.targetRefreshInterval = 0.1
state.ping = 0
state.pingJitter = 0
state.lastPing = 0
state.lastPingSample = 0
state.accuracy = 85
state.lastAccuracyUpdate = 0
state.aliveList = {}
state.aliveCount = 0
state.lastAliveRefresh = 0
state.ballVisible = false
state.ballVisibleCheck = 0
state.triggerbot = false
state.ballsFolder = nil
state.ballsFolderCheck = 0
state.ballTargetTimes = setmetatable({}, {__mode = "k"})
state.spamAccumulator = 0
state.actualSpamRate = 0
state.tickCount = 0
state.lastRateSample = os.clock()
state.curveType = "straight"
state.autoParry = false
state.autoParryConnection = nil
state.parrySuccessConnection = nil
state.parrySuccessConnection2 = nil
state.autoSpam = false
state.autoSpamThreshold = 1
state.autoSpamReady = false
state.ui = {}
state.ping = pingStat:GetValue()

local function toKeyName(keyCode)
	if not keyCode then
		return nil
	end

	local keyName = tostring(keyCode):gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", ""):gsub("KeyCode.", ""):gsub("Button", "")

	if keyName == "" then
		return nil
	end

	return keyName:upper()
end

local function refreshAliveList(now)
	if now - state.lastAliveRefresh < 0.3 then
		return
	end

	state.lastAliveRefresh = now
	state.aliveList = {}
	state.aliveCount = 0
	local Alive = workspace:FindFirstChild("Alive")

	if not Alive then
		return
	end

	local Character = LocalPlayer.Character

	for _, aliveCharacter in Alive:GetChildren() do
		if aliveCharacter ~= Character then
			state.aliveCount = state.aliveCount + 1
			state.aliveList[state.aliveCount] = aliveCharacter
		end
	end
end

local function isBallInPlay()
	local now = os.clock()

	if now - state.ballVisibleCheck < 0.05 then
		return state.ballVisible
	end

	state.ballVisibleCheck = now
	local Balls = workspace:FindFirstChild("Balls")

	if Balls then
		for _, ball in Balls:GetChildren() do
			if ball:GetAttribute("realBall") then
				state.ballVisible = true
				return true
			end
		end
	end

	local TrainingBalls = workspace:FindFirstChild("TrainingBalls")

	if TrainingBalls then
		for _, trainingBall in TrainingBalls:GetChildren() do
			if trainingBall:GetAttribute("realBall") then
				state.ballVisible = true
				return true
			end
		end
	end

	state.ballVisible = false
	return false
end

local function updatePingStats()
	local now = os.clock()

	if now - state.lastPingSample >= 0.2 then
		state.lastPingSample = now
		local Value = pingStat:GetValue()

		if state.ping == 0 then
			state.ping = Value
			state.lastPing = Value
		else
			local pingDelta = math.abs(Value - state.lastPing)
			state.lastPing = Value
			state.pingJitter = state.pingJitter * 0.8 + pingDelta * 0.2
			state.ping = state.ping * 0.7 + Value * 0.3
		end
	end

	if now - state.lastAccuracyUpdate >= 0.5 then
		state.lastAccuracyUpdate = now
		if state.config.mode ~= "auto" then
			state.accuracy = state.config.accuracy
		else
			local ping = state.ping
			local pingFactor

			if ping <= 80 then
				pingFactor = 1
			elseif ping >= 2000 then
				pingFactor = 0.35
			else
				pingFactor = 1 - (ping - 80) / 1920 * 0.65
			end

			local jitterFactor = math.clamp(1 - state.pingJitter / 300, 0.6, 1)
			state.accuracy = state.config.accuracy * pingFactor * jitterFactor
		end
	end
end

local function shouldSkipParry()
	local Character = LocalPlayer.Character

	if not Character then
		return true
	end

	if Character:GetAttribute("Stunned") then
		return true
	end

	local Alive = workspace:FindFirstChild("Alive")

	if not Alive then
		return false
	end

	local inLobbyTraining = LocalPlayer:GetAttribute("LobbyTraining") and Character.Parent == workspace:FindFirstChild("Dead")
	local lobbyParryEnabled = module and module.LobbyParry or LocalPlayer:GetAttribute("LobbyParry")

	if Character.Parent ~= Alive and not (lobbyParryEnabled or inLobbyTraining) then
		return true
	end

	if Character:GetAttribute("DoNotParry") then
		return true
	end

	local qiCharge = LocalPlayer.Upgrades and LocalPlayer.Upgrades:FindFirstChild("Qi-Charge")

	if Character:GetAttribute("ChargingAdrenaline") and qiCharge and qiCharge.Value < 2 then
		return true
	end

	if LocalPlayer:GetAttribute("LobbyParry") and LocalPlayer:GetAttribute("InLobbyParryCooldown") then
		return true
	end

	return false
end

local function applyCurve(targetCFrame)
	if typeof(targetCFrame) ~= "CFrame" then
		return CFrame.new()
	end

	local ct = state.curveType

	if not ct or ct == "straight" then
		return targetCFrame
	end

	if ct == "dot" then
		local Character = LocalPlayer.Character
		local selfRoot = Character and (Character.PrimaryPart or Character:FindFirstChild("HumanoidRootPart"))

		if not selfRoot then
			return targetCFrame
		end

		local Alive = workspace:FindFirstChild("Alive")

		if not Alive then
			return targetCFrame
		end

		local bestDistance = 1 / 0
		local nearestCharacter

		for _, child in ipairs(Alive:GetChildren()) do
			if child ~= Character and child:FindFirstChild("HumanoidRootPart") then
				local Magnitude = (selfRoot.Position - child.HumanoidRootPart.Position).Magnitude
				if Magnitude < bestDistance then
					bestDistance = Magnitude
					nearestCharacter = child
				end
			end
		end

		if nearestCharacter then
			return CFrame.lookAt(targetCFrame.Position, nearestCharacter.HumanoidRootPart.Position + Vector3.new(0, 1.75, 0))
		end

		return targetCFrame
	end

	local cFrame = CFrame.new()

	if ct == "backwards" then
		cFrame = CFrame.Angles(0, 10313.240312354817, 0)
	elseif ct == "down" then
		cFrame = CFrame.Angles(-2578.3100780887044, 0, 0)
	elseif ct == "up" then
		cFrame = CFrame.Angles(2578.3100780887044, 0, 0)
	elseif ct == "left" then
		cFrame = CFrame.Angles(0, -5156.620156177409, 0)
	elseif ct == "right" then
		cFrame = CFrame.Angles(0, 5156.620156177409, 0)
	elseif ct == "random" then
		cFrame = CFrame.Angles(0, math.random() * 3.141592653589793 * 2, 0)
	end

	return targetCFrame * cFrame
end

local function findNearestBall()
	local now = os.clock()

	if not state.ballsFolder or now - state.ballsFolderCheck > 0.1 then
		state.ballsFolderCheck = now
		state.ballsFolder = workspace:FindFirstChild("Balls")
	end

	local ballsFolder = state.ballsFolder

	if not ballsFolder then
		return nil
	end

	local Character = LocalPlayer.Character
	local rootPart = Character and Character:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		return nil
	end

	local bestDistance = 1 / 0
	local nearestBall
	local Position = rootPart.Position

	for _, child in ipairs(ballsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			local Magnitude = (Position - child.Position).Magnitude
			if Magnitude < bestDistance then
				nearestBall = child
				bestDistance = Magnitude
			end
		end
	end

	return nearestBall
end

local function updateOrbit(deltaTime)
	if not state.orbit.on then
		return
	end

	local Character = LocalPlayer.Character
	local rootPart = Character and Character:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		return
	end

	local ball = findNearestBall()

	if not ball then
		return
	end

	state.orbit.angle = state.orbit.angle + state.orbit.speed * deltaTime

	if state.orbit.angle > 6.283185307179586 then
		state.orbit.angle = state.orbit.angle - 6.283185307179586
	end

	local Position = ball.Position
	local vector3 = Vector3.new(math.cos(state.orbit.angle) * state.orbit.radius, math.sin(state.orbit.angle * 2) * 2, math.sin(state.orbit.angle) * state.orbit.radius)
	local orbitPosition = Position + vector3
	rootPart.CFrame = CFrame.new(orbitPosition)
end

local function findClosestBall()
	local Character = LocalPlayer.Character
	local rootPart = Character and Character:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		return nil
	end

	local Balls = workspace:FindFirstChild("Balls")

	if not Balls then
		return nil
	end

	local bestDistance = 1 / 0
	local closestBall

	for _, child in ipairs(Balls:GetChildren()) do
		if child:IsA("BasePart") then
			local Magnitude = (rootPart.Position - child.Position).Magnitude
			if Magnitude < bestDistance then
				closestBall = child
				bestDistance = Magnitude
			end
		end
	end

	return closestBall
end

local function randomOrbitOffset()
	local angle = math.random() * 3.141592653589793
	local doubleAngle = angle * 2
	local vec3 = Vector3.new
	local cosine = math.cos(doubleAngle)
	return vec3(cosine * state.rageOrbit.studs, 0, math.sin(doubleAngle) * state.rageOrbit.studs)
end

local function teleportArc(destination)
	local Character = LocalPlayer.Character
	local rootPart = Character and Character:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		return
	end

	local Position = rootPart.Position
	local midpoint = (Position + destination) / 2
	local direction = destination - Position

	if direction.Magnitude == 0 then
		return
	end

	local Unit = direction.Unit
	local Z = Unit.Z
	local vec3 = Vector3.new
	local X = Unit.X
	local controlPoint = midpoint + vec3(-Z, 0, X) * math.random(5, 15)
	local yawDegrees = 0
	local step = 1

	while true do
		local Character1 = LocalPlayer.Character
		local currentRoot = Character1 and Character1:FindFirstChild("HumanoidRootPart")

		if not currentRoot then
			break
		end

		local progress = step / 3
		local arcPosition = (1 - progress) ^ 2 * Position + 2 * (1 - progress) * progress * controlPoint + progress ^ 2 * destination
		yawDegrees = yawDegrees + 60
		currentRoot.CFrame = CFrame.new(arcPosition) * CFrame.Angles(0, math.rad(yawDegrees), 0)
		task.wait(0.001)
		step = step + 1

		if step > 3 then
			return
		end
	end
end

if not _G.__HAHA_PSA_WRAPPED then
	_G.__HAHA_PSA_WRAPPED = true
	_G.__HAHA_PSA_SEEN = _G.__HAHA_PSA_SEEN or setmetatable({}, {__mode = "k"})
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local parrySuccessAll = Remotes and Remotes:FindFirstChild("ParrySuccessAll")

	if parrySuccessAll and type(getconnections) == "function" then
		local ok, result = pcall(getconnections, parrySuccessAll.OnClientEvent)
		if ok and type(result) == "table" then
			local savedConnections = {}

			for _, connection in ipairs(result) do
				if connection.Function and not _G.__HAHA_PSA_SEEN[connection.Function] then
					_G.__HAHA_PSA_SEEN[connection.Function] = true
					table.insert(savedConnections, connection.Function)

					pcall(function()
						connection:Disable()
					end)
				end
			end

			if #savedConnections > 0 then
				parrySuccessAll.OnClientEvent:Connect(function(...)
					for _, savedCallback in ipairs(savedConnections) do
						pcall(savedCallback, ...)
					end
				end)
			end
		end
	end
end

local parryDelay = 0.5
local lastDelayUpdate = 0

local function onParrySucceeded()
	lastDelayUpdate = 0
end

local fireParry
local refreshPayload

local ok1, result1, result2 = pcall(function()
	local Replion = require(ReplicatedStorage.Packages.Replion)
	local ServerInfo = require(ReplicatedStorage.ServerInfo)
	local UniverseIds = require(ReplicatedStorage.Shared.UniverseIds)
	local noobParryEnabled = not ServerInfo.isDungeonsMatchServer() and game.PlaceId ~= UniverseIds.RankedMatches.PlaceId and game.PlaceId ~= UniverseIds.RankedMatchesNoAbility.PlaceId and not ServerInfo.isMedalServer() and not ServerInfo.isClanWarServer() and not ServerInfo.isTournamentMatchServer() and require(ReplicatedStorage.Common.Utils).FFlag.GetInstantFFlag("NoobParryEnabled", true)
	local Controllers = ReplicatedStorage:FindFirstChild("Controllers")

	if not Controllers then
		error("no c")
	end

	local swordsController

	for _, controller in Controllers:GetChildren() do
		if controller.Name:find("SwordsController") then
			swordsController = controller
			break
		end
	end

	if not swordsController then
		error("no sc")
	end

	local PRY = swordsController:FindFirstChild("PRY")

	if not PRY then
		error("no pry")
	end

	local module = require(PRY)
	local hashFunction = debug.getupvalue(module, 4)
	local parryRemoteKey = debug.getupvalue(module, 8)

	if type(hashFunction) ~= "function" or parryRemoteKey == nil then
		error("bad")
	end

	local signalClass
	local Packages = ReplicatedStorage:FindFirstChild("Packages")

	if Packages then
		local Signal = Packages:FindFirstChild("Signal")

		if Signal then
			local ok, result = pcall(require, Signal)
			if ok then
				signalClass = result
			end
		end

		if not signalClass then
			local _Index = Packages:FindFirstChild("_Index")
			if _Index then
				for _, signalModule in _Index:GetChildren() do
					if signalModule.Name:find("Signal") then
						local signalOk, signalResult = pcall(require, signalModule)
						if signalOk then
							signalClass = signalResult
							break
						end
					end
				end
			end
		end
	end

	if not signalClass then
		error("no sl")
	end

	local parryRemote
	local serverSeed
	local xorSeed
	local delayByParryCount = {1.5, 1.25, 1, 0.75, 0.625}
	local parrySignal = signalClass.new()
	parrySignal:Connect(module)

	local function captureParryArgs(remote, remoteKey, seedA, seedB, amount, cframe, tableA, tableB, booleanFlag)
		if
			remoteKey == parryRemoteKey
			and type(seedA) == "string"
			and type(seedB) == "string"
			and type(amount) == "number"
			and typeof(cframe) == "CFrame"
			and type(tableA) == "table"
			and type(tableB) == "table"
			and type(booleanFlag) == "boolean"
		then
			serverSeed = seedA
			parryRemote = remote
		end
	end

	local originalFireServer

	local hookedFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(remoteSelf, ...)
		if not parryRemote then
			local fromScript = not checkcaller

			if not fromScript then
				local ok, result = pcall(checkcaller)
				fromScript = ok and result
			end

			if not fromScript then
				captureParryArgs(remoteSelf, ...)
			end
		end
		return originalFireServer(remoteSelf, ...)
	end))

	local Client = Replion.Client
	originalFireServer = hookedFireServer
	local parryData = Client:WaitReplion("Data")
	local xorTables = {}
	local tablesReady = false
	local lastEncodedTime = -1
	local encodedTime = ""
	local bxor = bit32.bxor
	local byte = string.byte
	local char = string.char
	local concat = table.concat

	local function updateParryDelay()
		local now = os.clock()

		if now - lastDelayUpdate < 0.15 then
			return
		end

		lastDelayUpdate = now
		local timesParried = parryData and parryData:Get("timesParried")
		parryDelay = delayByParryCount[(timesParried or 0) + 1] or 0.5

		if noobParryEnabled then
			local kills = parryData and parryData:Get("TotalStats.Kills") or 0
			if kills < 20 then
				parryDelay = parryDelay * kills / 20
			end
		end
	end

	local function buildXorTables()
		local seedLength = #xorSeed

		for i = 1, 20 do
			local seedByte = byte(xorSeed, (i - 1) % seedLength + 1)
			xorTables[i] = {
				[48] = char(bxor((48 + i) % 256, seedByte)),
				[49] = char(bxor((49 + i) % 256, seedByte)),
				[50] = char(bxor((50 + i) % 256, seedByte)),
				[51] = char(bxor((51 + i) % 256, seedByte)),
				[52] = char(bxor((52 + i) % 256, seedByte)),
				[53] = char(bxor((53 + i) % 256, seedByte)),
				[54] = char(bxor((54 + i) % 256, seedByte)),
				[55] = char(bxor((55 + i) % 256, seedByte)),
				[56] = char(bxor((56 + i) % 256, seedByte)),
				[57] = char(bxor((57 + i) % 256, seedByte)),
			}
		end

		tablesReady = true
	end

	local function refreshEncodedTime()
		if not xorSeed then
			return
		end

		if not tablesReady then
			buildXorTables()
		end

		local serverCentiseconds = math.floor(getServerTime() * 100)

		if serverCentiseconds ~= lastEncodedTime then
			lastEncodedTime = serverCentiseconds
			local digits = tostring(serverCentiseconds)
			local digitCount = #digits
			local chunks = table.create(digitCount)

			for i = 1, digitCount do
				chunks[i] = xorTables[i][byte(digits, i)] or ""
			end

			encodedTime = concat(chunks)
		end
	end

	local function fireParryPacket(aimCFrame, screenPositions, viewportCenter)
		updateParryDelay()

		if not serverSeed then
			parrySignal:Fire(parryDelay, aimCFrame, screenPositions, viewportCenter, false)
			return true
		end

		if not xorSeed then
			local seedHash = hashFunction(serverSeed, "TIME")
			xorSeed = seedHash

			if type(xorSeed) ~= "string" or #xorSeed == 0 then
				return false
			end
		end

		refreshEncodedTime()
		originalFireServer(parryRemote, parryRemoteKey, serverSeed, encodedTime, parryDelay, aimCFrame, screenPositions, viewportCenter, false)
		return true
	end

	updateParryDelay()
	return fireParryPacket, refreshEncodedTime
end)

if ok1 and result1 then
	fireParry = result1
	refreshPayload = result2
end

if fireParry then
	pcall(function()
		local Remotes = ReplicatedStorage:FindFirstChild("Remotes")

		if not Remotes then
			return
		end

		for _, remoteName in ipairs({"ParrySuccess", "ParrySuccessAll"}) do
			local parryEvent = Remotes:FindFirstChild(remoteName)
			if parryEvent then
				parryEvent.OnClientEvent:Connect(onParrySucceeded)
			end
		end
	end)
end

if not fireParry then
	local pryFunction

	if getgc and debug and debug.info and debug.getupvalues then
		for _, candidateFunction in getgc(true) do
			if type(candidateFunction) == "function" then
				local ok2, result3 = pcall(debug.info, candidateFunction, "s")
				if ok2 and result3 and result3:find("PRY", 1, true) then
					for _, upvalue in debug.getupvalues(candidateFunction) do
						if type(upvalue) == "function" then
							pryFunction = upvalue
							break
						end
					end
					if pryFunction then
						break
					end
				end
			end
		end
	end

	local bxor = bit32.bxor
	local byte = string.byte
	local char = string.char
	local concat = table.concat
	local fallbackSeed
	local lastSeedInput
	local fallbackTables = {}
	local fallbackReady = false
	lastFallbackTime = -1
	fallbackTimeString = ""

	function buildHookXorTables()
		local seedLength = #fallbackSeed

		for i = 1, 20 do
			local seedByte = byte(fallbackSeed, (i - 1) % seedLength + 1)
			fallbackTables[i] = {
				[48] = char(bxor((48 + i) % 256, seedByte)),
				[49] = char(bxor((49 + i) % 256, seedByte)),
				[50] = char(bxor((50 + i) % 256, seedByte)),
				[51] = char(bxor((51 + i) % 256, seedByte)),
				[52] = char(bxor((52 + i) % 256, seedByte)),
				[53] = char(bxor((53 + i) % 256, seedByte)),
				[54] = char(bxor((54 + i) % 256, seedByte)),
				[55] = char(bxor((55 + i) % 256, seedByte)),
				[56] = char(bxor((56 + i) % 256, seedByte)),
				[57] = char(bxor((57 + i) % 256, seedByte)),
			}
		end

		fallbackReady = true
	end

	local interceptedArgs = {}

	function encodeTimePayload(seedInput)
		if type(pryFunction) ~= "function" or type(seedInput) ~= "string" then
			return nil
		end

		if lastSeedInput ~= seedInput then
			local seedHash = pryFunction(seedInput, "TIME")
			lastSeedInput = seedInput
			fallbackSeed = seedHash
			fallbackReady = false
		end

		if type(fallbackSeed) ~= "string" or #fallbackSeed == 0 then
			return nil
		end

		if not fallbackReady then
			buildHookXorTables()
		end

		local serverCentiseconds = math.floor(getServerTime() * 100)

		if serverCentiseconds ~= lastFallbackTime then
			lastFallbackTime = serverCentiseconds
			local digits = tostring(serverCentiseconds)
			local digitCount = #digits
			local chunks = table.create(digitCount)

			for i = 1, digitCount do
				chunks[i] = fallbackTables[i][byte(digits, i)] or ""
			end

			fallbackTimeString = concat(chunks)
		end

		return fallbackTimeString
	end

	local patchedMetatables = {}
	capturedArgs = interceptedArgs

	local function isParryArgs(args)
		return #args == 8 and type(args[2]) == "string" and type(args[3]) == "string" and type(args[4]) == "number" and typeof(args[5]) == "CFrame" and type(args[6]) == "table" and type(args[7]) == "table" and type(args[8]) == "boolean"
	end

	local function hookRemoteMeta(remote)
		if capturedArgs[remote] then
			return
		end

		local metatable = getrawmetatable(remote)

		if not metatable or patchedMetatables[metatable] then
			return
		end

		patchedMetatables[metatable] = true
		setreadonly(metatable, false)
		local __index = metatable.__index

		function metatable.__index(instance, key)
			if key == "FireServer" and instance:IsA("RemoteEvent") or key == "InvokeServer" and instance:IsA("RemoteFunction") then
				return function(firstArg, ...)
					local fireArgs = {...}

					if isParryArgs(fireArgs) and not capturedArgs[instance] then
						capturedArgs[instance] = fireArgs
					end

					return __index(instance, key)(firstArg, table.unpack(fireArgs))
				end
			end
			return __index(instance, key)
		end

		setreadonly(metatable, true)
	end

	if getrawmetatable and setreadonly then
		for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
			if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
				hookRemoteMeta(descendant)
			end
		end
	end

	task.wait(1)

	function findTrackedRemote()
		for k, storedArgs in pairs(capturedArgs) do
			if k and k.Parent and k:IsA("RemoteEvent") and type(storedArgs) == "table" then
				return k, storedArgs
			end
		end
	end

	function fireParry(aimCFrame, screenPositions, viewportCenter)
		local remote, args = findTrackedRemote()

		if not remote or not args then
			return false
		end

		local payload = encodeTimePayload(args[2])

		if not payload then
			return false
		end

		remote:FireServer(args[1], args[2], payload, 0.5, aimCFrame, screenPositions, viewportCenter, false)
		return true
	end
end

fireParry = fireParry or function()
	return false
end

local SwordAPI

pcall(function()
	local Shared = ReplicatedStorage:FindFirstChild("Shared")
	if Shared then
		SwordAPI = Shared:FindFirstChild("SwordAPI")
	end
end)

local AnimationController

pcall(function()
	local identity = getthreadidentity and getthreadidentity() or 2

	if setthreadidentity then
		pcall(setthreadidentity, 2)
	end

	local Controllers = ReplicatedStorage:FindFirstChild("Controllers")

	if Controllers and Controllers:FindFirstChild("AnimationController") then
		AnimationController = require(Controllers.AnimationController)
	end

	if setthreadidentity then
		pcall(setthreadidentity, identity)
	end
end)

local parryData

pcall(function()
	local identity = getthreadidentity and getthreadidentity() or 2

	if setthreadidentity then
		pcall(setthreadidentity, 2)
	end

	local Packages = ReplicatedStorage:FindFirstChild("Packages")

	if Packages and Packages:FindFirstChild("Replion") then
		parryData = require(Packages.Replion).Client:WaitReplion("Data")
	end

	if setthreadidentity then
		pcall(setthreadidentity, identity)
	end
end)

local SwordAPI1

pcall(function()
	local identity = getthreadidentity and getthreadidentity() or 2

	if setthreadidentity then
		pcall(setthreadidentity, 2)
	end

	local Shared = ReplicatedStorage:FindFirstChild("Shared")

	if Shared and Shared:FindFirstChild("SwordAPI") then
		SwordAPI1 = require(Shared.SwordAPI)
	end

	if setthreadidentity then
		pcall(setthreadidentity, identity)
	end
end)

local Swords

pcall(function()
	local identity = getthreadidentity and getthreadidentity() or 2

	if setthreadidentity then
		pcall(setthreadidentity, 2)
	end

	local Shared = ReplicatedStorage:FindFirstChild("Shared")

	if Shared then
		local ReplicatedInstances = Shared:FindFirstChild("ReplicatedInstances")
		if ReplicatedInstances and ReplicatedInstances:FindFirstChild("Swords") then
			Swords = require(ReplicatedInstances.Swords)
		end
	end

	if setthreadidentity then
		pcall(setthreadidentity, identity)
	end
end)

local animationCache = {}
local recentParry = false
local animFixRunning = false
local animFixCooldown = false
local m1Stopped = false

local function stopTrack(track)
	track:Stop((track:GetAttribute("StopFadeTime")))
end

local function playParryTrack(track)
	local timesParried = parryData and parryData:Get("timesParried") or 0
	local fastPlay = timesParried and timesParried >= 0 and timesParried <= 4

	track:Play(
		fastPlay and 0.05 or track:GetAttribute("PlayFadeTime"),
		fastPlay and 1 or track:GetAttribute("PlayWeight"),
		fastPlay and timesParried / 5 + 1 or track:GetAttribute("PlaySpeed")
	)
end

local function getGrabParryAnimation(swordName)
	local Character = LocalPlayer.Character

	if not Character then
		return nil
	end

	local cacheKey = swordName or ""

	if animationCache[cacheKey] then
		return animationCache[cacheKey]
	end

	local animationType = "Default"
	local swordType = "Single"

	if swordName and swordName ~= "" and Swords then
		local ok, result = pcall(function()
			return Swords:GetSword(swordName)
		end)
		if ok and result and type(result) == "table" then
			local SwordType = result.SwordType
			animationType = result.AnimationType or "Default"
			swordType = SwordType or "Single"
		end
	end

	local animation

	if SwordAPI1 and type(SwordAPI1.GetAnimations) == "function" then
		local ok1, result1 = pcall(function()
			return SwordAPI1:GetAnimations(Character, {"Parry", "GrabParry"}, animationType, swordType)
		end)
		if ok1 and type(result1) == "table" then
			for _, candidate in pairs(result1) do
				if typeof(candidate) == "Instance" then
					animation = candidate
					break
				end
			end
		end
	end

	if not animation then
		local defaultCollection = SwordAPI1 and SwordAPI1.Collection and SwordAPI1.Collection.Default

		if not defaultCollection and SwordAPI then
			local Collection = SwordAPI:FindFirstChild("Collection")
			defaultCollection = Collection and Collection:FindFirstChild("Default")
		end

		if defaultCollection then
			animation = defaultCollection:FindFirstChild("GrabParry") or defaultCollection:FindFirstChild("Grab")
		end
	end

	animationCache[cacheKey] = animation
	return animation
end

local function playParryAnimation()
	if not state.config.animFix then
		return
	end

	if shouldSkipParry() then
		return
	end

	local Character = LocalPlayer.Character

	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")

	if not Humanoid then
		return
	end

	local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid:FindFirstChild("Animator")

	if not animator then
		return
	end

	local currentlyEquippedSword = Character:GetAttribute("CurrentlyEquippedSword")
	local animation = getGrabParryAnimation(currentlyEquippedSword)

	if not animation then
		local defaultCollection = SwordAPI1 and SwordAPI1.Collection and SwordAPI1.Collection.Default

		if not defaultCollection and SwordAPI then
			local Collection = SwordAPI:FindFirstChild("Collection")
			defaultCollection = Collection and Collection:FindFirstChild("Default")
		end

		if defaultCollection then
			animation = defaultCollection:FindFirstChild("GrabParry")
		end
	end

	if not animation then
		return
	end

	if AnimationController then
		for _, track in pairs(AnimationController:GetPlayingAnimationTracks(animator)) do
			if track:GetAttribute("SuccessParry") then
				pcall(stopTrack, track)
			end
		end

		local ok, result = pcall(function()
			return AnimationController:LoadAnimation(animator, animation, true)
		end)

		if ok and result then
			playParryTrack(result)
		end
	else
		local track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action4
		track:Play(0, 1, 1)
	end
end

local function triggerAnimFix()
	if not state.config.animFix then
		return
	end

	if animFixCooldown or animFixRunning or m1Stopped then
		return
	end

	animFixRunning = true
	animFixCooldown = true
	playParryAnimation()

	task.delay(0, function()
		animFixRunning = false
		task.wait(0.3)

		if not recentParry then
			animFixCooldown = false
		end
	end)
end

pcall(function()
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local m1StopEvent = Remotes and Remotes:FindFirstChild("M1Stop")

	if m1StopEvent then
		if m1StopEvent:IsA("BindableEvent") then
			m1StopEvent.Event:Connect(function(stopState)
				m1Stopped = stopState
			end)
		elseif m1StopEvent:IsA("RemoteEvent") then
			m1StopEvent.OnClientEvent:Connect(function(stopState)
				m1Stopped = stopState
			end)
		end
	end
end)

pcall(function()
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local parrySuccessEvent = Remotes and Remotes:FindFirstChild("ParrySuccess")

	if parrySuccessEvent then
		parrySuccessEvent.OnClientEvent:Connect(function()
			if not state.config.animFix then
				return
			end

			animFixCooldown = false
			animFixRunning = false

			task.spawn(function()
				recentParry = true
				task.wait(0.3)
				recentParry = false
			end)

			local Character = LocalPlayer.Character

			if not Character then
				return
			end

			local Humanoid = Character:FindFirstChildOfClass("Humanoid")

			if not Humanoid then
				return
			end

			local animator = Humanoid:FindFirstChildOfClass("Animator") or Humanoid:FindFirstChild("Animator")

			if not animator then
				return
			end

			if AnimationController then
				for _, track in pairs(AnimationController:GetPlayingAnimationTracks(animator)) do
					if track:GetAttribute("GrabParry") then
						pcall(stopTrack, track)
					end
				end
			end
		end)
	end
end)

local function getNearestEnemyPosition()
	local Character = LocalPlayer.Character
	local rootPart = Character and Character:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		return nil
	end

	local Position = rootPart.Position
	local bestDistance
	local Position1

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local HumanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
			if HumanoidRootPart then
				local Humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if Humanoid and Humanoid.Health > 0 then
					local Magnitude = (HumanoidRootPart.Position - Position).Magnitude
					if not bestDistance or Magnitude < bestDistance then
						Position1 = HumanoidRootPart.Position
						bestDistance = Magnitude
					end
				end
			end
		end
	end

	return Position1
end

local function updateTargetPosition()
	local now = os.clock()
	local ltr = state.lastTargetRefresh
	local tri = state.targetRefreshInterval

	if now - ltr < tri then
		return
	end

	state.lastTargetRefresh = now
	state.targetPosition = getNearestEnemyPosition()
end

local function updateAimCache()
	local now = os.clock()
	updateTargetPosition()
	local CFrame1 = CurrentCamera.CFrame

	if state.targetPosition then
		state.aimCFrame = CFrame.new(CFrame1.Position, state.targetPosition)
	else
		state.aimCFrame = CFrame1
	end

	if now - state.lastScreenRefresh >= 0.1 then
		state.lastScreenRefresh = now
		local ViewportSize = CurrentCamera.ViewportSize

		if ViewportSize ~= state.viewportSize then
			state.viewportSize = ViewportSize
			state.screenCenter[1] = ViewportSize.X * 0.5
			state.screenCenter[2] = ViewportSize.Y * 0.5
		end

		refreshAliveList(now)

		if state.aliveCount == 0 then
			if next(state.screenPositions) ~= nil then
				table.clear(state.screenPositions)
			end
		else
			table.clear(state.screenPositions)
			local X = ViewportSize.X
			local Position = CFrame1.Position
			local Y = ViewportSize.Y

			for i = 1, state.aliveCount do
				local character = state.aliveList[i]
				local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")

				if HumanoidRootPart then
					local Position1 = HumanoidRootPart.Position
					local Y1 = Position1.Y
					local offsetX = Position1.X - Position.X
					local Z = Position.Z
					local Z1 = Position1.Z
					local offsetY = Y1 - Position.Y
					local offsetZ = Z1 - Z
					local squaredY = offsetY * offsetY
					local squaredX = offsetX * offsetX
					local squaredZ = offsetZ * offsetZ

					if squaredX + squaredY + squaredZ < 40000 then
						local screenPoint, onScreen = CurrentCamera:WorldToScreenPoint(Position1)
						if onScreen and screenPoint.X > 0 and screenPoint.Y > 0 and screenPoint.X < X and screenPoint.Y < Y then
							state.screenPositions[character.Name] = screenPoint
						end
					end
				end
			end
		end
	end
end

local function sendParryNow()
	updateAimCache()
	return pcall(fireParry, applyCurve(state.aimCFrame or CurrentCamera.CFrame), state.screenPositions, state.screenCenter)
end

local ballAPI = {}
local ballPositions = setmetatable({}, {__mode = "k"})
local ballPositionRemote
local Packages = ReplicatedStorage:FindFirstChild("Packages")
local indexFolder = Packages and Packages:FindFirstChild("_Index")
local netPackage = indexFolder and indexFolder:FindFirstChild("sleitnick_net@0.1.0")
local netFolder = netPackage and netPackage:FindFirstChild("net")

if netFolder then
	for _, child in ipairs(netFolder:GetChildren()) do
		if child:IsA("UnreliableRemoteEvent") and child.Name ~= "URE/ReplicateBallPosition" then
			ballPositionRemote = child
			break
		end
	end
end

if ballPositionRemote then
	ballPositionRemote.OnClientEvent:Connect(function(ball, position)
		local Balls = workspace:FindFirstChild("Balls")
		if
			ball
			and Balls
			and ball.Parent == Balls
			and ball:GetAttribute("realBall") == true
			and typeof(position) == "Vector3"
		then
			ballPositions[ball] = position
		end
	end)
end

function ballAPI.bp(ball)
	if not ball then
		return Vector3.zero
	end
	return ballPositions[ball] or ball.Position
end

function ballAPI.gbs()
	local balls = {}
	local Balls = workspace:FindFirstChild("Balls")

	if Balls then
		for _, ball in Balls:GetChildren() do
			if ball:GetAttribute("realBall") then
				table.insert(balls, ball)
			end
		end
	end

	local TrainingBalls = workspace:FindFirstChild("TrainingBalls")

	if TrainingBalls then
		for _, trainingBall in TrainingBalls:GetChildren() do
			if trainingBall:GetAttribute("realBall") then
				table.insert(balls, trainingBall)
			end
		end
	end

	return balls
end

function ballAPI.gb()
	local Balls = workspace:FindFirstChild("Balls")

	if Balls then
		for _, ball in Balls:GetChildren() do
			if ball:GetAttribute("realBall") then
				return ball
			end
		end
	end

	local TrainingBalls = workspace:FindFirstChild("TrainingBalls")

	if TrainingBalls then
		for _, trainingBall in TrainingBalls:GetChildren() do
			if trainingBall:GetAttribute("realBall") then
				return trainingBall
			end
		end
	end

	return nil
end

local zoomiesCache = setmetatable({}, {__mode = "k"})
local parriedBalls = setmetatable({}, {__mode = "k"})
local trackedBalls = setmetatable({}, {__mode = "k"})
local parryLocked = false
local timing = {at = tick(), lw = tick(), lr = 0, cv = tick()}

function ballAPI.bc(maybeBall)
	local ball = maybeBall or ballAPI.gb()

	if not ball then
		return false
	end

	local zoomies = zoomiesCache[ball] or ball:FindFirstChild("zoomies")

	if not zoomies then
		return false
	end

	zoomiesCache[ball] = zoomies
	local VectorVelocity = zoomies.VectorVelocity
	local Unit = VectorVelocity.Unit
	local ballPosition = ballAPI.bp(ball)
	local selfPosition = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position

	if not selfPosition then
		return false
	end

	local Unit1 = (selfPosition - ballPosition).Unit
	local closingDot = Unit1:Dot(Unit)
	local Magnitude = VectorVelocity.Magnitude
	local speedBonus = math.min(Magnitude / 100, 40)
	local departingDot = Unit1:Dot((Unit - VectorVelocity).Unit)
	local toBall = selfPosition - ballPosition
	local dotGap = closingDot - departingDot
	local Magnitude1 = toBall.Magnitude
	local ping = state.ping > 0 and state.ping or pingStat:GetValue()
	local pingSeconds = ping / 1000
	local travelRatio = Magnitude1 / Magnitude
	local dotThreshold = 0.5 - pingSeconds
	local timeMargin = travelRatio - ping / 1000
	local maxDistance = 15 - math.min(Magnitude1 / 1000, 15) + speedBonus
	local clampedDot = math.clamp(closingDot, -1, 1)
	local elevationAngle = math.rad(math.asin(clampedDot))
	local smoothedAngle = timing.lr
	timing.lr = smoothedAngle + (elevationAngle - smoothedAngle) * 0.8

	if Magnitude > 100 and timeMargin > ping / 10 then
		maxDistance = math.max(maxDistance - 15, 15)
	end

	if Magnitude1 < maxDistance then
		return false
	end

	if dotGap < dotThreshold then
		return true
	end

	if timing.lr < 0.018 then
		timing.lw = tick()
	end

	if tick() - timing.lw < timeMargin / 1.5 then
		return true
	end

	if tick() - timing.cv < timeMargin / 1.5 then
		return true
	end

	return closingDot < dotThreshold
end

local function trackBallAttributes(ball)
	if trackedBalls[ball] then
		return
	end

	trackedBalls[ball] = true

	ball:GetAttributeChangedSignal("target"):Connect(function()
		parriedBalls[ball] = nil
		parryLocked = false
	end)

	ball.Destroying:Connect(function()
		parriedBalls[ball] = nil
		trackedBalls[ball] = nil
		zoomiesCache[ball] = nil
	end)
end

local function accuracyScale(accuracy)
	return 1.285 * (math.clamp(tonumber(accuracy) or 100, 1, 100) / 100)
end

local function setAutoParry(enabled)
	state.autoParry = enabled
	if enabled then
		if state.autoParryConnection then
			return
		end
		state.autoParryConnection = RunService.PreSimulation:Connect(function()
			if shouldSkipParry() then
				return
			end

			updatePingStats()
			local Character = LocalPlayer.Character

			if not Character or not Character.PrimaryPart then
				return
			end

			local Humanoid = Character:FindFirstChildOfClass("Humanoid")

			if not Humanoid or Humanoid.Health <= 0 then
				return
			end

			local balls = ballAPI.gbs()
			local firstBall = balls[1]
			local firstBallTarget = firstBall and firstBall:GetAttribute("target")
			local pingOverTen = state.ping / 10
			local minReach = isMobile and 10 or 5
			local maxReach = isMobile and 30
			local reachRadius = math.clamp(pingOverTen / 10, minReach, maxReach or 20)
			local accuracyThreshold = accuracyScale(state.config.accuracy)
			local accuracyFactor = accuracyScale(state.config.accuracy)

			for _, ball in ipairs(balls) do
				local zoomies = zoomiesCache[ball] or ball:FindFirstChild("zoomies")
				if zoomies then
					zoomiesCache[ball] = zoomies
					trackBallAttributes(ball)

					if not parriedBalls[ball] then
						if not parryLocked then
							local target = ball:GetAttribute("target")
							local ballPosition = ballAPI.bp(ball)
							local VectorVelocity = zoomies.VectorVelocity
							local toBall = Character.PrimaryPart.Position - ballPosition
							local Magnitude = VectorVelocity.Magnitude
							local Magnitude1 = toBall.Magnitude
							local closingSpeed = (2.4 + math.min(math.max(Magnitude - 9.5, 0), 650) * 0.002) * accuracyFactor
							local parryRange = reachRadius + math.max(Magnitude / closingSpeed, 9.5)
							local shouldParry = ballAPI.bc(ball)

							if ball:FindFirstChild("AeroDynamicSlashVFX") then
								Debris:AddItem(ball.AeroDynamicSlashVFX, 0)
								timing.at = tick()
							end

							local Runtime = workspace:FindFirstChild("Runtime")
							local tornado = Runtime and Runtime:FindFirstChild("Tornado")

							if tornado then
								local tornadoTime = tornado:GetAttribute("TornadoTime")
								if tick() - timing.at < (tornadoTime or 1) + 0.314159 then
									continue
								end
							end

							if firstBallTarget ~= Name or not shouldParry or isMobile then
								if target == Name and Magnitude1 <= parryRange and accuracyThreshold * 0.8 then
									parriedBalls[ball] = true
									parryLocked = true
									local attemptTime

									if shouldSkipParry() then
										if not isBallInPlay() then
											attemptTime = tick()

											task.delay(0.5, function()
												if tick() - attemptTime >= 0.5 then
													parryLocked = false
												end
											end)

											continue
										end
									end

									if state.config.animFix then
										playParryAnimation()
									end

									pcall(sendParryNow)
									attemptTime = tick()

									task.delay(0.5, function()
										if tick() - attemptTime >= 0.5 then
											parryLocked = false
										end
									end)
								end
							end
						end
					end
				end
			end
		end)
	else
		if state.autoParryConnection then
			state.autoParryConnection:Disconnect()
			state.autoParryConnection = nil
		end
		parryLocked = false
	end
end

local handleBallTarget

local function trackBall(ball)
	local function clearBallCache()
		zoomiesCache[ball] = nil
		if handleBallTarget then
			handleBallTarget(ball)
		end
	end

	ball:GetAttributeChangedSignal("target"):Connect(clearBallCache)
	ball:GetAttributeChangedSignal("realBall"):Connect(clearBallCache)
	zoomiesCache[ball] = nil

	if handleBallTarget then
		handleBallTarget(ball)
	end
end

function handleBallTarget(ball)
	if not state.triggerbot then
		return
	end

	if ball:GetAttribute("target") ~= Name then
		return
	end

	local now = os.clock()

	if now - (state.ballTargetTimes[ball] or 0) < 0.015 then
		return
	end

	state.ballTargetTimes[ball] = now
	updateAimCache()

	if state.config.animFix then
		playParryAnimation()
	end

	local aimCFrame = applyCurve(CFrame.new(CurrentCamera.CFrame.Position, ballAPI.bp(ball)))
	pcall(fireParry, aimCFrame, state.screenPositions, state.screenCenter)
end

task.spawn(function()
	local Balls = workspace:WaitForChild("Balls", 10)

	if not Balls then
		return
	end

	Balls.ChildAdded:Connect(trackBall)

	Balls.ChildRemoved:Connect(function(child)
		parriedBalls[child] = nil
		zoomiesCache[child] = nil
	end)

	for _, child in ipairs(Balls:GetChildren()) do
		local function clearBallCache()
			zoomiesCache[child] = nil
			if handleBallTarget then
				handleBallTarget(child)
			end
		end

		child:GetAttributeChangedSignal("target"):Connect(clearBallCache)
		child:GetAttributeChangedSignal("realBall"):Connect(clearBallCache)
		zoomiesCache[child] = nil

		if handleBallTarget then
			handleBallTarget(child)
		end
	end
end)

local function enableNoRender()
	if state.noRender.on then
		return
	end

	state.noRender.on = true

	pcall(function()
		LocalPlayer.PlayerScripts.EffectScripts.ClientFX.Disabled = true
	end)

	local Runtime = workspace:FindFirstChild("Runtime")

	if Runtime then
		state.noRender.connection = Runtime.ChildAdded:Connect(function(child)
			if state.noRender.on then
				pcall(function()
					Debris:AddItem(child, 0)
				end)
			end
		end)
	end
end

local function disableNoRender()
	if not state.noRender.on then
		return
	end

	state.noRender.on = false

	pcall(function()
		LocalPlayer.PlayerScripts.EffectScripts.ClientFX.Disabled = false
	end)

	if state.noRender.connection then
		state.noRender.connection:Disconnect()
		state.noRender.connection = nil
	end
end

local function isAliveInMatch()
	local Character = LocalPlayer.Character

	if not Character then
		return false
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")

	if not Humanoid or Humanoid.Health <= 0 then
		return false
	end

	if LocalPlayer:GetAttribute("LobbyTraining") then
		return true
	end

	local Alive = workspace:FindFirstChild("Alive")

	if not Alive then
		return false
	end

	if not Alive:FindFirstChild(LocalPlayer.Name) then
		return false
	end

	return true
end

local function findNearestEnemy()
	local Character = LocalPlayer.Character

	if not Character or not Character.PrimaryPart then
		return nil
	end

	local Alive = workspace:FindFirstChild("Alive")

	if not Alive then
		return nil
	end

	local nearestCharacter
	local bestDistance = 1 / 0

	for _, child in ipairs(Alive:GetChildren()) do
		if child ~= Character and child.PrimaryPart then
			local Magnitude = (Character.PrimaryPart.Position - child.PrimaryPart.Position).Magnitude
			if Magnitude < bestDistance then
				bestDistance = Magnitude
				nearestCharacter = child
			end
		end
	end

	return nearestCharacter
end

local function updateAutoSpam(ball)
	if not state.autoSpam then
		state.autoSpamReady = false
		return
	end

	if not isAliveInMatch() then
		state.autoSpamReady = false
		return
	end

	local Character = LocalPlayer.Character

	if not Character or not Character.PrimaryPart then
		state.autoSpamReady = false
		return
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")

	if not HumanoidRootPart then
		state.autoSpamReady = false
		return
	end

	local nearestCharacter = findNearestEnemy()

	if not nearestCharacter or not nearestCharacter.PrimaryPart then
		state.autoSpamReady = false
		return
	end

	local zoomies = ball:FindFirstChild("zoomies")

	if not zoomies then
		state.autoSpamReady = false
		return
	end

	local pingOverTen = (state.ping > 0 and state.ping or pingStat:GetValue()) / 10
	local VectorVelocity = zoomies.VectorVelocity
	local pingScale = pingOverTen / 500
	local Magnitude = VectorVelocity.Magnitude
	local spamRange = 30.3

	if pingOverTen <= 0 or pingOverTen >= 130 then
		if pingOverTen <= 131 or pingOverTen >= 160 then
			if pingOverTen <= 161 or pingOverTen >= 225 then
				if pingOverTen > 226 and pingOverTen < 500 then
					spamRange = math.clamp(math.floor(math.max(Magnitude / 4 + pingScale, 32.5)), 32.5, 80)
				end
			else
				spamRange = math.clamp(math.floor(math.max(Magnitude / 4.25 + pingScale, 29.5)), 29.5, 70)
			end
		else
			spamRange = math.clamp(math.floor(math.max(Magnitude / 4.65 + pingScale, 27.25)), 27.25, 70)
		end
	else
		spamRange = math.clamp(math.floor(math.max(Magnitude / 5 + pingScale, 26)), 26, 70)
	end

	local Position = HumanoidRootPart.Position
	local threshold = spamRange * (state.autoSpamThreshold or 1)
	local Magnitude1 = (Position - ballAPI.bp(ball)).Magnitude
	local Magnitude2 = (HumanoidRootPart.Position - nearestCharacter.PrimaryPart.Position).Magnitude
	state.autoSpamReady = Magnitude1 <= threshold * 1.5 and Magnitude2 <= threshold
end

task.spawn(function()
	while true do
		if state.autoSpamReady then
			local hasBall = false
			local Balls = workspace:FindFirstChild("Balls")

			if Balls then
				for _, child in pairs(Balls:GetChildren()) do
					if child:GetAttribute("realBall") then
						hasBall = true
						break
					end
				end
			end

			if not hasBall then
				local TrainingBalls = workspace:FindFirstChild("TrainingBalls")
				if TrainingBalls then
					for _, child1 in pairs(TrainingBalls:GetChildren()) do
						if child1:GetAttribute("realBall") then
							hasBall = true
							break
						end
					end
				end
			end

			if not hasBall then
				state.autoSpamReady = false
			end
		end
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		if fireParry and (state.autoParry or state.triggerbot or state.autoSpam) then
			local Balls = workspace:FindFirstChild("Balls")

			if Balls then
				for _, child in pairs(Balls:GetChildren()) do
					if child:GetAttribute("realBall") then
						if state.triggerbot and not state.spam.on then
							handleBallTarget(child)
						end
						if state.autoSpam then
							updateAutoSpam(child)
						end
					end
				end
			end

			local TrainingBalls = workspace:FindFirstChild("TrainingBalls")

			if TrainingBalls then
				for _, child1 in pairs(TrainingBalls:GetChildren()) do
					if child1:GetAttribute("realBall") then
						if state.triggerbot and not state.spam.on then
							handleBallTarget(child1)
						end
						if state.autoSpam then
							updateAutoSpam(child1)
						end
					end
				end
			end

			task.wait(0.01)
		else
			task.wait(0.1)
		end
	end
end)

local spamRate = 500
local burstCap = math.ceil(25)
local budgetCap = math.ceil(50)

local pacer = {
	tr = 500,
	mr = 0,
	i = 0,
	im = -2000,
	imx = 2000,
	kp = 0.2,
	ki = 0.02,
	wn = 0.1,
	wt = 0,
	wf = 0,
	er = 500,
}

local function resetPacer()
	pacer.targetRate = spamRate
	pacer.currentRate = spamRate
	pacer.integral = 0
	pacer.measuredRate = 0
	pacer.windowTime = 0
	pacer.windowFrames = 0
	burstCap = math.ceil(spamRate * 0.05)
	budgetCap = math.ceil(spamRate * 0.1)
	state.spamAccumulator = 0
end

local function setSpamRate(rate)
	local clampedRate = math.clamp(rate, 60, 500)
	spamRate = math.floor(clampedRate + 0.5)
	state.spam.rate = spamRate
	resetPacer()
end

local function onPreSimulation(deltaTime)
	local dt = deltaTime
	local now = os.clock()

	if not state.spam.on and not state.autoSpamReady then
		state.spamAccumulator = 0
		pacer.integral = 0
		pacer.windowTime = 0
		pacer.windowFrames = 0
		return
	end

	if not isBallInPlay() then
		state.spamAccumulator = 0
		return
	end

	if not isAliveInMatch() then
		state.spamAccumulator = 0
		return
	end

	if state.config.animFix then
		triggerAnimFix()
	end

	if deltaTime > 0.1 then
		dt = 0.1
	end

	if dt < 0 then
		dt = 0
	end

	pacer.windowTime = pacer.windowTime + dt

	if pacer.windowTime >= pacer.windowSeconds then
		local measuredRate = pacer.windowFrames / pacer.windowTime
		pacer.measuredRate = pacer.measuredRate * 0.6 + measuredRate * 0.4
		local rateError = pacer.targetRate - pacer.measuredRate
		pacer.integral = math.clamp(pacer.integral + rateError * pacer.windowTime, pacer.integralMin, pacer.integralMax)
		local correction = pacer.kp * rateError + pacer.ki * pacer.integral
		pacer.currentRate = math.clamp(pacer.targetRate + correction, pacer.targetRate * 0.5, pacer.targetRate * 1.5)
		pacer.windowTime = 0
		pacer.windowFrames = 0
	end

	local interval = 1 / pacer.currentRate
	state.spamAccumulator = state.spamAccumulator + dt

	if state.spamAccumulator > interval * budgetCap then
		state.spamAccumulator = interval * budgetCap
	end

	local burstCount = math.floor(state.spamAccumulator / interval)

	if burstCount > burstCap then
		burstCount = burstCap
	end

	if burstCount <= 0 then
		return
	end

	state.spamAccumulator = state.spamAccumulator - burstCount * interval

	if state.spamAccumulator < 0 then
		state.spamAccumulator = 0
	end

	pacer.windowFrames = pacer.windowFrames + burstCount
	updateAimCache()

	if refreshPayload then
		refreshPayload()
	end

	local aimCFrame = applyCurve(state.aimCFrame or CurrentCamera.CFrame)
	local cs = state.screenPositions
	local ca = state.screenCenter
	local randomCurve = state.curveType == "random"

	pcall(function()
		for _ = 1, burstCount do
			if randomCurve then
				aimCFrame = applyCurve(state.aimCFrame or CurrentCamera.CFrame)
			end
			fireParry(aimCFrame, cs, ca)
		end
	end)

	state.tickCount = state.tickCount + burstCount

	if now - state.lastRateSample >= 0.5 then
		state.actualSpamRate = state.tickCount / (now - state.lastRateSample)
		state.tickCount = 0
		state.lastRateSample = now
	end
end

state.preSimulationConnection = RunService.PreSimulation:Connect(function(deltaTime)
	onPreSimulation(deltaTime)
end)

pcall(function()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

	if not Remotes then
		return
	end

	local ParrySuccessAll = Remotes:WaitForChild("ParrySuccessAll", 10)

	if not ParrySuccessAll then
		return
	end

	state.parrySuccessConnection = ParrySuccessAll.OnClientEvent:Connect(function(_, hitPart)
		if not state.autoParry then
			return
		end

		if shouldSkipParry() then
			return
		end

		local Character = LocalPlayer.Character

		if not Character or not Character.PrimaryPart then
			return
		end

		if hitPart.Parent and hitPart.Parent ~= Character then
			if hitPart.Parent.Parent ~= workspace.Alive then
				return
			end
		end

		local ball = ballAPI.gb()

		if not ball then
			return
		end

		local Position = Character.PrimaryPart.Position
		local ballPosition = ballAPI.bp(ball)
		local offset = Position - ballPosition
		local offsetDirection = Position - ballPosition
		local Magnitude = offset.Magnitude
		local velocityDot = offsetDirection.Unit:Dot(ball.AssemblyLinearVelocity.Unit)

		if Magnitude < 15 and velocityDot > -0.25 then
			if ballAPI.bc(ball) then
				pcall(sendParryNow)
			end
		end
	end)

	state.parrySuccessConnection2 = ParrySuccessAll.OnClientEvent:Connect(function(_, hitPart)
		if not state.autoParry then
			return
		end

		if shouldSkipParry() then
			return
		end

		local Character = LocalPlayer.Character

		if not Character or not Character.PrimaryPart then
			return
		end

		local PrimaryPart = Character.PrimaryPart
		local ball = ballAPI.gb()

		if not ball then
			return
		end

		local zoomies = ball:FindFirstChild("zoomies")

		if not zoomies then
			return
		end

		local ballPosition = ballAPI.bp(ball)
		local Magnitude = zoomies.VectorVelocity.Magnitude
		local Magnitude1 = (PrimaryPart.Position - ballPosition).Magnitude
		local ping = state.ping > 0 and state.ping or 50
		local speedBonus = math.min(Magnitude / 100, 40)
		local timeMargin = Magnitude1 / Magnitude - ping / 1000
		local isFast = Magnitude > 100
		local maxDistance = 15 - math.min(Magnitude1 / 1000, 15) + speedBonus

		if isFast and timeMargin > ping / 10 then
			maxDistance = math.max(maxDistance - 15, 15)
		end

		if hitPart ~= PrimaryPart and Magnitude1 > maxDistance then
			timing.cv = tick()
		end
	end)
end)

function _G:Notify(content, duration, imageId)
	pcall(function()
		uai:Notify({Title = self, Content = content, Duration = duration or 5, ImageID = imageId or "101017996369612"})
	end)
end

_G.PlaySound = _G.PlaySound or function() end
_G.Sounds = _G.Sounds or {}

local theme = {
	Font = "Cartoon",
	ImageTransparency = 25,
	BGTransparency = 10,
	OrbsTransparency = 100,
	BackgroundID = "",
	Main = Color3.fromRGB(14, 14, 18),
	Second = Color3.fromRGB(8, 8, 10),
	ElementAccent = Color3.fromRGB(110, 220, 150),
	TextColor = Color3.fromRGB(248, 248, 252),
	GradientStart = Color3.fromRGB(110, 220, 150),
	GradientEnd = Color3.fromRGB(70, 150, 100),
	CornerRadius = 22,
	HudTransparency = 10,
}

_G.Window = uai:CreateWindow({
	Title = "HAHA.dll",
	Theme = theme,
	ToggleKey = Enum.KeyCode.RightShift,
	Transparency = 0.5,
	ShowWatermark = {Enabled = false},
	ConfigFolder = "HAHA",
	CustomIcon = "101017996369612",
})

local combatTab = _G.Window:CreateTab("Combat", true, "7035631382")
local movementTab = _G.Window:CreateTab("Movement", true, "16149111731")
local performanceTab = _G.Window:CreateTab("Performance", true, "112583783444446")
local tuningTab = _G.Window:CreateTab("Tuning", true, "83745541516978")
local playerTab = _G.Window:CreateTab("Player", true, "116592854241448")
local Block = combatTab:CreateBlock({Name = "Auto Parry", Side = "Left", ImageID = "126813390527582"})

state.ui.autoParry = Block:CreateToggle({
	Name = "Auto parry",
	Default = false,
	Flag = "HAHA_AP",
	Callback = function(value)
		setAutoParry(value)

		if not value then
			parryLocked = false
			for k in pairs(parriedBalls) do
				parriedBalls[k] = nil
			end
		end

		if state.autoParryButton then
			state.autoParryButton.silentSet(value)
			state.autoParryButton.setState(value)
		end
	end,
})

Block:CreateToggle({
	Name = "Anim Fix",
	Default = false,
	Flag = "HAHA_AnimFix",
	Callback = function(value)
		state.config.animFix = value
		if not value then
			animationCache = {}
		end
	end,
})

Block:CreateToggle({
	Name = "Auto Spam",
	Default = false,
	Flag = "HAHA_AutoSpam",
	Callback = function(value)
		state.autoSpam = value
		if not value then
			state.autoSpamReady = false
		end
	end,
})

local Block1 = combatTab:CreateBlock({Name = "Manual Spam", Side = "Right", ImageID = "112583783444446"})

state.ui.spam = Block1:CreateToggle({
	Name = "Manual spam",
	Default = false,
	Flag = "HAHA_Spam",
	Callback = function(value)
		state.spam.on = value
		resetPacer()
		state.lastRateSample = os.clock()
		state.tickCount = 0
		state.actualSpamRate = 0

		if state.spamButton then
			state.spamButton.silentSet(value)
			state.spamButton.setState(value)
		end
	end,
})

local Block2 = combatTab:CreateBlock({Name = "Triggerbot", Side = "Left", ImageID = "115892909027721"})

state.ui.triggerbot = Block2:CreateToggle({
	Name = "Triggerbot",
	Default = false,
	Flag = "HAHA_TG",
	Callback = function(value)
		state.triggerbot = value

		if value then
			for _, ball in ipairs(ballAPI.gbs()) do
				handleBallTarget(ball)
			end
		end

		if state.triggerButton then
			state.triggerButton.silentSet(value)
			state.triggerButton.setState(value)
		end
	end,
})

Block2:CreateDropdown({
	Name = "Curve type",
	Items = curveTypes,
	Default = "straight",
	Flag = "HAHA_Curve",
	Callback = function(value)
		state.curveType = value
	end,
})

local Block3 = movementTab:CreateBlock({Name = "Ball Orbit", Side = "Left", ImageID = "128540628323761"})

state.ui.orbit = Block3:CreateToggle({
	Name = "Ball orbit",
	Default = false,
	Flag = "HAHA_Orbit",
	Callback = function(value)
		state.orbit.on = value
		state.orbit.angle = 0
		state.orbit.lastUpdate = os.clock()
	end,
})

Block3:CreateToggle({
	Name = "Rage orbit",
	Default = false,
	Flag = "HAHA_RageOrbit",
	Callback = function(value)
		state.rageOrbit.on = value
		if value then
			task.spawn(function()
				while state.rageOrbit.on and state.alive do
					if state.rageOrbit.on then
						local ball = findClosestBall()
						if ball then
							teleportArc(ball.Position + randomOrbitOffset())
						end
					end
					task.wait(state.rageOrbit.cooldown)
				end
			end)
		end
	end,
})

performanceTab:CreateBlock({Name = "Render", Side = "Left", ImageID = "84179715514460"}):CreateToggle({
	Name = "No render",
	Default = false,
	Flag = "HAHA_NoRender",
	Callback = function(value)
		if value then
			enableNoRender()
		else
			disableNoRender()
		end
	end,
})

local Block4 = tuningTab:CreateBlock({Name = "Combat Tuning", Side = "Left", ImageID = "116957729492323"})

local Slider = Block4:CreateSlider({
	Name = "Spam rate (/s)",
	Min = 60,
	Max = 500,
	Default = 500,
	Flag = "HAHA_Rate",
	Callback = function(value)
		setSpamRate(value)
	end,
})

Block4:CreateSlider({
	Name = "Accuracy",
	Min = 1,
	Max = 100,
	Default = state.config.accuracy,
	Flag = "HAHA_Acc",
	Callback = function(value)
		state.config.accuracy = value
	end,
})

Block4:CreateToggle({
	Name = "Auto accuracy",
	Default = true,
	Flag = "HAHA_AutoAcc",
	Callback = function(value)
		state.config.mode = value and "auto" or "manual"
		state.lastAccuracyUpdate = 0
	end,
})

Block4:CreateSlider({
	Name = "Auto-spam threshold",
	Min = 1,
	Max = 2,
	Default = state.autoSpamThreshold,
	Flag = "HAHA_Threshold",
	Callback = function(value)
		state.autoSpamThreshold = value
	end,
})

local Block5 = playerTab:CreateBlock({Name = "On-Screen Buttons", Side = "Left", ImageID = "15889469852"})
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HAHA_HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 2147483600
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

task.defer(function()
	local blockerFound = false
	for _, child in ipairs(PlayerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child ~= screenGui then
			for _, child1 in ipairs(child:GetChildren()) do
				if
					child1:IsA("Frame")
					and child1.ZIndex >= 2147483000
					and child1.Size.X.Scale == 1
					and child1.Size.Y.Scale == 1
				then
					blockerFound = true
					child1.Visible = false
					break
				end
			end
			if blockerFound then
				break
			end
		end
	end
end)

local textButton = Instance.new("TextButton")
textButton.Name = "Blocker"
textButton.Size = UDim2.new(1, 0, 1, 0)
textButton.BackgroundTransparency = 1
textButton.Text = ""
textButton.BorderSizePixel = 0
textButton.AutoButtonColor = false
textButton.Visible = false
textButton.ZIndex = 2147483647
textButton.Parent = screenGui

local buttonColors = {
	ac = Color3.fromRGB(110, 220, 150),
	ac2 = Color3.fromRGB(70, 150, 100),
	wn = Color3.fromRGB(245, 190, 100),
	wn2 = Color3.fromRGB(180, 130, 60),
	tx = Color3.fromRGB(248, 248, 252),
	txm = Color3.fromRGB(120, 120, 132),
	cd = Color3.fromRGB(24, 24, 28),
	cd2 = Color3.fromRGB(16, 16, 20),
	bg2 = Color3.fromRGB(10, 10, 12),
	sk = Color3.fromRGB(44, 44, 54),
}

local function createHudButton(name, text, activeColor, _, onToggle)
	local textButton1 = Instance.new("TextButton")
	textButton1.Name = name
	textButton1.Size = UDim2.new(0, 88, 0, 32)
	textButton1.Position = UDim2.new(0.5, -300, 1, -60)
	textButton1.BackgroundColor3 = buttonColors.cd
	textButton1.BorderSizePixel = 0
	textButton1.Text = ""
	textButton1.AutoButtonColor = false
	textButton1.Visible = false
	textButton1.ZIndex = 50
	textButton1.Parent = screenGui
	Instance.new("UICorner", textButton1).CornerRadius = UDim.new(0, 8)
	local uIGradient = Instance.new("UIGradient")
	uIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, buttonColors.cd), ColorSequenceKeypoint.new(1, buttonColors.bg2)})
	uIGradient.Rotation = 135
	uIGradient.Parent = textButton1
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 51
	frame.Parent = textButton1
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
	local uIStroke = Instance.new("UIStroke")
	uIStroke.Color = buttonColors.sk
	uIStroke.Thickness = 1
	uIStroke.Parent = frame
	local frame1 = Instance.new("Frame")
	frame1.Size = UDim2.new(0, 8, 0, 8)
	frame1.Position = UDim2.new(0, 10, 0.5, -4)
	frame1.BackgroundColor3 = buttonColors.txm
	frame1.BorderSizePixel = 0
	frame1.ZIndex = 52
	frame1.Parent = textButton1
	Instance.new("UICorner", frame1).CornerRadius = UDim.new(1, 0)
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -26, 0, 16)
	textLabel.Position = UDim2.new(0, 24, 0, 4)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = buttonColors.tx
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = 13
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.ZIndex = 52
	textLabel.Parent = textButton1
	local textLabel1 = Instance.new("TextLabel")
	textLabel1.Size = UDim2.new(1, -26, 0, 10)
	textLabel1.Position = UDim2.new(0, 24, 1, -14)
	textLabel1.BackgroundTransparency = 1
	textLabel1.Text = "OFF"
	textLabel1.TextColor3 = buttonColors.txm
	textLabel1.Font = Enum.Font.GothamBold
	textLabel1.TextSize = 8
	textLabel1.TextXAlignment = Enum.TextXAlignment.Left
	textLabel1.ZIndex = 52
	textLabel1.Parent = textButton1
	local enabled = false

	local function setEnabledVisual(value)
		enabled = value
		if value then
			local tweenInfo = TweenInfo.new(0.2)
			TweenService:Create(textButton1, tweenInfo, {BackgroundColor3 = activeColor}):Play()
			TweenService:Create(uIStroke, TweenInfo.new(0.2), {Color = activeColor, Thickness = 2}):Play()
			TweenService:Create(frame1, TweenInfo.new(0.2), {BackgroundColor3 = buttonColors.tx}):Play()
			textLabel.TextColor3 = Color3.fromRGB(16, 24, 18)
			textLabel1.Text = "ON"
			textLabel1.TextColor3 = Color3.fromRGB(16, 24, 18)
		else
			local tweenInfo1 = TweenInfo.new(0.2)
			TweenService:Create(textButton1, tweenInfo1, {BackgroundColor3 = buttonColors.cd}):Play()
			TweenService:Create(uIStroke, TweenInfo.new(0.2), {Color = buttonColors.sk, Thickness = 1}):Play()
			TweenService:Create(frame1, TweenInfo.new(0.2), {BackgroundColor3 = buttonColors.txm}):Play()
			textLabel.TextColor3 = buttonColors.tx
			textLabel1.Text = "OFF"
			textLabel1.TextColor3 = buttonColors.txm
		end
	end

	local function setEnabledSilent(value)
		enabled = value
	end

	local Position
	local Position1
	local dragging
	local dragged

	textButton1.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Position = input.Position
			Position1 = textButton1.Position
			dragging = true
			dragged = false
			textButton.Visible = true
			local connection1

			local connection = UserInputService.InputChanged:Connect(function(input)
				if not dragging then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
					local dragDelta = input.Position - Position

					if math.abs(dragDelta.X) > 4 or math.abs(dragDelta.Y) > 4 then
						dragged = true
					end

					if dragged then
						textButton1.Position = UDim2.new(Position1.X.Scale, Position1.X.Offset + dragDelta.X, Position1.Y.Scale, Position1.Y.Offset + dragDelta.Y)
					end
				end
			end)

			connection1 = UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
					connection:Disconnect()
					connection1:Disconnect()
					textButton.Visible = false

					if not dragged then
						local nextState = not enabled
						enabled = nextState
						setEnabledVisual(nextState)

						if onToggle then
							onToggle(nextState)
						end
					end
				end
			end)
		end
	end)

	return {
		frame = textButton1,
		setVisible = function(visible)
			textButton1.Visible = visible
		end,
		setState = function(value)
			setEnabledVisual(value)
		end,
		silentSet = setEnabledSilent,
		get = function()
			return enabled
		end,
	}
end

state.autoParryButton = createHudButton("ApButton", "AP", buttonColors.ac, buttonColors.ac2, function(value)
	pcall(function()
		state.ui.autoParry:Set(value)
	end)
end)

state.spamButton = createHudButton("SpamButton", "SPAM", buttonColors.ac, buttonColors.ac2, function(value)
	pcall(function()
		state.ui.spam:Set(value)
	end)
end)

state.triggerButton = createHudButton("TriggerButton", "TB", buttonColors.wn, buttonColors.wn2, function(value)
	pcall(function()
		state.ui.triggerbot:Set(value)
	end)
end)

state.autoParryButton.frame.Position = UDim2.new(0.5, -300, 1, -60)
state.spamButton.frame.Position = UDim2.new(0.5, -100, 1, -60)
state.triggerButton.frame.Position = UDim2.new(0.5, 100, 1, -60)

Block5:CreateToggle({
	Name = "Auto-parry button",
	Default = false,
	Flag = "HAHA_BtnAP",
	Callback = function(value)
		state.autoParryButton.setVisible(value)
		state.autoParryButton.silentSet(state.autoParry)
		state.autoParryButton.setState(state.autoParry)
	end,
})

Block5:CreateToggle({
	Name = "Spam button",
	Default = false,
	Flag = "HAHA_BtnSP",
	Callback = function(value)
		state.spamButton.setVisible(value)
		state.spamButton.silentSet(state.spam.on)
		state.spamButton.setState(state.spam.on)
	end,
})

Block5:CreateToggle({
	Name = "Triggerbot button",
	Default = false,
	Flag = "HAHA_BtnTB",
	Callback = function(value)
		state.triggerButton.setVisible(value)
		state.triggerButton.silentSet(state.triggerbot)
		state.triggerButton.setState(state.triggerbot)
	end,
})

local activeBindRow

local function createBindRow(parent, text, action)
	local textButton = Instance.new("TextButton")
	textButton.Size = UDim2.new(1, 0, 0, 26)
	textButton.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	textButton.BorderSizePixel = 0
	textButton.Text = ""
	textButton.AutoButtonColor = false
	textButton.ZIndex = 5
	textButton.Parent = parent
	local uICorner = Instance.new("UICorner")
	uICorner.CornerRadius = UDim.new(0, 6)
	uICorner.Parent = textButton
	local uIStroke = Instance.new("UIStroke")
	uIStroke.Color = Color3.fromRGB(44, 44, 54)
	uIStroke.Thickness = 1
	uIStroke.Parent = textButton
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(0.55, 0, 1, 0)
	textLabel.Position = UDim2.new(0, 10, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = Color3.fromRGB(248, 248, 252)
	textLabel.Font = Enum.Font.Gotham
	textLabel.TextSize = 11
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.ZIndex = 6
	textLabel.Parent = textButton
	local textLabel1 = Instance.new("TextLabel")
	textLabel1.Size = UDim2.new(0.4, 0, 1, 0)
	textLabel1.Position = UDim2.new(0.55, 0, 0, 0)
	textLabel1.BackgroundTransparency = 1
	textLabel1.Text = tostring(state.keybinds[action] or "NONE")
	textLabel1.TextColor3 = Color3.fromRGB(110, 220, 150)
	textLabel1.Font = Enum.Font.GothamBold
	textLabel1.TextSize = 11
	textLabel1.TextXAlignment = Enum.TextXAlignment.Right
	textLabel1.ZIndex = 6
	textLabel1.Parent = textButton

	textButton.MouseButton1Click:Connect(function()
		activeBindRow = {
			slot = action,
			reset = function()
				uIStroke.Color = Color3.fromRGB(44, 44, 54)
				uIStroke.Thickness = 1
				textLabel1.Text = tostring(state.keybinds[action] or "NONE")
				textLabel1.TextColor3 = Color3.fromRGB(110, 220, 150)
			end,
		}

		textLabel1.Text = "..."
		textLabel1.TextColor3 = Color3.fromRGB(245, 190, 100)
		uIStroke.Color = Color3.fromRGB(245, 190, 100)
		uIStroke.Thickness = 2
	end)
end

local frame = Instance.new("Frame")
frame.Name = "HAHA_Keybinds"
frame.Size = UDim2.new(0, 200, 0, 150)
frame.Position = UDim2.new(0, 20, 1, -180)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
frame.BorderSizePixel = 0
frame.ZIndex = 60
frame.Parent = screenGui
local uICorner = Instance.new("UICorner")
uICorner.CornerRadius = UDim.new(0, 8)
uICorner.Parent = frame
local uIStroke = Instance.new("UIStroke")
uIStroke.Color = Color3.fromRGB(44, 44, 54)
uIStroke.Thickness = 1
uIStroke.Parent = frame
local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(1, -20, 0, 20)
textLabel.Position = UDim2.new(0, 10, 0, 6)
textLabel.BackgroundTransparency = 1
textLabel.Text = "Keybinds"
textLabel.TextColor3 = Color3.fromRGB(248, 248, 252)
textLabel.Font = Enum.Font.GothamBold
textLabel.TextSize = 11
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.ZIndex = 61
textLabel.Parent = frame
local frame1 = Instance.new("Frame")
frame1.Size = UDim2.new(1, -16, 1, -32)
frame1.Position = UDim2.new(0, 8, 0, 28)
frame1.BackgroundTransparency = 1
frame1.ZIndex = 61
frame1.Parent = frame
local uIListLayout = Instance.new("UIListLayout")
uIListLayout.Padding = UDim.new(0, 4)
uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uIListLayout.Parent = frame1
createBindRow(frame1, "Auto Parry", "ap")
createBindRow(frame1, "Manual Spam", "sp")
createBindRow(frame1, "Triggerbot", "tg")
createBindRow(frame1, "Ball Orbit", "orb")

textLabel.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local Position = input.Position
		local Position1 = frame.Position
		local connection1

		local connection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local dragDelta = input.Position - Position
				local udim2 = UDim2.new
				local Scale = Position1.X.Scale
				local Offset = Position1.X.Offset
				local X = dragDelta.X
				local Y = Position1.Y
				frame.Position = udim2(Scale, Offset + X, Y.Scale, Position1.Y.Offset + dragDelta.Y)
			end
		end)

		connection1 = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				connection:Disconnect()
				connection1:Disconnect()
			end
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if activeBindRow then
		if input.KeyCode then
			local keyName = toKeyName(input.KeyCode)
			if keyName then
				state.keybinds[activeBindRow.slot] = keyName
				local reset = activeBindRow.reset
				activeBindRow = nil

				if reset then
					reset()
				end
			end
		end
		return
	end

	if gameProcessed then
		return
	end

	if not input.KeyCode then
		return
	end

	local keyName = toKeyName(input.KeyCode)

	if not keyName then
		return
	end

	if state.keybinds.ap == keyName then
		local newState = not state.autoParry
		state.autoParry = newState
		setAutoParry(newState)

		if not newState then
			parryLocked = false
			for k in pairs(parriedBalls) do
				parriedBalls[k] = nil
			end
		end

		pcall(function()
			state.ui.autoParry:Set(newState)
		end)

		if state.autoParryButton then
			state.autoParryButton.silentSet(newState)
			state.autoParryButton.setState(newState)
		end
	elseif state.keybinds.sp == keyName then
		local newState = not state.spam.on
		state.spam.on = newState
		resetPacer()
		state.lastRateSample = os.clock()
		state.tickCount = 0
		state.actualSpamRate = 0

		pcall(function()
			state.ui.spam:Set(newState)
		end)

		if state.spamButton then
			state.spamButton.silentSet(newState)
			state.spamButton.setState(newState)
		end
	elseif state.keybinds.tg == keyName then
		local newState = not state.triggerbot
		state.triggerbot = newState

		if newState then
			for _, ball in ipairs(ballAPI.gbs()) do
				handleBallTarget(ball)
			end
		end

		pcall(function()
			state.ui.triggerbot:Set(newState)
		end)

		if state.triggerButton then
			state.triggerButton.silentSet(newState)
			state.triggerButton.setState(newState)
		end
	elseif state.keybinds.orb == keyName then
		local newState = not state.orbit.on
		state.orbit.on = newState
		state.orbit.angle = 0
		state.orbit.lastUpdate = os.clock()

		pcall(function()
			state.ui.orbit:Set(newState)
		end)
	end
end)

RunService.PreSimulation:Connect(function()
	updateAimCache()
end)

RunService.Heartbeat:Connect(function()
	if not state.orbit.on then
		return
	end

	local now = os.clock()
	local deltaTime = now - state.orbit.lastUpdate
	state.orbit.lastUpdate = now

	if deltaTime > 0.1 then
		deltaTime = 0.1
	end

	updateOrbit(deltaTime)
end)

setSpamRate(500)

task.defer(function()
	pcall(function()
		Slider:Set(500)
	end)
	setSpamRate(500)
end)

