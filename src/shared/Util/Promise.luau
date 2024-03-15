--!strict

type PromiseStatus = "Pending" | "Resolved" | "Rejected"
type PromiseExecutor<T> = (resolve: (value: T) -> (), reject: (reason: any) -> ()) -> ()
type PromiseThen<T> = (value: T) -> ()
type PromiseCatch = (reason: any) -> ()

export type Promise<T> = {
	_status: PromiseStatus,
	_value: T?,
	_reason: any?,
	_thenCallbacks: { PromiseThen<T> },
	_catchCallbacks: { PromiseCatch },
	andThen: (self: Promise<T>, thenCallback: PromiseThen<T>) -> Promise<T>,
	await: (self: Promise<T>) -> ...T,
	catch: (self: Promise<T>, catchCallback: PromiseCatch) -> Promise<T>,
}

local Promise = {}

function Promise.new<T>(executor: PromiseExecutor<T>): Promise<T>
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

	local function resolve(...: T)
		if self._status == "Pending" then
			self._status = "Resolved"
			self._value = ...
			for _, callback in ipairs(self._thenCallbacks) do
				callback(...)
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

	task.spawn(executor, resolve, reject)

	return self
end

function Promise.andThen<T>(self: Promise<T>, thenCallback: PromiseThen<T>): Promise<T>
	if self._status == "Resolved" and self._value then
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
	if self._status == "Resolved" and self._value then
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

function Promise.resolve<T>(value: T): Promise<T>
	return Promise.new(function(resolve)
		resolve(value)
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
				:andThen(function(value)
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
