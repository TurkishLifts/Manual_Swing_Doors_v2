--!nocheck
local OpenValidator = {}
OpenValidator.__index = OpenValidator

function OpenValidator.new()
    local NewValidator = {}
    setmetatable(NewValidator, OpenValidator)

    NewValidator.Locked = false

    return NewValidator
end

function OpenValidator:Validate(Params : {DoorModel : Model, Nitwit: boolean})
    if Params.Nitwit == true then
        return true
    end

    local DoorModel = Params.DoorModel
    local FloorModel : Model = DoorModel.Parent.Parent
    local Lift : Model = DoorModel:FindFirstAncestor("Floors").Parent
    local Values : Folder = Lift:FindFirstChild("Values")

    if not Values then
        warn("Values not found, Validation failed!")
        return false
    end

    local FloorNumber : number = tonumber( (FloorModel.Name:gsub("Floor_", "")) )
    local CarFloor : NumberValue = Values:FindFirstChild("Floor")

    if CarFloor.Value ~= FloorNumber then
        return false
    end

    local Speed : NumberValue = Values:FindFirstChild("Speed")
    
    if Speed.Value ~= 0 then
        return false
    end

    return true
end

return OpenValidator