--[[
	made to bridge client and server sounds since I'm shocking at doing anything sound related



]]






export type ModifidedConfig = {
	Name: string, -- just for keeping track of it in cache
	ID: number | string,
	Origin: Vector3 | BasePart,
	SoundConfig:{[string]:any}?,


	Modifiers:{[string]:{ -- will make a template
		[string]:any
	}
	}?,
	
	StartTime:number
}



local runService = game:GetService("RunService")
local shared 		 = game:GetService("ReplicatedStorage")
local players    = game:GetService("Players")

local packages 	 = shared.Packages


local soundBrigeServer = {}
local soundBrigeClient = {}



local soundCache = {}
local serverCache: {[string]:ModifidedConfig?} = {}

export type Config = {
	Name: string, -- just for keeping track of it in cache
	ID: number | string,
	Origin: Vector3 | BasePart,
	SoundConfig:{[string]:any}?,


	Modifiers:{[string]:{
		[string]:any
	}
	}?
}






--CreatesSound

local function AddModifierStats(Inst: Instance , Info:{[string]:any})
	for Modifier , V in Info do
		local S , E = pcall(function()
			Inst[Modifier] = V
		end)
		
		if not S then
			warn(E)
		end
	end
end

local function CreateSound(Config: Config)
	local sound = Instance.new("Sound")
	
	if typeof(Config.ID) == "string" then
		sound.SoundId = Config.ID
	else
		sound.SoundId = `rbxassetid://{Config.ID}`
	end
	
	if Config.Modifiers then
		for Name , V in Config.Modifiers do
			local S , E = pcall(function()
				local mod = Instance.new(Name) :: Instance
				mod.Parent = sound

				if V then
					AddModifierStats(mod , V)
				end
			end)

			if not S then
				warn(E)
			end
		end
	end
	
	if Config.SoundConfig then
		for Name , V in Config.SoundConfig do
			local S , E = pcall(function()
				sound[Name] = V
			end)

			if not S then warn(E) end
		end
	end
	
	return sound
end









function soundBrigeClient.PlaySound(Config: Config)
	local Sound = CreateSound(Config)
	local trove = require(packages.Trove).new() :: typeof(require(packages.Trove))

	trove["Sound"] = Sound -- I like intellascense don't judge that's mean


	local function Clean()
		trove:Destroy()
		trove = nil
		
		script:FindFirstChildOfClass("RemoteEvent"):FireServer("SoundStopped" ,Config.Name)
	end


	
	if typeof(Config.Origin) == "Vector3" then
		local Temp = Instance.new("Part")
		Temp.Size = Vector3.new(1,1,1)
		Temp.Anchored = true
		Temp.Position = Config.Origin
		
		Temp.CanCollide = false
		Temp.CanTouch = false
		Temp.CanQuery = false
		Temp.AudioCanCollide = false
		
		
		Temp.Parent = workspace
		
		trove["Origin"] = Temp
		Sound.Parent = Temp
	else
		Sound.Parent = Config.Origin
	end
	
	if not soundCache then
		soundCache = {}
	end
	
	if Config.Name then
		soundCache[Config.Name] = Sound
	else
		print(Config.Name)
		warn("Sound Is Name Less this might be an issue")
	end
	
	
	
	
	
	Sound.Ended:Connect(function()
		Clean()
	end)

	Sound.Stopped:Connect(function()
		Clean()
	end)

	Sound:Play()
end

function	soundBrigeClient.StopSound(Name: string)
	if soundCache[Name] then
		soundCache[Name]:Stop()
	end	
end


function soundBrigeServer.PlaySound(Players : {Players}| Player , Config: Config, Cache:boolean?)
	
	if Cache == true then
		
		local newConfig = Config
		newConfig.StartTime = time()
		
		serverCache[Config.Name] = newConfig
	end
	
	
	
	
	if typeof(Players) == "Instance" then
		script:FindFirstChildOfClass("RemoteEvent"):FireClient(Players, "Play" , Config)
	else
		for _ , Player in Players do
			script:FindFirstChildOfClass("RemoteEvent"):FireClient(Players, "Play" , Config)
		end	
	end
end

function soundBrigeServer.StopSound(Players : {Player}| Player , Name:string)
	
	if serverCache[Name] then
		serverCache[Name] = nil
	end
	
	
	if typeof(Players) == "Instance" and Players:IsA("Player") then
		script:FindFirstChildOfClass("RemoteEvent"):FireClient(Players , "Stop" , Name)
	else
		for _ , Player in Players do
			if  typeof(Player) == "Instance" and Player:IsA("Player") then
				script:FindFirstChildOfClass("RemoteEvent"):FireClient(Players, "Stop" , Name)
			end
		end	
	end
end

local function RemoveItemFromServerCache(Name:string) -- for when song / music stops and makes it not be replicated to server
	if serverCache[Name] then
		serverCache[Name] = nil
	end
end







local function PlayerAdded(Player: Player)
	for _ , V in serverCache do
		local Temp = V
		Temp.SoundConfig["TimePosition"] = time() - V.StartTime
		Temp.StartTime = nil
		
		script:FindFirstChildOfClass("RemoteEvent"):FireClient(Player , "Play" , Temp)
	end
end














if runService:IsServer() then
	-- inits module
	Instance.new("RemoteEvent").Parent = script
	
	script:FindFirstChildOfClass("RemoteEvent").OnServerEvent:Connect(function(Player , Action , ...)
		if Action == "SoundStopped" then -- just to clear cache
			RemoveItemFromServerCache(...)
		end
		
		
		warn(Player , Action , ...)
	end)
	
	
	
	players.PlayerAdded:Connect(PlayerAdded)
	
	for _ , V in players:GetChildren() do
		if V:IsA("Player") then
			PlayerAdded(V)
		end
	end
	
	
	return soundBrigeServer
else

	
	if script:FindFirstChildOfClass("RemoteEvent") then
		
		script:FindFirstChildOfClass("RemoteEvent").OnClientEvent:Connect(function(Action , ...)
			if Action == "Play" then
				soundBrigeClient.PlaySound(...)
			elseif Action == "Stop" then
				soundBrigeClient.StopSound(...)
			end
		end)
	else
		warn("Server needs to be called first")
	end





	return soundBrigeClient
end
