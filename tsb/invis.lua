local key = Enum.KeyCode.X -- key to toggle invisibility

game.StarterGui:SetCore("SendNotification", {
    Title = "Invisible Ready";
    Duration = 1;
    Text = "";
})

--// dont edit script below
local invis_on = false
function onKeyPress(inputObject, chat)
    if chat then return end
    if inputObject.KeyCode == key then
	    invis_on = not invis_on
    	if invis_on then
            local savedpos = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame
            wait()
            game.Players.LocalPlayer.Character:MoveTo(Vector3.new(-25.95, 84, 3537.55))
            wait(.15)
            local Seat = Instance.new('Seat', game.Workspace)
            Seat.Anchored = false
            Seat.CanCollide = false
            Seat.Name = 'invischair'
            Seat.Transparency = 1
            Seat.Position = Vector3.new(-25.95, 84, 3537.55)
            local Weld = Instance.new("Weld", Seat)
            Weld.Part0 = Seat
            Weld.Part1 = game.Players.LocalPlayer.Character:FindFirstChild("Torso") or game.Players.LocalPlayer.Character.UpperTorso
            wait()
            Seat.CFrame = savedpos
            game.StarterGui:SetCore("SendNotification", {
                Title = "Invis On";
                Duration = 1;
                Text = "";
            })
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 75
        else
            workspace:FindFirstChild('invischair'):Remove()
            game.StarterGui:SetCore("SendNotification", {
                Title = "Invis Off";
                Duration = 1;
                Text = "";
            })
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 25
        end
    end
end

local function setup(char)
    local humanoid = char:WaitForChild("Humanoid")

    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if invis_on and humanoid.WalkSpeed ~= 75 then
            humanoid.WalkSpeed = 75
        end
    end)
end

if game.Players.LocalPlayer.Character then
    setup(game.Players.LocalPlayer.Character)
end

game.Players.LocalPlayer.CharacterAdded:Connect(setup)
game:GetService("UserInputService").InputBegan:Connect(onKeyPress)
