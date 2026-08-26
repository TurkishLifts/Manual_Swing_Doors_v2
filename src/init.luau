--[[
    Manual Swing Doors V2 | by: TurkishLifts

        VERSION: v2.0a | DATE: 26/08/2026
]]--
--!nocheck

local module = {}

function module.init(controller : {})
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Classes : Folder = script:FindFirstChild("Classes")
    local ValuesFolder : Folder = controller.ValuesFolder
    local FloorValue : NumberValue = ValuesFolder:FindFirstChild("Floor")
    local idle_loop = false
    local API : BindableEvent = controller.API

    local FloorsData = {}

    assert(Classes,"Classes folder not found!")

    local Dependencies : Folder = script:FindFirstChild("Dependencies")

    assert(Dependencies,"Dependencies folder not found!")
    
    local sift = require(Dependencies["sift"])
    local JanitorModule = require(Dependencies["janitor"])

    local Janitor = JanitorModule.new()

    local DoorClass = require(script.Classes.Door)
    local Config = require(script.Config)


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
                            DoorSide = Door.Side
                        },LocalConfig)))
                    else
                        table.insert(SwingDoorDatas, DoorClass.new(sift.Dictionary.merge({
                            DoorModel = Door.DoorModel,
                            DoorRotation = LocalConfig.DoorRotation,
                            DoorSide = Door.Side
                        },LocalConfig)))
                    end
                end
            elseif #SwingDoors == 1 then
                table.insert(SwingDoorDatas, DoorClass.new(sift.Dictionary.merge({
                    DoorModel = SwingDoors[1].DoorModel,
                    DoorRotation = LocalConfig.DoorRotation,
                },LocalConfig)))
            elseif #SwingDoors < 1 then
                warn("No SwingDoors found!")
                return
            else
                warn("Too many doors!")
                return
            end

            for _,SwingDoorData in ipairs(SwingDoorDatas) do
                if SwingDoorData.Detector:IsA("DragDetector") then
                    Janitor:Add(
                        SwingDoorData.Detector.DragStart:Connect(function()
                            SwingDoorData:Toggle()
                        end)
                    )
                elseif SwingDoorData.Detector:IsA("ClickDetector") then
                    Janitor:Add(
                        SwingDoorData.Detector.MouseClick:Connect(function()
                            SwingDoorData:Toggle()
                        end)
                    )
                end
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

    API.Event:Connect(function(protocol,params)
        local FloorData = FloorsData[`Floor_{FloorValue.Value}`]
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

            while idle_loop do
                task.wait(Config.IdleTime)

                if not FloorData then warn(`Idle loop failed! FloorData somehow doesn't exist for {FloorValue.Value}`); continue end

                local AllClosed = true
                for _,Door in ipairs(FloorData.Doors) do
                    if Door.Opened == true then
                        AllClosed = false
                    end
                end

                if AllClosed == true then
                    local LiftHasCalls = HasCalls()
                    if LiftHasCalls then
                        for _,Door in ipairs(FloorData.Doors) do
                            Door:SetLocked(true)
                        end
                        API:Fire('door_signal', {
                            sides = 'all', 
                            request = 'close' 
                        })
                        idle_loop = false
                    end
                end
                if idle_loop == false then break end
            end
        elseif protocol == "on_door_open" then
            idle_loop = true
            if Config.UnlockType == "BeforeOpen" then
                for _,Door in ipairs(FloorData.Doors) do
                    Door:SetLocked(false)
                end
            end
        end
    end)

end

return module