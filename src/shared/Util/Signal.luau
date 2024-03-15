--!strict

--[[
    Signal.luau
    A signal library for Roblox using Luau.
    This library provides a simple way to create and manage signals, which allow for event-driven programming.
    It includes the following classes and types:
    - Signal: Represents a signal that can be connected to and fired.
    - Connection: Represents a connection to a signal, which can be disconnected.
    The library also uses promises to provide a way to wait for a signal to be fired.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Util.Promise)

local Connection = {}
Connection.__index = Connection

type Connection<T...> = {
	Disconnect: (Connection<T...>) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (Signal<T...>, (T...) -> ()) -> Connection<T...>,
	DisconnectAll: (Signal<T...>) -> (),
	Fire: (Signal<T...>, T...) -> (),
	Wait: (Signal<T...>) -> (),
	Once: (Signal<T...>, (T...) -> ()) -> Connection<T...>,
}

function Connection.new<T...>(signal: Signal<T...>, fn: (T...) -> ()): Connection<T...>
	return setmetatable({
		_connected = true,
		_signal = signal,
		_fn = fn,
		_next = nil,
	}, Connection)
end

function Connection:Disconnect()
	assert(self._connected, "Can't disconnect a connection twice.", 2)
	self._connected = false
	if self._signal._handlerListHead == self then
		self._signal._handlerListHead = self._next
	else
		local prev = self._signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_handlerListHead = nil,
	}, Signal)
end

function Signal:Connect<T...>(fn: (T...) -> ()): Connection<T...>
	local connection = Connection.new(self, fn)
	if self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end
	return connection
end

function Signal:DisconnectAll()
	self._handlerListHead = nil
end

function Signal:Fire<T...>(...: T...)
	local item = self._handlerListHead
	while item do
		if item._connected then
			item._fn(...)
		end
		item = item._next
	end
end

function Signal:Wait<T...>()
	return Promise.new(function(resolve)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			resolve(...)
		end)
	end):await()
end

return Signal
