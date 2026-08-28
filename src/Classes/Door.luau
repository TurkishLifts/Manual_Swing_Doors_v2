--!nocheck
local Door = {}
Door.__index = Door

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Validator = require(script.Parent.OpenValidator).new()
local Signal = require(script.Parent.Parent.Dependencies.goodsignal)

function Door.new(DoorData)
    local NewDoor = {}
    setmetatable(NewDoor, Door)

    NewDoor.DoorModel = DoorData.DoorModel

    local DoorSound = Instance.new("Sound")
    DoorSound.Name = "Door_Sound"
    DoorSound.RollOffMaxDistance = DoorData.DoorRollOffMaxDistance or 15
    DoorSound.Volume = DoorData.DoorVolume or 1
    DoorSound.Parent = NewDoor.DoorModel
    NewDoor.DoorSound = DoorSound

    NewDoor.Opened = false
    NewDoor.Touch_Debounce = false
    NewDoor.CloseRequested = false
    NewDoor.Debounce = false
    NewDoor.Locked = false
    NewDoor.Priority = DoorData.Priority

    NewDoor.OpenSpeed = DoorData.OpenSpeed or 1
    if NewDoor.OpenSpeed <= 0 then
        NewDoor.OpenSpeed = 1
    end

    NewDoor.CloseSpeed = DoorData.CloseSpeed or 1
    if NewDoor.CloseSpeed <= 0 then
        NewDoor.CloseSpeed = 1
    end

    NewDoor.OpenTime = DoorData.OpenTime or 3
    if NewDoor.OpenTime < 0 then
        NewDoor.OpenTime = 0
    end

    NewDoor.IsOpening = Signal.new()
    
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
        DragDetector.MaxActivationDistance = DoorData.MaxActivationDistance or 10

        if DoorData.NewDragDetector == true then
            DragDetector.ActivatedCursorIcon = "rbxassetid://135040650935313"
            DragDetector.CursorIcon = "rbxassetid://84133861939386"
        end
        
        DragDetector.Parent = NewDoor.DoorModel
        NewDoor.Detector = DragDetector
    elseif DoorData.DetectorType == "ClickDetector" then
        local ClickDetector = Instance.new("ClickDetector")
        ClickDetector.MaxActivationDistance = DoorData.MaxActivationDistance or 10
        ClickDetector.Parent = NewDoor.DoorModel
        NewDoor.Detector = ClickDetector
    end
    
    return NewDoor
end

function Door:PlaySound(SoundId: number)
    if not SoundId or SoundId == 0 then return end

    if self.DoorData.DoorSoundsEnabled == false then return end

    local DoorSound : Sound = self.DoorSound
    if not DoorSound then
        local DoorSound_New = Instance.new("Sound")
        DoorSound_New.Name = "Door_Sound"
        DoorSound_New.RollOffMaxDistance = self.DoorData.DoorRollOffMaxDistance or 15
        DoorSound_New.Parent = self.DoorModel
        DoorSound_New.Volume = self.DoorData.DoorVolume or 1
        self.DoorSound = DoorSound_New
        DoorSound = DoorSound_New
    end

    if DoorSound.Playing then
        DoorSound:Stop()
    end

    DoorSound.SoundId = `rbxassetid://{SoundId}`
    DoorSound:Play()
end

function Door:Open()
    local AnimationAPI : RemoteEvent = ReplicatedStorage:FindFirstChild("MSDv2_AnimationAPI")

    if not AnimationAPI then warn("Animation API not found!"); return end

    if self.Debounce or self.Opened then return end

    self.Debounce = true

    self.IsOpening:Fire()

    AnimationAPI:FireAllClients({
        Animation = "Opening",
        DoorModel = self.DoorModel,
        StartPivot = self.startPivot,
        TargetPivot = self.targetPivot,
        AnimationSpeed = self.OpenSpeed
    })

    self:PlaySound(self.DoorData.OpenSound)
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

    self:PlaySound(self.DoorData.ClosingSound)
    task.wait(self.CloseSpeed)
    self:PlaySound(self.DoorData.ClosedSound)

    self.Opened = false
    self.DoorModel:PivotTo(self.startPivot)
    self.Debounce = false
end

function Door:Toggle(KEY : boolean)
    local success, result = pcall(function()
        return Validator:Validate({DoorModel = self.DoorModel, Nitwit = false})
    end)
    if ((success and result and self.Locked == false) or KEY) then
        if self.Opened == true then
            if self.DoorData.CloseWhileOpen == true then
                self.CloseRequested = true
            end
            return
        end

        self.CloseRequested = false      

        self:Open()

        if not self.Opened then
            return
        end

        local CloseAt = os.clock() + self.OpenTime

        while os.clock() < CloseAt and not self.CloseRequested do
            task.wait() 
        end
        
        self.CloseRequested = false
        self:Close()
    end
end

function Door:SetLocked(NewLocked : boolean)
    if self.Locked == NewLocked then return end
    self.Locked = NewLocked

    if self.Priority == "Primary" then 
        if NewLocked == true then
            self:PlaySound(self.DoorData.LockSound)
        else
            self:PlaySound(self.DoorData.UnlockSound)
        end
    end
end

return Door