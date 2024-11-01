local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Character = script.Parent
local Root = Character:WaitForChild("HumanoidRootPart") :: BasePart
local Camera = workspace.CurrentCamera
Camera.CameraSubject = Root
Camera.CameraType = Enum.CameraType.Follow

local directions = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.D] = false,
}

UserInputService.InputBegan:Connect(function(input)
	if directions[input.KeyCode] ~= nil then
		directions[input.KeyCode] = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if directions[input.KeyCode] ~= nil then
		directions[input.KeyCode] = false
	end
end)

local angularDampingFactor = 0.50
local angularDampenStrength = 15

local ballRadius = Root.Size.X / 2
local angularAcceleration = ballRadius * 10

RunService.Heartbeat:Connect(function()
	local cameraCFrame = Camera.CFrame
	local cameraLookVector = cameraCFrame.LookVector
	local cameraRightVector = cameraCFrame.RightVector

	local forwardDirection = Vector3.new(cameraLookVector.X, 0, cameraLookVector.Z).Unit
	local rightDirection = Vector3.new(cameraRightVector.X, 0, cameraRightVector.Z).Unit

	local angularImpulse = Vector3.new(0, 0, 0)
	local isMoving = false
	local velocity = Root.AssemblyLinearVelocity
	local isGrounded = math.round(velocity.Y) == 0

	if directions[Enum.KeyCode.W] then
		angularImpulse = angularImpulse - rightDirection * angularAcceleration * ballRadius
		isMoving = true
	end
	if directions[Enum.KeyCode.S] then
		angularImpulse = angularImpulse + rightDirection * angularAcceleration * ballRadius
		isMoving = true
	end
	if directions[Enum.KeyCode.A] then
		angularImpulse = angularImpulse - forwardDirection * angularAcceleration * ballRadius
		isMoving = true
	end
	if directions[Enum.KeyCode.D] then
		angularImpulse = angularImpulse + forwardDirection * angularAcceleration * ballRadius
		isMoving = true
	end

	if isMoving then
		Root:ApplyAngularImpulse(angularImpulse)
	end

	local angularVelocity = Root.AssemblyAngularVelocity
	if isGrounded then
		local angularDamping = -angularVelocity * angularDampenStrength * (1 - angularDampingFactor)
		--	Root:ApplyAngularImpulse(angularDamping)
	end
end)
