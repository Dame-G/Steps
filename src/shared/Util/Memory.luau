--!strict

--[[
    Luau Memory Module
    This module provides a simple key-value store with auto-saving functionality using Roblox's DataStore service.
    It includes the following classes and types:
    - Memory: Represents the main memory store, which manages entries and auto-saving.
    - Entry: Represents a single entry in the memory store, with a key, data, and signals for loading and saving.
    - Config: Represents the configuration options for the memory store, such as the DataStore name and version.
    The module also includes utility functions for loading, saving, and migrating data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Promise = require(ReplicatedStorage.Util.Promise)
local Signal = require(ReplicatedStorage.Util.Signal)
local Base64 = require(ReplicatedStorage.Util.Base64)
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
	LastSaveTime: number,
	Loaded: Signal.Signal<T>,
	Saved: Signal.Signal<boolean>,
}

type Memory<T> = {
	_config: Config,
	_entries: { [string]: Entry<T> },
	_template: T,
	_dataStore: DataStore,
	_autoSaveInterval: number,
	_autoSaveLoop: thread,
	new: (template: T, config: Config?) -> Memory<T>,
	SaveAsync: (self: Memory<T>, key: string) -> Promise.Promise<boolean>,
	LoadAsync: (self: Memory<T>, key: string) -> Promise.Promise<T>,
	Get: (self: Memory<T>, key: string) -> Entry<T>,
	Release: (self: Memory<T>, key: string) -> (),
	AutoSave: (self: Memory<T>, interval: number?) -> (),
	_migrate: (self: Memory<T>, data: T) -> (),
	migrate: (self: Memory<T>, data: T) -> (),
	reconcile: (self: Memory<T>, data: T) -> (),
}

local DEFAULT_CONFIG: Config = {
	MemoryName = "Data",
	Version = 1,
	Mock = false,
	CompressThreshold = 256,
	AutoSaveInterval = 5,
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
		_template = template,
	}, Memory)

	if self._config.Mock then
		self._dataStore = DataStoreService:GetDataStore(_config.MemoryName, tostring(tick()))
	else
		self._dataStore = DataStoreService:GetDataStore(_config.MemoryName)
	end

	self:AutoSave()

	return self
end

function Memory:SaveAsync(key: string): Promise.Promise<boolean>
	local entry = self._entries[key]

	if entry and entry.Active then
		return Promise.new(function(resolve, reject)
			local data = entry.Data
			local encoded = false

			if #MessagePack.encode(data) > self._config.CompressThreshold :: number then
				data = "--" .. Base64.encode(MessagePack.encode(data))
				encoded = true
			end

			local success = pcall(function()
				self._dataStore:SetAsync(tostring(key), data)
			end)

			if success then
				entry.LastSaveTime = os.clock()
				entry.Saved:Fire(encoded)
				resolve(encoded)
			else
				reject("Failed to save entry for key " .. tostring(key))
			end
		end)
	end

	return Promise.reject("Entry not loaded")
end

function Memory:LoadAsync<T>(key: string): Promise.Promise<T>
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
			local dataSize = #MessagePack.encode(data)
			if type(data) == "string" and data:sub(1, 2) == "--" then
				data = MessagePack.decode(Base64.decode(data:sub(3)))
				print("Loaded data for key " .. tostring(key) .. " (Size: " .. dataSize .. " bytes, Encoded)")
			else
				print("Loaded data for key " .. tostring(key) .. " (Size: " .. dataSize .. " bytes, Not Encoded)")
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
		LastSaveTime = 0,
		Loaded = Signal.new(),
		Saved = Signal.new(),
	}, Entry)
	return self
end

function Entry:Release()
	self.Loaded:DisconnectAll()
	self.Saved:DisconnectAll()
end

function Memory:Get<T>(key: string): Entry<T>
	local entry = self._entries[key]

	if not entry then
		entry = Entry.new(key, self._template)
		self._entries[key] = entry
	end

	return entry
end

function Memory:Release(key: string | number)
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

function Memory:AutoSave(interval: number?)
	self._autoSaveInterval = interval or self._config.AutoSaveInterval
	self._autoSaveLoop = task.defer(function()
		while true do
			local savePromises = {}
			for key, entry in pairs(self._entries) do
				if entry.Active then
					table.insert(savePromises, self:SaveAsync(key))
				end
			end
			Promise.all(savePromises :: { Promise.Promise<boolean> }):await()
			task.wait(self._autoSaveInterval)
		end
	end)
end

function Memory:_migrate(data)
	if data.version ~= self._config.Version then
		self:migrate(data)
		data.version = self._config.Version
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
