--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Promise = require(ReplicatedStorage.Util.Promise)
local Signal = require(ReplicatedStorage.Util.Signal)
local MessagePack = require(ReplicatedStorage.Util.MessagePack)

type Config = {
	MemoryName: string,
	Version: number?,
	Mock: boolean?,
	CompressThreshold: number?,
	AutoSaveInterval: number?,
}

type Entry<T> = {
	Key: string,
	Data: T,
	Active: boolean,
	Locked: boolean,
	Loaded: Signal.Signal<T>,
	Saved: Signal.Signal<boolean>,
}

type Memory<T> = {
	_dataStore: DataStore,
	new: (template: T, config: Config?) -> Memory<T>,
	SaveAsync: (self: Memory<T>, key: string | number) -> Promise.Promise<boolean>,
	LoadAsync: (self: Memory<T>, key: string | number) -> Promise.Promise<T>,
	Get: (self: Memory<T>, key: string | number) -> Entry<T>,
	Release: (self: Memory<T>, key: string | number) -> (),
	_migrate: (self: Memory<T>, data: T) -> (),
	migrate: (self: Memory<T>, data: T) -> (),
	reconcile: (self: Memory<T>, data: T) -> (),
}

local DEFAULT_CONFIG: Config = {
	MemoryName = "Data",
	Version = 1,
	Mock = false,
	CompressThreshold = 256,
	AutoSaveInterval = 1,
}

local Memory = {}
Memory.__index = Memory

Memory._entries = {}
Memory._config = DEFAULT_CONFIG

function Memory.new<T>(template: T, config: Config?): Memory<T>
	local _config = config or DEFAULT_CONFIG
	for key, value in pairs(DEFAULT_CONFIG) do
		if not _config[key] then
			_config[key] = value
		end
	end
	local self = setmetatable({
		_config = _config,
		_entries = {},
		_template = typeof(template) == "table" and table.clone(template) or template,
	}, Memory)

	if self._config.Mock then
		self._dataStore =
			DataStoreService:GetDataStore(_config.MemoryName .. self._config.Version :: number, tostring(tick()))
	else
		self._dataStore = DataStoreService:GetDataStore(_config.MemoryName .. self._config.Version :: number)
	end

	task.spawn(self._startAutoSave, self)
	game:BindToClose(function()
		for key, entry in pairs(self._entries) do
			task.spawn(function()
				self:SaveAsync(key):await()
				entry:Release()
			end)
		end
	end)

	return self
end

function Memory:_startAutoSave()
	while true do
		for _, entry in pairs(self._entries) do
			if entry.Active then
				self:SaveAsync(entry.Key)
			end
		end
		task.wait(self._config.AutoSaveInterval)
	end
end

function Memory:SaveAsync(key: string | number): Promise.Promise<boolean>
	key = tostring(key)
	local entry = self._entries[key]

	if entry and entry.Active then
		return Promise.new(function(resolve, reject)
			local data = entry.Data
			local encoded = false

			if #MessagePack.encode(data) > self._config.CompressThreshold :: number then
				data = "--" .. MessagePack.utf8Encode(MessagePack.encode(data))
				encoded = true
			end

			local success = pcall(function()
				self._dataStore:SetAsync(tostring(key), data)
			end)

			if success then
				entry.Saved:Fire(encoded)
				resolve(encoded)
			else
				reject("Failed to save entry for key " .. tostring(key))
			end
		end)
	end

	return Promise.reject("Entry not loaded")
end

function Memory:LoadAsync<T>(key: string | number): Promise.Promise<any>
	key = tostring(key)
	local entry = self:Get(key)

	return Promise.new(function(resolve, reject)
		if entry.Locked then
			reject("Entry is locked for key " .. tostring(key))
			return
		end

		entry.Locked = true

		local success, data = pcall(function()
			return self._dataStore:GetAsync(tostring(key))
		end)

		if success then
			data = data or {}
			if type(data) == "string" and data:sub(1, 2) == "--" then
				data = MessagePack.decode(MessagePack.utf8Decode(data:sub(3)))
			end

			self:_migrate(data)
			entry.Data = data
			entry.Active = true
			entry.Loaded:Fire(data)

			resolve(data)
		else
			entry.Locked = false
			reject("Failed to load entry for key " .. tostring(key))
		end
	end)
end

local Entry = {}
Entry.__index = Entry

function Entry.new(key, template)
	local self = setmetatable({
		Key = key,
		Data = template,
		Active = false,
		Locked = false,
		Loaded = Signal.new(),
		Saved = Signal.new(),
	}, Entry)
	return self
end

function Entry:Release()
	self.Loaded:DisconnectAll()
	self.Saved:DisconnectAll()
end

function Memory:Get<T>(key: string | number): Entry<T>
	key = tostring(key)
	local entry = self._entries[key]

	if not entry then
		entry = Entry.new(key, self._template)
		self._entries[key] = entry
	end

	return entry
end

function Memory:Release(key: string | number)
	key = tostring(key)
	local entry = self._entries[key]
	if entry then
		self:SaveAsync(key):await()
		entry:Release()
		entry.Locked = false
		self._entries[key] = nil
	end
end

function Memory:Lock(key: string): boolean
	local entry = self._entries[key]
	if entry and not entry.Locked then
		entry.Locked = true
		return true
	end
	return false
end

function Memory:Unlock(key: string): boolean
	local entry = self._entries[key]
	if entry and entry.Locked then
		entry.Locked = false
		return true
	end
	return false
end

function Memory:_migrate(data)
	if data.Version ~= self._config.Version then
		self:migrate(data)
		data.Version = self._config.Version
	end
	self:reconcile(data)
end

function Memory:migrate(data) end

function Memory:reconcile(data)
	for key, value in pairs(self._template) do
		if data[key] == nil then
			data[key] = value
		end
	end
end

return Memory
