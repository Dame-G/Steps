--!strict

--[[
    Promise.luau
    A promise library for Roblox using Luau.
    This library provides an implementation of promises, which allow for asynchronous programming and handling of async operations.
    It includes the following types and functions:
    - Promise: Represents a promise that can be resolved or rejected.
    - PromiseStatus: Represents the status of a promise (Pending, Resolved, or Rejected).
    - PromiseExecutor: Represents the executor function that is passed to the Promise constructor.
    - PromiseThen: Represents the callback function for handling resolved promises.
    - PromiseCatch: Represents the callback function for handling rejected promises.
    The library also provides utility functions for creating resolved or rejected promises, waiting for promises to resolve, and handling multiple promises.
]]

type PromiseStatus = "Pending" | "Resolved" | "Rejected"
type PromiseExecutor = (resolve: (value: any) -> (), reject: (reason: any) -> ()) -> ()
type PromiseThen<T> = (value: T) -> ()
type PromiseCatch = (reason: any) -> ()

export type Promise<T> = {
	_status: PromiseStatus,
	_value: T?,
	_reason: any,
	_thenCallbacks: { PromiseThen<T> },
	_catchCallbacks: { PromiseCatch },
	andThen: (self: Promise<T>, thenCallback: PromiseThen<T>) -> Promise<T>,
	await: (self: Promise<T>) -> ...T,
	catch: (self: Promise<T>, catchCallback: PromiseCatch) -> Promise<T>,
}

local Promise = {}

function Promise.new<T>(executor: PromiseExecutor): Promise<T>
	local self: Promise<T> = {
		_status = "Pending",
		_value = nil,
		_reason = nil,
		_thenCallbacks = {},
		_catchCallbacks = {},
		andThen = Promise.andThen,
		await = Promise.await,
		catch = Promise.catch,
	}

	local function resolve(...: any)
		local data = { ... }
		if self._status == "Pending" then
			self._status = "Resolved"
			self._value = unpack(data)
			for _, callback in ipairs(self._thenCallbacks) do
				callback(unpack(data))
			end
		end
	end

	local function reject(reason: any)
		if self._status == "Pending" then
			self._status = "Rejected"
			self._reason = reason
			for _, callback in ipairs(self._catchCallbacks) do
				callback(reason)
			end
		end
	end

	executor(resolve, reject)

	return self
end

function Promise.andThen<T>(self: Promise<T>, thenCallback: PromiseThen<T>): Promise<T>
	if self._status == "Resolved" then
		thenCallback(self._value)
	else
		table.insert(self._thenCallbacks, thenCallback)
	end
	return self
end

function Promise.await<T>(self: Promise<T>): ...T
	while self._status == "Pending" do
		task.wait()
	end
	if self._status == "Resolved" then
		return self._value
	else
		error(self._reason)
	end
end

function Promise.catch<T>(self: Promise<T>, catchCallback: PromiseCatch): Promise<T>
	if self._status == "Rejected" then
		catchCallback(self._reason)
	else
		table.insert(self._catchCallbacks, catchCallback)
	end
	return self
end

function Promise.resolve<T>(...: any): Promise<T>
	local data = { ... }
	return Promise.new(function(resolve)
		resolve(unpack(data))
	end)
end

function Promise.reject<T>(reason: any): Promise<T>
	return Promise.new(function(_, reject)
		reject(reason)
	end)
end

function Promise.all<T>(promises: { Promise<T> }): Promise<{ T }>
	return Promise.new(function(resolve, reject)
		local results = table.create(#promises)
		local pending = #promises
		if pending == 0 then
			resolve(results)
			return
		end
		for i, promise in ipairs(promises) do
			promise
				:andThen(function(value: T)
					results[i] = value
					pending -= 1
					if pending == 0 then
						resolve(results)
					end
				end)
				:catch(function(reason)
					reject(reason)
				end)
		end
	end)
end

function Promise.try<T>(callback: () -> T): Promise<T>
	return Promise.new(function(resolve, reject)
		local success, result = pcall(callback)
		if success then
			resolve(result)
		else
			reject(result)
		end
	end)
end

return Promise
