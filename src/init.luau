--[[
    Manual Swing Doors V2 | by: TurkishLifts

        VERSION: v2.0.0 | DATE: 26/08/2026
]]--
--!nocheck

local module = {}

function module.init(controller : {})
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Classes : Folder = script:FindFirstChild("Classes")
    local ValuesFolder : Folder = controller.ValuesFolder
    local FloorValue : NumberValue = ValuesFolder:FindFirstChild("Floor")
    local API : BindableEvent = controller.API
    local ElevatorConfig : {} = controller.Config
    
    local FloorsData = {}
    local State = {
        Stopped = false,
        idle_loop = false,
        idle_generation = 0,
        key_debounce = false
    }
    assert(Classes,"Classes folder not found!")

    local Dependencies : Folder = script:FindFirstChild("Dependencies")

    assert(Dependencies,"Dependencies folder not found!")

    local sift = require(Dependencies["sift"])
    local JanitorModule = require(Dependencies["janitor"])
    local Freeze = require(Dependencies["Freeze"])
    local Janitor = JanitorModule.new()
    
    local DoorClass = require(script.Classes.Door)
    local Config = require(script.Config)

    local WaitTime = Config.IdleTime or 7
    if WaitTime <= 0 then
        WaitTime = 7
    end

    local Source : Model = controller.Source
    assert(Source,"Source not found!")
    
    local Floors : Folder = Source:FindFirstChild("Floors")
    assert(Floors,"Floors not found!")

    local MSDClient = script:FindFirstChild("Client")
    assert(MSDClient, "Fatal error: Client not found")

    if not ReplicatedStorage:FindFirstChild("MSDv2_AnimationAPI") then
        local AnimationAPI = Instance.new("RemoteEvent")
        AnimationAPI.Name = "MSDv2_AnimationAPI"
        AnimationAPI.Parent = ReplicatedStorage
    end

    if not ReplicatedStorage:FindFirstChild("MSDv2_Client") then
        local CloneClient = MSDClient:Clone()
        CloneClient.Parent = ReplicatedStorage
        CloneClient.Name = "MSDv2_Client"
        CloneClient.Enabled = true
    end
    MSDClient:Destroy()

    local function LockDoors(FloorData)
        local IsOpened = false
        for _,Door in ipairs(FloorData.Doors) do
            if Door.Opened == true then
                IsOpened = true
                break
            end
        end

        if IsOpened == true then
            API:Fire('door_signal', {
                sides = 'all', 
                request = 'open' 
            })
        else
            for _,Door in ipairs(FloorData.Doors) do
                Door:SetLocked(true)
            end
        end
    end

    local HasCalls = function()
		local hasCarCalls = false
		local hasHallCalls = false

		for _, v in controller.Queue.HallCalls do
			local FloorNumber = v.Call
			if Floors:FindFirstChild(`Floor_{FloorNumber}`) and FloorValue.Value ~= FloorNumber then
				hasHallCalls = true
				break
			end
		end

		for _, v in controller.Queue.CarCalls do
			local FloorNumber = v.Call
			if Floors:FindFirstChild(`Floor_{FloorNumber}`) and FloorValue.Value ~= FloorNumber then
				hasCarCalls = true
				break
			end
		end

		if hasCarCalls or hasHallCalls then
			return true
		else
			return false
		end
    end

    for _,Floor : Model in ipairs(Floors:GetChildren()) do
        local Swing_Doors : Model = Floor:FindFirstChild("Swing_Doors")
        local LocalConfig = Config
        local CFC = Config.CustomFloorConfig[Floor.Name]
        if CFC then
            LocalConfig = sift.Dictionary.merge(Config,CFC)
        end

        if Swing_Doors then
            local FloorData = {
                Locked = false,
                Doors = {}
            }

            local SwingDoors = {}
            local SwingDoorDatas = {}

            for _,Door in ipairs(Swing_Doors:GetChildren()) do
                if Door.Name:sub(1,4):lower() == "door" and Door:IsA("Model") then
                    local DoorSide : "L"|"R" = "L"
                    if Door.Name:len() > 4 then
                        local Side = Door.Name:sub(5,5)
                        if Side == "L" or Side == "R" then
                            DoorSide = Side
                        end
                    end
                    table.insert(SwingDoors,{
                        DoorModel = Door,
                        Side = DoorSide
                    })
                end
            end

            if #SwingDoors == 2 then
                -- Double Doors
                for _,Door in ipairs(SwingDoors) do
                    if Door.Side == "L" then
                        table.insert(SwingDoorDatas, DoorClass.new(sift.Dictionary.merge({
                            DoorModel = Door.DoorModel,
                            DoorRotation = LocalConfig.DoorRotation,
                            DoorSide = Door.Side,
                            Priority = "Primary",
                        },LocalConfig)))
                    else
                        table.insert(SwingDoorDatas, DoorClass.new(sift.Dictionary.merge({
                            DoorModel = Door.DoorModel,
                            DoorRotation = LocalConfig.DoorRotation,
                            DoorSide = Door.Side,
                            Priority = "Secondary"
                        },LocalConfig)))
                    end
                end
            elseif #SwingDoors == 1 then
                table.insert(SwingDoorDatas, DoorClass.new(sift.Dictionary.merge({
                    DoorModel = SwingDoors[1].DoorModel,
                    DoorRotation = LocalConfig.DoorRotation,
                    Priority = "Primary",
                },LocalConfig)))
            elseif #SwingDoors < 1 then
                warn("No SwingDoors found!")
                continue
            else
                warn("Too many doors!")
                continue
            end

            for _,SwingDoorData in ipairs(SwingDoorDatas) do
                if SwingDoorData.Detector then
                    if SwingDoorData.Detector:IsA("DragDetector") then
                        Janitor:Add(
                            SwingDoorData.Detector.DragStart:Connect(function()
                                SwingDoorData:Toggle(false)
                            end)
                        )
                    elseif SwingDoorData.Detector:IsA("ClickDetector") then
                        Janitor:Add(
                            SwingDoorData.Detector.MouseClick:Connect(function()
                                SwingDoorData:Toggle(false)
                            end)
                        )
                    end
                end

                for _, DoorPart in ipairs(SwingDoorData.DoorModel:GetChildren()) do
                    if DoorPart:IsA("BasePart") then
                        Janitor:Add(
                            DoorPart.Touched:Connect(function(Part: BasePart)
                                if Part.Parent:IsA("Tool") then
                                    if Config.EnableBypass == false then return end
                                    if SwingDoorData.Touch_Debounce then return end
                                    SwingDoorData.Touch_Debounce = true
                                    
                                    task.delay(0.5,function()
                                        SwingDoorData.Touch_Debounce = false
                                    end)

                                    if Part.Parent.Name == "Triangle Key" then
                                        if State.key_debounce then return end

                                        State.key_debounce = true
                                        task.delay(0.5, function()
                                            State.key_debounce = false
                                        end)
                                        State.Stopped = not State.Stopped
                                        if State.Stopped then
                                            if not SwingDoorData.Opened then
                                                SwingDoorData:Open()
                                            end
                                            controller.StatValues.DoorSafetyLock = false
                                            controller.UpdateStatValues()
                                            
                                            API:Fire("Stop",true)
                                            
                                            if Config.OpenInnerdoorsOnKey then
                                                task.defer(function()							
                                                    for _, doorData in controller.door_data do
                                                        doorData.Disable(false)
                                                        doorData.Open({
                                                            open_time = controller.Config.doors.door_timers.open_no_call,
                                                            disable_safety_lock = true,
                                                            bypass_door_zone = true,
                                                            bypass_disabled_elevator = true,
                                                        })
                                                    end
                                                end)
                                            end
                                        else
                                           if SwingDoorData.Opened then
                                                SwingDoorData:Close()
                                           end
                                            API:Fire("Stop",false)
                                        end
                                    elseif Part.Parent.Name == "Safety Contact" then
                                        SwingDoorData:Toggle(true)
                                    end


                                end
                                
                            end)
                        )
                    end
                end
                SwingDoorData.IsOpened:Connect(function()
                    API:Fire('door_signal', {
                        sides = 'all', 
                        request = 'open' 
                    })
                end)
            end

            FloorData.Doors = SwingDoorDatas

            FloorsData[Floor.Name] = FloorData
        end
    end

	if Config.OpenInnerdoorsOnSetup == true then
		API:Fire('door_signal', {
			sides = 'all', 
			request = 'open' 
		})
	end
    Janitor:Add(
        API.Event:Connect(function(protocol,params)
            local FloorData = FloorsData[`Floor_{FloorValue.Value}`]

            if not FloorData then warn(`FloorData missing for floor {FloorValue.Value}`); return end
            
            if protocol == "on_stop" then
                if Config.UnlockType == "BeforeOpen" then
                    for _,Door in ipairs(FloorData.Doors) do
                        Door:SetLocked(false)
                    end
                end
            elseif protocol == "on_door_opened" then
                if Config.UnlockType == "AfterOpen" then
                    for _,Door in ipairs(FloorData.Doors) do
                        Door:SetLocked(false)
                    end
                end 

                if Config.OpenDoorOnArrive then
                    local FloorName = `Floor_{FloorValue.Value}`
                    task.wait(Config.OpenDoorOnArriveDelay)
                    if `Floor_{FloorValue.Value}` ~= FloorName then
                        return
                    end
                    for _,Door in ipairs(FloorData.Doors) do
                        task.spawn(function()
                            Door:Toggle(false)
                        end)
                    end
                end

                State.idle_generation += 1
                local generation = State.idle_generation
                State.idle_loop = true
                task.spawn(function()
                    while State.idle_loop  and generation == State.idle_generation do
                        task.wait(WaitTime)

                        if generation ~= State.idle_generation then
                            break
                        end

                        if not FloorData then warn(`Idle loop failed! FloorData somehow doesn't exist for {FloorValue.Value}`); return end

                        local allClosed = true
                        for _,Door in ipairs(FloorData.Doors) do
                            if Door.Opened == true then
                                allClosed = false
                                break
                            end
                        end
                        if allClosed then
                            if HasCalls() then
                                if Config.LockType == "BeforeClose" then
                                    LockDoors(FloorData)
                                end

                                task.wait(Config.CloseIdle or 0.5)

                                API:Fire('door_signal', {
                                    sides = 'all', 
                                    request = 'close' 
                                })
                                State.idle_loop = false
                                State.idle_generation += 1
                            end
                        end

                        if State.idle_loop == false then break end
                    end
                end)
            elseif protocol == "on_door_open" then
                State.idle_loop = true
                if Config.UnlockType == "BeforeOpen" then
                    for _,Door in ipairs(FloorData.Doors) do
                        Door:SetLocked(false)
                    end
                end
            elseif protocol == "on_door_close" then
                if Config.LockType == "BeforeClose" then
                    LockDoors(FloorData)
                end 

                local DoorCloseSpeed = Freeze.Dictionary.getIn(ElevatorConfig, {"doors","close_speed"}) or 1
                if not DoorCloseSpeed or DoorCloseSpeed <= 0 then
                    DoorCloseSpeed = 1
                end

                local AfterCloseLockRate = Config.AfterCloseLockRate or 10
                if AfterCloseLockRate <= 0 then
                    AfterCloseLockRate = 10
                end

                task.wait(DoorCloseSpeed-(DoorCloseSpeed/AfterCloseLockRate))

                if Config.LockType == "AfterClose" then
                    LockDoors(FloorData)
                end 
            elseif protocol == "on_door_closed" then
                LockDoors(FloorData)
            elseif protocol == "on_car_call_added" or protocol == "on_hall_call_added" then
                if Config.CloseDoorOnCall then
                    task.wait(1)
                    if HasCalls() then
                        for _,Door in ipairs(FloorData.Doors) do
                            task.spawn(function()
                                Door:Close()
                            end)
                        end
                    end
                end
            end
        end)
    )

    Janitor:LinkToInstance(script)
end

return module