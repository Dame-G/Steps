--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Util.Signal)

export type Entry<T> = {
	Key: string,
	Data: T,
	Active: boolean,
	Locked: boolean,
	Loaded: Signal.Signal<T>,
	Saved: Signal.Signal<boolean>,
	LastAccessed: number,
	Release: (self: Entry<T>) -> (),
	SetActive: (self: Entry<T>, active: boolean) -> (),
}

local Entry = {}
Entry.__index = Entry

function Entry.new<T>(key: string, template: T): Entry<T>
	local self = setmetatable({
		Key = key,
		Data = template,
		Active = false,
		Locked = false,
		Loaded = Signal.new(),
		Saved = Signal.new(),
		LastAccessed = tick(),
	}, Entry)
	return self
end

function Entry:Release()
	self.Loaded:DisconnectAll()
	self.Saved:DisconnectAll()
end

function Entry:SetActive(active: boolean)
	self.Active = active
end

return Entry
