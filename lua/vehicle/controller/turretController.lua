local M = {}
M.type = "auxiliary"
M.defaultOrder = 100

local random = math.random
local min = math.min
local max = math.max
local abs = math.abs
local atan2 = math.atan2
local asin = math.asin
local acos = math.acos

local rotationServo = nil
local elevationServo = nil

local minElevation = nil
local maxElevation = nil

local vehRot = quat()

local camPos = vec3()
local camRot = quat()

local barrelFrontId = nil
local barrelRearId = nil

local function shortestAngle(target, heading)
	return (target - heading + 3*math.pi) % (2*math.pi) - math.pi
end

local function setCameraRotation(pos, rot)
	camPos = pos
	camRot = rot
end

local function getCameraRotation()
	obj:queueGameEngineLua('be:queueObjectLua('..obj:getID()..', "controller.getControllerSafe(\''..M.name..'\').setCameraRotation("..serialize(core_camera.getPosition())..", "..serialize(core_camera.getQuat())..")")')
end

local function reset(jbeamData)
    vehRot = quatFromDir(-obj:getDirectionVector(), obj:getDirectionVectorUp())
end

local function init(jbeamData)
    rotationServo = jbeamData.rotationServo or rotationServo
    elevationServo = jbeamData.elevationServo or elevationServo

    minElevation = jbeamData.minElevation or minElevation
    maxElevation = jbeamData.maxElevation or maxElevation

    barrelNodeFront = jbeamData.barrelNodeFront
    barrelNodeRear = jbeamData.barrelNodeRear

    if not barrelNodeFront then
        log('E', "turretController.init", "barrelNodeFront not defined!")
    end
    if not barrelNodeRear then
        log('E', "turretController.init", "barrelNodeRear not defined!")
    end

    for _, n in pairs(v.data.nodes) do
        if n.name == barrelNodeFront then
            barrelFrontId = n.cid
        end
        if n.name == barrelNodeRear then
            barrelRearId = n.cid
        end
    end

    local elServo = powertrain.getDevice(elevationServo)
    if elServo and minElevation and maxElevation then
        elServo:setMinMaxAngles(minElevation, maxElevation)
    end

    reset(jbeamData)
end

local function updateGFX(dt)
    
    local gunDir = (obj:getNodePosition(barrelFrontId) - obj:getNodePosition(barrelRearId)):normalized()--vehRot * vec3(0,1,0)
    local camDir = obj:getDirectionVector()
    if playerInfo.anyPlayerSeated then
        getCameraRotation()
        camDir = camRot * vec3(0, 0.93, 0.37)
    -- AI aiming
    elseif ai.isDriving() then
        electrics.values.fireweapons = 0
        
        if mapmgr.objects[ai.targetObjectID] then
            local target = mapmgr.objects[ai.targetObjectID]
            local targetPos = target.pos + vec3(0, 0, 1)
            local shootPos = (obj:getPosition() + obj:getNodePosition(barrelRearId))
            
            local shotLen = shootPos:distance(targetPos)
            local hitLen = obj:castRayStatic(shootPos, gunDir, shotLen)
            
            -- Lead shots a bit
            targetPos = targetPos + target.vel*shotLen*0.003
            targetPos.z = targetPos.z + shotLen*shotLen*0.00005

            --print(hitLen.." "..shotLen)
            if abs(hitLen - shotLen) < 10 then
                electrics.values.fireweapons = 1
            end

            camDir = (targetPos - shootPos):normalized()
        end
    end
    
    local camHeading = atan2(camDir.y, camDir.x)
    local camElevation = asin(camDir.z)

    -- BeamMP compatibility
    if v.mpVehicleType == "L" then
        electrics.values["camHeading"] = camHeading
        electrics.values["camElevation"] = camElevation
    elseif v.mpVehicleType == "R" then
        camHeading = electrics.values["camHeading"] or camHeading
        camElevation = electrics.values["camElevation"] or camElevation
    end

    local gunHeading = atan2(gunDir.y, gunDir.x)
    local gunElevation = asin(gunDir.z)

    local rotServo = powertrain.getDevice(rotationServo)
    if rotServo then
        rotServo:setTargetAngle(rotServo.currentAngle + shortestAngle(gunHeading, camHeading)*0.1)
    end

    local elServo = powertrain.getDevice(elevationServo)
    if elServo then
        elServo:setTargetAngle(elServo.currentAngle + shortestAngle(gunElevation, camElevation)*0.1)
    end
end

-- public interface
M.reset      = reset
M.init       = init
M.updateGFX  = updateGFX
M.setCameraRotation = setCameraRotation

return M