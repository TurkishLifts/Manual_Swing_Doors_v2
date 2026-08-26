-- Client side of Manual_Swing_Doors V2

type DoorAnimationParams = {
    Animation: "Opening"|"Closing",
    DoorModel : Model,
    StartPivot : CFrame,
    TargetPivot: CFrame,
    AnimationSpeed: number,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationAPI: RemoteEvent = ReplicatedStorage:WaitForChild("MSDv2_AnimationAPI")

AnimationAPI.OnClientEvent:Connect(function(AnimationParams : DoorAnimationParams)
    if AnimationParams.DoorModel == nil then return end

    local Animation = AnimationParams.Animation
    local AnimationSpeed = AnimationParams.AnimationSpeed
    local DoorModel = AnimationParams.DoorModel
    local startPivot = AnimationParams.StartPivot
    local targetPivot = AnimationParams.TargetPivot

    if Animation == "Opening" then
        local t = 0
        while t < 1 do
            local dt = RunService.Heartbeat:Wait()
            t = math.min(t + dt / AnimationSpeed, 1) 
            DoorModel:PivotTo(startPivot:Lerp(targetPivot, t))
        end
    elseif Animation == "Closing" then
        local t = 0
        while t < 1 do
            local dt = RunService.Heartbeat:Wait()
            t = math.min(t + dt / AnimationSpeed, 1)
            DoorModel:PivotTo(targetPivot:Lerp(startPivot, t))
        end
    else
        warn(`Invalid animation request sent ({Animation}).`)
    end
end)