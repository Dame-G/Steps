local ECR = require(script.Parent.Parent.Util.ECR)

local Components = {
	Player = ECR.component(function()
		return table.clone(require(script.Parent.Player))
	end),
	Character = ECR.component(function()
		return table.clone(require(script.Parent.Character))
	end),
	Item = ECR.component(function()
		return table.clone(require(script.Parent.Item))
	end),
}

return Components
