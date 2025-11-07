local Library = loadstring(game:HttpGet("https://pastebin.com/raw/uuBp7PHm"))()
local colors = {
	SchemeColor = Color3.fromRGB(197, 55, 55),
	Background = Color3.fromRGB(25, 25, 25),
	Header = Color3.fromRGB(20, 20, 20),
	TextColor = Color3.fromRGB(230, 230, 230),
	ElementColor = Color3.fromRGB(45, 45, 45),
}

local Window = Library.CreateLib("King Crimson - CW", colors)

-- Services
local players = game:GetService("Players")
local soundservice = game:GetService("SoundService")

local client = players.LocalPlayer

-- Auto Parry
local autoParryEnabled = false
local autoParryChance = 100
local autoParryPanic = false
local autoParryPanicHealth = 50

-- Time Erasure
local timeEraseEnabled = false
local autoEraseEnabled = true
local panicTimeErase = false
local panicTimeEraseHealth = 30
local panicEraseCoolDown = 5
local offset = 1100
local invisible = game.Players.LocalPlayer
local soundservice = game:GetService("SoundService")
local grips = {}
local heldTool
local gripChanged
local handle
local weld
local lastTool
local charCon, bpCon
local duration = 2.3
local canTimeErase = true

-- Other
local antiRagdoll = false
local instantSelfRevive = false
local antiFallDamage = false
local infiniteStamina = false
local hitboxExtender = false
local antiParry = false

-- Instant Self Revive + Anti Ragdoll
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RagdollHandler = require(ReplicatedStorage.Shared.Source.Ragdoll.RagdollHandler)
local DataHandler = require(ReplicatedStorage.Shared.Source.Data.DataHandler)
local Maid = require(game.ReplicatedStorage.Shared.Vendor.Maid)
local ParryConstants = require(game.ReplicatedStorage.Shared.Source.Parry.ParryConstants)
local ParryHandler = require(game.ReplicatedStorage.Shared.Source.Parry.ParryHandler)
local ParryActionsClient = require(game.ReplicatedStorage.Client.Source.Parry.ParryActionsClient)
local FinishActionsClient = require(game.ReplicatedStorage.Client.Source.Finish.FinishActionsClient)
local GloryKillHandlerClient = require(game.ReplicatedStorage.Client.Source.GloryKill.GloryKillHandlerClient)
local DataHandler = require(game.ReplicatedStorage.Shared.Source.Data.DataHandler)
local Network = require(ReplicatedStorage.Shared.Vendor.Network)
local SelfReviveHandler = require(ReplicatedStorage.Shared.Source.SelfRevive.SelfReviveHandler)
local ReduxStore = require(ReplicatedStorage.Shared.Source.Rodux.RoduxStore)
local sessionStore = DataHandler.getSessionDataRoduxStoreForPlayer(client)
local WalkSpeedHandler = require(ReplicatedStorage.Client.Source.Movement.WalkSpeedHandlerClient)
local wsContainer = WalkSpeedHandler.getValueContainer()
local ds = require(game.ReplicatedStorage.Client.Source.DefaultStamina.DefaultStaminaHandlerClient).getDefaultStamina()

local RunService = game:GetService("RunService")

local movementBoostConnection -- stores the RenderStepped connection
local movementBoostEnabled = false
local movementBoostMultiplier = 1 -- tweakable multiplier for movement speed

---------------------------------------------------------------------------------------------------------

local weaponNames = {
	"Dragon Slayer",
	"Dragon Slayer (Old)",
	"Sea Beast",
	"Anchor",
	"Spear",
}

local weaponDistance = { -- Extra distance for long ranged weapons
	["Dragon Slayer"] = 5,
	["Dragon Slayer (Old)"] = 5,
	["Sea Beast"] = 6,
	["Anchor"] = 4,
	["Spear"] = 3.5,
}

local attackAnimIds = { -- All dashes/slides that allows hitting with extra range
	["rbxassetid://4611813691"] = true,
	["rbxassetid://7479225627"] = true,
	["rbxassetid://4639820070"] = true,
	["rbxassetid://4639819520"] = true,
}

local function setDisplayDistance(distance)
	for _, player in pairs(game.Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChildWhichIsA("Humanoid") then
			local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
			humanoid.NameDisplayDistance = distance
			humanoid.HealthDisplayDistance = distance
		end
	end
end

local tool = Instance.new("Tool")
tool.Name = "Initialise Time Erase"
tool.RequiresHandle = false
tool.CanBeDropped = false

local toolCloneLoaded = Instance.new("BoolValue")
toolCloneLoaded.Name = "ToolCloneLoaded"
toolCloneLoaded.Value = false
toolCloneLoaded.Parent = tool

local toolCloneServerClassLoaded = Instance.new("BoolValue")
toolCloneServerClassLoaded.Name = "ToolCloneServerClassLoaded"
toolCloneServerClassLoaded.Value = false
toolCloneServerClassLoaded.Parent = tool

local activationId = 0

local function EnableMovementBoost(humanoid, hrp)
	if movementBoostConnection then
		movementBoostConnection:Disconnect()
	end

	movementBoostEnabled = true

	movementBoostConnection = RunService.RenderStepped:Connect(function(dt)
		if not movementBoostEnabled then
			return
		end
		if not hrp or not humanoid or humanoid:GetAttribute("IsRagdolledClient") then
			return
		end

		local moveDir = humanoid.MoveDirection
		if moveDir.Magnitude == 0 then
			return
		end

		moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
		if moveDir.Magnitude < 1e-3 then
			return
		end
		moveDir = moveDir.Unit

		local vel = hrp.AssemblyLinearVelocity
		local flatVel = Vector3.new(vel.X, 0, vel.Z)
		if flatVel.Magnitude < 1 then
			return
		end

		local alignment = moveDir:Dot(flatVel.Unit)
		if alignment > 0.3 then
			local push = moveDir * 0.45 * movementBoostMultiplier * dt * 60
			local newPos = hrp.Position + Vector3.new(push.X, 0, push.Z)
			hrp.CFrame = CFrame.new(newPos, newPos + hrp.CFrame.LookVector)
		end
	end)
end

local function DisableMovementBoost()
	movementBoostEnabled = false
	if movementBoostConnection then
		movementBoostConnection:Disconnect()
		movementBoostConnection = nil
	end
end

local hipHeightCon

local function Disable(manual)
	manual = manual or true
	invisible = false
	tool.Name = "Disabled Time Erase"

	if handle then
		handle:Destroy()
	end
	if weld then
		weld:Destroy()
	end

	for _, child in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
		if child:IsA("Tool") and child.Name == "Disabled Time Erase" then
			child.Parent = game.Players.LocalPlayer.Backpack
		end
	end

	for toolItem, grip in pairs(grips) do
		if toolItem then
			toolItem.Grip = grip
		end
	end

	heldTool = nil
	setDisplayDistance(100)
	DisableMovementBoost()

	local player = game.Players.LocalPlayer
	local humanoid = player.Character.Humanoid
	local hrp = player.Character.HumanoidRootPart

	workspace.CurrentCamera.CameraSubject = humanoid
	hrp.CFrame = hrp.CFrame * CFrame.new(0, -offset, 0)

	local vel = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	hrp.AssemblyAngularVelocity = Vector3.zero

	humanoid.HipHeight = 0
	humanoid:ChangeState(Enum.HumanoidStateType.Running)

	local soundeffect = Instance.new("Sound", soundservice)
	soundeffect.SoundId = "rbxassetid://3373991228"
	soundeffect.PlayOnRemove = true
	soundeffect.Volume = 2
	soundeffect:Destroy()

	if hipHeightCon then
		hipHeightCon:Disconnect()
	end
end

tool.Equipped:Connect(function()
	if not canTimeErase then
		tool.Parent = client.Backpack
		return
	end

	--startNoclipFor0_1s(client, "HumanoidRootPart")
	task.spawn(function()
		RunService.RenderStepped:Wait()
		tool.Parent = client.Backpack
		if lastTool then
			client.Character.Humanoid:EquipTool(lastTool)
		end
	end)

	task.wait()

	if not invisible then
		local humanoid = client.Character.Humanoid

		invisible = true
		tool.Name = "Enabled Time Erase"

		if handle then
			handle:Destroy()
		end
		if weld then
			weld:Destroy()
		end
		local hrp = client.Character.HumanoidRootPart

		handle = Instance.new("Part", workspace)
		handle.Name = "Handle"
		handle.Transparency = 1
		handle.CanCollide = false
		handle.Size = Vector3.new(2, 1, 1)

		weld = Instance.new("Weld", handle)
		weld.Part0 = handle
		weld.Part1 = client.Character.HumanoidRootPart
		weld.C0 = CFrame.new(0, offset - 1.5, 0)

		setDisplayDistance(offset + 100)

		workspace.CurrentCamera.CameraSubject = handle

		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.zero

		local pos = hrp.Position + Vector3.new(0, offset, 0)
		hrp.CFrame = CFrame.new(pos)

		humanoid.HipHeight = offset

		hipHeightCon = humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
			if invisible and humanoid.HipHeight ~= offset then
				humanoid.HipHeight = offset
			end
		end)

		humanoid:ChangeState(11)

		EnableMovementBoost(humanoid, hrp)

		for _, child in pairs(game.Players.LocalPlayer.Backpack:GetChildren()) do
			if child:IsA("Tool") and child ~= tool then
				grips[child] = child.Grip
			end
		end

		local soundeffect = Instance.new("Sound", soundservice)
		soundeffect.SoundId = "rbxassetid://8036843509"
		soundeffect.PlayOnRemove = true
		soundeffect.Volume = 2
		soundeffect:Destroy()

		activationId += 1
		local currentId = activationId

		task.spawn(function()
			local start = tick()
			while tick() - start < duration do
				if currentId ~= activationId then
					return
				end
				task.wait()
			end

			if currentId == activationId and invisible then
				Disable(false)
			end
		end)
	else
		Disable()
		activationId += 1
	end
end)

client.Character.ChildAdded:Connect(function(child)
	wait()

	if invisible and child:IsA("Tool") and child ~= heldTool and child ~= tool then
		heldTool = child
		local lastGrip = heldTool.Grip

		if not grips[heldTool] then
			grips[heldTool] = lastGrip
		end

		local humanoid = client.Character.Humanoid
		for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
			track:Stop()
		end

		game.Players.LocalPlayer.Character.Animate.Disabled = true

		heldTool.Grip = heldTool.Grip * (CFrame.new(0, offset - 1.5, 1.5) * CFrame.Angles(math.rad(-90), 0, 0))
		heldTool.Parent = game.Players.LocalPlayer.Backpack
		heldTool.Parent = game.Players.LocalPlayer.Character

		if gripChanged then
			gripChanged:Disconnect()
		end

		gripChanged = heldTool:GetPropertyChangedSignal("Grip"):Connect(function()
			task.wait()

			if not invisible then
				gripChanged:Disconnect()
				return
			end

			if heldTool.Grip ~= lastGrip then
				lastGrip = heldTool.Grip * (CFrame.new(0, offset - 1.5, 1.5) * CFrame.Angles(math.rad(-90), 0, 0))
				heldTool.Grip = lastGrip
				heldTool.Parent = game.Players.LocalPlayer.Backpack
				heldTool.Parent = game.Players.LocalPlayer.Character
			end
		end)
	end
end)

local function trackTools(character)
	if charCon then
		charCon:Disconnect()
	end
	if bpCon then
		bpCon:Disconnect()
	end

	charCon = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child ~= tool then
			lastTool = child
		end
	end)

	bpCon = character.ChildRemoved:Connect(function(child)
		if child == lastTool then
			task.wait(0.25)
			if not character:FindFirstChild(child.Name) then
				lastTool = nil
			end
		end
	end)
end

client.CharacterAdded:Connect(trackTools)
if client.Character then
	trackTools(client.Character)
end

local activeConnections = {}

local function applyHead(head)
	if not head or not head:IsA("BasePart") then
		return
	end
	head.Size = Vector3.new(11, 11, 11)
	head.CanCollide = false
	head.Massless = true
	head.LocalTransparencyModifier = 1
	head.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0, 0, 0, 0)

	if activeConnections[head] then
		activeConnections[head]:Disconnect()
		activeConnections[head] = nil
	end

	activeConnections[head] = head:GetPropertyChangedSignal("CanCollide"):Connect(function()
		if head and head.CanCollide then
			head.CanCollide = false
			head.Massless = true
			head.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0, 0, 0, 0)
		end
	end)

	head.Destroying:Connect(function()
		if activeConnections[head] then
			activeConnections[head]:Disconnect()
			activeConnections[head] = nil
		end
	end)
end

local function modifyCharacterAppearance(character)
	if not hitboxExtender then
		return
	end
	if not character or character == client.Character then
		return
	end

	local head = character:FindFirstChild("Head")
	if head then
		applyHead(head)
	end

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Accessory") then
			local handle = desc:FindFirstChild("Handle")
			if handle then
				handle.LocalTransparencyModifier = 1
				handle.CanCollide = false
			end
		elseif desc:IsA("Decal") and desc.Parent and desc.Parent.Name == "Head" then
			desc.Transparency = 1
		end
	end

	character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") and desc.Name == "Head" then
			applyHead(desc)
		elseif desc:IsA("Accessory") then
			local handle = desc:FindFirstChild("Handle")
			if handle then
				handle.LocalTransparencyModifier = 1
				handle.CanCollide = false
			end
		elseif desc:IsA("Decal") and desc.Parent and desc.Parent.Name == "Head" then
			desc.Transparency = 1
		end
	end)
end

local function revertCharacterAppearance(character)
	if not character or character == client.Character then
		return
	end

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		head.Size = Vector3.new(2, 1, 1)
		head.CanCollide = true
		head.LocalTransparencyModifier = 0
		head.Massless = false

		if activeConnections[head] then
			activeConnections[head]:Disconnect()
			activeConnections[head] = nil
		end
	end

	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("Accessory") then
			local handle = desc:FindFirstChild("Handle")
			if handle then
				handle.LocalTransparencyModifier = 0
				handle.CanCollide = true
			end
		elseif desc:IsA("Decal") and desc.Parent and desc.Parent.Name == "Head" then
			desc.Transparency = 0
		end
	end
end

local function isAttackAnimation(track)
	return track.Animation and attackAnimIds[track.Animation.AnimationId]
end

local function getEquippedWeaponDistance(character)
	if not character then
		return nil
	end
	for _, item in pairs(character:GetChildren()) do
		if item:IsA("Tool") then
			for _, weaponName in ipairs(weaponNames) do
				if item.Name == weaponName then
					return weaponDistance[weaponName]
				end
			end
		end
	end
	return 0
end

local function getRootAndVel(character)
	if not (character and character.PrimaryPart) then
		return nil
	end
	local root = character.PrimaryPart
	local vel = root.AssemblyLinearVelocity or root.Velocity
	return root, vel or Vector3.zero
end

local function IsMovingTowardsMe(targetCharacter, localPlayer, minSpeed)
	local targetRoot, targetVel = getRootAndVel(targetCharacter)
	if not targetRoot then
		return false
	end
	local myChar = localPlayer.Character
	if not (myChar and myChar.PrimaryPart) then
		return false
	end
	local myRoot = myChar.PrimaryPart
	local myVel = myRoot.AssemblyLinearVelocity or myRoot.Velocity or Vector3.zero
	local toMe = (myRoot.Position - targetRoot.Position)
	local distSq = toMe:Dot(toMe)
	if distSq == 0 then
		return false
	end
	toMe = toMe.Unit
	local relVel = targetVel - myVel
	local closingSpeed = relVel:Dot(toMe)
	return closingSpeed >= (minSpeed or 4)
end

local function IsLookingAtMe(targetCharacter, localPlayer, maxAngle)
	if
		not (
			targetCharacter
			and localPlayer
			and targetCharacter.PrimaryPart
			and localPlayer.Character
			and localPlayer.Character.PrimaryPart
		)
	then
		return false
	end
	local targetRoot = targetCharacter.PrimaryPart
	local myRoot = localPlayer.Character.PrimaryPart
	local forward = targetRoot.CFrame.LookVector
	local toMe = (myRoot.Position - targetRoot.Position).Unit
	local dot = forward:Dot(toMe)
	local angle = math.deg(math.acos(dot))
	return angle <= (maxAngle or 30)
end

local function withinRange(a, b, maxDist)
	return (a.Position - b.Position).Magnitude <= maxDist
end

local function getParryCooldownPercentageFraction(startTime, afterSuccess)
	if not startTime then
		return 0
	end

	local elapsed = tick() - startTime
	local cooldownDuration = afterSuccess and 0 or ParryConstants.PARRY_COOLDOWN_IN_SECONDS

	if cooldownDuration == 0 then
		return 1
	end

	return elapsed / cooldownDuration
end

local function SimulateParry(tool)
	task.wait(math.random(0.05, 0.1))

	local state = sessionStore:getState()

	if not state.meleeClient.canMeleeFromCount then
		return
	end

	local lastParryFalseTick = state.parryClient.lastIsParryingFalseTick
	if getParryCooldownPercentageFraction(lastParryFalseTick, state.parry.lastParrySucceeded) < 1 then
		return
	end
	if state.stunClient.isStunned then
		return
	end

	local maid = Maid.new()
	local parryDuration = workspace:GetAttribute("parryDuration") or ParryConstants.PARRY_DURATION_IN_SECONDS
	task.delay(parryDuration, function()
		maid:Destroy()
	end)

	ParryHandler.handleParryMaid(maid, client, tool)

	sessionStore:dispatch(FinishActionsClient.cancelIsFinishing())
	GloryKillHandlerClient.cancelCurrentGking()

	sessionStore:dispatch(ParryActionsClient.changeIsParrying(true))
	Network:FireServer("Parry")

	maid:GiveTask(function()
		sessionStore:dispatch(ParryActionsClient.changeIsParrying(false))
		Network:FireServer("CancelParry")
	end)
end

local function AutoParry(child, chr)
	local clientChar = client.Character
	local currentTool = clientChar:FindFirstChildOfClass("Tool")
	local tool = chr:FindFirstChildOfClass("Tool")

	if currentTool and currentTool:FindFirstChild("ClientAmmo") then
		return
	end

	if not child:IsA("Sound") then
		return
	end

	local isRunning = false
	if IsMovingTowardsMe(chr, client, 17) then
		isRunning = true
	end

	local extraDistance = 0
	if getEquippedWeaponDistance(chr) ~= 0 then
		extraDistance = getEquippedWeaponDistance(chr)
	end

	local baseRange = (not IsLookingAtMe(chr, client, 150) and not IsMovingTowardsMe(chr, client, 5)) and 8 or 14.25
	local range = isRunning and (baseRange + 4) or baseRange

	if
		not withinRange(chr.HumanoidRootPart, client.Character.HumanoidRootPart, range + extraDistance)
		and withinRange(chr.HumanoidRootPart, client.Character.HumanoidRootPart, 25 + extraDistance)
		and IsMovingTowardsMe(chr, client, 3)
	then
		for _, track in ipairs(chr.Humanoid.Animator:GetPlayingAnimationTracks()) do
			if isAttackAnimation(track) then
				SimulateParry(currentTool)
			end
		end
	else
		if not withinRange(chr.HumanoidRootPart, client.Character.HumanoidRootPart, range + extraDistance) then
			return
		end

		if not tool or not currentTool then
			return
		end

		SimulateParry(currentTool)
	end
end

local function findSeaBeastParent(tool)
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant.Name == "SamehadaSpine.003" then
			return descendant
		end
	end
	return nil
end

local function AntiParry(chr)
	if not antiParry then
		return
	end
	if not client.Character:FindFirstChildOfClass("Tool") then
		return
	end
	if
		client.Character:FindFirstChildOfClass("Tool")
		and client.Character:FindFirstChildOfClass("Tool"):FindFirstChild("ClientAmmo")
	then
		return
	end
	if not withinRange(chr.HumanoidRootPart, client.Character.HumanoidRootPart, 30) then
		return
	end
	task.spawn(function()
		for _, v in ipairs(chr:GetChildren()) do
			if v:IsA("BasePart") then
				if v.Name == "Torso" then
					v.CanCollide = false
				end
				v.CanQuery = false
			end
		end

		task.wait(0.25)

		for _, v in ipairs(chr:GetChildren()) do
			if v:IsA("BasePart") then
				if v.Name == "Torso" then
					v.CanCollide = true
				end
				v.CanQuery = true
			end
		end
	end)
end

local hitboxConnections = {}

local function setupHitboxes(plr, tool, chr)
	if not tool or not tool:FindFirstChild("Hitboxes") then
		return
	end

	local hitbox = findSeaBeastParent(tool)
		or tool.Hitboxes:FindFirstChild("Hitbox")
		or tool.Hitboxes:FindFirstChild("Weapon1Hitbox")
		or tool.Hitboxes:FindFirstChild("RightFistHitbox")
		or tool.Hitboxes:FindFirstChild("TopHitbox")

	local leftFist
	if hitbox and hitbox.Name == "RightFistHitbox" then
		leftFist = tool.Hitboxes:FindFirstChild("LeftFistHitbox")
	end

	local weapon2HitBox
	if hitbox and hitbox.Name == "Weapon1Hitbox" then
		weapon2HitBox = tool.Hitboxes:FindFirstChild("Weapon2Hitbox")
	end

	local bottomHitbox
	if hitbox and hitbox.Name == "TopHitbox" then
		bottomHitbox = tool.Hitboxes:FindFirstChild("BottomHitbox")
	end

	hitboxConnections[chr] = {}

	local function connectHitbox(box, weaponTool)
		if not box then
			return
		end

		local plr = game:GetService("Players"):FindFirstChild(chr.Name)

		local conn = box.ChildAdded:Connect(function(child)
			if
				autoParryEnabled
				and (
					(autoParryPanic and client.Character.Humanoid.Health <= autoParryPanicHealth) and true
					or math.random(1, 100) <= tonumber(autoParryChance)
				)
			then
				task.spawn(AutoParry, child, chr)
			end
		end)

		local backpackcon = plr:FindFirstChild("Backpack").ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child ~= weaponTool and child:WaitForChild("Hitboxes", 0.2) then
				if hitboxConnections[chr] then
					for _, existingConn in ipairs(hitboxConnections[chr]) do
						existingConn:Disconnect()
					end
					hitboxConnections[chr] = {}
				end
				setupHitboxes(plr, child, chr)
			end
		end)

		table.insert(hitboxConnections[chr], conn)
		table.insert(hitboxConnections[chr], backpackcon)
	end

	connectHitbox(hitbox, tool)
	connectHitbox(leftFist, tool)
	connectHitbox(weapon2HitBox, tool)
	connectHitbox(bottomHitbox, tool)

	task.spawn(function()
		local shieldChild = chr.HumanoidRootPart:WaitForChild("Weld").Part1
		local shield = shieldChild.Parent

		if shield.Name == "None" then
			shieldChild.ChildAdded:Connect(function()
				AntiParry(chr)
			end)
		end

		shield:GetAttributeChangedSignal("Toggle"):Connect(function()
			local newValue = shield:GetAttribute("Toggle")
			if newValue then
				AntiParry(chr)
			end
		end)
	end)

	chr.AncestryChanged:Connect(function(_, parent)
		if not parent and hitboxConnections[chr] then
			for _, conn in ipairs(hitboxConnections[chr]) do
				conn:Disconnect()
			end
			hitboxConnections[chr] = nil
		end
	end)

	plr.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if hitboxConnections[chr] then
				for _, conn in ipairs(hitboxConnections[chr]) do
					conn:Disconnect()
				end
				hitboxConnections[chr] = nil
			end
		end
	end)
end

local playerRespawnConns = {}

local function Update(plr)
	if plr == client then
		return
	end

	if playerRespawnConns[plr] then
		playerRespawnConns[plr]:Disconnect()
		playerRespawnConns[plr] = nil
	end

	local function OnRespawn(chr)
		if hitboxExtender then
			modifyCharacterAppearance(chr)
		end
		local tool
		repeat
			task.wait()
			for _, item in ipairs(chr:GetChildren()) do
				if
					item:IsA("Tool")
					and item:GetAttribute("ItemType") == "weapon"
					and item:FindFirstChild("Hitboxes")
				then
					tool = item
					break
				end
			end
		until tool

		setupHitboxes(plr, tool, chr)
	end

	if plr.Character then
		task.spawn(OnRespawn, plr.Character)
	end

	local conn = plr.CharacterAdded:Connect(function(chr)
		task.spawn(OnRespawn, chr)
	end)

	playerRespawnConns[plr] = conn
end

for _, v in ipairs(players:GetPlayers()) do
	task.spawn(Update, v)
end
players.PlayerAdded:Connect(function(plr)
	task.spawn(Update, plr)
end)

game.Players.PlayerRemoving:Connect(function(plr)
	if playerRespawnConns[plr] then
		playerRespawnConns[plr]:Disconnect()
		playerRespawnConns[plr] = nil
	end
end)

local function onAnimationPlayed(track)
	local animId = track.Animation.AnimationId:match("%d+$")
	if animId == "76407687840829" and autoEraseEnabled then
		if tool and timeEraseEnabled then
			client.Character.Humanoid:UnequipTools()
			local now = os.clock()

			task.spawn(function()
				task.wait(0.1)
				repeat
					task.wait()
				until os.clock() - now > 1
				canTimeErase = true
			end)

			task.wait(0.05)

			wsContainer:removeFromZeroValueCount()
			if not invisible then
				client.Character.Humanoid:EquipTool(tool)
			end

			canTimeErase = false
		end
	end
end

local function connectCharacter()
	local humanoid = client.Character:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
	if animConn then
		animConn:Disconnect()
		animConn = nil
	end
	animConn = animator.AnimationPlayed:Connect(onAnimationPlayed)
end

if client.Character then
	connectCharacter()
end

client.CharacterAdded:Connect(function()
	task.spawn(connectCharacter)
end)

local function findBarClipper()
	for _, descendant in ipairs(client.PlayerGui:GetDescendants()) do
		if
			descendant:IsA("Frame")
			and descendant.Name == "BarClipper"
			and descendant.Parent
			and descendant.Parent.Name == "ProgressBar"
			and descendant.Parent.Parent
			and descendant.Parent.Parent.Name == "HealthBar"
		then
			return descendant
		end
	end
	return nil
end

local barClipperConnection
local lastTimeErase = 0

local function monitorHealth()
	repeat
		task.wait(0.1)
	until client.Character.HumanoidRootPart.Anchored == false
	task.wait(0.2)
	if barClipperConnection then
		barClipperConnection:Disconnect()
		barClipperConnection = nil
	end

	local character = client.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local healthBar = findBarClipper()
	if not healthBar then
		return
	end

	local lastScale = healthBar.Size.X.Scale

	barClipperConnection = healthBar:GetPropertyChangedSignal("Size"):Connect(function()
		local timeEraseCooldown = duration + panicEraseCoolDown
		local newScale = healthBar.Size.X.Scale

		if newScale ~= lastScale then
			lastScale = newScale

			local scaledPercent = math.floor(newScale * 100 + 0.5)

			if
				timeEraseEnabled
				and not invisible
				and panicTimeErase
				and scaledPercent > 0
				and scaledPercent <= panicTimeEraseHealth
				and client:FindFirstChild("Backpack")
				and client.Backpack:FindFirstChild(tool.Name)
			then
				local now = tick()
				if now - lastTimeErase >= timeEraseCooldown then
					lastTimeErase = now
					humanoid:EquipTool(tool)
				end
			end
		end
	end)
end

client.CharacterAdded:Connect(monitorHealth)
if client.Character then
	task.spawn(monitorHealth)
end

local function AntiRagdoll(char)
	local hum = client.Character:WaitForChild("Humanoid")
	sessionStore:dispatch({
		type = "RAGDOLL_CLIENT_IS_RAGDOLLED_CHANGE",
		payload = false,
	})

	RagdollHandler.toggleRagdoll(hum, false)

	Network:FireServer("ToggleRagdoll", false)

	hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	hum.PlatformStand = false

	RagdollHandler.buildRagdoll(hum)
end

local function InstantRevive()
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.05)
			SelfReviveHandler = require(ReplicatedStorage.Shared.Source.SelfRevive.SelfReviveHandler)
			SelfReviveHandler.getSelfReviveDuration = function()
				return 0
			end
			-- Re-attempt
			Network:FireServer("SelfReviveStart")
			Network:FireServer("SelfRevive")
		end
	end)
end

SelfReviveHandler.getSelfReviveDuration = function()
	return 0 -- Instant completion
end

if not ReduxStore.store then
	ReduxStore.init()
end

if client.Character then
	InstantRevive()
end

client.CharacterAdded:Connect(function()
	SelfReviveHandler.getSelfReviveDuration = function()
		return 0
	end

	if not ReduxStore.store then
		ReduxStore.init()
	end
	InstantRevive()
end)

local downed

local function SetUpWalkSpeed()
	local hum = client.Character:WaitForChild("Humanoid")

	if downed then
		downed:Disconnect()
		downed = nil
	end

	downed = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		local speedNow = hum.WalkSpeed
		if speedNow == 2 and hum.Health > 0 then
			if instantSelfRevive then
				InstantRevive()
			end

			if antiRagdoll then
				AntiRagdoll(client.Character)
			end
		end
	end)
end

client.CharacterAdded:Connect(SetUpWalkSpeed)
if client.Character then
	task.spawn(SetUpWalkSpeed)
end

local ragdollConnection

local function SetupRagdoll()
	local humanoid = client.Character:WaitForChild("Humanoid")

	if ragdollConnection then
		ragdollConnection:Disconnect()
		ragdollConnection = nil
	end

	if not humanoid:GetAttribute("IsRagdolledClient") then
		humanoid:SetAttribute("IsRagdolledClient", false)
	end

	ragdollConnection = humanoid:GetAttributeChangedSignal("IsRagdolledClient"):Connect(function()
		if humanoid:GetAttribute("IsRagdolledClient") and antiRagdoll then
			AntiRagdoll(client.Character)
		end
	end)
end

if client.Character then
	SetupRagdoll()
end

client.CharacterAdded:Connect(SetupRagdoll)

local function disableFallDamage()
	task.wait(1)

	ReduxStore.store:dispatch({
		type = "FALL_DAMAGE_DISABLED_COUNT_ADD",
	})
end

client.CharacterAdded:Connect(function()
	if antiFallDamage then
		task.spawn(disableFallDamage)
	end
end)

task.spawn(function()
	while true do
		if ds and infiniteStamina then
			ds:setStamina(ds:getMaxStamina())
		end
		task.wait(0.01)
	end
end)

---------------------------------------------------------------------------------------------------------

local MainTab = Window:NewTab("Main")
local TimeEraseTab = Window:NewTab("Time Erasure")
local OtherTab = Window:NewTab("Other")
local TimeEraseSettings = TimeEraseTab:NewSection('<font size="15"><b>Time Erasure Settings</b></font>')
local AutoParrySettings = MainTab:NewSection('<font size="15"><b>Auto Parry Settings (Epitaph)</b></font>')
local OtherSettings = OtherTab:NewSection('<font size="15"><b>Other Settings</b></font>')

AutoParrySettings:NewToggle("Enabled", "", function(state)
	autoParryEnabled = state
end)

AutoParrySettings:NewDropdown(
	"Auto Parry Chance",
	"",
	{ "0%", "25%", "50%", "75%", "90%", "100%" },
	function(currentOption)
		autoParryChance = string.match(currentOption, "%d+")
	end
)

AutoParrySettings:NewToggle("Panic", "", function(state)
	autoParryPanic = state
end)

AutoParrySettings:NewSlider("Panic Health", "", 100, 1, function(value)
	autoParryPanicHealth = value
end, 50)

TimeEraseSettings:NewToggle("Enabled", "", function(state)
	timeEraseEnabled = state
	local backpack = client:WaitForChild("Backpack")

	if state then
		if not backpack:FindFirstChild("Initialise Time Erase") then
			if client.Character.HumanoidRootPart.Anchored then
				repeat
					task.wait(0.1)
				until not client.Character.HumanoidRootPart.Anchored
			end
			task.wait(0.2)
			tool.Parent = backpack
		end

		local function onCharacterAdded(character)
			task.spawn(function()
				local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
				if not humanoidRootPart then
					return
				end

				repeat
					task.wait(0.1)
				until humanoidRootPart.Anchored == false
				task.wait(0.2)

				local backpack = client:WaitForChild("Backpack")
				if timeEraseEnabled and not backpack:FindFirstChild("Initialise Time Erase") then
					tool.Parent = backpack
				end
			end)
		end

		if client.Character then
			onCharacterAdded(client.Character)
		end
		client.CharacterAdded:Connect(onCharacterAdded)
	else
		local existing = client.Backpack:FindFirstChild("Initialise Time Erase")
		if existing then
			existing:Destroy()
		end

		if client.Character and client.Character:FindFirstChild("Initialise Time Erase") then
			client.Character["Initialise Time Erase"]:Destroy()
		end
	end
end)

local autoEraseToggle = TimeEraseSettings:NewToggle("Auto Time Erase", "", function(state)
	autoEraseEnabled = state
end)
autoEraseToggle:UpdateToggle(nil, true)

TimeEraseSettings:NewToggle("Panic Time Erase", "", function(state)
	panicTimeErase = state
end)

TimeEraseSettings:NewSlider("Panic Health", "", 100, 1, function(value)
	panicTimeEraseHealth = value
end, 30)

TimeEraseSettings:NewSlider("Panic Cooldown", "", 10, 1, function(value)
	panicEraseCoolDown = value
end, 5)

TimeEraseSettings:NewSlider("Erase Duration", "", 3, 0.1, function(value)
	duration = value
end, 2.3, 0.1)

TimeEraseSettings:NewSlider("Movement Boost", "", 2, 0.1, function(value)
	movementBoostMultiplier = value
end, 1, 0.1)

TimeEraseSettings:NewKeybind("Keybind", "", Enum.KeyCode.H, function()
	if timeEraseEnabled then
		client.Character.Humanoid:EquipTool(tool)
	end
end)

OtherSettings:NewToggle("Anti Ragdoll", "", function(state)
	antiRagdoll = state
end)

OtherSettings:NewToggle("Instant Revive", "", function(state)
	instantSelfRevive = state
end)

OtherSettings:NewToggle("Anti Fall Damage", "", function(state)
	antiFallDamage = state
	if antiFallDamage then
		task.spawn(disableFallDamage())
	end
end)

OtherSettings:NewToggle("Infinite Stamina", "", function(state)
	infiniteStamina = state
end)

OtherSettings:NewToggle("Hitbox extender", "", function(state)
	hitboxExtender = state
	if state then
		for _, player in ipairs(game.Players:GetPlayers()) do
			if player ~= client and player.Character then
				modifyCharacterAppearance(player.Character)
			end
		end
	else
		for _, player in ipairs(game.Players:GetPlayers()) do
			if player ~= client and player.Character then
				revertCharacterAppearance(player.Character)
			end
		end
	end
end)

OtherSettings:NewToggle("Anti Parry", "", function(state)
	antiParry = state
end)

-- TODO
--[[

	- Make parry more accurate
	- Bait Detection
	- Clean up + optimise code

]]
