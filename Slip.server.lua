local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local active = {}
local RagdollTime = 2
local Cooldown = 1
local TEST_BOOST = 5 -- set back to 1 when you're done testing

-- R6: build a temporary ball socket from a Motor6D's attachment frames
local function makeSocket(motor, created, noCollides)
	local p0, p1 = motor.Part0, motor.Part1
	if not p0 or not p1 then return end

	local a0 = Instance.new("Attachment")
	a0.CFrame = motor.C0
	a0.Parent = p0

	local a1 = Instance.new("Attachment")
	a1.CFrame = motor.C1
	a1.Parent = p1

	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = a0
	socket.Attachment1 = a1
	socket.LimitsEnabled = true
	socket.UpperAngle = 60
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -30
	socket.TwistUpperAngle = 30
	socket.Parent = p0

	local nc = Instance.new("NoCollisionConstraint")
	nc.Part0 = p0
	nc.Part1 = p1
	nc.Parent = p0

	table.insert(created, a0)
	table.insert(created, a1)
	table.insert(created, socket)
	table.insert(noCollides, nc)
end

script.Parent.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character or active[character] then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	active[character] = true

	task.spawn(function()
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			task.spawn(function()
				pcall(function()
					BadgeService:AwardBadgeAsync(player.UserId, 3269621971212993)
				end)
			end)
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
		local oldAutoRotate = humanoid.AutoRotate
		local oldPlatformStand = humanoid.PlatformStand
		local disabledConstraints = {} -- R15 AnimationConstraints
		local disabledMotors = {}      -- R6 Motor6Ds
		local created = {}             -- R6 temporary attachments/sockets
		local noCollides = {}
		local oldCollisions = {}

		-- grab slide direction before PlatformStand kills MoveDirection
		local pushDir = Vector3.zero
		if root then
			local v = root.AssemblyLinearVelocity
			local flat = Vector3.new(v.X, 0, v.Z)
			if flat.Magnitude > 1 then
				pushDir = flat.Unit
			elseif humanoid.MoveDirection.Magnitude > 0 then
				pushDir = humanoid.MoveDirection
			end
		end

		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") and part ~= root then
				oldCollisions[part] = part.CanCollide
				part.CanCollide = true
			end
		end

		humanoid.AutoRotate = false
		humanoid.PlatformStand = true

		for _, obj in ipairs(character:GetDescendants()) do
			if isR6 then
				if obj:IsA("Motor6D")
					and obj.Enabled
					and obj.Name ~= "Root"
					and obj.Name ~= "RootJoint" then

					makeSocket(obj, created, noCollides)
					table.insert(disabledMotors, obj)
					obj.Enabled = false
				end
			else
				if obj:IsA("AnimationConstraint")
					and obj.Enabled
					and obj.Name ~= "Root"
					and obj.Name ~= "RootJoint" then

					table.insert(disabledConstraints, obj)
					obj.Enabled = false

					local a0, a1 = obj.Attachment0, obj.Attachment1
					if a0 and a1 and a0.Parent and a1.Parent then
						local nc = Instance.new("NoCollisionConstraint")
						nc.Part0 = a0.Parent
						nc.Part1 = a1.Parent
						nc.Parent = a0.Parent
						table.insert(noCollides, nc)
					end
				end
			end
		end

		-- Humanoid keeps resetting limb collision, so force it back on every step
		local conn = RunService.Stepped:Connect(function()
			for part in pairs(oldCollisions) do
				if part.Parent and not part.CanCollide then
					part.CanCollide = true
				end
			end
		end)

		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		if root then
			local mass = root.AssemblyMass
			local speed = math.clamp(root.AssemblyLinearVelocity.Magnitude, 8, 24)

			root:ApplyImpulse(
				Vector3.new(0, mass * math.random(8, 14), 0)
				+ pushDir * mass * speed * 0.8 * TEST_BOOST
			)
		end

		task.wait(RagdollTime)

		conn:Disconnect()
		for _, nc in ipairs(noCollides) do
			nc:Destroy()
		end
		for _, inst in ipairs(created) do
			inst:Destroy()
		end
		for part, wasCollidable in pairs(oldCollisions) do
			if part.Parent then
				part.CanCollide = wasCollidable
			end
		end

		if character.Parent and humanoid.Parent and humanoid.Health > 0 then
			for _, constraint in ipairs(disabledConstraints) do
				if constraint.Parent then
					constraint.Enabled = true
				end
			end
			for _, motor in ipairs(disabledMotors) do
				if motor.Parent then
					motor.Enabled = true
				end
			end

			humanoid.PlatformStand = oldPlatformStand
			humanoid.AutoRotate = oldAutoRotate
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		task.wait(Cooldown)
		active[character] = nil
	end)
end)
