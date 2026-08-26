local Door = {}
Door.__index = Door

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Validator = require(script.Parent.OpenValidator).new()

function Door.new(DoorData)
    local NewDoor = {}
    setmetatable(NewDoor, Door)

    NewDoor.DoorModel = DoorData.DoorModel

    local DoorSound = Instance.new("Sound")
    DoorSound.Name = "Door_Sound"
    DoorSound.Parent = NewDoor.DoorModel
    NewDoor.DoorSound = DoorSound

    NewDoor.Opened = false
    NewDoor.Touch_Debounce = false
    NewDoor.Count = 0
    NewDoor.Debounce = false
    NewDoor.Locked = false
    NewDoor.OpenSpeed = DoorData.OpenSpeed
    NewDoor.CloseSpeed = DoorData.CloseSpeed
    NewDoor.OpenTime = DoorData.OpenTime

    local startPivot = NewDoor.DoorModel:GetPivot()
    NewDoor.startPivot = startPivot
    
    local targetPivot;
    local DoorRotation = DoorData.DoorRotation
    if DoorData.DoorSide then
        if DoorRotation == "Clockwise" then
            local angle = (DoorData.DoorSide == "L") and -90 or 90
            targetPivot = startPivot * CFrame.Angles(0, math.rad(angle), 0)
        else
            local angle = (DoorData.DoorSide == "L") and 90 or -90
            targetPivot = startPivot * CFrame.Angles(0, math.rad(angle), 0)
        end
    else   
        if DoorRotation == "Anticlockwise" then
            targetPivot = startPivot * CFrame.Angles(0, math.rad(90), 0)
        else
            targetPivot = startPivot * CFrame.Angles(0, math.rad(-90), 0)
        end
    end

    NewDoor.targetPivot = targetPivot

    NewDoor.DoorData = DoorData

    if DoorData.DetectorType == "DragDetector" then
        local DragDetector = Instance.new("DragDetector")
        DragDetector.DragStyle = Enum.DragDetectorDragStyle.Scriptable
        DragDetector.MaxActivationDistance = DoorData.MaxActivationDistance
        DragDetector.Parent = NewDoor.DoorModel
        NewDoor.Detector = DragDetector
    elseif DoorData.DetectorType == "ClickDetector" then
        local ClickDetector = Instance.new("ClickDetector")
        ClickDetector.MaxActivationDistance = DoorData.MaxActivationDistance
        ClickDetector.Parent = NewDoor.DoorModel
        NewDoor.Detector = ClickDetector
    end
    
    return NewDoor
end

function Door:PlaySound()

end

function Door:Open()
    local AnimationAPI : RemoteEvent = ReplicatedStorage:FindFirstChild("MSDv2_AnimationAPI")

    if not AnimationAPI then warn("Animation API not found!"); return end

    if self.Debounce or self.Opened then return end

    self.Debounce = true

    AnimationAPI:FireAllClients({
        Animation = "Opening",
        DoorModel = self.DoorModel,
        StartPivot = self.startPivot,
        TargetPivot = self.targetPivot,
        AnimationSpeed = self.OpenSpeed
    })

    task.wait(self.OpenSpeed)

    self.Opened = true
    self.DoorModel:PivotTo(self.targetPivot)
    self.Debounce = false
end

function Door:Close()
    local AnimationAPI : RemoteEvent = ReplicatedStorage:FindFirstChild("MSDv2_AnimationAPI")

    if not AnimationAPI then warn("Animation API not found!"); return end

    if self.Debounce or (not self.Opened) then return end

    self.Debounce = true

    AnimationAPI:FireAllClients({
        Animation = "Closing",
        DoorModel = self.DoorModel,
        StartPivot = self.startPivot,
        TargetPivot = self.targetPivot,
        AnimationSpeed = self.CloseSpeed
    })

    task.wait(self.CloseSpeed)
    
    self.Opened = false
    self.DoorModel:PivotTo(self.startPivot)
    self.Debounce = false
end

function Door:Toggle()
    if Validator:Validate({DoorModel = self.DoorModel, Nitwit = false}) and self.Locked == false then
        if self.Opened == true then
            if self.DoorData.CloseWhileOpen == true then
                self.Count = math.huge
            end
            return
        end
        
        self:Open()

        self.Count = 0
        while self.Count < self.OpenTime do
            self.Count += 0.01
            task.wait(0.01) 
        end
        
        self:Close()
    end
end

function Door:SetLocked(NewLocked : boolean)
    self.Locked = NewLocked
end

return Door