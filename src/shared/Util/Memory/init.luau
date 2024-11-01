--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Promise = require(ReplicatedStorage.Util.Promise)

local Config = require(script.Config)
local Entry = require(script.Entry)
local Utils = require(script.Utils)

export type Memory<T> = {
	_dataStore: DataStore,
	new: (template: T, config: Config.Config?) -> Memory<T>,
	SaveAsync: (self: Memory<T>, key: string, force: boolean?) -> Promise.Promise<boolean>,
	LoadAsync: (self: Memory<T>, key: string, active: boolean?) -> Promise.Promise<T>,
	Get: (self: Memory<T>, key: string) -> Entry.Entry<T>,
	Release: (self: Memory<T>, key: string) -> (),
	_migrate: (self: Memory<T>, data: T) -> (),
	migrate: (self: Memory<T>, data: T) -> (),
	reconcile: (self: Memory<T>, data: T) -> (),
	GetMetrics: (self: Memory<T>) -> { [string]: number },
}

local Memory = {}
Memory.__index = Memory

function Memory.new<T>(template: T, config: Config.Config?): Memory<T>
	local _config = Config.createConfig(config)
	assert(_config.CacheSize and _config.CacheSize > 0, "Cache size must exist and be greater than 0")
	local self = setmetatable({
		_config = _config,
		_entries = table.create(_config.CacheSize),
		_cacheKeys = table.create(_config.CacheSize),
		_template = typeof(template) == "table" and table.clone(template) or template,
	}, Memory)

	if self._config.Mock then
		self._dataStore = DataStoreService:GetDataStore(_config.MemoryName .. _config.Version, tostring(tick()))
	else
		self._dataStore = DataStoreService:GetDataStore(_config.MemoryName .. _config.Version)
	end

	task.spawn(self._startAutoSave, self)
	game:BindToClose(function()
		self:_onShutdown()
	end)

	return self
end

function Memory:_startAutoSave()
	while task.wait(self._config.AutoSaveInterval) do
		local savedCount = 0
		for _, entry in pairs(self._entries) do
			if entry.Active then
				self:SaveAsync(entry.Key)
				savedCount += 1
			end
		end
	end
end

function Memory:_onShutdown()
	for key, entry in pairs(self._entries) do
		self:Release(tostring(key))
	end
end

function Memory:SaveAsync(key: string, force: boolean?): Promise.Promise<boolean>
	local entry = self._entries[key]
	assert(
		self._config.CompressThreshold and self._config.CompressThreshold > 0,
		"Compress threshold must exist and be greater than 0"
	)

	if entry and (entry.Active or force) then
		return Promise.new(function(resolve, reject)
			local data = entry.Data
			local encoded = Utils.compressIfNeeded(data, self._config.CompressThreshold)

			local success = pcall(function()
				self._dataStore:SetAsync(key, encoded.data)
			end)

			if success then
				entry.Saved:Fire(encoded.wasCompressed)
				resolve(encoded.wasCompressed)
			else
				reject("Failed to save data for key " .. key)
			end
		end)
	end

	return Promise.reject("Data not active or doesn't exist")
end

function Memory:LoadAsync<T>(key: string, active: boolean?): Promise.Promise<T>
	local entry = self:Get(key)

	return Promise.new(function(resolve, reject)
		if entry.Locked then
			reject("Data is locked for key " .. key)
			return
		end

		local success, data = pcall(function()
			return self._dataStore:GetAsync(tostring(key))
		end)

		entry.Locked = true

		if success then
			data = Utils.decompressIfNeeded(data) or {}
			if active == nil then
				active = true
			end

			if active then
				self:_migrate(data)
			end
			entry.Data = data
			entry.Active = active

			if not active then
				entry.Locked = false
			end

			if active then
				entry.Loaded:Fire(data)
			end
			resolve(data)
		else
			entry.Locked = false
			reject("Failed to load data for key " .. key)
		end
	end)
end

function Memory:Get<T>(key: string): Entry.Entry<T>
	local entry = self._entries[key]

	if not entry then
		if #self._cacheKeys >= self._config.CacheSize then
			local oldestKey = table.remove(self._cacheKeys, 1)
			self:Release(oldestKey)
			assert(
				oldestKey ~= nil and typeof(oldestKey) == "string",
				"Cache full, but no oldest key found or key is not a string"
			)
		end

		entry = Entry.new(key, self._template)
		self._entries[key] = entry
		table.insert(self._cacheKeys, key)
	else
		Utils.updateCacheOrder(self._cacheKeys, key)
	end

	entry.LastAccessed = tick()
	return entry
end

function Memory:Release(key: string)
	local entry = self._entries[key]
	if entry then
		entry.Locked = false
		if entry.Active then
			entry.Active = false
			self:SaveAsync(key, true)
		end

		entry:Release()
		self._entries[key] = nil

		Utils.removeFromCache(self._cacheKeys, key)
	end
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
	local reconciledCount = 0
	for key, value in pairs(self._template) do
		if data[key] == nil then
			data[key] = value
			reconciledCount += 1
		end
	end
end

return Memory
