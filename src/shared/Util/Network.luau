--!strict

--[[
    Network.luau
    A channel-based networking library for Roblox using Luau.
    This library provides a simple way to create and manage network channels for communication between the server and clients.
    It includes the following classes and types:
    - Network: Represents the main networking object, which is used to create channels.
    - Channel: Represents a network channel, which can be used to send and receive data.
    - Config: Represents the configuration options for a channel, such as throttling and batch size.
    The library uses MessagePack and LibDeflate for serialization and compression of data, and it also uses promises for handling async operations.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remoteEvent: RemoteEvent
local remoteFunction: RemoteFunction

local MessagePack = require(ReplicatedStorage.Util.MessagePack)
local LibDeflate = require(ReplicatedStorage.Util.LibDeflate)
local Signal = require(ReplicatedStorage.Util.Signal)
local Promise = require(ReplicatedStorage.Util.Promise)

if RunService:IsServer() then
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = "NetworkRemoteEvent"
	remoteEvent.Parent = ReplicatedStorage

	remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = "NetworkRemoteFunction"
	remoteFunction.Parent = ReplicatedStorage
end

if RunService:IsClient() then
	remoteEvent = ReplicatedStorage:WaitForChild("NetworkRemoteEvent") :: RemoteEvent
	remoteFunction = ReplicatedStorage:WaitForChild("NetworkRemoteFunction") :: RemoteFunction
end

local Network = {}
Network.__index = Network

local channels: { [string]: Channel<any, any, any> } = {}

local Channel = {}
Channel.__index = Channel

local queues = {}

type Config = {
	ThrottleInterval: number?,
	MaxBatchSize: number?,
	CompressThreshold: number?,
}

type Callback<T> = (...T) -> any
type RespondCallback<TSend, TReceive> = (player: Player, ...TSend) -> TReceive

type Channel<TSend, TReceive, TRespond> = {
	Send: (...TSend) -> (),
	SendTo: (player: Player, ...TSend) -> (),
	Broadcast: (...TSend) -> (),
	Call: (...TSend) -> Promise.Promise<TReceive>,
	Respond: (callback: RespondCallback<TRespond, TReceive>) -> (),
	Receive: (callback: Callback<TReceive>) -> Signal.Signal<TReceive>,
	_received: Signal.Signal<TReceive>,
	name: string,
	config: Config,
	queue: { TSend },
	lastSendTime: number,
	Serialize: (Channel<TSend, TReceive, TRespond>, any) -> string,
	Deserialize: (Channel<TSend, TReceive, TRespond>, any) -> any,
	SendBatch: (Channel<TSend, TReceive, TRespond>) -> (),
}

local DefaultConfig: Config = {
	ThrottleInterval = 0.025,
	MaxBatchSize = 100,
	CompressThreshold = 256,
}

function Channel.new<TSend, TReceive, TRespond>(name: string, config: Config?): Channel<TSend, TReceive, TRespond>
	local self = setmetatable({}, Channel)
	self.name = name
	self._received = Signal.new()
	self.config = config or DefaultConfig
	for key, value in pairs(DefaultConfig) do
		if self.config[key] == nil then
			self.config[key] = value
		end
	end
	self.queue = {}
	self.lastSendTime = 0

	if RunService:IsServer() then
		queues[name] = self.queue
	end

	return self
end

function Channel:SendBatch()
	if #self.queue > 0 then
		local data = self:Serialize(self.queue)
		remoteEvent:FireServer(self.name, data)
		table.clear(self.queue)
	end
end

function Channel:Send(...: any)
	local data = { ... }
	table.insert(self.queue, data)

	if #self.queue >= self.config.MaxBatchSize or os.clock() - self.lastSendTime >= self.config.ThrottleInterval then
		self:SendBatch()
		self.lastSendTime = os.clock()
	end
end

function Channel:Call(...: any)
	local _data = { ... }
	return Promise.new(function(resolve, reject)
		local data = self:Serialize(_data)
		local success, result = pcall(function()
			return remoteFunction:InvokeServer(self.name, data)
		end)
		if success then
			local deserializedResult = self:Deserialize(result)
			resolve(deserializedResult)
		else
			reject(result)
		end
	end)
end

function Channel:SendTo(player: Player, ...: any)
	local data = self:Serialize({ ... })
	remoteEvent:FireClient(player, self.name, data)
end

function Channel:Broadcast(...: any)
	local data = self:Serialize({ ... })
	remoteEvent:FireAllClients(self.name, data)
end

function Channel:Respond(callback: (player: Player, ...any) -> ...any)
	remoteFunction.OnServerInvoke = function(player: Player, name: string, data: string)
		if name == self.name then
			local deserializedData = self:Deserialize(data)
			local result = callback(player, unpack(deserializedData))
			return self:Serialize(result)
		end
	end
end

function Channel:Receive(callback: (...any) -> ())
	return self._received:Connect(callback)
end

function Channel:Serialize(data: any): string
	local serialized = MessagePack.encode(data)
	if #MessagePack.encode(serialized) >= self.config.CompressThreshold then
		serialized = "--" .. LibDeflate:CompressDeflate(serialized)
	end
	return serialized
end

function Channel:Deserialize(data: any): any
	if type(data) == "string" then
		if data:sub(1, 2) == "--" then
			data = LibDeflate:DecompressDeflate(data:sub(3))
		end
		return MessagePack.decode(data)
	else
		return data
	end
end

function Network:Create<TSend, TReceive, TRespond>(name: string, config: Config?): Channel<TSend, TReceive, TRespond>
	if not channels[name] then
		channels[name] = Channel.new(name, config)
	end
	return channels[name]
end

if RunService:IsServer() then
	remoteEvent.OnServerEvent:Connect(function(player: Player, name: string, data: string)
		local channel = channels[name]
		if channel then
			local deserializedData = channel:Deserialize(data)
			for _, item in ipairs(deserializedData) do
				(channel._received :: any):Fire(player, unpack(item))
			end
		end
	end)
else
	remoteEvent.OnClientEvent:Connect(function(name: string, data: string)
		local channel = channels[name]
		if channel then
			local deserializedData = channel:Deserialize(data)
			for _, item in ipairs(deserializedData) do
				(channel._received :: any):Fire(item)
			end
		end
	end)
end

return Network
