--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Util.Promise)
local Signal = require(ReplicatedStorage.Util.Signal)

export type Component<T> = {
	Name: string,
	Data: T,
	Changed: Signal.Signal<{ any }, any>,
	Set: (self: Component<T>, path: { any }, value: any) -> (),
	Get: (self: Component<T>, path: { any }) -> any,
}

export type Entity = {
	Active: boolean,
	Reference: any,
	ComponentAdded: Signal.Signal<Component<any>>,
	ComponentRemoved: Signal.Signal<Component<any>>,
	AddComponent: <T>(self: Entity, component: Component<T>) -> Component<T>,
	RemoveComponent: (self: Entity, name: string) -> (),
	GetComponent: <T>(self: Entity, name: string) -> Component<T>?,
	HasComponent: (self: Entity, name: string) -> boolean,
	SetActive: (self: Entity, active: boolean) -> (),
	IsActive: (self: Entity) -> boolean,
}

export type System<T...> = {
	AddEntity: (self: System<T...>, entity: Entity) -> (),
	shouldAddEntity: (self: System<T...>, entity: Entity) -> boolean,
	RemoveEntity: (self: System<T...>, entity: Entity) -> (),
	Update: (self: System<T...>, tick: number, config: WorldConfig?) -> (),
}

type WorldConfig = {
	Speed: number?,
}

local DEFAULT_CONFIG: WorldConfig = {
	Speed = 1,
}
export type World = {
	AddEntity: (self: World, entity: Entity) -> (),
	RemoveEntity: (self: World, entity: Entity) -> (),
	GetEntity: (self: World, queryFunc: (Entity) -> boolean) -> Entity?,
	AddSystem: <T...>(self: World, system: System<T...>) -> (),
	Update: (self: World) -> (),
}

local World = {}
World.__index = World

function World.new(config: WorldConfig?): World
	local _config = config and table.clone(config) or DEFAULT_CONFIG
	for key, value in pairs(DEFAULT_CONFIG) do
		if not _config[key] then
			_config[key] = value
		end
	end
	return setmetatable({ _entities = {}, _systems = {}, _tick = 0, _config = _config }, World)
end

function World:AddEntity(entity: Entity)
	table.insert(self._entities, entity)
	for _, system in ipairs(self._systems) do
		if system:shouldAddEntity(entity) then
			system:AddEntity(entity)
		end
	end
end

function World:RemoveEntity(entity: Entity)
	for i, e in ipairs(self._entities) do
		if e == entity then
			table.remove(self._entities, i)
			break
		end
	end
	for _, system in ipairs(self._systems) do
		system:RemoveEntity(entity)
	end
end

function World:GetEntity(queryFunc: (Entity) -> boolean): Entity?
	for _, entity in ipairs(self._entities) do
		if queryFunc(entity) then
			return entity
		end
	end
	return nil
end

function World:AddSystem<T>(system: System<T>)
	table.insert(self._systems, system)
	for _, entity in ipairs(self._entities) do
		if system:shouldAddEntity(entity) then
			system:AddEntity(entity)
		end
	end
end

function World:Update()
	for _, system in ipairs(self._systems) do
		system:Update(self._tick, self._config)
	end
	self._tick += 1
	task.wait(self._config.Speed)
end

local Component = {}
Component.__index = Component
function Component.new<T>(name: string, data: T?): Component<T>
	return setmetatable({
		Name = name,
		Data = data and table.clone(data) or {} :: T,
		Changed = Signal.new(),
	}, Component)
end

function Component:Set(path: { any }, value: any)
	local data = self.Data
	local lastKey = table.remove(path)
	for _, key in ipairs(path) do
		if not data[key] then
			data[key] = {}
		end
		data = data[key]
	end
	if lastKey == nil then
		self.Data = value
		self.Changed:Fire(path, value)
		return
	end
	data[lastKey] = value
	path[#path + 1] = lastKey
	self.Changed:Fire(path, value)
end

function Component:Get(path: { any }): any
	local data = self.Data
	for _, key in ipairs(path) do
		data = data[key]
		if not data then
			return nil
		end
	end
	return data
end

local Entity = {}
Entity.__index = Entity

function Entity.new(reference: any): Entity
	return setmetatable({
		_components = {},
		Active = true,
		Reference = reference,
		ComponentAdded = Signal.new(),
		ComponentRemoved = Signal.new(),
	}, Entity)
end

function Entity:AddComponent<T>(component: Component<T>): Component<T>
	self._components[component.Name] = component
	self.ComponentAdded:Fire(component)
	return component
end

function Entity:RemoveComponent(name: string)
	local component = self._components[name]
	if component then
		self._components[name] = nil
		self.ComponentRemoved:Fire(component)
	end
end

function Entity:GetComponent<T>(name: string): Component<T>?
	return self._components[name]
end

function Entity:HasComponent(name: string): boolean
	return self._components[name] ~= nil
end

function Entity:SetActive(active: boolean)
	self.Active = active
end

function Entity:IsActive(): boolean
	return self.Active
end

local System = {}
System.__index = System

function System.new<T>(
	processFunc: (Entity, { [string]: Component<any> }, number, WorldConfig?) -> (),
	dependencies: { string }?
): System<T>
	return setmetatable({
		_entities = {},
		_processFunc = processFunc,
		_dependencies = dependencies or {},
	}, System)
end

function System:AddEntity(entity: Entity)
	table.insert(self._entities, { entity = entity })
end

function System:shouldAddEntity(entity: Entity): boolean
	for _, componentName in ipairs(self._dependencies) do
		if not entity:HasComponent(componentName) then
			return false
		end
	end
	return true
end

function System:RemoveEntity(entity: Entity)
	for i, pair in ipairs(self._entities) do
		if pair.entity == entity then
			table.remove(self._entities, i)
			break
		end
	end
end

function System:Update(tick: number, config: WorldConfig?)
	for _, pair in ipairs(self._entities) do
		local entity = pair.entity
		if entity:IsActive() then
			Promise.try(function()
				local components = {}
				for _, componentName in ipairs(self._dependencies) do
					components[componentName] = entity:GetComponent(componentName) :: Component<any>
				end
				return self._processFunc(entity, components, tick, config)
			end)
		end
	end
end

return {
	Component = Component,
	Entity = Entity,
	System = System,
	World = World,
}
