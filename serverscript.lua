-- Script by qwery, qwery96 | Discord, DarkOfOBCIvan | Roblox    


-- Simplified Combination Lock System
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")
-- Create a RemoteEvent for client-server communication
local LockRemoteEvent = Instance.new("RemoteEvent")
LockRemoteEvent.Name = "LockRemoteEvent"
LockRemoteEvent.Parent = ReplicatedStorage

-- Constants
local NUMBER_COUNT = 10
local ROTATION_DURATION = 0.3 -- Duration of rotation animation in seconds

-- Find all locks in the workspace
local function FindLocks()
	local locks = {}
	for _, model in pairs(workspace:GetDescendants()) do
		if model:IsA("Model") and 
			model:FindFirstChild("Lock") and
			model:FindFirstChild("Dial1") and
			model:FindFirstChild("Dial2") and
			model:FindFirstChild("Dial3") and
			model:FindFirstChild("CameraPosition") and
			model:FindFirstChild("LockCombination") then
			table.insert(locks, model)
			print("Found lock:", model.Name)
		end
	end
	return locks
end

-- Setup a lock
local function SetupLock(lockModel)
	print("Setting up lock:", lockModel.Name)

	-- Get lock components
	local lock = lockModel:FindFirstChild("Lock")
	local dial1 = lockModel:FindFirstChild("Dial1")
	local dial2 = lockModel:FindFirstChild("Dial2")
	local dial3 = lockModel:FindFirstChild("Dial3")
	local combination = lockModel:FindFirstChild("LockCombination").Value

	-- Setup dials
	SetupDial(dial1, lockModel, 1)
	SetupDial(dial2, lockModel, 2)
	SetupDial(dial3, lockModel, 3)

	-- Add proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Inspect Lock"
	prompt.ObjectText = "Combination Lock"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 6
	prompt.Parent = lock

	-- Connect proximity prompt
	prompt.Triggered:Connect(function(player)
		LockRemoteEvent:FireClient(player, "ZoomCamera", lockModel)
	end)

	-- Store current combination
	lockModel:SetAttribute("Dial1Value", 0)
	lockModel:SetAttribute("Dial2Value", 0)
	lockModel:SetAttribute("Dial3Value", 0)

	-- Store rotation states to prevent multiple rotations at once
	lockModel:SetAttribute("Dial1Rotating", false)
	lockModel:SetAttribute("Dial2Rotating", false)
	lockModel:SetAttribute("Dial3Rotating", false)

	print("Lock setup complete for:", lockModel.Name)
	print("Correct combination:", combination)
end

-- Setup a dial
function SetupDial(dial, lockModel, dialIndex)
	-- Find the actual part to rotate
	local targetPart = dial
	if dial:IsA("Model") then
		-- Try to find a part inside the model
		for _, child in pairs(dial:GetDescendants()) do
			if child:IsA("BasePart") then
				targetPart = child
				break
			end
		end
	end

	-- Add a click detector
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 10
	clickDetector.Parent = targetPart

	-- Connect click event
	clickDetector.MouseClick:Connect(function(player)
		RotateDial(targetPart, lockModel, dialIndex, player)
	end)

	print("Dial", dialIndex, "setup complete")
end

-- Rotate a dial
function RotateDial(targetPart, lockModel, dialIndex, player)
	-- Check if dial is already rotating
	local rotatingAttr = "Dial" .. dialIndex .. "Rotating"
	if lockModel:GetAttribute(rotatingAttr) then
		return -- Dial is already rotating, ignore this click
	end

	-- Set rotating state to true
	lockModel:SetAttribute(rotatingAttr, true)

	-- Get current value
	local currentValue = lockModel:GetAttribute("Dial" .. dialIndex .. "Value")

	-- Update to next value (inverted order: 0-9-8-7...)
	local newValue = (currentValue - 1) % NUMBER_COUNT
	if newValue < 0 then newValue = newValue + NUMBER_COUNT end

	-- Store the new value
	lockModel:SetAttribute("Dial" .. dialIndex .. "Value", newValue)

	-- Create tween for smooth rotation
	local currentOrientation = targetPart.Orientation
	local newRotation = currentOrientation.Y - 36 -- 36 degrees per number (counterclockwise)

	local tweenInfo = TweenInfo.new(
		ROTATION_DURATION,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local goal = {
		Orientation = Vector3.new(currentOrientation.X, newRotation, currentOrientation.Z)
	}

	local tween = tweenService:Create(targetPart, tweenInfo, goal)

	-- Play the tween
	tween:Play()

	-- Add optional click sound for feedback
	local clickSound = Instance.new("Sound")
	clickSound.SoundId = "rbxassetid://255881176" -- Simple click sound, replace with preferred sound ID
	clickSound.Volume = 0.5
	clickSound.Parent = targetPart
	clickSound:Play()
	game.Debris:AddItem(clickSound, 1)

	-- Calculate the displayed number (which is the reverse of the internal tracking number)
	-- For a 0-9 dial where internal 0 shows as 0, internal 9 shows as 1, internal 8 shows as 2, etc.
	local displayedNumber = (10 - newValue) % 10

	-- Debug output
	print("Dial", dialIndex, "rotating to value", newValue, "displaying", displayedNumber)

	-- Wait for tween to complete before checking combination
	tween.Completed:Connect(function()
		-- Reset rotating state
		lockModel:SetAttribute(rotatingAttr, false)

		-- Check combination after rotation completes
		CheckCombination(lockModel, player)
	end)
end

-- Check if the combination is correct
function CheckCombination(lockModel, player)
	-- Get current internal values
	local value1 = lockModel:GetAttribute("Dial1Value")
	local value2 = lockModel:GetAttribute("Dial2Value")
	local value3 = lockModel:GetAttribute("Dial3Value")

	-- Convert to displayed values
	local displayed1 = (10 - value1) % 10
	local displayed2 = (10 - value2) % 10
	local displayed3 = (10 - value3) % 10

	-- Get correct combination
	local correctCombination = lockModel.LockCombination.Value

	-- Convert to strings for comparison
	local enteredCombination = tostring(displayed1) .. tostring(displayed2) .. tostring(displayed3)

	-- Debug output
	print("Lock:", lockModel.Name)
	print("Internal values:", value1, value2, value3)
	print("Displayed values:", displayed1, displayed2, displayed3)
	print("Entered (displayed):", enteredCombination)
	print("Correct:", correctCombination)

	-- Check if correct
	if enteredCombination == correctCombination then
		print("COMBINATION CORRECT!")
		UnlockLock(lockModel, player)
	else
		print("Combination incorrect")
	end
end

-- Unlock the lock
function UnlockLock(lockModel, player)
	print("UNLOCKING LOCK:", lockModel.Name)

	-- Visual feedback - change lock color to green
	local lock = lockModel.Lock
	lock.BrickColor = BrickColor.new("Lime green")
	local bar = lockModel:FindFirstChild("Bar")
	local unlockSound = Instance.new("Sound")
	unlockSound.SoundId = "rbxassetid://7163763387"
	unlockSound.Volume = 1
	unlockSound.Parent = lockModel

	local tweenInfo = TweenInfo.new(
		2, -- Duration (in seconds)
		Enum.EasingStyle.Quad, -- Smoothness style
		Enum.EasingDirection.Out -- Ease out effect
	)

	-- Offset calculation
	local offset = Vector3.new(0, 3.5, 0)

	-- New target position (current position + offset)
	local targetPosition = bar.Position + offset

	local goal = { Position = targetPosition } -- Apply the offset
	local tween = tweenService:Create(bar, tweenInfo, goal)
	tween:Play()
	unlockSound:Play()

	-- Tell client to play effects
	LockRemoteEvent:FireClient(player, "UnlockLock", lockModel)

	-- Wait for animation
	wait(2)

	-- Fire any unlock event
	local unlockEvent = lockModel:FindFirstChild("UnlockEvent")
	if unlockEvent and unlockEvent:IsA("BindableEvent") then
		unlockEvent:Fire()
	end

	-- Move the lock to ReplicatedStorage (effectively removing it)
	print("Removing lock from workspace")
	lockModel.Parent = nil

	print("Lock successfully unlocked!")
end

-- Setup all locks
local locks = FindLocks()
for _, lock in pairs(locks) do
	SetupLock(lock)
end