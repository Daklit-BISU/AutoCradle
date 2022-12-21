function sysCall_init() 
    arm = sim.getObjectHandle('Arm_actuator')
    grab = sim.getObjectHandle('Grab_actuator')
    hoist = sim.getObjectHandle('Hoist_actuator')
    suction = sim.getObjectHandle('SuctionPad') 
    
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
        
    s=sim.getObject('./Sensor')
    l=sim.getObject('./LoopClosureDummy1')
    l2=sim.getObject('./LoopClosureDummy2')
    b=sim.getObject('.')
    suctionPadLink=sim.getObject('./Link')

    infiniteStrength=true
    maxPullForce=3
    maxShearForce=1
    maxPeelTorque=0.1
    enabled=false

    sim.setLinkDummy(l,-1)
    sim.setObjectParent(l,b,true)
    m=sim.getObjectMatrix(l2,sim.handle_world)
    sim.setObjectMatrix(l,sim.handle_world,m)
end

function ArmActuator(ui, id, newVal)
    local val = newVal *36 
    sim.setJointTargetPosition(arm, val * math.pi / 180)
    simUI.setLabelText(ui, 1, string.format("Arm position (deg): %.2f", val))
end

function GrabActuator(ui, id, newVal)
    local val = newVal * 0.65
    sim.setJointTargetPosition(grab, math.deg(val))
    simUI.setLabelText(ui, 3, string.format("Grab position (m): %.2f", val))
end

function HoistActuator(ui, id, newVal)
    local val = newVal * 0.6
    sim.setJointTargetPosition(hoist, val)
    simUI.setLabelText(ui, 5, string.format("Hoist position (m): %.2f", val))
end


function MagnetActuator(ui)
    if enabled then
        enabled = false
        simUI.setButtonText(ui,8,"Deactivated")
    else
        enabled = true
        simUI.setButtonText(ui,8,"Activated")
    end
end

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