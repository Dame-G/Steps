--!strict

--[[
    Luau Entity Component System (ECS) Module
    This module provides an implementation of the Entity Component System architecture for Roblox games.
    It includes the following classes:
    - World: Represents the game world and manages entities and systems.
    - Entity: Represents an entity in the game world, which can have multiple components.
    - Component: Represents a component that can be attached to an entity.
    - System: Represents a system that processes entities with specific components.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Util.Promise)
local Signal = require(ReplicatedStorage.Util.Signal)

export type Component<T> = {
	Name: string,
	Data: T,
	Changed: Signal.Signal<{ any }, any>,
	Set: (Component<T>, { any }, any) -> (),
	Get: (Component<T>, { any }) -> any,
}

export type Entity = {
	_components: { [string]: Component<any> },
	Active: boolean,
	Reference: any,
	ComponentAdded: Signal.Signal<Component<any>>,
	ComponentRemoved: Signal.Signal<Component<any>>,
	AddComponent: <T>(Entity, Component<T>) -> Component<T>,
	RemoveComponent: (Entity, string) -> (),
	GetComponent: <T>(Entity, string) -> Component<T>?,
	HasComponent: (Entity, string) -> boolean,
	SetActive: (Entity, boolean) -> (),
	IsActive: (Entity) -> boolean,
}

export type System<T...> = {
	_entities: { { entity: Entity } },
	_processFunc: (Entity, T...) -> (),
	_dependencies: { string }?,
	AddEntity: (System<T...>, Entity) -> (),
	shouldAddEntity: (System<T...>, Entity) -> boolean,
	RemoveEntity: (System<T...>, Entity) -> (),
	Update: (System<T...>, T...) -> (),
}

export type World = {
	_entities: { Entity },
	_systems: { System<any> },
	AddEntity: (World, Entity) -> (),
	RemoveEntity: (World, Entity) -> (),
	GetEntity: (World, (Entity) -> boolean) -> Entity?,
	AddSystem: <T...>(World, System<T...>, { string }?) -> (),
	Update: <T...>(World, T...) -> (),
}

local World = {}
World.__index = World

function World.new(): World
	return setmetatable({ _entities = {}, _systems = {} }, World)
end

function World:AddEntity(entity: Entity)
	table.insert(self._entities, entity)
	for _, system in ipairs(self._systems) do
		for _, component in pairs(entity._components) do
			system:AddEntity(entity, component)
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

function World:Update(dt: number)
	for _, system in ipairs(self._systems) do
		system:Update(dt)
	end
end

local Component = {}
Component.__index = Component
function Component.new<T>(name: string, data: T?): Component<T>
	return setmetatable({
		Name = name,
		Data = data or {} :: T,
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
	local newComponent = Component.new(component.Name, table.clone(component.Data))
	self._components[newComponent.Name] = newComponent
	self.ComponentAdded:Fire(newComponent)
	return newComponent
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

function System.new<T>(processFunc: (Entity, number) -> (), dependencies: { string }?): System<T>
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

function System:Update(dt: number)
	for _, pair in ipairs(self._entities) do
		local entity = pair.entity
		if entity:IsActive() then
			Promise.try(function()
				return self._processFunc(entity, dt)
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
