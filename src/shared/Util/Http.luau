--!strict

local HttpService = game:GetService("HttpService")

local function isAllowedType(valueType)
	return valueType == "bool"
		or valueType == "int"
		or valueType == "int64"
		or valueType == "float"
		or valueType == "double"
		or valueType == "string"
		or valueType:match("^Class:")
end

local function hasAllowedTags(tags)
	return #tags == 0 or (#tags == 1 and tags[1] == "readonly")
end

local apiData = game:GetService("RunService"):IsServer()
	and HttpService:JSONDecode(HttpService:GetAsync("https://anaminus.github.io/rbx/json/api/latest.json"))

local function getInstanceProperties(className)
	local properties = {}

	for _, class in ipairs(apiData) do
		if class.type == "Class" and class.Name == className then
			for _, member in ipairs(apiData) do
				if
					member.Class == className
					and member.type == "Property"
					and isAllowedType(member.ValueType)
					and hasAllowedTags(member.tags)
				then
					table.insert(properties, {
						Name = member.Name,
						ValueType = member.ValueType,
						Tags = member.tags,
					})
				end
			end

			if class.Superclass then
				local inheritedProperties = getInstanceProperties(class.Superclass)
				for _, inheritedProperty in ipairs(inheritedProperties) do
					table.insert(properties, inheritedProperty)
				end
			end

			break
		end
	end

	return properties
end

local serializedInstances = {}

local function serializeData(data: any): any
	if typeof(data) == "Instance" then
		if serializedInstances[data] then
			return { __cyclic = true }
		end

		local serializedInstance = {}
		serializedInstances[data] = serializedInstance

		for _, property in ipairs(getInstanceProperties(data.ClassName)) do
			serializedInstance[property.Name] = serializeData((data :: any)[property.Name])
		end

		serializedInstances[data] = nil

		return serializedInstance
	elseif type(data) == "table" then
		if serializedInstances[data] then
			return { __cyclic = true }
		end

		serializedInstances[data] = true

		local serializedTable = {}
		for key, value in pairs(data) do
			serializedTable[key] = serializeData(value)
		end

		serializedInstances[data] = nil

		return serializedTable
	else
		return data
	end
end

local Http = {}
Http.getInstanceProperties = getInstanceProperties
Http.serializeData = serializeData

return Http
