-- This script controls a crane with an arm, a grab, and a hoist.
-- It also has a magnet that can be activated or deactivated.
-- The user can control the actuators using a UI with sliders and buttons.

-- First, we define several variables that will be used in the script:
-- The handles for the arm, grab, and hoist actuators:
arm = sim.getObjectHandle('Arm_actuator')
grab = sim.getObjectHandle('Grab_actuator')
hoist = sim.getObjectHandle('Hoist_actuator')

-- The handle for the suction pad:
suction = sim.getObjectHandle('SuctionPad') 

-- The handles for the sensor, the loop closure dummy objects, and the base object:
s=sim.getObject('./Sensor')
l=sim.getObject('./LoopClosureDummy1')
l2=sim.getObject('./LoopClosureDummy2')
b=sim.getObject('.')

-- The handle for the suction pad link:
suctionPadLink=sim.getObject('./Link')

-- Flags for the magnet:
infiniteStrength=true
maxPullForce=3
maxShearForce=1
maxPeelTorque=0.1
enabled=false

-- The sysCall_init function is called when the script is first loaded:
function sysCall_init()
    -- Set the parent of the object l to be the object b:
    sim.setLinkDummy(l,-1)
    sim.setObjectParent(l,b,true)
    -- Set the object matrix of l to be the same as the object matrix of l2 in the world frame:
    m=sim.getObjectMatrix(l2,sim.handle_world)
    sim.setObjectMatrix(l,sim.handle_world,m)

    -- The UI with sliders and buttons:
    xml = [[
        <ui title="Crane Control" closeable="true" resizable="false" activate="false">
            <group layout="form" flat="true">
                <label text="Arm Position (rad): 0.00" id="1"/>
                <hslider tick-position="above" tick-interval="1" minimum="0" maximum="10" on-change="ArmActuator" id="2"/>
                <label text="Grab Position (m): 0.00" id="3"/>
                <hslider tick-position="above" tick-interval="1" minimum="0" maximum="10" on-change="GrabActuator" id="4"/>
                <label text="Hoist Position (m): 0.00" id="5"/>
                <hslider tick-position="above" tick-interval="1" minimum="-10" maximum="0" on-change="HoistActuator" id="6"/>
                <label text="Magnet" id="7"/>
                <button text="Deactivated" on-click="MagnetActuator" checkable="true" id="8"/>
            </group>
            <label text="" style="* {margin-left: 400px;}"/>
        </ui>
        ]]
    ui = simUI.create(xml)
end

-- The ArmActuator function is called when the arm position slider is changed:
function ArmActuator(ui, id, newVal)
    -- Convert the new slider value to a joint angle in degrees:
    local val = newVal *36 
    -- Set the target position of the arm actuator based on the new joint angle:
    sim.setJointTargetPosition(arm, val * math.pi / 180)
    -- Update the label text to show the new arm position:
    simUI.setLabelText(ui, 1, string.format("Arm position (deg): %.2f", val))
end

-- The GrabActuator function is called when the grab position slider is changed:
function GrabActuator(ui, id, newVal)
    -- Convert the new slider value to a grab position in meters:
    local val = newVal * 0.65
    -- Set the target position of the grab actuator based on the new grab position:
    sim.setJointTargetPosition(grab, math.deg(val))
    -- Update the label text to show the new grab position:
    simUI.setLabelText(ui, 3, string.format("Grab position (m): %.2f", val))
end

-- The HoistActuator function is called when the hoist position slider is changed:
function HoistActuator(ui, id, newVal)
    -- Convert the new slider value to a hoist position in meters:
    local val = newVal * 0.6
    -- Set the target position of the hoist actuator based on the new hoist position:
    sim.setJointTargetPosition(hoist, val)
    -- Update the label text to show the new hoist position:
    simUI.setLabelText(ui, 5, string.format("Hoist position (m): %.2f", val))
end

-- The MagnetActuator function is called when the magnet button is clicked:
function MagnetActuator(ui)
    -- Toggle the magnet between activated and deactivated:
    if enabled then
        enabled = false
        -- Update the button text to show that the magnet is deactivated:
        simUI.setButtonText(ui,8,"Deactivated")
    else
        enabled = true
        -- Update the button text to show that the magnet is activated:
        simUI.setButtonText(ui,8,"Activated")
    end
end

--The codes bellow are built in scripts of the suction cup
function sysCall_cleanup() 
    sim.setLinkDummy(l,-1)
    sim.setObjectParent(l,b,true)
    m=sim.getObjectMatrix(l2,sim.handle_world)
    sim.setObjectMatrix(l,sim.handle_world,m)
end 

function sysCall_sensing() 
    parent=sim.getObjectParent(l)
    if not enabled then
        if (parent~=b) then
            sim.setLinkDummy(l,-1)
            sim.setObjectParent(l,b,true)
            m=sim.getObjectMatrix(l2,sim.handle_world)
            sim.setObjectMatrix(l,sim.handle_world,m)
        end
    else
        if (parent==b) then
            -- Here we want to detect a respondable shape, and then connect to it with a force sensor (via a loop closure dummy dummy link)
            -- However most respondable shapes are set to "non-detectable", so "sim.readProximitySensor" or similar will not work.
            -- But "sim.checkProximitySensor" or similar will work (they don't check the "detectable" flags), but we have to go through all shape objects!
            index=0
            while true do
                shape=sim.getObjects(index,sim.object_shape_type)
                if (shape==-1) then
                    break
                end
                if (shape~=b) and (sim.getObjectInt32Param(shape,sim.shapeintparam_respondable)~=0) and (sim.checkProximitySensor(s,shape)==1) then
                    -- Ok, we found a respondable shape that was detected
                    -- We connect to that shape:
                    -- Make sure the two dummies are initially coincident:
                    sim.setObjectParent(l,b,true)
                    m=sim.getObjectMatrix(l2,sim.handle_world)
                    sim.setObjectMatrix(l,sim.handle_world,m)
                    -- Do the connection:
                    sim.setObjectParent(l,shape,true)
                    sim.setLinkDummy(l,l2)
                    break
                end
                index=index+1
            end
        else
            -- Here we have an object attached
            if (infiniteStrength==false) then
                -- We might have to conditionally beak it apart!
                result,force,torque=sim.readForceSensor(suctionPadLink) -- Here we read the median value out of 5 values (check the force sensor prop. dialog)
                if (result>0) then
                    breakIt=false
                    if (force[3]>maxPullForce) then breakIt=true end
                    sf=math.sqrt(force[1]*force[1]+force[2]*force[2])
                    if (sf>maxShearForce) then breakIt=true end
                    if (torque[1]>maxPeelTorque) then breakIt=true end
                    if (torque[2]>maxPeelTorque) then breakIt=true end
                    if (breakIt) then
                        -- We break the link:
                        sim.setLinkDummy(l,-1)
                        sim.setObjectParent(l,b,true)
                        m=sim.getObjectMatrix(l2,sim.handle_world)
                        sim.setObjectMatrix(l,sim.handle_world,m)
                    end
                end
            end
        end
    end
end 