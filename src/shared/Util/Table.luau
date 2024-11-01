local Table = {}

function Table.deepCopy(original)
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for k, v in pairs(original) do
		copy[Table.deepCopy(k)] = Table.deepCopy(v)
	end
	return copy
end

function Table.deepCompare(t1, t2)
	if type(t1) ~= "table" or type(t2) ~= "table" then
		if type(t1) == "number" and type(t2) == "number" then
			return math.abs(t1 - t2) < 1e-10
		end
		return t1 == t2
	end
	for k, v in pairs(t1) do
		if not Table.deepCompare(v, t2[k]) then
			return false
		end
	end
	for k in pairs(t2) do
		if t1[k] == nil then
			return false
		end
	end
	return true
end

function Table.deepUpdate(original, updates)
	for k, v in pairs(updates) do
		if type(v) == "table" and type(original[k]) == "table" then
			Table.deepUpdate(original[k], v)
		else
			original[k] = v
		end
	end
	return original
end

function Table.getChanges(old, new)
	if type(old) ~= "table" or type(new) ~= "table" then
		if type(old) == "number" and type(new) == "number" then
			if math.abs(old - new) >= 1e-10 then
				return new
			end
		elseif old ~= new then
			return new
		end
		return nil
	end

	local changes = {}
	for k, v in pairs(new) do
		local oldValue = old[k]
		if type(v) == "table" and type(oldValue) == "table" then
			local nestedChanges = Table.getChanges(oldValue, v)
			if nestedChanges ~= nil then
				changes[k] = nestedChanges
			end
		elseif not Table.deepCompare(v, oldValue) then
			changes[k] = v
		end
	end

	for k in pairs(old) do
		if new[k] == nil then
			changes[k] = nil
		end
	end

	return next(changes) and changes or nil
end

return Table
