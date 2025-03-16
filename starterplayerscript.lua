local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local LockRemoteEvent = ReplicatedStorage:WaitForChild("LockRemoteEvent")
local defaultCameraSubject = nil
local defaultCameraType = nil
local isZoomedIn = false

-- Handle remote events
LockRemoteEvent.OnClientEvent:Connect(function(action, lockModel)
	if action == "ZoomCamera" then
		ZoomCameraToLock(lockModel)
	elseif action == "UnlockLock" then
		PlayUnlockAnimation(lockModel)
	end
end)

function ZoomCameraToLock(lockModel)
	-- Store current camera settings
	if not isZoomedIn then
		defaultCameraSubject = camera.CameraSubject
		defaultCameraType = camera.CameraType
	end

	local lockPart = lockModel:FindFirstChild("Lock")
	local cameraPart = lockModel:FindFirstChild("CameraPosition") -- Part for camera position

	if not lockPart or not cameraPart then return end

	-- Set camera to scriptable
	camera.CameraType = Enum.CameraType.Scriptable

	-- Position the camera at the location specified by `CameraPosition`
	local targetCFrame = CFrame.new(cameraPart.Position, lockPart.Position) -- Camera looks at the lock

	-- Smooth camera transition
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local cameraTween = TweenService:Create(camera, tweenInfo, { CFrame = targetCFrame })

	cameraTween:Play()
	isZoomedIn = true

	-- Add exit button
	ShowExitButton()
end

-- Play unlock animation
function PlayUnlockAnimation(lockModel)
	-- Simple unlock animation
	local lockPart = lockModel:FindFirstChild("Lock")
	local bar = lockModel:FindFirstChild("Bar")

	local tweenInfo = TweenInfo.new(
		2, -- Duration (in seconds)
		Enum.EasingStyle.Quad, -- Smoothness style
		Enum.EasingDirection.Out -- Ease out effect
	)

	-- Offset calculation
	local offset = Vector3.new(0, 0.099, 0)

	-- New target position (current position + offset)
	local targetPosition = bar.Position + offset

	local goal = { Position = targetPosition } -- Apply the offset
	local tween = TweenService:Create(bar, tweenInfo, goal)
	tween:Play()

	if not lockPart then return end

	-- Play unlock sound if available
	local unlockSound = lockPart:FindFirstChild("UnlockSound")
	if unlockSound and unlockSound:IsA("Sound") then
		unlockSound:Play()
	end

	-- Visual effect (could be expanded)
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.5
	highlight.FillColor = Color3.fromRGB(0, 255, 0)
	highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
	highlight.Parent = lockModel

	-- Animate the highlight
	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local highlightTween = TweenService:Create(highlight, tweenInfo, {
		FillTransparency = 1,
		OutlineTransparency = 1
	})

	highlightTween:Play()
	highlightTween.Completed:Connect(function()
		highlight:Destroy()
		ResetCamera()
	end)
end

-- Show exit button to get out of lock view
function ShowExitButton()
	-- Create UI for exit button
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LockViewGUI"

	local exitButton = Instance.new("TextButton")
	exitButton.Size = UDim2.new(0, 100, 0, 40)
	exitButton.Position = UDim2.new(0.5, -50, 0.9, 0)
	exitButton.Text = "Exit (ESC)"
	exitButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	exitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	exitButton.BorderSizePixel = 0
	exitButton.Parent = screenGui

	-- Add corner to make it look nicer
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = exitButton

	screenGui.Parent = player.PlayerGui

	-- Exit button click event
	exitButton.MouseButton1Click:Connect(function()
		ResetCamera()
		screenGui:Destroy()
	end)

	-- Also exit on ESC key
	local userInputService = game:GetService("UserInputService")
	local escConnection
	escConnection = userInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			ResetCamera()
			screenGui:Destroy()
			escConnection:Disconnect()
		end
	end)
end

-- Reset camera to default state
function ResetCamera()
	if isZoomedIn then
		-- Restore camera settings
		camera.CameraType = defaultCameraType
		camera.CameraSubject = defaultCameraSubject
		isZoomedIn = false

		-- Remove any lock view GUI
		local gui = player.PlayerGui:FindFirstChild("LockViewGUI")
		if gui then
			gui:Destroy()
		end
	end
end
