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
	if #tags == 0 then
		return true
	elseif #tags == 1 and tags[1] == "readonly" then
		return true
	else
		return false
	end
end
-- Make an HTTP request to fetch the API data
local apiData = nil

if game:GetService("RunService"):IsServer() then
	apiData = HttpService:JSONDecode(HttpService:GetAsync("https://anaminus.github.io/rbx/json/api/latest.json"))
end

local function getInstanceProperties(className)
	local properties = {}
	for _, class in ipairs(apiData) do
		if class.type == "Class" and class.Name == className and class.Name ~= "Workspace" then
			-- Found the class, now iterate through its members
			for _, member in ipairs(apiData) do
				-- Check if the member belongs to the class and is a property
				if member.Class == className and member.type == "Property" then
					-- Check if the property has an allowed type value and allowed tags
					if isAllowedType(member.ValueType) and hasAllowedTags(member.tags) then
						-- Add the property to the list
						table.insert(properties, {
							Name = member.Name,
							ValueType = member.ValueType,
							Tags = member.tags,
						})
					end
				end
			end

			-- Recursively get properties from the superclass
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
